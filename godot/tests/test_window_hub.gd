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
	failed += _check(
		"close world hides without leaving",
		_close_world_hides_without_leaving(source)
	)
	failed += _check("discard world on quit", source.contains("func discard_world"))
	failed += _check("friends panel kind", source.contains('"friends"'))
	failed += _check("open friends API", source.contains("func open_friends"))
	failed += _check("go home API", source.contains("func go_home"))
	failed += _check(
		"go home connects before pending",
		_go_home_connects_before_pending(source)
	)
	failed += _check(
		"connect room before opening friends",
		_open_friends_connects_before_opening(source)
	)
	failed += _check("school snapshot gate", source.contains("SchoolSocial.should_open_world"))
	failed += _check("show bubble API", source.contains("func show_bubble"))
	failed += _check("hide bubble API", source.contains("func hide_bubble"))
	failed += _check("connects bubble_requested", source.contains("WeatherClient.bubble_requested"))
	failed += _check("bubble window script", source.contains("res://windows/bubble_window.gd"))
	failed += _check("clamps to usable rect", source.contains("screen_get_usable_rect"))

	var bubble_script: Variant = load("res://windows/bubble_window.gd")
	if bubble_script == null or not bubble_script is Script or not bubble_script.can_instantiate():
		push_error("window_hub: missing bubble window")
		return failed + 1
	var bubble: Window = bubble_script.new()
	failed += _check("bubble is Window", bubble is Window)
	failed += _check("bubble borderless", bubble.borderless)
	failed += _check("bubble transparent", bubble.transparent)
	failed += _check("bubble always on top", bubble.always_on_top)
	failed += _check("bubble unresizable", bubble.unresizable)
	failed += _check("bubble min size", bubble.size.x >= 220 and bubble.size.y >= 80)
	var bubble_source := FileAccess.get_file_as_string("res://windows/bubble_window.gd")
	failed += _check("bubble shell open", bubble_source.contains("OS.shell_open"))
	failed += _check("bubble hold 8s", bubble_source.contains("8.0"))
	failed += _check("bubble hold 16s", bubble_source.contains("16.0"))
	failed += _check("bubble wrap width", bubble_source.contains("240"))
	failed += _check("bubble autowrap", bubble_source.contains("autowrap"))
	failed += _check("bubble label", bubble_source.contains("Label"))
	bubble.free()
	return failed


func _go_home_connects_before_pending(source: String) -> bool:
	var start := source.find("func go_home")
	if start < 0:
		return false
	var nxt := source.find("\nfunc ", start + 1)
	var body := source.substr(start, nxt - start if nxt > start else source.length() - start)
	var connect := body.find("connect_room")
	var pending := body.find("pending_enter")
	return (
		body.contains("RoomClient.go_home")
		and connect >= 0
		and pending >= 0
		and connect < pending
	)


func _open_friends_connects_before_opening(source: String) -> bool:
	var start := source.find("func open_friends")
	if start < 0:
		return false
	var nxt := source.find("\nfunc ", start + 1)
	var body := source.substr(start, nxt - start if nxt > start else source.length() - start)
	var connect := body.find("connect_room")
	var open := body.find('open_panel("friends")')
	return connect >= 0 and open >= 0 and connect < open


func _close_world_hides_without_leaving(source: String) -> bool:
	var start := source.find("func close_world")
	if start < 0:
		return false
	var nxt := source.find("\nfunc ", start + 1)
	var body := source.substr(start, nxt - start if nxt > start else source.length() - start)
	return (
		body.contains("_world.hide()")
		and not body.contains("leave_school")
		and not body.contains("disconnect_room")
		and not body.contains("queue_free")
	)


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("window_hub: %s" % label)
	return 1
