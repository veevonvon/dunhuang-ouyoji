# 本地 Godot / Android 工具链

核对日期：2026-11-19。开发主机为 macOS Apple Silicon，工具只安装到工程的 `.toolchain/`。不要求全局 Godot、Java 或 Android Studio，不修改系统 PATH。`.toolchain/.gdignore` 阻止引擎导入工具自身。

## 使用

在工程根目录执行：

```sh
tools/setup-toolchain.sh
tools/godot.sh --version
tools/godot.sh --editor --path .
tools/export-android.sh
```

安装脚本使用 Python 3 标准库、macOS 自带 `curl`、`ditto`、`tar` 和 `codesign`。安装是可重复的：校验缓存下载，保留现有完整工具和调试密钥；发现不完整目录时中止，不覆盖目录。该固定安装器仅适用于 macOS ARM64。其他系统可以使用相同 Godot 和 SDK 版本，但需替换主机工具包及启动脚本。

`tools/godot.sh` 透传所有 Godot 参数，工作目录固定为工程根；`_sc_` 标记位于 `Godot.app` 同级。已通过 verbose 输出确认编辑器数据存储在 `.toolchain/godot/editor_data/`。`JAVA_HOME`、`ANDROID_HOME`、`ANDROID_SDK_ROOT` 和 `ANDROID_USER_HOME` 只在子进程中设置。

导出命令先导入资源，再生成 `builds/ouyoji-android-debug.apk`，随后检查 APK 签名、16 KB 原生库对齐和 Android manifest，并写出同名 `.sha256` 文件。它不上传文件，不使用商店签名。

## 固定版本与来源

| 工具 | 固定版本 | 用途与许可 |
| --- | --- | --- |
| Godot 标准版 | 4.7.2.stable.official.ed1daf0bf，macOS universal | 编辑器和 GDScript；MIT 及随附第三方声明 |
| Godot 导出模板 | 4.7.2.stable | 官方预编译 Android debug/release 模板；MIT 及随附第三方声明 |
| Eclipse Temurin JDK | 17.0.21.1+2，macOS ARM64 | APK 签名工具；GPL-2.0 with Classpath Exception，仅本地开发工具，不随源码或 APK 分发 |
| Android Command-line Tools | 19.0，build 13114758 | SDK 管理；Android SDK License Agreement 及 NOTICE |
| Android Platform-Tools | 37.0.1，build 15733141 | adb；Android SDK License Agreement 及 NOTICE |
| Android Build-Tools | 36.0.0 | aapt、zipalign、apksigner；Android SDK License Agreement 及 NOTICE |
| Android SDK Platform | API 36，revision 2 | 本地 SDK；Android SDK License Agreement 及 NOTICE |

下载地址、许可摘要和 SHA256 固定在 `tools/setup-toolchain.json`；安装副本记录在 `.toolchain/download-manifest.json`。引擎和模板先与 Godot 官方 SHA512 清单匹配；JDK 与 Adoptium API 的 SHA256 匹配；Google SDK 文件先与官方 repository XML 的 SHA1 匹配，再固定本项目 SHA256。

| 文件 | SHA256 |
| --- | --- |
| Godot_v4.7.2-stable_macos.universal.zip | `c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e` |
| Godot_v4.7.2-stable_export_templates.tpz | `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011` |
| OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.21.1_2.tar.gz | `2a88ccb044a8fb00957be93245da6357c11b55717511509d147cbcc5d93b2109` |
| commandlinetools-mac-13114758_latest.zip | `5673201e6f3869f418eeed3b5cb6c4be7401502bd0aae1b12a29d164d647a54e` |
| platform-tools_r37.0.1-darwin.zip | `ee39ad5967e95c2a07f04dbcbde96b1a0c916ba376096db5d2f498b7727a5d1d` |
| build-tools_r36_macosx.zip | `04e7f3a72044de4926fa038fa0e251a37bba1e1c3fb8beab6f8401bfd9eb4bf3` |
| platform-36_r02.zip | `37607369a28c5b640b3a7998868d45898ebcb777565a0e85f9acf36f29631d2e` |

这里使用 `gradle_build/use_gradle_build=false` 的预编译 APK 导出路径。GDScript 游戏没有 Android 插件，无需重新编译引擎、Gradle、NDK 或 CMake。官方 stable 导出文档仍列出 Build-Tools 35.0.1；实际 4.7.2 模板的 manifest 为最低 API 24、目标 API 36，且引擎会提示 35 的工具版本不匹配。因此最终固定 Build-Tools 36.0.0 / Platform 36，按实际模板对齐。

Command-line Tools 23 的 `sdkmanager` 已改为新的 Android CLI 引导器，连 `--version` 都会触发额外工具下载。本工程固定使用仍提供经典 Java SDK 管理器的 19.0，避免安装时引入未固定的额外下载。

## APK 配置与密钥

- 包名：`org.ouyoji.dunhuang`；显示名：`欧哟几`；版本：`4.0.0` / `40000`。
- ABI：`arm64-v8a` 与 `armeabi-v7a`；不包含 x86。
- 主工程负责 Compatibility、1280×720 `canvas_items / expand` 和横屏设置。
- 不启用网络、摄像头、麦克风、定位、通知和外部存储权限；不启用云备份。
- `.toolchain/signing/debug.keystore` 只用于调试安装，权限为 `0600`；默认 Android 调试别名及密码通过包装器及导出进程环境传入，不写入 preset。
- 源码交付必须排除 `.toolchain/`、`.godot/`、`builds/` 和缓存。现有密钥不会被安装脚本重建或覆盖。
- `data/*.json`、字体许可证/来源与 `assets/licenses/*.txt` 显式包含在 APK；测试、工具、工程文档、运行截图和构建输出显式排除。

## 验证记录

已执行：官方校验值比对、Godot `--version` / `--help`、无界面编辑器初始化、Godot app `codesign --verify --deep --strict`、JDK / adb / sdkmanager 版本检查、安装脚本重复运行、shell 语法和 Python 语法检查。

最终真实工程 APK 已于 2026-11-19 导出并安装运行：

| 项目 | 实测结果 |
| --- | --- |
| 文件 | `builds/ouyoji-android-debug.apk`，95,801,410 字节 |
| SHA256 | `0d3bbb2265729343eadbc54b773da32cff35e13fe21d1fe05c238e6a8719f30f` |
| 身份与系统 | `org.ouyoji.dunhuang`，`4.0.0` / `40000`，最低 API 24、目标 API 36，横屏，Android 游戏分类 |
| 签名与对齐 | `apksigner verify` 的 v2、v3 签名通过；`zipalign -c -P 16 4` 通过 |
| 原生包结构 | 含 `classes.dex` 与两个 ABI 的 `libgodot_android.so`；ARM64、ARM32 均存在；不含 HTML、JS、Wasm、工具链、测试、调试密钥 |
| 内容与许可 | 6 地点、11 活动、31 知识条目、12 历史事件、6 章节、18 相遇、3 封信、9 件装饰校验通过；中文字体及 OFL、PROVENANCE、Godot、Godot 第三方许可均在 APK 中 |
| 权限 | Android manifest 无 `uses-permission`；文件搬家使用系统选择器授予的单个 content URI 读写权限 |

同一最终 APK 在下述 Android 15 ARM64 模拟器完成以下验收：

- 冷启动成功，首页、世界、小游戏中文及图像正常显示。截图为 `test-results/android/home.png`、`world.png`、`minigame.png`，尺寸均为 2340×1080。
- 世界中打开行囊弹窗，单次 Android Back 只关闭弹窗；小游戏中单次 Back 只返回世界，进程保持运行。该检查覆盖了 `SceneTree.quit_on_go_back=false` 的真实 Android 行为。
- Home 切后台再回前台，保留同一进程并恢复世界；强制停止应用后冷启动，已获得的 1 枚活动印章仍保留。
- 从系统 DocumentsUI 导出 559 字节、`version=2` 的 JSON，再通过系统选择器导入刚导出的文件，界面提示合并成功；文件保留 `completed: ["pack"]`，无需外部存储权限。
- 最终应用进程日志未发现 GDScript 解析错误、脚本运行错误或致命崩溃。导出记录位于 `.toolchain/final-apk-verification.log`，结构报告位于 `.toolchain/apk-structure.json`，运行与 SAF 日志位于 `.toolchain/android-final-*.log`。

验收范围为 Android 15 ARM64 模拟器；ARM32 已检查打包结构，未另行运行。模拟器使用 `-no-audio`，本轮未做扬声器试听或实体手机验证。安卓手动流程不替代工程的完整自动化主线与活动测试。

## 本地 Android 模拟器

本次使用官方 Android Emulator `37.2.13`（build `16740729`，macOS ARM64），Google APIs Android 15 / API 35 ARM64 系统镜像 revision 9，Pixel 5 配置。`-accel-check` 返回 `Hypervisor.Framework OS X Version 26.3`，`sys.boot_completed` 返回 `1`。此环境完成了上方真实 APK 验收；验收后关闭本次创建的模拟器及专用 adb 服务，保留本地 AVD 供复验。

安装与启动命令如下；所有 AVD 数据留在 `.toolchain/`。模拟器使用独立 adb 5038 端口，避免操作其他已连接设备。

```sh
export JAVA_HOME="$PWD/.toolchain/jdk17/Contents/Home"
export ANDROID_HOME="$PWD/.toolchain/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$PWD/.toolchain/android-user"
export ANDROID_EMULATOR_HOME="$ANDROID_USER_HOME"
export ANDROID_AVD_HOME="$PWD/.toolchain/android-avd"
export ANDROID_ADB_SERVER_PORT=5038
export ADB_SERVER_SOCKET=tcp:localhost:5038

"$ANDROID_HOME/cmdline-tools/19.0/bin/sdkmanager" --sdk_root="$ANDROID_HOME" \
  --install 'emulator' 'system-images;android-35;google_apis;arm64-v8a'
# 仅首次创建；已有此 AVD 时跳过下一条，不加 --force。
printf 'no\n' | "$ANDROID_HOME/cmdline-tools/19.0/bin/avdmanager" create avd \
  --name ouyoji_api35 --package 'system-images;android-35;google_apis;arm64-v8a' \
  --device pixel_5 --path "$ANDROID_AVD_HOME/ouyoji_api35.avd"
"$ANDROID_HOME/emulator/emulator" -avd ouyoji_api35 -port 5554 \
  -no-window -no-audio -no-boot-anim -no-snapshot -gpu host
```

另一个使用相同局部环境变量的终端可执行：

```sh
"$ANDROID_HOME/platform-tools/adb" -s emulator-5554 shell getprop sys.boot_completed
"$ANDROID_HOME/platform-tools/adb" -s emulator-5554 install --no-incremental -r builds/ouyoji-android-debug.apk
"$ANDROID_HOME/platform-tools/adb" -s emulator-5554 shell am start \
  -n org.ouyoji.dunhuang/com.godot.game.GodotAppLauncher
"$ANDROID_HOME/platform-tools/adb" -s emulator-5554 emu kill
# 仅关闭上述环境变量指定的专用 5038 服务。
"$ANDROID_HOME/platform-tools/adb" kill-server
```

本次额外安装包也与 Google 官方 SHA1 匹配，并记录以下 SHA256：

- [emulator-darwin_aarch64-16740729.zip](https://dl.google.com/android/repository/emulator-darwin_aarch64-16740729.zip)：`9e50ac521c38949d412f69250c0df9a4afa684d5be54ab4b80fc0205a73f5054`。许可：GPL-2.0 及随附第三方声明，仅作为开发工具。
- [arm64-v8a-35_r09.zip](https://dl.google.com/android/repository/sys-img/google_apis/arm64-v8a-35_r09.zip)：`d2e7c6076e5df54d3677605a324daf9edf813b2808c216bdb1687f6b2b6aed99`。许可：Android SDK / Google APIs 系统镜像许可，仅供本地测试。

## 官方参考

- [Godot 4.7.2 下载归档](https://godotengine.org/download/archive/4.7.2-stable/)
- [Godot 4.7.2 官方 SHA512](https://github.com/godotengine/godot/releases/download/4.7.2-stable/SHA512-SUMS.txt)
- [Godot Android 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Godot Android 导出配置](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformandroid.html)
- [Godot 独立编辑器数据目录](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html#self-contained-mode)
- [Eclipse Adoptium 官方 API](https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=aarch64&image_type=jdk&os=mac&vendor=eclipse)
- [Google SDK 官方仓库清单](https://dl.google.com/android/repository/repository2-1.xml)
- [Android SDK 管理器](https://developer.android.com/tools/sdkmanager)
- [Android SDK 许可](https://developer.android.com/studio/terms)
- [Android 模拟器命令行](https://developer.android.com/studio/run/emulator-commandline)
- [Android 模拟器加速](https://developer.android.com/studio/run/emulator-acceleration)

## 4.1《寻纹听铃》更新

4.1 的安装包为 `builds/ouyoji-4.1.0-android.apk`，版本 `4.1.0` / `40100`。资源检查及从 4.0 原位升级的实测见 [Android 4.1 验收](android-4.1.md)。

## 4.2《四时山河》更新

4.2 版脚本输出 `builds/ouyoji-4.2.0-android.apk`，版本 `4.2.0` / `40200`。沿用之前的应用 ID 与本地调试签名，从本工程先前交付的安装包直接升级。景点扩展的 19 份数据、57 项观察、四季画景及环境声均随包离线分发。`python3 tools/export-verify.py builds/ouyoji-4.2.0-android.apk` 检查 APK 内资源，`python3 tools/package-source.py` 生成独立源码包及 SHA-256。具体设备、升级路径和触摸记录见 [Android 4.2 验收](android-4.2.md)。

## 4.3《旅伴有灵》更新

本版导出为 `builds/ouyoji-4.3.0-android.apk`（40300）。保留既有包名和本地调试签名。导出检查会从 APK 的资源映射定位两位旅伴每件分层画稿、动作脚本、八个原创拟音和各自的导入二进制。源码归档文件名为 `ouyoji-godot-source-4.3.0.zip`。
