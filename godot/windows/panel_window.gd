extends Window

const PANEL_SIZES := {
	"wizard": Vector2i(340, 560),
	"hub": Vector2i(300, 620),
	"settings": Vector2i(340, 860),
	"friends": Vector2i(300, 560),
	"chat": Vector2i(340, 520),
}
const STATE_PATH := "user://bbpet-state.json"
const PixelPetScene = preload("res://pet/pixel_pet.tscn")
const PET_TEMPLATES = preload("res://pet/templates.gd")
const SchoolSocial = preload("res://school/school_social.gd")
const HomeLogic = preload("res://home/home_logic.gd")
const WeatherCities = preload("res://weather/cities.gd")
const PetColors = preload("res://pet/colors.gd")
const ChatClient = preload("res://llm/chat_client.gd")
const GameView = preload("res://game/game_view.gd")
const BbPetTheme = preload("res://ui/bbpet_theme.gd")

@onready var content: VBoxContainer = $Margin/Content

var _selected_species := "blob"
var _chat_history: Array = []
var _chat_busy := false
var _http: HTTPRequest
var _pending_models: Array = []
var _pending_messages: Array = []


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
		"chat":
			_build_chat()


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
		BbPetTheme.apply_button(button, "pill")
		species_grid.add_child(button)
	var name_input := LineEdit.new()
	name_input.name = "Name"
	name_input.placeholder_text = "名字"
	name_input.text = _state().pet.name
	BbPetTheme.apply_input(name_input)
	content.add_child(name_input)
	var city_input := _add_city_input()
	var photo := Button.new()
	photo.name = "Photo"
	photo.text = "选一张照片取色"
	photo.pressed.connect(_pick_photo)
	BbPetTheme.apply_button(photo, "pill")
	content.add_child(photo)
	_add_photo_preview()
	var error_label := _add_error_label()
	var confirm := Button.new()
	confirm.name = "Confirm"
	confirm.text = "确定"
	confirm.pressed.connect(_confirm_wizard.bind(name_input, city_input, error_label))
	BbPetTheme.apply_button(confirm, "main")
	content.add_child(confirm)


func _build_hub() -> void:
	title = "今天去哪"
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 8)
	content.add_child(head)
	var heading := Label.new()
	heading.text = "今天去哪"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BbPetTheme.apply_heading(heading)
	heading.add_theme_font_size_override("font_size", 16)
	head.add_child(heading)
	var fold := Button.new()
	fold.name = "Close"
	fold.text = "收起"
	fold.pressed.connect(func(): _window_hub().close_panel())
	BbPetTheme.apply_button(fold, "ghost")
	head.add_child(fold)
	var hero := HBoxContainer.new()
	hero.name = "Hero"
	hero.add_theme_constant_override("separation", 10)
	content.add_child(hero)
	var preview: TextureRect = PixelPetScene.instantiate()
	preview.name = "Preview"
	preview.species = _state().pet.species
	preview.colors = _state().pet.colors.duplicate(true)
	preview.pixel_size = 4
	hero.add_child(preview)
	preview.redraw()
	var meta := VBoxContainer.new()
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(meta)
	var name_label := Label.new()
	name_label.text = String(_state().pet.name)
	name_label.add_theme_color_override("font_color", BbPetTheme.INK)
	name_label.add_theme_font_size_override("font_size", 16)
	meta.add_child(name_label)
	var hint := Label.new()
	hint.text = "去学校不会离开家。客厅聊天一直在桌面上。"
	BbPetTheme.apply_hint(hint)
	meta.add_child(hint)
	_add_hub_action("Chat", "和宠物聊", "还是原来的悄悄话", false, _open_chat)
	_add_hub_action("School", _school_button_text(), _school_button_hint(), true, _go_to_school)
	_add_hub_action("Home", "回家", "客厅一直在桌面。若在朋友家，点这里回来。", false, _go_home)
	_add_hub_action("Friends", _friends_button_text(), "在家的好友才能进；不在家去不了", false, _open_friends)
	var foot := HBoxContainer.new()
	foot.name = "Foot"
	foot.add_theme_constant_override("separation", 8)
	content.add_child(foot)
	var room_url := Label.new()
	room_url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_url.text = "学校地址 %s" % str(_state().settings.get("roomUrl", ""))
	BbPetTheme.apply_hint(room_url)
	foot.add_child(room_url)
	var settings := Button.new()
	settings.name = "Settings"
	settings.text = "设置"
	settings.pressed.connect(_open_settings)
	BbPetTheme.apply_button(settings, "ghost")
	foot.add_child(settings)
	var room := _room_client_or_null()
	if room and not room.friends_changed.is_connected(_on_hub_friends):
		room.friends_changed.connect(_on_hub_friends)


func _add_hub_action(node_name: String, main_text: String, hint: String, main: bool, handler: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = main_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = false
	button.custom_minimum_size = Vector2(0, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(handler)
	var kind := "main" if main else "hub"
	var normal := BbPetTheme.button_style(kind)
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 22.0
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", BbPetTheme.button_style("main" if kind == "hub" else kind))
	button.add_theme_stylebox_override("pressed", BbPetTheme.button_style("main"))
	button.add_theme_stylebox_override("disabled", BbPetTheme.button_style("ghost"))
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_color_override("font_color", BbPetTheme.INK)
	button.add_theme_color_override("font_hover_color", BbPetTheme.INK)
	button.add_theme_color_override("font_pressed_color", BbPetTheme.INK)
	button.add_theme_color_override("font_disabled_color", BbPetTheme.HINT)
	button.add_theme_color_override("font_focus_color", BbPetTheme.INK)
	var sub := Label.new()
	sub.name = "Hint"
	sub.text = hint
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	BbPetTheme.apply_hint(sub)
	sub.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sub.offset_left = 12
	sub.offset_right = -8
	sub.offset_top = -22
	sub.offset_bottom = -6
	button.add_child(sub)
	content.add_child(button)


func _school_button_text() -> String:
	var room := _room_client_or_null()
	if room and room.connected and SchoolSocial.should_open_world(String(room.place_id)):
		return "回到学校"
	return "去上学"


func _school_button_hint() -> String:
	if _school_button_text() == "回到学校":
		return "人还在学校里，收起只是藏窗口"
	return "WASD 走动，教室黑板；家里客厅同时还在"


func _build_friends() -> void:
	title = "好友"
	var status := Label.new()
	status.name = "RoomStatus"
	status.add_theme_color_override("font_color", BbPetTheme.ERROR_ALT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status)
	var notice := Label.new()
	notice.name = "Notice"
	BbPetTheme.apply_hint(notice)
	content.add_child(notice)
	var invite := HBoxContainer.new()
	invite.name = "Invite"
	content.add_child(invite)
	var incoming_head := Label.new()
	incoming_head.name = "IncomingHead"
	incoming_head.text = "好友申请"
	BbPetTheme.apply_heading(incoming_head)
	content.add_child(incoming_head)
	var incoming_list := VBoxContainer.new()
	incoming_list.name = "Incoming"
	content.add_child(incoming_list)
	var empty := Label.new()
	empty.name = "Empty"
	empty.text = "去学校点别的同学，点「加好友」就会出现在这里。"
	BbPetTheme.apply_hint(empty)
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
		if not room.game_updated.is_connected(_on_friends_game):
			room.game_updated.connect(_on_friends_game)
	var tick := Timer.new()
	tick.wait_time = 0.2
	tick.timeout.connect(_refresh_friends)
	content.add_child(tick)
	if is_inside_tree():
		tick.start()


func _on_friends_changed(_friends: Array) -> void:
	_refresh_friends()


func _on_friends_status(_text: String) -> void:
	_refresh_friends()


func _on_friends_disconnected() -> void:
	_refresh_friends()


func _on_friends_game(_game: Dictionary) -> void:
	_refresh_friends()


func _refresh_friends() -> void:
	var status: Label = content.get_node_or_null("RoomStatus")
	var notice: Label = content.get_node_or_null("Notice")
	var empty: Label = content.get_node_or_null("Empty")
	var list: VBoxContainer = content.get_node_or_null("List")
	var incoming_list: VBoxContainer = content.get_node_or_null("Incoming")
	var invite: HBoxContainer = content.get_node_or_null("Invite")
	if status == null or empty == null or list == null or notice == null or incoming_list == null or invite == null:
		return
	for child in list.get_children():
		child.free()
	for child in incoming_list.get_children():
		child.free()
	for child in invite.get_children():
		child.free()
	var room := _room_client_or_null()
	var cards: Array = room.friends if room else []
	var requests: Array = room.incoming if room else []
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
	for card in requests:
		if not card is Dictionary:
			continue
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = String(card.get("name", card.get("clientId", "")))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var accept := Button.new()
		accept.text = "同意"
		BbPetTheme.apply_button(accept, "main")
		var target_id := String(card.get("clientId", ""))
		if room:
			accept.pressed.connect(func(): room.accept_friend(target_id))
		row.add_child(accept)
		var decline := Button.new()
		decline.text = "拒绝"
		BbPetTheme.apply_button(decline, "ghost")
		if room:
			decline.pressed.connect(func(): room.decline_friend(target_id))
		row.add_child(decline)
		incoming_list.add_child(row)
	var game: Dictionary = room.game if room else {}
	if GameView.is_incoming_invite(game):
		invite.visible = true
		var black: Dictionary = game.get("black", {}) if game.get("black") is Dictionary else {}
		var now_ms := int(Time.get_unix_time_from_system() * 1000.0)
		var seconds: int = GameView.seconds_left(int(game.get("deadlineAt", 0)), now_ms)
		var invite_label := Label.new()
		invite_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		invite_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		invite_label.text = "%s 邀请你下五子棋 %d秒" % [String(black.get("name", "")), seconds]
		invite.add_child(invite_label)
		var accept_game := Button.new()
		accept_game.text = "接受"
		BbPetTheme.apply_button(accept_game, "main")
		var game_id := String(game.get("id", ""))
		if room:
			accept_game.pressed.connect(func(): room.game_respond(game_id, true))
		invite.add_child(accept_game)
		var decline_game := Button.new()
		decline_game.text = "拒绝"
		BbPetTheme.apply_button(decline_game, "ghost")
		if room:
			decline_game.pressed.connect(func(): room.game_respond(game_id, false))
		invite.add_child(decline_game)
	else:
		invite.visible = false
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
		var my_id := ""
		if is_inside_tree() and get_node_or_null("/root/AppState") != null:
			my_id = String(_app_state().state.clientId)
		if room and GameView.can_invite_friend(game, my_id, card):
			var play := Button.new()
			play.text = "五子棋"
			BbPetTheme.apply_button(play, "pill")
			var target := String(card.get("clientId", ""))
			play.pressed.connect(func(): room.invite_game(target))
			row.add_child(play)
		var visit := Button.new()
		var at_home := HomeLogic.is_friend_at_home(card)
		visit.text = "进他家" if at_home else "不在家"
		visit.disabled = not at_home
		BbPetTheme.apply_button(visit, "pill" if at_home else "ghost")
		visit.pressed.connect(_go_home.bind(String(card.get("clientId", ""))))
		row.add_child(visit)
		list.add_child(row)


func _build_settings() -> void:
	title = "设置"
	_add_heading("宠物名字")
	var name_input := LineEdit.new()
	name_input.name = "Name"
	name_input.text = _state().pet.name
	name_input.placeholder_text = "名字"
	BbPetTheme.apply_input(name_input)
	content.add_child(name_input)
	_add_heading("宠物种类")
	var species_input := OptionButton.new()
	species_input.name = "Species"
	BbPetTheme.apply_input(species_input)
	for species: String in PET_TEMPLATES.SPECIES:
		var index := species_input.item_count
		species_input.add_item(PET_TEMPLATES.SPECIES_LABELS[species])
		species_input.set_item_metadata(index, species)
		if species == _state().pet.species:
			species_input.select(index)
	content.add_child(species_input)
	_add_heading("城市")
	var city_input := _add_city_input()
	_add_heading("冒泡间隔（分钟）")
	var push_input := LineEdit.new()
	push_input.name = "PushMin"
	push_input.text = str(_state().settings.pushIntervalMin)
	BbPetTheme.apply_input(push_input)
	content.add_child(push_input)
	_add_heading("学校地址")
	var room_input := LineEdit.new()
	room_input.name = "RoomUrl"
	room_input.text = _state().settings.roomUrl
	BbPetTheme.apply_input(room_input)
	content.add_child(room_input)
	var host_room := CheckBox.new()
	host_room.name = "HostRoom"
	host_room.text = "我来当校长（本机开房，同事填下面的内网地址）"
	host_room.button_pressed = bool(_state().settings.get("hostRoom", false))
	host_room.add_theme_color_override("font_color", BbPetTheme.INK)
	host_room.add_theme_color_override("font_hover_color", BbPetTheme.INK)
	host_room.add_theme_color_override("font_pressed_color", BbPetTheme.INK)
	content.add_child(host_room)
	var photo := Button.new()
	photo.name = "Photo"
	photo.text = "选一张照片取色"
	photo.pressed.connect(_pick_photo)
	BbPetTheme.apply_button(photo, "pill")
	content.add_child(photo)
	_add_photo_preview()
	_add_heading("API Base URL")
	var base_input := LineEdit.new()
	base_input.name = "ApiBase"
	base_input.text = str(_state().settings.get("apiBaseUrl", "https://openrouter.ai/api/v1"))
	BbPetTheme.apply_input(base_input)
	content.add_child(base_input)
	_add_heading("API Key")
	var key_input := LineEdit.new()
	key_input.name = "ApiKey"
	key_input.secret = true
	key_input.text = str(_state().settings.get("apiKey", ""))
	BbPetTheme.apply_input(key_input)
	content.add_child(key_input)
	_add_heading("模型")
	var model_input := LineEdit.new()
	model_input.name = "Model"
	model_input.text = str(_state().settings.get("model", "minimax/minimax-m3:free"))
	BbPetTheme.apply_input(model_input)
	content.add_child(model_input)
	_add_heading("回退模型")
	var fallback_input := LineEdit.new()
	fallback_input.name = "Fallback"
	fallback_input.text = str(_state().settings.get("fallbackModel", "minimax/minimax-m2.7:free"))
	BbPetTheme.apply_input(fallback_input)
	content.add_child(fallback_input)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var error_label := _add_error_label()
	var save := Button.new()
	save.name = "Save"
	save.text = "保存"
	BbPetTheme.apply_button(save, "main")
	save.pressed.connect(
		_save_settings.bind(
			name_input,
			species_input,
			city_input,
			push_input,
			room_input,
			host_room,
			base_input,
			key_input,
			model_input,
			fallback_input,
			error_label
		)
	)
	content.add_child(save)


func _add_heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	BbPetTheme.apply_heading(label)
	content.add_child(label)


func _add_photo_preview() -> void:
	var preview := TextureRect.new()
	preview.name = "PhotoPreview"
	preview.custom_minimum_size = Vector2(72, 72)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var url := String(_state().pet.get("photoDataUrl", ""))
	var tex := _texture_from_data_url(url)
	if tex:
		preview.texture = tex
		preview.visible = true
	else:
		preview.visible = false
	content.add_child(preview)


func _texture_from_data_url(url: String) -> ImageTexture:
	var marker := "base64,"
	var idx := url.find(marker)
	if idx < 0:
		return null
	var raw := Marshalls.base64_to_raw(url.substr(idx + marker.length()))
	var image := Image.new()
	if image.load_png_from_buffer(raw) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _image_to_data_url(image: Image) -> String:
	var bytes := image.save_png_to_buffer()
	return "data:image/png;base64," + Marshalls.raw_to_base64(bytes)


func _add_city_input() -> OptionButton:
	var city_input := OptionButton.new()
	city_input.name = "City"
	BbPetTheme.apply_input(city_input)
	for city: Dictionary in WeatherCities.CITIES:
		var index := city_input.item_count
		city_input.add_item(city.name)
		city_input.set_item_metadata(index, city.id)
		if city.id == _state().settings.cityId:
			city_input.select(index)
	content.add_child(city_input)
	return city_input


func _add_error_label() -> Label:
	var label := Label.new()
	label.name = "Error"
	label.add_theme_color_override("font_color", BbPetTheme.ERROR_ALT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label


func _select_species(species: String) -> void:
	_selected_species = species


func _go_to_school() -> void:
	_window_hub().go_to_school()


func _go_home(owner_id: String = "") -> void:
	_window_hub().go_home(owner_id)


func _open_friends() -> void:
	_window_hub().open_friends()


func _open_settings() -> void:
	_window_hub().open_panel("settings")


func _open_chat() -> void:
	_window_hub().open_panel("chat")


func _friends_button_text() -> String:
	var room := _room_client_or_null()
	var n: int = room.incoming.size() if room else 0
	return "好友（%d）" % n if n > 0 else "好友"


func _on_hub_friends(_friends: Array) -> void:
	var friends_btn: Button = content.get_node_or_null("Friends")
	if friends_btn:
		friends_btn.text = _friends_button_text()
	var school_btn: Button = content.get_node_or_null("School")
	if school_btn:
		school_btn.text = _school_button_text()
		var school_hint: Label = school_btn.get_node_or_null("Hint")
		if school_hint:
			school_hint.text = _school_button_hint()


func _pick_photo() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp;图片"])
	dialog.always_on_top = true
	add_child(dialog)
	dialog.file_selected.connect(_on_photo_selected.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(640, 420))


func _on_photo_selected(path: String, dialog: FileDialog) -> void:
	dialog.queue_free()
	var image := Image.new()
	if image.load(path) != OK:
		return
	_app_state().set_pet_colors(PetColors.extract_palette(image, _state().pet.species))
	_app_state().set_photo_data_url(_image_to_data_url(image))
	_app_state().save_to(STATE_PATH)
	_window_hub().refresh_pet()
	var preview: TextureRect = content.get_node_or_null("PhotoPreview")
	if preview:
		preview.texture = _texture_from_data_url(String(_state().pet.get("photoDataUrl", "")))
		preview.visible = preview.texture != null


func _build_chat() -> void:
	title = "和 %s 聊天" % _state().pet.name
	var saved: Variant = _state().get("chatHistory", [])
	_chat_history = saved.duplicate(true) if saved is Array else []
	var log := VBoxContainer.new()
	log.name = "Log"
	log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(log)
	_refresh_chat_log()
	var row := HBoxContainer.new()
	row.name = "Composer"
	var draft := LineEdit.new()
	draft.name = "Draft"
	draft.placeholder_text = "跟桌宠说点什么"
	draft.max_length = 200
	draft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BbPetTheme.apply_input(draft)
	draft.text_submitted.connect(func(text): _send_chat(text))
	row.add_child(draft)
	var send := Button.new()
	send.name = "Send"
	send.text = "发送"
	BbPetTheme.apply_button(send, "main")
	send.pressed.connect(func(): _send_chat(draft.text))
	row.add_child(send)
	content.add_child(row)


func _refresh_chat_log() -> void:
	var log: VBoxContainer = content.get_node_or_null("Log")
	if log == null:
		return
	for child in log.get_children():
		child.free()
	if _chat_history.is_empty() and not _chat_busy:
		var hint := Label.new()
		hint.text = "点一下就能聊。可以说天气、新闻，或随便问问今天开不开心。"
		BbPetTheme.apply_hint(hint)
		log.add_child(hint)
	for item in _chat_history:
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = String(item.get("content", ""))
		log.add_child(row)
	if _chat_busy:
		var pending := Label.new()
		pending.text = "%s 正在想..." % _state().pet.name
		log.add_child(pending)


func _send_chat(text: String) -> void:
	var cleaned := text.strip_edges()
	if cleaned.is_empty() or _chat_busy:
		return
	var draft: LineEdit = content.get_node_or_null("Composer/Draft")
	if draft:
		draft.text = ""
	_chat_history.append({"role": "user", "content": cleaned})
	var settings: Dictionary = _state().settings
	if String(settings.get("apiKey", "")).strip_edges().is_empty():
		var placeholder: Dictionary = ChatClient.reply_without_key(_chat_history.size())
		_chat_history.append({"role": "assistant", "content": placeholder.reply})
		_persist_chat()
		_refresh_chat_log()
		return
	_chat_busy = true
	_persist_chat()
	_refresh_chat_log()
	_pending_messages = _chat_history.duplicate(true)
	_pending_models = []
	var model := String(settings.get("model", ""))
	var fallback := String(settings.get("fallbackModel", ""))
	if not model.is_empty():
		_pending_models.append(model)
	if not fallback.is_empty() and fallback != model:
		_pending_models.append(fallback)
	_ensure_http()
	_request_next_model()


func _ensure_http() -> void:
	if _http != null:
		return
	_http = HTTPRequest.new()
	_http.timeout = 28.0
	add_child(_http)
	_http.request_completed.connect(_on_chat_http)


func _request_next_model() -> void:
	if _pending_models.is_empty():
		_chat_busy = false
		var fail: Dictionary = ChatClient.error_reply("empty")
		_chat_history.append({"role": "assistant", "content": fail.reply})
		_persist_chat()
		_refresh_chat_log()
		return
	var model: String = _pending_models.pop_front()
	var settings: Dictionary = _state().settings
	var url := ChatClient.completions_url(str(settings.get("apiBaseUrl", "")))
	var body: Dictionary = ChatClient.chat_body(
		model,
		_pending_messages,
		str(_state().pet.name),
		str(PET_TEMPLATES.SPECIES_LABELS.get(_state().pet.species, _state().pet.species))
	)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % str(settings.get("apiKey", "")),
		"HTTP-Referer: https://bbpet.local",
		"X-Title: BbPet",
	])
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_request_next_model()


func _on_chat_http(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var raw := body.get_string_from_utf8()
	if code >= 200 and code < 300:
		var text := ChatClient.parse_reply(raw)
		if not text.is_empty():
			_chat_busy = false
			_chat_history.append({"role": "assistant", "content": text})
			_persist_chat()
			_refresh_chat_log()
			return
	if not _pending_models.is_empty():
		_request_next_model()
		return
	_chat_busy = false
	var fail: Dictionary = ChatClient.error_reply("HTTP %d: %s" % [code, raw])
	_chat_history.append({"role": "assistant", "content": fail.reply})
	_persist_chat()
	_refresh_chat_log()


func _confirm_wizard(name_input: LineEdit, city_input: OptionButton, error_label: Label) -> void:
	_app_state().set_species(_selected_species)
	if not _app_state().set_pet_name(name_input.text):
		error_label.text = "请给宠物起个名字"
		return
	var city_id: String = city_input.get_item_metadata(city_input.selected)
	_app_state().set_city(city_id)
	_app_state().mark_onboarded()
	_app_state().save_to(STATE_PATH)
	get_node("/root/WeatherClient").refresh_after_settings()
	_window_hub().refresh_pet()
	_window_hub().close_panel()


func _save_settings(
	name_input: LineEdit,
	species_input: OptionButton,
	city_input: OptionButton,
	push_input: LineEdit,
	room_input: LineEdit,
	host_room: CheckBox,
	base_input: LineEdit,
	key_input: LineEdit,
	model_input: LineEdit,
	fallback_input: LineEdit,
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
	var city_id: String = city_input.get_item_metadata(city_input.selected)
	_app_state().set_city(city_id)
	_app_state().set_push_interval_min(int(push_input.text))
	_app_state().set_llm(base_input.text, key_input.text, model_input.text, fallback_input.text)
	_app_state().set_host_room(host_room.button_pressed)
	_app_state().save_to(STATE_PATH)
	get_node("/root/WeatherClient").refresh_after_settings()
	_window_hub().refresh_pet()
	_window_hub().sync_room_host()
	var host_error := String(_window_hub().host_error)
	if not host_error.is_empty():
		error_label.text = host_error
		return
	var room_client := _room_client()
	if room_client.connected:
		_window_hub().discard_world()
		room_client.disconnect_room()
	_window_hub().close_panel()


func _persist_chat() -> void:
	if not is_inside_tree():
		return
	_app_state().set_chat_history(_chat_history)
	_app_state().save_to(STATE_PATH)


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
			"photoDataUrl": "",
		},
		"chatHistory": [],
		"settings": {
			"roomUrl": "",
			"cityId": WeatherCities.DEFAULT_CITY.id,
			"pushIntervalMin": 30,
			"hostRoom": false,
		},
	}


func _room_client() -> Node:
	return get_node("/root/RoomClient")


func _room_client_or_null() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/RoomClient")


func _window_hub() -> Node:
	return get_node("/root/WindowHub")
