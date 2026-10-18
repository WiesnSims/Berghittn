shader_type spatial;
// The mountain around the hut (AlmTerrain): snow on the gentle faces, bare rock on the steep ones.
// Both photo textures are projected from the world axes (triplanar), as the terrain has no UVs.
// The vertex colour darkens faces a little, so the snow does not look like one sheet of plastic.

uniform sampler2D snow_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Metres one texture repeat covers. Larger than on the walkable ground: the slopes are seen from afar.
uniform float snow_size = 6.0;
uniform float rock_size = 8.0;
// Faces whose normal points up less than this show rock (set by AlmTerrain).
uniform float rock_steepness = 0.8;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 triplanar(sampler2D tex, vec3 position, vec3 normal) {
	vec3 weights = pow(abs(normal), vec3(4.0));
	weights /= weights.x + weights.y + weights.z;
	return texture(tex, position.zy).rgb * weights.x
			+ texture(tex, position.xz).rgb * weights.y
			+ texture(tex, position.xy).rgb * weights.z;
}

void fragment() {
	vec3 snow = triplanar(snow_texture, world_position / snow_size, world_normal);
	vec3 rock = triplanar(rock_texture, world_position / rock_size, world_normal);
	ALBEDO = (world_normal.y < rock_steepness ? rock : snow) * COLOR.rgb;
	ROUGHNESS = 1.0;
}
