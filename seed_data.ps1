$baseUrl = "http://localhost:8005"
$uploadDir = "C:\Users\lee\Desktop\test\aip\server-go\uploads"

Write-Host "=== AIP Seed Data ===" -ForegroundColor Cyan

# --- Generate test images using .NET ---
Write-Host "[1/4] Generating test images..." -ForegroundColor Yellow
Add-Type -AssemblyName System.Drawing

$colors = @(
    [System.Drawing.Color]::FromArgb(220, 53, 69),
    [System.Drawing.Color]::FromArgb(40, 167, 69),
    [System.Drawing.Color]::FromArgb(0, 123, 255),
    [System.Drawing.Color]::FromArgb(255, 193, 7),
    [System.Drawing.Color]::FromArgb(23, 162, 184),
    [System.Drawing.Color]::FromArgb(111, 66, 193),
    [System.Drawing.Color]::FromArgb(253, 126, 20),
    [System.Drawing.Color]::FromArgb(32, 201, 151),
    [System.Drawing.Color]::FromArgb(232, 62, 140),
    [System.Drawing.Color]::FromArgb(102, 16, 242),
    [System.Drawing.Color]::FromArgb(134, 188, 37),
    [System.Drawing.Color]::FromArgb(0, 200, 83),
    [System.Drawing.Color]::FromArgb(255, 82, 82),
    [System.Drawing.Color]::FromArgb(41, 121, 255),
    [System.Drawing.Color]::FromArgb(255, 171, 0)
)

$imagePaths = @()
for ($i = 0; $i -lt 15; $i++) {
    $bmp = New-Object System.Drawing.Bitmap(640, 480)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear($colors[$i])
    $g.DrawString("Image $($i+1)", (New-Object System.Drawing.Font("Arial", 28, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::White, 200, 220)
    $path = Join-Path $uploadDir "test_img_$i.jpg"
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    $g.Dispose(); $bmp.Dispose()
    $imagePaths += $path
}
Write-Host "  Created 15 test images" -ForegroundColor Green

# --- Generate test videos using ffmpeg ---
Write-Host "[2/4] Generating test videos..." -ForegroundColor Yellow
$ffmpeg = "C:\Users\lee\Desktop\test\aip\server-go\ffmpeg.exe"
$videoPaths = @()
for ($i = 0; $i -lt 5; $i++) {
    $vPath = Join-Path $uploadDir "test_vid_$i.mp4"
    $colorNames = @("red", "green", "blue", "yellow", "purple")
    $c = $colorNames[$i]
    & $ffmpeg -y -f lavfi -i "color=c=$c:s=640x480:d=3" -f lavfi -i "anullsrc=r=44100:cl=stereo" -c:v libx264 -t 3 -pix_fmt yuv420p -c:a aac -shortest $vPath 2>&1 | Out-Null
    if (Test-Path $vPath) { $videoPaths += $vPath }
}
Write-Host "  Created $($videoPaths.Count) test videos" -ForegroundColor Green

# --- Upload media files ---
Write-Host "[3/4] Uploading media..." -ForegroundColor Yellow

function Upload-File($filePath) {
    $boundary = [System.Guid]::NewGuid().ToString()
    $fileName = Split-Path $filePath -Leaf
    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
    $enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")

    $body = New-Object System.Text.StringBuilder
    $body.AppendLine("--$boundary") | Out-Null
    $body.AppendLine("Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"") | Out-Null
    $body.AppendLine("Content-Type: application/octet-stream") | Out-Null
    $body.AppendLine() | Out-Null

    $headerBytes = $enc.GetBytes($body.ToString())
    $footerBytes = $enc.GetBytes("`r`n--$boundary--`r`n")

    $stream = New-Object System.IO.MemoryStream
    $stream.Write($headerBytes, 0, $headerBytes.Length)
    $stream.Write($fileBytes, 0, $fileBytes.Length)
    $stream.Write($footerBytes, 0, $footerBytes.Length)
    $stream.Position = 0

    $resp = Invoke-RestMethod -Uri "$baseUrl/api/upload" -Method Post -Body $stream -ContentType "multipart/form-data; boundary=$boundary"
    $stream.Dispose()
    return $resp.url
}

$uploadedImages = @()
foreach ($p in $imagePaths) {
    $r = Upload-File $p
    $uploadedImages += $r
    Write-Host "  Uploaded image: $r" -ForegroundColor DarkGray
}

$uploadedVideos = @()
foreach ($p in $videoPaths) {
    $r = Upload-File $p
    $uploadedVideos += $r
    Write-Host "  Uploaded video: $r" -ForegroundColor DarkGray
}
Write-Host "  Uploaded $($uploadedImages.Count) images, $($uploadedVideos.Count) videos" -ForegroundColor Green

# --- Random data ---
$firstNames = @("张伟","王芳","李强","赵敏","陈刚","刘洋","杨帆","黄磊","周杰","吴婷","孙丽","朱明","马超","胡歌","林峰","郑爽","何冰","高圆","罗晋","梁博","宋茜","唐嫣","韩庚","冯绍峰","谢霆","邓超","曹颖","彭于","袁泉","董洁","潘粤","蒋欣","于和","任嘉","古力","杨幂","Angel","Luna","Max","Sofia","Leo","Mia","Aiden","Zoe","Lucas","Chloe","Ethan","Emma","Noah","Olivia","Jack","Ava","Logan","Isabella","Henry","Sophia","Sebastian","Mia","Alexander","Charlotte","Daniel","Amelia","Matthew","Harper","Jackson","Evelyn","David","Abigail","Carter","Emily","Jayden","Elizabeth","Luke","Sofia","Owen","Chloe","Aiden","Madison","Nathan","Grace","Ryan","Lily","Andrew","Hannah","Elijah","Zoey","Gabriel","Nora","Caleb","Riley","Isaac","Aria","Thomas","Layla")

$texts = @(
    "今天天气真好，出去走走吧！",
    "刚刚完成了一个大项目，感觉很棒！",
    "分享一个有趣的故事...",
    "周末愉快！大家有什么计划？",
    "最近在学习一门新的编程语言",
    "推荐一家很好吃的餐厅",
    "这本书真的很好看，强烈推荐！",
    "旅行中遇到的美景",
    "今天的日落太美了",
    "分享一下我的新发现",
    "生活需要仪式感",
    "努力工作，享受生活",
    "今天的咖啡特别好喝",
    "周末的慵懒时光",
    "分享一首好听的歌",
    "美食是最好的治愈",
    "新的一天，新的开始",
    "保持好奇心，探索世界",
    "今天的运动打卡",
    "分享一个小技巧",
    "阅读让我快乐",
    "音乐是灵魂的食粮",
    "珍惜每一个当下",
    "感恩生活中的美好",
    "今天的天空特别蓝",
    "和朋友聚会的快乐时光",
    "学习永无止境",
    "分享一本好书",
    "生活处处有惊喜",
    "保持积极的心态",
    "今天的风景如画",
    "享受独处的时光",
    "美食制作分享",
    "今天的心情特别好",
    "探索未知的领域",
    "记录生活中的小确幸",
    "分享一个好看的电影",
    "生活处处有美好",
    "保持好奇心",
    "享受慢生活",
    "分享我的收藏",
    "今天的小确幸",
    "分享一个好去处",
    "今天的快乐时光",
    "记录美好瞬间",
    "分享我的日常",
    "今天的小惊喜",
    "享受生活的每一天",
    "分享一个有趣的话题",
    "今天的小感动"
)

$bios = @(
    "热爱生活，热爱代码",
    "AI爱好者 | 技术探索者",
    "设计师 | 摄影爱好者",
    "美食家 | 旅行达人",
    "程序员 | 音乐爱好者",
    "学生 | 好奇心旺盛",
    "创业者 | 梦想追逐者",
    "作家 | 阅读爱好者",
    "运动爱好者 | 健康生活",
    "摄影师 | 旅行者"
)

# --- Register users & create posts ---
Write-Host "[4/4] Creating 100 users and posts..." -ForegroundColor Yellow

$tokens = @()
for ($i = 0; $i -lt 100; $i++) {
    $name = $firstNames[$i % $firstNames.Count]
    $suffix = (Get-Random -Minimum 100 -Maximum 9999)
    $username = "$name$suffix"
    $handle = "user$((Get-Random -Minimum 10000 -Maximum 99999))"
    $email = "$handle@test.com"
    $password = "123456"
    $bio = $bios[(Get-Random -Minimum 0 -Maximum $bios.Count)]

    try {
        $regBody = @{
            username = $username
            handle   = $handle
            email    = $email
            password = $password
        } | ConvertTo-Json

        $regResp = Invoke-RestMethod -Uri "$baseUrl/api/auth/register" -Method Post -Body $regBody -ContentType "application/json"
        $token = $regResp.token
        $tokens += $token

        $postCount = Get-Random -Minimum 2 -Maximum 6
        for ($j = 0; $j -lt $postCount; $j++) {
            $text = $texts[(Get-Random -Minimum 0 -Maximum $texts.Count)]
            $hasImage = (Get-Random -Minimum 0 -Maximum 10) -lt 6
            $hasVideo = -not $hasImage -and (Get-Random -Minimum 0 -Maximum 10) -lt 3

            $postBody = @{ content = $text }
            if ($hasImage) {
                $imgCount = Get-Random -Minimum 1 -Maximum 4
                $imgs = @()
                for ($k = 0; $k -lt $imgCount; $k++) {
                    $imgs += $uploadedImages[(Get-Random -Minimum 0 -Maximum $uploadedImages.Count)]
                }
                $postBody.images = $imgs
            }
            if ($hasVideo -and $uploadedVideos.Count -gt 0) {
                $vid = $uploadedVideos[(Get-Random -Minimum 0 -Maximum $uploadedVideos.Count)]
                $postBody.videos = @($vid)
            }

            $postJson = $postBody | ConvertTo-Json
            Invoke-RestMethod -Uri "$baseUrl/api/posts" -Method Post -Body $postJson -ContentType "application/json" -Headers @{ Authorization = "Bearer $token" } | Out-Null
        }
        Write-Host "  [$($i+1)/100] $username - $postCount posts" -ForegroundColor DarkGray
    } catch {
        Write-Host "  [$($i+1)/100] Failed: $_" -ForegroundColor Red
    }
}

Write-Host "`n=== Done! Created $($tokens.Count) users ===" -ForegroundColor Cyan
