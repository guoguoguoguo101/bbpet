extends RefCounted

func run() -> int:
	var failed := 0
	var source := FileAccess.get_file_as_string("res://windows/pet_root.gd")
	failed += _check("gathering layout", source.contains("func _refresh_gathering"))
	failed += _check("chat copy", source.contains('"聊"') and source.contains('"收"') and source.contains("回车发送"))
	failed += _check("title home", source.contains("自家"))
	failed += _check("emote hugs", source.contains("抱抱"))
	failed += _check("play flyer", source.contains("WindowHub.play_flyer"))
	failed += _check("flyer seat", source.contains("HomeLogic.flyer_seat"))
	failed += _check("home chat", source.contains("send_home_chat"))
	failed += _check("send emote", source.contains("send_emote"))
	failed += _check("passthrough region", source.contains("DisplayServer.window_set_mouse_passthrough"))
	failed += _check("no full click-through", not source.contains("mouse_passthrough = true"))
	failed += _check("anchor math", source.contains("HomeLogic.anchor_window"))
	failed += _check(
		"reposition on gather",
		_fn_contains(source, "_refresh_gathering", "_set_window_size")
		or _fn_contains(source, "_refresh_gathering", "HomeLogic.anchor_window")
	)
	failed += _check(
		"reposition on shrink",
		_fn_contains(source, "_shrink_to_pet", "_set_window_size")
		or _fn_contains(source, "_shrink_to_pet", "HomeLogic.anchor_window")
	)
	return failed


func _fn_contains(source: String, fn: String, needle: String) -> bool:
	var start := source.find("func %s" % fn)
	if start < 0:
		return false
	var nxt := source.find("\nfunc ", start + 1)
	var body := source.substr(start, nxt - start if nxt > start else source.length() - start)
	return body.contains(needle)

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("pet_gathering: %s" % label)
	return 1
