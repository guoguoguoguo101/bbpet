extends Node

signal panel_toggled

const PANEL_SCENE = preload("res://windows/panel_window.tscn")
const WORLD_SCENE = preload("res://windows/world_window.tscn")
const MENU_SHOW := 1
const MENU_HIDE := 2
const MENU_QUIT := 3

var _has_tray := false
var _panel: Window
var _world: Window


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_setup_tray()
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
	menu.add_item("退出", MENU_QUIT)
	add_child(menu)
	add_child(indicator)
	indicator.menu = menu.get_path()
	indicator.pressed.connect(_on_tray_pressed)
	menu.id_pressed.connect(_on_tray_menu)
	_has_tray = true


func toggle_panel() -> void:
	if panel_is_open():
		close_panel()
	elif not AppState.state.onboarded:
		open_panel("wizard")
	else:
		open_panel("hub")
	panel_toggled.emit()


func open_panel(kind: String) -> void:
	if not ["wizard", "hub", "settings"].has(kind):
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
	if is_instance_valid(_world):
		_world.show()
		_world.grab_focus()
		return
	close_panel()
	var place_id := "school:campus"
	var spawn := SchoolLogic.default_spawn(place_id)
	var pet: Dictionary = AppState.state.pet
	var you := {
		"clientId": AppState.state.clientId,
		"name": pet.name,
		"species": pet.species,
		"colors": pet.colors.duplicate(true),
		"x": spawn.x,
		"y": spawn.y,
		"facing": "r",
		"schoolPlaceId": place_id,
	}
	show_world(you, [], place_id)
	RoomClient.enter_place(place_id)


func show_world(you: Dictionary, people: Array, place_id: String) -> void:
	if not is_instance_valid(_world):
		_world = WORLD_SCENE.instantiate()
		add_child(_world)
	_world.apply_snapshot(you, people, place_id)
	_world.popup()
	_world.grab_focus()


func close_world() -> void:
	if is_instance_valid(_world):
		AppState.save_world_size(_world.size.x, _world.size.y)
		_world.hide()
		_world.queue_free()
		_world = null
	RoomClient.disconnect_room()


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


func hide_pet() -> void:
	if _has_tray:
		get_window().hide()
	else:
		get_window().mode = Window.MODE_MINIMIZED


func quit_app() -> void:
	RoomClient.disconnect_room()
	get_tree().quit()


func show_pet() -> void:
	var pet_window := get_window()
	pet_window.show()
	pet_window.mode = Window.MODE_WINDOWED
	pet_window.always_on_top = true


func _on_tray_pressed(mouse_button: int, _mouse_position: Vector2i) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		show_pet()


func _on_tray_menu(id: int) -> void:
	match id:
		MENU_SHOW:
			show_pet()
		MENU_HIDE:
			hide_pet()
		MENU_QUIT:
			quit_app()
