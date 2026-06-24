package main

import (
	"fmt"
	"log"
	"net/http"

	"aip-server/config"
	"aip-server/handlers"
	"aip-server/middleware"
	"aip-server/services"
	"aip-server/ws"

	"github.com/gofiber/adaptor/v2"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/websocket/v2"
)

func main() {
	config.Load()
	services.InitDB()
	services.InitRedis()
	ws.NewHub()

	app := fiber.New(fiber.Config{
		AppName:      "AIP Server",
		BodyLimit:    int(config.C.MaxUploadSize),
		ServerHeader: "AIP-Server",
	})

	app.Use(func(c *fiber.Ctx) error {
		c.Set("Access-Control-Allow-Origin", "*")
		c.Set("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
		c.Set("Access-Control-Allow-Headers", "Content-Type,Authorization")
		if c.Method() == "OPTIONS" {
			return c.SendStatus(204)
		}
		return c.Next()
	})

	app.Static("/uploads", "./uploads")

	app.Get("/api/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok", "timestamp": nil})
	})

	auth := app.Group("/api/auth")
	auth.Post("/register", handlers.Register)
	auth.Post("/login", handlers.Login)
	auth.Get("/me", middleware.AuthRequired(), handlers.GetMe)

	users := app.Group("/api/users", middleware.AuthRequired())
	users.Get("/:id", handlers.GetUser)
	users.Put("/:id", handlers.UpdateUser)
	users.Post("/:id/follow", handlers.Follow)
	users.Delete("/:id/follow", handlers.Unfollow)
	users.Get("/:id/followers", handlers.GetFollowers)
	users.Get("/:id/following", handlers.GetFollowing)

	posts := app.Group("/api/posts", middleware.AuthRequired())
	posts.Post("/", handlers.CreatePost)
	posts.Get("/feed", handlers.GetFeed)
	posts.Get("/explore", handlers.GetExplore)
	posts.Get("/user/:userId", handlers.GetUserPosts)
	posts.Get("/:id", handlers.GetPost)
	posts.Delete("/:id", handlers.DeletePost)
	posts.Post("/:id/like", handlers.LikePost)
	posts.Delete("/:id/like", handlers.UnlikePost)
	posts.Post("/:id/retweet", handlers.RetweetPost)
	posts.Delete("/:id/retweet", handlers.UndoRetweet)

	messages := app.Group("/api/messages", middleware.AuthRequired())
	messages.Get("/conversations", handlers.GetConversations)
	messages.Get("/:userId", handlers.GetMessages)
	messages.Post("/:userId", handlers.SendMessage)

	groups := app.Group("/api/groups", middleware.AuthRequired())
	groups.Post("/", handlers.CreateGroup)
	groups.Get("/", handlers.ListGroups)
	groups.Get("/:id", handlers.GetGroup)
	groups.Post("/:id/members", handlers.AddMembers)
	groups.Delete("/:id/members/:memberId", handlers.RemoveMember)
	groups.Get("/:id/messages", handlers.GetGroupMessages)
	groups.Post("/:id/messages", handlers.SendGroupMessage)

	friends := app.Group("/api/friends", middleware.AuthRequired())
	friends.Post("/:toUserId", handlers.SendFriendRequest)
	friends.Get("/status/:userId", handlers.GetFriendStatus)
	friends.Get("/pending", handlers.GetPendingRequests)
	friends.Get("/friends", handlers.GetFriends)
	friends.Put("/:requestId/accept", handlers.AcceptFriend)
	friends.Put("/:requestId/decline", handlers.DeclineFriend)
	friends.Delete("/:userId", handlers.RemoveFriend)

	notifications := app.Group("/api/notifications", middleware.AuthRequired())
	notifications.Get("/", handlers.GetNotifications)
	notifications.Get("/unread", handlers.GetUnreadCount)
	notifications.Put("/:id/read", handlers.MarkRead)
	notifications.Put("/read-all", handlers.MarkAllRead)

	search := app.Group("/api/search", middleware.AuthRequired())
	search.Get("/", handlers.Search)
	search.Get("/web", handlers.WebSearch)
	search.Get("/trends", handlers.GetTrends)

	app.Post("/api/upload", middleware.AuthRequired(), handlers.Upload)

	app.Get("/api/ai/models", middleware.AuthRequired(), handlers.GetModels)

	app.Use("/ws", func(c *fiber.Ctx) error {
		if websocket.IsWebSocketUpgrade(c) {
			return c.Next()
		}
		return fiber.ErrUpgradeRequired
	})
	app.Get("/ws", websocket.New(ws.HandleConnection))

	fiberHandler := adaptor.FiberApp(app)

	httpMux := http.NewServeMux()

	httpMux.HandleFunc("/api/ai", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "GET" {
			fiberHandler.ServeHTTP(w, r)
			return
		}
		handlers.AIChatHTTP(w, r)
	})

	httpMux.Handle("/", fiberHandler)

	port := config.C.Port
	addr := fmt.Sprintf("0.0.0.0:%d", port)
	log.Printf("Server running on port %d", port)
	log.Fatal(http.ListenAndServe(addr, httpMux))
}
