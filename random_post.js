const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

function httpReq(method, urlPath, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const h = { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), ...headers };
    const r = http.request({ hostname: 'localhost', port: 8005, path: urlPath, method, headers: h }, res => {
      let buf = ''; res.on('data', c => buf += c);
      res.on('end', () => { try { resolve(JSON.parse(buf)); } catch { resolve(buf); } });
    });
    r.on('error', reject); r.write(data); r.end();
  });
}

function aiGenerate(prompt) {
  const apiKey = fs.readFileSync(path.join(__dirname, 'server-go', 'key.config.txt'), 'utf-8').trim();
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      model: 'agnes-2.0-flash',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.9,
      max_tokens: 200
    });
    const r = https.request({
      hostname: 'apihub.agnes-ai.com',
      path: '/v1/chat/completions',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + apiKey,
        'Content-Length': Buffer.byteLength(data)
      }
    }, res => {
      let buf = ''; res.on('data', c => buf += c);
      res.on('end', () => {
        try {
          const json = JSON.parse(buf);
          resolve(json.choices?.[0]?.message?.content?.trim() || '');
        } catch { resolve(''); }
      });
    });
    r.on('error', reject); r.write(data); r.end();
  });
}

async function main() {
  console.log('=== 随机发帖工具 ===\n');

  // Get random user
  const jsFile = path.join(__dirname, '_rand_user.js');
  fs.writeFileSync(jsFile, 'var u = db.getSiblingDB("aip").users.aggregate([{$sample:{size:1}}]).next(); print(u.username + "|" + u.email);');
  const result = execSync('docker exec -i aip-mongo mongosh --quiet < ' + jsFile, { encoding: 'utf-8' }).trim();
  fs.unlinkSync(jsFile);

  const [username, email] = result.split('|');
  if (!email) { console.log('获取用户失败'); return; }

  // Generate post content via AI
  console.log('正在生成帖子内容...');
  const text = await aiGenerate('请用中文写一条朋友圈风格的帖子，要求：1. 拟人化口语化，像真人发的 2. 内容可以是日常生活、工作、学习、美食、运动、旅行、心情等 3. 长度50-100字 4. 不要带表情符号 5. 只输出帖子内容，不要任何前缀和解释');
  if (!text) { console.log('AI 生成失败'); return; }

  // Login
  let token = null;
  for (const pwd of ['123456', 'Ab58576145']) {
    const login = await httpReq('POST', '/api/auth/login', { email, password: pwd });
    if (login.token) { token = login.token; break; }
  }
  if (!token) { console.log('登录失败:', username); return; }

  // Post
  const post = await httpReq('POST', '/api/posts', { content: text }, { Authorization: 'Bearer ' + token });
  if (post.id || post._id) {
    console.log(`[${username}] 发布了帖子:`);
    console.log(`"${text}"`);
  } else {
    console.log('发布失败:', JSON.stringify(post));
  }
}

main();
