shader_type spatial;
// 世界地图卡通渲染的树叶/花草变体：双面 + 贴图 alpha 裁切。
// Stylized Nature 的叶片是带透明通道的面片，单面版会把背面剔掉、把透明区画成黑块。
render_mode cull_disabled, diffuse_toon, specular_disabled;

#define FOLIAGE
#include "res://shaders/hex_toon_body.gdshaderinc"
