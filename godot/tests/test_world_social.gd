extends RefCounted


func run() -> int:
	var failed := 0
	var source := FileAccess.get_file_as_string("res://windows/world_window.gd")
	failed += _check("inspect menu helper", source.contains("func _open_inspect"))
	failed += _check("add friend copy", source.contains('"加好友"'))
	failed += _check("already friend copy", source.contains('"已是好友"'))
	failed += _check("cancel copy", source.contains('"取消"'))
	failed += _check("no visit", not source.contains("去他家"))
	failed += _check("no gomoku", not source.contains("五子棋"))
	failed += _check("request friend", source.contains("RoomClient.request_friend"))
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("world_social: %s" % label)
	return 1
