# 参考与许可

核对日期：2026-11-19。实现使用 Godot 原生 API，没有复制第三方游戏实现或引入游戏插件。

| 官方资料 | 本工程采用的部分 |
| --- | --- |
| [Godot 4.7.2 下载](https://godotengine.org/download/archive/4.7.2-stable/) | 标准版引擎及对应 Android 导出模板 |
| [Android 导出指引](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) | JDK、SDK、签名与预编译 APK 导出；实际模板使用 API 36，见工具链记录 |
| [多分辨率](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) | 1280×720、canvas_items、expand 的横屏布局 |
| [原生布局与锚点](https://docs.godotengine.org/en/stable/tutorials/ui/size_and_anchors.html) | Container、主题、长中文自动换行 |
| [Button](https://docs.godotengine.org/en/stable/classes/class_button.html) | 原生触摸按钮，使用最小尺寸与换行，不用固定字宽压缩 |
| [DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html) | Android 安全区、剪贴板 |
| [Camera2D](https://docs.godotengine.org/en/stable/classes/class_camera2d.html) | 世界镜头跟随、边界限制 |
| [InputEventScreenTouch](https://docs.godotengine.org/en/stable/classes/class_inputeventscreentouch.html) | 主手指捕获、多点与取消处理 |
| [SceneTree 返回键](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-property-quit-on-go-back) | 关闭默认自动退出，交由游戏逐层返回 |
| [FileDialog](https://docs.godotengine.org/en/stable/classes/class_filedialog.html) | 原生文件选择器、Android SAF、MIME 类型和中文文件名 |
| [Audio 总线](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html) | 本地音频与音量控制；本工程用两路播放器交叉淡入并实时压低旁白下的音乐 |
| [FontVariation](https://docs.godotengine.org/en/stable/classes/class_fontvariation.html) | 字体轴选择；实际运行验证整数 wght 标签与 500 字重 |
| [AudioStreamSynchronized](https://docs.godotengine.org/en/stable/classes/class_audiostreamsynchronized.html) | 4.1 用同步起播的主旋律与伴奏轨响应站立、行走、解谜 |
| [TextureRect](https://docs.godotengine.org/en/stable/classes/class_texturerect.html) 与 [StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html) | 透明插画等比显示，程序绘制双层金边、漆色按钮和绢页面板 |
| [Control 的焦点继承](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control-property-focus-behavior-recursive) | 打开行囊和对话时将焦点限制在弹窗，返回后交还原控件 |
| [Godot 许可说明](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html) / [Engine](https://docs.godotengine.org/en/stable/classes/class_engine.html) | 引擎 MIT 与第三方声明，通过引擎 API 导出完整文本并在游戏菜单提供入口 |

Godot 引擎采用 MIT 及随附第三方许可；本项目只使用公开 API，没有复制引擎内部实现。完整文本在 `assets/licenses/`。通过 `tools/write-licenses.gd` 可从相同版本引擎重建。

中文字体为官方 Noto Sans SC，SIL Open Font License 1.1。完整许可与原始版权保存在 `assets/fonts/OFL.txt`，固定 SHA-256、下载来源和字重选择在 `assets/fonts/PROVENANCE.md`。未修改字体二进制。

4.1 标题采用从 **Noto Serif SC** 制作的静态 700 字重子集，内部字体家族改名为 **Hexi Scroll Titles**。共包含 1,099 个 Unicode 字符，大小 483,800 字节，缺字由既有正文字体补充。原始字体 SHA-256 为 `050080d9255a86808f2945bffac582b31ef32bc36411ce29563b4961670c66f9`，4.1 分发的 `assets/fonts/scroll_titles.ttf` 为 `4c29d5061d257171047b438eb53fe8422f1f03e70095fdef2609a4729d0c1f1e`。来源核对于 2026-11-19，原始版权与完整 SIL OFL 1.1 许可随 APK 和源码一并提供。[Google Fonts 上游](https://github.com/google/fonts/tree/main/ofl/notoserifsc) · [随附许可](../assets/fonts/TITLE-OFL.txt)

4.2 补入新景点、写生题与建筑细节使用的汉字。标题字现含 1,352 个 Unicode 字符，大小 589,772 字节，SHA-256 为 `1805df2fbb46fb8e70e77d7fbf16dfb3eca79937dc258184ae02cbeab8abd8ba`。以相同上游文件运行 `tools/make-title-subset.py` 可重建。景点解说逐处列有资料出处。观景镜通过 Godot 的屏幕纹理读取当下画卷，使镜中的季节和时辰与周围一致。[景点来源](landmark-sources.md) · [Godot 屏幕纹理](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)

图片、场景、欧哟几、鹿铃、原创乐谱与已生成的朗读沿用原版项目，158 个文件逐字节一致。具体来源、路径和哈希见 `assets/README.md` 与 `assets/manifest.json`。历史文字和资料链接完整保留在 `data/content.json`，游戏内的“资料来源”按钮可查阅。

新增的绘卷、纹印、朋友及物件使用 ImageGen 为本游戏绘制。两幅寻纹画带在工程中绘制。八首场景曲、纹音和合奏使用项目自作的旋律、合成器与混音，源码附分谱及音频信号验证方法。[美术记录](../assets/edition/README.md) · [配乐记录](../tools/score/README.md)

JDK、Android SDK 和模拟器只用作本机开发工具，不包含在源码 ZIP 或 APK 中；版本、许可证和官方下载校验值在 `docs/toolchain.md` 与 `tools/setup-toolchain.json`。

4.3 的双角色沿用原画身份，新增的透明画稿由 ImageGen 辅助绘制，关节层级、布料权重、表情调度、眼睑、步态和触地特效在本项目制作。引擎接口依照 [Godot 二维骨骼](https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html)、[Bone2D](https://docs.godotengine.org/en/stable/classes/class_bone2d.html) 与 [Movie Maker 原生录制](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html)（2026-11-20 查阅）。布鞋、鹿蹄、画笔与铜铃声音来自项目自写的离线合成谱。[拟音谱](../tools/score/compose_companion_foley.py)
