extends RefCounted

const GameView = preload("res://game/game_view.gd")


func run() -> int:
	var failed := 0
	failed += _check("idle not busy", not GameView.is_game_busy({}))
	failed += _check("pending busy", GameView.is_game_busy({"status": "pending"}))
	failed += _check("playing busy", GameView.is_game_busy({"status": "playing"}))
	failed += _check("ended not busy", not GameView.is_game_busy({"status": "ended"}))
	failed += _check(
		"incoming white pending",
		GameView.is_incoming_invite({"status": "pending", "you": "white"})
	)
	failed += _check(
		"outgoing not incoming",
		not GameView.is_incoming_invite({"status": "pending", "you": "black"})
	)
	failed += _check(
		"playing not invite",
		not GameView.is_incoming_invite({"status": "playing", "you": "white"})
	)
	var card := {"clientId": "b", "online": true, "inGame": false}
	failed += _check("can invite idle", GameView.can_invite_friend({}, "a", card))
	failed += _check("busy blocks invite", not GameView.can_invite_friend({"status": "playing"}, "a", card))
	failed += _check("offline blocks", not GameView.can_invite_friend({}, "a", {"clientId": "b", "online": false, "inGame": false}))
	failed += _check("inGame blocks", not GameView.can_invite_friend({}, "a", {"clientId": "b", "online": true, "inGame": true}))
	failed += _check("self blocks", not GameView.can_invite_friend({}, "a", {"clientId": "a", "online": true, "inGame": false}))
	failed += _check("black turn", GameView.my_turn({"you": "black", "turn": 1}))
	failed += _check("white wait", not GameView.my_turn({"you": "white", "turn": 1}))
	failed += _check("click center", GameView.point_from_click(22.0, 22.0) == Vector2i(0, 0))
	failed += _check("click last", GameView.point_from_click(22.0 + 28.0 * 14.0, 22.0 + 28.0 * 14.0) == Vector2i(14, 14))
	failed += _check("click oob", GameView.point_from_click(-8.0, 22.0) == Vector2i(-1, -1))
	failed += _check("seconds floor", GameView.seconds_left(1500, 0) == 2)
	failed += _check("seconds zero", GameView.seconds_left(100, 1000) == 0)
	failed += _check(
		"five win",
		GameView.result_copy({"winnerId": "a", "reason": "five"}, "a") == "五连胜"
	)
	failed += _check(
		"five lose",
		GameView.result_copy({"winnerId": "b", "reason": "five"}, "a") == "对方五连"
	)
	failed += _check("draw", GameView.result_copy({"winnerId": null, "reason": "draw"}, "a") == "满盘平局")
	var parsed: Dictionary = GameView.normalize({
		"id": "g1",
		"status": "playing",
		"turn": 1.0,
		"deadlineAt": 90.0,
		"you": "black",
		"board": [[0.0, 1.0], [2.0, 0.0]],
		"lastMove": {"x": 1.0, "y": 0.0},
		"winLine": [{"x": 0.0, "y": 0.0}],
		"black": {"clientId": "a", "name": "甲"},
		"white": {"clientId": "b", "name": "乙"},
	})
	failed += _check("normalize turn", parsed.turn == 1)
	failed += _check("normalize board", parsed.board[0][1] == 1)
	failed += _check("normalize empty", GameView.normalize(null).is_empty())
	failed += _check("board size const", GameView.BOARD == 436)
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("game_view: %s" % label)
	return 1
