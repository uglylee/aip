const fs = require('fs');
const path = require('path');
const http = require('http');

const BASE = 'http://localhost:8005';
const UPLOAD_DIR = path.join(__dirname, 'server-go', 'uploads');

function httpReq(method, urlPath, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const h = { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), ...headers };
    const u = new URL(BASE + urlPath);
    const req = http.request({ hostname: u.hostname, port: u.port, path: urlPath, method, headers: h }, res => {
      let buf = '';
      res.on('data', c => buf += c);
      res.on('end', () => { try { resolve(JSON.parse(buf)); } catch { resolve(buf); } });
    });
    req.on('error', reject); req.write(data); req.end();
  });
}

function httpUpload(urlPath, filePath, token) {
  return new Promise((resolve, reject) => {
    const boundary = '----B' + Date.now();
    const fileData = fs.readFileSync(filePath);
    const head = Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="${path.basename(filePath)}"\r\nContent-Type: image/bmp\r\n\r\n`);
    const foot = Buffer.from(`\r\n--${boundary}--\r\n`);
    const body = Buffer.concat([head, fileData, foot]);
    const u = new URL(BASE + urlPath);
    const h = { 'Content-Type': `multipart/form-data; boundary=${boundary}`, 'Content-Length': body.length, 'Authorization': `Bearer ${token}` };
    const req = http.request({ hostname: u.hostname, port: u.port, path: urlPath, method: 'POST', headers: h }, res => {
      let buf = '';
      res.on('data', c => buf += c);
      res.on('end', () => { try { resolve(JSON.parse(buf)); } catch { reject(new Error(buf)); } });
    });
    req.on('error', reject); req.write(body); req.end();
  });
}

// ---- Image generation helpers ----
const W = 640, H = 480;

function createBmp(filePath, pixelFn) {
  const rowSize = Math.ceil((W * 3) / 4) * 4;
  const imgSize = rowSize * H;
  const buf = Buffer.alloc(54 + imgSize);
  buf.write('BM', 0);
  buf.writeUInt32LE(54 + imgSize, 2);
  buf.writeUInt32LE(54, 10);
  buf.writeUInt32LE(40, 14);
  buf.writeInt32LE(W, 18); buf.writeInt32LE(H, 22);
  buf.writeUInt16LE(1, 26); buf.writeUInt16LE(24, 28);
  buf.writeUInt32LE(imgSize, 34);
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const [r, g, b] = pixelFn(x, y);
      const off = 54 + y * rowSize + x * 3;
      buf[off] = b; buf[off + 1] = g; buf[off + 2] = r;
    }
  }
  const bmpPath = filePath + '.bmp';
  fs.writeFileSync(bmpPath, buf);
  fs.renameSync(bmpPath, filePath);
}

function lerp(a, b, t) { return a + (b - a) * Math.max(0, Math.min(1, t)); }
function dist(x1, y1, x2, y2) { return Math.sqrt((x1-x2)**2 + (y1-y2)**2); }

// ---- Per-image generators ----

// 红烧肉 - brown/red gradient with circles (meat chunks)
function gen_hongshaorou(filePath) {
  createBmp(filePath, (x, y) => {
    const t = y / H;
    let r = lerp(80, 140, t), g = lerp(30, 50, t), b = lerp(20, 30, t);
    // circles representing meat chunks
    const circles = [[160,200,50],[320,180,60],[480,220,45],[240,300,55],[400,320,40],[120,340,35]];
    for (const [cx,cy,cr] of circles) {
      const d = dist(x,y,cx,cy);
      if (d < cr) { r = 180; g = 40; b = 25; }
      else if (d < cr+8) { r = 160; g = 60; b = 30; }
    }
    // highlight
    const d0 = dist(x, y, 320, 150);
    if (d0 < 100) { const f = 1 - d0/100; r += 30*f; g += 20*f; b += 10*f; }
    return [r, g, b];
  });
}

// 蛋糕 - pink/cream with layers
function gen_cake(filePath) {
  createBmp(filePath, (x, y) => {
    const t = y / H;
    // background gradient cream
    let r = lerp(255,240,t), g = lerp(228,200,t), b = lerp(196,170,t);
    // cake body
    if (y > 200 && y < 400 && x > 180 && x < 460) {
      r = 245; g = 210; b = 160; // sponge
    }
    // frosting top
    if (y > 190 && y < 215 && x > 170 && x < 470) {
      r = 255; g = 180; b = 190;
      // drips
      if ((x % 60 < 15) && y > 210 && y < 250) { r=255; g=170; b=180; }
    }
    // cherry on top
    const dc = dist(x,y,320,175);
    if (dc < 18) { r=220; g=30; b=50; }
    else if (dc < 22) { r=180; g=20; b=30; }
    return [r, g, b];
  });
}

// 咖啡 - warm brown with cup shape
function gen_coffee(filePath) {
  createBmp(filePath, (x, y) => {
    let r=60,g=40,b=25; // dark bg
    // table
    if (y > 350) { r=90; g=60; b=35; }
    // cup body
    if (y > 180 && y < 360 && x > 200 && x < 440) {
      r=220; g=215; b=200; // cup white
      // coffee inside
      if (y > 220 && x > 215 && x < 425) { r=80; g=45; b=20; }
    }
    // handle
    if (x > 430 && x < 480 && y > 230 && y < 310) {
      const d = dist(x,y,455,270);
      if (d > 18 && d < 28) { r=220; g=215; b=200; }
    }
    // steam
    if (x > 280 && x < 360 && y < 180 && y > 80) {
      const wave = Math.sin((y+x*0.05)*0.1) * 15;
      if (Math.abs(x - 320 - wave) < 8) { r=200; g=200; b=200; }
    }
    return [r,g,b];
  });
}

// 糖醋排骨 - reddish brown with bone shapes
function gen_paicu(filePath) {
  createBmp(filePath, (x, y) => {
    const t = y/H;
    let r=lerp(120,80,t), g=lerp(50,30,t), b=lerp(30,20,t);
    // plate
    const dp = dist(x,y,320,280);
    if (dp < 180 && dp > 120) { r=230; g=225; b=210; }
    if (dp < 120) { r=170; g=70; b=30; } // food on plate
    // bone highlights
    const bones = [[260,250],[320,240],[380,260],[290,290],[350,300]];
    for (const [bx,by] of bones) {
      if (dist(x,y,bx,by) < 20) { r=230; g=220; b=180; }
    }
    return [r,g,b];
  });
}

// 芝士蛋糕 - yellow triangle slice on plate
function gen_cheesecake(filePath) {
  createBmp(filePath, (x, y) => {
    let r=245,g=240,b=230; // cream bg
    // plate
    const dp = dist(x,y,320,350);
    if (dp < 200) { r=250; g=248; b=240; }
    // cake slice (triangle)
    if (y > 150 && y < 350) {
      const cx = 320, cy = 150;
      const halfW = (y - cy) * 0.7;
      if (x > cx - halfW && x < cx + halfW) {
        r=255; g=220; b=100; // cheese yellow
        // crust bottom
        if (y > 310) { r=180; g=130; b=70; }
      }
    }
    return [r,g,b];
  });
}

// 日落天空 - gradient orange/purple
function gen_sunset(filePath) {
  createBmp(filePath, (x, y) => {
    const t = y / H;
    const r = lerp(40, 255, t) * lerp(1.2, 0.8, t);
    const g = lerp(20, 120, t*t);
    const b = lerp(80, 40, t);
    // sun
    const ds = dist(x, y, 320, 200);
    if (ds < 50) { return [255, 200, 50]; }
    if (ds < 60) { return [255, 150, 30]; }
    // clouds
    if (y > 100 && y < 180 && (x > 100 && x < 250 || x > 400 && x < 550)) {
      return [255, 180, 120];
    }
    return [Math.min(255,r), Math.min(255,g), Math.min(255,b)];
  });
}

// 山景 - green mountains
function gen_mountain(filePath) {
  createBmp(filePath, (x, y) => {
    // sky
    let r=135,g=180,b=230;
    // mountain 1 (back)
    if (y > 150 + Math.sin(x*0.008)*60 + Math.cos(x*0.003)*80) { r=80; g=120; b=80; }
    // mountain 2 (front)
    if (y > 250 + Math.sin(x*0.012+1)*40 + Math.cos(x*0.005)*50) { r=60; g=100; b=60; }
    // snow cap
    if (y > 130 && y < 170 && Math.abs(x-320)<60) { r=240;g=240;b=245; }
    // ground
    if (y > 400) { r=50; g=90; b=40; }
    return [r,g,b];
  });
}

// 湖泊倒影
function gen_lake(filePath) {
  createBmp(filePath, (x, y) => {
    let r,g,b;
    if (y < 240) {
      // sky
      r=130; g=175; b=225;
      // trees on far bank
      if (y > 180 && Math.sin(x*0.03)>0.3) { r=40; g=80; b=40; }
    } else {
      // water - mirror of sky
      const ry = 480 - y;
      r=70; g=120; b=180;
      // ripples
      if (Math.sin(x*0.05 + y*0.1)*0.5+0.5 > 0.7) { r+=15; g+=15; b+=15; }
    }
    return [r,g,b];
  });
}

// 星空草原
function gen_starry(filePath) {
  createBmp(filePath, (x, y) => {
    let r=10,g=10,b=30; // dark sky
    if (y > 350) { r=30; g=60; b=20; } // grass
    // stars
    if (y < 350 && ((x*7+y*13)%97<2)) { r=255;g=255;b=200; }
    // milky way band
    if (y < 300 && Math.abs(y - 150 + Math.sin(x*0.01)*50) < 30) { r+=20; g+=15; b+=30; }
    return [r,g,b];
  });
}

// 海边日出
function gen_sunrise(filePath) {
  createBmp(filePath, (x, y) => {
    let r,g,b;
    if (y < 280) {
      // sky
      const t = y/280;
      r = lerp(255,100,t); g = lerp(180,140,t); b = lerp(100,200,t);
    } else {
      // ocean
      r=30; g=80+Math.sin(x*0.02)*10; b=150+Math.sin(x*0.03+y*0.05)*10;
    }
    // sun
    const ds = dist(x,y,320,260);
    if (ds < 40) { r=255;g=200;b=50; }
    else if (ds < 55) { r=255;g=150;b=30; }
    return [r,g,b];
  });
}

// 代码屏幕 - dark bg with colored text lines
function gen_code(filePath) {
  createBmp(filePath, (x, y) => {
    let r=30,g=30,b=35; // dark IDE bg
    // code lines
    const lineY = Math.floor(y / 18) * 18;
    const lineInBlock = y - lineY;
    if (lineInBlock < 12 && lineY > 20 && lineY < 460) {
      const indent = ((lineY * 7 + 13) % 5) * 20 + 40;
      if (x > indent && x < indent + 200 + (lineY*3)%150) {
        const colorIdx = (lineY * 11) % 4;
        if (colorIdx === 0) { r=86;g=182;b=194; } // keyword cyan
        else if (colorIdx === 1) { r=169;g=184;b=133; } // string green
        else if (colorIdx === 2) { r=206;g=145;b=120; } // number orange
        else { r=171;g=178;b=191; } // default white
      }
    }
    // line numbers
    if (x < 35 && lineInBlock < 12 && lineY > 20 && lineY < 460) {
      r=85; g=85; b=85;
    }
    // cursor blink
    if (Math.abs(x - 320) < 2 && Math.abs(y - 200) < 9) { r=200;g=200;b=200; }
    return [r,g,b];
  });
}

// 键盘 - dark with key shapes
function gen_keyboard(filePath) {
  createBmp(filePath, (x, y) => {
    let r=50,g=50,b=55; // desk
    // keyboard body
    if (y > 160 && y < 360 && x > 60 && x < 580) { r=35;g=35;b=40; }
    // keys
    const kx = (x - 80) % 52, ky = (y - 180) % 40;
    if (x > 80 && x < 560 && y > 180 && y < 340 && kx < 40 && ky < 28) {
      r=55; g=55; b=60;
      // some keys colored (WASD)
      const col = Math.floor((x-80)/52), row = Math.floor((y-180)/40);
      if ((col===4&&row===2)||(col===3&&row===3)||(col===5&&row===3)||(col===4&&row===3)) {
        r=200;g=50;b=50; // red accent
      }
    }
    return [r,g,b];
  });
}

// 书本 - open book
function gen_book(filePath) {
  createBmp(filePath, (x, y) => {
    let r=240,g=235,b=225; // table
    // left page
    if (y > 80 && y < 420 && x > 80 && x < 310) {
      r=255; g=252; b=245;
      // text lines
      if (y % 22 < 14 && x > 110 && x < 290) { r=60;g=60;b=60; }
    }
    // right page
    if (y > 80 && y < 420 && x > 330 && x < 560) {
      r=255; g=252; b=245;
      if (y % 22 < 14 && x > 360 && x < 540) { r=60;g=60;b=60; }
    }
    // spine
    if (x > 305 && x < 335) { r=180;g=60;b=40; }
    return [r,g,b];
  });
}

// 跑步 - runner silhouette
function gen_running(filePath) {
  createBmp(filePath, (x, y) => {
    let r=180,g=220,b=255; // morning sky
    if (y > 350) { r=100;g=160;b=80; } // grass
    // road
    if (y > 360 && y < 390) { r=180;g=180;b=180; }
    // runner silhouette (simple)
    // head
    if (dist(x,y,300,250)<20) { r=50;g=50;b=50; }
    // body
    if (x>280&&x<320&&y>270&&y<340) { r=50;g=50;b=50; }
    // legs
    if ((Math.abs(x-285)<8&&y>340&&y<400)||(Math.abs(x-315)<8&&y>340&&y<400)) { r=50;g=50;b=50; }
    return [r,g,b];
  });
}

// 音符 - music notes on staff
function gen_music(filePath) {
  createBmp(filePath, (x, y) => {
    let r=20;g=15;b=40; // dark purple bg
    // staff lines
    for (let i = 0; i < 5; i++) {
      if (Math.abs(y - (180 + i*30)) < 2) { r=200;g=200;b=200; }
    }
    // notes
    const notes = [[150,195],[250,225],[350,180],[450,210],[200,240],[400,195]];
    for (const [nx,ny] of notes) {
      if (dist(x,y,nx,ny)<12) { r=255;g=200;b=50; }
      // stem
      if (x>nx+8&&x<nx+12&&y>ny-50&&y<ny) { r=255;g=200;b=50; }
    }
    return [r,g,b];
  });
}

// 花园 - flowers
function gen_garden(filePath) {
  createBmp(filePath, (x, y) => {
    let r=100,g=180,b=100; // grass
    if (y < 150) { r=150;g=200;b=250; } // sky
    // flowers
    const flowers = [[120,300,255,100,100],[250,280,255,200,50],[380,310,200,100,255],[500,290,255,150,200],[180,350,100,200,255],[450,340,255,255,100]];
    for (const [fx,fy,fr,fg,fb] of flowers) {
      if (dist(x,y,fx,fy)<18) { r=fr;g=fg;b=fb; }
      if (dist(x,y,fx,fy)<6) { r=255;g=220;b=50; } // center
      // stem
      if (Math.abs(x-fx)<3&&y>fy&&y<fy+60) { r=50;g=120;b=50; }
    }
    return [r,g,b];
  });
}

// 城市夜景 - skyline with lights
function gen_citynight(filePath) {
  createBmp(filePath, (x, y) => {
    let r=15,g=15,b=35; // night sky
    // buildings
    const buildings = [[60,350,100],[120,280,80],[200,200,120],[320,250,90],[400,180,130],[520,300,70]];
    for (const [bx,bw,bh] of buildings) {
      if (x>bx&&x<bx+bw&&y>H-bh) {
        r=40;g=40;b=50;
        // windows
        if ((x-bx)%15<8 && (y-(H-bh))%15<8) {
          if (((bx+y)*7)%3===0) { r=255;g=220;b=100; } // lit window
          else { r=20;g=20;b=25; }
        }
      }
    }
    // reflections on water
    if (y > 400) {
      const refY = 400 - (y-400);
      if (refY > 0 && refY < H) {
        r = Math.max(0, r * 0.5 + 20);
        g = Math.max(0, g * 0.5 + 20);
        b = Math.max(0, b * 0.5 + 40);
      }
    }
    // stars
    if (y < 180 && ((x*13+y*7)%89<2)) { r=255;g=255;b=200; }
    return [r,g,b];
  });
}

// 面条 - noodle bowl
function gen_noodle(filePath) {
  createBmp(filePath, (x, y) => {
    let r=230;g=225;b=215; // table
    // bowl
    const db = dist(x,y,320,300);
    if (db < 160) { r=240;g=240;b=235; } // bowl white
    if (db < 140) { r=200;g=160;b=80; } // broth
    // noodles (wavy lines)
    if (y > 220 && y < 350 && db < 130) {
      const wave = Math.sin((x+y*0.5)*0.08)*10;
      if (Math.abs(x - 320 + wave) < 3 || Math.abs(x - 280 + wave) < 3 || Math.abs(x - 360 + wave) < 3) {
        r=240; g=220; b=150;
      }
    }
    // green onion bits
    const bits = [[250,240],[350,250],[300,230],[380,260]];
    for (const [bx,by] of bits) {
      if (dist(x,y,bx,by)<6) { r=80;g=160;b=60; }
    }
    // steam
    if (y < 200 && Math.abs(x-320+Math.sin(y*0.1)*20)<10) { r=220;g=220;b=220; }
    return [r,g,b];
  });
}

// 早餐吐司
function gen_breakfast(filePath) {
  createBmp(filePath, (x, y) => {
    let r=200;g=195;b=185; // plate/table
    // plate
    const dp = dist(x,y,320,280);
    if (dp < 180) { r=245;g=245;b=240; }
    // toast
    if (y>180&&y<320&&x>160&&x<340) {
      r=210;g=170;b=100; // bread
      if (y<200) { r=170;g=120;b=60; } // crust
    }
    // egg on top
    const de = dist(x,y,250,250);
    if (de < 40) { r=255;g=255;b=240; } // white
    if (de < 18) { r=255;g=200;b=50; } // yolk
    // fruit on side
    const fruits = [[400,240,20,220,80],[430,270,20,200,60],[420,220,15,230,90]];
    for (const [fx,fy,fr2,fg2,fb2] of fruits) {
      if (dist(x,y,fx,fy)<fr2) { r=fg2;g=fb2;b=60; }
    }
    return [r,g,b];
  });
}

// ---- Themed posts data ----
const POSTS = [
  // 美食
  { theme:'food', text:'折腾了一上午的红烧肉终于出锅了！肥而不腻入口即化，感觉自己可以去开店了哈哈', img: gen_hongshaorou },
  { theme:'food', text:'第一次自己做戚风蛋糕居然没塌！虽然卖相一般但真的超好吃，暴风哭泣', img: gen_cake },
  { theme:'food', text:'路过一家宝藏咖啡馆，老板自己烘的豆子，这杯手冲直接封神', img: gen_coffee },
  { theme:'food', text:'糖醋排骨yyds！连汤汁都被我拌饭吃光了，减肥什么的明天再说', img: gen_paicu },
  { theme:'food', text:'下午茶小确幸～一块芝士蛋糕配一杯美式，这就是人间值得吧', img: gen_cheesecake },
  { theme:'food', text:'被朋友安利的深夜面馆，这碗牛肉面真的绝了，汤底浓郁到我想哭', img: gen_noodle },
  { theme:'food', text:'周末早起给自己做了顿brunch，吐司煎蛋配水果，仪式感拉满', img: gen_breakfast },
  { theme:'food', text:'研究了三天的拉花终于像样了！虽然还是歪的但好歹能看了', img: gen_coffee },
  { theme:'food', text:'冰箱里翻出来的食材随便炒了一盘，没想到意外的好吃，我是不是有天赋', img: gen_noodle },
  { theme:'food', text:'自制珍珠奶茶成功！比某点点好喝一百倍不接受反驳', img: gen_coffee },
  // 风景
  { theme:'nature', text:'下班路上抬头看到的晚霞，整片天空都是橘子味的，突然觉得活着真好', img: gen_sunset },
  { theme:'nature', text:'爬了三个小时终于到山顶！累到不行但看到云海的那一刻值了', img: gen_mountain },
  { theme:'nature', text:'清晨五点爬起来看湖面的雾气，安静得只听见鸟叫，这一刻什么都不想', img: gen_lake },
  { theme:'nature', text:'露营的时候偶然抬头，银河就这么挂在头顶，比任何壁纸都震撼', img: gen_starry },
  { theme:'nature', text:'海边等了两小时终于等到日出，当第一缕光洒在海面上的时候眼眶湿了', img: gen_sunrise },
  { theme:'nature', text:'雨后的山里空气好到想打包带走，每一口都是负离子的味道', img: gen_mountain },
  { theme:'nature', text:'秋天的落叶铺满了小路，踩上去沙沙响，这就是秋天该有的样子吧', img: gen_garden },
  // 科技
  { theme:'tech', text:'这个bug卡了我三天！刚才突然灵光一闪搞定了，程序员的快乐就是这么朴素', img: gen_code },
  { theme:'tech', text:'机器学习第一周，被数学公式虐到怀疑人生但还是想继续学下去', img: gen_code },
  { theme:'tech', text:'终于入手了心心念念的机械键盘！红轴手感太爽了打字都想多写两行代码', img: gen_keyboard },
  { theme:'tech', text:'给自己的开源项目加了个新feature，虽然star还没破百但成就感满满', img: gen_code },
  { theme:'tech', text:'今天code review被大佬指出了好几个问题，果然还是要多学习多进步', img: gen_code },
  { theme:'tech', text:'用新框架重构了一下午代码，跑通的那一刻真的想给自己鼓掌', img: gen_code },
  // 生活
  { theme:'life', text:'今天阳光太好了没忍住出去溜达了一圈，公园里的花都开了心情瞬间变好', img: gen_garden },
  { theme:'life', text:'和闺蜜去郊外野餐啦～铺上格子布摆上水果，这才是周末该有的样子', img: gen_garden },
  { theme:'life', text:'早起跑步打卡！虽然跑到两公里的时候真的很想放弃但还是撑下来了', img: gen_running },
  { theme:'life', text:'在咖啡店窝了一下午看完了一本一直想看的书，窗外下着雨里面暖暖的', img: gen_book },
  { theme:'life', text:'深夜单曲循环一首歌，旋律在脑子里转了一整天怎么都停不下来', img: gen_music },
  { theme:'life', text:'周末在家窝着看剧吃零食，虽然有点颓但偶尔躺平也是一种幸福', img: gen_book },
  { theme:'life', text:'整理房间的时候翻到了去年的旅行照片，好想再去一次啊', img: gen_garden },
];

const NAMES = ['张伟','王芳','李强','赵敏','陈刚','刘洋','杨帆','黄磊','周杰','吴婷','孙丽','朱明','马超','胡歌','林峰','郑爽','何冰','罗晋','宋茜','韩庚','Angel','Luna','Max','Sofia','Leo','Mia','Aiden','Zoe','Lucas','Chloe','Ethan','Emma','Noah','Olivia','Jack','Ava','Logan','Henry','Sophia','Sebastian','Alexander','Charlotte','Daniel','Amelia','Matthew','Harper','Jackson','David','Carter','Emily','Jayden','Luke','Owen','Nathan','Grace','Ryan','Lily','Andrew','Hannah','Elijah','Zoey','Gabriel','Nora','Caleb','Riley','Isaac','Aria','Thomas','Layla'];

async function main() {
  console.log('=== AIP Seed Data v3 ===\n');

  // Step 1: Generate all themed images
  console.log('[1/4] Generating themed images...');
  const uploadedPaths = [];
  for (const post of POSTS) {
    const fp = path.join(UPLOAD_DIR, `${post.theme}_${uploadedPaths.length}.jpg`);
    post.img(fp);
    post.localPath = fp;
    uploadedPaths.push(fp);
  }
  console.log(`  Created ${uploadedPaths.length} images`);

  // Step 2: Upload
  console.log('\n[2/4] Uploading media...');
  const token = (await httpReq('POST', '/api/auth/login', { email: 'assd4750@163.com', password: 'Ab58576145' })).token;
  for (const post of POSTS) {
    const resp = await httpUpload('/api/upload', post.localPath, token);
    post.imageUrl = resp.url;
  }
  console.log(`  Uploaded ${POSTS.length} images`);

  // Step 3: Create 100 users
  console.log('\n[3/4] Creating 100 users...');
  const tokens = [];
  for (let i = 0; i < 100; i++) {
    const name = NAMES[i % NAMES.length];
    const handle = `user${Date.now()}${i}`;
    const email = `${handle}@test.com`;
    const username = `${name}${Math.floor(Math.random()*9000+1000)}`;
    try {
      const resp = await httpReq('POST', '/api/auth/register', { username, handle, email, password: '123456' });
      if (resp.token) tokens.push(resp.token);
    } catch {}
  }
  console.log(`  Created ${tokens.length} users`);

  // Step 4: Create posts - each user gets 2-5 posts with their own token
  console.log('\n[4/4] Creating posts...');
  let total = 0;
  for (let i = 0; i < tokens.length; i++) {
    const userToken = tokens[i];
    const count = Math.floor(Math.random() * 4) + 2;
    for (let j = 0; j < count; j++) {
      const post = POSTS[Math.floor(Math.random() * POSTS.length)];
      const body = { content: post.text, images: [post.imageUrl] };
      try {
        await httpReq('POST', '/api/posts', body, { Authorization: `Bearer ${userToken}` });
        total++;
      } catch {}
    }
  }
  console.log(`  Created ${total} posts`);

  console.log(`\n=== Done! ${tokens.length} users, ${total} posts ===`);
}

main().catch(console.error);
