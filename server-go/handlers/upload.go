package handlers

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"aip-server/config"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

var videoExtRegex = regexp.MustCompile(`(?i)\.(mp4|mov|avi|mkv|webm|3gp)$`)

func getUploadDir() string {
	return config.C.UploadDir
}

func findFFmpeg() string {
	candidates := []string{
		os.Getenv("FFMPEG_PATH"),
		"./ffmpeg.exe",
		"ffmpeg",
	}
	for _, c := range candidates {
		if c == "" {
			continue
		}
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return "ffmpeg"
}

func Upload(c *fiber.Ctx) error {
	file, err := c.FormFile("file")
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "No file uploaded"})
	}

	ext := filepath.Ext(file.Filename)
	randStr := strings.ReplaceAll(uuid.New().String()[:8], "-", "")
	filename := fmt.Sprintf("%d-%s%s", time.Now().UnixMilli(), randStr, ext)
	uploadDir := getUploadDir()
	os.MkdirAll(uploadDir, 0755)
	uploadPath := filepath.Join(uploadDir, filename)

	if err := c.SaveFile(file, uploadPath); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	result := fiber.Map{
		"url": "/uploads/" + filename,
	}

	if videoExtRegex.MatchString(filename) {
		thumbFilename := "thumb_" + strings.TrimSuffix(filename, ext) + ".jpg"
		thumbPath := filepath.Join(uploadDir, thumbFilename)
		if err := extractThumbnail(uploadPath, thumbPath); err == nil {
			result["thumbnail"] = "/uploads/" + thumbFilename
		}
	}

	return c.JSON(result)
}

func extractThumbnail(videoPath, thumbPath string) error {
	ffmpegPath := findFFmpeg()

	cmd := exec.Command(ffmpegPath,
		"-i", videoPath,
		"-ss", "00:00:01",
		"-vframes", "1",
		"-vf", "scale=480:-1",
		"-y", thumbPath,
	)

	done := make(chan error, 1)
	go func() {
		done <- cmd.Run()
	}()

	select {
	case err := <-done:
		return err
	case <-time.After(15 * time.Second):
		cmd.Process.Kill()
		return fmt.Errorf("ffmpeg timeout")
	}
}

var appVersion = "1.0.40"
var appBuildTime = ""

func CheckUpdate(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"version":    appVersion,
		"buildTime":  appBuildTime,
		"apkUrl":     "/uploads/aip-debug.apk",
		"minVersion": "1.0.0",
		"forceUpdate": false,
		"changelog":  "Latest version",
	})
}

func DownloadPage(c *fiber.Ctx) error {
	html := fmt.Sprintf(`<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AIP Download</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, sans-serif; background: #f5f5f5; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
.card { background: white; border-radius: 16px; padding: 40px 32px; text-align: center; max-width: 360px; width: 90%%; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
.icon { width: 80px; height: 80px; background: linear-gradient(135deg, #1DA1F2, #0d8ecf); border-radius: 20px; margin: 0 auto 20px; display: flex; align-items: center; justify-content: center; }
.icon span { color: white; font-size: 36px; font-weight: bold; }
h1 { font-size: 22px; margin-bottom: 8px; }
.desc { color: #666; font-size: 14px; margin-bottom: 24px; }
.btn { display: block; width: 100%%; padding: 14px; background: #1DA1F2; color: white; text-decoration: none; border-radius: 12px; font-size: 16px; font-weight: bold; }
.btn:active { background: #0d8ecf; }
.info { margin-top: 16px; color: #999; font-size: 12px; }
.ver { color: #1DA1F2; font-weight: bold; }
</style>
</head>
<body>
<div class="card">
<div class="icon"><span>A</span></div>
<h1>AIP - AI Chat</h1>
<p class="desc">AI Chat + Social App</p>
<p class="ver">v%s</p>
<a class="btn" href="/uploads/aip-debug.apk?v=%s" download="aip.apk">Download APK</a>
<p class="info">Tap download, then install<br>For updates, reopen this page</p>
</div>
</body>
</html>`, appVersion, appVersion)
	c.Set("Content-Type", "text/html; charset=utf-8")
	return c.SendString(html)
}