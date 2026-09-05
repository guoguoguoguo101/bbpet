extends RefCounted

const ROOM_CLIENT_SCRIPT = preload("res://autoload/room_client.gd")
const SchoolSocial = preload("res://school/school_social.gd")


func run() -> int:
	var failed := 0
	var rc: Node = ROOM_CLIENT_SCRIPT.new()
	if not rc.has_method("leave_school") or not rc.has_method("send_chat") or not rc.has_method("request_friend"):
		rc.free()
		return _check("social API", false)
	failed += _check("go_home API", rc.has_method("go_home") and rc.has_method("send_emote") and rc.has_method("send_home_chat"))
	if failed:
		rc.free()
		return failed
	rc.connected = true
	rc._handle_server_text(
		'{"type":"welcome","you":{"clientId":"x","homeId":"home:x","placeId":"home:x"},'
		+ '"home":{"placeId":"home:x","people":[{"clientId":"y","name":"乙"}],"board":[],"friends":[]}}'
	)
	failed += _check("welcome home people", rc.home_people.size() == 1)
	rc.disconnect_room()
	failed += _check("disconnect clears you", rc.you_dict().is_empty())
	failed += _check("disconnect clears home people", rc.home_people.is_empty())
	failed += _check("disconnect clears home id", rc.home_id().is_empty())
	rc.connected = true
	rc._handle_server_text(
		'{"type":"welcome","you":{"clientId":"x","homeId":"home:x","placeId":"home:x"},'
		+ '"home":{"placeId":"home:x","people":[{"clientId":"y","name":"乙"}],"board":[],"friends":[]}}'
	)
	failed += _check("rewelcome home people", rc.home_people.size() == 1)
	rc._handle_server_text(
		'{"type":"snapshot","you":{"clientId":"x","homeId":"home:x","schoolPlaceId":"school:campus"},'
		+ '"snapshot":{"placeId":"school:campus","people":[],"board":[]}}'
	)
	var school_place: String = rc.place_id
	failed += _check("school place", school_place == "school:campus")
	rc._handle_server_text(
		'{"type":"snapshot","you":{"clientId":"x","homeId":"home:x","schoolPlaceId":"school:campus"},'
		+ '"snapshot":{"placeId":"home:x","people":[{"clientId":"y","name":"乙"}],"board":[]}}'
	)
	failed += _check("home snapshot keeps school place", rc.place_id == "school:campus")
	failed += _check("home people from home snap", rc.home_people.size() == 1)
	failed += _check("home must not open world", SchoolSocial.should_open_world("home:x") == false)
	rc._handle_server_text(
		'{"type":"join","placeId":"home:x","person":{"clientId":"z","name":"丙"}}'
	)
	failed += _check("home join while at school", rc.home_people.size() == 2)
	rc.go_home("y")
	failed += _check("visit enter", rc.last_enter_requested == "home:y")
	rc.send_emote("hug", "y")
	failed += _check("emote payload", rc.last_sent.type == "emote" and rc.last_sent.kind == "hug" and rc.last_sent.targetId == "y")
	var pose_before: Array = rc.home_people.duplicate(true)
	rc.send_emote("kick", "y")
	failed += _check("no optimistic emote pose", rc.home_people.size() == pose_before.size())
	rc.send_home_chat("  客厅  ")
	failed += _check("home chat", rc.last_sent.type == "chat" and rc.last_sent.placeId == "home:x" and rc.last_sent.text == "客厅")
	rc.disconnect_room()
	var saw := {"campus": false, "home": false, "friends": 0, "chats": 0}
	rc.snapshot_ready.connect(func(_you, _people, place_id):
		if place_id == "school:campus":
			saw.campus = true
		if str(place_id).begins_with("home:"):
			saw.home = true
	)
	rc.friends_changed.connect(func(friends):
		saw.friends = friends.size()
	)
	rc.chat_received.connect(func(_line):
		saw.chats += 1
	)
	rc.begin_school_flow()
	rc._handle_server_text(
		'{"type":"welcome","you":{"clientId":"x","placeId":"home:x","x":0,"y":0},'
		+ '"home":{"placeId":"home:x","friends":[{"clientId":"y","name":"乙","online":true}],"incoming":[]}}'
	)
	failed += _check("queued enter", rc.last_enter_requested == "school:campus")
	failed += _check("welcome friends", saw.friends == 1 and rc.is_friend("y"))
	rc.connected = true
	rc._handle_server_text(
		'{"type":"snapshot","you":{"clientId":"x","x":384,"y":348,"facing":"r",'
		+ '"species":"blob","name":"豆豆","colors":{}},'
		+ '"snapshot":{"placeId":"school:campus","people":[],"board":[],"friends":[{"clientId":"y","name":"乙","online":true}]}}'
	)
	failed += _check("campus snapshot", saw.campus)
	rc.leave_school()
	failed += _check("leave away", rc.last_enter_requested == "away")
	failed += _check("still connected", rc.connected == true)
	failed += _check("friends kept", rc.is_friend("y"))
	rc._handle_server_text(
		'{"type":"snapshot","you":{"clientId":"x","placeId":"home:x"},'
		+ '"snapshot":{"placeId":"home:x","people":[],"board":[],"friends":[{"clientId":"y","name":"乙","online":true}]}}'
	)
	failed += _check("home snapshot not school signal", saw.home == false)
	failed += _check("home must not open world", SchoolSocial.should_open_world("home:x") == false)
	rc._handle_server_text(
		'{"type":"snapshot","you":{"clientId":"x","x":40,"y":40,"name":"豆豆"},'
		+ '"snapshot":{"placeId":"school:class-1","people":[],"board":['
		+ '{"id":"old","clientId":"z","name":"丙","text":"先写的","placeId":"school:class-1"}]}}'
	)
	failed += _check("snapshot board", rc.board.size() == 1)
	rc._handle_server_text(
		'{"type":"chat","line":{"id":"n1","clientId":"y","name":"乙","text":"你好","kind":"board","placeId":"school:class-1"}}'
	)
	failed += _check("same-class chat", saw.chats == 1 and rc.board.size() == 2)
	rc._handle_server_text(
		'{"type":"chat","line":{"id":"n2","clientId":"z","name":"丁","text":"隔壁","kind":"board","placeId":"school:class-2"}}'
	)
	failed += _check("other-class dropped", saw.chats == 1 and rc.board.size() == 2)
	rc.send_chat("  黑板字  ")
	failed += _check("send chat payload", rc.last_sent.type == "chat" and rc.last_sent.text == "黑板字" and rc.last_sent.placeId == "school:class-1")
	failed += _check("no optimistic board", rc.board.size() == 2)
	rc.request_friend("y")
	failed += _check("friend request", rc.last_sent.type == "friendRequest" and rc.last_sent.targetId == "y")
	rc._handle_server_text('{"type":"friends","friends":[{"clientId":"y","name":"乙","online":true}],"incoming":[{"clientId":"z"}]}')
	failed += _check("incoming stored unused", rc.incoming.size() == 1)
	rc._handle_server_text('{"type":"notice","text":"已添加 乙"}')
	failed += _check("last notice", rc.last_notice.contains("已添加"))
	rc._handle_server_text('{"type":"error","message":"学校人满了"}')
	failed += _check("error text", rc.status_text.contains("学校人满了"))
	rc.free()
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("room_client: %s" % label)
	return 1
