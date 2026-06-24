package models

import (
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
)

type FriendRequest struct {
	ID        bson.ObjectID `bson:"_id,omitempty" json:"id"`
	From      bson.ObjectID `bson:"from" json:"from"`
	To        bson.ObjectID `bson:"to" json:"to"`
	Status    string        `bson:"status" json:"status"`
	CreatedAt time.Time     `bson:"createdAt" json:"createdAt"`
	UpdatedAt time.Time     `bson:"updatedAt" json:"updatedAt"`
}
