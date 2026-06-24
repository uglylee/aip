# CLAUDE.md

## 项目概述

AIP 是一个 AI 聊天 + 社交应用，Flutter 跨平台客户端 + Go 后端。核心功能是接入多种 AI 供应商（Agnes AI、DeepSeek 等）进行流式对话，同时支持推文发布、私信群聊、好友系统等社交功能。

## 技术栈

### Flutter 前端
- **架构**: Screen/Service/Model 三层分离
- **状态管理**: setState + SharedPreferences
- **网络**: http 包，SSE 流式响应用 Stream<String>
- **视频播放**: webview_flutter（兼容华为等无 ExoPlayer 设备）
- **图片**: image_picker（压缩 quality=50, max 1024px）

### Go 后端
- **框架**: Fiber v2 (fasthttp) + net/http (SSE)
- **数据库**: MongoDB (mongo-driver v2) + Redis (go-redis v9)
- **AI 接口**: OpenAI 兼容协议，SSE 流式推送（net/http Flusher）
- **实时**: WebSocket (gorilla/websocket)
- **认证**: JWT (golang-jwt/jwt/v5)
- **上传**: 本地文件存储 + ffmpeg 截取视频首帧缩略图
- **路由桥接**: gofiber/adaptor v2 (Fiber ↔ net/http)

### 基础设施
- Docker Compose (Redis + MongoDB)
- 端口: 后端 8005 / Redis 6380 / MongoDB 27018

## 架构要点

### SSE 流式对话
- **问题**: Fiber (fasthttp) 会缓冲响应体，`ctx.Write()` 不会立即 flush
- **解决**: AI SSE 接口 (`/api/ai` POST) 使用原生 `net/http` + `http.Flusher`，每次写入后立即 flush
- **桥接**: main.go 中 `adaptor.FiberApp(app)` 将 Fiber app 转为 http.Handler，`/api/ai` POST 单独走 net/http handler
- `reasoning_content` 字段为思考过程，`content` 为回复内容
- 图片以 base64 data URL 格式发送给 AI API
- 服务端自动补全 API URL 路径，HTTP 自动转 HTTPS

### 供应商系统
- 每个供应商独立保存模型配置 `model_{providerId}`
- Thinking 开关全局统一
- API Key 显示脱敏
- Agnes: `chat_template_kwargs.enable_thinking`
- DeepSeek: `body.think`

### 角色系统
- 每个角色独立 system prompt 和对话上下文
- 默认角色 + 翻译助手（不可删除）
- 聊天记录按角色 ID 持久化到 SharedPreferences

### 社交功能
- 推文: 文字/图片/视频发布，视频上传时 ffmpeg 截取首帧缩略图
- 关注: 关注/取关，粉丝/关注列表 API
- 好友: 发送/接受/拒绝请求，好友列表
- 私信: 一对一聊天，未读计数，WebSocket 实时推送
- 群聊: 创建/发消息/成员管理
- 通知: 点赞/转发/关注/回复/好友请求，自动标记已读

### MongoDB JSON 字段名
Go 后端 JSON 序列化使用 `json:"id"` 而非 MongoDB 的 `_id`。Flutter 客户端已做兼容: `j['id'] ?? j['_id']`。

## 关键文件

### Go 后端 (`server-go/`)
| 文件 | 作用 |
|------|------|
| `main.go` | 入口：Fiber 路由 + net/http 桥接 + WebSocket |
| `handlers/auth.go` | 注册/登录/me (Fiber) |
| `handlers/ai.go` | AI 流式对话 (Fiber) + 工具函数 |
| `handlers/ai_http.go` | AI SSE 流式对话 (net/http + Flusher) |
| `handlers/posts.go` | 推文 CRUD + 点赞/转发 |
| `handlers/messages.go` | 私信 + 会话列表 |
| `handlers/groups.go` | 群聊 |
| `handlers/friends.go` | 好友请求 |
| `handlers/notifications.go` | 通知 |
| `handlers/search.go` | 搜索 + DuckDuckGo + 趋势 |
| `handlers/upload.go` | 文件上传 + ffmpeg 缩略图 |
| `handlers/users.go` | 用户/关注/粉丝 |
| `models/` | 6 个 MongoDB 文档模型 |
| `services/db.go` | MongoDB 连接 + 索引 |
| `services/redis.go` | Redis 连接 |
| `middleware/auth.go` | JWT 中间件 |
| `ws/socket.go` | WebSocket Hub |
| `config/config.go` | 环境变量配置 |

### Flutter 前端 (`aip_app/`)
| 文件 | 作用 |
|------|------|
| `lib/services/api_service.dart` | 所有 HTTP 请求 + SSE 流式 |
| `lib/screens/ai_chat_screen.dart` | AI 聊天核心页面 |
| `lib/screens/home_screen.dart` | 首页 Feed |
| `lib/screens/settings_screen.dart` | 供应商/模型/Thinking 设置 |
| `lib/screens/chat_screen.dart` | 私信聊天 |
| `lib/screens/post_detail_screen.dart` | 帖子详情 + 评论 |
| `lib/models/post.dart` | Post 模型 (兼容 id/_id) |
| `lib/widgets/post_card.dart` | 帖子卡片 (图片/视频/缩略图) |

## 常用命令

```bash
# 启动数据库
cd aip && docker-compose up -d

# 启动 Go 后端
cd aip/server-go && go run main.go

# 构建 Android
cd aip/aip_app && flutter build apk --debug

# 安装到手机
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# 测试 AI 流式
python test_stream.py "你好"
```

## 注意事项

- Android 需要 `android:usesCleartextTraffic="true"` 访问 HTTP
- 视频上传限制 50MB，自动压缩图片 quality=50 max 1024px
- Docker 容器名前缀为 `aip-`，卷名为 `aip_`
- Post 模型 content 字段已改为非必填，支持纯图片/视频帖子
- 上传文件存储在 `server-go/uploads/`，ffmpeg 在 `server-go/ffmpeg.exe`
- SSE 流式必须用 `net/http` + `Flusher`，Fiber 的 `ctx.Write()` 会缓冲
