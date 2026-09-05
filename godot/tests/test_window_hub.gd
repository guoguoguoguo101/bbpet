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
	failed += _check("close world leaves school", source.contains("RoomClient.leave_school()"))
	failed += _check(
		"close world does not disconnect",
		_close_world_does_not_disconnect(source)
	)
	failed += _check("friends panel kind", source.contains('"friends"'))
	failed += _check("open friends API", source.contains("func open_friends"))
	failed += _check(
		"connect room before opening friends",
		_open_friends_connects_before_opening(source)
	)
	failed += _check("school snapshot gate", source.contains("SchoolSocial.should_open_world"))
	return failed


func _open_friends_connects_before_opening(source: String) -> bool:
	var start := source.find("func open_friends")
	if start < 0:
		return false
	var nxt := source.find("\nfunc ", start + 1)
	var body := source.substr(start, nxt - start if nxt > start else source.length() - start)
	var connect := body.find("connect_room")
	var open := body.find('open_panel("friends")')
	return connect >= 0 and open >= 0 and connect < open


func _close_world_does_not_disconnect(source: String) -> bool:
	var start := source.find("func close_world")
	if start < 0:
		return false
	var nxt := source.find("\nfunc ", start + 1)
	var body := source.substr(start, nxt - start if nxt > start else source.length() - start)
	return body.contains("leave_school") and not body.contains("disconnect_room")


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("window_hub: %s" % label)
	return 1
