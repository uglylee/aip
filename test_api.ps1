$Base = "http://127.0.0.1:8005"
$pass = 0; $fail = 0

function Log($msg) { Write-Host "  $msg" }
function OK($msg) { $script:pass++; Write-Host "  PASS: $msg" -ForegroundColor Green }
function FA($msg) { $script:fail++; Write-Host "  FAIL: $msg" -ForegroundColor Red }
function Sec($name) { Write-Host "`n=== $name ===" -ForegroundColor Cyan }

function CJ($url, $method, $body, $auth) {
    $args = @("-s", "-w", "`n%{http_code}", "-X", $method, "-H", "Content-Type: application/json")
    if ($auth) { $args += "-H"; $args += "Authorization: Bearer $auth" }
    if ($body) { $args += "-d"; $args += ($body | ConvertTo-Json -Compress -Depth 10) }
    $args += "$Base$url"
    $raw = & curl.exe @args
    $code = [int]$raw[-1]
    $json = ($raw[0..($raw.Count-2)] -join "`n")
    try { $obj = $json | ConvertFrom-Json } catch { $obj = $null }
    @{ code=$code; data=$obj; raw=$json }
}

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  AIP API Test Suite" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Sec "Health Check"
$r = CJ "/api/health" GET
OK "Health: $($r.data.status)"

Sec "Auth - Register"
$ua = CJ "/api/auth/register" POST @{username="TestA";handle="testa";email="a@test.com";password="pass123"}
OK "Register A" ($ua.code -eq 200 -and $ua.data.token)
$tA = $ua.data.token; $idA = $ua.data.user.id

$ub = CJ "/api/auth/register" POST @{username="TestB";handle="testb";email="b@test.com";password="pass123"}
OK "Register B" ($ub.code -eq 200 -and $ub.data.token)
$tB = $ub.data.token; $idB = $ub.data.user.id

$uc = CJ "/api/auth/register" POST @{username="TestC";handle="testc";email="c@test.com";password="pass123"}
OK "Register C" ($uc.code -eq 200)
$tC = $uc.data.token; $idC = $uc.data.user.id

Sec "Auth - Duplicate"
$d1 = CJ "/api/auth/register" POST @{username="X";handle="testa";email="x@test.com";password="pass123"}
OK "Dup handle -> 400" ($d1.code -eq 400)
$d2 = CJ "/api/auth/register" POST @{username="Y";handle="y";email="a@test.com";password="pass123"}
OK "Dup email -> 400" ($d2.code -eq 400)

Sec "Auth - Login"
$lg = CJ "/api/auth/login" POST @{email="a@test.com";password="pass123"}
OK "Login email" ($lg.code -eq 200 -and $lg.data.token)
$lg2 = CJ "/api/auth/login" POST @{email="testa";password="pass123"}
OK "Login handle" ($lg2.code -eq 200)
$lg3 = CJ "/api/auth/login" POST @{email="a@test.com";password="wrong"}
OK "Wrong pw -> 400" ($lg3.code -eq 400)

Sec "Auth - Get Me"
$me = CJ "/api/auth/me" GET $null $tA
OK "GetMe" ($me.code -eq 200 -and $me.data.username -eq "TestA")
$me2 = CJ "/api/auth/me" GET
OK "GetMe no token -> 401" ($me2.code -eq 401)

Sec "Users"
$gu = CJ "/api/users/$idB" GET $null $tA
OK "Get user B" ($gu.code -eq 200 -and $gu.data.username -eq "TestB")
$uu = CJ "/api/users/$idA" PUT @{username="TestA2";bio="Hi"} $tA
OK "Update user" ($uu.code -eq 200 -and $uu.data.username -eq "TestA2")
$fol = CJ "/api/users/$idB/follow" POST @{} $tA
OK "Follow B" ($fol.code -eq 200 -and $fol.data.isFollowing -eq $true)
$flw = CJ "/api/users/$idA/following" GET $null $tA
OK "Get following" ($flw.code -eq 200 -and $flw.data.Count -ge 1)
$fers = CJ "/api/users/$idB/followers" GET $null $tA
OK "Get followers" ($fers.code -eq 200 -and $fers.data.Count -ge 1)
$sf = CJ "/api/users/$idA/follow" POST @{} $tA
OK "Self follow -> 400" ($sf.code -eq 400)
$uf = CJ "/api/users/$idB/follow" DELETE $null $tA
OK "Unfollow" ($uf.code -eq 200 -and $uf.data.isFollowing -eq $false)

Sec "Posts"
$p1 = CJ "/api/posts" POST @{content="Hello world"} $tA
OK "Create post" ($p1.code -eq 200 -and $p1.data.content -eq "Hello world")
$pid1 = $p1.data.id
$fi = CJ "/api/posts/feed" GET $null $tA
OK "Feed" ($fi.code -eq 200 -and $fi.data.posts -ne $null)
$ex = CJ "/api/posts/explore" GET $null $tA
OK "Explore" ($ex.code -eq 200)
$dt = CJ "/api/posts/$pid1" GET $null $tA
OK "Get post detail" ($dt.code -eq 200 -and $dt.data.post.id -eq $pid1)
$lk = CJ "/api/posts/$pid1/like" POST @{} $tB
OK "Like" ($lk.code -eq 200 -and $lk.data.liked -eq $true)
$ul = CJ "/api/posts/$pid1/like" DELETE $null $tB
OK "Unlike" ($ul.code -eq 200 -and $ul.data.liked -eq $false)
$rt = CJ "/api/posts/$pid1/retweet" POST @{} $tB
OK "Retweet" ($rt.code -eq 200 -and $rt.data.retweeted -eq $true)
$urt = CJ "/api/posts/$pid1/retweet" DELETE $null $tB
OK "Undo retweet" ($urt.code -eq 200 -and $urt.data.retweeted -eq $false)
$rp = CJ "/api/posts" POST @{content="Reply";replyTo=$pid1} $tB
OK "Reply" ($rp.code -eq 200 -and $rp.data.replyTo)
$pdel = CJ "/api/posts" POST @{content="Delete me"} $tA
$dd = CJ "/api/posts/$($pdel.data.id)" DELETE $null $tA
OK "Delete own post" ($dd.code -eq 200 -and $dd.data.success -eq $true)
$pother = CJ "/api/posts" POST @{content="Not yours"} $tB
$df = CJ "/api/posts/$($pother.data.id)" DELETE $null $tA
OK "Cannot delete other" ($df.code -eq 403)
$up = CJ "/api/posts/user/$idA" GET $null $tA
OK "User posts" ($up.code -eq 200 -and $up.data.posts -ne $null)

Sec "Messages"
$mg = CJ "/api/messages/$idB" POST @{content="Hi B"} $tA
OK "Send message" ($mg.code -eq 200 -and $mg.data.content -eq "Hi B")
CJ "/api/messages/$idA" POST @{content="Hi A"} $tB | Out-Null
$mg2 = CJ "/api/messages/$idB" GET $null $tA
OK "Get messages" ($mg2.code -eq 200 -and $mg2.data.messages.Count -ge 1)
$cv = CJ "/api/messages/conversations" GET $null $tA
OK "Conversations" ($cv.code -eq 200 -and $cv.data.conversations.Count -ge 1)

Sec "Groups"
$gr = CJ "/api/groups" POST @{name="TestGroup";memberIds=@($idB)} $tA
OK "Create group" ($gr.code -eq 200 -and $gr.data.name -eq "TestGroup")
$gid = $gr.data.id
$gl = CJ "/api/groups" GET $null $tA
OK "List groups" ($gl.code -eq 200 -and $gl.data.groups.Count -ge 1)
$gd = CJ "/api/groups/$gid" GET $null $tA
OK "Get group" ($gd.code -eq 200 -and $gd.data.id -eq $gid)
$ga = CJ "/api/groups/$gid/members" POST @{userIds=@($idC)} $tA
OK "Add member" ($ga.code -eq 200 -and $ga.data.members.Count -ge 2)
$gm = CJ "/api/groups/$gid/messages" POST @{content="Hello group"} $tA
OK "Send group msg" ($gm.code -eq 200 -and $gm.data.content -eq "Hello group")
$gml = CJ "/api/groups/$gid/messages" GET $null $tA
OK "Get group msgs" ($gml.code -eq 200 -and $gml.data.messages.Count -ge 1)
$grm = CJ "/api/groups/$gid/members/$idC" DELETE $null $tA
OK "Remove member" ($grm.code -eq 200 -and $grm.data.success -eq $true)

Sec "Friends"
$fr = CJ "/api/friends/$idB" POST @{} $tA
OK "Friend request" ($fr.code -eq 200 -and $fr.data.status -eq "pending")
$fstat = CJ "/api/friends/status/$idB" GET $null $tA
OK "Friend status" ($fstat.code -eq 200 -and $fstat.data.status -eq "pending")
$fpend = CJ "/api/friends/pending" GET $null $tB
OK "Pending requests" ($fpend.code -eq 200 -and $fpend.data.requests.Count -ge 1)
$fac = CJ "/api/friends/$($fr.data.id)/accept" PUT @{} $tB
OK "Accept friend" ($fac.code -eq 200 -and $fac.data.success -eq $true)
$ffr = CJ "/api/friends/friends" GET $null $tA
OK "Friends list" ($ffr.code -eq 200 -and $ffr.data.friends.Count -ge 1)
$fchk = CJ "/api/friends/status/$idB" GET $null $tA
OK "Are friends" ($fchk.code -eq 200 -and $fchk.data.areFriends -eq $true)
$fdup = CJ "/api/friends/$idB" POST @{} $tA
OK "Dup friend req -> 400" ($fdup.code -eq 400)
$frm = CJ "/api/friends/$idB" DELETE $null $tA
OK "Remove friend" ($frm.code -eq 200 -and $frm.data.success -eq $true)

Sec "Notifications"
$nt = CJ "/api/notifications" GET $null $tA
OK "Notifications" ($nt.code -eq 200 -and $nt.data.notifications -ne $null)
$un = CJ "/api/notifications/unread" GET $null $tA
OK "Unread count" ($un.code -eq 200 -and $un.data.count -ne $null)

Sec "Search"
$se = CJ "/api/search?q=Hello" GET $null $tA
OK "Search" ($se.code -eq 200 -and $se.data.posts -ne $null)
$se2 = CJ "/api/search?q=" GET $null $tA
OK "Empty search" ($se2.code -eq 200)
$tr = CJ "/api/search/trends" GET $null $tA
OK "Trends" ($tr.code -eq 200 -and $tr.data.trends -ne $null)

Sec "Upload"
$noup = CJ "/api/upload" POST
OK "No file -> 400" ($noup.code -eq 400)

Sec "AI"
$ml = CJ "/api/ai/models" GET $null $tA
OK "Get models" ($ml.code -eq 200 -and $ml.data.models -ne $null)
$ai = CJ "/api/ai" POST @{messages=@(@{role="user";content="Say hi"});model="agnes-2.0-flash"} $tA
OK "AI chat SSE" ($ai.code -eq 200)

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "  RESULTS: $pass passed, $fail failed" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
if ($fail -gt 0) { exit 1 }
