const express = require('express');
const Post = require('../models/Post');
const User = require('../models/User');
const auth = require('../middleware/auth');
const axios = require('axios');
const router = express.Router();

router.get('/', auth, async (req, res) => {
  try {
    const q = req.query.q || '';
    if (!q) return res.json({ posts: [], users: [], web: [] });

    const posts = await Post.find({ $text: { $search: q }, replyTo: null })
      .sort({ createdAt: -1 })
      .limit(20)
      .populate('author', 'username handle avatar');

    const users = await User.find({ $text: { $search: q } })
      .select('username handle avatar bio')
      .limit(10);

    let web = [];
    try {
      const searchUrl = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(q)}`;
      const resp = await axios.get(searchUrl, {
        headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
        timeout: 5000
      });
      const html = resp.data;
      const results = [];
      const resultRegex = /<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>([\s\S]*?)<\/a>/g;
      const snippetRegex = /<a[^>]*class="result__snippet"[^>]*>([\s\S]*?)<\/a>/g;
      let match;
      const links = [];
      const titles = [];
      const snippets = [];
      while ((match = resultRegex.exec(html)) !== null && results.length < 10) {
        links.push(match[1]);
        titles.push(match[2].replace(/<[^>]*>/g, '').trim());
      }
      while ((match = snippetRegex.exec(html)) !== null && snippets.length < 10) {
        snippets.push(match[1].replace(/<[^>]*>/g, '').trim());
      }
      for (let i = 0; i < Math.min(titles.length, 10); i++) {
        let url = links[i] || '';
        const uddg = url.match(/uddg=([^&]*)/);
        if (uddg) url = decodeURIComponent(uddg[1]);
        results.push({
          title: titles[i] || '',
          url: url,
          snippet: snippets[i] || ''
        });
      }
      web = results;
    } catch (e) {
      web = [];
    }

    res.json({ posts, users, web });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/web', auth, async (req, res) => {
  try {
    const q = req.query.q || '';
    if (!q) return res.json({ web: [] });
    const searchUrl = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(q)}`;
    const resp = await axios.get(searchUrl, {
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
      timeout: 5000
    });
    const html = resp.data;
    const results = [];
    const resultRegex = /<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>([\s\S]*?)<\/a>/g;
    const snippetRegex = /<a[^>]*class="result__snippet"[^>]*>([\s\S]*?)<\/a>/g;
    let match;
    const links = [];
    const titles = [];
    const snippets = [];
    while ((match = resultRegex.exec(html)) !== null && results.length < 10) {
      links.push(match[1]);
      titles.push(match[2].replace(/<[^>]*>/g, '').trim());
    }
    while ((match = snippetRegex.exec(html)) !== null && snippets.length < 10) {
      snippets.push(match[1].replace(/<[^>]*>/g, '').trim());
    }
    for (let i = 0; i < Math.min(titles.length, 10); i++) {
      let url = links[i] || '';
      const uddg = url.match(/uddg=([^&]*)/);
      if (uddg) url = decodeURIComponent(uddg[1]);
      results.push({
        title: titles[i] || '',
        url: url,
        snippet: snippets[i] || ''
      });
    }
    res.json({ web: results });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/trends', auth, async (req, res) => {
  try {
    const trends = await Post.aggregate([
      { $match: { createdAt: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) } } },
      { $project: { words: { $split: ['$content', ' '] } } },
      { $unwind: '$words' },
      { $match: { words: { $regex: /^#/, $options: 'i' } } },
      { $group: { _id: '$words', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 10 }
    ]);
    res.json({ trends: trends.map(t => ({ tag: t._id, count: t.count })) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
