shader_type canvas_item;
// Section 11: the realistic mood comes from grading and vignette, not texture resolution.
// Drawn over the 3D view and under the HUD. No film grain (play-test 2026-10-17).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float saturation = 0.82;
uniform float contrast = 1.1;
// Cold shadows, barely warm highlights: the lamps bring the warmth, and bright snow must stay white.
uniform vec3 shadow_tint = vec3(0.9, 0.96, 1.1);
uniform vec3 highlight_tint = vec3(1.03, 1.0, 0.96);
uniform float vignette = 0.55;
// 0 = thawed, 1 = as frozen as it gets: ice grows in from the screen edges while outdoors.
uniform float frost = 0.0;
uniform vec3 frost_color : source_color = vec3(0.82, 0.9, 1.0);
// How far in from the edges full frost reaches (share of the half screen).
uniform float frost_reach = 0.24;
// Most the ice covers what is behind it, at its thickest at the very edge.
uniform float frost_opacity = 0.55;

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += value_noise(p) * amp;
		p = p * 2.03 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return sum;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Frost first, since it also bends the view a little where the ice is thick.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = vec2(uv.x * aspect, uv.y) * 9.0;
	float n = fbm(p);
	// Fine crystals: thin ridges of a higher noise.
	float veins = 1.0 - abs(fbm(p * 4.0 + 4.0) * 2.0 - 1.0);
	vec2 centered = abs(uv - 0.5) * 2.0;
	// Rounded corners, so the corners frost first and deepest, as on a real pane.
	float edge = length(max(centered - 0.55, 0.0)) * 1.2 + max(centered.x, centered.y) * 0.5;
	float threshold = 1.0 - frost * frost_reach;
	// A slow, large wobble on top of the fine noise, so the border is not an even frame.
	float wobble = fbm(p * 0.25 + 11.0) - 0.5;
	float ice = smoothstep(threshold, threshold + 0.18, edge + (n - 0.5) * 0.18 + wobble * 0.3) * step(0.001, frost);
	uv += (vec2(n, fbm(p + 3.1)) - 0.5) * 0.006 * ice;

	vec3 c = texture(screen_tex, uv).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= mix(shadow_tint, highlight_tint, smoothstep(0.05, 0.6, luma));
	vec2 from_center = (SCREEN_UV - 0.5) * vec2(1.0, 0.8);
	c *= 1.0 - vignette * smoothstep(0.15, 0.75, dot(from_center, from_center) * 2.0);
	vec3 frosted = frost_color * (0.6 + 0.25 * n + 0.15 * pow(veins, 10.0));
	c = mix(c, frosted, ice * frost_opacity);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
