#!/bin/bash
set -e

echo "=== AIP iOS 构建安装脚本 ==="

# 查找设备
DEVICE_ID=$(xcrun devicectl list devices --json-output /dev/stdout 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for d in data.get('result', {}).get('devices', []):
    if d.get('deviceProperties', {}).get('osVersionNumber', '').startswith('18'):
        print(d['identifier'])
        break
" 2>/dev/null)

if [ -z "$DEVICE_ID" ]; then
    echo "未找到 iOS 设备，请确认手机已连接并开启开发者模式"
    exit 1
fi

echo "找到设备: $DEVICE_ID"

# 清理并获取依赖
echo "=== 清理构建缓存 ==="
flutter clean

echo "=== 获取依赖 ==="
flutter pub get

# 构建 release
echo "=== 构建 iOS Release ==="
flutter build ios --release

# 安装
echo "=== 安装到设备 ==="
IOS_DEPLOY="/Users/zhaoli/development/flutter/bin/cache/artifacts/ios-deploy/ios-deploy"
if [ -f "$IOS_DEPLOY" ]; then
    $IOS_DEPLOY --bundle build/ios/iphoneos/Runner.app --id "$DEVICE_ID"
else
    echo "ios-deploy 未找到，尝试 devicectl..."
    xcrun devicectl device install app --device "$DEVICE_ID" build/ios/iphoneos/Runner.app
fi

echo "=== 安装完成 ==="
