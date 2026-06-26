package handlers

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"aip-server/config"

	"github.com/gofiber/fiber/v2"
)

var mimeMap = map[string]string{
	".jpg":  "image/jpeg",
	".jpeg": "image/jpeg",
	".png":  "image/png",
	".gif":  "image/gif",
	".webp": "image/webp",
}

func getDefaultAPIKey() string {
	if config.C.DefaultAIKey != "" {
		return config.C.DefaultAIKey
	}
	if data, err := os.ReadFile("key.config.txt"); err == nil {
		return strings.TrimSpace(string(data))
	}
	return ""
}

func imageToBase64(imgPath string) string {
	if strings.HasPrefix(imgPath, "http") || strings.HasPrefix(imgPath, "data:") {
		return imgPath
	}
	searchPaths := []string{
		filepath.Join(".", imgPath),
		filepath.Join("uploads", filepath.Base(imgPath)),
		filepath.Join(config.C.UploadDir, filepath.Base(imgPath)),
	}
	var data []byte
	var localPath string
	for _, p := range searchPaths {
		if d, err := os.ReadFile(p); err == nil {
			data = d
			localPath = p
			break
		}
	}
	if data == nil {
		return imgPath
	}
	if float64(len(data))/1024 > 500 {
		return ""
	}
	ext := strings.ToLower(filepath.Ext(localPath))
	mime := mimeMap[ext]
	if mime == "" {
		mime = "image/jpeg"
	}
	return fmt.Sprintf("data:%s;base64,%s", mime, base64.StdEncoding.EncodeToString(data))
}

func GetDefaultProvider(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"id":      strings.ToLower(config.C.DefaultAIName),
		"name":    config.C.DefaultAIName,
		"apiBase": config.C.DefaultAIBase,
		"apiKey":  config.C.DefaultAIKey,
		"model":   config.C.DefaultAIModel,
	})
}

func GetModels(c *fiber.Ctx) error {
	apiBase := c.Query("apiBase", config.C.DefaultAIBase)
	apiKey := c.Query("apiKey", getDefaultAPIKey())

	baseURL := strings.TrimRight(apiBase, "/chat/completions")
	baseURL = strings.TrimRight(baseURL, "/")

	req, err := http.NewRequest("GET", baseURL+"/models", nil)
	if err != nil {
		return c.JSON(fiber.Map{"models": []interface{}{}, "error": err.Error()})
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return c.JSON(fiber.Map{"models": []interface{}{}, "error": err.Error()})
	}
	defer resp.Body.Close()

	var result struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	json.NewDecoder(resp.Body).Decode(&result)

	models := make([]string, len(result.Data))
	for i, m := range result.Data {
		models[i] = m.ID
	}

	return c.JSON(fiber.Map{"models": models})
}
