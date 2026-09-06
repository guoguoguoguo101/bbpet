extends Node

signal connect_failed(reason: String)
signal status(text: String)
signal snapshot_ready(you: Dictionary, people: Array, place_id: String)
signal others_updated(people: Array)
signal disconnected
signal chat_received(line: Dictionary)
signal friends_changed(friends: Array)
signal home_updated
signal emote_received(emote: Dictionary)
signal dress_updated
signal game_updated(game: Dictionary)

const RoomMessages = preload("res://net/room_messages.gd")
const SchoolSocial = preload("res://school/school_social.gd")
const SchoolLogic = preload("res://school/school_logic.gd")
const HomeLogic = preload("res://home/home_logic.gd")
const GameView = preload("res://game/game_view.gd")
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
var home_people: Array = []
var home_board: Array = []
var last_emote: Dictionary = {}
var home_poses: Dictionary = {}
var dresses: Dictionary = {}
var connecting := false
var game: Dictionary = {}
var _url := ""

var _peer: WebSocketPeer
var _was_open := false
var _intentional_disconnect := false
var _you: Dictionary = {}
var _people: Array = []
var _has_last_move := false
var _last_move := Vector2.ZERO
var _last_facing := ""
var _has_uploaded_dress := false
var _last_uploaded_dress: Dictionary = {}


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
	home_people.clear()
	home_board.clear()
	last_emote.clear()
	home_poses.clear()
	dresses.clear()
	_you.clear()
	_url = ""
	_has_last_move = false
	_has_uploaded_dress = false
	_last_uploaded_dress.clear()
	game.clear()
	game_updated.emit({})
	home_updated.emit()


func begin_school_flow() -> void:
	pending_enter = SCHOOL_CAMPUS


func send_chat(text: String) -> void:
	var cleaned := SchoolSocial.sanitize_chat(text)
	if cleaned.is_empty() or not connected:
		return
	var place: Dictionary = SchoolLogic.PLACES.get(place_id, {})
	if not SchoolSocial.can_chat_here(place):
		return
	_send({"type": "chat", "text": cleaned, "placeId": place_id})


func request_friend(target_id: String) -> void:
	if not connected or target_id.is_empty():
		return
	_send({"type": "friendRequest", "targetId": target_id})


func accept_friend(target_id: String) -> void:
	if not connected or target_id.is_empty():
		return
	_send({"type": "friendAccept", "targetId": target_id})


func decline_friend(target_id: String) -> void:
	if not connected or target_id.is_empty():
		return
	_send({"type": "friendDecline", "targetId": target_id})


func invite_game(target_id: String) -> void:
	if not connected or target_id.is_empty():
		return
	_send({"type": "inviteGame", "targetId": target_id})


func game_respond(game_id: String, accept: bool) -> void:
	if not connected or game_id.is_empty():
		return
	_send({"type": "gameRespond", "gameId": game_id, "accept": accept})


func game_move(game_id: String, x: int, y: int) -> void:
	if not connected or game_id.is_empty():
		return
	_send({"type": "gameMove", "gameId": game_id, "x": x, "y": y})


func game_resign(game_id: String) -> void:
	if not connected or game_id.is_empty():
		return
	_send({"type": "gameResign", "gameId": game_id})


func leave_school() -> void:
	if not connected:
		return
	enter_place("away")


func go_home(owner_id: String) -> void:
	if owner_id.is_empty():
		return
	enter_place(HomeLogic.home_place_id(owner_id))


func send_home_chat(text: String) -> void:
	var cleaned := SchoolSocial.sanitize_chat(text)
	if cleaned.is_empty() or not connected or home_id().is_empty():
		return
	_send({"type": "chat", "text": cleaned, "placeId": home_id()})


func send_emote(kind: String, target_id: String) -> void:
	if not connected or kind.is_empty() or target_id.is_empty() or home_id().is_empty():
		return
	_send({"type": "emote", "kind": kind, "targetId": target_id, "placeId": home_id()})


func send_dress(dress: Dictionary) -> void:
	if not connected or home_id().is_empty():
		return
	if _has_uploaded_dress and dress == _last_uploaded_dress:
		return
	_has_uploaded_dress = true
	_last_uploaded_dress = dress.duplicate(true)
	_send({"type": "dress", "dress": dress, "placeId": home_id()})


func send_pose(pose: String, look_x: int = 0, look_y: int = 0) -> void:
	if not connected or home_id().is_empty() or pose.is_empty() or pose == "blink":
		return
	_send({
		"type": "pose",
		"pose": pose,
		"lookX": look_x,
		"lookY": look_y,
		"placeId": home_id(),
	})


func you_dict() -> Dictionary:
	return _you.duplicate(true)


func home_id() -> String:
	return String(_you.get("homeId", ""))


func my_id() -> String:
	return String(_you.get("clientId", _app_state().state.clientId))


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
			_apply_home_bucket(msg.get("home", {}))
			_apply_game(msg.get("game", null))
			home_updated.emit()
			_upload_local_dress()
			if not pending_enter.is_empty():
				enter_place(pending_enter)
		"snapshot":
			var snapshot: Dictionary = msg.get("snapshot", {})
			_you = msg.get("you", {}).duplicate(true)
			var snap_id := String(snapshot.get("placeId", ""))
			_apply_friends(snapshot)
			if snap_id.begins_with("home:"):
				_apply_home_bucket(snapshot)
				if pending_enter == snap_id:
					pending_enter = ""
				home_updated.emit()
			else:
				place_id = snap_id
				_people = _without_self(snapshot.get("people", []))
				_apply_board(snapshot)
				if pending_enter == place_id:
					pending_enter = ""
				snapshot_ready.emit(_you.duplicate(true), _people.duplicate(true), place_id)
		"join":
			var join_place := String(msg.get("placeId", ""))
			if join_place == place_id:
				_upsert_person(msg.get("person", {}))
			if join_place == home_id() and not home_id().is_empty():
				_upsert_home_person(msg.get("person", {}))
				home_updated.emit()
		"leave":
			var leave_place := String(msg.get("placeId", ""))
			if leave_place == place_id:
				_remove_person(String(msg.get("clientId", "")))
			if leave_place == home_id() and not home_id().is_empty():
				_remove_home_person(String(msg.get("clientId", "")))
				home_updated.emit()
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
			_apply_incoming_chat(msg.get("line", {}))
		"emote":
			var emote: Variant = msg.get("emote", {})
			if emote is Dictionary:
				last_emote = emote.duplicate(true)
			else:
				last_emote = {}
			emote_received.emit(last_emote.duplicate(true))
			home_updated.emit()
		"pose":
			_apply_home_pose(msg)
		"dress":
			_apply_dress(msg)
		"gameState":
			_apply_game(msg.get("game", null))
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


func _apply_home_bucket(source: Dictionary) -> void:
	home_people = _without_self(source.get("people", []))
	home_board = []
	var raw: Array = source.get("board", [])
	for line in raw:
		if line is Dictionary:
			home_board = SchoolSocial.append_board(home_board, line)


func _apply_incoming_chat(line: Dictionary) -> void:
	if line.is_empty():
		return
	var line_place := String(line.get("placeId", ""))
	var hid := home_id()
	if not hid.is_empty() and line_place == hid:
		home_board = SchoolSocial.append_board(home_board, line)
		home_updated.emit()
		return
	_apply_chat(line)


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
	if not SchoolSocial.can_chat_here(place):
		return
	if SchoolSocial.is_classroom_place(place):
		board = SchoolSocial.append_board(board, line)
	chat_received.emit(line.duplicate(true))


func _without_self(people: Array) -> Array:
	var result: Array = []
	var self_id := String(_you.get("clientId", ""))
	for person in people:
		if person is Dictionary and String(person.get("clientId", "")) != self_id:
			var copy: Dictionary = person.duplicate(true)
			_seed_person_dress(copy)
			result.append(copy)
	return result


func _upsert_person(person: Dictionary) -> void:
	var client_id := String(person.get("clientId", ""))
	if client_id.is_empty() or client_id == String(_you.get("clientId", "")):
		return
	_seed_person_dress(person)
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


func _upsert_home_person(person: Dictionary) -> void:
	var client_id := String(person.get("clientId", ""))
	if client_id.is_empty() or client_id == String(_you.get("clientId", "")):
		return
	_seed_person_dress(person)
	for index in home_people.size():
		if String(home_people[index].get("clientId", "")) == client_id:
			home_people[index] = person.duplicate(true)
			return
	home_people.append(person.duplicate(true))


func _remove_home_person(client_id: String) -> void:
	for index in range(home_people.size() - 1, -1, -1):
		if String(home_people[index].get("clientId", "")) == client_id:
			home_people.remove_at(index)


func _apply_home_pose(msg: Dictionary) -> void:
	var client_id := String(msg.get("clientId", ""))
	if client_id.is_empty():
		return
	var pose_place := String(msg.get("placeId", ""))
	if pose_place.begins_with("school:"):
		return
	var pose := String(msg.get("pose", "idle"))
	home_poses[client_id] = pose
	for index in home_people.size():
		var person: Dictionary = home_people[index]
		if String(person.get("clientId", "")) == client_id:
			person.pose = pose
			person.lookX = msg.get("lookX", person.get("lookX", 0.0))
			person.lookY = msg.get("lookY", person.get("lookY", 0.0))
			home_people[index] = person
			break
	home_updated.emit()


func _normalized_dress(raw: Dictionary) -> Dictionary:
	var gear: Variant = raw.get("gear", [])
	var fx: Variant = raw.get("fx", [])
	return {
		"gear": gear.duplicate() if gear is Array else [],
		"fx": fx.duplicate() if fx is Array else [],
	}


func _seed_person_dress(person: Dictionary) -> void:
	var client_id := String(person.get("clientId", ""))
	if client_id.is_empty() or not person.has("dress"):
		return
	var raw: Variant = person.dress
	if raw is Dictionary:
		dresses[client_id] = _normalized_dress(raw)


func _upload_local_dress() -> void:
	var weather := _named_autoload("WeatherClient")
	if weather == null:
		return
	var dress: Variant = weather.get("last_dress")
	if dress is Dictionary and not dress.is_empty():
		send_dress(dress)


func _named_autoload(node_name: String) -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/%s" % node_name)
	return null


func _apply_dress(msg: Dictionary) -> void:
	var client_id := String(msg.get("clientId", ""))
	var raw_dress: Variant = msg.get("dress", {})
	if client_id.is_empty() or not raw_dress is Dictionary:
		return
	var next_dress: Dictionary = _normalized_dress(raw_dress)
	dresses[client_id] = next_dress
	for index in home_people.size():
		var home_person: Dictionary = home_people[index]
		if String(home_person.get("clientId", "")) == client_id:
			home_person.dress = next_dress.duplicate(true)
			home_people[index] = home_person
	for index in _people.size():
		var school_person: Dictionary = _people[index]
		if String(school_person.get("clientId", "")) == client_id:
			school_person.dress = next_dress.duplicate(true)
			_people[index] = school_person
	dress_updated.emit()


func _apply_game(raw: Variant) -> void:
	game = GameView.normalize(raw)
	game_updated.emit(game.duplicate(true))


func _app_state() -> Node:
	return get_node("/root/AppState")
