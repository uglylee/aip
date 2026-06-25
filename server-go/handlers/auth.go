package handlers

import (
	"context"
	"time"

	"aip-server/middleware"
	"aip-server/models"
	"aip-server/services"

	"github.com/gofiber/fiber/v2"
	"go.mongodb.org/mongo-driver/v2/bson"
	"golang.org/x/crypto/bcrypt"
)

func Register(c *fiber.Ctx) error {
	var body struct {
		Username string `json:"username"`
		Handle   string `json:"handle"`
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "无效请求"})
	}

	if body.Email == "" || body.Password == "" {
		return c.Status(400).JSON(fiber.Map{"error": "邮箱和密码不能为空"})
	}
	if len(body.Password) < 6 {
		return c.Status(400).JSON(fiber.Map{"error": "密码至少6位"})
	}
	if body.Username == "" || body.Handle == "" {
		return c.Status(400).JSON(fiber.Map{"error": "用户名和@用户名不能为空"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var existing models.User
	if err := services.Users.FindOne(ctx, bson.M{"email": body.Email}).Decode(&existing); err == nil {
		return c.Status(400).JSON(fiber.Map{"error": "该邮箱已被注册"})
	}
	if err := services.Users.FindOne(ctx, bson.M{"handle": body.Handle}).Decode(&existing); err == nil {
		return c.Status(400).JSON(fiber.Map{"error": "该@用户名已被使用"})
	}
	if err := services.Users.FindOne(ctx, bson.M{"username": body.Username}).Decode(&existing); err == nil {
		return c.Status(400).JSON(fiber.Map{"error": "该用户名已被使用"})
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(body.Password), 12)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	user := models.User{
		ID:        bson.NewObjectID(),
		Username:  body.Username,
		Handle:    body.Handle,
		Email:     body.Email,
		Password:  string(hashed),
		Followers: []bson.ObjectID{},
		Following: []bson.ObjectID{},
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	if _, err := services.Users.InsertOne(ctx, user); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	token, err := middleware.GenerateToken(user.ID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{
		"token": token,
		"user": fiber.Map{
			"id":         user.ID,
			"username":   user.Username,
			"handle":     user.Handle,
			"avatar":     user.Avatar,
			"bio":        user.Bio,
			"followers":  len(user.Followers),
			"following":  len(user.Following),
		},
	})
}

func Login(c *fiber.Ctx) error {
	var body struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "无效请求"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var user models.User
	err := services.Users.FindOne(ctx, bson.M{
		"$or": []bson.M{
			{"email": body.Email},
			{"handle": body.Email},
			{"username": body.Email},
		},
	}).Decode(&user)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "用户不存在"})
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(body.Password)); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "密码错误"})
	}

	token, err := middleware.GenerateToken(user.ID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	return c.JSON(fiber.Map{
		"token": token,
		"user": fiber.Map{
			"id":         user.ID,
			"username":   user.Username,
			"handle":     user.Handle,
			"avatar":     user.Avatar,
			"bio":        user.Bio,
			"followers":  len(user.Followers),
			"following":  len(user.Following),
		},
	})
}

func GetMe(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	userID := middleware.GetUserID(c)
	var user models.User
	if err := services.Users.FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "用户不存在"})
	}

	return c.JSON(fiber.Map{
		"id":         user.ID,
		"username":   user.Username,
		"handle":     user.Handle,
		"avatar":     user.Avatar,
		"bio":        user.Bio,
		"followers":  len(user.Followers),
		"following":  len(user.Following),
		"createdAt":  user.CreatedAt,
	})
}

func ChangePassword(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var body struct {
		OldPassword string `json:"oldPassword"`
		NewPassword string `json:"newPassword"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "无效请求"})
	}

	if body.OldPassword == "" || body.NewPassword == "" {
		return c.Status(400).JSON(fiber.Map{"error": "旧密码和新密码不能为空"})
	}
	if len(body.NewPassword) < 6 {
		return c.Status(400).JSON(fiber.Map{"error": "新密码至少6位"})
	}

	userID := middleware.GetUserID(c)
	var user models.User
	if err := services.Users.FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "用户不存在"})
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(body.OldPassword)); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "旧密码错误"})
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(body.NewPassword), 12)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "密码加密失败"})
	}

	services.Users.UpdateOne(ctx, bson.M{"_id": userID}, bson.M{"$set": bson.M{"password": string(hashed)}})
	return c.JSON(fiber.Map{"success": true})
}

func lookupUserByID(ctx context.Context, id bson.ObjectID) (*models.User, error) {
	var user models.User
	err := services.Users.FindOne(ctx, bson.M{"_id": id}).Decode(&user)
	return &user, err
}

func toUserPublic(user *models.User, viewerID bson.ObjectID) fiber.Map {
	isFollowing := false
	for _, fid := range user.Followers {
		if fid == viewerID {
			isFollowing = true
			break
		}
	}
	return fiber.Map{
		"id":          user.ID,
		"username":    user.Username,
		"handle":      user.Handle,
		"avatar":      user.Avatar,
		"bio":         user.Bio,
		"followers":   len(user.Followers),
		"following":   len(user.Following),
		"isFollowing": isFollowing,
		"createdAt":   user.CreatedAt,
	}
}

func toUserBrief(user *models.User) fiber.Map {
	return fiber.Map{
		"id":       user.ID,
		"username": user.Username,
		"handle":   user.Handle,
		"avatar":   user.Avatar,
	}
}
