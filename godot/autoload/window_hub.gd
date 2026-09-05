extends Node

signal panel_toggled

var _has_tray := false


func toggle_panel() -> void:
	panel_toggled.emit()


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
