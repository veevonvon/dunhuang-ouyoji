#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export JAVA_HOME="$PROJECT_ROOT/.toolchain/jdk17/Contents/Home"
export ANDROID_HOME="$PROJECT_ROOT/.toolchain/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$PROJECT_ROOT/.toolchain/android-user"
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$PROJECT_ROOT/.toolchain/signing/debug.keystore"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android

APK="$PROJECT_ROOT/builds/ouyoji-4.3.0-android.apk"
BUILD_TOOLS="$ANDROID_HOME/build-tools/36.0.0"

if [ ! -x "$BUILD_TOOLS/apksigner" ] || [ ! -f "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" ]; then
    printf '%s\n' 'Android 工具链或调试密钥缺失。请先运行 tools/setup-toolchain.sh。' >&2
    exit 1
fi
if [ ! -f "$PROJECT_ROOT/project.godot" ]; then
    printf '%s\n' '缺少 project.godot，无法导出游戏。' >&2
    exit 1
fi

mkdir -p "$PROJECT_ROOT/builds"
touch "$PROJECT_ROOT/builds/.gdignore"
IMPORT_LOG="$PROJECT_ROOT/.toolchain/export-import-4.3.log"
EXPORT_LOG="$PROJECT_ROOT/.toolchain/export-android-4.3.log"
if ! "$PROJECT_ROOT/tools/godot.sh" --headless --editor --path "$PROJECT_ROOT" --import > "$IMPORT_LOG" 2>&1; then
    cat "$IMPORT_LOG" >&2
    exit 1
fi
if grep -Eq '^(SCRIPT ERROR|ERROR):' "$IMPORT_LOG"; then
    cat "$IMPORT_LOG" >&2
    exit 1
fi
if ! "$PROJECT_ROOT/tools/godot.sh" --headless --path "$PROJECT_ROOT" --export-debug "Android Debug" "$APK" > "$EXPORT_LOG" 2>&1; then
    cat "$EXPORT_LOG" >&2
    exit 1
fi
if grep -Eq '^(SCRIPT ERROR|ERROR):' "$EXPORT_LOG"; then
    cat "$EXPORT_LOG" >&2
    exit 1
fi
"$BUILD_TOOLS/apksigner" verify --verbose --print-certs "$APK"
"$BUILD_TOOLS/zipalign" -c -P 16 4 "$APK"
"$BUILD_TOOLS/aapt" dump badging "$APK"
python3 "$PROJECT_ROOT/tools/export-verify.py" "$APK"
(cd "$PROJECT_ROOT/builds" && shasum -a 256 ouyoji-4.3.0-android.apk > ouyoji-4.3.0-android.apk.sha256)
printf '\n%s\n' "已导出并检查调试 APK：$APK"
