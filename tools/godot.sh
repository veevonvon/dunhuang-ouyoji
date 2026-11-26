#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_ROOT="$PROJECT_ROOT/.toolchain/godot"
GODOT_BIN="$GODOT_ROOT/Godot.app/Contents/MacOS/Godot"

if [ ! -x "$GODOT_BIN" ]; then
    printf '%s\n' '尚未安装本地 Godot。请先运行 tools/setup-toolchain.sh。' >&2
    exit 1
fi

# macOS 4.7 checks the directory containing the .app for portable editor data.
touch "$GODOT_ROOT/_sc_"
export JAVA_HOME="$PROJECT_ROOT/.toolchain/jdk17/Contents/Home"
export ANDROID_HOME="$PROJECT_ROOT/.toolchain/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$PROJECT_ROOT/.toolchain/android-user"
export ANDROID_EMULATOR_HOME="$ANDROID_USER_HOME"
export ANDROID_AVD_HOME="$PROJECT_ROOT/.toolchain/android-avd"
export ANDROID_ADB_SERVER_PORT=5038
export ADB_SERVER_SOCKET=tcp:localhost:5038
if [ -f "$PROJECT_ROOT/.toolchain/signing/debug.keystore" ]; then
    export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$PROJECT_ROOT/.toolchain/signing/debug.keystore"
    export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
    export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
fi

cd "$PROJECT_ROOT"
exec "$GODOT_BIN" "$@"
