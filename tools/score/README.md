# 寻纹听铃 · 原创配乐

4.2《四时山河》让旅途的配乐在不同实景中有不同的听感。月牙泉让细沙和近水同响，胡杨林让树叶声盖在湖声上方，榆林窟保留溪流的底声。春夏秋的晨鸟、夏夜的虫声会跟随所处环境加入。全部七份环境音可使用 `python3 tools/score/render_landscapes.py` 以固定种子重建，依赖 NumPy 与 SoundFile，仅在制作时使用。[环境声源文件](../../assets/landmarks/sounds)

[听《六纹合奏》MP3](seal-song-preview.mp3)。26.40 秒。开头用筝与一声小铃奏出出发主题，六站依次应答，回到地图的 D 宫主题，最后由笛、弓弦和分解和弦收住尾音。游戏使用同一混音的 [Vorbis 原轨](../../assets/score/seal_song.ogg)。

| 场景 | 曲名 | 调式与速度（四分音符/分钟） | 听觉线索 |
| --- | --- | --- | --- |
| 地图 | 一盏灯出发 | D 宫，76，4/4 | 气声笛从弱拍起，右侧筝回应 |
| 武威 | 驼铃小步 | G 宫，96，4/4 | 两次同音拨弦起步，尾拍留给簧管 |
| 张掖 | 小水渠绕弯 | D 多利亚，79，6/8 | 弦音沿小三度上行到明亮的大六度 |
| 酒泉 | 泉眼里的铜星 | A 羽，70，6/8 | 金石敲击响过半拍，留空再落回泉眼 |
| 嘉峪关 | 关门开一扇 | C 混合利底亚，90，7/8 | 簧管跨五度，弹拨和软鼓按二、二、三分组 |
| 瓜州 | 弦上瓜藤 | E 商，94，4/4 | 休止后连续下行三音，弱拍反弹，弓弦接句 |
| 敦煌 | 石壁上的月色 | F 徵，66，4/4 | 长弓与短铃交替，乐句之间留出长呼吸 |
| 终章 | 六盏灯回家 | D 宫，72，6/8 | 笛将地图主题倒转下行，弓弦回应 |

每站纹印采用该站第一小节独有的音程和节奏。印谱独奏、地图配乐和终章通过相同主题彼此呼应。旋律、演奏参数、编码前音频均由本工程生成。弹拨、筝、笛、簧管、弓弦、金石、低音弹弦、木块和软鼓均为数字模拟音色。没有使用商业采样、外部录音或已发表乐曲。

## 重建和检查

游戏内没有 Python 依赖。开发机音频生成使用 Python 3.9、NumPy 2.0.2、SoundFile 0.13.1、libsndfile 1.2.2。提供这些开发依赖后，在 Godot 工程目录运行下列命令。

```sh
python3 tools/score/render.py
python3 tools/score/check_audio.py
tools/godot.sh --headless --editor --path . --import
tools/godot.sh --headless --path . --script tests/test_score.gd
tools/godot.sh --headless --path . --script tests/test_audio.gd
```

[分谱](score.py) 使用各调式音级记录八个小节的旋律、低音与伴奏重音。[合成器](render.py) 对拨弦建模拨弦位置、双弦微失谐和泛音衰减，对吹管与弓弦建模起音、气息和渐入揉音。左右声像及六个早期反射模拟小室内的空间。固定表演随机种子，采样率为 24 kHz，双声道。

每个循环导出两轨。静止时只有主轨，行走或解谜时伴奏逐渐进入。Godot 的 AudioStreamSynchronized 从同一样本播放两轨，关掉伴奏时它继续走拍。两个音乐播放器交叉淡化，离开场景时记录播放位置。语音、演奏和纹印试听按优先级让背景音乐降低，退到后台会停止短音和合奏。参考 [Godot 同步音轨接口](https://docs.godotengine.org/en/stable/classes/class_audiostreamsynchronized.html) 与 [Vorbis 循环接口](https://docs.godotengine.org/en/stable/classes/class_audiostreamoggvorbis.html)。

[声学检查](check_audio.py) 逐轨解码最终 Vorbis，输出采样帧数、绝对峰值和 RMS，检查双声道信号、每对采样帧数相同、循环边界、合成不削波、六条独立旋律以及全曲的尾音。Godot 检查同时使用 AudioEffectCapture 采集行走前后的混音输出的 RMS，并验证自然结束以及中断时的曲终信号。印谱用 `is_seal_song_playing()` 读取当前状态，`seal_song_finished` 在全曲结束或被纹印、静音、切页、后台打断时只触发一次。

如需更新另附的 MP3 试听，可使用本机 FFmpeg。

```sh
ffmpeg -i assets/score/seal_song.ogg -codec:a libmp3lame -b:a 128k -metadata title="六纹合奏" -metadata album="欧哟几 · 敦煌奇游记" -y tools/score/seal-song-preview.mp3
```

## 旅伴的动作声

4.3 的六个落脚音区分布鞋和鹿蹄在轻沙、草叶、石路上的触地。画笔用两段力度渐变的擦纸声，颈铃有两次相继的轻碰。八个单声道拟音以 24 kHz PCM 保存，音谱可用 Python 标准库重新生成。脚步对准真实的支撑脚，近景铃声和笔声跟随动作中的挂点提示，行囊的“所有声音”控制它们。[拟音合成谱](compose_companion_foley.py)
