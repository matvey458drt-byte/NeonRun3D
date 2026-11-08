extends Node3D

const LANES := [-2.4, 0.0, 2.4]
const SPEED_START := 13.0
const SPAWN_Z := -48.0

var player: CharacterBody3D
var camera: Camera3D
var world_root: Node3D
var hud: CanvasLayer
var score_label: Label
var message_label: Label
var best_label: Label
var lane := 1
var speed := SPEED_START
var score := 0.0
var coins := 0
var alive := true
var jump_velocity := 8.0
var gravity := 22.0
var slide_timer := 0.0
var spawn_timer := 0.0
var coin_timer := 0.0
var touch_start := Vector2.ZERO
var best := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	best = int(ConfigFile.new().get_value("save", "best", 0))
	_build_world()
	_build_hud()
	_reset_player()

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.02, 0.07)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.55, 0.9)
	environment.ambient_light_energy = 0.8
	env.environment = environment
	add_child(env)

	camera = Camera3D.new()
	camera.position = Vector3(0, 7.5, 11)
	camera.rotation_degrees = Vector3(-27, 0, 0)
	camera.current = true
	add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.2
	add_child(light)

	world_root = Node3D.new()
	add_child(world_root)
	_make_box(world_root, Vector3(0, -0.55, -22), Vector3(9, 1, 65), Color(0.055, 0.07, 0.14))
	for x in [-3.7, -1.2, 1.2, 3.7]:
		_make_box(world_root, Vector3(x, 0.02, -22), Vector3(0.055, 0.035, 65), Color(0.0, 0.8, 1.0))
	for z in range(-50, 15, 5):
		_make_box(world_root, Vector3(0, 0.015, z), Vector3(7.2, 0.025, 0.035), Color(0.12, 0.18, 0.3))

func _make_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.35
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance

func _reset_player() -> void:
	if is_instance_valid(player):
		player.queue_free()
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.95, 3)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 1.8
	shape.shape = capsule
	player.add_child(shape)
	var body := _make_box(player, Vector3(0, 0, 0), Vector3(0.75, 1.35, 0.65), Color(0.0, 0.85, 1.0))
	body.position.y = 0.05
	add_child(player)
	lane = 1
	slide_timer = 0.0

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var panel := ColorRect.new()
	panel.color = Color(0.01, 0.025, 0.08, 0.72)
	panel.position = Vector2(18, 18)
	panel.size = Vector2(330, 112)
	hud.add_child(panel)
	score_label = _label("DISTANCE  0 m", 34, Vector2(34, 28), Vector2(310, 42))
	best_label = _label("BEST  %d m" % best, 23, Vector2(34, 75), Vector2(280, 32))
	message_label = _label("SWIPE  ←  →   JUMP ↑   SLIDE ↓", 24, Vector2(20, 0), Vector2(680, 90))
	message_label.position = Vector2(20, 1120)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _label(value: String, font_size: int, pos: Vector2, size: Vector2) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
	hud.add_child(label)
	return label

func _process(delta: float) -> void:
	if not alive:
		return
	speed += delta * 0.12
	score += delta * speed
	score_label.text = "DISTANCE  %d m   •   ◈ %d" % [int(score), coins]
	best_label.text = "BEST  %d m" % best
	spawn_timer -= delta
	coin_timer -= delta
	if spawn_timer <= 0:
		_spawn_obstacle()
		spawn_timer = max(0.62, 1.25 - speed * 0.025) + rng.randf_range(0.0, 0.35)
	if coin_timer <= 0:
		_spawn_coin_line()
		coin_timer = 2.0
	for item in world_root.get_children():
		if item.has_meta("moving"):
			item.position.z += speed * delta
			if item.position.z > 12:
				item.queue_free()
	if slide_timer > 0:
		slide_timer -= delta
		if slide_timer <= 0 and is_instance_valid(player):
			player.scale.y = 1.0
	if is_instance_valid(player):
		player.position.x = lerp(player.position.x, LANES[lane], min(1.0, delta * 13.0))
		player.velocity.y -= gravity * delta
		player.move_and_slide()
		if player.position.y < 0.95:
			player.position.y = 0.95
			player.velocity.y = 0
		_check_hits()

func _spawn_obstacle() -> void:
	var obstacle := Area3D.new()
	obstacle.position = Vector3(LANES[rng.randi_range(0, 2)], 0.9, SPAWN_Z)
	obstacle.set_meta("moving", true)
	var kind := rng.randi_range(0, 2)
	var dims := Vector3(1.35, 1.8, 1.0)
	var color := Color(1.0, 0.18, 0.32)
	if kind == 1:
		dims = Vector3(1.35, 0.8, 1.0)
		color = Color(1.0, 0.55, 0.05)
	elif kind == 2:
		dims = Vector3(1.45, 2.7, 0.7)
		color = Color(0.75, 0.2, 1.0)
	obstacle.set_meta("kind", kind)
	var visual := _make_box(obstacle, Vector3.ZERO, dims, color)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dims
	collision.shape = box
	obstacle.add_child(collision)
	world_root.add_child(obstacle)

func _spawn_coin_line() -> void:
	var x: float = float(LANES[rng.randi_range(0, 2)])
	for i in range(5):
		var coin := Area3D.new()
		coin.position = Vector3(x, 1.25, SPAWN_Z - i * 1.7)
		coin.set_meta("moving", true)
		coin.set_meta("coin", true)
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.28
		sphere.height = 0.56
		mesh.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.82, 0.05)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.6, 0.0)
		mesh.material_override = mat
		coin.add_child(mesh)
		world_root.add_child(coin)

func _check_hits() -> void:
	for item in world_root.get_children():
		if not item.has_meta("moving") or abs(item.position.z - player.position.z) > 0.85:
			continue
		if abs(item.position.x - player.position.x) > 0.8:
			continue
		if item.has_meta("coin"):
			coins += 1
			item.queue_free()
			continue
		var kind: int = int(item.get_meta("kind"))
		if kind == 1 and player.position.y > 1.7:
			continue
		if kind == 2 and slide_timer > 0.12:
			continue
		if kind == 0 and player.position.y > 1.8:
			continue
		_game_over()
		return

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
		else:
			_handle_swipe(event.position - touch_start)
	elif event is InputEventScreenDrag:
		pass
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT: _move_lane(-1)
			KEY_RIGHT: _move_lane(1)
			KEY_UP, KEY_SPACE: _jump()
			KEY_DOWN: _slide()
			KEY_ENTER: if not alive: _restart()

func _handle_swipe(v: Vector2) -> void:
	if not alive:
		_restart()
		return
	if v.length() < 35:
		return
	if abs(v.x) > abs(v.y):
		_move_lane(1 if v.x > 0 else -1)
	elif v.y < 0:
		_jump()
	else:
		_slide()

func _move_lane(direction: int) -> void:
	if alive:
		lane = clampi(lane + direction, 0, 2)

func _jump() -> void:
	if alive and player.position.y <= 0.96:
		player.velocity.y = jump_velocity

func _slide() -> void:
	if alive and slide_timer <= 0:
		slide_timer = 0.65
		player.scale.y = 0.55

func _game_over() -> void:
	alive = false
	var result := int(score)
	if result > best:
		best = result
		var save := ConfigFile.new()
		save.set_value("save", "best", best)
		save.save("user://record.cfg")
	message_label.text = "GAME OVER  •  %d m  •  TAP TO RETRY" % result
	message_label.position = Vector2(20, 1040)

func _restart() -> void:
	for item in world_root.get_children():
		if item.has_meta("moving"):
			item.queue_free()
	score = 0
	coins = 0
	speed = SPEED_START
	spawn_timer = 0.5
	coin_timer = 1.0
	alive = true
	message_label.text = "SWIPE  ←  →   JUMP ↑   SLIDE ↓"
	message_label.position = Vector2(20, 1120)
	_reset_player()
