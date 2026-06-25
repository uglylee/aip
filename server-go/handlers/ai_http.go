package handlers

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"

	"aip-server/config"

	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/v2/bson"
)

func authHTTP(r *http.Request) (bson.ObjectID, bool) {
	auth := r.Header.Get("Authorization")
	if auth == "" {
		return bson.NilObjectID, false
	}
	tokenStr := strings.TrimPrefix(auth, "Bearer ")
	claims := &jwt.RegisteredClaims{}
	token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
		return []byte(config.C.JWTSecret), nil
	})
	if err != nil || !token.Valid {
		return bson.NilObjectID, false
	}
	var userID bson.ObjectID
	if err := userID.UnmarshalText([]byte(claims.Subject)); err != nil {
		userID, _ = bson.ObjectIDFromHex(claims.Subject)
	}
	return userID, true
}

func AIChatHTTP(w http.ResponseWriter, r *http.Request) {
	userID, ok := authHTTP(r)
	_ = userID
	if !ok {
		http.Error(w, `{"error":"未提供有效令牌"}`, 401)
		return
	}

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
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, `{"error":"无效请求"}`, 400)
		return
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
		http.Error(w, `{"error":"`+err.Error()+`"}`, 500)
		return
	}
	req.Header.Set("Authorization", "Bearer "+key)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 120 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, 500)
		return
	}
	defer resp.Body.Close()

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")
	w.Header().Set("Transfer-Encoding", "chunked")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, `{"error":"不支持流式传输"}`, 500)
		return
	}

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
					fmt.Fprintln(w, filtered)
				} else {
					fmt.Fprintln(w, l)
				}
				flusher.Flush()
			}
		} else {
			fmt.Fprintln(w, line)
			flusher.Flush()
		}
	}

	if !thinkingEnabled && sseBuffer != "" {
		if strings.Contains(sseBuffer, "reasoning_content") {
			filtered := re.ReplaceAllString(sseBuffer, `"reasoning_content":""`)
			fmt.Fprint(w, filtered)
		} else {
			fmt.Fprint(w, sseBuffer)
		}
		flusher.Flush()
	}
}
