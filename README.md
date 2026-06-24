# AIP - AI Chat Application

一个功能完整的 AI 聊天 + 社交应用，Flutter 跨平台客户端 + Node.js 后端。支持多 AI 供应商流式对话、图片视频发布、私信群聊、好友系统。

## 功能概览

### AI 助手
- 多供应商管理（Agnes AI / DeepSeek 等，自由添加）
- 流式 SSE 实时逐字输出
- Thinking 模式（思考过程流式显示，完成后折叠）
- 图片输入识别（多模态对话）
- 角色设定（自定义系统提示词，每个角色独立对话上下文）
- 对话历史按角色持久化
- 语音输入（键盘语音识别 + 自动发送）

### 社交功能
- **推文系统**: 发布文字/图片/视频，点赞/转发/评论/回复
- **图片视频**: 上传自动压缩，视频服务端截取首帧缩略图
- **关注系统**: 关注/取关，粉丝/关注列表
- **好友系统**: 发送/接受/拒绝好友请求，好友列表
- **私信系统**: 一对一私信，未读计数，已读标记，实时推送
- **群聊系统**: 创建群聊，群消息，成员管理
- **通知系统**: 点赞/转发/关注/回复/好友请求，未读标记
- **搜索系统**: 搜索用户/帖子
- **个人资料**: 头像/用户名/简介，查看他人资料页

## 技术栈

### 前端 (Flutter)
- **框架**: Flutter 3.44+ / Dart 3.12+
- **状态管理**: setState + SharedPreferences
- **网络**: http 包 + SSE 流式
- **视频播放**: webview_flutter
- **图片选择**: image_picker
- **实时通信**: socket_io_client

### 后端 (Node.js)
- **框架**: Express
- **数据库**: MongoDB (Mongoose) + Redis (ioredis)
- **实时**: Socket.IO
- **AI**: OpenAI 兼容协议 + SSE
- **文件上传**: multer + ffmpeg（视频截取缩略图）
- **认证**: JWT

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
│   │   ├── services/api_service.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart        # 首页 Feed + 搜索框
│   │   │   ├── ai_chat_screen.dart     # AI 聊天（语音/文字/图片）
│   │   │   ├── settings_screen.dart    # AI 供应商/模型/Thinking 设置
│   │   │   ├── providers_screen.dart   # 供应商管理
│   │   │   ├── roles_screen.dart       # 角色管理
│   │   │   ├── create_post_screen.dart # 发布推文（文字/图片/视频）
│   │   │   ├── post_detail_screen.dart # 帖子详情 + 评论
│   │   │   ├── profile_screen.dart     # 个人资料 + 关注/好友
│   │   │   ├── search_screen.dart      # 搜索
│   │   │   ├── messages_screen.dart    # 消息列表 + 好友/群聊入口
│   │   │   ├── chat_screen.dart        # 私信聊天
│   │   │   ├── friends_screen.dart     # 好友列表 + 好友请求
│   │   │   ├── group_list_screen.dart  # 群聊列表
│   │   │   ├── group_chat_screen.dart  # 群聊聊天
│   │   │   └── notifications_screen.dart # 通知
│   │   └── widgets/post_card.dart  # 帖子卡片（图片/视频/点赞/转发）
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
│
├── server/                         # Node.js 后端
│   ├── index.js
│   ├── routes/
│   │   ├── auth.js             # 注册/登录
│   │   ├── users.js            # 用户/关注
│   │   ├── posts.js            # 推文 CRUD + 点赞/转发
│   │   ├── messages.js         # 私信
│   │   ├── groups.js           # 群聊
│   │   ├── friends.js          # 好友请求
│   │   ├── notifications.js    # 通知
│   │   ├── search.js           # 搜索
│   │   ├── upload.js           # 文件上传 + 视频缩略图
│   │   └── ai.js               # AI 流式对话
│   ├── models/                 # Mongoose 数据模型
│   ├── middleware/auth.js      # JWT 认证
│   └── key.config.txt          # 默认 API Key
│
├── docker-compose.yml
├── test_stream.py              # AI 流式测试脚本
└── test_deepseek.py            # DeepSeek 测试脚本
```

## 快速开始

### 1. 启动数据库
```bash
cd aip
docker-compose up -d
```

### 2. 启动后端
```bash
cd server
npm install
node index.js
```

### 3. 构建 Android
```bash
cd aip_app
flutter pub get
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## API 接口

| 路由 | 方法 | 说明 |
|------|------|------|
| `/api/auth/register` | POST | 注册 |
| `/api/auth/login` | POST | 登录 |
| `/api/auth/me` | GET | 当前用户 |
| `/api/posts` | POST | 发帖（文字/图片/视频） |
| `/api/posts/feed` | GET | 首页 Feed |
| `/api/posts/explore` | GET | 探索页 |
| `/api/posts/:id` | GET | 帖子详情 |
| `/api/posts/:id/like` | POST/DELETE | 点赞 |
| `/api/posts/:id/retweet` | POST/DELETE | 转发 |
| `/api/users/:id` | GET | 用户信息 |
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
| `/api/ai/models` | GET | 获取模型列表 |

## 环境要求

- Flutter 3.44+
- Node.js 18+
- Docker & Docker Compose
- Android SDK (API 34+)
