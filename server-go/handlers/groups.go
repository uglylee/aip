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

func CreateGroup(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var body struct {
		Name      string   `json:"name"`
		MemberIDs []string `json:"memberIds"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request"})
	}

	viewerID := middleware.GetUserID(c)
	members := []bson.ObjectID{viewerID}
	seen := map[bson.ObjectID]bool{viewerID: true}

	for _, mid := range body.MemberIDs {
		oid, err := bson.ObjectIDFromHex(mid)
		if err == nil && !seen[oid] {
			members = append(members, oid)
			seen[oid] = true
		}
	}

	group := models.Group{
		ID:        bson.NewObjectID(),
		Name:      body.Name,
		Admin:     viewerID,
		Members:   members,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	if _, err := services.Groups.InsertOne(ctx, group); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(toGroupResponse(ctx, &group))
}

func ListGroups(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	viewerID := middleware.GetUserID(c)
	opts := options.Find().SetSort(bson.D{{Key: "updatedAt", Value: -1}})

	cursor, err := services.Groups.Find(ctx, bson.M{"members": viewerID}, opts)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var groups []models.Group
	cursor.All(ctx, &groups)

	result := make([]fiber.Map, len(groups))
	for i, g := range groups {
		var lastMsg models.Message
		services.Messages.FindOne(ctx, bson.M{"groupId": g.ID}, options.FindOne().SetSort(bson.D{{Key: "createdAt", Value: -1}})).Decode(&lastMsg)

		result[i] = fiber.Map{
			"group":       toGroupResponse(ctx, &g),
			"lastMessage": lastMsg,
		}
	}

	return c.JSON(fiber.Map{"groups": result})
}

func GetGroup(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	groupID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid group ID"})
	}

	var group models.Group
	if err := services.Groups.FindOne(ctx, bson.M{"_id": groupID}).Decode(&group); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Group not found"})
	}

	return c.JSON(toGroupResponse(ctx, &group))
}

func AddMembers(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	groupID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid group ID"})
	}

	var body struct {
		UserIDs []string `json:"userIds"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request"})
	}

	var group models.Group
	if err := services.Groups.FindOne(ctx, bson.M{"_id": groupID}).Decode(&group); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Group not found"})
	}

	for _, uid := range body.UserIDs {
		oid, err := bson.ObjectIDFromHex(uid)
		if err != nil {
			continue
		}
		exists := false
		for _, m := range group.Members {
			if m == oid {
				exists = true
				break
			}
		}
		if !exists {
			group.Members = append(group.Members, oid)
		}
	}

	services.Groups.UpdateOne(ctx, bson.M{"_id": groupID}, bson.M{"$set": bson.M{"members": group.Members}})
	services.Groups.FindOne(ctx, bson.M{"_id": groupID}).Decode(&group)

	return c.JSON(toGroupResponse(ctx, &group))
}

func RemoveMember(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	groupID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid group ID"})
	}

	memberID, err := bson.ObjectIDFromHex(c.Params("memberId"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid member ID"})
	}

	var group models.Group
	if err := services.Groups.FindOne(ctx, bson.M{"_id": groupID}).Decode(&group); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Group not found"})
	}

	newMembers := []bson.ObjectID{}
	for _, m := range group.Members {
		if m != memberID {
			newMembers = append(newMembers, m)
		}
	}
	services.Groups.UpdateOne(ctx, bson.M{"_id": groupID}, bson.M{"$set": bson.M{"members": newMembers}})

	return c.JSON(fiber.Map{"success": true})
}

func GetGroupMessages(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	groupID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid group ID"})
	}

	opts := options.Find().SetSort(bson.D{{Key: "createdAt", Value: 1}})
	cursor, err := services.Messages.Find(ctx, bson.M{"groupId": groupID}, opts)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var messages []models.Message
	cursor.All(ctx, &messages)

	return c.JSON(fiber.Map{"messages": messages})
}

func SendGroupMessage(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	groupID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid group ID"})
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
		GroupID:   &groupID,
		Content:   body.Content,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	if _, err := services.Messages.InsertOne(ctx, message); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	ws.H.EmitToRoom("group:"+groupID.Hex(), "group_message", fiber.Map{
		"_id":       message.ID,
		"sender":    viewerID,
		"groupId":   groupID,
		"content":   message.Content,
		"createdAt": message.CreatedAt,
	})

	return c.JSON(message)
}

func toGroupResponse(ctx context.Context, group *models.Group) fiber.Map {
	members := []fiber.Map{}
	if len(group.Members) > 0 {
		cursor, err := services.Users.Find(ctx, bson.M{"_id": bson.M{"$in": group.Members}}, options.Find().SetProjection(bson.M{"password": 0}))
		if err == nil {
			var users []models.User
			cursor.All(ctx, &users)
			for _, u := range users {
				members = append(members, toUserBrief(&u))
			}
		}
	}

	return fiber.Map{
		"id":        group.ID,
		"name":      group.Name,
		"avatar":    group.Avatar,
		"admin":     group.Admin,
		"members":   members,
		"createdAt": group.CreatedAt,
		"updatedAt": group.UpdatedAt,
	}
}
