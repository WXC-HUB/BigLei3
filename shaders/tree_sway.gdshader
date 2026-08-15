shader_type canvas_item;

uniform float amplitude_px : hint_range(0.0, 8.0, 0.1) = 4.0;
uniform float angular_speed : hint_range(0.1, 2.0, 0.05) = 0.72;
uniform float phase : hint_range(0.0, 6.283, 0.01) = 0.0;
uniform float fixed_bottom_ratio : hint_range(0.0, 0.6, 0.01) = 0.34;
uniform float transition_height : hint_range(0.1, 0.6, 0.01) = 0.34;
uniform float click_strength : hint_range(0.0, 10.0, 0.1) = 0.0;


void vertex() {
	// UV height is zero at the roots and one at the top of the crown.
	float height_from_bottom = 1.0 - UV.y;
	float sway_mask = smoothstep(
		fixed_bottom_ratio,
		fixed_bottom_ratio + transition_height,
		height_from_bottom
	);
	float wind = sin(
		TIME * angular_speed
		+ phase
		+ height_from_bottom * 1.65
	);
	float click_mask = mix(0.35, 1.0, height_from_bottom);
	float click_shake = sin(TIME * 58.0 + phase) * click_strength * click_mask;
	VERTEX.x += wind * amplitude_px * sway_mask + click_shake;
}
