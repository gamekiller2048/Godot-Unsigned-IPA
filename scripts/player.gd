extends CharacterBody3D
class_name NeonRunnerPlayer

signal action_performed(action: StringName)

const LANE_WIDTH := 2.8
const STANDING_HEIGHT := 1.7
const DUCKING_HEIGHT := 1.02
const GRAVITY := 22.0
const JUMP_SPEED := 8.8
const DUCK_DURATION := 0.85
const ROLL_DURATION := 0.72

const MATERIALS = preload("res://scripts/neon_materials.gd")

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var forward_speed := 0.0
var input_enabled := false
var lane_index := 1
var duck_timer := 0.0
var roll_timer := 0.0
var roll_elapsed := 0.0
var high_jump_enabled := false
var hoverboard_enabled := false
var run_time := 0.0

var _capsule_shape: CapsuleShape3D
var _visual_root: Node3D
var _body_visual: MeshInstance3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _hoverboard_visual: Node3D

func _ready() -> void:
	add_to_group("runner")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.25
	_capsule_shape = CapsuleShape3D.new()
	_capsule_shape.radius = 0.36
	_capsule_shape.height = STANDING_HEIGHT
	collision_shape.shape = _capsule_shape
	collision_shape.position.y = STANDING_HEIGHT * 0.5
	_build_visuals()

func _physics_process(delta: float) -> void:
	run_time += delta
	if input_enabled:
		_read_movement_input()
	duck_timer = maxf(duck_timer - delta, 0.0)
	roll_timer = maxf(roll_timer - delta, 0.0)
	if roll_timer > 0.0:
		roll_elapsed += delta

	var target_x := float(lane_index - 1) * LANE_WIDTH
	var horizontal_error := target_x - global_position.x
	velocity.x = clampf(horizontal_error * 12.0, -15.0, 15.0) if input_enabled else 0.0
	if absf(horizontal_error) < 0.035:
		velocity.x = 0.0
		global_position.x = target_x

	velocity.z = -forward_speed
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	_update_duck_pose(delta)
	_animate_runner()

func perform_action(action: StringName) -> void:
	if not input_enabled:
		return
	match action:
		&"left":
			lane_index = maxi(lane_index - 1, 0)
		&"right":
			lane_index = mini(lane_index + 1, 2)
		&"jump":
			if is_on_floor():
				velocity.y = JUMP_SPEED * (1.55 if high_jump_enabled else 1.0)
		&"duck":
			duck_timer = DUCK_DURATION
		&"roll":
			if is_on_floor():
				roll_timer = ROLL_DURATION
				roll_elapsed = 0.0
		_:
			return
	action_performed.emit(action)

func reset_runner() -> void:
	global_position = Vector3.ZERO
	velocity = Vector3.ZERO
	forward_speed = 0.0
	input_enabled = false
	lane_index = 1
	duck_timer = 0.0
	roll_timer = 0.0
	roll_elapsed = 0.0
	high_jump_enabled = false
	hoverboard_enabled = false
	run_time = 0.0
	_capsule_shape.height = STANDING_HEIGHT
	collision_shape.position.y = STANDING_HEIGHT * 0.5
	_body_visual.scale = Vector3.ONE
	_visual_root.position.y = STANDING_HEIGHT * 0.5
	_visual_root.rotation = Vector3.ZERO
	_body_visual.position.y = 0.0
	_hoverboard_visual.visible = false

func _read_movement_input() -> void:
	# Einzelne Tastendrücke verhindern, dass gehaltene Tasten mehrere Spuren überspringen.
	if Input.is_action_just_pressed("move_left"):
		perform_action(&"left")
	if Input.is_action_just_pressed("move_right"):
		perform_action(&"right")
	if Input.is_action_just_pressed("move_jump"):
		perform_action(&"jump")
	if Input.is_action_just_pressed("move_duck"):
		perform_action(&"duck")
	if Input.is_action_just_pressed("move_roll"):
		perform_action(&"roll")

func _update_duck_pose(delta: float) -> void:
	var is_low := duck_timer > 0.0 or roll_timer > 0.0
	var target_height := DUCKING_HEIGHT if is_low else STANDING_HEIGHT
	_capsule_shape.height = move_toward(_capsule_shape.height, target_height, delta * 5.0)
	collision_shape.position.y = _capsule_shape.height * 0.5
	_body_visual.scale.y = move_toward(_body_visual.scale.y, 0.62 if is_low else 1.0, delta * 5.0)
	_body_visual.position.y = 0.0
	_visual_root.position.y = move_toward(_visual_root.position.y, DUCKING_HEIGHT * 0.5 if is_low else STANDING_HEIGHT * 0.5, delta * 5.0)
	if roll_timer > 0.0:
		_visual_root.rotation.x = TAU * minf(roll_elapsed / ROLL_DURATION, 1.0)
	else:
		_visual_root.rotation.x = 0.0

func _animate_runner() -> void:
	var moving := forward_speed > 0.0
	var is_low := duck_timer > 0.0 or roll_timer > 0.0
	var grounded := is_on_floor()
	var bob := sin(run_time * 12.0) * 0.055 if moving and grounded and not is_low else 0.0
	_body_visual.position.y = bob
	var stride := sin(run_time * 12.0) * 0.42 if moving and grounded and not is_low else 0.0
	_left_leg.rotation.x = stride if grounded else -0.55
	_right_leg.rotation.x = -stride if grounded else 0.75
	_left_arm.rotation.x = -stride * 0.75 if grounded else -0.95
	_right_arm.rotation.x = stride * 0.75 if grounded else 0.95
	_visual_root.rotation.z = clampf(velocity.x * -0.035, -0.3, 0.3)
	_hoverboard_visual.visible = hoverboard_enabled
	if hoverboard_enabled:
		_hoverboard_visual.position.y = -0.68 + sin(run_time * 8.0) * 0.035

func _build_visuals() -> void:
	var suit := MATERIALS.make_surface(Color(0.16, 0.2, 0.42), false, 0.45)
	var cyan := MATERIALS.make_surface(Color(0.12, 0.92, 1.0), true)
	var magenta := MATERIALS.make_surface(Color(1.0, 0.16, 0.65), true)
	var skin := MATERIALS.make_surface(Color(0.72, 0.43, 0.3), false, 0.1)
	var pants := MATERIALS.make_surface(Color(0.045, 0.075, 0.16), false, 0.3)
	var shoes := MATERIALS.make_surface(Color(0.12, 0.16, 0.25), false, 0.45)

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	_visual_root.position.y = STANDING_HEIGHT * 0.5
	add_child(_visual_root)

	_body_visual = MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.3
	body_mesh.height = 1.02
	_body_visual.mesh = body_mesh
	_body_visual.material_override = suit
	_body_visual.position.y = 0.08
	_visual_root.add_child(_body_visual)

	var chest_panel := _make_box_mesh(Vector3(0.32, 0.38, 0.08), cyan)
	chest_panel.position = Vector3(0.0, 0.12, -0.285)
	_body_visual.add_child(chest_panel)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.245
	head_mesh.height = 0.49
	head.mesh = head_mesh
	head.material_override = skin
	head.position = Vector3(0.0, 0.79, 0.0)
	_visual_root.add_child(head)

	var hair := _make_box_mesh(Vector3(0.38, 0.1, 0.35), pants)
	hair.position = Vector3(0.0, 0.97, 0.035)
	_visual_root.add_child(hair)

	var visor := _make_box_mesh(Vector3(0.34, 0.09, 0.08), cyan)
	visor.position = Vector3(0.0, 0.81, -0.21)
	_visual_root.add_child(visor)

	var backpack := _make_box_mesh(Vector3(0.36, 0.48, 0.19), pants)
	backpack.position = Vector3(0.0, 0.08, 0.25)
	_visual_root.add_child(backpack)
	var pack_light := _make_box_mesh(Vector3(0.23, 0.07, 0.025), magenta)
	pack_light.position = Vector3(0.0, 0.1, 0.35)
	_visual_root.add_child(pack_light)

	_left_leg = _make_limb_pivot(Vector3(-0.17, -0.34, 0.0), Vector3(0.2, 0.55, 0.2), pants)
	_right_leg = _make_limb_pivot(Vector3(0.17, -0.34, 0.0), Vector3(0.2, 0.55, 0.2), pants)
	var left_shoe := _make_box_mesh(Vector3(0.23, 0.13, 0.36), shoes)
	left_shoe.position = Vector3(0.0, -0.29, -0.055)
	_left_leg.add_child(left_shoe)
	var right_shoe := _make_box_mesh(Vector3(0.23, 0.13, 0.36), shoes)
	right_shoe.position = Vector3(0.0, -0.29, -0.055)
	_right_leg.add_child(right_shoe)
	var left_shoe_light := _make_box_mesh(Vector3(0.17, 0.035, 0.035), cyan)
	left_shoe_light.position = Vector3(0.0, -0.26, -0.24)
	_left_leg.add_child(left_shoe_light)
	var right_shoe_light := _make_box_mesh(Vector3(0.17, 0.035, 0.035), cyan)
	right_shoe_light.position = Vector3(0.0, -0.26, -0.24)
	_right_leg.add_child(right_shoe_light)

	_left_arm = _make_limb_pivot(Vector3(-0.36, 0.39, 0.0), Vector3(0.16, 0.52, 0.17), magenta)
	_right_arm = _make_limb_pivot(Vector3(0.36, 0.39, 0.0), Vector3(0.16, 0.52, 0.17), magenta)
	_make_hand(_left_arm, skin, cyan)
	_make_hand(_right_arm, skin, cyan)

	_hoverboard_visual = Node3D.new()
	_hoverboard_visual.name = "HoverboardVisual"
	_hoverboard_visual.position = Vector3(0.0, -0.68, 0.0)
	_visual_root.add_child(_hoverboard_visual)
	var board := _make_box_mesh(Vector3(0.82, 0.11, 1.08), MATERIALS.make_surface(Color(0.055, 0.09, 0.18), false, 0.65))
	_hoverboard_visual.add_child(board)
	var board_glow := _make_box_mesh(Vector3(0.64, 0.035, 0.78), cyan)
	board_glow.position.y = -0.075
	_hoverboard_visual.add_child(board_glow)
	for wheel_x in [-0.34, 0.34]:
		var wheel := MeshInstance3D.new()
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.12
		wheel_mesh.bottom_radius = 0.12
		wheel_mesh.height = 0.17
		wheel.mesh = wheel_mesh
		wheel.material_override = magenta
		wheel.position = Vector3(wheel_x, -0.05, 0.0)
		wheel.rotation.z = PI * 0.5
		_hoverboard_visual.add_child(wheel)
	_hoverboard_visual.visible = false

func _make_limb_pivot(limb_position: Vector3, limb_size: Vector3, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = limb_position
	_visual_root.add_child(pivot)
	var limb := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = limb_size
	limb.mesh = mesh
	limb.material_override = material
	limb.position.y = -limb_size.y * 0.5
	pivot.add_child(limb)
	return pivot

func _make_hand(parent: Node3D, skin_material: Material, glove_material: Material) -> void:
	var glove := _make_box_mesh(Vector3(0.18, 0.17, 0.18), glove_material)
	glove.position.y = -0.48
	parent.add_child(glove)
	var hand := MeshInstance3D.new()
	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 0.085
	hand_mesh.height = 0.17
	hand.mesh = hand_mesh
	hand.material_override = skin_material
	hand.position.y = -0.55
	parent.add_child(hand)

func _make_box_mesh(size: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	return visual
