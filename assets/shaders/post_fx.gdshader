shader_type canvas_item;
// Section 11: the realistic mood comes from grading, grain and vignette, not texture resolution.
// Drawn over the 3D view and under the HUD.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float saturation = 0.82;
uniform float contrast = 1.1;
// Cold shadows, barely warm highlights: the lamps bring the warmth, and bright snow must stay white.
uniform vec3 shadow_tint = vec3(0.9, 0.96, 1.1);
uniform vec3 highlight_tint = vec3(1.03, 1.0, 0.96);
uniform float vignette = 0.55;
uniform float grain = 0.07;

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= mix(shadow_tint, highlight_tint, smoothstep(0.05, 0.6, luma));
	vec2 from_center = (SCREEN_UV - 0.5) * vec2(1.0, 0.8);
	c *= 1.0 - vignette * smoothstep(0.15, 0.75, dot(from_center, from_center) * 2.0);
	// Grain is stronger in the dark, like film; a new pattern every 1/24 s.
	float frame = floor(TIME * 24.0);
	float n = hash(FRAGCOORD.xy + frame * 17.0) - 0.5;
	c += n * grain * (1.2 - luma);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
