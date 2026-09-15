shader_type canvas_item;

// 教程遮罩：整屏压暗，只在 hole_rect（控件本地像素坐标，x/y/w/h）处挖一个圆角洞，
// 洞边缘描一圈金色光边。rect_size 是承载它的 ColorRect 尺寸，用 UV 反推像素位置，
// 这样窗口缩放（canvas_items 拉伸）时洞的位置仍跟设计分辨率坐标一致。
uniform vec2 rect_size = vec2(1920.0, 1080.0);
uniform vec4 hole_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform float corner_radius = 22.0;
uniform float feather = 3.0;
uniform vec4 dim_color : source_color = vec4(0.05, 0.08, 0.05, 0.74);
uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.45, 0.95);
uniform float rim_width = 4.0;
uniform float rim_glow = 26.0;

float sd_round_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}

void fragment() {
	vec2 p = UV * rect_size;
	vec4 result = dim_color;
	if (hole_rect.z > 0.0 && hole_rect.w > 0.0) {
		vec2 half_size = hole_rect.zw * 0.5;
		vec2 center = hole_rect.xy + half_size;
		float radius = min(corner_radius, min(half_size.x, half_size.y));
		float d = sd_round_box(p - center, half_size, radius);
		float inside = 1.0 - smoothstep(0.0, feather, d);
		result.a = dim_color.a * (1.0 - inside);
		// 光边：紧贴洞外沿的一圈实线，再往外一段柔光。
		float rim = 1.0 - smoothstep(0.0, rim_width, abs(d - rim_width * 0.5));
		float glow = (1.0 - smoothstep(0.0, rim_glow, d)) * step(0.0, d) * 0.35;
		float rim_mix = clamp(rim + glow, 0.0, 1.0) * rim_color.a;
		result.rgb = mix(result.rgb, rim_color.rgb, rim_mix);
		result.a = max(result.a, rim_mix);
	}
	COLOR = result;
}
