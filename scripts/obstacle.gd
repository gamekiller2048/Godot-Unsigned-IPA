extends Area3D
class_name NeonRunnerObstacle

const MATERIALS = preload("res://scripts/neon_materials.gd")
const LANE_WIDTH := 2.8
const TRAIN_RAMP_RUN := 5.6

enum Kind { BARRIER, OVERHEAD_GATE, BLOCK, TRAIN }

func configure(kind: int, lane: int, world_z: float) -> void:
	position = Vector3(float(lane - 1) * LANE_WIDTH, 0.0, world_z)
	collision_layer = 0
	collision_mask = 2
	monitoring = true

	var size := Vector3(1.9, 0.9, 0.8)
	var height := 0.45
	var color := Color(1.0, 0.26, 0.14)
	var glow_color := Color(1.0, 0.67, 0.12)
	match kind:
		Kind.OVERHEAD_GATE:
			size = Vector3(2.05, 0.48, 0.7)
			height = 1.72
			color = Color(0.95, 0.12, 0.42)
			glow_color = Color(1.0, 0.28, 0.68)
		Kind.BLOCK:
			size = Vector3(1.8, 1.85, 1.15)
			height = size.y * 0.5
			color = Color(0.9, 0.12, 0.22)
			glow_color = Color(1.0, 0.18, 0.25)
		Kind.TRAIN:
			size = Vector3(2.35, 2.8, 15.0)
			height = size.y * 0.5
			color = Color(0.08, 0.17, 0.31)
			glow_color = Color(0.08, 0.88, 1.0)

	var obstacle_mesh := BoxMesh.new()
	obstacle_mesh.size = size
	var obstacle_visual := MeshInstance3D.new()
	obstacle_visual.mesh = obstacle_mesh
	obstacle_visual.material_override = MATERIALS.make_surface(color, false, 0.35)
	obstacle_visual.position.y = height
	add_child(obstacle_visual)

	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(size.x + 0.035, 0.075, size.z + 0.035)
	var trim := MeshInstance3D.new()
	trim.mesh = trim_mesh
	trim.material_override = MATERIALS.make_surface(glow_color, true)
	trim.position = Vector3(0.0, height + size.y * 0.5 + 0.035, 0.0) if kind == Kind.TRAIN else Vector3(0.0, height + size.y * 0.42, 0.0)
	add_child(trim)

	if kind == Kind.TRAIN:
		_add_train_ramp(size)
		_build_train_details(size)

	if kind == Kind.TRAIN:
		_add_train_collisions(size)
	else:
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = height
		add_child(collision)

func _add_train_collisions(size: Vector3) -> void:
	var platform := StaticBody3D.new()
	platform.name = "TrainPlatform"
	platform.collision_layer = 1
	platform.collision_mask = 0
	var roof_shape := BoxShape3D.new()
	roof_shape.size = size
	var roof_collision := CollisionShape3D.new()
	roof_collision.shape = roof_shape
	roof_collision.position.y = size.y * 0.5
	platform.add_child(roof_collision)
	add_child(platform)

	var front_hazard := BoxShape3D.new()
	front_hazard.size = Vector3(size.x, 0.62, 0.24)
	var front_collision := CollisionShape3D.new()
	front_collision.shape = front_hazard
	front_collision.position = Vector3(0.0, 0.31, size.z * 0.5 + 0.1)
	add_child(front_collision)

	for side in [-1.0, 1.0]:
		var side_hazard := BoxShape3D.new()
		side_hazard.size = Vector3(0.2, 0.62, size.z)
		var side_collision := CollisionShape3D.new()
		side_collision.shape = side_hazard
		side_collision.position = Vector3(side * (size.x * 0.5 + 0.07), 0.31, 0.0)
		add_child(side_collision)

func _add_train_ramp(size: Vector3) -> void:
	var run := TRAIN_RAMP_RUN
	var rise := size.y
	var ramp_length := Vector2(run, rise).length()
	var ramp_angle := atan2(rise, run)
	var ramp_center := Vector3(0.0, rise * 0.5, size.z * 0.5 + run * 0.5)
	var ramp_size := Vector3(size.x, 0.18, ramp_length)

	var ramp_mesh := BoxMesh.new()
	ramp_mesh.size = ramp_size
	var ramp_visual := MeshInstance3D.new()
	ramp_visual.name = "TrainRamp"
	ramp_visual.mesh = ramp_mesh
	ramp_visual.material_override = MATERIALS.make_surface(Color(0.12, 0.28, 0.43), false, 0.55)
	ramp_visual.position = ramp_center
	ramp_visual.rotation.x = ramp_angle
	add_child(ramp_visual)

	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(size.x + 0.035, 0.045, ramp_length * 0.07)
	var grip_material := MATERIALS.make_surface(Color(0.1, 0.88, 1.0), true)
	for index in range(5):
		var grip := MeshInstance3D.new()
		grip.name = "RampGrip"
		grip.mesh = grip_mesh
		grip.material_override = grip_material
		grip.position = ramp_center + Vector3(0.0, 0.085, -ramp_length * 0.39 + float(index) * ramp_length * 0.195)
		grip.rotation.x = ramp_angle
		add_child(grip)

	var ramp_body := StaticBody3D.new()
	ramp_body.name = "RampCollision"
	ramp_body.collision_layer = 1
	ramp_body.collision_mask = 0
	var ramp_shape := BoxShape3D.new()
	ramp_shape.size = ramp_size
	var ramp_collision := CollisionShape3D.new()
	ramp_collision.shape = ramp_shape
	ramp_collision.position = ramp_center
	ramp_collision.rotation.x = ramp_angle
	ramp_body.add_child(ramp_collision)
	add_child(ramp_body)

func _build_train_details(size: Vector3) -> void:
	var window_material := MATERIALS.make_surface(Color(0.025, 0.075, 0.13), true)
	var door_material := MATERIALS.make_surface(Color(0.035, 0.26, 0.42), false, 0.55)
	var window_count := 4
	for side in [-1.0, 1.0]:
		for index in range(window_count):
			var window_mesh := BoxMesh.new()
			window_mesh.size = Vector3(0.045, 0.72, 1.25)
			var window := MeshInstance3D.new()
			window.mesh = window_mesh
			window.material_override = window_material
			window.position = Vector3(side * (size.x * 0.5 + 0.026), 1.9, -3.0 + float(index) * 2.0)
			add_child(window)

		var side_stripe := BoxMesh.new()
		side_stripe.size = Vector3(0.055, 0.12, size.z * 0.94)
		var stripe := MeshInstance3D.new()
		stripe.mesh = side_stripe
		stripe.material_override = MATERIALS.make_surface(Color(0.95, 0.12, 0.55), true)
		stripe.position = Vector3(side * (size.x * 0.5 + 0.035), 0.85, 0.0)
		add_child(stripe)

		for door_z in [-5.2, 0.0, 5.2]:
			var door_mesh := BoxMesh.new()
			door_mesh.size = Vector3(0.05, 2.2, 0.95)
			var door := MeshInstance3D.new()
			door.mesh = door_mesh
			door.material_override = door_material
			door.position = Vector3(side * (size.x * 0.5 + 0.032), 1.35, door_z)
			add_child(door)

			var handle_mesh := BoxMesh.new()
			handle_mesh.size = Vector3(0.07, 0.42, 0.045)
			var handle := MeshInstance3D.new()
			handle.mesh = handle_mesh
			handle.material_override = MATERIALS.make_surface(Color(0.2, 0.86, 1.0), true)
			handle.position = Vector3(side * (size.x * 0.5 + 0.07), 1.35, door_z)
			add_child(handle)

	var front_mesh := BoxMesh.new()
	front_mesh.size = Vector3(0.09, 0.22, 0.65)
	for side in [-1.0, 1.0]:
		var headlight := MeshInstance3D.new()
		headlight.mesh = front_mesh
		headlight.material_override = MATERIALS.make_surface(Color(1.0, 0.75, 0.22), true)
		headlight.position = Vector3(side * 0.72, 0.7, size.z * 0.5 + 0.052)
		add_child(headlight)
