extends Node3D

enum GameState { TITLE, PLAYING, PAUSED, GAME_OVER }

const OBSTACLE_SCENE: PackedScene = preload("res://scenes/obstacle.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const POWERUP_SCENE: PackedScene = preload("res://scenes/powerup.tscn")
const SAVE_PATH := "user://neon_runner.cfg"
const BASE_SPEED := 14.0
const MAX_SPEED := 23.0
const ROW_SPACING := 24.0
const BOOSTER_PRICES := {"shield": 80, "magnet": 40, "turbo": 60}
const BOOSTER_DURATIONS := {"shield": 8.0, "magnet": 8.0, "turbo": 6.0}

@onready var player: NeonRunnerPlayer = $Player
@onready var track_manager: NeonRunnerTrackManager = $TrackManager
@onready var spawned_objects: Node3D = $SpawnedObjects
@onready var camera: Camera3D = $Camera3D
@onready var ui: NeonRunnerUI = $UI
@onready var world_environment: WorldEnvironment = $WorldEnvironment

var game_state := GameState.TITLE
var coins := 0
var wallet := 0
var boosters := {"shield": 0, "magnet": 0, "turbo": 0}
var booster_timers := {"shield": 0.0, "magnet": 0.0, "turbo": 0.0}
var pickup_timers := {"high_jump": 0.0, "double_coins": 0.0, "hoverboard": 0.0}
var high_score := 0
var score := 0
var volume := 0.7
var next_row_z := -30.0
var _train_route_active := false
var _last_train_lane := 1
var _random := RandomNumberGenerator.new()
var _sound_player: AudioStreamPlayer
var _sound_library: Dictionary = {}

func _ready() -> void:
	_random.randomize()
	_configure_input_actions()
	_configure_world()
	_load_progress()
	_configure_audio()
	track_manager.reset_track()

	ui.start_requested.connect(_start_run)
	ui.pause_requested.connect(_pause_run)
	ui.resume_requested.connect(_resume_run)
	ui.restart_requested.connect(_start_run)
	ui.volume_changed.connect(_set_volume)
	ui.swipe_action.connect(_on_swipe_action)
	ui.shop_requested.connect(_open_shop)
	ui.shop_closed.connect(_close_shop)
	ui.booster_buy.connect(_buy_booster)
	ui.booster_use.connect(_activate_booster)
	player.action_performed.connect(_on_player_action)
	ui.update_stats(0, 0, wallet, high_score)
	ui.update_boosters(boosters, booster_timers)
	ui.update_powerups(pickup_timers)
	ui.show_title(high_score, volume, wallet, boosters)
	_update_camera(1.0)

func _process(delta: float) -> void:
	if game_state != GameState.PLAYING:
		return
	var distance := maxf(-player.global_position.z, 0.0)
	var speed := minf(BASE_SPEED + distance * 0.012, MAX_SPEED)
	_update_booster_timers(delta)
	_update_pickup_timers(delta)
	player.forward_speed = speed * 1.45 if booster_timers["turbo"] > 0.0 else speed
	track_manager.update_for_player(player.global_position.z)
	_spawn_rows()
	_cleanup_spawned_objects()

	score = int(distance * 1.5)
	ui.update_stats(score, coins, wallet, high_score)
	ui.update_boosters(boosters, booster_timers)
	ui.update_powerups(pickup_timers)
	_update_camera(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game", false) and game_state == GameState.PLAYING:
		_pause_run()
	elif event.is_action_pressed("use_shield", false):
		_activate_booster(&"shield")
	elif event.is_action_pressed("use_magnet", false):
		_activate_booster(&"magnet")
	elif event.is_action_pressed("use_turbo", false):
		_activate_booster(&"turbo")

func _start_run() -> void:
	get_tree().paused = false
	game_state = GameState.PLAYING
	score = 0
	coins = 0
	for booster in booster_timers:
		booster_timers[booster] = 0.0
	for pickup in pickup_timers:
		pickup_timers[pickup] = 0.0
	next_row_z = -30.0
	_train_route_active = false
	_last_train_lane = 1
	player.reset_runner()
	player.high_jump_enabled = false
	player.hoverboard_enabled = false
	player.input_enabled = true
	player.forward_speed = BASE_SPEED
	track_manager.reset_track()
	_clear_spawned_objects()
	ui.update_stats(0, 0, wallet, high_score)
	ui.update_boosters(boosters, booster_timers)
	ui.update_powerups(pickup_timers)
	ui.show_hud()
	_play_sound("start")

func _pause_run() -> void:
	if game_state != GameState.PLAYING:
		return
	game_state = GameState.PAUSED
	get_tree().paused = true
	ui.show_pause(high_score)

func _resume_run() -> void:
	if game_state != GameState.PAUSED:
		return
	get_tree().paused = false
	game_state = GameState.PLAYING
	ui.show_hud()

func _end_run() -> void:
	if game_state != GameState.PLAYING:
		return
	game_state = GameState.GAME_OVER
	player.input_enabled = false
	player.forward_speed = 0.0
	if score > high_score:
		high_score = score
		_save_progress()
	ui.show_game_over(score, high_score)
	_play_sound("crash")

func _open_shop() -> void:
	ui.show_shop(wallet, boosters)

func _close_shop() -> void:
	match game_state:
		GameState.PAUSED:
			ui.show_pause(high_score)
		GameState.GAME_OVER:
			ui.show_game_over(score, high_score)
		_:
			ui.show_title(high_score, volume, wallet, boosters)

func _buy_booster(booster: StringName) -> void:
	var key := String(booster)
	if not BOOSTER_PRICES.has(key):
		push_warning("Unbekannter Booster: %s" % key)
		return
	var price: int = BOOSTER_PRICES[key]
	if wallet < price:
		return
	wallet -= price
	boosters[key] = int(boosters.get(key, 0)) + 1
	_save_progress()
	ui.update_stats(score, coins, wallet, high_score)
	ui.update_shop(wallet, boosters)

func _activate_booster(booster: StringName) -> void:
	if game_state != GameState.PLAYING:
		return
	var key := String(booster)
	if not BOOSTER_DURATIONS.has(key) or booster_timers[key] > 0.0:
		return
	if int(boosters.get(key, 0)) <= 0:
		return
	boosters[key] = int(boosters[key]) - 1
	booster_timers[key] = float(BOOSTER_DURATIONS[key])
	_save_progress()
	ui.update_boosters(boosters, booster_timers)
	_play_sound("booster")

func _update_booster_timers(delta: float) -> void:
	for booster in booster_timers:
		booster_timers[booster] = maxf(float(booster_timers[booster]) - delta, 0.0)
	if booster_timers["magnet"] > 0.0:
		for spawned in spawned_objects.get_children():
			if spawned is NeonRunnerCoin and spawned.global_position.distance_to(player.global_position) <= 5.0:
				spawned.collect()

func _spawn_rows() -> void:
	while next_row_z > player.global_position.z - 90.0:
		_spawn_obstacle_row(next_row_z)
		next_row_z -= ROW_SPACING

func _spawn_obstacle_row(world_z: float) -> void:
	var safe_lanes: Array[int] = []
	var blocked_lanes: Array[int] = []
	var spawn_train := _train_route_active or _random.randf() < 0.48
	if spawn_train:
		var train_lane := _last_train_lane
		if not _train_route_active or _random.randf() >= 0.78:
			train_lane = _random.randi_range(0, 2)
		_last_train_lane = train_lane
		_train_route_active = _random.randf() < 0.72
		blocked_lanes.append(train_lane)
		_spawn_obstacle(NeonRunnerObstacle.Kind.TRAIN, train_lane, world_z)
	elif _random.randf() < 0.42:
		_train_route_active = false
		var first_lane := _random.randi_range(0, 2)
		var second_lane := (first_lane + _random.randi_range(1, 2)) % 3
		blocked_lanes.append_array([first_lane, second_lane])
		_spawn_obstacle(NeonRunnerObstacle.Kind.BARRIER, first_lane, world_z)
		_spawn_obstacle(NeonRunnerObstacle.Kind.OVERHEAD_GATE, second_lane, world_z)
	else:
		_train_route_active = false
		var blocked_lane := _random.randi_range(0, 2)
		blocked_lanes.append(blocked_lane)
		_spawn_obstacle(_random.randi_range(0, 2), blocked_lane, world_z)

	# Jede Reihe lässt mindestens eine Spur frei und legt die Münzspur dort entlang.
	for lane in range(3):
		if not blocked_lanes.has(lane):
			safe_lanes.append(lane)
	if _random.randf() < 0.78:
		var coin_count := _random.randi_range(3, 5)
		var zigzag := safe_lanes.size() > 1 and _random.randf() < 0.45
		var starting_lane: int = safe_lanes[_random.randi_range(0, safe_lanes.size() - 1)]
		for coin_index in range(coin_count):
			var coin_lane := starting_lane
			if zigzag:
				coin_lane = safe_lanes[coin_index % safe_lanes.size()]
			_spawn_coin(coin_lane, world_z - float(coin_index) * 1.8)
	if _random.randf() < 0.18:
		var pickup_lane: int = safe_lanes[_random.randi_range(0, safe_lanes.size() - 1)]
		_spawn_powerup(_random.randi_range(0, 2), pickup_lane, world_z - 10.0)

func _spawn_obstacle(kind: int, lane: int, world_z: float) -> void:
	var obstacle := OBSTACLE_SCENE.instantiate() as NeonRunnerObstacle
	obstacle.configure(kind, lane, world_z)
	obstacle.body_entered.connect(_on_obstacle_body_entered)
	spawned_objects.add_child(obstacle)

func _spawn_coin(lane: int, world_z: float) -> void:
	var coin := COIN_SCENE.instantiate() as NeonRunnerCoin
	coin.configure(lane, world_z)
	coin.collected.connect(_on_coin_collected)
	spawned_objects.add_child(coin)

func _spawn_powerup(type: int, lane: int, world_z: float) -> void:
	var powerup := POWERUP_SCENE.instantiate() as NeonRunnerPowerup
	powerup.configure(type, lane, world_z)
	powerup.collected.connect(_on_powerup_collected)
	spawned_objects.add_child(powerup)

func _cleanup_spawned_objects() -> void:
	for spawned in spawned_objects.get_children():
		if spawned.global_position.z > player.global_position.z + 35.0:
			spawned.queue_free()

func _clear_spawned_objects() -> void:
	for spawned in spawned_objects.get_children():
		spawned.queue_free()

func _on_obstacle_body_entered(body: Node3D) -> void:
	if body == player:
		if pickup_timers["hoverboard"] > 0.0:
			pickup_timers["hoverboard"] = 0.0
			player.hoverboard_enabled = false
			ui.update_powerups(pickup_timers)
			_play_sound("shield")
			return
		if booster_timers["shield"] > 0.0:
			booster_timers["shield"] = 0.0
			ui.update_boosters(boosters, booster_timers)
			_play_sound("shield")
			return
		_end_run()

func _on_coin_collected() -> void:
	var coin_value := 2 if pickup_timers["double_coins"] > 0.0 else 1
	coins += coin_value
	wallet += coin_value
	_save_progress()
	ui.update_stats(score, coins, wallet, high_score)
	_play_sound("coin")

func _on_powerup_collected(powerup_type: int) -> void:
	match powerup_type:
		NeonRunnerPowerup.HIGH_JUMP:
			pickup_timers["high_jump"] = 10.0
			player.high_jump_enabled = true
		NeonRunnerPowerup.DOUBLE_COINS:
			pickup_timers["double_coins"] = 12.0
		NeonRunnerPowerup.HOVERBOARD:
			pickup_timers["hoverboard"] = 10.0
			player.hoverboard_enabled = true
		_:
			push_warning("Unbekannter Power-up-Typ: %d" % powerup_type)
			return
	ui.update_powerups(pickup_timers)
	_play_sound("booster")

func _update_pickup_timers(delta: float) -> void:
	for pickup in pickup_timers:
		pickup_timers[pickup] = maxf(float(pickup_timers[pickup]) - delta, 0.0)
	player.high_jump_enabled = pickup_timers["high_jump"] > 0.0
	player.hoverboard_enabled = pickup_timers["hoverboard"] > 0.0

func _on_swipe_action(action: StringName) -> void:
	if game_state == GameState.PLAYING:
		player.perform_action(action)

func _on_player_action(action: StringName) -> void:
	if action == &"jump":
		_play_sound("jump")
	elif action == &"roll":
		_play_sound("booster")

func _configure_input_actions() -> void:
	_add_input_action(&"move_left", [KEY_A, KEY_LEFT])
	_add_input_action(&"move_right", [KEY_D, KEY_RIGHT])
	_add_input_action(&"move_jump", [KEY_W, KEY_UP, KEY_SPACE])
	_add_input_action(&"move_duck", [KEY_S, KEY_DOWN])
	_add_input_action(&"move_roll", [KEY_R, KEY_SHIFT])
	_add_input_action(&"use_shield", [KEY_1])
	_add_input_action(&"use_magnet", [KEY_2])
	_add_input_action(&"use_turbo", [KEY_3])
	_add_input_action(&"pause_game", [KEY_ESCAPE])

func _add_input_action(action: StringName, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keycodes:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = keycode
		if not InputMap.action_has_event(action, key_event):
			InputMap.action_add_event(action, key_event)

func _configure_world() -> void:
	camera.current = true
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.024, 0.08)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.33, 0.44, 0.72)
	environment.ambient_light_energy = 0.7
	environment.glow_enabled = true
	world_environment.environment = environment

func _update_camera(delta: float) -> void:
	var target := player.global_position + Vector3(0.0, 5.0, 9.5)
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-delta * 5.0))
	camera.look_at(player.global_position + Vector3(0.0, 1.0, -8.0), Vector3.UP)

func _configure_audio() -> void:
	_sound_player = AudioStreamPlayer.new()
	_sound_player.bus = "Master"
	add_child(_sound_player)
	_sound_library["start"] = _make_tone(660.0, 0.12)
	_sound_library["coin"] = _make_tone(1040.0, 0.09)
	_sound_library["jump"] = _make_tone(460.0, 0.08)
	_sound_library["crash"] = _make_tone(155.0, 0.28)
	_sound_library["booster"] = _make_tone(820.0, 0.16)
	_sound_library["shield"] = _make_tone(1240.0, 0.2)
	_apply_volume()

func _make_tone(frequency: float, duration: float) -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	var sample_count := int(float(SAMPLE_RATE) * duration)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for index in range(sample_count):
		var fade := 1.0 - float(index) / float(sample_count)
		var amplitude := sin(TAU * frequency * float(index) / float(SAMPLE_RATE)) * fade * 0.22
		samples.encode_s16(index * 2, int(amplitude * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = samples
	return stream

func _play_sound(sound_name: String) -> void:
	if _sound_player == null or not _sound_library.has(sound_name):
		return
	_sound_player.stop()
	_sound_player.stream = _sound_library[sound_name]
	_sound_player.play()

func _set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save_progress()

func _apply_volume() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(volume, 0.0001)))

func _load_progress() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_error("Spielstand konnte nicht gelesen werden: %s" % error_string(error))
		return
	high_score = int(config.get_value("progress", "high_score", 0))
	wallet = int(config.get_value("progress", "wallet", 0))
	for booster in boosters:
		boosters[booster] = int(config.get_value("progress", "booster_%s" % booster, 0))
	volume = clampf(float(config.get_value("settings", "volume", 0.7)), 0.0, 1.0)

func _save_progress() -> void:
	var config := ConfigFile.new()
	var load_error := config.load(SAVE_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_error("Vorhandene Einstellungen konnten nicht geladen werden: %s" % error_string(load_error))
		return
	config.set_value("progress", "high_score", high_score)
	config.set_value("progress", "wallet", wallet)
	for booster in boosters:
		config.set_value("progress", "booster_%s" % booster, boosters[booster])
	config.set_value("settings", "volume", volume)
	var save_error := config.save(SAVE_PATH)
	if save_error != OK:
		push_error("Spielstand konnte nicht gespeichert werden: %s" % error_string(save_error))
