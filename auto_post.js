const { exec } = require('child_process');
const path = require('path');

function runPost() {
  const start = new Date().toLocaleTimeString();
  console.log(`[${start}] 执行中...`);
  exec('node ' + path.join(__dirname, 'random_post.js'), { cwd: __dirname }, (err, stdout, stderr) => {
    if (stdout) process.stdout.write(stdout);
    if (stderr) process.stderr.write(stderr);
    scheduleNext();
  });
}

function scheduleNext() {
  const delay = Math.floor(Math.random() * 110000) + 10000; // 10s ~ 120s
  const sec = Math.round(delay / 1000);
  console.log(`下次执行: ${sec}秒后\n`);
  setTimeout(runPost, delay);
}

console.log('=== 自动发帖服务已启动 ===');
console.log('间隔: 10~120秒随机\n');
runPost();
