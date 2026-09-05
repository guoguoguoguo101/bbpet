class_name WorldWindow
extends Window

const PlacePaint = preload("res://school/paint.gd")
const PetSync = preload("res://school/sync.gd")
const PixelPetScene = preload("res://pet/pixel_pet.tscn")
const SchoolLogic = preload("res://school/school_logic.gd")
const CAMERA_SCALE := 1.8

@onready var _status: Label = $VBox/Status
@onready var _stage: Control = $VBox/Stage
@onready var _map_root: Node2D = $VBox/Stage/MapRoot
@onready var _map_texture: TextureRect = $VBox/Stage/MapRoot/Map

var _place_id := ""
var _place: Dictionary = {}
var _you: Dictionary = {}
var _others: Array = []
var _motions: Dictionary = {}
var _pet_nodes: Dictionary = {}
var _label_nodes: Array[Label] = []
var _last_send_ms := 0
var _ignore_door_until_ms := 0
var _was_moving := false


func _ready() -> void:
	title = "学校"
	min_size = Vector2i(520, 380)
	transparent = false
	always_on_top = false
	var settings: Dictionary = AppState.state.settings
	size = Vector2i(
		maxi(520, int(settings.worldWidth)),
		maxi(380, int(settings.worldHeight))
	)
	close_requested.connect(WindowHub.close_world)
	_stage.resized.connect(_update_camera)


func apply_snapshot(you: Dictionary, people: Array, place_id: String) -> void:
	if not SchoolLogic.is_school_place(place_id):
		return
	_place_id = place_id
	_place = SchoolLogic.PLACES[place_id]
	_you = you.duplicate(true)
	_ignore_door_until_ms = Time.get_ticks_msec() + 800

	var incoming: Array = []
	for person in people:
		if person.get("clientId", "") != _you.get("clientId", ""):
			incoming.append(person.duplicate(true))
	_apply_incoming_people(incoming)

	_rebuild_map()
	_sync_pet_nodes()
	_update_status()
	_update_camera()


func apply_others(people: Array) -> void:
	if _place.is_empty() or _you.is_empty():
		return
	var incoming: Array = []
	for person in people:
		if person.get("clientId", "") != _you.get("clientId", ""):
			incoming.append(person.duplicate(true))
	_apply_incoming_people(incoming)
	_sync_pet_nodes()
	_update_status()


func show_status(text: String) -> void:
	if is_instance_valid(_status):
		_status.text = text


func _apply_incoming_people(incoming: Array) -> void:
	var visual := PetSync.keep_visual_people(_others, incoming)
	_others = visual
	_motions.clear()
	var now := float(Time.get_ticks_msec())
	for index in incoming.size():
		var shown: Dictionary = visual[index]
		var target: Dictionary = incoming[index]
		_motions[target.clientId] = {
			"from_x": float(shown.x),
			"from_y": float(shown.y),
			"to_x": float(target.x),
			"to_y": float(target.y),
			"from_facing": shown.get("facing", "r"),
			"facing": target.get("facing", "r"),
			"from_at": now,
		}


func _physics_process(delta: float) -> void:
	_interpolate_others()
	_sync_pet_transforms()
	_update_camera()
	if _place.is_empty() or _you.is_empty() or not has_focus():
		return

	var direction := _movement_direction()
	var now_ms := Time.get_ticks_msec()
	if direction == Vector2.ZERO:
		if _was_moving:
			_send_current_pose()
			_last_send_ms = now_ms
		_was_moving = false
		return

	_was_moving = true
	var next := Vector2(float(_you.x), float(_you.y))
	next += direction * SchoolLogic.MOVE_SPEED * minf(delta, 0.05)
	var moved := SchoolLogic.clamp_move(_place, _you.x, _you.y, next.x, next.y)
	_you.x = moved.x
	_you.y = moved.y
	if direction.x < 0.0:
		_you.facing = "l"
	elif direction.x > 0.0:
		_you.facing = "r"
	_sync_pet_transforms()

	if now_ms - _last_send_ms >= SchoolLogic.MOVE_SEND_MS:
		_send_current_pose()
		_last_send_ms = now_ms
	if now_ms >= _ignore_door_until_ms:
		_handle_trigger(now_ms)


func _movement_direction() -> Vector2:
	var x := int(
		Input.is_physical_key_pressed(KEY_D)
		or Input.is_physical_key_pressed(KEY_RIGHT)
	) - int(
		Input.is_physical_key_pressed(KEY_A)
		or Input.is_physical_key_pressed(KEY_LEFT)
	)
	var y := int(
		Input.is_physical_key_pressed(KEY_S)
		or Input.is_physical_key_pressed(KEY_DOWN)
	) - int(
		Input.is_physical_key_pressed(KEY_W)
		or Input.is_physical_key_pressed(KEY_UP)
	)
	var direction := Vector2(x, y)
	return direction.normalized() if direction != Vector2.ZERO else direction


func _send_current_pose() -> void:
	var rounded := PetSync.round_pose(float(_you.x), float(_you.y))
	RoomClient.send_move(rounded.x, rounded.y, _you.get("facing", "r"))


func _handle_trigger(now_ms: int) -> void:
	var trigger: Variant = SchoolLogic.trigger_at(_place, _you.x, _you.y)
	if trigger == null:
		return
	match trigger.kind:
		"exit":
			WindowHub.close_world()
		"campus":
			_ignore_door_until_ms = now_ms + 800
			RoomClient.enter_place("school:campus")
		"classroom":
			_ignore_door_until_ms = now_ms + 800
			RoomClient.enter_place(trigger.place_id)


func _rebuild_map() -> void:
	var image := PlacePaint.image_for(_place)
	_map_texture.texture = ImageTexture.create_from_image(image)
	_map_texture.size = Vector2(image.get_width(), image.get_height())
	for label in _label_nodes:
		label.queue_free()
	_label_nodes.clear()
	for data in _place.labels:
		var width := 52.0 if String(data.text).length() > 2 else 40.0
		_add_map_label(
			String(data.text),
			Vector2(
				float(data.tx * SchoolLogic.TILE) + SchoolLogic.TILE / 2.0,
				float(data.ty * SchoolLogic.TILE) + SchoolLogic.TILE / 2.0
			),
			Vector2(width, 18.0),
			Color("#fff8f2")
		)
	if _place.kind == "campus":
		var map_size := SchoolLogic.map_size(_place)
		_add_map_label(
			"校门口 · 往上走进教室",
			Vector2(map_size.cols * SchoolLogic.TILE / 2.0, 13 * SchoolLogic.TILE + 15.0),
			Vector2(140.0, 22.0),
			Color("#c8f5e4")
		)


func _add_map_label(text: String, center: Vector2, label_size: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = center - label_size / 2.0
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 12)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#3d2c29")
	label.add_theme_stylebox_override("normal", box)
	label.z_index = 1
	_map_root.add_child(label)
	_label_nodes.append(label)


func _sync_pet_nodes() -> void:
	var wanted := {"self": true}
	for person in _others:
		wanted[person.clientId] = true
	for id in _pet_nodes.keys():
		if not wanted.has(id):
			_pet_nodes[id].queue_free()
			_pet_nodes.erase(id)
	_configure_pet("self", _you)
	for person in _others:
		_configure_pet(person.clientId, person)
	_sync_pet_transforms()


func _configure_pet(id: String, data: Dictionary) -> void:
	var pet: Variant = _pet_nodes.get(id)
	if pet == null:
		pet = PixelPetScene.instantiate()
		_map_root.add_child(pet)
		_pet_nodes[id] = pet
	pet.species = data.get("species", "blob")
	pet.colors = data.get("colors", AppState.state.pet.colors).duplicate(true)
	pet.pose = "idle"
	pet.pixel_size = 2
	pet.flip = data.get("facing", "r") == "l"
	pet.redraw()


func _interpolate_others() -> void:
	var now := float(Time.get_ticks_msec())
	for index in _others.size():
		var person: Dictionary = _others[index]
		var motion: Dictionary = _motions.get(person.clientId, {})
		if motion.is_empty():
			continue
		var pose := PetSync.interpolate_pose(
			motion.from_x,
			motion.from_y,
			motion.to_x,
			motion.to_y,
			motion.from_at,
			now
		)
		person.x = pose.x
		person.y = pose.y
		person.facing = PetSync.pose_facing(motion.from_facing, motion.facing, pose.t)
		_others[index] = person


func _sync_pet_transforms() -> void:
	if _pet_nodes.has("self") and not _you.is_empty():
		_position_pet(_pet_nodes.self, _you)
	for person in _others:
		if _pet_nodes.has(person.clientId):
			_position_pet(_pet_nodes[person.clientId], person)


func _position_pet(pet: Variant, data: Dictionary) -> void:
	pet.position = Vector2(float(data.x), float(data.y))
	pet.flip = data.get("facing", "r") == "l"
	pet.flip_h = pet.flip
	pet.z_index = 10 + int(data.y)


func _update_status() -> void:
	if _place.is_empty():
		_status.text = "正在走进校门..."
	else:
		_status.text = "%s · %d 人在这里" % [_place.title, _others.size() + 1]


func _update_camera() -> void:
	if _place.is_empty() or _you.is_empty() or not is_instance_valid(_stage):
		return
	var map_size := SchoolLogic.map_size(_place)
	var camera := SchoolLogic.camera_for(
		CAMERA_SCALE,
		float(_you.x),
		float(_you.y),
		_stage.size.x,
		_stage.size.y,
		map_size.cols * SchoolLogic.TILE,
		map_size.rows * SchoolLogic.TILE
	)
	_map_root.position = Vector2(camera.left, camera.top)
	_map_root.scale = Vector2(camera.scale, camera.scale)
