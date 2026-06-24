const express = require('express');
const User = require('../models/User');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');
const router = express.Router();

router.get('/:id', auth, async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-password');
    if (!user) return res.status(404).json({ error: 'User not found' });
    const isFollowing = user.followers.includes(req.userId);
    res.json({
      id: user._id, username: user.username, handle: user.handle,
      avatar: user.avatar, bio: user.bio,
      followers: user.followers.length, following: user.following.length,
      isFollowing, createdAt: user.createdAt
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id', auth, async (req, res) => {
  try {
    const { username, bio, avatar } = req.body;
    const user = await User.findByIdAndUpdate(req.params.id, { username, bio, avatar }, { new: true }).select('-password');
    res.json(user);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/:id/follow', auth, async (req, res) => {
  try {
    if (req.params.id === req.userId) return res.status(400).json({ error: 'Cannot follow yourself' });
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    if (!user.followers.includes(req.userId)) {
      user.followers.push(req.userId);
      await user.save();
      await User.findByIdAndUpdate(req.userId, { $addToSet: { following: req.params.id } });
      await Notification.create({
        user: req.params.id, fromUser: req.userId, type: 'follow'
      });
      const io = req.app.get('io');
      if (io) io.to(req.params.id).emit('notification', { type: 'follow' });
    }
    res.json({ isFollowing: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id/follow', auth, async (req, res) => {
  try {
    await User.findByIdAndUpdate(req.params.id, { $pull: { followers: req.userId } });
    await User.findByIdAndUpdate(req.userId, { $pull: { following: req.params.id } });
    res.json({ isFollowing: false });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:id/followers', auth, async (req, res) => {
  try {
    const user = await User.findById(req.params.id).populate('followers', 'username handle avatar');
    res.json(user.followers);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:id/following', auth, async (req, res) => {
  try {
    const user = await User.findById(req.params.id).populate('following', 'username handle avatar');
    res.json(user.following);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
