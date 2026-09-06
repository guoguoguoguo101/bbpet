class_name GameView
extends RefCounted

const POINTS := 15
const CELL := 28
const PAD := 22
const STONE := 22
const BOARD := PAD * 2 + CELL * 14


static func is_game_busy(game: Dictionary) -> bool:
	var status := String(game.get("status", ""))
	return status == "pending" or status == "playing"


static func is_incoming_invite(game: Dictionary) -> bool:
	return String(game.get("status", "")) == "pending" and String(game.get("you", "")) == "white"


static func can_invite_friend(game: Dictionary, my_id: String, card: Dictionary) -> bool:
	var client_id := String(card.get("clientId", ""))
	if client_id.is_empty() or client_id == my_id:
		return false
	if not bool(card.get("online", false)):
		return false
	if bool(card.get("inGame", false)):
		return false
	return not is_game_busy(game)


static func my_turn(game: Dictionary) -> bool:
	var you := String(game.get("you", ""))
	var turn := int(game.get("turn", 0))
	return (you == "black" and turn == 1) or (you == "white" and turn == 2)


static func seconds_left(deadline_at: int, now_ms: int) -> int:
	return maxi(0, int(ceil(float(deadline_at - now_ms) / 1000.0)))


static func point_from_click(px: float, py: float) -> Vector2i:
	var x := int(round((px - PAD) / float(CELL)))
	var y := int(round((py - PAD) / float(CELL)))
	if x < 0 or y < 0 or x >= POINTS or y >= POINTS:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


static func result_copy(result: Dictionary, client_id: String) -> String:
	if result.is_empty():
		return ""
	var winner := ""
	if result.get("winnerId") != null:
		winner = String(result.get("winnerId", ""))
	var mine := not winner.is_empty() and winner == client_id
	var reason := String(result.get("reason", ""))
	match reason:
		"five":
			return "五连胜" if mine else "对方五连"
		"draw":
			return "满盘平局"
		"resign":
			return "对方认输" if mine else "你认输了"
		"timeout":
			return "对方超时" if mine else "你超时了"
		"disconnect":
			return "对方断线" if mine else "你断线了"
		_:
			return ""


static func opponent_name(game: Dictionary) -> String:
	var you := String(game.get("you", ""))
	var other: Dictionary = game.get("white", {}) if you == "black" else game.get("black", {})
	if not other is Dictionary:
		return ""
	return String(other.get("name", ""))


static func normalize(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var data: Dictionary = raw
	if String(data.get("id", "")).is_empty():
		return {}
	var board: Array = []
	var raw_board: Variant = data.get("board", [])
	if raw_board is Array:
		for row in raw_board:
			var next_row: Array = []
			if row is Array:
				for cell in row:
					next_row.append(int(cell))
			board.append(next_row)
	var last_move: Dictionary = {}
	var last_raw: Variant = data.get("lastMove", null)
	if last_raw is Dictionary:
		last_move = {"x": int(last_raw.get("x", 0)), "y": int(last_raw.get("y", 0))}
	var win_line: Array = []
	var win_raw: Variant = data.get("winLine", null)
	if win_raw is Array:
		for point in win_raw:
			if point is Dictionary:
				win_line.append({"x": int(point.get("x", 0)), "y": int(point.get("y", 0))})
	var result: Dictionary = {}
	var result_raw: Variant = data.get("result", null)
	if result_raw is Dictionary:
		result = {
			"winnerId": result_raw.get("winnerId"),
			"reason": String(result_raw.get("reason", "")),
		}
	var black: Dictionary = {}
	if data.get("black") is Dictionary:
		black = data.black.duplicate(true)
	var white: Dictionary = {}
	if data.get("white") is Dictionary:
		white = data.white.duplicate(true)
	return {
		"id": String(data.get("id", "")),
		"status": String(data.get("status", "")),
		"black": black,
		"white": white,
		"board": board,
		"turn": int(data.get("turn", 1)),
		"deadlineAt": int(data.get("deadlineAt", 0)),
		"lastMove": last_move,
		"winLine": win_line,
		"result": result,
		"you": String(data.get("you", "")),
	}
