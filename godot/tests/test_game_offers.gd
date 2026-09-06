extends RefCounted

const GameOffers = preload("res://game/offers.gd")


func run() -> int:
	var failed := 0
	var incoming := {
		"id": "g1",
		"status": "pending",
		"you": "white",
		"deadlineAt": 90000,
		"black": {"name": "甲"},
		"white": {"name": "乙"},
	}
	var offers: Array = GameOffers.offers_from_game(incoming)
	failed += _check("incoming count", offers.size() == 1)
	failed += _check("incoming role", offers[0].role == "incoming")
	failed += _check("incoming title", String(offers[0].title).contains("甲"))
	failed += _check("incoming accept", offers[0].actions[0].label == "好呀")
	failed += _check("incoming decline", offers[0].actions[1].label == "先不要")
	failed += _check("alive", GameOffers.is_offer_alive(offers[0], 1000))
	failed += _check("dead", not GameOffers.is_offer_alive(offers[0], 90000))
	failed += _check("seconds", GameOffers.offer_seconds(offers[0], 30000) == 60)
	var outgoing := GameOffers.offers_from_game({
		"id": "g2",
		"status": "pending",
		"you": "black",
		"deadlineAt": 1,
		"black": {"name": "甲"},
		"white": {"name": "乙"},
	})
	failed += _check("outgoing wait", outgoing[0].role == "outgoing" and outgoing[0].actions.is_empty())
	failed += _check("playing empty", GameOffers.offers_from_game({"status": "playing", "you": "white"}).is_empty())
	var pet_src := FileAccess.get_file_as_string("res://windows/pet_root.gd")
	failed += _check("pet offer copy", pet_src.contains("好呀") and pet_src.contains("先不要"))
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("game_offers: %s" % label)
	return 1
