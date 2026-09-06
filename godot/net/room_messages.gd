class_name RoomMessages
extends RefCounted

const HANDLED := [
	"welcome", "snapshot", "join", "leave", "move", "poses",
	"chat", "friends", "error", "notice", "emote", "pose",
	"dress",
]

static func encode(msg: Dictionary) -> PackedByteArray:
	return JSON.stringify(msg).to_utf8_buffer()

static func parse_server(text: String) -> Dictionary:
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not data.has("type"):
		return { "ignored": true }
	var kind := String(data.type)
	if kind not in HANDLED:
		return { "ignored": true }
	return { "ignored": false, "type": kind, "msg": data }
