extends RefCounted


func run() -> int:
	var failed := 0
	var source := FileAccess.get_file_as_string("res://windows/world_window.gd")
	failed += _check("inspect menu helper", source.contains("func _open_inspect"))
	failed += _check("add friend copy", source.contains('"加好友"'))
	failed += _check("no already friend copy", not source.contains('"已是好友"'))
	failed += _check("visit copy", source.contains('"去他家"'))
	failed += _check("away copy", source.contains('"不在家"'))
	failed += _check("cancel copy", source.contains('"取消"'))
	failed += _check("gomoku copy", source.contains("五子棋"))
	failed += _check("invite copy", source.contains("邀请你下五子棋"))
	failed += _check("game respond", source.contains("game_respond"))
	failed += _check("invite game", source.contains("invite_game"))
	failed += _check("request friend", source.contains("RoomClient.request_friend"))
	failed += _check("board empty copy", source.contains("黑板还是空的，回车写一句。"))
	failed += _check("board hint", source.contains("黑板只有本班听得见"))
	failed += _check("chat placeholder", source.contains("点这里或按 Enter 写黑板"))
	failed += _check("campus placeholder", source.contains("点这里或按 Enter 说话"))
	failed += _check("send copy", source.contains('"发送"'))
	failed += _check("bubble hint", source.contains("走近才看得到气泡"))
	failed += _check("nearby bubbles", source.contains("_refresh_nearby_bubbles"))
	failed += _check("chat send", source.contains("RoomClient.send_chat"))
	failed += _check("focus blocks walk", source.contains("_chat_focused"))
	failed += _check("school WeatherDress overlay", source.contains("WeatherDress"))
	failed += _check("school dress_updated", source.contains("dress_updated"))
	var tscn := FileAccess.get_file_as_string("res://windows/world_window.tscn")
	failed += _check("chat bar scene", tscn.contains("name=\"ChatBar\""))
	failed += _check("chat input scene", tscn.contains("name=\"ChatInput\""))
	failed += _check("status not stuck on last notice", not _update_status_uses_last_notice(source))
	return failed


func _update_status_uses_last_notice(source: String) -> bool:
	var start := source.find("func _update_status")
	if start < 0:
		return true
	var nxt := source.find("\nfunc ", start + 1)
	var body := source.substr(start, nxt - start if nxt > start else source.length() - start)
	return body.contains("last_notice")


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("world_social: %s" % label)
	return 1
