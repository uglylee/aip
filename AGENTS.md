# AGENTS.md

## Repo structure

Two packages, no shared build system:
- `aip_app/` — Flutter client (Dart SDK ^3.12.2)
- `server-go/` — Go backend (module `aip-server`, Go 1.26.3, Fiber v2 + net/http)

Infrastructure: `docker-compose.yml` starts Redis (port 6380) and MongoDB (port 27018) with prefixed container/volume names (`aip-redis`, `aip-mongo`, `aip_*`).

## Commands

```bash
# Infrastructure (from repo root)
docker-compose up -d

# Go backend (from server-go/)
go run main.go              # runs on :8005, reads .env
go build -o aip-server.exe  # Windows binary

# Flutter (from aip_app/)
flutter pub get
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
flutter analyze              # uses flutter_lints/flutter.yaml
flutter test                 # only a boilerplate stub exists — not useful
```

No CI, no Makefile, no test runner beyond `flutter test`. No Go tests exist.

## Architecture gotchas

### SSE must bypass Fiber
The AI streaming endpoint (`POST /api/ai`) uses raw `net/http` + `http.Flusher` because Fiber (fasthttp) buffers response bodies. In `main.go`, all traffic goes through `adaptor.FiberApp(app)` except `/api/ai POST` which is routed to `handlers.AIChatHTTP` via a plain `http.ServeMux`. **Never move SSE to a Fiber handler.**

### MongoDB id field
Go models serialize `_id` as `json:"id"`. Flutter models must handle both: `j['id'] ?? j['_id']`. Every `fromJson` factory does this.

### Hardcoded base URL
`ApiService.baseUrl` in `aip_app/lib/services/api_service.dart` is hardcoded to `http://192.168.0.108:8005`. Change this to match your dev machine's LAN IP.

### Android cleartext
`android:usesCleartextTraffic="true"` is required in the manifest for HTTP dev connections.

## Conventions

- **Flutter**: Screen/Service/Model three-layer split. `setState` for state. `typedef JSONObject = Map<String, dynamic>` in api_service.dart.
- **Go**: All handlers in `handlers/`, MongoDB models in `models/`, DB/Redis clients in `services/`. Fiber middleware in `middleware/`. WebSocket hub in `ws/`.
- **Vendor config**: Per-provider model settings stored as `model_{providerId}` in SharedPreferences. Thinking toggle is global.
- **Image handling**: `image_picker` compresses to quality=50, max 1024px. Video uploads limited to 50MB. Server-side ffmpeg (`server-go/ffmpeg.exe`) extracts first-frame thumbnails.
- **Uploads**: Stored in `server-go/uploads/`, served as static files at `/uploads/*`.
- **Windows binaries**: `ffmpeg.exe` and `aip-server.exe` are Windows-specific and gitignored.

## Key files

| File | Why it matters |
|------|---------------|
| `server-go/main.go` | Entry point: Fiber routes + net/http bridge + WebSocket |
| `server-go/handlers/ai_http.go` | SSE streaming implementation (the tricky part) |
| `server-go/config/config.go` | All env vars with defaults (godotenv) |
| `server-go/services/db.go` | MongoDB collections + indexes |
| `aip_app/lib/services/api_service.dart` | All HTTP calls + SSE streaming client |
| `aip_app/lib/models/post.dart` | Exemplar of the `id`/`_id` dual-field pattern |
| `aip_app/lib/screens/ai_chat_screen.dart` | Core AI chat UI |
