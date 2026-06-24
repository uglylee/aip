const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const auth = require('../middleware/auth');
const router = express.Router();

const JWT_SECRET = 'xclone_secret_key_2024';

router.post('/register', async (req, res) => {
  try {
    const { username, handle, email, password } = req.body;
    const existEmail = await User.findOne({ email });
    if (existEmail) return res.status(400).json({ error: '该邮箱已被注册' });
    const existHandle = await User.findOne({ handle });
    if (existHandle) return res.status(400).json({ error: '该@用户名已被使用' });
    const existName = await User.findOne({ username });
    if (existName) return res.status(400).json({ error: '该用户名已被使用' });
    const hashed = await bcrypt.hash(password, 10);
    const user = await User.create({ username, handle, email, password: hashed });
    const token = jwt.sign({ userId: user._id }, JWT_SECRET, { expiresIn: '30d' });
    res.json({ token, user: { id: user._id, username: user.username, handle: user.handle, avatar: user.avatar } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({
      $or: [{ email: email }, { handle: email }, { username: email }]
    });
    if (!user) return res.status(400).json({ error: '用户不存在' });
    const valid = await bcrypt.compare(password, user.password);
    if (!valid) return res.status(400).json({ error: 'Invalid password' });
    const token = jwt.sign({ userId: user._id }, JWT_SECRET, { expiresIn: '30d' });
    res.json({
      token,
      user: {
        id: user._id, username: user.username, handle: user.handle,
        avatar: user.avatar, bio: user.bio,
        followers: user.followers.length, following: user.following.length
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/me', auth, async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('-password');
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({
      id: user._id, username: user.username, handle: user.handle,
      avatar: user.avatar, bio: user.bio,
      followers: user.followers.length, following: user.following.length,
      createdAt: user.createdAt
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
