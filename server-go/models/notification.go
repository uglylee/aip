package models

import (
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
)

type Notification struct {
	ID        bson.ObjectID  `bson:"_id,omitempty" json:"id"`
	User      bson.ObjectID  `bson:"user" json:"user"`
	FromUser  bson.ObjectID  `bson:"fromUser" json:"fromUser"`
	Type      string         `bson:"type" json:"type"`
	Post      *bson.ObjectID `bson:"post,omitempty" json:"post"`
	Read      bool           `bson:"read" json:"read"`
	CreatedAt time.Time      `bson:"createdAt" json:"createdAt"`
	UpdatedAt time.Time      `bson:"updatedAt" json:"updatedAt"`
}
