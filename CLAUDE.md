# CLAUDE.md

## 项目概述

AIP 是一个 AI 聊天 + 社交应用，Flutter 跨平台客户端 + Node.js 后端。核心功能是接入多种 AI 供应商（Agnes AI、DeepSeek 等）进行流式对话，同时支持推文发布、私信群聊、好友系统等社交功能。

## 技术要点

### Flutter 前端
- **架构**: Screen/Service/Model 三层分离
- **状态管理**: setState + SharedPreferences
- **网络**: http 包，SSE 流式响应用 Stream<String>
- **视频播放**: webview_flutter（兼容华为等无 ExoPlayer 设备）
- **图片**: image_picker（压缩 quality=50, max 1024px）

### Node.js 后端
- **路由**: Express Router 按功能模块拆分
- **数据库**: MongoDB (Mongoose) + Redis (ioredis)
- **AI 接口**: OpenAI 兼容协议，SSE 流式推送
- **实时**: Socket.IO
- **上传**: multer + ffmpeg-static（视频自动截取首帧缩略图）

### AI 流式响应
- 服务端: Express SSE (text/event-stream) + axios stream 转发
- 客户端: http.Client.send() + StreamedResponse 逐行解析
- `reasoning_content` 字段为思考过程，`content` 为回复内容
- 图片以 base64 data URL 格式发送给 AI API
- 服务端自动补全 API URL 路径，HTTP 自动转 HTTPS

### 供应商系统
- 每个供应商独立保存模型配置 `model_{providerId}`
- Thinking 开关全局统一，不随供应商切换
- API Key 显示脱敏
- Agnes: `chat_template_kwargs.enable_thinking`
- DeepSeek: `body.think`

### 角色系统
- 每个角色独立 system prompt 和对话上下文
- 默认角色 + 翻译助手（不可删除）
- 聊天记录按角色 ID 持久化到 SharedPreferences

### 社交功能
- 推文: 文字/图片/视频发布，视频上传时服务端 ffmpeg 截取首帧缩略图
- 关注: 关注/取关，粉丝/关注列表 API
- 好友: 发送/接受/拒绝请求，好友列表
- 私信: 一对一聊天，未读计数，Socket.IO 实时推送
- 群聊: 创建/发消息/成员管理
- 通知: 点赞/转发/关注/回复/好友请求，自动标记已读

## 关键文件

| 文件 | 作用 |
|------|------|
| `aip_app/lib/services/api_service.dart` | 所有 HTTP 请求 + SSE 流式 + 上传 |
| `aip_app/lib/screens/ai_chat_screen.dart` | AI 聊天核心页面 |
| `aip_app/lib/screens/home_screen.dart` | 首页 Feed + 搜索框 |
| `aip_app/lib/screens/settings_screen.dart` | 供应商 + 模型 + Thinking 设置 |
| `aip_app/lib/screens/create_post_screen.dart` | 发布推文（文字/图片/视频） |
| `aip_app/lib/screens/messages_screen.dart` | 消息列表 + 好友/群聊入口 |
| `aip_app/lib/screens/friends_screen.dart` | 好友列表 + 请求 |
| `aip_app/lib/screens/group_list_screen.dart` | 群聊列表 |
| `aip_app/lib/screens/notifications_screen.dart` | 通知列表 |
| `aip_app/lib/models/provider_model.dart` | 供应商模型 + 本地持久化 |
| `aip_app/lib/widgets/post_card.dart` | 帖子卡片（图片/视频缩略图/点赞/转发） |
| `server/routes/ai.js` | AI 流式接口 + 图片 base64 转换 |
| `server/routes/upload.js` | 文件上传 + ffmpeg 视频缩略图 |
| `server/routes/posts.js` | 推文 CRUD + 点赞/转发/评论 |
| `server/routes/messages.js` | 私信 + 会话列表 |
| `server/routes/groups.js` | 群聊 |
| `server/routes/friends.js` | 好友请求 |
| `server/routes/notifications.js` | 通知 |
| `server/models/Post.js` | Post 模型（含 images/videos/thumbnails） |
| `server/key.config.txt` | 默认 API Key |

## 常用命令

```bash
# 启动数据库
cd aip && docker-compose up -d

# 启动后端
cd aip/server && node index.js

# 构建 Android
cd aip/aip_app && flutter build apk --debug

# 安装到手机
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# 测试 AI 流式（需要先设置编码）
chcp 65001
python test_stream.py "你好"
python test_stream.py "用中文解释量子计算" --think
python test_deepseek.py "hi"  # 需先修改脚本中的 API Key
```

## 注意事项

- Android 需要 `android:usesCleartextTraffic="true"` 访问 HTTP
- Android 需要 `RECORD_AUDIO` 权限用于语音输入
- 华为设备无 Google 服务，语音识别用键盘自带功能，视频播放用 WebView
- 视频上传限制 50MB，自动压缩图片 quality=50 max 1024px
- Docker 容器名前缀为 `aip-`，卷名为 `aip_`
- 切换供应商时需清空模型列表避免下拉框报错
- Post 模型 content 字段已改为非必填，支持纯图片/视频帖子
