const express = require('express');
const Message = require('../models/Message');
const User = require('../models/User');
const auth = require('../middleware/auth');
const router = express.Router();

router.get('/conversations', auth, async (req, res) => {
  try {
    const conversations = await Message.aggregate([
      { $match: { $or: [{ sender: req.userId }, { receiver: req.userId }] } },
      { $sort: { createdAt: -1 } },
      {
        $group: {
          _id: {
            $cond: [{ $eq: ['$sender', req.userId] }, '$receiver', '$sender']
          },
          lastMessage: { $first: '$$ROOT' },
          unread: {
            $sum: {
              $cond: [{ $and: [{ $eq: ['$receiver', req.userId] }, { $eq: ['$read', false] }] }, 1, 0]
            }
          }
        }
      },
      { $sort: { 'lastMessage.createdAt': -1 } }
    ]);
    const userIds = conversations.map(c => c._id);
    const users = await User.find({ _id: { $in: userIds } }).select('username handle avatar');
    const userMap = {};
    users.forEach(u => { userMap[u._id.toString()] = u; });
    const result = conversations.map(c => ({
      user: userMap[c._id.toString()],
      lastMessage: c.lastMessage,
      unread: c.unread
    }));
    res.json({ conversations: result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:userId', auth, async (req, res) => {
  try {
    const messages = await Message.find({
      $or: [
        { sender: req.userId, receiver: req.params.userId },
        { sender: req.params.userId, receiver: req.userId }
      ]
    }).sort({ createdAt: 1 });
    await Message.updateMany(
      { sender: req.params.userId, receiver: req.userId, read: false },
      { read: true }
    );
    res.json({ messages });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/:userId', auth, async (req, res) => {
  try {
    const message = await Message.create({
      sender: req.userId,
      receiver: req.params.userId,
      content: req.body.content
    });
    const io = req.app.get('io');
    if (io) {
      io.to(req.params.userId).emit('message', {
        _id: message._id,
        sender: req.userId,
        receiver: req.params.userId,
        content: message.content,
        createdAt: message.createdAt
      });
    }
    res.json(message);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
