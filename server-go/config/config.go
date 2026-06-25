package config

import (
	"log"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	Port           int
	MongoURI       string
	DBName         string
	RedisAddr      string
	RedisPassword  string
	RedisDB        int
	JWTSecret      string
	JWTExpiryHours int
	DefaultAIBase  string
	DefaultAIModel string
	UploadDir      string
	MaxUploadSize  int64
}

var C Config

func Load() {
	godotenv.Load()

	port, _ := strconv.Atoi(getEnv("PORT", "8005"))
	redisDB, _ := strconv.Atoi(getEnv("REDIS_DB", "0"))
	maxUpload, _ := strconv.ParseInt(getEnv("MAX_UPLOAD_SIZE", "52428800"), 10, 64)

	C = Config{
		Port:           port,
		MongoURI:       getEnv("MONGO_URI", "mongodb://127.0.0.1:27018/aip"),
		DBName:         getEnv("DB_NAME", "aip"),
		RedisAddr:      getEnv("REDIS_ADDR", "127.0.0.1:6380"),
		RedisPassword:  getEnv("REDIS_PASSWORD", ""),
		RedisDB:        redisDB,
		JWTSecret:      getEnv("JWT_SECRET", ""),
		JWTExpiryHours: 30 * 24,
		DefaultAIBase:  getEnv("DEFAULT_AI_BASE", "https://apihub.agnes-ai.com/v1/chat/completions"),
		DefaultAIModel: getEnv("DEFAULT_AI_MODEL", "agnes-2.0-flash"),
		UploadDir:      getEnv("UPLOAD_DIR", "./uploads"),
		MaxUploadSize:  maxUpload,
	}

	if C.JWTSecret == "" {
		log.Fatal("JWT_SECRET environment variable is required")
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
