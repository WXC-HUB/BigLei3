shader_type spatial;
// 世界地图的卡通风格化渲染（单面版：地格、建筑、道具、石头）。
//
// 光照走引擎自带的 diffuse_toon，这样 Compatibility 下树影和地格侧面才会吃到主光阴影。
// 自己写 light() 时 ATTENUATION 在 GLES3 上经常不带阴影，画面就会一整片一样亮。
// `specular_disabled` 是必须的：镜面高光会在平坦的六边形顶面上拖出一道亮斑。
// 调色与云影逻辑在 hex_toon_body.gdshaderinc，和树叶变体共用。
render_mode cull_back, diffuse_toon, specular_disabled;

#include "res://shaders/hex_toon_body.gdshaderinc"
