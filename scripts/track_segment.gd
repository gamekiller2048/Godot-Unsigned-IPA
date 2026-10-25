extends StaticBody3D
class_name NeonRunnerTrackSegment

const MATERIALS = preload("res://scripts/neon_materials.gd")
const LENGTH := 36.0

var segment_seed := 0

func _ready() -> void:
	_build_segment()

func _build_segment() -> void:
	var road := _add_box("Road", Vector3(9.6, 0.18, LENGTH), Vector3(0.0, -0.09, 0.0), Color(0.035, 0.055, 0.14), false)
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var sidewalk_material := MATERIALS.make_surface(Color(0.12, 0.15, 0.28), false, 0.25)
	for side in [-1.0, 1.0]:
		_add_box("Sidewalk", Vector3(1.05, 0.18, LENGTH), Vector3(side * 5.3, -0.09, 0.0), Color(0.08, 0.11, 0.22), false, sidewalk_material)
		_add_box("PlatformEdge", Vector3(0.12, 0.035, LENGTH), Vector3(side * 4.82, 0.025, 0.0), Color(1.0, 0.68, 0.12), true)
		_add_box("Rail", Vector3(0.14, 0.62, LENGTH), Vector3(side * 4.65, 0.31, 0.0), Color(0.12, 0.24, 0.42), false)
		_add_box("RailLight", Vector3(0.06, 0.08, LENGTH), Vector3(side * 4.65, 0.66, 0.0), Color(0.1, 0.85, 1.0), true)

	_add_tracks()

	for lane_line in [-1.0, 1.0]:
		_add_box("LaneMarking", Vector3(0.055, 0.025, LENGTH), Vector3(lane_line * 1.4, 0.016, 0.0), Color(0.08, 0.72, 0.94), true)

	var collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(10.2, 0.3, LENGTH)
	collision.shape = floor_shape
	collision.position.y = -0.15
	add_child(collision)

	_add_city_blocks()
	_add_trackside_background()
	if segment_seed % 3 == 1:
		_add_station_canopy()

func _add_tracks() -> void:
	var sleeper_material := MATERIALS.make_surface(Color(0.17, 0.2, 0.29), false, 0.3)
	var rail_material := MATERIALS.make_surface(Color(0.48, 0.61, 0.72), false, 0.78)
	for lane in range(3):
		var center_x := float(lane - 1) * 2.8
		_add_box("TrackBed", Vector3(1.95, 0.025, LENGTH), Vector3(center_x, 0.012, 0.0), Color(0.025, 0.035, 0.07), false)
		for rail_side in [-1.0, 1.0]:
			_add_box("SteelRail", Vector3(0.12, 0.14, LENGTH), Vector3(center_x + rail_side * 0.63, 0.075, 0.0), Color(0.48, 0.61, 0.72), false, rail_material)
		for sleeper in range(12):
			var sleeper_z := -16.5 + float(sleeper) * 3.0
			_add_box("Sleeper", Vector3(1.85, 0.09, 0.25), Vector3(center_x, 0.038, sleeper_z), Color(0.17, 0.2, 0.29), false, sleeper_material)

func _add_station_canopy() -> void:
	var support_material := MATERIALS.make_surface(Color(0.16, 0.26, 0.39), false, 0.55)
	var sign_material := MATERIALS.make_surface(Color(0.025, 0.12, 0.22), true)
	for side in [-1.0, 1.0]:
		_add_box("StationPillar", Vector3(0.32, 5.2, 0.42), Vector3(side * 6.15, 2.6, 0.0), Color(0.16, 0.26, 0.39), false, support_material)
		_add_box("StationCanopy", Vector3(1.8, 0.22, LENGTH), Vector3(side * 5.5, 5.2, 0.0), Color(0.08, 0.14, 0.24), false)
		_add_box("CanopyLight", Vector3(0.1, 0.07, LENGTH), Vector3(side * 4.82, 5.06, 0.0), Color(0.12, 0.82, 1.0), true)

	_add_box("StationSign", Vector3(3.6, 0.85, 0.22), Vector3(0.0, 4.45, -2.0), Color(0.025, 0.12, 0.22), true, sign_material)
	_add_box("StationSignStripe", Vector3(3.6, 0.09, 0.25), Vector3(0.0, 4.12, -2.0), Color(1.0, 0.16, 0.58), true)
	var sign_text := Label3D.new()
	sign_text.text = "NEON METRO"
	sign_text.font_size = 48
	sign_text.pixel_size = 0.01
	sign_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_text.modulate = Color(0.35, 0.94, 1.0)
	sign_text.position = Vector3(0.0, 4.45, -1.86)
	add_child(sign_text)

func _add_trackside_background() -> void:
	var concrete := MATERIALS.make_surface(Color(0.1, 0.14, 0.22), false, 0.25)
	var metal := MATERIALS.make_surface(Color(0.23, 0.3, 0.4), false, 0.68)
	for side in [-1.0, 1.0]:
		_add_box("TunnelWall", Vector3(0.35, 9.0, LENGTH), Vector3(side * 14.5, 4.5, 0.0), Color(0.055, 0.075, 0.13), false, concrete)
		_add_box("WallNeon", Vector3(0.08, 0.16, LENGTH), Vector3(side * 14.28, 3.5, 0.0), Color(0.1, 0.68, 0.92), true)
		for support in range(4):
			var support_z := -13.5 + float(support) * 9.0
			_add_box("TunnelSupport", Vector3(0.34, 8.2, 0.4), Vector3(side * 7.1, 4.1, support_z), Color(0.13, 0.18, 0.27), false, metal)
			_add_box("SupportLight", Vector3(0.48, 0.12, 0.48), Vector3(side * 7.1, 8.25, support_z), Color(0.16, 0.76, 1.0), true)
		for sign_index in range(2):
			var sign_z := -8.0 + float(sign_index) * 16.0
			_add_box("WallAdPanel", Vector3(0.12, 1.65, 2.4), Vector3(side * 14.22, 5.1, sign_z), Color(0.025, 0.1, 0.2), true)
			_add_box("WallAdStripe", Vector3(0.15, 0.1, 2.15), Vector3(side * 14.12, 4.55, sign_z), Color(1.0, 0.16, 0.62), true)

	_add_box("TunnelCeiling", Vector3(29.0, 0.32, LENGTH), Vector3(0.0, 9.0, 0.0), Color(0.035, 0.05, 0.09), false, concrete)
	for light_index in range(6):
		var light_z := -15.0 + float(light_index) * 6.0
		_add_box("CeilingLight", Vector3(0.72, 0.08, 1.9), Vector3(0.0, 8.78, light_z), Color(0.46, 0.76, 1.0), true)

func _add_city_blocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(segment_seed, 1)
	var accents: Array[Color] = [
		Color(0.14, 0.38, 0.72),
		Color(0.24, 0.22, 0.56),
		Color(0.1, 0.42, 0.52),
		Color(0.38, 0.18, 0.46)
	]
	for side in [-1.0, 1.0]:
		for block in range(2):
			var depth := rng.randf_range(4.5, 7.0)
			var width := rng.randf_range(3.4, 5.4)
			var height := rng.randf_range(7.0, 16.0)
			var local_z := rng.randf_range(-13.0, 13.0)
			var center_x: float = float(side) * rng.randf_range(8.0, 10.5)
			var accent: Color = accents[rng.randi_range(0, accents.size() - 1)]
			_add_box("Building", Vector3(width, height, depth), Vector3(center_x, height * 0.5, local_z), accent, false)
			var front_x: float = center_x - float(side) * (width * 0.5 + 0.035)
			_add_box("NeonFacade", Vector3(0.08, height * 0.72, depth * 0.72), Vector3(front_x, height * 0.52, local_z), Color(0.12, 0.75, 1.0) if block == 0 else Color(1.0, 0.17, 0.65), true)
			for window_row in range(3):
				for window_column in range(2):
					var window_y := height * 0.3 + float(window_row) * height * 0.22
					var window_z := local_z - depth * 0.22 + float(window_column) * depth * 0.44
					_add_box("BuildingWindow", Vector3(0.055, 0.42, 0.62), Vector3(front_x - float(side) * 0.05, window_y, window_z), Color(0.28, 0.75, 1.0) if rng.randf() < 0.6 else Color(1.0, 0.62, 0.24), true)

func _add_box(
	node_name: String,
	size: Vector3,
	box_position: Vector3,
	color: Color,
	glow: bool,
	material: Material = null
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.material_override = material if material != null else MATERIALS.make_surface(color, glow)
	visual.position = box_position
	add_child(visual)
	return visual
