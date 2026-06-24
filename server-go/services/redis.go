package services

import (
	"context"
	"log"
	"time"

	"aip-server/config"

	"github.com/redis/go-redis/v9"
)

var RDB *redis.Client

func InitRedis() {
	RDB = redis.NewClient(&redis.Options{
		Addr:     config.C.RedisAddr,
		Password: config.C.RedisPassword,
		DB:       config.C.RedisDB,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := RDB.Ping(ctx).Err(); err != nil {
		log.Fatal("Redis connect error:", err)
	}
	log.Println("Redis connected")
}
