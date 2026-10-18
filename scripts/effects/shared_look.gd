class_name SharedLook
extends RefCounted
## Fewer shaders for the browser to build on a first visit (#78). Every distinct material setup is
## its own shader, and a lit one takes most of a second to compile. A plain lit colour (no texture)
## looks exactly the same as that colour on a white texture, so plain materials take the setup the
## textured props already use (white texture, object triplanar, anisotropic filter) and share their
## shaders. Materials with anything else going on are left as they are.

const WHITE: Texture2D = preload("res://assets/textures/white.png")


## Moves a plain lit colour material onto the shared setup; any other material is returned untouched.
static func adopt(material: BaseMaterial3D) -> BaseMaterial3D:
	if material.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL or material.albedo_texture != null \
			or material.vertex_color_use_as_albedo or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			or material.emission_enabled or material.normal_enabled:
		return material
	material.albedo_texture = WHITE
	material.uv1_triplanar = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material
