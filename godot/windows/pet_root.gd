extends Control

const PixelPetScene = preload("res://pet/pixel_pet.tscn")
const HomeLogic = preload("res://home/home_logic.gd")
const WeatherDress = preload("res://weather/weather_dress.gd")
const IdleLife = preload("res://pet/idle_life.gd")
const BbPetTheme = preload("res://ui/bbpet_theme.gd")

const PET_SIZE := Vector2i(64, 86)
const PET_OFFSET := Vector2(0, 11)
const DRAG_THRESHOLD := 4.0
const MENU_HIDE := 0
const MENU_QUIT := 1
const MENU_IDLE := 10
const MENU_TALK := 11
const MENU_DRINK := 12
const MENU_SLEEP := 13
const MENU_PHONE := 14
const MENU_WX_SUN := 20
const MENU_WX_RAIN := 21
const SLOT_PIXEL := 4
const SLOT_PET_LEFT := 4.0
const SLOT_PET_TOP := 14.0
const CAPTION_H := 14.0
const PLATE_H := 14.0
const LOG_LIMIT := 24
const BUBBLE_MS := 5000
const TICK_SECONDS := 0.4
const TITLE_HOME := "自家"
const CHAT_HINT := "回车发送"
const EMOTE_MENU_W := 46.0
const EMOTE_ROW_H := 22.0
const EMOTES := [
	["hug", "抱抱"],
	["pour", "倒水"],
	["wake", "拍醒"],
	["kick", "飞踢"],
]
const BAR_BG := Color("#3d2c29")
const LOG_BG := Color("#24382c")
const BAR_TEXT := Color("#fff8f2")
const LOG_TEXT := Color("#e8f0c8")

@onready var pixel_pet := $PixelPet
@onready var context_menu: PopupMenu = $ContextMenu

var _dragging := false
var _press_position := Vector2i.ZERO
var _gathering := false
var _chatting := false
var _menu_for := ""
var _cool_until_ms := 0
var _bubbles: Dictionary = {}
var _slots: Dictionary = {}
var _emote_at_ms := 0
var _last_chat_id := ""
var _layout_signature := ""
var _gathering_root: Control
var _slot_root: Control
var _log_root: Control
var _log_lines: VBoxContainer
var _bar_root: Control
var _bar_title: Label
var _bar_count: Label
var _bar_spacer: Control
var _bar_chat: Button
var _bar_input: LineEdit
var _bar_close: Button
var _emote_menu: Control
var _emote_buttons: Array[Button] = []
var _solo_dress: Control
var _pose_lock_until := 0
var _airborne_id := ""
var _key_pid := -1
var _typing_until := 0
var _sense_skip := false


func _ready() -> void:
	var win := get_window()
	win.borderless = true
	win.unresizable = true
	win.always_on_top = true
	win.transparent = true
	win.size = PET_SIZE
	var usable_area := DisplayServer.screen_get_usable_rect()
	win.position = Vector2i(usable_area.end.x - 72, usable_area.end.y - 94)

	pixel_pet.position = PET_OFFSET
	var pet: Dictionary = AppState.state.pet
	pixel_pet.species = pet.species
	pixel_pet.colors = pet.colors.duplicate(true)
	pixel_pet.pixel_size = 4
	_set_pose("idle")

	context_menu.add_item("发呆", MENU_IDLE)
	context_menu.add_item("说话", MENU_TALK)
	context_menu.add_item("喝水", MENU_DRINK)
	context_menu.add_item("睡觉", MENU_SLEEP)
	context_menu.add_item("刷手机", MENU_PHONE)
	context_menu.add_separator()
	context_menu.add_item("晴天", MENU_WX_SUN)
	context_menu.add_item("下雨", MENU_WX_RAIN)
	context_menu.add_separator()
	context_menu.add_item("隐藏", MENU_HIDE)
	context_menu.add_item("退出", MENU_QUIT)
	context_menu.always_on_top = true
	BbPetTheme.apply_popup(context_menu)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)

	_build_gathering()
	_solo_dress = _attach_dress(pixel_pet)
	RoomClient.home_updated.connect(_on_home_updated)
	RoomClient.emote_received.connect(_on_emote_received)
	RoomClient.disconnected.connect(_on_room_lost)
	RoomClient.connect_failed.connect(_on_connect_failed)
	WeatherClient.weather_changed.connect(_on_weather_changed)
	RoomClient.dress_updated.connect(_on_dress_updated)
	_refresh_dresses()

	_blink_loop()
	_drink_loop()
	_nap_loop()
	_slack_loop()
	_gathering_loop()
	_start_pet_sense()


func _gui_input(event: InputEvent) -> void:
	_handle_pointer(event, "")


func _handle_pointer(event: InputEvent, slot_id: String) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_dragging = false
				_press_position = DisplayServer.mouse_get_position()
				accept_event()
			else:
				if not _dragging:
					_on_left_click(slot_id)
				_dragging = false
				accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT and not button.pressed:
			_on_right_click(slot_id)
			accept_event()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var motion := event as InputEventMouseMotion
		if not _dragging:
			var mouse_position := DisplayServer.mouse_get_position()
			_dragging = Vector2(mouse_position - _press_position).length() > DRAG_THRESHOLD
		if _dragging:
			get_window().position += Vector2i(motion.relative.round())
			accept_event()


func _on_left_click(slot_id: String) -> void:
	if not _gathering:
		WindowHub.toggle_panel()
		return
	var closing := not _menu_for.is_empty()
	_menu_for = ""
	if closing:
		_invalidate()
	if slot_id.is_empty() or slot_id == RoomClient.my_id():
		WindowHub.toggle_panel()


func _on_right_click(slot_id: String) -> void:
	if _gathering and not slot_id.is_empty() and slot_id != RoomClient.my_id():
		_menu_for = "" if _menu_for == slot_id else slot_id
		_invalidate()
		return
	if _gathering and not _menu_for.is_empty():
		_menu_for = ""
		_invalidate()
	context_menu.position = DisplayServer.mouse_get_position()
	context_menu.popup()


func _set_pose(next_pose: String) -> void:
	pixel_pet.pose = next_pose
	pixel_pet.redraw()
	update_passthrough()


func _current_pose() -> String:
	return String(pixel_pet.pose)


func _autonomous() -> bool:
	return not _gathering and Time.get_ticks_msec() >= _pose_lock_until


func _lock_pose(pose: String, hold_ms: int = IdleLife.ACTION_HOLD_MS) -> void:
	_pose_lock_until = Time.get_ticks_msec() + hold_ms
	_set_pose(pose)


func _blink_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(2.5, 4.5)).timeout
		if not is_inside_tree():
			return
		if _gathering or not _autonomous():
			continue
		_set_pose("blink")
		await get_tree().create_timer(0.12).timeout
		if not is_inside_tree():
			return
		if _gathering or not _autonomous():
			continue
		if _current_pose() == "blink":
			_set_pose("idle")


func _drink_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(150.0, 300.0)).timeout
		if not is_inside_tree():
			return
		if not _autonomous():
			continue
		if IdleLife.has_juice(WeatherClient.last_dress) or _current_pose() == "idle" or _current_pose() == "blink":
			if _current_pose() == "idle" or _current_pose() == "blink":
				_set_pose("drink")
				await get_tree().create_timer(IdleLife.DRINK_MS / 1000.0).timeout
				if _current_pose() == "drink" and _autonomous():
					_set_pose("idle")


func _nap_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(55.0, 75.0)).timeout
		if not is_inside_tree():
			return
		if not _autonomous() or not IdleLife.can_nap(_current_pose()):
			continue
		_set_pose("sleep")
		await get_tree().create_timer((IdleLife.NAP_SLEEP_MIN_MS + randi() % IdleLife.NAP_SLEEP_SPAN_MS) / 1000.0).timeout
		if not is_inside_tree():
			return
		if _current_pose() != "sleep":
			continue
		_set_pose("wake")
		await get_tree().create_timer(IdleLife.WAKE_MS / 1000.0).timeout
		if _current_pose() == "wake" and _autonomous():
			_set_pose("idle")


func _slack_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(14.0, 30.0)).timeout
		if not is_inside_tree():
			return
		if not _autonomous() or not IdleLife.can_slack(_current_pose()):
			continue
		_set_pose(IdleLife.pick_slack(randi()))
		await get_tree().create_timer((IdleLife.SLACK_HOLD_MIN_MS + randi() % IdleLife.SLACK_HOLD_SPAN_MS) / 1000.0).timeout
		if IdleLife.is_slack(_current_pose()) and _autonomous():
			_set_pose("idle")


func _gathering_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(TICK_SECONDS).timeout
		if not is_inside_tree():
			return
		if _gathering:
			_refresh_gathering()


func _build_gathering() -> void:
	var root: Control = get_node_or_null("Gathering")
	if root == null:
		root = Control.new()
		root.name = "Gathering"
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(root)
	_gathering_root = root
	for child in _gathering_root.get_children():
		child.free()
	_slot_root = _add_layer("Slots")
	_build_log()
	_build_bar()
	_build_emote_menu()
	_gathering_root.visible = false


func _add_layer(layer_name: String) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gathering_root.add_child(layer)
	return layer


func _build_log() -> void:
	_log_root = _add_layer("Log")
	_log_root.clip_contents = true
	_log_root.add_child(_fill_rect(LOG_BG))
	_log_lines = VBoxContainer.new()
	_log_lines.name = "Lines"
	_log_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_log_lines.alignment = BoxContainer.ALIGNMENT_END
	_log_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_lines.add_theme_constant_override("separation", 1)
	_log_root.add_child(_log_lines)
	_log_root.visible = false


func _build_bar() -> void:
	_bar_root = _add_layer("Bar")
	_bar_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar_root.add_child(_fill_rect(BAR_BG))
	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 4)
	_bar_root.add_child(row)

	_bar_title = _bar_label("Title", TITLE_HOME)
	row.add_child(_bar_title)
	_bar_count = _bar_label("Count", "")
	row.add_child(_bar_count)

	_bar_input = LineEdit.new()
	_bar_input.name = "ChatInput"
	_bar_input.placeholder_text = CHAT_HINT
	_bar_input.tooltip_text = CHAT_HINT
	_bar_input.max_length = 80
	_bar_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_input.add_theme_font_size_override("font_size", 12)
	BbPetTheme.apply_input(_bar_input)
	_bar_input.text_submitted.connect(_on_chat_submitted)
	row.add_child(_bar_input)

	_bar_spacer = Control.new()
	_bar_spacer.name = "Spacer"
	_bar_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_bar_spacer)

	_bar_chat = Button.new()
	_bar_chat.name = "ChatOpen"
	_bar_chat.text = "聊"
	_bar_chat.add_theme_font_size_override("font_size", 12)
	BbPetTheme.apply_button(_bar_chat, "pill")
	_bar_chat.pressed.connect(_on_chat_open)
	row.add_child(_bar_chat)

	_bar_close = Button.new()
	_bar_close.name = "ChatClose"
	_bar_close.text = "收"
	_bar_close.add_theme_font_size_override("font_size", 12)
	BbPetTheme.apply_button(_bar_close, "ghost")
	_bar_close.pressed.connect(_on_chat_close)
	row.add_child(_bar_close)


func _bar_label(label_name: String, text: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", BAR_TEXT)
	label.add_theme_font_size_override("font_size", 12)
	return label


func _fill_rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "Background"
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _refresh_gathering() -> void:
	var you := RoomClient.you_dict()
	var my_id := RoomClient.my_id()
	var guests: Array = []
	if not you.is_empty():
		guests.append(you)
	for person in RoomClient.home_people:
		guests.append(person)
	var gather := HomeLogic.is_home_gathering(you, RoomClient.home_people, my_id)
	_gathering = gather
	pixel_pet.visible = not gather
	_gathering_root.visible = gather
	if not gather:
		_shrink_to_pet()
		return

	_track_chat_bubble()
	_expire_bubbles()
	var views := _guest_views(guests)
	var log_n := 0
	if _chatting:
		log_n = mini(RoomClient.home_board.size(), LOG_LIMIT)
	var yard: Dictionary = HomeLogic.yard_metrics(guests.size(), _chatting, log_n)
	var signature := _layout_key(views, yard)
	if signature == _layout_signature:
		return
	_layout_signature = signature

	_set_window_size(Vector2i(int(yard.width), int(yard.height)))
	_rebuild_slots(views)
	_refresh_bar(you, guests, my_id, yard)
	_refresh_log(yard)
	_refresh_emote_menu(views, yard)
	update_passthrough()


func _shrink_to_pet() -> void:
	_chatting = false
	_menu_for = ""
	_bubbles.clear()
	_layout_signature = ""
	_emote_menu.visible = false
	_clear_slots()
	_set_window_size(PET_SIZE)
	pixel_pet.position = PET_OFFSET
	update_passthrough()


func _set_window_size(new_size: Vector2i) -> void:
	var win := get_window()
	var prev_pos := win.position
	var prev_size := win.size
	win.size = new_size
	win.position = HomeLogic.anchor_window(
		prev_pos, prev_size, new_size, DisplayServer.screen_get_usable_rect()
	)


func _guest_views(guests: Array) -> Array:
	var emote := _active_emote()
	var views: Array = []
	for guest in guests:
		var id := String(guest.get("clientId", ""))
		var resting := String(RoomClient.home_poses.get(id, "idle"))
		var pose := HomeLogic.pose_for_action(emote, id, resting)
		var caption := HomeLogic.label_for_action(emote, id)
		var bubble: Dictionary = _bubbles.get(id, {})
		if caption.is_empty() and not bubble.is_empty():
			caption = String(bubble.text)
			pose = "talk"
		var species := String(guest.get("species", "blob"))
		if not PetTemplates.DEFAULT_COLORS.has(species):
			species = "blob"
		var colors: Variant = guest.get("colors", {})
		if not colors is Dictionary:
			colors = {}
		views.append({
			"id": id,
			"name": String(guest.get("name", "")),
			"species": species,
			"colors": PetTemplates.colors_for(species, colors),
			"pose": pose,
			"caption": caption,
		})
	return views


func _active_emote() -> Dictionary:
	var emote: Dictionary = RoomClient.last_emote
	if emote.is_empty() or _emote_at_ms <= 0:
		return {}
	var kind := String(emote.get("kind", ""))
	if not HomeLogic.HOME_ACTIONS.has(kind):
		return {}
	if Time.get_ticks_msec() - _emote_at_ms > int(HomeLogic.HOME_ACTIONS[kind].duration):
		return {}
	return emote


func _layout_key(views: Array, yard: Dictionary) -> String:
	var parts := PackedStringArray()
	for view in views:
		parts.append("%s/%s/%s/%s" % [view.id, view.name, view.pose, view.caption])
	parts.append("%d/%d/%s/%s/%s/%s/%d" % [
		int(yard.width),
		int(yard.height),
		str(_chatting),
		_menu_for,
		_airborne_id,
		str(_cooling()),
		RoomClient.home_board.size(),
	])
	return "\n".join(parts)


func _rebuild_slots(views: Array) -> void:
	var wanted := {}
	for view in views:
		wanted[view.id] = true
	for id in _slots.keys():
		if not wanted.has(id):
			_slots[id].queue_free()
			_slots.erase(id)
	for index in views.size():
		var view: Dictionary = views[index]
		var offset: Dictionary = HomeLogic.slot_offset(index, views.size())
		_configure_slot(view, Vector2(float(offset.x), float(offset.y)))


func _configure_slot(view: Dictionary, at: Vector2) -> void:
	var slot: Control = _slots.get(view.id)
	if slot == null:
		slot = _make_slot(String(view.id))
	slot.position = at
	slot.size = Vector2(HomeLogic.SLOT_W, HomeLogic.SLOT_H)
	var caption: Label = slot.get_node("Caption")
	caption.text = String(view.caption)
	caption.visible = not String(view.caption).is_empty()
	var pet: PixelPet = slot.get_node("Pet")
	pet.species = String(view.species)
	pet.colors = view.colors
	pet.pose = String(view.pose)
	pet.pixel_size = SLOT_PIXEL
	pet.visible = String(view.id) != _airborne_id
	pet.redraw()
	var overlay: Control = slot.get_node_or_null("WeatherDress")
	if overlay != null and overlay.has_method("apply"):
		overlay.call("apply", _dress_for(String(view.id)))
		overlay.visible = String(view.id) != _airborne_id
	var plate: Label = slot.get_node("Plate")
	plate.text = String(view.name)


func _make_slot(id: String) -> Control:
	var slot := Control.new()
	slot.name = "Slot_%s" % id
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.tooltip_text = "右键选动作"
	slot.gui_input.connect(_handle_pointer.bind(id))
	_slot_root.add_child(slot)
	_slots[id] = slot

	var caption := _slot_label("Caption", BAR_TEXT)
	caption.position = Vector2.ZERO
	caption.size = Vector2(HomeLogic.SLOT_W, CAPTION_H)
	slot.add_child(caption)

	var pet: PixelPet = PixelPetScene.instantiate()
	pet.name = "Pet"
	pet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pet.position = Vector2(SLOT_PET_LEFT, SLOT_PET_TOP)
	slot.add_child(pet)
	var overlay := _attach_dress(slot)
	overlay.position = Vector2(SLOT_PET_LEFT, SLOT_PET_TOP)

	var plate := _slot_label("Plate", LOG_TEXT)
	plate.position = Vector2(0.0, HomeLogic.SLOT_H - PLATE_H)
	plate.size = Vector2(HomeLogic.SLOT_W, PLATE_H)
	slot.add_child(plate)
	return slot


func _slot_label(label_name: String, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 11)
	var box := StyleBoxFlat.new()
	box.bg_color = BAR_BG
	label.add_theme_stylebox_override("normal", box)
	return label


func _clear_slots() -> void:
	for id in _slots.keys():
		_slots[id].queue_free()
	_slots.clear()


func _refresh_bar(you: Dictionary, guests: Array, my_id: String, yard: Dictionary) -> void:
	_bar_root.position = Vector2(float(yard.barLeft), float(yard.height) - HomeLogic.BAR_H)
	_bar_root.size = Vector2(float(yard.barW), float(HomeLogic.BAR_H))
	_bar_title.text = HomeLogic.gathering_title(you, guests, my_id)
	_bar_count.text = "%d人" % guests.size()
	_bar_title.visible = not _chatting
	_bar_count.visible = not _chatting
	_bar_spacer.visible = not _chatting
	_bar_chat.visible = not _chatting
	_bar_input.visible = _chatting
	_bar_close.visible = _chatting


func _refresh_log(yard: Dictionary) -> void:
	var log_h := int(yard.logH)
	_log_root.visible = _chatting and log_h > 0
	if not _log_root.visible:
		return
	_log_root.position = Vector2(
		float(yard.barLeft),
		float(yard.height) - float(HomeLogic.BAR_H) - float(log_h)
	)
	_log_root.size = Vector2(float(yard.barW), float(log_h))
	for child in _log_lines.get_children():
		child.queue_free()
	var lines: Array = RoomClient.home_board
	if lines.size() > LOG_LIMIT:
		lines = lines.slice(lines.size() - LOG_LIMIT)
	for line in lines:
		var row := Label.new()
		if bool(line.get("action", false)):
			row.text = String(line.get("text", ""))
		else:
			row.text = "%s：%s" % [String(line.get("name", "")), String(line.get("text", ""))]
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.clip_text = true
		row.add_theme_color_override("font_color", LOG_TEXT)
		row.add_theme_font_size_override("font_size", 11)
		_log_lines.add_child(row)


func _build_emote_menu() -> void:
	_emote_menu = _add_layer("EmoteMenu")
	_emote_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_emote_menu.size = Vector2(EMOTE_MENU_W, EMOTE_ROW_H * EMOTES.size())
	_emote_menu.add_child(_fill_rect(BAR_BG))
	var column := VBoxContainer.new()
	column.name = "Actions"
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 1)
	_emote_menu.add_child(column)
	_emote_buttons.clear()
	for entry in EMOTES:
		var button := Button.new()
		button.text = String(entry[1])
		button.custom_minimum_size = Vector2(EMOTE_MENU_W, EMOTE_ROW_H)
		button.add_theme_font_size_override("font_size", 11)
		BbPetTheme.apply_button(button, "pill")
		button.pressed.connect(_on_emote_pressed.bind(String(entry[0])))
		column.add_child(button)
		_emote_buttons.append(button)
	_emote_menu.visible = false


func _refresh_emote_menu(views: Array, yard: Dictionary) -> void:
	var index := -1
	for slot_index in views.size():
		if String(views[slot_index].id) == _menu_for:
			index = slot_index
			break
	if index < 0:
		_menu_for = ""
		_emote_menu.visible = false
		return
	for button in _emote_buttons:
		button.disabled = _cooling()
	var menu_size := _emote_menu.size
	var offset: Dictionary = HomeLogic.slot_offset(index, views.size())
	_emote_menu.position = Vector2(
		minf(float(offset.x) + HomeLogic.SLOT_W, float(yard.width) - menu_size.x - 2.0),
		clampf(float(offset.y), 2.0, float(yard.height) - menu_size.y - 2.0)
	)
	_emote_menu.visible = true


func _on_emote_pressed(kind: String) -> void:
	if _cooling() or _menu_for.is_empty():
		return
	RoomClient.send_emote(kind, _menu_for)
	_cool_until_ms = Time.get_ticks_msec() + HomeLogic.EMOTE_COOLDOWN_MS
	_menu_for = ""
	_invalidate()


func _cooling() -> bool:
	return Time.get_ticks_msec() < _cool_until_ms


func _on_chat_open() -> void:
	_chatting = true
	_menu_for = ""
	_invalidate()
	_bar_input.grab_focus()


func _on_chat_close() -> void:
	_chatting = false
	_bar_input.text = ""
	_bar_input.release_focus()
	_invalidate()


func _on_chat_submitted(text: String) -> void:
	RoomClient.send_home_chat(text)
	_bar_input.text = ""


func _track_chat_bubble() -> void:
	if RoomClient.home_board.is_empty():
		return
	var line: Dictionary = RoomClient.home_board.back()
	var line_id := String(line.get("id", ""))
	if line_id.is_empty() or line_id == _last_chat_id:
		return
	_last_chat_id = line_id
	if bool(line.get("action", false)):
		return
	_bubbles[String(line.get("clientId", ""))] = {
		"text": String(line.get("text", "")),
		"until": Time.get_ticks_msec() + BUBBLE_MS,
	}


func _expire_bubbles() -> void:
	var now := Time.get_ticks_msec()
	for id in _bubbles.keys():
		if int(_bubbles[id].until) <= now:
			_bubbles.erase(id)


func _invalidate() -> void:
	_layout_signature = ""
	_refresh_gathering()


func _on_home_updated() -> void:
	_invalidate()


func _on_emote_received(_emote: Dictionary) -> void:
	_emote_at_ms = Time.get_ticks_msec()
	_invalidate()
	if String(_emote.get("kind", "")) == "kick":
		_launch_kick_flyer(_emote)


func _on_room_lost() -> void:
	_gathering = false
	pixel_pet.visible = true
	_gathering_root.visible = false
	_shrink_to_pet()


func _on_connect_failed(_reason: String) -> void:
	_on_room_lost()


func _on_weather_changed(_info: Dictionary) -> void:
	_refresh_dresses()


func _on_dress_updated() -> void:
	_refresh_dresses()


func _refresh_dresses() -> void:
	if is_instance_valid(_solo_dress) and _solo_dress.has_method("apply"):
		_solo_dress.call("apply", WeatherClient.last_dress)
	for id in _slots:
		var overlay: Control = _slots[id].get_node_or_null("WeatherDress")
		if overlay != null and overlay.has_method("apply"):
			overlay.call("apply", _dress_for(String(id)))
	update_passthrough()


func _dress_for(client_id: String) -> Dictionary:
	if client_id.is_empty() or client_id == RoomClient.my_id():
		return WeatherClient.last_dress
	if RoomClient.dresses.has(client_id):
		var cached: Variant = RoomClient.dresses[client_id]
		if cached is Dictionary:
			return cached
	for person in RoomClient.home_people:
		if String(person.get("clientId", "")) != client_id:
			continue
		var from_person: Variant = person.get("dress", {})
		if from_person is Dictionary:
			return from_person
		break
	return {}


func _attach_dress(parent: Node) -> Control:
	var overlay: Control = parent.get_node_or_null("WeatherDress")
	if overlay != null:
		return overlay
	overlay = WeatherDress.new()
	overlay.name = "WeatherDress"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(overlay)
	return overlay


func _dress_points(overlay: Control, origin: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if overlay == null or not overlay.has_method("opaque_rects"):
		return points
	for rect in overlay.call("opaque_rects"):
		var at: Vector2 = origin + overlay.position + rect.position
		points.append(at)
		points.append(Vector2(at.x + rect.size.x, at.y))
		points.append(Vector2(at.x, at.y + rect.size.y))
		points.append(at + rect.size)
	return points


func update_passthrough() -> void:
	if _gathering:
		_apply_hull(_gathering_points())
		return
	var image: Image = pixel_pet.current_image()
	if image == null:
		get_window().mouse_passthrough = false
		return
	var points := _image_points(image, pixel_pet.position)
	points.append_array(_dress_points(_solo_dress, pixel_pet.position))
	_apply_hull(points)


func _gathering_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for id in _slots:
		var slot: Control = _slots[id]
		var pet: PixelPet = slot.get_node("Pet")
		var image: Image = pet.current_image()
		if image != null:
			points.append_array(_image_points(image, slot.position + pet.position))
		var overlay: Control = slot.get_node_or_null("WeatherDress")
		if overlay != null:
			points.append_array(_dress_points(overlay, slot.position))
	for rect in _ui_rects():
		points.append(rect.position)
		points.append(Vector2(rect.end.x, rect.position.y))
		points.append(Vector2(rect.position.x, rect.end.y))
		points.append(rect.end)
	return points


func _ui_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if is_instance_valid(_bar_root) and _bar_root.visible:
		rects.append(Rect2(_bar_root.position, _bar_root.size))
	if is_instance_valid(_log_root) and _log_root.visible:
		rects.append(Rect2(_log_root.position, _log_root.size))
	if is_instance_valid(_emote_menu) and _emote_menu.visible:
		rects.append(Rect2(_emote_menu.position, _emote_menu.size))
	return rects


func _image_points(image: Image, at: Vector2) -> Array[Vector2]:
	var unique_points := {}
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.5:
				continue
			for corner in [
				Vector2i(x, y),
				Vector2i(x + 1, y),
				Vector2i(x, y + 1),
				Vector2i(x + 1, y + 1),
			]:
				unique_points[corner] = true

	var points: Array[Vector2] = []
	for point: Vector2i in unique_points:
		points.append(Vector2(point) + at)
	return points


func _apply_hull(points: Array[Vector2]) -> void:
	var hull := _convex_hull(points)
	# On Windows, Window.mouse_passthrough=true makes the whole window
	# click-through, including the polygon. Use the region API instead.
	get_window().mouse_passthrough = false
	if hull.size() < 3:
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
		return
	DisplayServer.window_set_mouse_passthrough(hull)


func _convex_hull(points: Array[Vector2]) -> PackedVector2Array:
	if points.size() < 3:
		return PackedVector2Array(points)
	points.sort_custom(
		func(a: Vector2, b: Vector2) -> bool:
			return a.x < b.x or (a.x == b.x and a.y < b.y)
	)

	var lower: Array[Vector2] = []
	for point in points:
		while lower.size() >= 2 and _cross(lower[-2], lower[-1], point) <= 0.0:
			lower.pop_back()
		lower.append(point)

	var upper: Array[Vector2] = []
	for index in range(points.size() - 1, -1, -1):
		var point := points[index]
		while upper.size() >= 2 and _cross(upper[-2], upper[-1], point) <= 0.0:
			upper.pop_back()
		upper.append(point)

	lower.pop_back()
	upper.pop_back()
	lower.append_array(upper)
	return PackedVector2Array(lower)


func _cross(origin: Vector2, a: Vector2, b: Vector2) -> float:
	return (a - origin).cross(b - origin)


func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		MENU_IDLE:
			_lock_pose("idle")
		MENU_TALK:
			_lock_pose("talk")
		MENU_DRINK:
			_lock_pose("drink")
		MENU_SLEEP:
			_lock_pose("sleep")
		MENU_PHONE:
			_lock_pose("phone")
		MENU_WX_SUN:
			WeatherClient.apply_weather(IdleLife.demo_weather("sun"), false)
		MENU_WX_RAIN:
			WeatherClient.apply_weather(IdleLife.demo_weather("rain"), false)
		MENU_HIDE:
			WindowHub.hide_pet()
		MENU_QUIT:
			WindowHub.quit_app()


func _launch_kick_flyer(emote: Dictionary) -> void:
	var target_id := String(emote.get("targetId", ""))
	if target_id.is_empty():
		return
	_airborne_id = target_id
	_invalidate()
	var guests: Array = []
	var you := RoomClient.you_dict()
	if not you.is_empty():
		guests.append(you)
	for person in RoomClient.home_people:
		guests.append(person)
	var from_index := -1
	var to_index := -1
	var target: Dictionary = {}
	for index in guests.size():
		var id := String(guests[index].get("clientId", ""))
		if id == String(emote.get("fromId", "")):
			from_index = index
		if id == target_id:
			to_index = index
			target = guests[index]
	var slot: Control = _slots.get(target_id)
	var slot_pos := slot.position if slot != null else Vector2.ZERO
	var win := get_window()
	var seat := HomeLogic.flyer_seat(win.position.x, win.position.y, slot_pos.x, slot_pos.y)
	var dir := HomeLogic.flyer_dir(String(emote.get("id", "")), from_index, to_index)
	var path: Dictionary = HomeLogic.flyer_path(
		seat.x, seat.y, dir, Rect2(DisplayServer.screen_get_usable_rect())
	)
	var species := String(target.get("species", "blob"))
	var colors: Variant = target.get("colors", {})
	if not colors is Dictionary:
		colors = {}
	WindowHub.play_flyer({
		"id": target_id,
		"species": species,
		"colors": PetTemplates.colors_for(species, colors),
		"pose": "peek",
		"start": path.start,
		"dest": path.dest,
		"duration": HomeLogic.HOME_ACTIONS.kick.duration,
	})


func on_flyer_finished() -> void:
	_airborne_id = ""
	_invalidate()


func _start_pet_sense() -> void:
	if DisplayServer.get_name() == "headless":
		_sense_skip = true
		return
	var timer := Timer.new()
	timer.wait_time = 0.09
	timer.timeout.connect(_tick_pet_sense)
	add_child(timer)
	timer.start()
	if OS.get_name() != "Windows":
		return
	var godot_dir := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var script := godot_dir.get_base_dir().path_join("electron/watch-keys.ps1")
	if not FileAccess.file_exists(script):
		return
	var out_path := ProjectSettings.globalize_path("user://bbpet-keys.txt")
	var command := "& { & '%s' | ForEach-Object { Set-Content -LiteralPath '%s' -Value $_ } }" % [script.replace("'", "''"), out_path.replace("'", "''")]
	_key_pid = OS.create_process(
		"powershell.exe",
		PackedStringArray(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", command])
	)


func _tick_pet_sense() -> void:
	if _sense_skip or _gathering:
		return
	var win := get_window()
	if win == null or not win.visible:
		return
	var mouse := DisplayServer.mouse_get_position()
	var center := win.position + Vector2i(win.size.x / 2, int(round(win.size.y * 0.32)))
	var dx := mouse.x - center.x
	var dy := mouse.y - center.y
	var pose := _current_pose()
	var pose_blocks_look := pose == "sleep" or pose == "peek"
	var look_x := 0 if pose_blocks_look else (-1 if dx < -42 else (1 if dx > 42 else 0))
	var look_y := 0 if pose_blocks_look else (-1 if dy < -28 else (1 if dy > 36 else 0))
	pixel_pet.look_x = look_x
	pixel_pet.look_y = look_y
	pixel_pet.flip = look_x < 0
	pixel_pet.flip_h = pixel_pet.flip
	var key_path := "user://bbpet-keys.txt"
	if FileAccess.file_exists(key_path):
		var token := FileAccess.get_file_as_string(key_path).strip_edges()
		if token.contains("T1"):
			_typing_until = Time.get_ticks_msec() + 400
	var typing := Time.get_ticks_msec() < _typing_until
	if typing and _autonomous() and (_current_pose() == "idle" or _current_pose() == "blink"):
		_set_pose("type")
	elif not typing and _current_pose() == "type" and _autonomous():
		_set_pose("idle")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _key_pid > 0:
		OS.kill(_key_pid)
		_key_pid = -1
