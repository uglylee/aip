const http = require('http');
const data = JSON.stringify({
  username: "uglylee",
  handle: "uglylee130",
  email: "uglylee@test.com",
  password: "123456"
});
const req = http.request({
  hostname: '127.0.0.1',
  port: 3000,
  path: '/api/auth/register',
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'Content-Length': data.length }
}, (res) => {
  let body = '';
  res.on('data', d => body += d);
  res.on('end', () => console.log(body));
});
req.write(data);
req.end();
