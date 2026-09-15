// 展柜台面：奶油底色上下渐变 + 屏幕空间的波点桌布 + 一点暗角。
//
// 点子按像素画在屏幕空间里，所以不管相机怎么俯视都是正圆，像海报底纹；台面仍是受光的
// 3D 平面，小岛的影子照样落在点子上。三种点色取自展品配色（沙、灰绿、陶土），对比很低，
// 主角还是小岛。dot_drift 让点阵极慢地漂，静止截图看不出，盯着看会活。
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform vec4 base_far : source_color = vec4(0.965, 0.94, 0.89, 1.0);
uniform vec4 base_near : source_color = vec4(0.925, 0.885, 0.815, 1.0);
uniform vec4 dot_sand : source_color = vec4(0.905, 0.86, 0.77, 1.0);
uniform vec4 dot_sage : source_color = vec4(0.80, 0.84, 0.72, 1.0);
uniform vec4 dot_clay : source_color = vec4(0.94, 0.83, 0.75, 1.0);
uniform float dot_spacing = 78.0;
uniform float dot_radius = 10.0;
uniform float dot_softness = 1.2;
uniform float dot_strength : hint_range(0.0, 1.0) = 0.7;
uniform vec2 dot_drift = vec2(3.0, 2.0);
uniform float vignette : hint_range(0.0, 0.5) = 0.10;
uniform float exposure = 0.95;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// 屏幕像素坐标，按 1080p 归一：不同分辩率下点子看起来一样大。
	vec2 px = (FRAGCOORD.xy + dot_drift * TIME) * (1080.0 / VIEWPORT_SIZE.y);
	float row_h = dot_spacing * 0.866;
	float row = floor(px.y / row_h);
	float shift = mod(row, 2.0) * 0.5 * dot_spacing;
	vec2 cell = vec2(mod(px.x + shift, dot_spacing), mod(px.y, row_h));
	vec2 id = vec2(floor((px.x + shift) / dot_spacing), row);
	float h = hash21(id);
	float h2 = hash21(id + vec2(17.0, 29.0));
	float radius = dot_radius * (0.78 + 0.44 * h2);
	float d = length(cell - vec2(dot_spacing * 0.5, row_h * 0.5));
	float disc = 1.0 - smoothstep(radius - dot_softness, radius + dot_softness, d);
	vec3 dot_col = h < 0.58 ? dot_sand.rgb : (h < 0.84 ? dot_sage.rgb : dot_clay.rgb);
	vec3 base = mix(base_far.rgb, base_near.rgb, smoothstep(0.3, 0.85, uv.y));
	vec3 col = mix(base, dot_col, disc * dot_strength);
	float v = length((uv - vec2(0.5)) * vec2(1.0, 0.85));
	col *= 1.0 - vignette * smoothstep(0.4, 0.95, v);
	ALBEDO = col * exposure;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
