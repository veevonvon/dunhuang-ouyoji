# 离线素材与来源

4.2《四时山河》的 19 处景点各有春、夏、秋、冬四幅同机位插画。游戏用场景遮罩分别照亮天际、地貌、水面和树木，写生页的 304 幅小画由同一套游戏渲染器输出。标记的坐标与观察板图案按景点核对。七层风、沙、水、叶、庭院、鸟与虫的声音通过固定种子的本地乐谱脚本合成。[四时取材](../docs/landmark-sources.md) · [生成环境声](../tools/score/render_landscapes.py)

4.1《寻纹听铃》另含 30 张新绘的封面、纹印、肖像及物件，2 张原创机关画带与 28 段配乐文件。配乐在游戏中按场景和操作变化。分发的 APK 使用新场景配乐，开发源码另存旧主旋律以便比较。[插画说明](edition/README.md) · [音乐制作](../tools/score/README.md) · [标题字体来源](../docs/references.md)

本目录保留上层原版 `public/canvas` 的已优化文件，迁移时没有重新编辑图像或重新生成声音。`manifest.json` 记录每个文件的原路径、字节数和 SHA-256。

| 内容 | 数量 | 本工程路径 | 来源 |
| --- | ---: | --- | --- |
| 原创插画 | 13 | `images/` | 原版会话 ImageGen 创作；PNG 人物与 JPG 场景原样迁移 |
| 原创场景配乐 | 8 | `music/` | 原版 `src/music/scores.ts` 乐谱与数字合成；保留现有 MP3 |
| 营地音符 | 15 | `notes/` | 原版程序合成，三种音色各五个音符 |
| 固定中文朗读 | 122 | `voice/` | 原版 `scripts/canvas/prepare-assets.mjs` 已生成的本地朗读 MP3 |
| 中文字体 | 1 | `fonts/chinese.ttf` | 官方 Google Fonts Noto Sans SC；SIL OFL 1.1，见 [字体来源](fonts/PROVENANCE.md)及[完整许可](fonts/OFL.txt) |

原画不是文物照片、受保护壁画的扫描件或古曲复原；沿用原版项目的原创角色、虚构居民与故事。历史卡片的原始资料链接完整保留在 `data/content.json`。原版创作记录见上层 `docs/references.md`、`docs/art-v2.md`、`docs/music-v2.md`。

迁移与字节一致性校验：

```sh
/opt/homebrew/opt/node@24/bin/node --experimental-strip-types tools/migrate-content.mjs
/opt/homebrew/opt/node@24/bin/node --experimental-strip-types tools/migrate-content.mjs --check
```

导出 APK 包含 `data/*.json`、字体许可与来源文件、Godot 引擎及第三方许可。游戏播放图音、查阅中文内容和保存旅行均不需要网络；字体已覆盖迁移内容中的全部 905 个不同中文字。

独立源码包的离线校验使用 `python3 tools/check-assets.py`，无需上层工程。`migrate-content.mjs` 仅供需要重新从旧版迁移时使用，要求上层原版 TypeScript 工程和 Node 24。
