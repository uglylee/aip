package handlers

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

var videoExtRegex = regexp.MustCompile(`(?i)\.(mp4|mov|avi|mkv|webm|3gp)$`)

func getUploadDir() string {
	return "./uploads"
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
