package models

import (
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
)

type Message struct {
	ID        bson.ObjectID  `bson:"_id,omitempty" json:"id"`
	Sender    bson.ObjectID  `bson:"sender" json:"sender"`
	Receiver  *bson.ObjectID `bson:"receiver,omitempty" json:"receiver"`
	GroupID   *bson.ObjectID `bson:"groupId,omitempty" json:"groupId"`
	Content   string         `bson:"content" json:"content"`
	Read      bool           `bson:"read" json:"read"`
	CreatedAt time.Time      `bson:"createdAt" json:"createdAt"`
	UpdatedAt time.Time      `bson:"updatedAt" json:"updatedAt"`
}
