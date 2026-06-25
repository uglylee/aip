# AIP - AI Chat Application

一个功能完整的 AI 聊天 + 社交应用，Flutter 跨平台客户端 + Go 后端。支持多 AI 供应商流式对话、图片视频发布、私信群聊、好友系统。

## 功能概览

### AI 助手
- 多供应商管理（Agnes AI / DeepSeek 等，自由添加）
- 流式 SSE 实时逐字输出
- Thinking 模式（思考过程流式显示，完成后折叠）
- 图片输入识别（多模态对话）
- 角色设定（自定义系统提示词，每个角色独立对话上下文）

### 社交功能
- **推文系统**: 发布文字/图片/视频，点赞/转发/评论/回复
- **图片视频**: 上传自动压缩，视频 ffmpeg 截取首帧缩略图
- **关注系统**: 关注/取关，粉丝/关注列表
- **好友系统**: 发送/接受/拒绝好友请求，好友列表
- **私信系统**: 一对一私信，未读计数，已读标记，WebSocket 实时推送
- **群聊系统**: 创建群聊，群消息，成员管理
- **通知系统**: 点赞/转发/关注/回复/好友请求，未读标记
- **搜索系统**: 搜索用户/帖子 + DuckDuckGo 网页搜索
- **个人资料**: 头像/用户名/简介，查看他人资料页

### 应用功能
- **应用内更新**: 检测新版本，下载 APK 并触发系统安装
- **前台服务**: Android 前台通知保活
- **推送通知**: 本地通知提醒

## 技术栈

### 前端 (Flutter)
- **框架**: Flutter 3.44+ / Dart 3.12+
- **状态管理**: setState + SharedPreferences
- **网络**: http 包 + SSE 流式
- **视频播放**: webview_flutter
- **图片选择**: image_picker
- **实时通信**: web_socket_channel
- **应用更新**: dio 下载 + open_file 安装
- **通知**: flutter_local_notifications + MethodChannel 原生安装

### 后端 (Go)
- **框架**: Fiber v2 (fasthttp) + net/http (SSE)
- **数据库**: MongoDB (mongo-driver v2) + Redis (go-redis v9)
- **实时**: gorilla/websocket
- **AI**: OpenAI 兼容协议 + net/http Flusher SSE
- **认证**: JWT (golang-jwt/jwt/v5)
- **上传**: 本地存储 + ffmpeg 视频缩略图
- **路由桥接**: gofiber/adaptor v2

### 基础设施
- Docker Compose (Redis + MongoDB)
- 端口: 后端 8005 / Redis 6380 / MongoDB 27018

## 项目结构

```
aip/
├── aip_app/                        # Flutter 前端
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/                 # user, post, message, provider_model, role
│   │   ├── services/
│   │   │   ├── api_service.dart        # HTTP 请求 + SSE
│   │   │   ├── update_service.dart     # 应用内更新
│   │   │   ├── socket_service.dart     # WebSocket 连接
│   │   │   ├── foreground_service.dart # Android 前台服务
│   │   │   └── notification_service.dart # 本地通知
│   │   ├── screens/
│   │   │   ├── home_screen.dart        # 首页 Feed + 搜索框
│   │   │   ├── ai_chat_screen.dart     # AI 聊天
│   │   │   ├── settings_screen.dart    # AI 供应商/模型/Thinking 设置
│   │   │   ├── providers_screen.dart   # 供应商管理
│   │   │   ├── roles_screen.dart       # 角色管理
│   │   │   ├── create_post_screen.dart # 发布推文
│   │   │   ├── post_detail_screen.dart # 帖子详情 + 评论
│   │   │   ├── profile_screen.dart     # 个人资料
│   │   │   ├── search_screen.dart      # 搜索
│   │   │   ├── messages_screen.dart    # 消息列表
│   │   │   ├── chat_screen.dart        # 私信聊天
│   │   │   ├── friends_screen.dart     # 好友列表
│   │   │   ├── group_list_screen.dart  # 群聊列表
│   │   │   ├── group_chat_screen.dart  # 群聊聊天
│   │   │   ├── login_screen.dart       # 登录
│   │   │   └── notifications_screen.dart
│   │   └── widgets/
│   │       ├── post_card.dart          # 帖子卡片
│   │       └── user_avatar.dart        # 用户头像
│   ├── android/
│   │   └── app/src/main/
│   │       ├── AndroidManifest.xml     # 权限声明
│   │       ├── kotlin/.../MainActivity.kt  # MethodChannel 安装 APK
│   │       └── res/xml/file_paths.xml  # FileProvider 路径
│   └── pubspec.yaml
│
├── server-go/                      # Go 后端
│   ├── main.go                     # 入口: Fiber 路由 + net/http 桥接
│   ├── .env / .env.example         # 环境变量配置
│   ├── Dockerfile
│   ├── go.mod / go.sum
│   ├── config/config.go            # 配置加载 (godotenv)
│   ├── handlers/
│   │   ├── auth.go                 # 注册/登录/me
│   │   ├── ai.go                   # AI 工具函数
│   │   ├── ai_http.go              # AI SSE (net/http Flusher)
│   │   ├── posts.go                # 推文 CRUD + 点赞/转发
│   │   ├── messages.go             # 私信
│   │   ├── groups.go               # 群聊
│   │   ├── friends.go              # 好友请求
│   │   ├── notifications.go        # 通知
│   │   ├── search.go               # 搜索 + DuckDuckGo
│   │   ├── upload.go               # 上传 + 版本检查
│   │   └── users.go                # 用户/关注
│   ├── models/                     # 6 个 MongoDB 文档模型
│   ├── services/
│   │   ├── db.go                   # MongoDB 连接 + 索引
│   │   └── redis.go                # Redis 连接
│   ├── middleware/auth.go          # JWT 中间件
│   ├── ws/socket.go                # WebSocket Hub
│   └── uploads/                    # 上传文件
│
├── deploy.ps1                      # 一键部署脚本
├── docker-compose.yml
├── seed_data.js                    # 测试数据生成
├── AGENTS.md
├── CLAUDE.md
└── README.md
```

## 快速开始

### 1. 启动数据库
```bash
cd aip
docker-compose up -d
```

### 2. 配置环境变量
```bash
cd server-go
cp .env.example .env
# 编辑 .env 设置 JWT_SECRET 等
```

### 3. 启动后端
```bash
cd server-go
go run main.go
```

### 4. 构建 Android
```bash
cd aip_app
flutter pub get
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### 5. 构建 iOS（需 macOS）
```bash
flutter clean && flutter pub get && flutter build ios --release ios-deploy --bundle build/ios/iphoneos/Runner.app --id <设备UDID>
```

### 6. 一键部署 (Windows)
```powershell
.\deploy.ps1
```
自动完成: 版本递增 → Go 编译 → Flutter 构建 → APK 安装 → 服务器重启

## API 接口

| 路由 | 方法 | 说明 |
|------|------|------|
| `/api/auth/register` | POST | 注册 |
| `/api/auth/login` | POST | 登录 |
| `/api/auth/me` | GET | 当前用户 |
| `/api/posts` | POST | 发帖 |
| `/api/posts/feed` | GET | 首页 Feed |
| `/api/posts/explore` | GET | 探索页 |
| `/api/posts/:id` | GET | 帖子详情 |
| `/api/posts/:id/like` | POST/DELETE | 点赞 |
| `/api/posts/:id/retweet` | POST/DELETE | 转发 |
| `/api/users/:id` | GET/PUT | 用户信息 |
| `/api/users/:id/follow` | POST/DELETE | 关注 |
| `/api/messages/conversations` | GET | 会话列表 |
| `/api/messages/:userId` | GET/POST | 私信 |
| `/api/groups` | GET/POST | 群聊 |
| `/api/groups/:id/messages` | GET/POST | 群消息 |
| `/api/friends` | - | 好友请求 |
| `/api/notifications` | GET | 通知列表 |
| `/api/notifications/unread` | GET | 未读数 |
| `/api/search` | GET | 搜索 |
| `/api/upload` | POST | 文件上传 |
| `/api/ai` | POST | AI 流式对话 |
| `/api/ai/models` | GET | 模型列表 |
| `/api/version` | GET | 版本检查 |
| `/app` | GET | 下载页面 |

## 环境要求

- Flutter 3.44+ / Dart 3.12+
- Go 1.22+
- Docker & Docker Compose
- Android SDK (API 34+)
- macOS + Xcode (iOS 构建)
- ios-deploy（Flutter SDK 自带）

## iOS 构建安装

### 前置条件
1. Mac 安装 Xcode 和 Flutter SDK
2. iPhone 开启**开发者模式**：设置 → 隐私与安全性 → 开发者模式
3. 用数据线连接 iPhone，点击**信任此电脑**

### 安装
```bash
cd aip_app
flutter clean
flutter pub get
flutter build ios --release ios-deploy --bundle build/ios/iphoneos/Runner.app --id <设备UDID>
```

查看设备 UDID：
```bash
xcrun devicectl list devices
```

### 注意事项
- 项目必须在 Mac 本地磁盘，**不要放在 Windows 共享目录**（会导致构建死锁）
- 必须用 `--release` 模式，debug 模式在 iOS 18.7.7 上会 VSyncClient 崩溃
- 用 `ios-deploy` 而非 `devicectl` 安装，避免 Xcode 隧道连接问题
- 免费 Apple ID 签名有效期 **7 天**，到期需重新安装
