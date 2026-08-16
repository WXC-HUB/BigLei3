# 音频源文件

Godot 不支持 mp4/AAC 音轨，这里保留转码前的原始文件，导出时由 `.gdignore` 排除。

| 源文件 | 转出 | 用途 |
| --- | --- | --- |
| `44a046a753eb34851afa088560f19736.mp4` | `../credits_tender.ogg` | 制作人名单 BGM · 极致柔情 |
| `b3d4be0a2d8641bb91fad2862123f1a7_raw.mp4` | `../credits_hype.ogg` | 制作人名单 BGM · 劲爆男声 |

转码命令：

```sh
ffmpeg -i <源文件> -vn -c:a libvorbis -q:a 4 <目标.ogg>
```
