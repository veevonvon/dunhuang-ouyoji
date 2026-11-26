# 中文字体来源

字体：Noto Sans SC 可变 TrueType 字体（简体中文）。原始字体二进制未修改，仅将文件名改为 `chinese.ttf`。

- 官方上游：[Google Fonts / Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc)
- 下载地址：[NotoSansSC[wght].ttf](https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf)
- 许可：[SIL Open Font License 1.1](OFL.txt)，原始版权声明与完整许可随项目和 APK 一同分发。
- 获取日期：2026-11-19。
- SHA-256：`a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da`
- 文件字节数：17,772,300。

此字体可随应用捆绑分发；本项目没有售卖字体本身，也没有改变字体内部名称或字形。

原字体 `wght` 轴范围为 100–900、默认 100。`chinese_regular.tres` 是 Godot 的 FontVariation 资源，选择中字重 500 以便儿童界面清晰显示；它只选择字体内已有字重，不修改字体二进制。使用整数 OpenType 标签 `2003265652`（`wght`）选择轴，并通过 TextServer 实际坐标验证，避免字符串标签在当前引擎中静默回落到细体。用法依据 [Godot FontVariation 官方文档](https://docs.godotengine.org/en/stable/classes/class_fontvariation.html)。
