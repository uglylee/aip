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

	result := make([]fiber.Map, len(notifications))
	for i, n := range notifications {
		var fromUser models.User
		services.Users.FindOne(ctx, bson.M{"_id": n.FromUser}).Decode(&fromUser)

		var postData fiber.Map
		if n.Post != nil {
			var post models.Post
			if err := services.Posts.FindOne(ctx, bson.M{"_id": n.Post}).Decode(&post); err == nil {
				postData = fiber.Map{"content": post.Content}
			}
		}

		result[i] = fiber.Map{
			"id":        n.ID,
			"user":      n.User,
			"fromUser":  toUserBrief(&fromUser),
			"type":      n.Type,
			"post":      postData,
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
		return c.Status(400).JSON(fiber.Map{"error": "Invalid notification ID"})
	}

	services.Notifications.UpdateOne(ctx, bson.M{"_id": notifID}, bson.M{"$set": bson.M{"read": true}})
	return c.JSON(fiber.Map{"success": true})
}

func MarkAllRead(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	viewerID := middleware.GetUserID(c)
	services.Notifications.UpdateMany(ctx, bson.M{"user": viewerID, "read": false}, bson.M{"$set": bson.M{"read": true}})
	return c.JSON(fiber.Map{"success": true})
}
