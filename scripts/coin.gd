extends Area3D
class_name NeonRunnerCoin

signal collected

const MATERIALS = preload("res://scripts/neon_materials.gd")
const LANE_WIDTH := 2.8

var spin_speed := 2.4
var _visual: MeshInstance3D
var _collected := false

func configure(lane: int, world_z: float, height: float = 1.05) -> void:
	position = Vector3(float(lane - 1) * LANE_WIDTH, height, world_z)
	collision_layer = 0
	collision_mask = 2
	monitoring = true

	var shape := SphereShape3D.new()
	shape.radius = 0.52
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	_visual = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.34
	mesh.height = 0.12
	_visual.mesh = mesh
	_visual.material_override = MATERIALS.make_surface(Color(1.0, 0.78, 0.16), true, 0.65)
	_visual.rotation.x = PI * 0.5
	add_child(_visual)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_instance_valid(_visual):
		_visual.rotation.y += spin_speed * delta

func collect() -> void:
	if _collected:
		return
	_collected = true
	collected.emit()
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("runner"):
		return
	collect()
