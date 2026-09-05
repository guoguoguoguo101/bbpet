extends Window

const PANEL_SIZES := {
	"wizard": Vector2i(340, 520),
	"hub": Vector2i(300, 430),
	"settings": Vector2i(340, 640),
	"friends": Vector2i(300, 480),
}
const STATE_PATH := "user://bbpet-state.json"
const PixelPetScene = preload("res://pet/pixel_pet.tscn")
const PET_TEMPLATES = preload("res://pet/templates.gd")
const SchoolSocial = preload("res://school/school_social.gd")

@onready var content: VBoxContainer = $Margin/Content

var _selected_species := "blob"


func _ready() -> void:
	close_requested.connect(Callable(_window_hub(), "close_panel"))


func show_kind(kind: String) -> void:
	if not PANEL_SIZES.has(kind):
		push_error("Unknown panel kind: %s" % kind)
		return
	if content == null:
		content = get_node("Margin/Content")
	size = PANEL_SIZES[kind]
	_clear_content()
	match kind:
		"wizard":
			_build_wizard()
		"hub":
			_build_hub()
		"settings":
			_build_settings()
		"friends":
			_build_friends()


func _clear_content() -> void:
	for child in content.get_children():
		child.free()


func _build_wizard() -> void:
	title = "欢迎"
	_selected_species = _state().pet.species
	_add_heading("选择你的宠物")
	var species_grid := GridContainer.new()
	species_grid.name = "Species"
	species_grid.columns = 2
	species_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(species_grid)
	for species: String in PET_TEMPLATES.SPECIES:
		var button := Button.new()
		button.text = PET_TEMPLATES.SPECIES_LABELS[species]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_species.bind(species))
		species_grid.add_child(button)
	var name_input := LineEdit.new()
	name_input.name = "Name"
	name_input.placeholder_text = "名字"
	name_input.text = _state().pet.name
	content.add_child(name_input)
	var error_label := _add_error_label()
	var confirm := Button.new()
	confirm.name = "Confirm"
	confirm.text = "确定"
	confirm.pressed.connect(_confirm_wizard.bind(name_input, error_label))
	content.add_child(confirm)


func _build_hub() -> void:
	title = "宠物中心"
	var preview: TextureRect = PixelPetScene.instantiate()
	preview.name = "Preview"
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.species = _state().pet.species
	preview.colors = _state().pet.colors.duplicate(true)
	preview.pixel_size = 6
	content.add_child(preview)
	preview.redraw()
	var school := Button.new()
	school.name = "School"
	school.text = "去上学"
	school.pressed.connect(_go_to_school)
	content.add_child(school)
	var friends := Button.new()
	friends.name = "Friends"
	friends.text = "好友"
	friends.pressed.connect(_open_friends)
	content.add_child(friends)
	var settings := Button.new()
	settings.name = "Settings"
	settings.text = "设置"
	settings.pressed.connect(_open_settings)
	content.add_child(settings)


func _build_friends() -> void:
	title = "好友"
	var status := Label.new()
	status.name = "RoomStatus"
	status.modulate = Color("#b3261e")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status)
	var notice := Label.new()
	notice.name = "Notice"
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(notice)
	var empty := Label.new()
	empty.name = "Empty"
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.text = "去学校点别的同学，点「加好友」就会出现在这里。"
	content.add_child(empty)
	var list := VBoxContainer.new()
	list.name = "List"
	content.add_child(list)
	_refresh_friends()
	var room := _room_client_or_null()
	if room:
		if not room.friends_changed.is_connected(_on_friends_changed):
			room.friends_changed.connect(_on_friends_changed)
		if not room.status.is_connected(_on_friends_status):
			room.status.connect(_on_friends_status)
		if not room.connect_failed.is_connected(_on_friends_status):
			room.connect_failed.connect(_on_friends_status)
		if not room.disconnected.is_connected(_on_friends_disconnected):
			room.disconnected.connect(_on_friends_disconnected)


func _on_friends_changed(_friends: Array) -> void:
	_refresh_friends()


func _on_friends_status(_text: String) -> void:
	_refresh_friends()


func _on_friends_disconnected() -> void:
	_refresh_friends()


func _refresh_friends() -> void:
	var status: Label = content.get_node_or_null("RoomStatus")
	var notice: Label = content.get_node_or_null("Notice")
	var empty: Label = content.get_node_or_null("Empty")
	var list: VBoxContainer = content.get_node_or_null("List")
	if status == null or empty == null or list == null or notice == null:
		return
	for child in list.get_children():
		child.free()
	var room := _room_client_or_null()
	var cards: Array = room.friends if room else []
	var connected: bool = room.connected if room else false
	var connecting: bool = room.connecting if room else false
	status.text = ""
	if room:
		if not connected and connecting:
			status.text = "正在连学校..."
		elif not connected and not room.status_text.is_empty():
			status.text = room.status_text
		elif not connected:
			status.text = "连不上学校"
	notice.text = room.last_notice if room else ""
	empty.visible = cards.is_empty()
	if cards.is_empty():
		empty.text = "去学校点别的同学，点「加好友」就会出现在这里。"
		return
	for card in cards:
		if not card is Dictionary:
			continue
		var row := HBoxContainer.new()
		var preview: TextureRect = PixelPetScene.instantiate()
		preview.species = String(card.get("species", "blob"))
		preview.colors = PET_TEMPLATES.colors_for(preview.species, card.get("colors", {}))
		preview.pixel_size = 2
		preview.pose = "idle"
		row.add_child(preview)
		preview.redraw()
		var meta := VBoxContainer.new()
		var name_label := Label.new()
		name_label.text = String(card.get("name", ""))
		meta.add_child(name_label)
		var state_label := Label.new()
		state_label.text = SchoolSocial.friend_status_text(card)
		meta.add_child(state_label)
		row.add_child(meta)
		list.add_child(row)


func _build_settings() -> void:
	title = "设置"
	_add_heading("宠物名字")
	var name_input := LineEdit.new()
	name_input.name = "Name"
	name_input.text = _state().pet.name
	name_input.placeholder_text = "名字"
	content.add_child(name_input)
	_add_heading("宠物种类")
	var species_input := OptionButton.new()
	species_input.name = "Species"
	for species: String in PET_TEMPLATES.SPECIES:
		var index := species_input.item_count
		species_input.add_item(PET_TEMPLATES.SPECIES_LABELS[species])
		species_input.set_item_metadata(index, species)
		if species == _state().pet.species:
			species_input.select(index)
	content.add_child(species_input)
	_add_heading("学校地址")
	var room_input := LineEdit.new()
	room_input.name = "RoomUrl"
	room_input.text = _state().settings.roomUrl
	content.add_child(room_input)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var error_label := _add_error_label()
	var save := Button.new()
	save.name = "Save"
	save.text = "保存"
	save.pressed.connect(_save_settings.bind(name_input, species_input, room_input, error_label))
	content.add_child(save)


func _add_heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	content.add_child(label)


func _add_error_label() -> Label:
	var label := Label.new()
	label.name = "Error"
	label.modulate = Color("#b3261e")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label


func _select_species(species: String) -> void:
	_selected_species = species


func _go_to_school() -> void:
	_window_hub().go_to_school()


func _open_friends() -> void:
	_window_hub().open_friends()


func _open_settings() -> void:
	_window_hub().open_panel("settings")


func _confirm_wizard(name_input: LineEdit, error_label: Label) -> void:
	_app_state().set_species(_selected_species)
	if not _app_state().set_pet_name(name_input.text):
		error_label.text = "请给宠物起个名字"
		return
	_app_state().mark_onboarded()
	_app_state().save_to(STATE_PATH)
	_window_hub().refresh_pet()
	_window_hub().close_panel()


func _save_settings(
	name_input: LineEdit,
	species_input: OptionButton,
	room_input: LineEdit,
	error_label: Label
) -> void:
	if not _app_state().set_pet_name(name_input.text):
		error_label.text = "请给宠物起个名字"
		return
	var species: String = species_input.get_item_metadata(species_input.selected)
	_app_state().set_species(species)
	var room_error: String = _app_state().set_room_url(room_input.text)
	if not room_error.is_empty():
		error_label.text = room_error
		return
	_app_state().save_to(STATE_PATH)
	_window_hub().refresh_pet()
	var room_client := _room_client()
	if room_client.connected:
		_window_hub().discard_world()
		room_client.disconnect_room()
	_window_hub().close_panel()


func _app_state() -> Node:
	return get_node("/root/AppState")


func _state() -> Dictionary:
	if is_inside_tree():
		return _app_state().state
	return {
		"pet": {
			"name": "",
			"species": "blob",
			"colors": PET_TEMPLATES.DEFAULT_COLORS["blob"].duplicate(true),
		},
		"settings": {"roomUrl": ""},
	}


func _room_client() -> Node:
	return get_node("/root/RoomClient")


func _room_client_or_null() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/RoomClient")


func _window_hub() -> Node:
	return get_node("/root/WindowHub")
