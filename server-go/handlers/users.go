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
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

func GetUser(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	targetID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid user ID"})
	}

	user, err := lookupUserByID(ctx, targetID)
	if err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "User not found"})
	}

	viewerID := middleware.GetUserID(c)
	return c.JSON(toUserPublic(user, viewerID))
}

func UpdateUser(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	targetID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid user ID"})
	}

	var body struct {
		Username string `json:"username"`
		Bio      string `json:"bio"`
		Avatar   string `json:"avatar"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request"})
	}

	update := bson.M{}
	if body.Username != "" {
		update["username"] = body.Username
	}
	if body.Bio != "" {
		update["bio"] = body.Bio
	}
	if body.Avatar != "" {
		update["avatar"] = body.Avatar
	}
	if len(update) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "No fields to update"})
	}

	var user models.User
	err = services.Users.FindOneAndUpdate(ctx, bson.M{"_id": targetID}, bson.M{"$set": update}, options.FindOneAndUpdate().SetReturnDocument(options.After)).Decode(&user)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(toUserBrief(&user))
}

func Follow(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	targetID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid user ID"})
	}
	viewerID := middleware.GetUserID(c)

	if targetID == viewerID {
		return c.Status(400).JSON(fiber.Map{"error": "Cannot follow yourself"})
	}

	var target models.User
	if err := services.Users.FindOne(ctx, bson.M{"_id": targetID}).Decode(&target); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "User not found"})
	}

	alreadyFollowing := false
	for _, fid := range target.Followers {
		if fid == viewerID {
			alreadyFollowing = true
			break
		}
	}

	if !alreadyFollowing {
		services.Users.UpdateOne(ctx, bson.M{"_id": targetID}, bson.M{"$addToSet": bson.M{"followers": viewerID}})
		services.Users.UpdateOne(ctx, bson.M{"_id": viewerID}, bson.M{"$addToSet": bson.M{"following": targetID}})

		notification := models.Notification{
			ID:       bson.NewObjectID(),
			User:     targetID,
			FromUser: viewerID,
			Type:     "follow",
			Read:     false,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		}
		services.Notifications.InsertOne(ctx, notification)

		ws.H.EmitToUser(targetID.Hex(), "notification", fiber.Map{"type": "follow"})
	}

	return c.JSON(fiber.Map{"isFollowing": true})
}

func Unfollow(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	targetID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid user ID"})
	}
	viewerID := middleware.GetUserID(c)

	services.Users.UpdateOne(ctx, bson.M{"_id": targetID}, bson.M{"$pull": bson.M{"followers": viewerID}})
	services.Users.UpdateOne(ctx, bson.M{"_id": viewerID}, bson.M{"$pull": bson.M{"following": targetID}})

	return c.JSON(fiber.Map{"isFollowing": false})
}

func GetFollowers(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	targetID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid user ID"})
	}

	var user models.User
	if err := services.Users.FindOne(ctx, bson.M{"_id": targetID}).Decode(&user); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "User not found"})
	}

	if len(user.Followers) == 0 {
		return c.JSON([]interface{}{})
	}

	opts := options.Find().SetProjection(bson.M{"password": 0})
	cursor, err := services.Users.Find(ctx, bson.M{"_id": bson.M{"$in": user.Followers}}, opts)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var users []models.User
	if err := cursor.All(ctx, &users); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	result := make([]fiber.Map, len(users))
	for i, u := range users {
		result[i] = toUserBrief(&u)
	}
	return c.JSON(result)
}

func GetFollowing(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	targetID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid user ID"})
	}

	var user models.User
	if err := services.Users.FindOne(ctx, bson.M{"_id": targetID}).Decode(&user); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "User not found"})
	}

	if len(user.Following) == 0 {
		return c.JSON([]interface{}{})
	}

	opts := options.Find().SetProjection(bson.M{"password": 0})
	cursor, err := services.Users.Find(ctx, bson.M{"_id": bson.M{"$in": user.Following}}, opts)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var users []models.User
	if err := cursor.All(ctx, &users); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	result := make([]fiber.Map, len(users))
	for i, u := range users {
		result[i] = toUserBrief(&u)
	}
	return c.JSON(result)
}
