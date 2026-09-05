extends Node

signal connect_failed(reason: String)
signal status(text: String)
signal snapshot_ready(you: Dictionary, people: Array, place_id: String)
signal others_updated(people: Array)
signal disconnected

const RoomMessages = preload("res://net/room_messages.gd")
const SCHOOL_CAMPUS := "school:campus"

var connected := false
var status_text := ""
var pending_enter := ""
var last_enter_requested := ""

var _peer: WebSocketPeer
var _was_open := false
var _connecting := false
var _intentional_disconnect := false
var _you: Dictionary = {}
var _people: Array = []
var _place_id := ""
var _has_last_move := false
var _last_move := Vector2.ZERO
var _last_facing := ""


func _process(_delta: float) -> void:
	if _peer == null:
		return
	_peer.poll()
	var state := _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			_connecting = false
			connected = true
			_send({
				"type": "hello",
				"clientId": _app_state().state.clientId,
				"pet": _app_state().pet_for_hello(),
			})
			if not pending_enter.is_empty():
				enter_place(pending_enter)
		while _peer.get_available_packet_count() > 0:
			_handle_server_text(_peer.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		_handle_closed()


func connect_room(url: String) -> void:
	disconnect_room()
	if url.is_empty():
		status_text = "连不上学校"
		connect_failed.emit(status_text)
		return
	_peer = WebSocketPeer.new()
	_intentional_disconnect = false
	_connecting = true
	var result := _peer.connect_to_url(url)
	if result != OK:
		_peer = null
		_connecting = false
		status_text = "连不上学校"
		connect_failed.emit(status_text)


func disconnect_room() -> void:
	_intentional_disconnect = true
	if _peer != null:
		var state := _peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN or state == WebSocketPeer.STATE_CONNECTING:
			_peer.close()
	_peer = null
	connected = false
	_connecting = false
	_was_open = false
	pending_enter = ""
	_place_id = ""
	_people.clear()
	_has_last_move = false


func begin_school_flow() -> void:
	pending_enter = SCHOOL_CAMPUS


func send_move(x: float, y: float, facing: String) -> void:
	if not connected:
		return
	var position := Vector2(x, y)
	if _has_last_move and position == _last_move and facing == _last_facing:
		return
	_has_last_move = true
	_last_move = position
	_last_facing = facing
	_send({"type": "move", "x": x, "y": y, "facing": facing})


func enter_place(place_id: String) -> void:
	last_enter_requested = place_id
	if not connected:
		return
	_send({"type": "enterPlace", "placeId": place_id})


func _handle_server_text(text: String) -> void:
	var parsed: Dictionary = RoomMessages.parse_server(text)
	if parsed.get("ignored", true):
		return
	var kind: String = parsed.type
	var msg: Dictionary = parsed.msg
	match kind:
		"welcome":
			_you = msg.get("you", {}).duplicate(true)
			if not pending_enter.is_empty():
				enter_place(pending_enter)
		"snapshot":
			var snapshot: Dictionary = msg.get("snapshot", {})
			var place_id := String(snapshot.get("placeId", ""))
			var people: Array = snapshot.get("people", [])
			_you = msg.get("you", {}).duplicate(true)
			_place_id = place_id
			_people = _without_self(people)
			if pending_enter == place_id:
				pending_enter = ""
			snapshot_ready.emit(_you.duplicate(true), _people.duplicate(true), place_id)
		"join":
			if String(msg.get("placeId", "")) == _place_id:
				_upsert_person(msg.get("person", {}))
		"leave":
			if String(msg.get("placeId", "")) == _place_id:
				_remove_person(String(msg.get("clientId", "")))
		"move":
			_apply_move(msg)
		"poses":
			if String(msg.get("placeId", "")) == _place_id:
				var items: Array = msg.get("items", [])
				for item in items:
					if item is Dictionary:
						_apply_pose_item(item)
				others_updated.emit(_people.duplicate(true))
		"error", "notice":
			var raw := String(msg.get("message", msg.get("text", "")))
			status_text = raw.replace("\r", " ").replace("\n", " ").substr(0, 80)
			status.emit(status_text)


func _handle_closed() -> void:
	var opened := _was_open
	var was_connecting := _connecting
	_peer = null
	connected = false
	_connecting = false
	_was_open = false
	if _intentional_disconnect:
		return
	if opened:
		status_text = "已断开"
		status.emit(status_text)
		disconnected.emit()
	elif was_connecting:
		status_text = "连不上学校"
		connect_failed.emit(status_text)


func _send(message: Dictionary) -> void:
	if _peer == null or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_peer.send_text(JSON.stringify(message))


func _without_self(people: Array) -> Array:
	var result: Array = []
	var self_id := String(_you.get("clientId", ""))
	for person in people:
		if person is Dictionary and String(person.get("clientId", "")) != self_id:
			result.append(person.duplicate(true))
	return result


func _upsert_person(person: Dictionary) -> void:
	var client_id := String(person.get("clientId", ""))
	if client_id.is_empty() or client_id == String(_you.get("clientId", "")):
		return
	for index in _people.size():
		if String(_people[index].get("clientId", "")) == client_id:
			_people[index] = person.duplicate(true)
			others_updated.emit(_people.duplicate(true))
			return
	_people.append(person.duplicate(true))
	others_updated.emit(_people.duplicate(true))


func _remove_person(client_id: String) -> void:
	for index in range(_people.size() - 1, -1, -1):
		if String(_people[index].get("clientId", "")) == client_id:
			_people.remove_at(index)
	others_updated.emit(_people.duplicate(true))


func _apply_move(msg: Dictionary) -> void:
	var client_id := String(msg.get("clientId", ""))
	if client_id == String(_you.get("clientId", "")):
		return
	for index in _people.size():
		var person: Dictionary = _people[index]
		if String(person.get("clientId", "")) == client_id:
			person.x = msg.get("x", person.get("x", 0.0))
			person.y = msg.get("y", person.get("y", 0.0))
			person.facing = msg.get("facing", person.get("facing", "r"))
			_people[index] = person
			others_updated.emit(_people.duplicate(true))
			return


func _apply_pose_item(item: Dictionary) -> void:
	var client_id := String(item.get("id", ""))
	if client_id == String(_you.get("clientId", "")):
		return
	for index in _people.size():
		var person: Dictionary = _people[index]
		if String(person.get("clientId", "")) == client_id:
			person.x = item.get("x", person.get("x", 0.0))
			person.y = item.get("y", person.get("y", 0.0))
			person.facing = item.get("facing", person.get("facing", "r"))
			_people[index] = person
			return


func _app_state() -> Node:
	return get_node("/root/AppState")
