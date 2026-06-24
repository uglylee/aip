package handlers

import (
	"context"
	"time"

	"aip-server/middleware"
	"aip-server/models"
	"aip-server/services"
	"aip-server/ws"

	"github.com/gofiber/fiber/v2"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

func GetConversations(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	viewerID := middleware.GetUserID(c)

	pipeline := mongo.Pipeline{
		{{Key: "$match", Value: bson.M{
			"$or": []bson.M{
				{"sender": viewerID},
				{"receiver": viewerID},
			},
		}}},
		{{Key: "$sort", Value: bson.D{{Key: "createdAt", Value: -1}}}},
		{{Key: "$group", Value: bson.M{
			"_id": bson.M{
				"$cond": bson.A{
					bson.M{"$eq": bson.A{"$sender", viewerID}},
					"$receiver",
					"$sender",
				},
			},
			"lastMessage": bson.M{"$first": "$$ROOT"},
			"unread": bson.M{
				"$sum": bson.M{
					"$cond": bson.A{
						bson.M{"$and": bson.A{
							bson.M{"$eq": bson.A{"$receiver", viewerID}},
							bson.M{"$eq": bson.A{"$read", false}},
						}},
						1, 0,
					},
				},
			},
		}}},
		{{Key: "$sort", Value: bson.D{{Key: "lastMessage.createdAt", Value: -1}}}},
	}

	cursor, err := services.Messages.Aggregate(ctx, pipeline)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	type ConversationResult struct {
		User        bson.ObjectID `bson:"_id"`
		LastMessage models.Message `bson:"lastMessage"`
		Unread      int           `bson:"unread"`
	}
	var conversations []ConversationResult
	if err := cursor.All(ctx, &conversations); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	if len(conversations) == 0 {
		return c.JSON(fiber.Map{"conversations": []interface{}{}})
	}

	userIDs := make([]bson.ObjectID, len(conversations))
	for i, conv := range conversations {
		userIDs[i] = conv.User
	}

	userCursor, err := services.Users.Find(ctx, bson.M{"_id": bson.M{"$in": userIDs}}, options.Find().SetProjection(bson.M{"password": 0}))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var users []models.User
	userCursor.All(ctx, &users)

	userMap := make(map[string]*models.User)
	for i := range users {
		userMap[users[i].ID.Hex()] = &users[i]
	}

	result := make([]fiber.Map, len(conversations))
	for i, conv := range conversations {
		user := userMap[conv.User.Hex()]
		var userData fiber.Map
		if user != nil {
			userData = toUserBrief(user)
		}
		result[i] = fiber.Map{
			"user":        userData,
			"lastMessage": conv.LastMessage,
			"unread":      conv.Unread,
		}
	}

	return c.JSON(fiber.Map{"conversations": result})
}

func GetMessages(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	otherID, err := bson.ObjectIDFromHex(c.Params("userId"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid user ID"})
	}
	viewerID := middleware.GetUserID(c)

	opts := options.Find().SetSort(bson.D{{Key: "createdAt", Value: 1}})
	cursor, err := services.Messages.Find(ctx, bson.M{
		"$or": []bson.M{
			{"sender": viewerID, "receiver": otherID},
			{"sender": otherID, "receiver": viewerID},
		},
	}, opts)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var messages []models.Message
	cursor.All(ctx, &messages)

	services.Messages.UpdateMany(ctx, bson.M{
		"sender":   otherID,
		"receiver": viewerID,
		"read":     false,
	}, bson.M{"$set": bson.M{"read": true}})

	return c.JSON(fiber.Map{"messages": messages})
}

func SendMessage(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	otherID, err := bson.ObjectIDFromHex(c.Params("userId"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid user ID"})
	}
	viewerID := middleware.GetUserID(c)

	var body struct {
		Content string `json:"content"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request"})
	}

	message := models.Message{
		ID:        bson.NewObjectID(),
		Sender:    viewerID,
		Receiver:  &otherID,
		Content:   body.Content,
		Read:      false,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	if _, err := services.Messages.InsertOne(ctx, message); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	ws.H.EmitToUser(otherID.Hex(), "message", fiber.Map{
		"_id":       message.ID,
		"sender":    viewerID,
		"receiver":  otherID,
		"content":   message.Content,
		"createdAt": message.CreatedAt,
	})

	return c.JSON(message)
}
