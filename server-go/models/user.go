package models

import (
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
)

type User struct {
	ID        bson.ObjectID   `bson:"_id,omitempty" json:"id"`
	Username  string          `bson:"username" json:"username"`
	Handle    string          `bson:"handle" json:"handle"`
	Email     string          `bson:"email" json:"email"`
	Password  string          `bson:"password" json:"-"`
	Avatar    string          `bson:"avatar" json:"avatar"`
	Bio       string          `bson:"bio" json:"bio"`
	Followers []bson.ObjectID `bson:"followers,omitempty" json:"followers"`
	Following []bson.ObjectID `bson:"following,omitempty" json:"following"`
	Bookmarks []bson.ObjectID `bson:"bookmarks,omitempty" json:"bookmarks"`
	CreatedAt time.Time       `bson:"createdAt" json:"createdAt"`
	UpdatedAt time.Time       `bson:"updatedAt" json:"updatedAt"`
}

type UserPublic struct {
	ID        bson.ObjectID `bson:"_id,omitempty" json:"id"`
	Username  string        `bson:"username" json:"username"`
	Handle    string        `bson:"handle" json:"handle"`
	Avatar    string        `bson:"avatar" json:"avatar"`
	Bio       string        `bson:"bio" json:"bio"`
	FollowerCount int      `bson:"-" json:"followers"`
	FollowingCount int     `bson:"-" json:"following"`
	IsFollowing bool        `bson:"-" json:"isFollowing,omitempty"`
	CreatedAt time.Time    `bson:"createdAt" json:"createdAt"`
}

type UserLoginResponse struct {
	ID        bson.ObjectID `json:"id"`
	Username  string        `json:"username"`
	Handle    string        `json:"handle"`
	Avatar    string        `json:"avatar"`
	Bio       string        `json:"bio"`
	FollowerCount int      `json:"followers"`
	FollowingCount int     `json:"following"`
}
