package services

import (
	"context"
	"log"
	"time"

	"aip-server/config"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

var (
	Users          *mongo.Collection
	Posts          *mongo.Collection
	Messages       *mongo.Collection
	Groups         *mongo.Collection
	FriendRequests *mongo.Collection
	Notifications  *mongo.Collection
)

func InitDB() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(options.Client().ApplyURI(config.C.MongoURI))
	if err != nil {
		log.Fatal("MongoDB connect error:", err)
	}

	if err := client.Ping(ctx, nil); err != nil {
		log.Fatal("MongoDB ping error:", err)
	}
	log.Println("MongoDB connected")

	db := client.Database(config.C.DBName)
	Users = db.Collection("users")
	Posts = db.Collection("posts")
	Messages = db.Collection("messages")
	Groups = db.Collection("groups")
	FriendRequests = db.Collection("friendrequests")
	Notifications = db.Collection("notifications")

	createIndexes(ctx)
}

func createIndexes(ctx context.Context) {
	Users.Indexes().CreateMany(ctx, []mongo.IndexModel{
		{Keys: bson.D{{Key: "handle", Value: "text"}, {Key: "username", Value: "text"}}},
	})

	Posts.Indexes().CreateMany(ctx, []mongo.IndexModel{
		{Keys: bson.D{{Key: "content", Value: "text"}}},
		{Keys: bson.D{{Key: "createdAt", Value: -1}}},
	})

	Messages.Indexes().CreateMany(ctx, []mongo.IndexModel{
		{Keys: bson.D{{Key: "sender", Value: 1}, {Key: "receiver", Value: 1}}},
		{Keys: bson.D{{Key: "groupId", Value: 1}, {Key: "createdAt", Value: -1}}},
		{Keys: bson.D{{Key: "createdAt", Value: -1}}},
	})

	FriendRequests.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "from", Value: 1}, {Key: "to", Value: 1}},
		Options: options.Index().SetUnique(true),
	})

	Notifications.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys: bson.D{{Key: "user", Value: 1}, {Key: "createdAt", Value: -1}},
	})
}
