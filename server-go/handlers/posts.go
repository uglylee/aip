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

func CreatePost(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var body struct {
		Content    string   `json:"content"`
		ReplyTo    string   `json:"replyTo"`
		Images     []string `json:"images"`
		Videos     []string `json:"videos"`
		Thumbnails []string `json:"thumbnails"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request"})
	}

	viewerID := middleware.GetUserID(c)
	post := models.Post{
		ID:        bson.NewObjectID(),
		Author:    viewerID,
		Content:   body.Content,
		Images:    body.Images,
		Videos:    body.Videos,
		Thumbnails: body.Thumbnails,
		Likes:     []bson.ObjectID{},
		Retweets:  []bson.ObjectID{},
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	if body.ReplyTo != "" {
		replyToID, err := bson.ObjectIDFromHex(body.ReplyTo)
		if err == nil {
			post.ReplyTo = &replyToID
			services.Posts.UpdateOne(ctx, bson.M{"_id": replyToID}, bson.M{"$inc": bson.M{"replyCount": 1}})

			var original models.Post
			if err := services.Posts.FindOne(ctx, bson.M{"_id": replyToID}).Decode(&original); err == nil {
				if original.Author != viewerID {
					notification := models.Notification{
						ID:        bson.NewObjectID(),
						User:      original.Author,
						FromUser:  viewerID,
						Type:      "reply",
						Post:      &replyToID,
						Read:      false,
						CreatedAt: time.Now(),
						UpdatedAt: time.Now(),
					}
					services.Notifications.InsertOne(ctx, notification)
					ws.H.EmitToUser(original.Author.Hex(), "notification", fiber.Map{"type": "reply"})
				}
			}
		}
	}

	if _, err := services.Posts.InsertOne(ctx, post); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(toPostResponse(ctx, &post, viewerID))
}

func GetFeed(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	viewerID := middleware.GetUserID(c)

	opts := options.Find().
		SetSort(bson.D{{Key: "createdAt", Value: -1}}).
		SetSkip(int64((page - 1) * limit)).
		SetLimit(int64(limit))

	cursor, err := services.Posts.Find(ctx, bson.M{
		"replyTo":   nil,
		"retweetOf": nil,
	}, opts)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var posts []models.Post
	if err := cursor.All(ctx, &posts); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	result := make([]fiber.Map, len(posts))
	for i, p := range posts {
		result[i] = toPostResponse(ctx, &p, viewerID)
	}
	return c.JSON(fiber.Map{"posts": result})
}

func GetExplore(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	viewerID := middleware.GetUserID(c)
	opts := options.Find().
		SetSort(bson.D{{Key: "viewCount", Value: -1}, {Key: "createdAt", Value: -1}}).
		SetLimit(50)

	cursor, err := services.Posts.Find(ctx, bson.M{
		"replyTo":   nil,
		"retweetOf": nil,
	}, opts)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var posts []models.Post
	if err := cursor.All(ctx, &posts); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	result := make([]fiber.Map, len(posts))
	for i, p := range posts {
		result[i] = toPostResponse(ctx, &p, viewerID)
	}
	return c.JSON(fiber.Map{"posts": result})
}

func GetUserPosts(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	authorID, err := bson.ObjectIDFromHex(c.Params("userId"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid user ID"})
	}
	viewerID := middleware.GetUserID(c)

	opts := options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}})
	cursor, err := services.Posts.Find(ctx, bson.M{
		"author":    authorID,
		"retweetOf": nil,
	}, opts)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	var posts []models.Post
	if err := cursor.All(ctx, &posts); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	result := make([]fiber.Map, len(posts))
	for i, p := range posts {
		result[i] = toPostResponse(ctx, &p, viewerID)
	}
	return c.JSON(fiber.Map{"posts": result})
}

func GetPost(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	postID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid post ID"})
	}
	viewerID := middleware.GetUserID(c)

	var post models.Post
	if err := services.Posts.FindOneAndUpdate(ctx, bson.M{"_id": postID}, bson.M{"$inc": bson.M{"viewCount": 1}}, options.FindOneAndUpdate().SetReturnDocument(options.After)).Decode(&post); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Post not found"})
	}

	cursor, err := services.Posts.Find(ctx, bson.M{"replyTo": postID}, options.Find().SetSort(bson.D{{Key: "createdAt", Value: -1}}))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var replies []models.Post
	cursor.All(ctx, &replies)

	repliesJSON := make([]fiber.Map, len(replies))
	for i, r := range replies {
		repliesJSON[i] = toPostResponse(ctx, &r, viewerID)
	}

	return c.JSON(fiber.Map{
		"post":    toPostResponse(ctx, &post, viewerID),
		"replies": repliesJSON,
	})
}

func DeletePost(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	postID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid post ID"})
	}
	viewerID := middleware.GetUserID(c)

	var post models.Post
	if err := services.Posts.FindOne(ctx, bson.M{"_id": postID}).Decode(&post); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Post not found"})
	}
	if post.Author != viewerID {
		return c.Status(403).JSON(fiber.Map{"error": "Not authorized"})
	}

	services.Posts.DeleteOne(ctx, bson.M{"_id": postID})
	return c.JSON(fiber.Map{"success": true})
}

func LikePost(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	postID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid post ID"})
	}
	viewerID := middleware.GetUserID(c)

	var post models.Post
	if err := services.Posts.FindOne(ctx, bson.M{"_id": postID}).Decode(&post); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Post not found"})
	}

	alreadyLiked := false
	for _, lid := range post.Likes {
		if lid == viewerID {
			alreadyLiked = true
			break
		}
	}

	if !alreadyLiked {
		services.Posts.UpdateOne(ctx, bson.M{"_id": postID}, bson.M{"$addToSet": bson.M{"likes": viewerID}})

		if post.Author != viewerID {
			notification := models.Notification{
				ID:        bson.NewObjectID(),
				User:      post.Author,
				FromUser:  viewerID,
				Type:      "like",
				Post:      &postID,
				Read:      false,
				CreatedAt: time.Now(),
				UpdatedAt: time.Now(),
			}
			services.Notifications.InsertOne(ctx, notification)
			ws.H.EmitToUser(post.Author.Hex(), "notification", fiber.Map{"type": "like"})
		}
	}

	newCount := len(post.Likes)
	if !alreadyLiked {
		newCount++
	}
	return c.JSON(fiber.Map{"liked": true, "likes": newCount})
}

func UnlikePost(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	postID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid post ID"})
	}
	viewerID := middleware.GetUserID(c)

	services.Posts.UpdateOne(ctx, bson.M{"_id": postID}, bson.M{"$pull": bson.M{"likes": viewerID}})

	var post models.Post
	services.Posts.FindOne(ctx, bson.M{"_id": postID}).Decode(&post)
	return c.JSON(fiber.Map{"liked": false, "likes": len(post.Likes)})
}

func RetweetPost(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	postID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid post ID"})
	}
	viewerID := middleware.GetUserID(c)

	var post models.Post
	if err := services.Posts.FindOne(ctx, bson.M{"_id": postID}).Decode(&post); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Post not found"})
	}

	alreadyRetweeted := false
	for _, rid := range post.Retweets {
		if rid == viewerID {
			alreadyRetweeted = true
			break
		}
	}

	if !alreadyRetweeted {
		services.Posts.UpdateOne(ctx, bson.M{"_id": postID}, bson.M{"$addToSet": bson.M{"retweets": viewerID}})

		retweet := models.Post{
			ID:        bson.NewObjectID(),
			Author:    viewerID,
			Content:   "",
			RetweetOf: &postID,
			Likes:     []bson.ObjectID{},
			Retweets:  []bson.ObjectID{},
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		}
		services.Posts.InsertOne(ctx, retweet)

		if post.Author != viewerID {
			notification := models.Notification{
				ID:        bson.NewObjectID(),
				User:      post.Author,
				FromUser:  viewerID,
				Type:      "retweet",
				Post:      &postID,
				Read:      false,
				CreatedAt: time.Now(),
				UpdatedAt: time.Now(),
			}
			services.Notifications.InsertOne(ctx, notification)
			ws.H.EmitToUser(post.Author.Hex(), "notification", fiber.Map{"type": "retweet"})
		}
	}

	newCount := len(post.Retweets)
	if !alreadyRetweeted {
		newCount++
	}
	return c.JSON(fiber.Map{"retweeted": true, "retweets": newCount})
}

func UndoRetweet(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	postID, err := bson.ObjectIDFromHex(c.Params("id"))
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid post ID"})
	}
	viewerID := middleware.GetUserID(c)

	services.Posts.UpdateOne(ctx, bson.M{"_id": postID}, bson.M{"$pull": bson.M{"retweets": viewerID}})
	services.Posts.DeleteOne(ctx, bson.M{"author": viewerID, "retweetOf": postID})

	var post models.Post
	services.Posts.FindOne(ctx, bson.M{"_id": postID}).Decode(&post)
	return c.JSON(fiber.Map{"retweeted": false, "retweets": len(post.Retweets)})
}

func toPostResponse(ctx context.Context, post *models.Post, viewerID bson.ObjectID) fiber.Map {
	var author models.User
	if err := services.Users.FindOne(ctx, bson.M{"_id": post.Author}).Decode(&author); err != nil {
		author = models.User{ID: post.Author, Username: "unknown", Handle: "unknown"}
	}

	return fiber.Map{
		"id":         post.ID,
		"author":     toUserBrief(&author),
		"content":    post.Content,
		"images":     post.Images,
		"videos":     post.Videos,
		"thumbnails": post.Thumbnails,
		"replyTo":    post.ReplyTo,
		"retweetOf":  post.RetweetOf,
		"likes":      post.Likes,
		"retweets":   post.Retweets,
		"replyCount": post.ReplyCount,
		"viewCount":  post.ViewCount,
		"createdAt":  post.CreatedAt,
		"updatedAt":  post.UpdatedAt,
	}
}
