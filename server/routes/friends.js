const express = require('express');
const FriendRequest = require('../models/FriendRequest');
const User = require('../models/User');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');
const router = express.Router();

router.post('/:toUserId', auth, async (req, res) => {
  try {
    if (req.params.toUserId === req.userId) return res.status(400).json({ error: '不能添加自己' });
    const existing = await FriendRequest.findOne({ from: req.userId, to: req.params.toUserId });
    if (existing) return res.status(400).json({ error: '已经发送过请求' });
    const reverse = await FriendRequest.findOne({ from: req.params.toUserId, to: req.userId, status: 'pending' });
    if (reverse) {
      reverse.status = 'accepted';
      await reverse.save();
      return res.json({ status: 'accepted' });
    }
    const accepted = await FriendRequest.findOne({ from: req.params.toUserId, to: req.userId, status: 'accepted' });
    if (accepted) return res.status(400).json({ error: '已经是好友' });
    await FriendRequest.create({ from: req.userId, to: req.params.toUserId });
    await Notification.create({ user: req.params.toUserId, fromUser: req.userId, type: 'friend_request' });
    const io = req.app.get('io');
    if (io) io.to(req.params.toUserId).emit('notification', { type: 'friend_request' });
    res.json({ status: 'pending' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/status/:userId', auth, async (req, res) => {
  try {
    const outgoing = await FriendRequest.findOne({ from: req.userId, to: req.params.userId });
    const incoming = await FriendRequest.findOne({ from: req.params.userId, to: req.userId });
    let status = 'none';
    if (outgoing) status = outgoing.status;
    else if (incoming && incoming.status === 'pending') status = 'received';
    else if (incoming && incoming.status === 'accepted') status = 'accepted';
    const areFriends = (outgoing && outgoing.status === 'accepted') || (incoming && incoming.status === 'accepted');
    res.json({ status, areFriends });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/pending', auth, async (req, res) => {
  try {
    const requests = await FriendRequest.find({ to: req.userId, status: 'pending' })
      .populate('from', 'username handle avatar');
    res.json({ requests });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/friends', auth, async (req, res) => {
  try {
    const sent = await FriendRequest.find({ from: req.userId, status: 'accepted' }).populate('to', 'username handle avatar');
    const received = await FriendRequest.find({ to: req.userId, status: 'accepted' }).populate('from', 'username handle avatar');
    const friends = [...sent.map(r => r.to), ...received.map(r => r.from)];
    res.json({ friends });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:requestId/accept', auth, async (req, res) => {
  try {
    const request = await FriendRequest.findById(req.params.requestId);
    if (!request || request.to.toString() !== req.userId) return res.status(403).json({ error: 'Not authorized' });
    request.status = 'accepted';
    await request.save();
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:requestId/decline', auth, async (req, res) => {
  try {
    const request = await FriendRequest.findById(req.params.requestId);
    if (!request || request.to.toString() !== req.userId) return res.status(403).json({ error: 'Not authorized' });
    request.status = 'declined';
    await request.save();
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:userId', auth, async (req, res) => {
  try {
    await FriendRequest.deleteMany({
      $or: [
        { from: req.userId, to: req.params.userId },
        { from: req.params.userId, to: req.userId }
      ]
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
