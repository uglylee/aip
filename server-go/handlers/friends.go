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

func SendFriendRequest(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	toID, err := bson.ObjectIDFromHex(c.Params("toUserId"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "无效用户ID"})
	}
	viewerID := middleware.GetUserID(c)

	if toID == viewerID {
		return c.Status(400).JSON(fiber.Map{"error": "不能添加自己"})
	}

	var existing models.FriendRequest
	err = services.FriendRequests.FindOne(ctx, bson.M{"from": viewerID, "to": toID}).Decode(&existing)
	if err == nil {
		return c.Status(400).JSON(fiber.Map{"error": "已经发送过请求"})
	}

	var reverse models.FriendRequest
	err = services.FriendRequests.FindOne(ctx, bson.M{"from": toID, "to": viewerID, "status": "pending"}).Decode(&reverse)
	if err == nil {
		services.FriendRequests.UpdateOne(ctx, bson.M{"_id": reverse.ID}, bson.M{"$set": bson.M{"status": "accepted"}})
		return c.JSON(fiber.Map{"status": "accepted"})
	}

	var accepted models.FriendRequest
	err = services.FriendRequests.FindOne(ctx, bson.M{"from": toID, "to": viewerID, "status": "accepted"}).Decode(&accepted)
	if err == nil {
		return c.Status(400).JSON(fiber.Map{"error": "已经是好友"})
	}

	friendReq := models.FriendRequest{
		ID:     bson.NewObjectID(),
		From:   viewerID,
		To:     toID,
		Status: "pending",
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	services.FriendRequests.InsertOne(ctx, friendReq)

	notification := models.Notification{
		ID:        bson.NewObjectID(),
		User:      toID,
		FromUser:  viewerID,
		Type:      "friend_request",
		Read:      false,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	services.Notifications.InsertOne(ctx, notification)

	ws.H.EmitToUser(toID.Hex(), "notification", fiber.Map{"type": "friend_request"})

	return c.JSON(fiber.Map{"status": "pending"})
}

func GetFriendStatus(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	targetID, err := bson.ObjectIDFromHex(c.Params("userId"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "无效用户ID"})
	}
	viewerID := middleware.GetUserID(c)

	var outgoing, incoming models.FriendRequest
	outErr := services.FriendRequests.FindOne(ctx, bson.M{"from": viewerID, "to": targetID}).Decode(&outgoing)
	inErr := services.FriendRequests.FindOne(ctx, bson.M{"from": targetID, "to": viewerID}).Decode(&incoming)

	status := "none"
	areFriends := false

	if outErr == nil {
		status = outgoing.Status
	} else if inErr == nil {
		if incoming.Status == "pending" {
			status = "received"
		} else if incoming.Status == "accepted" {
			status = "accepted"
		}
	}

	if (outErr == nil && outgoing.Status == "accepted") || (inErr == nil && incoming.Status == "accepted") {
		areFriends = true
	}

	return c.JSON(fiber.Map{"status": status, "areFriends": areFriends})
}

func GetPendingRequests(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	viewerID := middleware.GetUserID(c)
	opts := options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}})

	cursor, err := services.FriendRequests.Find(ctx, bson.M{"to": viewerID, "status": "pending"}, opts)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var requests []models.FriendRequest
	cursor.All(ctx, &requests)

	result := make([]fiber.Map, len(requests))
	for i, req := range requests {
		var user models.User
		services.Users.FindOne(ctx, bson.M{"_id": req.From}).Decode(&user)
		result[i] = fiber.Map{
			"id":     req.ID,
			"from":   toUserBrief(&user),
			"to":     req.To,
			"status": req.Status,
		}
	}

	return c.JSON(fiber.Map{"requests": result})
}

func GetFriends(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	viewerID := middleware.GetUserID(c)

	var sent, received []models.FriendRequest
	cursor1, _ := services.FriendRequests.Find(ctx, bson.M{"from": viewerID, "status": "accepted"})
	cursor1.All(ctx, &sent)
	cursor2, _ := services.FriendRequests.Find(ctx, bson.M{"to": viewerID, "status": "accepted"})
	cursor2.All(ctx, &received)

	friendIDs := []bson.ObjectID{}
	for _, r := range sent {
		friendIDs = append(friendIDs, r.To)
	}
	for _, r := range received {
		friendIDs = append(friendIDs, r.From)
	}

	if len(friendIDs) == 0 {
		return c.JSON(fiber.Map{"friends": []interface{}{}})
	}

	cursor, err := services.Users.Find(ctx, bson.M{"_id": bson.M{"$in": friendIDs}}, options.Find().SetProjection(bson.M{"password": 0}))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var users []models.User
	cursor.All(ctx, &users)

	result := make([]fiber.Map, len(users))
	for i, u := range users {
		result[i] = toUserBrief(&u)
	}

	return c.JSON(fiber.Map{"friends": result})
}

func AcceptFriend(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	requestID, err := bson.ObjectIDFromHex(c.Params("requestId"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "无效请求ID"})
	}
	viewerID := middleware.GetUserID(c)

	var req models.FriendRequest
	if err := services.FriendRequests.FindOne(ctx, bson.M{"_id": requestID}).Decode(&req); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "请求不存在"})
	}
	if req.To != viewerID {
		return c.Status(403).JSON(fiber.Map{"error": "无权操作"})
	}

	services.FriendRequests.UpdateOne(ctx, bson.M{"_id": requestID}, bson.M{"$set": bson.M{"status": "accepted"}})
	return c.JSON(fiber.Map{"success": true})
}

func DeclineFriend(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	requestID, err := bson.ObjectIDFromHex(c.Params("requestId"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "无效请求ID"})
	}
	viewerID := middleware.GetUserID(c)

	var req models.FriendRequest
	if err := services.FriendRequests.FindOne(ctx, bson.M{"_id": requestID}).Decode(&req); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "请求不存在"})
	}
	if req.To != viewerID {
		return c.Status(403).JSON(fiber.Map{"error": "无权操作"})
	}

	services.FriendRequests.UpdateOne(ctx, bson.M{"_id": requestID}, bson.M{"$set": bson.M{"status": "declined"}})
	return c.JSON(fiber.Map{"success": true})
}

func RemoveFriend(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	targetID, err := bson.ObjectIDFromHex(c.Params("userId"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "无效用户ID"})
	}
	viewerID := middleware.GetUserID(c)

	services.FriendRequests.DeleteMany(ctx, bson.M{
		"$or": []bson.M{
			{"from": viewerID, "to": targetID},
			{"from": targetID, "to": viewerID},
		},
	})

	return c.JSON(fiber.Map{"success": true})
}
