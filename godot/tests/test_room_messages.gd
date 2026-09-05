extends RefCounted

const RoomMessages = preload("res://net/room_messages.gd")

func run() -> int:
	var failed := 0
	var hello := _parse_client_roundtrip({
		"type": "hello",
		"clientId": "abc",
		"pet": {"name": "豆豆", "species": "blob", "colors": {"body": "#fff"}},
	})
	failed += _check("hello type", hello.type == "hello" and hello.clientId == "abc")
	var parsed: Dictionary = RoomMessages.parse_server('{"type":"notice","text":"满员"}')
	failed += _check("notice", parsed.ignored == false and parsed.type == "notice")
	var chat: Dictionary = RoomMessages.parse_server(
		'{"type":"chat","line":{"id":"1","name":"豆豆","text":"hi","placeId":"school:class-1"}}'
	)
	failed += _check("parse chat", chat.ignored == false and chat.type == "chat")
	var friends: Dictionary = RoomMessages.parse_server('{"type":"friends","friends":[],"incoming":[]}')
	failed += _check("parse friends", friends.ignored == false and friends.type == "friends")
	var drop2: Dictionary = RoomMessages.parse_server('{"type":"gameState"}')
	failed += _check("drop game", drop2.ignored == true)
	var emote: Dictionary = RoomMessages.parse_server('{"type":"emote","emote":{"kind":"hug"}}')
	failed += _check("parse emote", emote.ignored == false and emote.type == "emote")
	var pose: Dictionary = RoomMessages.parse_server('{"type":"pose","clientId":"a","pose":"drink"}')
	failed += _check("parse pose", pose.ignored == false and pose.type == "pose")
	var dress: Dictionary = RoomMessages.parse_server('{"type":"dress"}')
	failed += _check("drop dress", dress.ignored == true)
	var bad: Dictionary = RoomMessages.parse_server("not-json")
	failed += _check("bad json", bad.ignored == true)
	var welcome: Dictionary = RoomMessages.parse_server('{"type":"welcome","you":{"clientId":"a","placeId":"home:a"}}')
	failed += _check("welcome", welcome.type == "welcome" and welcome.msg.you.clientId == "a")
	return failed

func _parse_client_roundtrip(d: Dictionary) -> Dictionary:
	return JSON.parse_string(RoomMessages.encode(d).get_string_from_utf8())

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("room_messages: %s" % label)
	return 1
