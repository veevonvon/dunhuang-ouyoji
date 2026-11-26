# 内容与兼容存档

`landmarks.json` 是 4.2 的景点目录。每个景点保存真实名称、旅途站点、资料来源、3 项观察及其画面坐标、4 条季节与 4 条时辰笔记，还有鹿铃来信要求的 2 幅小画和 1 项发现。详情见 [逐处取材说明](../docs/landmark-sources.md)。

4.2 会在 v2 行囊中添加可选的 `atlas`。每处的季节、时辰、已发现的细节与写生小画可随行囊搬家。采风印由这三项实际收藏推出，19 处都可自由回访。已完成任一观察的景点可以为本站风铃计一次发现。

`content.json` 直接从原版 TypeScript 模块导出，保留六个站点、六章故事、十八处发现、三十一张知识卡、十二段历史、十一种玩法、三封问候、九件摆设及营地音符/位置/音色数据。原版中文正文与出处没有重写。`images`、`voices` 只把原版路径映射到 Godot 离线资源；`voiceLines` 保留朗读对应文本。

`Library` 提供内容索引，`Journey` 提供存档与领域操作。`Journey.normalize(raw)` 只规范化、不写盘；`save_path` 默认 `user://progress.json`，可在节点挂载前改为独立路径。实际调用按 `docs/contracts.md`，接取问候必须提供正确礼物，送达必须提供收件站点。`place_decoration("", slot)` 表示收回该位置的摆设。

存档沿用原版 v2 键，接受 v1/v2 导出文件。导入会合并双方已完成活动、知识发现、主线进度与问候；旧版或未自定义的营地不覆盖当前创作，明确自定义的导入营地按原版规则生效。所有外来 ID、颜色、音符、布尔与奖励前提均在边界规范化。风铃必须按章节顺序，完成对话、至少两处本地发现和指定玩法；酒泉指定玩法为公平集市 `trade`。

每次写入先完成同目录临时文件、flush 与读回验证，再更新上一个有效存档的 `.bak`，最后 rename 替换主文件。备份恢复不会把损坏主文件覆盖到好备份。主文件和备份均损坏时停止自动写盘，保留原文件并允许导出本次内存进度；无效导入和写入失败的导入均不改变已有好进度。

相关官方接口：[FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)、[DirAccess](https://docs.godotengine.org/en/stable/classes/class_diraccess.html)，核查日期 2026-11-19。实现只使用引擎接口，未复制外部存档库。

领域验证命令：

```sh
tools/godot.sh --headless --path . --script tests/test_domain.gd
```

测试只在 `user://domain-tests-{进程号}/` 中创建与删除自己的数据。已执行缺失实现的 RED 与实现后的 GREEN，并对恶意字段类型、真实临时文件/备份写入失败、重新加载、损坏备份保护、完整六章与全部十一种活动进行验证。这里的文件系统验证基于 macOS Godot 4.7.2；安卓生命周期、真机断电和安装验证由整体验收另行记录。
