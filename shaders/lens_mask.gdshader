shader_type canvas_item;
// 只在两片圆镜片里显示贴图：坐标按控件本地像素算，和眼镜图上的镜片圆心、半径对齐。

uniform vec2 lens_a = vec2(200.0, 150.0);
uniform vec2 lens_b = vec2(560.0, 150.0);
uniform float radius = 122.0;
uniform float feather = 2.5;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float nearest = min(distance(local_pos, lens_a), distance(local_pos, lens_b));
	float inside = 1.0 - smoothstep(radius - feather, radius, nearest);
	vec4 source = texture(TEXTURE, UV);
	COLOR = vec4(source.rgb, source.a * inside);
}
