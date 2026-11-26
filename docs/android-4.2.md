# 《四时山河》4.2.0 安卓验收

2026 年 11 月 20 日，在 Android 15 / API 35、ARM64 的 Pixel 5 配置模拟器上，将原版 4.1 原位升级至最终 4.2.0。启用飞行模式并关闭 Wi-Fi，Android 确认没有默认网络。随后通过系统触摸输入完成月牙泉采风、莫高窟三兔、两处倒影及雅丹夜游，再冷启动读回新旧收藏。

## 安装包与旧存档

| 项目 | 结果 |
| --- | --- |
| 安装包 | `builds/ouyoji-4.2.0-android.apk`，247,055,829 字节 |
| SHA256 | `02d205f183728dd447a5fd40cef9a95b5bb23b7a3e59e96c52a58611903d185f`，设备安装后的 `base.apk` 与交付文件一致 |
| 应用 | `org.ouyoji.dunhuang`，`4.2.0` / `40200`，最低 API 24、目标 API 36，横屏，ARM64 与 ARMv7 |
| 签名 | 与 4.1 相同的本地调试证书，SHA256 为 `b48cd53d0555cfe8d5d587aabc19b350000139ab90ed2e701eaf44a8a68c0323`，v2/v3 验证及 16 KB 对齐通过 |
| 导出验证 | `tools/export-android.sh` 退出码 0；包内 19 处景点、57 项观察、76 幅季节画及对应遮罩、19 张写生图版、7 段环境声均通过资源核验。Android manifest 未申请应用权限，包括网络权限 |

专用 AVD `ouyoji_final42` 使用停机状态的 4.1 测试设备克隆。旧包与原交付 SHA256 一致，旧印谱中可见已拓的武威驼铃纹。旧 `files/progress.json` 共 624 字节，含 `pack` 印章、`silk` / `camel` 发现、`wuwei` 纹印、营地和声音设置。使用 `adb install --no-incremental -r` 覆盖安装，并在第一次启动前以 `run-as` 只读取回存档。安装前后逐字节相同，SHA256 均为 `105c2793402f24ee8f87762abcdd01132c5da55e0eabe0ffc275428d909cdc04`。最后重新核验了 4.0、4.1 的 APK 与源码 ZIP 校验和。

## 触摸与画面

- 从首页点“四时山河”，选敦煌，点“鸣沙山月牙泉”。四次白天截图显示同一机位的嫩枝、浓绿、黄叶和冬季裸枝。实际页面上的季节、时辰、观察标记与底部按钮均可读可点。[首页](../test-results/android-4.2/home.png) · [敦煌目录](../test-results/android-4.2/dunhuang-atlas.png) · [春](../test-results/android-4.2/crescent-spring-day.png) · [夏](../test-results/android-4.2/crescent-summer-day.png) · [秋](../test-results/android-4.2/crescent-autumn-day.png) · [冬](../test-results/android-4.2/crescent-winter-day.png)
- 在鹿铃来信中读“月牙弯到哪”，收进夏晨和秋昏两幅时景。按照“左尖 → 弯心 → 右尖”触摸泉形图，写生页出现一件发现、两幅已留影和采风印。再点印章中的“重读鹿铃来信”，来信显示两种时景均已收、月牙弯岸已发现。[来信](../test-results/android-4.2/crescent-letter.png) · [夏晨](../test-results/android-4.2/crescent-summer-dawn.png) · [秋昏](../test-results/android-4.2/crescent-autumn-dusk.png) · [机关](../test-results/android-4.2/crescent-puzzle.png) · [采风印](../test-results/android-4.2/crescent-stamp.png) · [重读](../test-results/android-4.2/crescent-reread.png) · [写生页](../test-results/android-4.2/crescent-journal.png)
- 在莫高窟黄昏打开“莲心三兔”。点左页放大井心图，单次 Android 返回键收回大图，随后转正三块画片，取得发现。武威天梯山“库边倒影”和酒泉“水亭双影”各完成三组上下翻转配对，其中一组使用拖连。雅丹黑夜的星空、丘体和三处标记可辨，截图中未见画面被整行横线切断。[莫高窟](../test-results/android-4.2/mogao-dusk.png) · [三兔整图](../test-results/android-4.2/mogao-three-hares.png) · [库边倒影](../test-results/android-4.2/tiantishan-reflection.png) · [雅丹黑夜](../test-results/android-4.2/yardang-night.png)

## 后台和重新启动

雅丹春夜开启“时光流转”，按 Android Home 回桌面超过 20 秒，超过一个 18 秒时辰。返回后仍是同一进程、同一处春夜，页面仍显示“暂停流转”。切后台前、后台中、恢复后读回的进度逐字节一致。随后从景点按返回键回敦煌目录，再回首页，按返回并实际选择“下次再见”。系统回到桌面，游戏进程结束。

再次从系统启动，Android 报告 `COLD`，进程从 2673 换为 3675。刚冷启动时取回的 1,349 字节存档与退出前逐字节相同。再次进入武威纹印谱和月牙泉写生页，新旧收藏均能从界面打开。旧存档全部七个顶层字段的内容保持一致，新增的 `atlas` 保存月牙泉秋昏、两幅留影、`crescent_line`，也保存了莫高窟、天梯山和酒泉的观察记录及雅丹春夜。[复启后的旧印谱](../test-results/android-4.2/restored-trail-album.png) · [复启后的写生页](../test-results/android-4.2/restored-journal.png)

## 模拟器性能与运行记录

在 Apple M1 主机使用 Android Emulator 37.2.13、宿主 GPU 和 Godot 4.7.2 OpenGL ES 3 Compatibility。游戏横屏分辨率为 2340×1080。每项独立采样约 10 秒，FPS 以 Android SurfaceFlinger 的游戏 SurfaceView 帧数除以实测采样秒数计算。P95 取相邻呈现时间的直方图档位，PSS 取 Android 游戏进程的 `dumpsys meminfo`。数值会随宿主负载变化。[Android dumpsys 说明](https://developer.android.com/tools/dumpsys)

| 界面 | 帧数 / 秒数 | FPS | 帧间隔 P95 | 进程 PSS |
| --- | ---: | ---: | ---: | ---: |
| 首页 | 585 / 10.03 | 58.3 | 18 ms | 213.1 MiB |
| 月牙泉秋昏，首次采样 | 440 / 10.15 | 43.3 | 62 ms | 233.1 MiB |
| 月牙泉秋昏，冷启回访 | 599 / 10.03 | 59.7 | 17 ms | 232.8 MiB |
| 月牙泉写生页 | 596 / 10.04 | 59.4 | 17 ms | 247.9 MiB |
| 雅丹黑夜 | 599 / 10.03 | 59.7 | 17 ms | 253.4 MiB |

切季选单打开后，从发出 Android 点击到首次读到与新季节稳态画面匹配的连续两次采样中的第一帧，夏转冬、冬转秋、再次夏转秋的实测上界分别为 545、327、145 ms。方法从 Android 原尺寸截图的画面中部提取四行彩色像素，使用主机单调时钟计时，包含 adb 指令及取样传输开销。

一次持续读取原始视频帧的诊断中，宿主 QEMU 进程以 137（SIGKILL）退出，原因未确定。随后恢复同一 AVD 和已安装的 APK，使用单次取样完成上述游玩与冷启。按游戏进程筛查三段日志，未发现 GDScript 错误、Android 致命异常或原生崩溃。正常告别时，模拟器的 `eglCodecCommon` 记录一条 VAO 清理信息，随后 Godot 完成终止。模拟器音频 HAL 另有 PCM 输出 I/O 错误，本轮未核实实体设备的扬声器听感。ARMv7 和 API 24 的覆盖来自安装包结构，运行测试使用 Android 15 ARM64 模拟器。

设备证据位于工程本地 `.toolchain/android-4.2/final/`，包含安装前后进度、三段应用进程日志、签名和权限报告、实际帧统计及内存原始输出。交付截图位于 `test-results/android-4.2/`。测试使用的模拟器和专用 adb 5038 已关闭。
