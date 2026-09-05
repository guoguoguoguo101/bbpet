extends RefCounted

const ROOM_CLIENT_SCRIPT = preload("res://autoload/room_client.gd")


func run() -> int:
	var failed := 0
	var room_client: Node = ROOM_CLIENT_SCRIPT.new()
	failed += _check("room client disconnect API", room_client.has_method("disconnect_room"))
	room_client.free()

	var source := FileAccess.get_file_as_string("res://autoload/window_hub.gd")
	failed += _check("tray indicator", source.contains("StatusIndicator.new()"))
	failed += _check(
		"tray support guard",
		source.contains("DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR)")
	)
	failed += _check("tray show item", source.contains('menu.add_item("显示", MENU_SHOW)'))
	failed += _check("tray hide item", source.contains('menu.add_item("隐藏", MENU_HIDE)'))
	failed += _check("tray quit item", source.contains('menu.add_item("退出", MENU_QUIT)'))
	failed += _check("quit disconnects room", source.contains("RoomClient.disconnect_room()"))
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("window_hub: %s" % label)
	return 1
