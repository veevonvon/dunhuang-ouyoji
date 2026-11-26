# 模块接口与文件所有权

运行时使用 GDScript。原版旅程从 `data/content.json` 读取，景点、时景笔记与采风来信从 `data/landmarks.json` 读取。

## 工具链任务

维护 `.toolchain/`、`tools/setup*`、`tools/godot*`、`tools/export*`、`export_presets.cfg` 与 `docs/toolchain.md`。本地固定 Godot 4.7.2、匹配导出模板、JDK 17 与 Android SDK。`tools/godot.sh` 透传引擎参数，`tools/export-android.sh` 输出 `builds/ouyoji-4.3.0-android.apk`。

## 旅伴演出

两位角色共用 `scripts/characters/travel_actor.gd`。骨架、表情与骨骼挂点随角色变换，已落下的脚印留在地上。世界、营地与绘本近景实例化同样的角色。控制器通过 `set_locomotion`、`perform`、`set_reduced_motion`、`set_active` 调用，猜动作只读取当前演出，不读写收藏。[动作和挂点约定](companions-4.3.md)

## 景点、四时与写生

- `scripts/landmarks/catalog.gd` 提供稳定的景点、站点和观察 ID，以及四季、四时的中文名和顺序。每处景点有三个带画面坐标的观察、八条时景笔记、一封列出两幅目标时景和一个观察 ID 的来信。资料出处保存在每个景点的 `source` 和 `sourceName`。
- `scripts/landmarks/scenery.gd` 按场景、季节、时辰选择同机位画作与环境光照，将触摸映射回当前画中位置。成功点击发出 `detail_requested`。观察板完成指定手势后发出 `solved`，主场景核对当前页面与景点，再调用保存服务。进入后台或打开弹窗会取消手指尚未完成的动作。
- `Journey.visit_landmark`、`set_landmark_sky`、`complete_landmark_detail`、`save_sky_print` 统一提交景点进度。旧 v1/v2 存档兼容可选的 `atlas` 字段，内含 `lastSite` 与按稳定 ID 保存的 `places`。每页记录 `season`、`phase`、`details`、`prints`。时景组合示例为 `summer:dawn`。相同观察与小画合并后只占一格，采风印由本页收藏推导。主线按已发现细节的不同景点计数。
- `tools/render_field_prints.gd` 从游戏本身渲染写生页的 4 × 4 小画。修改画作、遮罩或环境光照后，在本机执行 `tools/godot.sh --path . --script tools/render_field_prints.gd`，再让编辑器重新导入资源。相同命令追加 `-- --verify-prints` 会逐格比较实际加载的小画与新渲染的风景。

## 纹印与音乐

`scripts/trails/trail_catalog.gd` 将六个稳定站点 ID 与机关、风景 ID、纹印名和提示关联。机关只发出解谜信号，由主场景核对当前页面与站点，再交给 `Journey.collect_seal(station)`。首次成功将纹印、风景和关联知识一起保存。行囊 v2 的 `journey.trailSeals` 是可选字段，旧行囊按空列表读取，合并导入按站点去重。

`scripts/audio/audio_director.gd` 负责场景配乐、同步伴奏、短反馈和印谱合奏。世界节点只上报走动状态，机关只上报进展、提示与失误。印谱按是否集齐六枚控制合奏入口，监听 `seal_song_finished` 在自然结束或中断后恢复播放按钮。

## 内容与领域任务

拥有 `data/`、`assets/`（除生成图标）、`scripts/core/`、`tests/test_domain.gd`、`tools/migrate-content.mjs`。迁移原版 content/adventure/camp 数据及已有图片、MP3；取得可再分发中文字体和许可证。

- `scripts/core/content_db.gd`：Node，autoload 名称 Library；`data: Dictionary` 包含 stages、activities、facts、historyEvents、chapters、encounters、letters、decorations、campNotes、campVoices、campSpots；`all(collection: String) -> Array`，`by_id(collection: String, id: String) -> Dictionary`，`image_path(id: String) -> String`，`voice_path(id: String) -> String`。
- `scripts/core/progress_store.gd`：Node，autoload 名称 Journey；`progress: Dictionary` 与原版 v2 的键相同；signals `changed`、`save_failed(message: String)`；`start_journey()`、`visit(encounter_id: String)`、`answer(stage_id: String, choice_id: String)`、`complete_game(game_id: String)`、`can_claim(stage_id: String) -> bool`、`claim(stage_id: String) -> bool`、`has_ending() -> bool`、`accept_letter(id: String, gift: String) -> bool`、`deliver_letter(id: String, stage: String) -> bool`、`available_decorations() -> Array`、`place_decoration(id: String, slot: String) -> bool`、`set_camp(field: String, value: Variant)`、`set_paint(index: int, color: String)`、`set_setting(key: String, value: Variant)`、`finish_ending()`、`export_json() -> String`、`import_json(text: String) -> Dictionary` 返回 ok/error，`save() -> bool`。规范化代码可单独拆分。
- 图片标准路径 `res://assets/images/{id}.jpg`，boy/deer 为png；音乐 `res://assets/music/{id}.mp3`；语音 `res://assets/voice/{id}.mp3`；音符 `res://assets/notes/{bell|wood|lute}-{0..4}.mp3`；字体 `res://assets/fonts/chinese.ttf`（若 OTF 更合适及时通知）。

## 玩法任务

仅拥有 `scripts/games/`、`scenes/games/`、`tests/test_games.gd`。`scripts/games/minigame_view.gd` extends Control，class_name MiniGameView；`configure(game_id: String, content: Dictionary, progress: Dictionary) -> void` 在add_child前调用；signals `finished(game_id: String)`、`back_requested`、`narration_requested(id: String)`、`note_requested(note: int, voice: String)`、`paint_changed(index: int, color: String)`。所有玩法入口由一个模块负责，可拆游戏类，避免千行单文件。

协调者提供 `scripts/ui/game_theme.gd` class_name GameTheme：static `make() -> Theme`、`button(text: String, callback: Callable, min_size := Vector2(156, 64), accent := false) -> Button`、`label(text: String, font_size := 24, color := Color("f6e6c3")) -> Label`、`panel(dark := false) -> PanelContainer`、`margin(amount := 20) -> MarginContainer`、`icon(name: String, size := Vector2(36, 36)) -> Control`。完整屏幕布局使用1280×720及更宽横屏，顶部预留返回/标题，底部提示，游戏本体充足空间；通过 Container 自适应，不直接搬竖屏 Canvas 坐标。玩法自身不得写存档，使用上述 signals。

## 主协调者

拥有 `project.godot`、`scenes/main.tscn`、`scenes/world/`、`scripts/main.gd`、`scripts/world/`、`scripts/ui/`、`scripts/audio/`、其他集成测试/文档/交付。负责首页、世界、地图、营地、作曲、历史图鉴、对话、主线与跨站问候、触摸/安全区、运行截图、审核修复和最终打包。
