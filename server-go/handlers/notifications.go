package handlers

import (
	"context"
	"time"

	"aip-server/middleware"
	"aip-server/models"
	"aip-server/services"

	"github.com/gofiber/fiber/v2"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

func GetNotifications(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	viewerID := middleware.GetUserID(c)
	opts := options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}}).SetLimit(50)

	cursor, err := services.Notifications.Find(ctx, bson.M{"user": viewerID}, opts)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var notifications []models.Notification
	cursor.All(ctx, &notifications)

	fromUserIDs := make([]bson.ObjectID, 0, len(notifications))
	for _, n := range notifications {
		fromUserIDs = append(fromUserIDs, n.FromUser)
	}

	userMap := make(map[string]*models.User)
	if len(fromUserIDs) > 0 {
		userCursor, _ := services.Users.Find(ctx, bson.M{"_id": bson.M{"$in": fromUserIDs}}, options.Find().SetProjection(bson.M{"password": 0}))
		var users []models.User
		userCursor.All(ctx, &users)
		for i := range users {
			userMap[users[i].ID.Hex()] = &users[i]
		}
	}

	result := make([]fiber.Map, len(notifications))
	for i, n := range notifications {
		fromUser := userMap[n.FromUser.Hex()]
		var fromUserData fiber.Map
		if fromUser != nil {
			fromUserData = toUserBrief(fromUser)
		}

		var postData fiber.Map
		if n.Post != nil {
			var post models.Post
			if err := services.Posts.FindOne(ctx, bson.M{"_id": n.Post}).Decode(&post); err == nil {
				postData = fiber.Map{"id": post.ID, "content": post.Content}
			}
		}

		result[i] = fiber.Map{
			"id":        n.ID,
			"user":      n.User,
			"fromUser":  fromUserData,
			"type":      n.Type,
			"post":      postData,
			"postId":    n.Post,
			"read":      n.Read,
			"createdAt": n.CreatedAt,
		}
	}

	return c.JSON(fiber.Map{"notifications": result})
}

func GetUnreadCount(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	viewerID := middleware.GetUserID(c)
	count, err := services.Notifications.CountDocuments(ctx, bson.M{"user": viewerID, "read": false})
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{"count": count})
}

func MarkRead(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	notifID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "无效通知ID"})
	}

	viewerID := middleware.GetUserID(c)
	services.Notifications.UpdateOne(ctx, bson.M{"_id": notifID, "user": viewerID}, bson.M{"$set": bson.M{"read": true}})
	return c.JSON(fiber.Map{"success": true})
}

func MarkAllRead(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	viewerID := middleware.GetUserID(c)
	services.Notifications.UpdateMany(ctx, bson.M{"user": viewerID, "read": false}, bson.M{"$set": bson.M{"read": true}})
	return c.JSON(fiber.Map{"success": true})
}
