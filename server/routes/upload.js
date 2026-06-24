const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const auth = require('../middleware/auth');
const router = express.Router();

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, path.join(__dirname, '../uploads')),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${Date.now()}-${Math.random().toString(36).substr(2, 9)}${ext}`);
  }
});
const upload = multer({ storage, limits: { fileSize: 50 * 1024 * 1024 } });

function isVideo(filename) {
  return /\.(mp4|mov|avi|mkv|webm|3gp)$/i.test(filename);
}

function extractThumbnail(videoPath, thumbPath) {
  return new Promise((resolve, reject) => {
    try {
      const ffmpegPath = require('ffmpeg-static');
      if (!ffmpegPath) return reject(new Error('ffmpeg-static not found'));
      const { execFile } = require('child_process');
      execFile(ffmpegPath, [
        '-i', videoPath,
        '-ss', '00:00:01',
        '-vframes', '1',
        '-vf', 'scale=480:-1',
        '-y', thumbPath
      ], { timeout: 15000 }, (err) => {
        if (err) reject(err);
        else resolve(thumbPath);
      });
    } catch (e) {
      reject(e);
    }
  });
}

router.post('/', auth, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
    const url = `/uploads/${req.file.filename}`;
    const result = { url };

    if (isVideo(req.file.filename)) {
      const videoPath = path.join(__dirname, '../uploads', req.file.filename);
      const thumbFilename = `thumb_${req.file.filename.replace(path.extname(req.file.filename), '.jpg')}`;
      const thumbPath = path.join(__dirname, '../uploads', thumbFilename);
      try {
        await extractThumbnail(videoPath, thumbPath);
        result.thumbnail = `/uploads/${thumbFilename}`;
        console.log('[Upload] Thumbnail created:', thumbFilename);
      } catch (e) {
        console.error('[Upload] Thumbnail error:', e.message);
      }
    }

    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
