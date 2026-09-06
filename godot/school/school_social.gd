class_name SchoolSocial
extends RefCounted

const BOARD_LIMIT := 80
const BOARD_VISIBLE := 7
const BOARD_LEFT := 32.0
const BOARD_TOP := 6.0
const BOARD_HEIGHT := 78.0
const BOARD_SIDE_PAD := 32.0
const NEARBY_RANGE := 140.0
const NEARBY_BUBBLE_MS := 5000


static func sanitize_chat(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\s+")
	return regex.sub(text, " ", true).strip_edges().substr(0, 80)


static func append_board(board: Array, line: Dictionary) -> Array:
	var next: Array = board.duplicate()
	next.append(line.duplicate(true))
	if next.size() > BOARD_LIMIT:
		next = next.slice(next.size() - BOARD_LIMIT)
	return next


static func visible_board(board: Array) -> Array:
	if board.size() <= BOARD_VISIBLE:
		return board.duplicate()
	return board.slice(board.size() - BOARD_VISIBLE)


static func friend_menu_kind(client_id: String, friend_ids: Array) -> String:
	return "already" if friend_ids.has(client_id) else "add"


static func _as_text(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	return value


static func friend_status_text(card: Dictionary) -> String:
	if not card.get("online", false):
		return "离线"
	if not _as_text(card.get("schoolPlaceId")).is_empty():
		return "在学校"
	return "在线"


static func should_open_world(place_id: String) -> bool:
	return place_id.begins_with("school:")


static func is_classroom_place(place: Dictionary) -> bool:
	return String(place.get("kind", "")) == "classroom"


static func is_campus_place(place: Dictionary) -> bool:
	return String(place.get("kind", "")) == "campus"


static func can_chat_here(place: Dictionary) -> bool:
	return is_classroom_place(place) or is_campus_place(place)


static func chat_kind_for(place: Dictionary) -> String:
	return "board" if is_classroom_place(place) else "nearby"


static func nearby_visible(ax: float, ay: float, bx: float, by: float) -> bool:
	var dx := ax - bx
	var dy := ay - by
	return dx * dx + dy * dy <= NEARBY_RANGE * NEARBY_RANGE


static func friend_ids(friends: Array) -> Array:
	var ids: Array = []
	for card in friends:
		if card is Dictionary:
			var id := String(card.get("clientId", ""))
			if not id.is_empty():
				ids.append(id)
	return ids
