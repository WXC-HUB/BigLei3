shader_type canvas_item;

// The range goes well past the scenery props' 4-6 px: a full-screen backdrop tree
// needs an order of magnitude more travel before the eye reads it as wind.
uniform float amplitude_px : hint_range(0.0, 64.0, 0.5) = 4.0;
uniform float angular_speed : hint_range(0.1, 2.0, 0.05) = 0.72;
uniform float phase : hint_range(0.0, 6.283, 0.01) = 0.0;
uniform float fixed_bottom_ratio : hint_range(0.0, 0.6, 0.01) = 0.34;
uniform float transition_height : hint_range(0.1, 0.6, 0.01) = 0.34;
uniform float click_strength : hint_range(0.0, 10.0, 0.1) = 0.0;
// A faster, smaller second wave riding on the main one. Off by default so the
// small props keep their single clean swing; the big backdrops turn it on to
// avoid looking like one rigid board rocking back and forth.
uniform float gust_amplitude_px : hint_range(0.0, 32.0, 0.5) = 0.0;
uniform float gust_speed : hint_range(0.1, 8.0, 0.05) = 2.6;


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
	float gust = sin(TIME * gust_speed + phase * 1.7) * gust_amplitude_px;
	float click_mask = mix(0.35, 1.0, height_from_bottom);
	float click_shake = sin(TIME * 58.0 + phase) * click_strength * click_mask;
	VERTEX.x += (wind * amplitude_px + gust) * sway_mask + click_shake;
}
