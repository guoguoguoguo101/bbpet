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
	var drop: Dictionary = RoomMessages.parse_server('{"type":"chat","line":{}}')
	failed += _check("drop chat", drop.ignored == true)
	var drop2: Dictionary = RoomMessages.parse_server('{"type":"gameState"}')
	failed += _check("drop game", drop2.ignored == true)
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
