shader_type canvas_item;
render_mode unshaded;

uniform vec4 base_color : source_color = vec4(0.925, 0.886, 0.792, 1.0);
uniform vec4 moss_tint : source_color = vec4(0.53, 0.62, 0.30, 1.0);
uniform vec4 ochre_tint : source_color = vec4(0.88, 0.66, 0.38, 1.0);
uniform float cloud_strength : hint_range(0.0, 0.50) = 0.38;
uniform float motion_speed : hint_range(0.0, 0.03) = 0.012;
uniform float paper_strength : hint_range(0.0, 0.25) = 0.18;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float fbm(vec2 point) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += value_noise(point) * amplitude;
		point = point * 2.03 + vec2(13.1, 7.7);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 aspect_uv = UV;
	aspect_uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	// Fine structure stays fixed, so the surface reads as paper rather than a
	// texture sliding behind the interface.
	float broad_stain = fbm(aspect_uv * 8.0 + vec2(2.4, 8.1));
	float fibers = value_noise(aspect_uv * 115.0 + vec2(17.0, 3.0));
	float paper = (broad_stain - 0.5) * 0.72 + (fibers - 0.5) * 0.28;

	// Only broad watercolor washes move, following two opposing slow paths.
	float drift = TIME * motion_speed;
	float cloud_a = fbm(aspect_uv * 1.55 + vec2(drift, -drift * 0.32));
	float cloud_b = fbm(aspect_uv * 2.05 + vec2(8.3 - drift * 0.58, 2.1 + drift * 0.76));
	float moss_mask = smoothstep(0.46, 0.68, cloud_a);
	float ochre_mask = smoothstep(0.48, 0.70, cloud_b);

	vec3 color = base_color.rgb;
	color = mix(color, moss_tint.rgb, moss_mask * cloud_strength);
	color = mix(color, ochre_tint.rgb, ochre_mask * cloud_strength * 0.82);
	color *= 1.0 + paper * paper_strength;

	vec2 centered = UV - vec2(0.5);
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float vignette_noise = fbm(aspect_uv * 3.2 + vec2(5.0, 11.0));
	float vignette = smoothstep(0.42 + vignette_noise * 0.07, 1.04, length(centered));
	color *= 1.0 - vignette * 0.055;

	COLOR = vec4(color, base_color.a);
}
