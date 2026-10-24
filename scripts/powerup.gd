extends Area3D
class_name NeonRunnerPowerup

signal collected(powerup_type: int)

const MATERIALS = preload("res://scripts/neon_materials.gd")
const LANE_WIDTH := 2.8
const HIGH_JUMP := 0
const DOUBLE_COINS := 1
const HOVERBOARD := 2

var powerup_type := HIGH_JUMP
var _visual: Node3D
var _collected := false
var _spin_speed := 1.8

func configure(type: int, lane: int, world_z: float) -> void:
	powerup_type = type
	position = Vector3(float(lane - 1) * LANE_WIDTH, 1.45, world_z)
	collision_layer = 0
	collision_mask = 2
	monitoring = true

	var shape := SphereShape3D.new()
	shape.radius = 0.68
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	var color := Color(0.12, 0.72, 1.0)
	if powerup_type == DOUBLE_COINS:
		color = Color(1.0, 0.68, 0.12)
	elif powerup_type == HOVERBOARD:
		color = Color(0.95, 0.12, 0.72)
	var material := MATERIALS.make_surface(color, true, 0.55)
	_visual = Node3D.new()
	add_child(_visual)

	var orb := MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.36
	orb_mesh.height = 0.72
	orb.mesh = orb_mesh
	orb.material_override = material
	_visual.add_child(orb)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.43
	ring_mesh.outer_radius = 0.52
	ring.mesh = ring_mesh
	var ring_color := Color(0.55, 0.94, 1.0)
	if powerup_type == DOUBLE_COINS:
		ring_color = Color(1.0, 0.9, 0.3)
	elif powerup_type == HOVERBOARD:
		ring_color = Color(1.0, 0.35, 0.84)
	ring.material_override = MATERIALS.make_surface(ring_color, true)
	ring.rotation.x = PI * 0.5
	_visual.add_child(ring)

	var glyph := MeshInstance3D.new()
	if powerup_type == HIGH_JUMP:
		var arrow_mesh := BoxMesh.new()
		arrow_mesh.size = Vector3(0.12, 0.42, 0.12)
		glyph.mesh = arrow_mesh
		glyph.material_override = MATERIALS.make_surface(Color.WHITE, true)
	elif powerup_type == DOUBLE_COINS:
		var coin_mesh := CylinderMesh.new()
		coin_mesh.top_radius = 0.19
		coin_mesh.bottom_radius = 0.19
		coin_mesh.height = 0.08
		glyph.mesh = coin_mesh
		glyph.material_override = MATERIALS.make_surface(Color.WHITE, true)
		glyph.rotation.x = PI * 0.5
	else:
		var board_mesh := BoxMesh.new()
		board_mesh.size = Vector3(0.42, 0.08, 0.2)
		glyph.mesh = board_mesh
		glyph.material_override = MATERIALS.make_surface(Color.WHITE, true)
	_visual.add_child(glyph)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if not is_instance_valid(_visual):
		return
	_visual.rotation.y += _spin_speed * delta
	_visual.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.1

func collect() -> void:
	if _collected:
		return
	_collected = true
	collected.emit(powerup_type)
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("runner"):
		collect()
