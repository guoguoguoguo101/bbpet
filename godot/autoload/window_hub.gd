extends Node

signal panel_toggled

const PANEL_SCENE = preload("res://windows/panel_window.tscn")
const WORLD_SCENE = preload("res://windows/world_window.tscn")
const BUBBLE_SCRIPT = preload("res://windows/bubble_window.gd")
const FLYER_SCRIPT = preload("res://windows/flyer_window.gd")
const GOMOKU_SCRIPT = preload("res://windows/gomoku_window.gd")
const SchoolSocial = preload("res://school/school_social.gd")
const HomeLogic = preload("res://home/home_logic.gd")
const SchoolLogic = preload("res://school/school_logic.gd")
const MENU_SHOW := 1
const MENU_HIDE := 2
const MENU_QUIT := 3
const MENU_HUB := 10
const MENU_SCHOOL := 11
const MENU_HOME := 12
const MENU_FRIENDS := 13
const MENU_CHAT := 14
const MENU_WEATHER := 15
const MENU_NEWS := 16
const MENU_SETTINGS := 17
const MENU_DEMO_OFF := 40

var _has_tray := false
var _panel: Window
var _world: Window
var _bubble: Window
var _flyer: Window
var _flyer_target := ""
var _game: Window
var _last_game_status := ""
var _demo_ids := {}
var _host_pid := -1
var host_error := ""


func _ready() -> void:
	_ensure_room_signals()
	_ensure_bubble_signals()
	_ensure_game_signals()
	if DisplayServer.get_name() == "headless":
		return
	_setup_tray()
	sync_room_host()
	if not AppState.state.onboarded:
		open_panel.call_deferred("wizard")


func _setup_tray() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
		_has_tray = false
		return
	var indicator := StatusIndicator.new()
	if indicator.get_class() != "StatusIndicator":
		indicator.free()
		_has_tray = false
		return
	indicator.tooltip = "BbPet"
	var pet: Dictionary = AppState.state.pet
	var frame := PetTemplates.get_frame(pet.species, "idle")
	var image := PetTemplates.paint_image(frame, pet.colors, 1)
	indicator.icon = ImageTexture.create_from_image(image)

	var menu := PopupMenu.new()
	menu.add_item("显示", MENU_SHOW)
	menu.add_item("隐藏", MENU_HIDE)
	menu.add_separator()
	_add_shortcut_items(menu)
	menu.add_separator()
	_add_action_submenu(menu)
	menu.add_separator()
	menu.add_item("退出", MENU_QUIT)
	add_child(menu)
	add_child(indicator)
	indicator.menu = menu.get_path()
	indicator.pressed.connect(_on_tray_pressed)
	menu.id_pressed.connect(_on_tray_menu)
	_has_tray = true


func _add_shortcut_items(menu: PopupMenu) -> void:
	menu.add_item("今天去哪", MENU_HUB)
	menu.add_item("去上学", MENU_SCHOOL)
	menu.add_item("回家", MENU_HOME)
	menu.add_item("好友", MENU_FRIENDS)
	menu.add_item("聊一聊", MENU_CHAT)
	menu.add_item("现在看看天气", MENU_WEATHER)
	menu.add_item("现在看看新闻", MENU_NEWS)
	menu.add_item("设置", MENU_SETTINGS)


func _add_action_submenu(menu: PopupMenu) -> void:
	var actions := PopupMenu.new()
	menu.add_child(actions)
	var poses := PopupMenu.new()
	var slack := PopupMenu.new()
	var weather := PopupMenu.new()
	actions.add_child(poses)
	actions.add_child(slack)
	actions.add_child(weather)
	var pose_items := [
		["idle", "发呆"],
		["look-right", "看右边"],
		["look-left", "看左边"],
		["blink", "眨眼"],
		["talk", "说话"],
		["drink", "喝水"],
		["sleep", "睡觉"],
		["wake", "伸懒腰"],
		["type", "打字"],
	]
	var slack_items := [
		["phone", "刷手机"],
		["snack", "偷吃"],
		["peek", "张望"],
		["game", "打游戏"],
		["coffee", "喝咖啡"],
		["toilet", "上厕所"],
	]
	var weather_items := [
		["wx-sun", "☀️ 晴天"],
		["wx-hot", "🥵 炎热"],
		["wx-drizzle", "🌦️ 毛毛雨 · 伞"],
		["wx-rain", "🌧️ 下雨 · 雨衣"],
		["wx-storm", "⛈️ 雷暴 · 发抖"],
		["wx-snow", "🌨️ 下雪 · 雪人"],
		["wx-cold", "☁️ 寒冷 · 围巾帽"],
		["wx-fog", "🌫️ 有雾"],
		["wx-night", "🌙 晚上 · 星星"],
		["wx-wind", "💨 大风 · 站稳"],
		["wx-partly", "⛅ 多云"],
		["wx-overcast", "☁️ 阴天"],
	]
	_fill_demo_menu(poses, pose_items, 100)
	_fill_demo_menu(slack, slack_items, 200)
	_fill_demo_menu(weather, weather_items, 300)
	actions.add_submenu_node_item("待机动作", poses)
	actions.add_submenu_node_item("摸鱼", slack)
	actions.add_submenu_node_item("天气装扮", weather)
	actions.add_separator()
	actions.add_item("恢复待机", MENU_DEMO_OFF)
	actions.id_pressed.connect(_on_tray_menu)
	poses.id_pressed.connect(_on_demo_menu)
	slack.id_pressed.connect(_on_demo_menu)
	weather.id_pressed.connect(_on_demo_menu)
	menu.add_submenu_node_item("动作", actions)


func _fill_demo_menu(menu: PopupMenu, items: Array, id_base: int) -> void:
	for index in items.size():
		var entry: Array = items[index]
		var item_id := id_base + index
		menu.add_item(String(entry[1]), item_id)
		_demo_ids[item_id] = String(entry[0])


func toggle_panel() -> void:
	if panel_is_open():
		close_panel()
	elif not AppState.state.onboarded:
		open_panel("wizard")
	else:
		open_panel("hub")
	panel_toggled.emit()


func open_panel(kind: String) -> void:
	if not ["wizard", "hub", "settings", "friends", "chat"].has(kind):
		push_error("Unknown panel kind: %s" % kind)
		return
	close_panel()
	_panel = PANEL_SCENE.instantiate()
	add_child(_panel)
	_panel.show_kind(kind)
	_panel.popup()
	_position_panel()


func close_panel() -> void:
	if not is_instance_valid(_panel):
		_panel = null
		return
	_panel.hide()
	_panel.queue_free()
	_panel = null


func panel_is_open() -> bool:
	return is_instance_valid(_panel) and _panel.visible


func go_to_school() -> void:
	_ensure_room_signals()
	if is_instance_valid(_world) and RoomClient.connected and SchoolSocial.should_open_world(RoomClient.place_id):
		_world.show()
		_world.grab_focus()
		return
	_show_room_status("")
	if RoomClient.connected:
		RoomClient.begin_school_flow()
		RoomClient.enter_place(RoomClient.SCHOOL_CAMPUS)
		return
	RoomClient.connect_room(AppState.state.settings.roomUrl)
	RoomClient.begin_school_flow()


func go_home(owner_id: String = "") -> void:
	close_panel()
	_ensure_room_signals()
	var target := owner_id
	if target.is_empty():
		target = AppState.state.clientId
	if RoomClient.connected:
		RoomClient.go_home(target)
		return
	RoomClient.connect_room(AppState.state.settings.roomUrl)
	RoomClient.pending_enter = HomeLogic.home_place_id(target)


func open_friends() -> void:
	_ensure_room_signals()
	if not RoomClient.connected:
		_show_room_status("")
		RoomClient.pending_enter = ""
		RoomClient.connect_room(AppState.state.settings.roomUrl)
	open_panel("friends")


func show_world(you: Dictionary, people: Array, place_id: String) -> void:
	if not is_instance_valid(_world):
		_world = WORLD_SCENE.instantiate()
		add_child(_world)
	_world.apply_snapshot(you, people, place_id)
	_world.popup()
	_world.grab_focus()


func _ensure_room_signals() -> void:
	if not RoomClient.connect_failed.is_connected(_on_room_connect_failed):
		RoomClient.connect_failed.connect(_on_room_connect_failed)
	if not RoomClient.status.is_connected(_on_room_status):
		RoomClient.status.connect(_on_room_status)
	if not RoomClient.snapshot_ready.is_connected(_on_room_snapshot):
		RoomClient.snapshot_ready.connect(_on_room_snapshot)
	if not RoomClient.others_updated.is_connected(_on_room_others_updated):
		RoomClient.others_updated.connect(_on_room_others_updated)


func _ensure_game_signals() -> void:
	if not RoomClient.game_updated.is_connected(_on_game_updated):
		RoomClient.game_updated.connect(_on_game_updated)


func _on_game_updated(game: Dictionary) -> void:
	var status := String(game.get("status", ""))
	if status == "playing" and _last_game_status != "playing":
		show_game()
	_last_game_status = status
	if is_instance_valid(_game) and _game.has_method("present"):
		_game.call("present", game)


func _on_room_connect_failed(reason: String) -> void:
	_show_room_status(reason)


func _on_room_status(text: String) -> void:
	_show_room_status(text)


func _on_room_snapshot(you: Dictionary, people: Array, place_id: String) -> void:
	if not SchoolSocial.should_open_world(place_id):
		return
	close_panel()
	show_world(you, people, place_id)


func _on_room_others_updated(people: Array) -> void:
	if is_instance_valid(_world):
		_world.apply_others(people)


func _show_room_status(text: String) -> void:
	if is_instance_valid(_world):
		_world.show_status(text)
		return
	if not is_instance_valid(_panel):
		return
	var content: VBoxContainer = _panel.get_node_or_null("Margin/Content")
	if content == null:
		return
	var label: Label = content.get_node_or_null("RoomStatus")
	if label == null:
		label = Label.new()
		label.name = "RoomStatus"
		label.modulate = Color("#b3261e")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(label)
		content.move_child(label, 0)
	label.text = text


func close_world() -> void:
	if not is_instance_valid(_world):
		return
	AppState.save_world_size(_world.size.x, _world.size.y)
	_world.show_status("")
	_world.hide()


func discard_world() -> void:
	close_world()
	if not is_instance_valid(_world):
		return
	_world.queue_free()
	_world = null


func refresh_pet() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pet: TextureRect = scene.get_node_or_null("PixelPet")
	if pet == null:
		return
	pet.species = AppState.state.pet.species
	pet.colors = AppState.state.pet.colors.duplicate(true)
	pet.redraw()
	if scene.has_method("update_passthrough"):
		scene.call("update_passthrough")


func _position_panel() -> void:
	if not is_instance_valid(_panel):
		return
	var pet_window := get_tree().root
	var usable := DisplayServer.screen_get_usable_rect()
	var right := pet_window.position + Vector2i(pet_window.size.x + 8, 0)
	if right.x + _panel.size.x <= usable.end.x:
		_panel.position = right
	else:
		_panel.position = Vector2i(pet_window.position.x - _panel.size.x - 8, pet_window.position.y)


func _ensure_bubble_signals() -> void:
	if not WeatherClient.bubble_requested.is_connected(show_bubble):
		WeatherClient.bubble_requested.connect(show_bubble)


func show_bubble(payload: Dictionary) -> void:
	var pet_window := get_window()
	if pet_window == null or not pet_window.visible or pet_window.mode == Window.MODE_MINIMIZED:
		return
	if not is_instance_valid(_bubble):
		_bubble = BUBBLE_SCRIPT.new()
		add_child(_bubble)
		if not _bubble.dismissed.is_connected(_on_bubble_dismissed):
			_bubble.dismissed.connect(_on_bubble_dismissed)
	_bubble.present(payload)
	_position_bubble()
	_bubble.show()
	_set_pet_talking(bool(payload.get("talk", false)))


func hide_bubble() -> void:
	if not is_instance_valid(_bubble):
		_bubble = null
		_set_pet_talking(false)
		return
	_bubble.dismiss()


func _on_bubble_dismissed() -> void:
	_set_pet_talking(false)


func _set_pet_talking(on: bool) -> void:
	if get_tree() == null:
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("set_talking_push"):
		scene.call("set_talking_push", on)


func play_flyer(payload: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not is_instance_valid(_flyer):
		_flyer = FLYER_SCRIPT.new()
		add_child(_flyer)
	_flyer_target = String(payload.get("id", ""))
	_flyer.play(payload)


func hide_flyer() -> void:
	_flyer_target = ""
	if is_instance_valid(_flyer):
		_flyer.dismiss()


func flyer_finished() -> void:
	_flyer_target = ""
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("on_flyer_finished"):
		scene.call("on_flyer_finished")


func flyer_target_id() -> String:
	return _flyer_target


func _position_bubble() -> void:
	if not is_instance_valid(_bubble):
		return
	var pet_window := get_tree().root
	var usable := DisplayServer.screen_get_usable_rect()
	var pos := Vector2i(
		pet_window.position.x - _bubble.size.x - 8,
		pet_window.position.y
	)
	pos.x = clampi(pos.x, usable.position.x, usable.end.x - _bubble.size.x)
	pos.y = clampi(pos.y, usable.position.y, usable.end.y - _bubble.size.y)
	_bubble.position = pos


func hide_pet() -> void:
	if _has_tray:
		get_window().hide()
	else:
		get_window().mode = Window.MODE_MINIMIZED


func show_game() -> void:
	_ensure_game_signals()
	if DisplayServer.get_name() == "headless":
		return
	if not is_instance_valid(_game):
		_game = GOMOKU_SCRIPT.new()
		add_child(_game)
		if not _game.close_requested.is_connected(close_game):
			_game.close_requested.connect(close_game)
	if _game.has_method("present"):
		_game.call("present", RoomClient.game)
	_game.show()
	_game.grab_focus()


func close_game() -> void:
	if is_instance_valid(_game):
		if String(RoomClient.game.get("status", "")) == "playing":
			RoomClient.game_resign(String(RoomClient.game.get("id", "")))
		_game.hide()
		_game.queue_free()
		_game = null


func quit_app() -> void:
	stop_room_host()
	close_game()
	hide_flyer()
	discard_world()
	RoomClient.disconnect_room()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		stop_room_host()


func sync_room_host() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want := bool(AppState.state.settings.get("hostRoom", false))
	if not want:
		stop_room_host()
		host_error = ""
		return
	if _host_pid > 0 and OS.is_process_running(_host_pid):
		host_error = ""
		return
	_host_pid = -1
	if _port_in_use(SchoolLogic.room_listen_port(str(AppState.state.settings.get("roomUrl", "")))):
		host_error = "校长室没开起来，端口可能被占用"
		return
	_host_pid = _start_room_process()
	if _host_pid <= 0:
		host_error = "校长室没开起来，端口可能被占用"
		return
	host_error = ""


func stop_room_host() -> void:
	if _host_pid <= 0:
		return
	if OS.get_name() == "Windows":
		OS.execute("taskkill", PackedStringArray(["/PID", str(_host_pid), "/T", "/F"]), [], false, false)
	elif OS.is_process_running(_host_pid):
		OS.kill(_host_pid)
	_host_pid = -1


func _start_room_process() -> int:
	var root := _repo_root()
	if root.is_empty():
		return -1
	var quoted := root.replace("'", "''")
	var command := "Set-Location -LiteralPath '%s'; npm run room" % quoted
	return OS.create_process(
		"powershell.exe",
		PackedStringArray([
			"-NoProfile",
			"-WindowStyle",
			"Hidden",
			"-ExecutionPolicy",
			"Bypass",
			"-Command",
			command,
		])
	)


func _repo_root() -> String:
	var godot_dir := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	return godot_dir.get_base_dir()


func _port_in_use(port: int) -> bool:
	var probe := TCPServer.new()
	var err := probe.listen(port, "127.0.0.1")
	if err == OK:
		probe.stop()
		return false
	return true


func show_pet() -> void:
	var pet_window := get_window()
	pet_window.show()
	pet_window.mode = Window.MODE_WINDOWED
	pet_window.always_on_top = true


func _on_tray_pressed(mouse_button: int, _mouse_position: Vector2i) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		show_pet()


func _on_demo_menu(id: int) -> void:
	if not _demo_ids.has(id):
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("play_demo"):
		scene.call("play_demo", String(_demo_ids[id]))


func _on_tray_menu(id: int) -> void:
	match id:
		MENU_SHOW:
			show_pet()
		MENU_HIDE:
			hide_pet()
		MENU_HUB:
			open_panel("hub")
		MENU_SCHOOL:
			go_to_school()
		MENU_HOME:
			go_home()
		MENU_FRIENDS:
			open_friends()
		MENU_CHAT:
			open_panel("chat")
		MENU_WEATHER:
			WeatherClient.push_once("weather")
		MENU_NEWS:
			WeatherClient.push_once("news")
		MENU_SETTINGS:
			open_panel("settings")
		MENU_DEMO_OFF:
			var scene := get_tree().current_scene
			if scene != null and scene.has_method("play_demo"):
				scene.call("play_demo", "off")
		MENU_QUIT:
			quit_app()
		_:
			_on_demo_menu(id)
