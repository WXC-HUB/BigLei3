# Generated gameplay sprites

- `source/generated_sprite_atlas.png`：用户提供的原始图集，保留用于重新切图。
- `generated/*.png`：43 张已去除洋红背景的 256 × 256 RGBA Sprite。
- `generated/manifest.json`：语义名称、Godot `res://` 路径和原图位置。

原图前五行各有 7 个元素，最后一行有 8 个元素。切图脚本依据真实排布处理，而不是假设为等列的 8 × 6 图集。

重新生成：

```powershell
python tools/slice_generated_atlas.py assets/sprites/source/generated_sprite_atlas.png assets/sprites/generated
```

Godot 中直接通过 `manifest.json` 记录的路径加载即可。素材使用统一 256 × 256 画布，默认原点应设在中心；地格类素材可按格子完整尺寸显示，道具类素材保留了原图中的视觉留白。
