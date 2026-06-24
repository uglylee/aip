const express = require('express');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const auth = require('../middleware/auth');
const router = express.Router();

const DEFAULT_API_BASE = 'https://apihub.agnes-ai.com/v1/chat/completions';
const DEFAULT_MODEL = 'agnes-2.0-flash';

function getDefaultApiKey() {
  try {
    const configPath = path.join(__dirname, '../../key.config.txt');
    if (fs.existsSync(configPath)) {
      return fs.readFileSync(configPath, 'utf-8').trim();
    }
  } catch (e) {}
  return '';
}

function imageToBase64(imgPath) {
  if (imgPath.startsWith('http') || imgPath.startsWith('data:')) return imgPath;
  const localPath = path.join(__dirname, '..', imgPath);
  if (!fs.existsSync(localPath)) return imgPath;
  const ext = path.extname(localPath).toLowerCase();
  const mimeMap = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.gif': 'image/gif', '.webp': 'image/webp' };
  const mime = mimeMap[ext] || 'image/jpeg';
  const data = fs.readFileSync(localPath);
  const sizeKB = data.length / 1024;
  if (sizeKB > 500) {
    console.log(`[AI] Image too large (${Math.round(sizeKB)}KB), skipping`);
    return null;
  }
  const base64 = data.toString('base64');
  return `data:${mime};base64,${base64}`;
}

router.get('/models', auth, async (req, res) => {
  try {
    const { apiBase, apiKey } = req.query;
    const baseUrl = (apiBase || DEFAULT_API_BASE).replace(/\/chat\/completions.*$/, '');
    const key = apiKey || getDefaultApiKey();
    console.log('[Models] baseUrl:', baseUrl, 'key:', key ? key.substring(0, 10) + '...' : 'empty');
    const response = await axios.get(`${baseUrl}/models`, {
      headers: { 'Authorization': `Bearer ${key}` },
      timeout: 15000
    });
    const models = response.data?.data?.map(m => m.id) || [];
    console.log('[Models] found:', models.length);
    res.json({ models });
  } catch (err) {
    console.error('[Models] error:', err.message);
    res.json({ models: [], error: err.message });
  }
});

router.post('/', auth, async (req, res) => {
  try {
    const { messages, apiBase, apiKey, model, enableThinking } = req.body;
    const thinkingEnabled = enableThinking === true || enableThinking === 'true';
    console.log('[AI Stream] enableThinking:', enableThinking, '-> parsed:', thinkingEnabled);
    let url = apiBase || DEFAULT_API_BASE;
    const key = apiKey || getDefaultApiKey();
    const modelName = model || DEFAULT_MODEL;

    if (!url.includes('/chat/completions')) {
      url = url.replace(/\/+$/, '') + '/chat/completions';
    }
    if (url.startsWith('http://') && !url.includes('localhost')) {
      url = url.replace('http://', 'https://');
    }

    const formattedMessages = (messages || []).map(m => {
      if (m.images && m.images.length > 0) {
        const content = [];
        content.push({ type: 'text', text: m.content || '' });
        m.images.forEach(img => {
          const url = imageToBase64(img);
          if (url) content.push({ type: 'image_url', image_url: { url } });
        });
        return { role: m.role, content };
      }
      return { role: m.role, content: m.content || '' };
    });

    const body = {
      model: modelName,
      messages: formattedMessages,
      stream: true
    };

    const isAgnes = url.includes('agnes');
    const isDeepseek = url.includes('deepseek');

    if (thinkingEnabled) {
      if (isAgnes) {
        body.chat_template_kwargs = { enable_thinking: true };
      } else if (isDeepseek) {
        body.think = true;
      }
    }

    console.log('[AI Request] model:', modelName, 'thinking:', thinkingEnabled, 'body:', JSON.stringify(body));

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.setHeader('Transfer-Encoding', 'chunked');
    res.flushHeaders();

    const response = await axios.post(url, body, {
      headers: {
        'Authorization': `Bearer ${key}`,
        'Content-Type': 'application/json'
      },
      responseType: 'stream',
      timeout: 120000
    });

    let sseBuffer = '';

    response.data.on('data', (chunk) => {
      const text = chunk.toString();
      console.log('[AI chunk]', text.substring(0, 150));
      if (!thinkingEnabled) {
        sseBuffer += text;
        const lines = sseBuffer.split('\n');
        sseBuffer = lines.pop() || '';
        for (const line of lines) {
          if (line.startsWith('data: ') && line.includes('reasoning_content')) {
            const filtered = line.replace(/"reasoning_content":"[^"]*"/g, '"reasoning_content":""');
            res.write(filtered + '\n');
          } else {
            res.write(line + '\n');
          }
        }
      } else {
        res.write(chunk);
      }
      if (typeof res.flush === 'function') res.flush();
    });

    response.data.on('end', () => {
      if (!thinkingEnabled && sseBuffer) {
        if (sseBuffer.includes('reasoning_content')) {
          const filtered = sseBuffer.replace(/"reasoning_content":"[^"]*"/g, '"reasoning_content":""');
          res.write(filtered);
        } else {
          res.write(sseBuffer);
        }
      }
      res.end();
    });

    response.data.on('error', (err) => {
      console.error('[AI stream error]', err.message);
      if (!res.writableEnded) {
        const errData = JSON.stringify({choices:[{delta:{content:'\n\n[错误: ' + err.message + ']'}}]});
        res.write('data: ' + errData + '\n\n');
        res.write('data: [DONE]\n\n');
        res.end();
      }
    });

    req.on('close', () => {
      response.data.destroy();
    });
  } catch (err) {
    console.error('[AI error]', err.message);
    if (!res.headersSent) {
      res.status(500).json({ error: err.message });
    } else if (!res.writableEnded) {
      const errData = JSON.stringify({choices:[{delta:{content:'\n\n[请求失败: ' + err.message + ']'}}]});
      res.write('data: ' + errData + '\n\n');
      res.write('data: [DONE]\n\n');
      res.end();
    }
  }
});

module.exports = router;
