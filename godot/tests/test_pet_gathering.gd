extends RefCounted

func run() -> int:
	var failed := 0
	var source := FileAccess.get_file_as_string("res://windows/pet_root.gd")
	failed += _check("gathering layout", source.contains("func _refresh_gathering"))
	failed += _check("chat copy", source.contains('"聊"') and source.contains('"收"') and source.contains("回车发送"))
	failed += _check("title home", source.contains("自家"))
	failed += _check("emote hugs", source.contains("抱抱"))
	failed += _check("no flyer", not source.contains("FLYER") and not source.contains("playFlyer"))
	failed += _check("home chat", source.contains("send_home_chat"))
	failed += _check("send emote", source.contains("send_emote"))
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("pet_gathering: %s" % label)
	return 1
