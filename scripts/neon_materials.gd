extends RefCounted
class_name NeonMaterials

static func make_surface(color: Color, glow: bool = false, metallic: float = 0.15) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.42
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.6
	return material
