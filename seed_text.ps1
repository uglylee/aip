$baseUrl = "http://localhost:8005"

Write-Host "=== Create Users & Text Posts ===" -ForegroundColor Cyan

# Register 2 main users
$u1 = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" -Method Post -Body '{"username":"zhaoli","handle":"zhaoli","email":"assd4750@163.com","password":"Ab58576145"}' -ContentType "application/json"
Write-Host "User 1: zhaoli" -ForegroundColor Green

$u2 = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" -Method Post -Body '{"username":"lihengju","handle":"lihengju","email":"lihengju@163.com","password":"Ab58576145"}' -ContentType "application/json"
Write-Host "User 2: lihengju" -ForegroundColor Green

$mainTokens = @($u1.token, $u2.token)

# Register 98 more users
$names = @('Zhang','Wang','Li','Zhao','Chen','Liu','Yang','Huang','Zhou','Wu','Sun','Zhu','Ma','Hu','Lin','Angel','Luna','Max','Sofia','Leo','Mia','Aiden','Zoe','Lucas','Chloe','Ethan','Emma','Noah','Olivia','Jack','Ava','Logan','Henry','Sophia','Sebastian','Alexander','Charlotte','Daniel','Amelia','Matthew','Harper','Jackson','David','Carter','Emily','Jayden','Luke','Owen','Nathan','Grace')
$allTokens = @() + $mainTokens

for ($i = 0; $i -lt 98; $i++) {
    $name = $names[$i % $names.Length]
    $num = Get-Random -Minimum 1000 -Maximum 9999
    $handle = "user$((Get-Random -Minimum 100000 -Maximum 999999))"
    $body = @{username="$name$num"; handle=$handle; email="$handle@test.com"; password="123456"} | ConvertTo-Json
    try {
        $r = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" -Method Post -Body $body -ContentType "application/json"
        if ($r.token) { $allTokens += $r.token }
    } catch {}
}
Write-Host "Total users: $($allTokens.Count)" -ForegroundColor Green

# Posts text
$texts = @(
    "折腾了一上午的红烧肉终于出锅了！肥而不腻入口即化，感觉自己可以去开店了哈哈",
    "第一次自己做戚风蛋糕居然没塌！虽然卖相一般但真的超好吃，暴风哭泣",
    "路过一家宝藏咖啡馆，老板自己烘的豆子，这杯手冲直接封神",
    "糖醋排骨yyds！连汤汁都被我拌饭吃光了，减肥什么的明天再说",
    "下午茶小确幸一块芝士蛋糕配一杯美式，这就是人间值得吧",
    "被朋友安利的深夜面馆，这碗牛肉面真的绝了，汤底浓郁到我想哭",
    "周末早起给自己做了顿早午餐，吐司煎蛋配水果，仪式感拉满",
    "研究了三天的拉花终于像样了！虽然还是歪的但好歹能看了",
    "冰箱里翻出来的食材随便炒了一盘，没想到意外的好吃，我是不是有天赋",
    "自制珍珠奶茶成功！比外面卖的好喝一百倍不接受反驳",
    "下班路上抬头看到的晚霞，整片天空都是橘子味的，突然觉得活着真好",
    "爬了三个小时终于到山顶！累到不行但看到云海的那一刻值了",
    "清晨五点爬起来看湖面的雾气，安静得只听见鸟叫，这一刻什么都不想",
    "露营的时候偶然抬头，银河就这么挂在头顶，比任何壁纸都震撼",
    "海边等了两小时终于等到日出，当第一缕光洒在海面上的时候眼眶湿了",
    "雨后的山里空气好到想打包带走，每一口都是负离子的味道",
    "秋天的落叶铺满了小路，踩上去沙沙响，这就是秋天该有的样子吧",
    "这个bug卡了我三天！刚才突然灵光一闪搞定了，程序员的快乐就是这么朴素",
    "机器学习第一周，被数学公式虐到怀疑人生但还是想继续学下去",
    "终于入手了心心念念的机械键盘！红轴手感太爽了打字都想多写两行代码",
    "给自己的开源项目加了个新feature，虽然star还没破百但成就感满满",
    "今天code review被大佬指出了好几个问题，果然还是要多学习多进步",
    "用新框架重构了一下午代码，跑通的那一刻真的想给自己鼓掌",
    "今天阳光太好了没忍住出去溜达了一圈，公园里的花都开了心情瞬间变好",
    "和闺蜜去郊外野餐啦铺上格子布摆上水果，这才是周末该有的样子",
    "早起跑步打卡！虽然跑到两公里的时候真的很想放弃但还是撑下来了",
    "在咖啡店窝了一下午看完了一本一直想看的书，窗外下着雨里面暖暖的",
    "深夜单曲循环一首歌，旋律在脑子里转了一整天怎么都停不下来",
    "周末在家窝着看剧吃零食，虽然有点颓但偶尔躺平也是一种幸福",
    "整理房间的时候翻到了去年的旅行照片，好想再去一次啊",
    "刚看完一部超感人的电影，哭得稀里哗啦的，强烈推荐大家去看",
    "今天面试表现还不错，希望能收到offer吧，加油打工人",
    "养的绿萝终于发新芽了！照顾了半年终于看到回报了",
    "周末去了趟花鸟市场，买了两盆多肉，希望这次不要被我养死",
    "今天和老朋友聚了一下，聊了好多以前的事，时间过得真快",
    "刚跑完五公里，虽然累得不行但多巴胺分泌的感觉真爽",
    "发现了一家超好吃的火锅店，锅底是现炒的，辣到飞起但停不下来",
    "今天把家里彻底打扫了一遍，断舍离扔了好多东西，整个人都轻松了",
    "第一次尝试做提拉米苏，竟然一次成功！朋友们都说好吃到哭",
    "晚上去江边散步，风吹着特别舒服，所有的烦恼都被吹走了"
)

# Create posts
$total = 0
foreach ($t in $allTokens) {
    $count = Get-Random -Minimum 2 -Maximum 6
    for ($j = 0; $j -lt $count; $j++) {
        $text = $texts[(Get-Random -Minimum 0 -Maximum $texts.Count)]
        $body = @{content=$text} | ConvertTo-Json
        try {
            Invoke-RestMethod -Uri "$baseUrl/api/posts" -Method Post -Body $body -ContentType "application/json" -Headers @{Authorization="Bearer $t"} | Out-Null
            $total++
        } catch {}
    }
}

Write-Host "Created $total text-only posts" -ForegroundColor Green
Write-Host "=== Done ===" -ForegroundColor Cyan
