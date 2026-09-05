extends RefCounted

const ROOM_CLIENT_SCRIPT = preload("res://autoload/room_client.gd")


func run() -> int:
	var failed := 0
	var rc: Node = ROOM_CLIENT_SCRIPT.new()
	if not rc.has_signal("snapshot_ready") or not rc.has_method("begin_school_flow"):
		rc.free()
		return _check("school flow API", false)
	rc.disconnect_room()
	var saw := {"campus": false}
	var on_snap := func(_you, _people, place_id):
		if place_id == "school:campus":
			saw.campus = true
	rc.snapshot_ready.connect(on_snap)
	rc.begin_school_flow()
	rc._handle_server_text(
		'{"type":"welcome","you":{"clientId":"x","placeId":"home:x","x":0,"y":0}}'
	)
	failed += _check("queued enter", rc.last_enter_requested == "school:campus")
	rc._handle_server_text(
		'{"type":"snapshot","you":{"clientId":"x","x":384,"y":348,"facing":"r",'
		+ '"species":"blob","name":"豆豆","colors":{}},'
		+ '"snapshot":{"placeId":"school:campus","people":[]}}'
	)
	failed += _check("campus snapshot", saw.campus)
	rc._handle_server_text('{"type":"chat","line":{"text":"hi"}}')
	failed += _check("ignored chat", rc.status_text.find("hi") == -1)
	rc._handle_server_text('{"type":"error","message":"学校人满了"}')
	failed += _check("error text", rc.status_text.contains("学校人满了"))
	rc.snapshot_ready.disconnect(on_snap)
	rc.free()
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("room_client: %s" % label)
	return 1
