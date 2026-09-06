class_name GameOffers
extends RefCounted

const GOMOKU_INVITE_MS := 60000


static func offer_progress(offer: Dictionary, now_ms: int) -> float:
	var deadline := int(offer.get("deadlineAt", 0))
	var duration := int(offer.get("durationMs", 0))
	if deadline <= 0 or duration <= 0:
		return 1.0
	return clampf(float(deadline - now_ms) / float(duration), 0.0, 1.0)


static func offer_seconds(offer: Dictionary, now_ms: int) -> int:
	var deadline := int(offer.get("deadlineAt", 0))
	if deadline <= 0:
		return 0
	return maxi(0, int(ceil(float(deadline - now_ms) / 1000.0)))


static func is_offer_alive(offer: Dictionary, now_ms: int) -> bool:
	var deadline := int(offer.get("deadlineAt", 0))
	return deadline <= 0 or now_ms < deadline


static func offers_from_game(game: Dictionary) -> Array:
	if game.is_empty() or String(game.get("status", "")) != "pending":
		return []
	var incoming := String(game.get("you", "")) == "white"
	var black: Dictionary = game.get("black", {}) if game.get("black") is Dictionary else {}
	var white: Dictionary = game.get("white", {}) if game.get("white") is Dictionary else {}
	var game_id := String(game.get("id", ""))
	var deadline := int(game.get("deadlineAt", 0))
	if incoming:
		return [{
			"id": "gomoku:%s:in" % game_id,
			"kind": "gomoku",
			"role": "incoming",
			"title": "%s 来找你玩" % String(black.get("name", "")),
			"body": "一起下五子棋呀",
			"stamp": "五子棋",
			"deadlineAt": deadline,
			"durationMs": GOMOKU_INVITE_MS,
			"gameId": game_id,
			"actions": [
				{"id": "accept", "label": "好呀", "tone": "primary", "accept": true},
				{"id": "decline", "label": "先不要", "tone": "ghost", "accept": false},
			],
		}]
	return [{
		"id": "gomoku:%s:out" % game_id,
		"kind": "gomoku",
		"role": "outgoing",
		"title": "在等 %s" % String(white.get("name", "")),
		"body": "五子棋邀请已送出",
		"stamp": "等待中",
		"deadlineAt": deadline,
		"durationMs": GOMOKU_INVITE_MS,
		"gameId": game_id,
		"actions": [],
	}]


static func collect_offers(game: Dictionary, now_ms: int) -> Array:
	var live: Array = []
	for offer in offers_from_game(game):
		if offer is Dictionary and is_offer_alive(offer, now_ms):
			live.append(offer)
	return live
