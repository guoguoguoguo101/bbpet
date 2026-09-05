extends Node

signal panel_toggled

const PANEL_SCENE = preload("res://windows/panel_window.tscn")

var _has_tray := false
var _panel: Window


func _ready() -> void:
	if DisplayServer.get_name() != "headless" and not AppState.state.onboarded:
		open_panel.call_deferred("wizard")


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
	push_warning("go_to_school")


func close_world() -> void:
	if RoomClient.has_method("disconnect_room"):
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
	get_tree().quit()


func show_pet() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().always_on_top = true
