shader_type canvas_item;
// 解锁页「虚焦」：直接采屏幕纹理的高阶 mipmap，blur_lod 越大越糊。
// 铺在整页之上、眼镜之下，所以立绘、文字、背景图案一起糊，只有镜片里是清楚的。

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float blur_lod : hint_range(0.0, 6.0) = 0.0;

void fragment() {
	COLOR = textureLod(screen_texture, SCREEN_UV, blur_lod);
}
