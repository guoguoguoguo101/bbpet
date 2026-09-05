extends Node

signal connect_failed(reason: String)
signal status(text: String)
signal snapshot_ready(you: Dictionary, people: Array, place_id: String)
signal others_updated(people: Array)
signal disconnected
signal chat_received(line: Dictionary)
signal friends_changed(friends: Array)

const RoomMessages = preload("res://net/room_messages.gd")
const SchoolSocial = preload("res://school/school_social.gd")
const SchoolLogic = preload("res://school/school_logic.gd")
const SCHOOL_CAMPUS := "school:campus"

var connected := false
var status_text := ""
var pending_enter := ""
var last_enter_requested := ""
var friends: Array = []
var incoming: Array = []
var board: Array = []
var last_notice := ""
var last_sent: Dictionary = {}
var place_id := ""
var connecting := false
var _url := ""

var _peer: WebSocketPeer
var _was_open := false
var _intentional_disconnect := false
var _you: Dictionary = {}
var _people: Array = []
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
			connecting = false
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
	if connected and _url == url:
		return
	disconnect_room()
	if url.is_empty():
		status_text = "连不上学校"
		connect_failed.emit(status_text)
		return
	_peer = WebSocketPeer.new()
	_intentional_disconnect = false
	connecting = true
	_url = url
	var result := _peer.connect_to_url(url)
	if result != OK:
		_peer = null
		connecting = false
		_url = ""
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
	connecting = false
	_was_open = false
	pending_enter = ""
	place_id = ""
	_people.clear()
	board.clear()
	_url = ""
	_has_last_move = false


func begin_school_flow() -> void:
	pending_enter = SCHOOL_CAMPUS


func send_chat(text: String) -> void:
	var cleaned := SchoolSocial.sanitize_chat(text)
	if cleaned.is_empty() or not connected:
		return
	var place: Dictionary = SchoolLogic.PLACES.get(place_id, {})
	if not SchoolSocial.is_classroom_place(place):
		return
	_send({"type": "chat", "text": cleaned, "placeId": place_id})


func request_friend(target_id: String) -> void:
	if not connected or target_id.is_empty():
		return
	_send({"type": "friendRequest", "targetId": target_id})


func leave_school() -> void:
	if not connected:
		return
	enter_place("away")


func is_friend(client_id: String) -> bool:
	return SchoolSocial.friend_ids(friends).has(client_id)


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
			_apply_friends(msg.get("home", {}))
			if not pending_enter.is_empty():
				enter_place(pending_enter)
		"snapshot":
			var snapshot: Dictionary = msg.get("snapshot", {})
			var people: Array = snapshot.get("people", [])
			_you = msg.get("you", {}).duplicate(true)
			place_id = String(snapshot.get("placeId", ""))
			_people = _without_self(people)
			_apply_friends(snapshot)
			_apply_board(snapshot)
			if pending_enter == place_id:
				pending_enter = ""
			snapshot_ready.emit(_you.duplicate(true), _people.duplicate(true), place_id)
		"join":
			if String(msg.get("placeId", "")) == place_id:
				_upsert_person(msg.get("person", {}))
		"leave":
			if String(msg.get("placeId", "")) == place_id:
				_remove_person(String(msg.get("clientId", "")))
		"move":
			_apply_move(msg)
		"poses":
			if String(msg.get("placeId", "")) == place_id:
				var items: Array = msg.get("items", [])
				for item in items:
					if item is Dictionary:
						_apply_pose_item(item)
				others_updated.emit(_people.duplicate(true))
		"friends":
			_apply_friends(msg)
		"chat":
			_apply_chat(msg.get("line", {}))
		"error", "notice":
			var raw := String(msg.get("message", msg.get("text", "")))
			status_text = raw.replace("\r", " ").replace("\n", " ").substr(0, 80)
			last_notice = status_text
			status.emit(status_text)


func _handle_closed() -> void:
	var opened := _was_open
	var was_connecting := connecting
	_peer = null
	connected = false
	connecting = false
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
	last_sent = message.duplicate(true)
	if _peer == null or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_peer.send_text(JSON.stringify(message))


func _apply_friends(source: Dictionary) -> void:
	var next: Array = source.get("friends", [])
	friends = []
	for card in next:
		if card is Dictionary:
			friends.append(card.duplicate(true))
	incoming = []
	var raw_in: Array = source.get("incoming", [])
	for card in raw_in:
		if card is Dictionary:
			incoming.append(card.duplicate(true))
	friends_changed.emit(friends.duplicate(true))


func _apply_board(snapshot: Dictionary) -> void:
	board = []
	var place: Dictionary = SchoolLogic.PLACES.get(place_id, {})
	if not SchoolSocial.is_classroom_place(place):
		return
	var raw: Array = snapshot.get("board", [])
	for line in raw:
		if line is Dictionary:
			board = SchoolSocial.append_board(board, line)


func _apply_chat(line: Dictionary) -> void:
	if line.is_empty():
		return
	if String(line.get("placeId", "")) != place_id:
		return
	var place: Dictionary = SchoolLogic.PLACES.get(place_id, {})
	if not SchoolSocial.is_classroom_place(place):
		return
	board = SchoolSocial.append_board(board, line)
	chat_received.emit(line.duplicate(true))


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
