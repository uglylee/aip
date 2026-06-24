package handlers

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"time"

	"aip-server/middleware"
	"aip-server/models"
	"aip-server/services"

	"github.com/gofiber/fiber/v2"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

func Search(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	q := c.Query("q", "")
	if q == "" {
		return c.JSON(fiber.Map{"posts": []interface{}{}, "users": []interface{}{}, "web": []interface{}{}})
	}

	viewerID := middleware.GetUserID(c)

	postOpts := options.Find().
		SetSort(bson.D{{Key: "createdAt", Value: -1}}).
		SetLimit(20)
	postCursor, _ := services.Posts.Find(ctx, bson.M{
		"$text": bson.M{"$search": q},
		"replyTo": nil,
	}, postOpts)
	var posts []models.Post
	postCursor.All(ctx, &posts)

	userOpts := options.Find().SetLimit(10)
	userCursor, _ := services.Users.Find(ctx, bson.M{
		"$text": bson.M{"$search": q},
	}, userOpts)
	var users []models.User
	userCursor.All(ctx, &users)

	postsJSON := make([]fiber.Map, len(posts))
	for i, p := range posts {
		postsJSON[i] = toPostResponse(ctx, &p, viewerID)
	}
	usersJSON := make([]fiber.Map, len(users))
	for i, u := range users {
		usersJSON[i] = toUserBrief(&u)
	}

	web := webSearch(q)

	return c.JSON(fiber.Map{
		"posts": postsJSON,
		"users": usersJSON,
		"web":   web,
	})
}

func WebSearch(c *fiber.Ctx) error {
	q := c.Query("q", "")
	if q == "" {
		return c.JSON(fiber.Map{"web": []interface{}{}})
	}
	return c.JSON(fiber.Map{"web": webSearch(q)})
}

func GetTrends(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	sevenDaysAgo := time.Now().Add(-7 * 24 * time.Hour)
	pipeline := []bson.M{
		{"$match": bson.M{"createdAt": bson.M{"$gte": sevenDaysAgo}}},
		{"$project": bson.M{"words": bson.M{"$split": []interface{}{"$content", " "}}}},
		{"$unwind": "$words"},
		{"$match": bson.M{"words": bson.M{"$regex": "^#", "$options": "i"}}},
		{"$group": bson.M{"_id": "$words", "count": bson.M{"$sum": 1}}},
		{"$sort": bson.M{"count": -1}},
		{"$limit": 10},
	}

	cursor, err := services.Posts.Aggregate(ctx, pipeline)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	type Trend struct {
		ID    string `bson:"_id"`
		Count int    `bson:"count"`
	}
	var trends []Trend
	cursor.All(ctx, &trends)

	result := make([]fiber.Map, len(trends))
	for i, t := range trends {
		result[i] = fiber.Map{"tag": t.ID, "count": t.Count}
	}

	return c.JSON(fiber.Map{"trends": result})
}

var (
	resultRegex  = regexp.MustCompile(`<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>([\s\S]*?)</a>`)
	snippetRegex = regexp.MustCompile(`<a[^>]*class="result__snippet"[^>]*>([\s\S]*?)</a>`)
	tagRegex     = regexp.MustCompile(`<[^>]*>`)
)

func webSearch(query string) []fiber.Map {
	searchURL := fmt.Sprintf("https://html.duckduckgo.com/html/?q=%s", query)

	client := &http.Client{Timeout: 5 * time.Second}
	req, _ := http.NewRequest("GET", searchURL, nil)
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

	resp, err := client.Do(req)
	if err != nil {
		return []fiber.Map{}
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	html := string(body)

	linkMatches := resultRegex.FindAllStringSubmatch(html, 10)
	titleMatches := resultRegex.FindAllStringSubmatch(html, 10)
	snippetMatches := snippetRegex.FindAllStringSubmatch(html, 10)

	results := []fiber.Map{}
	for i := 0; i < len(titleMatches) && i < 10; i++ {
		title := tagRegex.ReplaceAllString(titleMatches[i][2], "")
		snippet := ""
		if i < len(snippetMatches) {
			snippet = tagRegex.ReplaceAllString(snippetMatches[i][1], "")
		}
		url := ""
		if i < len(linkMatches) {
			url = linkMatches[i][1]
			if uddg := regexp.MustCompile(`uddg=([^&]*)`).FindStringSubmatch(url); len(uddg) > 1 {
				url = uddg[1]
			}
		}
		results = append(results, fiber.Map{
			"title":   title,
			"url":     url,
			"snippet": snippet,
		})
	}

	return results
}
