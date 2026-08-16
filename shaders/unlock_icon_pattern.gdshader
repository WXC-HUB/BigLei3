shader_type canvas_item;

uniform sampler2D icon_texture : source_color, repeat_disable, filter_linear;
uniform vec4 icon_color : source_color = vec4(0.92, 0.9, 0.78, 0.16);
uniform vec2 tile_count = vec2(6.0, 6.0);
uniform float motion_speed : hint_range(0.05, 1.0) = 0.2;
uniform vec2 travel = vec2(0.045, 0.028);

void fragment() {
	// Ping-pong with cosine easing: the icon field slows at both endpoints.
	float eased = 0.5 - 0.5 * cos(TIME * motion_speed);
	vec2 moving_uv = UV + mix(-travel, travel, eased);
	vec2 tiled = moving_uv * tile_count;
	float row = floor(tiled.y);
	// Offset alternating rows to avoid a rigid wallpaper-grid impression.
	tiled.x += mod(row, 2.0) * 0.5;
	vec2 icon_uv = fract(tiled);
	vec4 source_icon = texture(icon_texture, icon_uv);
	float luminance = dot(source_icon.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grayscale = vec3(luminance);
	vec3 decolored_icon = mix(grayscale, icon_color.rgb, 0.72);
	COLOR = vec4(decolored_icon, source_icon.a * icon_color.a);
}
