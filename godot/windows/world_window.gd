class_name WorldWindow
extends Window

const PlacePaint = preload("res://school/paint.gd")
const PetSync = preload("res://school/sync.gd")
const PixelPetScene = preload("res://pet/pixel_pet.tscn")
const SchoolLogic = preload("res://school/school_logic.gd")
const SchoolSocial = preload("res://school/school_social.gd")
const HomeLogic = preload("res://home/home_logic.gd")
const WeatherDress = preload("res://weather/weather_dress.gd")
const GameView = preload("res://game/game_view.gd")
const BbPetTheme = preload("res://ui/bbpet_theme.gd")
const CAMERA_SCALE := 1.8

@onready var _status: Label = $VBox/Status
@onready var _stage: Control = $VBox/Stage
@onready var _map_root: Node2D = $VBox/Stage/MapRoot
@onready var _map_texture: TextureRect = $VBox/Stage/MapRoot/Map
@onready var _chat_bar: VBoxContainer = $VBox/ChatBar
@onready var _chat_hint: Label = $VBox/ChatBar/ChatHint
@onready var _chat_input: LineEdit = $VBox/ChatBar/ChatRow/ChatInput
@onready var _chat_send: Button = $VBox/ChatBar/ChatRow/ChatSend

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
var _alert := ""
var _inspect_id := ""
var _inspect_menu: Control
var _board_overlay: Control
var _bubbles: Dictionary = {}
var _invite_bar: HBoxContainer
var _invite_tick: Timer


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
	_stage.gui_input.connect(_on_stage_input)
	_map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_hint.text = "黑板只有本班听得见"
	_chat_input.placeholder_text = "点这里或按 Enter 写黑板"
	_chat_send.text = "发送"
	BbPetTheme.apply_input(_chat_input)
	BbPetTheme.apply_hint(_chat_hint)
	BbPetTheme.apply_button(_chat_send, "main")
	_chat_send.pressed.connect(_submit_chat)
	_chat_input.text_submitted.connect(func(_t): _submit_chat())
	if not RoomClient.chat_received.is_connected(_on_chat_received):
		RoomClient.chat_received.connect(_on_chat_received)
	if not RoomClient.friends_changed.is_connected(_on_friends_changed_world):
		RoomClient.friends_changed.connect(_on_friends_changed_world)
	if not RoomClient.dress_updated.is_connected(_on_dress_updated):
		RoomClient.dress_updated.connect(_on_dress_updated)
	if not WeatherClient.weather_changed.is_connected(_on_weather_changed):
		WeatherClient.weather_changed.connect(_on_weather_changed)
	if not RoomClient.game_updated.is_connected(_on_game_updated_world):
		RoomClient.game_updated.connect(_on_game_updated_world)
	var invite_wrap := PanelContainer.new()
	invite_wrap.name = "InviteBar"
	BbPetTheme.apply_panel(invite_wrap)
	_invite_bar = HBoxContainer.new()
	_invite_bar.add_theme_constant_override("separation", 8)
	invite_wrap.add_child(_invite_bar)
	$VBox.add_child(invite_wrap)
	$VBox.move_child(invite_wrap, 1)
	_invite_tick = Timer.new()
	_invite_tick.wait_time = 0.2
	_invite_tick.timeout.connect(_refresh_invite)
	add_child(_invite_tick)
	_invite_tick.start()
	_refresh_invite()


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
	if not _has_other(_inspect_id):
		_close_inspect()
	_alert = ""
	_update_status()
	_update_camera()
	_refresh_board()
	_refresh_chat_bar()


func apply_others(people: Array) -> void:
	if _place.is_empty() or _you.is_empty():
		return
	var incoming: Array = []
	for person in people:
		if person.get("clientId", "") != _you.get("clientId", ""):
			incoming.append(person.duplicate(true))
	_apply_incoming_people(incoming)
	_sync_pet_nodes()
	if not _has_other(_inspect_id):
		_close_inspect()
	_update_status()


func show_status(text: String) -> void:
	_alert = text
	_update_status()


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
	_refresh_nearby_bubbles()
	_update_camera()
	if _place.is_empty() or _you.is_empty() or not has_focus() or _chat_focused():
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


func _chat_focused() -> bool:
	return is_instance_valid(_chat_input) and _chat_input.has_focus()


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
		_attach_dress(pet)
	var species := String(data.get("species", "blob"))
	if not PetTemplates.DEFAULT_COLORS.has(species):
		species = "blob"
	var incoming_colors: Variant = data.get("colors", {})
	if not incoming_colors is Dictionary:
		incoming_colors = {}
	pet.species = species
	pet.colors = PetTemplates.colors_for(species, incoming_colors)
	pet.pose = "talk" if _show_bubble_for(id, data) else "idle"
	pet.pixel_size = 2
	pet.flip = data.get("facing", "r") == "l"
	pet.redraw()
	_apply_pet_dress(id, data, pet)
	pet.mouse_filter = Control.MOUSE_FILTER_STOP
	for conn in pet.gui_input.get_connections():
		pet.gui_input.disconnect(conn.callable)
	if id == "self":
		pet.gui_input.connect(_on_self_pet_input)
	else:
		pet.gui_input.connect(_on_other_pet_input.bind(id))


func _attach_dress(pet: Node) -> Control:
	var overlay: Control = pet.get_node_or_null("WeatherDress")
	if overlay != null:
		return overlay
	overlay = WeatherDress.new()
	overlay.name = "WeatherDress"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pet.add_child(overlay)
	return overlay


func _dress_for(id: String, data: Dictionary) -> Dictionary:
	if id == "self":
		return WeatherClient.last_dress
	if RoomClient.dresses.has(id):
		var cached: Variant = RoomClient.dresses[id]
		if cached is Dictionary:
			return cached
	var from_person: Variant = data.get("dress", {})
	if from_person is Dictionary:
		return from_person
	return {}


func _apply_pet_dress(id: String, data: Dictionary, pet: Node = null) -> void:
	if pet == null:
		pet = _pet_nodes.get(id)
	if pet == null:
		return
	var overlay := _attach_dress(pet)
	if overlay.has_method("apply"):
		overlay.call("apply", _dress_for(id, data))
	var pixel := 4
	if pet.get("pixel_size") != null:
		pixel = int(pet.pixel_size)
	overlay.scale = Vector2(float(pixel) / 4.0, float(pixel) / 4.0)


func _refresh_dresses() -> void:
	if _pet_nodes.has("self") and not _you.is_empty():
		_apply_pet_dress("self", _you)
	for person in _others:
		_apply_pet_dress(String(person.get("clientId", "")), person)


func _on_dress_updated() -> void:
	if visible:
		_refresh_dresses()


func _on_weather_changed(_info: Dictionary) -> void:
	if visible:
		_refresh_dresses()


func _on_self_pet_input(event: InputEvent) -> void:
	if _is_left_click(event):
		_close_inspect()


func _on_other_pet_input(event: InputEvent, client_id: String) -> void:
	if not _is_left_click(event):
		return
	_open_inspect(client_id)


func _on_stage_input(event: InputEvent) -> void:
	if not _is_left_click(event):
		return
	_close_inspect()
	var focus := get_viewport().gui_get_focus_owner()
	if focus:
		focus.release_focus()


func _submit_chat() -> void:
	if not is_instance_valid(_chat_input):
		return
	RoomClient.send_chat(_chat_input.text)
	_chat_input.text = ""


func _on_chat_received(line: Dictionary) -> void:
	if SchoolSocial.chat_kind_for(_place) == "nearby" or String(line.get("kind", "")) == "nearby":
		var id := String(line.get("clientId", ""))
		if not id.is_empty():
			_bubbles[id] = {
				"text": String(line.get("text", "")),
				"until": Time.get_ticks_msec() + int(SchoolSocial.NEARBY_BUBBLE_MS),
			}
	_refresh_board()
	_refresh_nearby_bubbles()


func _on_friends_changed_world(_friends: Array) -> void:
	if not _inspect_id.is_empty():
		_open_inspect(_inspect_id)
	_refresh_invite()


func _on_game_updated_world(_game: Dictionary) -> void:
	if not _inspect_id.is_empty():
		_open_inspect(_inspect_id)
	_refresh_invite()


func _refresh_chat_bar() -> void:
	var school := SchoolLogic.is_school_place(_place_id)
	_chat_bar.visible = school
	if not school:
		return
	if _classroom_now():
		_chat_hint.text = "黑板只有本班听得见"
		_chat_input.placeholder_text = "点这里或按 Enter 写黑板"
	else:
		_chat_hint.text = "走近才看得到气泡"
		_chat_input.placeholder_text = "点这里或按 Enter 说话"


func _show_bubble_for(id: String, data: Dictionary) -> bool:
	var client_id := String(_you.get("clientId", "")) if id == "self" else String(data.get("clientId", id))
	var bubble: Dictionary = _bubbles.get(client_id, {})
	if bubble.is_empty():
		return false
	if int(bubble.get("until", 0)) <= Time.get_ticks_msec():
		_bubbles.erase(client_id)
		return false
	if id == "self" or _classroom_now():
		return true
	return SchoolSocial.nearby_visible(
		float(_you.get("x", 0)),
		float(_you.get("y", 0)),
		float(data.get("x", 0)),
		float(data.get("y", 0))
	)


func _refresh_nearby_bubbles() -> void:
	var now := Time.get_ticks_msec()
	for id in _bubbles.keys():
		if int(_bubbles[id].until) <= now:
			_bubbles.erase(id)
	for id in _pet_nodes.keys():
		var pet: Node = _pet_nodes[id]
		var data: Dictionary = _you if id == "self" else {}
		if id != "self":
			for person in _others:
				if String(person.get("clientId", "")) == id:
					data = person
					break
		var show := _show_bubble_for(id, data)
		pet.pose = "talk" if show else "idle"
		pet.redraw()
		var label: Label = pet.get_node_or_null("NearbyBubble")
		if show:
			if label == null:
				label = Label.new()
				label.name = "NearbyBubble"
				label.position = Vector2(-10, -18)
				label.add_theme_font_size_override("font_size", 10)
				label.add_theme_color_override("font_color", Color("#24382c"))
				pet.add_child(label)
			var key: String = String(_you.get("clientId", "")) if id == "self" else id
			label.text = String(_bubbles.get(key, {}).get("text", ""))
			label.visible = true
		elif label != null:
			label.visible = false


func _classroom_now() -> bool:
	return SchoolSocial.is_classroom_place(_place)


func _refresh_board() -> void:
	if is_instance_valid(_board_overlay):
		_board_overlay.queue_free()
		_board_overlay = null
	_refresh_chat_bar()
	if not _classroom_now():
		return
	var overlay := Control.new()
	_board_overlay = overlay
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var map_w: float = float(SchoolLogic.map_size(_place).cols * SchoolLogic.TILE)
	overlay.position = Vector2(SchoolSocial.BOARD_LEFT, SchoolSocial.BOARD_TOP)
	overlay.size = Vector2(map_w - SchoolSocial.BOARD_SIDE_PAD * 2.0, SchoolSocial.BOARD_HEIGHT)
	var bg := ColorRect.new()
	bg.color = Color("#24382c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)
	var lines := VBoxContainer.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.add_theme_constant_override("separation", 2)
	overlay.add_child(lines)
	var visible: Array = SchoolSocial.visible_board(RoomClient.board)
	if visible.is_empty():
		var empty := Label.new()
		empty.text = "黑板还是空的，回车写一句。"
		empty.add_theme_color_override("font_color", Color("#e8f0c8"))
		empty.add_theme_font_size_override("font_size", 12)
		lines.add_child(empty)
	else:
		for line in visible:
			var row := Label.new()
			row.text = "%s：%s" % [String(line.get("name", "")), String(line.get("text", ""))]
			row.add_theme_color_override("font_color", Color("#e8f0c8"))
			row.add_theme_font_size_override("font_size", 12)
			lines.add_child(row)
	_map_root.add_child(overlay)


func _is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func _open_inspect(client_id: String) -> void:
	var person: Dictionary = {}
	for item in _others:
		if String(item.get("clientId", "")) == client_id:
			person = item
			break
	if person.is_empty():
		return
	_inspect_id = client_id
	if is_instance_valid(_inspect_menu):
		_inspect_menu.queue_free()
	var menu := PanelContainer.new()
	_inspect_menu = menu
	BbPetTheme.apply_panel(menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	menu.add_child(box)
	var name_label := Label.new()
	name_label.text = String(person.get("name", ""))
	BbPetTheme.apply_heading(name_label)
	box.add_child(name_label)
	var kind := SchoolSocial.friend_menu_kind(client_id, SchoolSocial.friend_ids(RoomClient.friends))
	if kind == "already":
		var card: Dictionary = {}
		for item in RoomClient.friends:
			if String(item.get("clientId", "")) == client_id:
				card = item
				break
		var visit := Button.new()
		if HomeLogic.is_friend_at_home(card):
			visit.text = "去他家"
			BbPetTheme.apply_button(visit, "pill")
			visit.pressed.connect(func():
				WindowHub.go_home(client_id)
				_close_inspect()
			)
		else:
			visit.text = "不在家"
			visit.disabled = true
			BbPetTheme.apply_button(visit, "ghost")
		if GameView.can_invite_friend(RoomClient.game, String(_you.get("clientId", "")), card):
			var play := Button.new()
			play.text = "五子棋"
			BbPetTheme.apply_button(play, "pill")
			play.pressed.connect(func():
				RoomClient.invite_game(client_id)
				_close_inspect()
			)
			box.add_child(play)
		box.add_child(visit)
	else:
		var add := Button.new()
		add.text = "加好友"
		BbPetTheme.apply_button(add, "main")
		add.pressed.connect(func():
			RoomClient.request_friend(client_id)
			_close_inspect()
		)
		box.add_child(add)
	var cancel := Button.new()
	cancel.text = "取消"
	BbPetTheme.apply_button(cancel, "ghost")
	cancel.pressed.connect(_close_inspect)
	box.add_child(cancel)
	_stage.add_child(menu)
	var screen := _map_root.position + Vector2(float(person.x), float(person.y)) * _map_root.scale
	menu.position = Vector2(maxi(8, int(screen.x + 36)), maxi(8, int(screen.y)))


func _close_inspect() -> void:
	_inspect_id = ""
	if is_instance_valid(_inspect_menu):
		_inspect_menu.queue_free()
	_inspect_menu = null


func _has_other(client_id: String) -> bool:
	if client_id.is_empty():
		return true
	for person in _others:
		if String(person.get("clientId", "")) == client_id:
			return true
	return false


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
	if not _alert.is_empty():
		_status.text = _alert
	elif _place.is_empty():
		_status.text = "正在走进校门..."
	else:
		_status.text = "%s · %d人 · WASD 移动 · 点同学加好友 · %s" % [
			_place.title,
			_others.size() + 1,
			"黑板只有本班听得见" if _classroom_now() else "走近才看得到气泡",
		]
	_refresh_invite()


func _refresh_invite() -> void:
	if _invite_bar == null:
		return
	var wrap: Control = _invite_bar.get_parent()
	for child in _invite_bar.get_children():
		child.free()
	var game: Dictionary = RoomClient.game
	if not GameView.is_incoming_invite(game):
		_invite_bar.visible = false
		if wrap:
			wrap.visible = false
		return
	_invite_bar.visible = true
	if wrap:
		wrap.visible = true
	var black: Dictionary = game.get("black", {}) if game.get("black") is Dictionary else {}
	var now_ms := int(Time.get_unix_time_from_system() * 1000.0)
	var seconds: int = GameView.seconds_left(int(game.get("deadlineAt", 0)), now_ms)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "%s 邀请你下五子棋 %d秒" % [String(black.get("name", "")), seconds]
	BbPetTheme.apply_heading(label)
	_invite_bar.add_child(label)
	var accept := Button.new()
	accept.text = "接受"
	BbPetTheme.apply_button(accept, "main")
	var game_id := String(game.get("id", ""))
	accept.pressed.connect(func(): RoomClient.game_respond(game_id, true))
	_invite_bar.add_child(accept)
	var decline := Button.new()
	decline.text = "拒绝"
	BbPetTheme.apply_button(decline, "ghost")
	decline.pressed.connect(func(): RoomClient.game_respond(game_id, false))
	_invite_bar.add_child(decline)


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
