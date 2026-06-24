package handlers

import (
	"bufio"
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
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
	paths := []string{
		"key.config.txt",
		".env",
	}
	for _, p := range paths {
		if data, err := os.ReadFile(p); err == nil {
			return strings.TrimSpace(string(data))
		}
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

type chanReader struct {
	ch  <-chan []byte
	buf []byte
}

func (r *chanReader) Read(p []byte) (int, error) {
	if len(r.buf) > 0 {
		n := copy(p, r.buf)
		r.buf = r.buf[n:]
		return n, nil
	}
	data, ok := <-r.ch
	if !ok {
		return 0, io.EOF
	}
	n := copy(p, data)
	if n < len(data) {
		r.buf = data[n:]
	}
	return n, nil
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

func AIChat(c *fiber.Ctx) error {
	var body struct {
		Messages       []struct {
			Role    string   `json:"role"`
			Content string   `json:"content"`
			Images  []string `json:"images"`
		} `json:"messages"`
		APIBase        string `json:"apiBase"`
		APIKey         string `json:"apiKey"`
		Model          string `json:"model"`
		EnableThinking any    `json:"enableThinking"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request"})
	}

	thinkingEnabled := false
	switch v := body.EnableThinking.(type) {
	case bool:
		thinkingEnabled = v
	case string:
		thinkingEnabled = v == "true"
	}

	aiURL := body.APIBase
	if aiURL == "" {
		aiURL = config.C.DefaultAIBase
	}
	key := body.APIKey
	if key == "" {
		key = getDefaultAPIKey()
	}
	modelName := body.Model
	if modelName == "" {
		modelName = config.C.DefaultAIModel
	}

	if !strings.Contains(aiURL, "/chat/completions") {
		aiURL = strings.TrimRight(aiURL, "/") + "/chat/completions"
	}
	if strings.HasPrefix(aiURL, "http://") && !strings.Contains(aiURL, "localhost") {
		aiURL = strings.Replace(aiURL, "http://", "https://", 1)
	}

	formattedMessages := []map[string]interface{}{}
	for _, m := range body.Messages {
		if len(m.Images) > 0 {
			content := []map[string]interface{}{}
			content = append(content, map[string]interface{}{"type": "text", "text": m.Content})
			for _, img := range m.Images {
				if b64 := imageToBase64(img); b64 != "" {
					content = append(content, map[string]interface{}{
						"type": "image_url",
						"image_url": map[string]string{"url": b64},
					})
				}
			}
			formattedMessages = append(formattedMessages, map[string]interface{}{
				"role":    m.Role,
				"content": content,
			})
		} else {
			formattedMessages = append(formattedMessages, map[string]interface{}{
				"role":    m.Role,
				"content": m.Content,
			})
		}
	}

	reqBody := map[string]interface{}{
		"model":    modelName,
		"messages": formattedMessages,
		"stream":   true,
	}

	isAgnes := strings.Contains(aiURL, "agnes")
	isDeepseek := strings.Contains(aiURL, "deepseek")

	if thinkingEnabled {
		if isAgnes {
			reqBody["chat_template_kwargs"] = map[string]bool{"enable_thinking": true}
		} else if isDeepseek {
			reqBody["think"] = true
		}
	}

	reqJSON, _ := json.Marshal(reqBody)
	req, err := http.NewRequest("POST", aiURL, bytes.NewReader(reqJSON))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	req.Header.Set("Authorization", "Bearer "+key)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 120 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	defer resp.Body.Close()

	c.Set("Content-Type", "text/event-stream")
	c.Set("Cache-Control", "no-cache")
	c.Set("Connection", "keep-alive")
	c.Set("X-Accel-Buffering", "no")

	ch := make(chan []byte, 256)

	go func() {
		defer close(ch)
		scanner := bufio.NewScanner(resp.Body)
		scanner.Buffer(make([]byte, 1024*1024), 1024*1024)

		sseBuffer := ""
		re := regexp.MustCompile(`"reasoning_content":"[^"]*"`)

		for scanner.Scan() {
			line := scanner.Text()

			if !thinkingEnabled {
				sseBuffer += line + "\n"
				lines := strings.Split(sseBuffer, "\n")
				sseBuffer = lines[len(lines)-1]
				for _, l := range lines[:len(lines)-1] {
					if strings.HasPrefix(l, "data: ") && strings.Contains(l, "reasoning_content") {
						filtered := re.ReplaceAllString(l, `"reasoning_content":""`)
						ch <- []byte(filtered + "\n")
					} else {
						ch <- []byte(l + "\n")
					}
				}
			} else {
				ch <- []byte(line + "\n")
			}
		}

		if !thinkingEnabled && sseBuffer != "" {
			if strings.Contains(sseBuffer, "reasoning_content") {
				filtered := re.ReplaceAllString(sseBuffer, `"reasoning_content":""`)
				ch <- []byte(filtered)
			} else {
				ch <- []byte(sseBuffer)
			}
		}
	}()

	c.Context().SetBodyStream(&chanReader{ch: ch}, -1)
	return nil
}
