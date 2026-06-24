package models

import (
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
)

type Group struct {
	ID        bson.ObjectID   `bson:"_id,omitempty" json:"id"`
	Name      string          `bson:"name" json:"name"`
	Avatar    string          `bson:"avatar" json:"avatar"`
	Admin     bson.ObjectID   `bson:"admin" json:"admin"`
	Members   []bson.ObjectID `bson:"members,omitempty" json:"members"`
	CreatedAt time.Time       `bson:"createdAt" json:"createdAt"`
	UpdatedAt time.Time       `bson:"updatedAt" json:"updatedAt"`
}
