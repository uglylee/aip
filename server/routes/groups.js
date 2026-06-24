const express = require('express');
const Group = require('../models/Group');
const Message = require('../models/Message');
const User = require('../models/User');
const auth = require('../middleware/auth');
const router = express.Router();

router.post('/', auth, async (req, res) => {
  try {
    const { name, memberIds } = req.body;
    const allMembers = [...new Set([req.userId, ...(memberIds || [])])];
    const group = await Group.create({ name, admin: req.userId, members: allMembers });
    await group.populate('members', 'username handle avatar');
    res.json(group);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/', auth, async (req, res) => {
  try {
    const groups = await Group.find({ members: req.userId })
      .populate('members', 'username handle avatar')
      .sort({ updatedAt: -1 });
    const result = await Promise.all(groups.map(async (g) => {
      const lastMsg = await Message.findOne({ groupId: g._id }).sort({ createdAt: -1 });
      return { group: g, lastMessage: lastMsg };
    }));
    res.json({ groups: result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:id', auth, async (req, res) => {
  try {
    const group = await Group.findById(req.params.id).populate('members', 'username handle avatar');
    if (!group) return res.status(404).json({ error: 'Group not found' });
    res.json(group);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/:id/members', auth, async (req, res) => {
  try {
    const { userIds } = req.body;
    const group = await Group.findById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    for (const uid of userIds) {
      if (!group.members.includes(uid)) group.members.push(uid);
    }
    await group.save();
    await group.populate('members', 'username handle avatar');
    res.json(group);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id/members/:memberId', auth, async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    group.members = group.members.filter(m => m.toString() !== req.params.memberId);
    await group.save();
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:id/messages', auth, async (req, res) => {
  try {
    const messages = await Message.find({ groupId: req.params.id }).sort({ createdAt: 1 });
    res.json({ messages });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/:id/messages', auth, async (req, res) => {
  try {
    const { content } = req.body;
    const message = await Message.create({
      sender: req.userId,
      groupId: req.params.id,
      content
    });
    const io = req.app.get('io');
    if (io) io.to(`group:${req.params.id}`).emit('group_message', {
      _id: message._id,
      sender: req.userId,
      groupId: req.params.id,
      content,
      createdAt: message.createdAt
    });
    res.json(message);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
