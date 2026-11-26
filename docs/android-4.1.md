# 《寻纹听铃》Android 4.1 验收

日期：2026-11-19。工具链沿用 [本地 Godot / Android 工具链](toolchain.md) 的官方 Godot 4.7.2、JDK 17、Build-Tools 36.0.0 与 API 36。全部操作在本机完成，无上传或发布。

## 版本与导出

在工程根执行 `tools/export-android.sh`，新版输出为 `builds/ouyoji-4.1.0-android.apk` 及同名 SHA256 文件。包名仍为 `org.ouyoji.dunhuang`，版本 `4.1.0` / `40100`，沿用 `.toolchain/signing/debug.keystore` 的原调试签名。导出器检查签名、16 KB 对齐、ARM64 + ARM32、横屏、原生 Godot Activity 与零应用权限。

旧版 `builds/ouyoji-android-debug.apk` 和 `builds/ouyoji-godot-source-4.0.0.zip` 保留；源码打包器的新目标为 `builds/ouyoji-godot-source-4.1.0.zip`。

新增 APK 检查覆盖：

- 原有离线 13 张插画、15 个音符样本、122 段旁白；检查每项导入映射及实际二进制资源。
- `assets/edition/` 开场图、6 枚纹印、6 位朋友，以及实际存在的 17 张物件贴图（包括绢面底图与翻牌背面）。
- `assets/score/` 的 28 个 Ogg 资源：8 站景 × 2 层、6 枚纹印动机、1 首合奏、5 个回应音。
- 2 张寻纹机关画卷、7 个寻纹原生 GDScript 模块及纹印谱界面。
- 两套中文字体；随包 OFL、TITLE-OFL、字体来源、Godot 及第三方许可证与工程原文件逐字节一致。

已停用的 `assets/music/` 8 个 MP3 仅从 APK 排除，源工程保留。测试、工具、文档、截图、构建输出与工具链不进入 APK；不会捆绑 HTML、JavaScript、Wasm 或签名密钥。

## 升级验收环境

最终复测新建隔离 AVD `ouyoji_final41`：Android Emulator 37.2.13、Android 15 / API 35 Google APIs ARM64 revision 9、Pixel 5；专用 adb 端口 5038、设备 `emulator-5556`。本轮以正常音频配置启动，未使用 `-no-audio`。此前 `ouyoji_api35` 的 4.1 测试存档保留，本次未启动或改写该 AVD。

在新设备安装原始 `4.0.0` / `40000` APK，从首页出发进入武威「帮朋友」，实际点击水壶、粮食、丝绸、书卷完成小游戏并获得旧印章。升级前通过应用自己的调试 `run-as` 读取私有 `files/progress.json` 留档，原文件 559 字节、schema version 2，包含 `completed: ["pack"]` 与 `discoveries: ["silk"]`。随后不卸载应用、不清除数据，直接升级最终 4.1；全程不向存档注入测试状态。

升级命令使用同一签名的替换安装：

```sh
export ANDROID_USER_HOME="$PWD/.toolchain/android-user"
export ADB_SERVER_SOCKET=tcp:localhost:5038
TASK_ADB="$PWD/.toolchain/android-sdk/platform-tools/adb"
"$TASK_ADB" -s emulator-5556 install --no-incremental -r builds/ouyoji-4.1.0-android.apk
"$TASK_ADB" -s emulator-5556 shell am start -W \
  -n org.ouyoji.dunhuang/com.godot.game.GodotAppLauncher
```

## 最终 APK

| 项目 | 实测结果 |
| --- | --- |
| 文件 | `builds/ouyoji-4.1.0-android.apk` |
| 字节数 | 101,541,916 |
| SHA256 | `723373b4e47039ab95e54b5053383e88fa057d55a1fde93dcea527b0ac9c89ec` |
| 签名证书 SHA256 | `b48cd53d0555cfe8d5d587aabc19b350000139ab90ed2e701eaf44a8a68c0323`，与 4.0 完全相同 |
| Android | 最低 API 24、目标 API 36；ARM64 + ARM32；横屏；游戏分类；无 `uses-permission` |
| 导出检查 | 完整 `tools/export-android.sh` exit 0；v2/v3 签名、16 KB 对齐、ZIP CRC、全部上述资源与排除规则通过 |

实际升级使用 `install --no-incremental -r`，安装成功，设备报告版本 `40100` / `4.1.0`。安装后、第一次启动前的私有存档与升级前逐字节相同。

## 实际触摸与生命周期

以下均在上述最终 APK 上，通过 Android 系统输入进入正常产品界面；未调用游戏调试入口或修改存档：

1. 首页「继续旅行」进入武威，点击右下角「寻纹」进入「沙上驼踪」。依次触摸画卷上的五处蹄印和驼铃，出现「拓得驼铃纹」；打开纹印谱后显示「已拓 1 / 6 枚」，驼铃纹标为「已拓印」。
2. 在印谱中连续两次点击「听纹音」，界面保持可用，应用日志无音频资源加载错误或 GDScript 错误。
3. 打开行囊后单次 Android Back 只关闭弹窗；再按一次从印谱返回武威。重新进入寻纹后单次 Back 只返回武威，进程没有退出。
4. Home 切后台再返回，保持同一进程与世界画面。AudioFlinger 的应用 44.1 kHz AudioTrack 在后台为 `Active=no`、状态 `P`、增益 `-inf`；回前台为 `Active=yes`、状态 `A`。采样记录的 underrun 数为 0。
5. 返回首页，按 Android Back 打开「要歇一会儿吗」，实际点击「下次再见」。应用正常返回 Android 桌面，原进程结束；退出日志没有 Godot 资源泄漏、原生资源未释放或脚本异常。随后再次正常启动并从首页打开印谱，驼铃纹仍在。私有存档保留旧 `pack` 印章、`silk` 发现、全部声音设置和营地数据；新增 `journey.trailSeals: ["wuwei"]`，并增加 `camel` 风景发现。

普通 Android 冷启动实际使用系统音频输出，应用 AudioTrack 活跃；未指定 Dummy 音频驱动。启动、通关/重听、后台恢复、正常告别和重新启动日志未发现 Godot 警告、脚本解析错误、GDScript 运行错误或致命崩溃。退出时模拟器另记录一条 `eglCodecCommon removeVertexArrayObject` 清理信息，随后完成 `OnGodotTerminating`，重新启动成功；该记录没有被计作 Godot 音轨资源泄漏。

## 截图与证据

以下五张实际 Android 截图均已用上述最终 SHA256 对应的 APK 重新拍摄，尺寸为 2340×1080：

- [首页](../test-results/android-4.1/home.png)
- [武威世界](../test-results/android-4.1/world.png)
- [进入寻纹机关](../test-results/android-4.1/trail.png)
- [解完获得驼铃纹](../test-results/android-4.1/trail-complete.png)
- [已获得纹印的印谱](../test-results/android-4.1/album.png)

本次最终详细证据保存在 `.toolchain/android-4.1-final/`：`export-verification.log`、旧版自然通关截图、升级前后私有存档副本、`startup.log`、`runtime-exit.log`、`restart.log`、前后台 AudioFlinger 记录，以及返回、告别和复启截图。结构与完整资源报告为 `.toolchain/apk-structure-4.1.json`。之前版本的 APK 与五图副本也保存在该本地目录，原先完整回归日志保留在 `.toolchain/android-4.1/`；本文最终结果与五张交付截图均以本次最终包为准。这些开发记录不打入 APK 或源码 ZIP。

验收后关闭本次 `emulator-5556` 和专用 adb 5038 服务，保留两个 AVD 的各自数据。验证范围为 Android 15 ARM64 模拟器；ARM32 与 API 24 只验证打包声明，未在对应设备运行。未进行实体手机或扬声器音质试听；手机侧手动完成武威寻纹，不将其描述为六站全部手动通关。
