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
	failed += _check("dress API", rc.has_method("send_dress") and rc.has_signal("dress_updated"))
	failed += _check(
		"game API",
		rc.has_method("invite_game")
		and rc.has_method("game_respond")
		and rc.has_method("game_move")
		and rc.has_method("game_resign")
		and rc.has_signal("game_updated")
	)
	if failed:
		rc.free()
		return failed
	rc.connected = true
	rc._handle_server_text(
		'{"type":"welcome","you":{"clientId":"x","homeId":"home:x","placeId":"home:x"},'
		+ '"home":{"placeId":"home:x","people":[{"clientId":"y","name":"乙"}],"board":[],"friends":[]}}'
	)
	failed += _check("welcome home people", rc.home_people.size() == 1)
	var weather_dress := {"gear": ["raincoat"], "fx": ["rain"]}
	rc.send_dress(weather_dress)
	failed += _check(
		"dress payload",
		rc.last_sent.type == "dress"
		and rc.last_sent.dress == weather_dress
		and rc.last_sent.placeId == "home:x"
	)
	rc.last_sent = {"type": "sentinel"}
	rc.send_dress(weather_dress)
	failed += _check("unchanged dress not sent", rc.last_sent.type == "sentinel")
	rc.disconnect_room()
	failed += _check("disconnect clears you", rc.you_dict().is_empty())
	failed += _check("disconnect clears home people", rc.home_people.is_empty())
	failed += _check("disconnect clears home id", rc.home_id().is_empty())
	rc.last_sent = {"type": "sentinel"}
	rc.send_dress({"gear": ["hat"], "fx": []})
	failed += _check("disconnected dress not sent", rc.last_sent.type == "sentinel")
	rc.connected = true
	rc.send_dress({"gear": ["hat"], "fx": []})
	failed += _check("dress without home not sent", rc.last_sent.type == "sentinel")
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
		'{"type":"join","placeId":"home:x","person":{"clientId":"z","name":"丙","dress":{"gear":["umbrella"]}}}'
	)
	failed += _check("home join while at school", rc.home_people.size() == 2)
	failed += _check(
		"home join seeds dress",
		rc.dresses.get("z", {}) == {"gear": ["umbrella"], "fx": []}
	)
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
	var saw := {"campus": false, "home": false, "snapshots": 0, "dress": 0, "friends": 0, "chats": 0}
	rc.snapshot_ready.connect(func(_you, _people, place_id):
		saw.snapshots += 1
		if place_id == "school:campus":
			saw.campus = true
		if str(place_id).begins_with("home:"):
			saw.home = true
	)
	rc.dress_updated.connect(func():
		saw.dress += 1
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
		+ '"species":"blob","name":"豆豆","colors":{},"homeId":"home:x"},'
		+ '"snapshot":{"placeId":"school:campus","people":[{"clientId":"y","name":"乙","dress":{"gear":["scarf"],"fx":["snow"]}}],"board":[],"friends":[{"clientId":"y","name":"乙","online":true}]}}'
	)
	failed += _check("campus snapshot", saw.campus)
	failed += _check(
		"school snapshot seeds dress",
		rc.dresses.get("y", {}) == {"gear": ["scarf"], "fx": ["snow"]}
	)
	rc.leave_school()
	failed += _check("leave away", rc.last_enter_requested == "away")
	failed += _check("still connected", rc.connected == true)
	failed += _check("friends kept", rc.is_friend("y"))
	rc._handle_server_text(
		'{"type":"snapshot","you":{"clientId":"x","placeId":"home:x","homeId":"home:x"},'
		+ '"snapshot":{"placeId":"home:x","people":[{"clientId":"y","name":"乙"}],"board":[],"friends":[{"clientId":"y","name":"乙","online":true}]}}'
	)
	failed += _check("home snapshot not school signal", saw.home == false)
	failed += _check("home must not open world", SchoolSocial.should_open_world("home:x") == false)
	var snapshots_before: int = saw.snapshots
	var place_before: String = rc.place_id
	rc._handle_server_text(
		'{"type":"dress","clientId":"y","dress":{"gear":["raincoat"],"fx":["rain"]}}'
	)
	failed += _check("dress stored", rc.dresses.get("y", {}) == weather_dress)
	rc._handle_server_text('{"type":"dress","clientId":"z","dress":{}}')
	failed += _check(
		"dress missing gear fx",
		rc.dresses.get("z", {}) == {"gear": [], "fx": []}
	)
	failed += _check(
		"dress patches people",
		rc.home_people[0].get("dress", {}) == weather_dress
		and rc._people[0].get("dress", {}) == weather_dress
	)
	failed += _check("dress signal", saw.dress == 2)
	failed += _check(
		"dress keeps navigation",
		rc.place_id == place_before and saw.snapshots == snapshots_before
	)
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
	failed += _check("incoming stored", rc.incoming.size() == 1)
	rc.accept_friend("z")
	failed += _check("friend accept", rc.last_sent.type == "friendAccept" and rc.last_sent.targetId == "z")
	rc.decline_friend("z")
	failed += _check("friend decline", rc.last_sent.type == "friendDecline" and rc.last_sent.targetId == "z")
	var incoming_before: int = rc.incoming.size()
	failed += _check("accept does not local-clear incoming", rc.incoming.size() == incoming_before)
	rc._handle_server_text(
		'{"type":"snapshot","you":{"clientId":"x","x":384,"y":348},'
		+ '"snapshot":{"placeId":"school:campus","people":[],"board":[]}}'
	)
	rc.send_chat("  操场说  ")
	failed += _check(
		"campus chat",
		rc.last_sent.type == "chat" and rc.last_sent.text == "操场说" and rc.last_sent.placeId == "school:campus"
	)
	var chats_before: int = saw.chats
	var board_before: int = rc.board.size()
	rc._handle_server_text(
		'{"type":"chat","line":{"id":"n3","clientId":"y","name":"乙","text":"嗨","kind":"nearby","placeId":"school:campus"}}'
	)
	failed += _check("nearby chat signal", saw.chats == chats_before + 1)
	failed += _check("nearby not board", rc.board.size() == board_before)
	var game_before: Dictionary = rc.game.duplicate(true)
	rc.invite_game("y")
	failed += _check("invite payload", rc.last_sent.type == "inviteGame" and rc.last_sent.targetId == "y")
	failed += _check("invite not optimistic", rc.game == game_before)
	rc._handle_server_text(
		'{"type":"gameState","game":{"id":"g1","status":"pending","you":"black",'
		+ '"black":{"clientId":"x","name":"豆豆"},"white":{"clientId":"y","name":"乙"},'
		+ '"board":[],"turn":1,"deadlineAt":1}}'
	)
	failed += _check("pending stored", rc.game.status == "pending" and rc.game.id == "g1")
	rc.game_respond("g1", true)
	failed += _check("respond payload", rc.last_sent.type == "gameRespond" and rc.last_sent.gameId == "g1" and rc.last_sent.accept == true)
	rc._handle_server_text(
		'{"type":"gameState","game":{"id":"g1","status":"playing","you":"black",'
		+ '"black":{"clientId":"x","name":"豆豆"},"white":{"clientId":"y","name":"乙"},'
		+ '"board":[[0,0],[0,0]],"turn":1.0,"deadlineAt":9.0,"lastMove":null,"winLine":null,"result":null}}'
	)
	failed += _check("playing stored", rc.game.status == "playing" and int(rc.game.turn) == 1)
	rc.game_move("g1", 7, 7)
	failed += _check("move payload", rc.last_sent.type == "gameMove" and rc.last_sent.x == 7 and rc.last_sent.y == 7)
	failed += _check("move not optimistic", rc.game.status == "playing" and rc.game.board[0][0] == 0)
	rc.game_resign("g1")
	failed += _check("resign payload", rc.last_sent.type == "gameResign" and rc.last_sent.gameId == "g1")
	rc._handle_server_text(
		'{"type":"gameState","game":{"id":"g1","status":"ended","you":"black","result":{"winnerId":"y","reason":"resign"},'
		+ '"black":{"clientId":"x","name":"豆豆"},"white":{"clientId":"y","name":"乙"},"board":[],"turn":1,"deadlineAt":0}}'
	)
	failed += _check("ended stored", rc.game.status == "ended")
	rc.invite_game("y")
	failed += _check("ended can invite again", rc.last_sent.type == "inviteGame")
	rc._handle_server_text('{"type":"notice","text":"已添加 乙"}')
	failed += _check("last notice", rc.last_notice.contains("已添加"))
	rc._handle_server_text('{"type":"error","message":"学校人满了"}')
	failed += _check("error text", rc.status_text.contains("学校人满了"))
	rc.disconnect_room()
	failed += _check("disconnect clears dresses", rc.dresses.is_empty())
	failed += _check("disconnect clears game", rc.game.is_empty())
	var room_src := FileAccess.get_file_as_string("res://autoload/room_client.gd")
	failed += _check("welcome uploads last dress", room_src.contains("last_dress"))
	rc.free()
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("room_client: %s" % label)
	return 1
