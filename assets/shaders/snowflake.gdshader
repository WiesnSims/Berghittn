shader_type spatial;
// One snow flake of the storm particles: a soft camera-facing dot that vanishes under any roof, so
// the emitter can follow the camera indoors without snowing into the Stube.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D roof_heights : filter_nearest, repeat_disable;
// x, z of the roof map's corner and its width and depth in metres.
uniform vec4 roof_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float roof_ready = 0.0;
uniform vec4 flake_color : source_color = vec4(0.86, 0.9, 1.0, 0.85);
// Flakes closer than this fade out, so none ever smears across the whole view.
uniform float near_fade = 0.6;

varying float keep;

void vertex() {
	vec3 world = MODEL_MATRIX[3].xyz;
	vec2 uv = (world.xz - roof_rect.xy) / roof_rect.zw;
	keep = roof_ready;
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
		float roof = textureLod(roof_heights, uv, 0.0).r;
		keep *= step(roof, world.y);
	}
	// Billboard, keeping the particle's own scale.
	float scale = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale, INV_VIEW_MATRIX[1] * scale,
			INV_VIEW_MATRIX[2] * scale, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float dot_shape = 1.0 - smoothstep(0.2, 0.5, length(UV - vec2(0.5)));
	float near = smoothstep(near_fade * 0.5, near_fade, -VERTEX.z);
	float alpha = flake_color.a * dot_shape * near * keep;
	if (alpha < 0.01) {
		discard;
	}
	ALBEDO = flake_color.rgb;
	ALPHA = alpha;
}
