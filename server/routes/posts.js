const express = require('express');
const Post = require('../models/Post');
const User = require('../models/User');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');
const router = express.Router();

router.post('/', auth, async (req, res) => {
  try {
    const { content, replyTo, images, videos, thumbnails } = req.body;
    const post = await Post.create({ author: req.userId, content, replyTo: replyTo || null, images: images || [], videos: videos || [], thumbnails: thumbnails || [] });
    if (replyTo) {
      await Post.findByIdAndUpdate(replyTo, { $inc: { replyCount: 1 } });
      const original = await Post.findById(replyTo);
      if (original && original.author.toString() !== req.userId) {
        await Notification.create({ user: original.author, fromUser: req.userId, type: 'reply', post: post._id });
        const io = req.app.get('io');
        if (io) io.to(original.author.toString()).emit('notification', { type: 'reply' });
      }
    }
    await post.populate('author', 'username handle avatar');
    res.json(post);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/feed', auth, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const user = await User.findById(req.userId);
    const followingIds = [...user.following, req.userId];
    const posts = await Post.find({ author: { $in: followingIds }, replyTo: null, retweetOf: null })
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .populate('author', 'username handle avatar');
    res.json({ posts });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/explore', auth, async (req, res) => {
  try {
    const posts = await Post.find({ replyTo: null, retweetOf: null })
      .sort({ viewCount: -1, createdAt: -1 })
      .limit(50)
      .populate('author', 'username handle avatar');
    res.json({ posts });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/user/:userId', auth, async (req, res) => {
  try {
    const posts = await Post.find({ author: req.params.userId, retweetOf: null })
      .sort({ createdAt: -1 })
      .populate('author', 'username handle avatar');
    res.json({ posts });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:id', auth, async (req, res) => {
  try {
    const post = await Post.findByIdAndUpdate(req.params.id, { $inc: { viewCount: 1 } }, { new: true })
      .populate('author', 'username handle avatar');
    if (!post) return res.status(404).json({ error: 'Post not found' });
    const replies = await Post.find({ replyTo: post._id })
      .sort({ createdAt: -1 })
      .populate('author', 'username handle avatar');
    res.json({ post, replies });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id', auth, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post || post.author.toString() !== req.userId) return res.status(403).json({ error: 'Not authorized' });
    await Post.findByIdAndDelete(req.params.id);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/:id/like', auth, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ error: 'Post not found' });
    if (!post.likes.includes(req.userId)) {
      post.likes.push(req.userId);
      await post.save();
      if (post.author.toString() !== req.userId) {
        await Notification.create({ user: post.author, fromUser: req.userId, type: 'like', post: post._id });
        const io = req.app.get('io');
        if (io) io.to(post.author.toString()).emit('notification', { type: 'like' });
      }
    }
    res.json({ liked: true, likes: post.likes.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id/like', auth, async (req, res) => {
  try {
    const post = await Post.findByIdAndUpdate(req.params.id, { $pull: { likes: req.userId } }, { new: true });
    res.json({ liked: false, likes: post.likes.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/:id/retweet', auth, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ error: 'Post not found' });
    if (!post.retweets.includes(req.userId)) {
      post.retweets.push(req.userId);
      await post.save();
      await Post.create({ author: req.userId, content: '', retweetOf: post._id });
      if (post.author.toString() !== req.userId) {
        await Notification.create({ user: post.author, fromUser: req.userId, type: 'retweet', post: post._id });
        const io = req.app.get('io');
        if (io) io.to(post.author.toString()).emit('notification', { type: 'retweet' });
      }
    }
    res.json({ retweeted: true, retweets: post.retweets.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id/retweet', auth, async (req, res) => {
  try {
    const post = await Post.findByIdAndUpdate(req.params.id, { $pull: { retweets: req.userId } }, { new: true });
    await Post.deleteOne({ author: req.userId, retweetOf: req.params.id });
    res.json({ retweeted: false, retweets: post.retweets.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
