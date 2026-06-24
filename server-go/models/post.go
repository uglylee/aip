package models

import (
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
)

type Post struct {
	ID         bson.ObjectID   `bson:"_id,omitempty" json:"id"`
	Author     bson.ObjectID   `bson:"author" json:"author"`
	Content    string          `bson:"content" json:"content"`
	Images     []string        `bson:"images,omitempty" json:"images"`
	Videos     []string        `bson:"videos,omitempty" json:"videos"`
	Thumbnails []string        `bson:"thumbnails,omitempty" json:"thumbnails"`
	ReplyTo    *bson.ObjectID  `bson:"replyTo,omitempty" json:"replyTo"`
	RetweetOf  *bson.ObjectID  `bson:"retweetOf,omitempty" json:"retweetOf"`
	Likes      []bson.ObjectID `bson:"likes,omitempty" json:"likes"`
	Retweets   []bson.ObjectID `bson:"retweets,omitempty" json:"retweets"`
	ReplyCount int             `bson:"replyCount" json:"replyCount"`
	ViewCount  int             `bson:"viewCount" json:"viewCount"`
	CreatedAt  time.Time       `bson:"createdAt" json:"createdAt"`
	UpdatedAt  time.Time       `bson:"updatedAt" json:"updatedAt"`
}
