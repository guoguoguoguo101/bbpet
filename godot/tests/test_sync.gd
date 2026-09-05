extends RefCounted

const PetSync = preload("res://school/sync.gd")

func run() -> int:
	var failed := 0
	var r: Vector2 = PetSync.round_pose(1.26, 2.24)
	failed += _check("round", is_equal_approx(r.x, 1.3) and is_equal_approx(r.y, 2.2))
	var neg: Vector2 = PetSync.round_pose(-1.25, 1.25)
	failed += _check("round negative tie", is_equal_approx(neg.x, -1.2) and is_equal_approx(neg.y, 1.3))
	var mid: Dictionary = PetSync.interpolate_pose(0.0, 0.0, 10.0, 0.0, 0.0, 70.0, 140.0)
	failed += _check("lerp t", is_equal_approx(mid.t, 0.5) and is_equal_approx(mid.x, 5.0))
	failed += _check("facing early", PetSync.pose_facing("l", "r", 0.2) == "l")
	failed += _check("facing late", PetSync.pose_facing("l", "r", 0.4) == "r")
	var prev := [{"clientId": "a", "x": 1.0, "y": 2.0, "facing": "l", "name": "old"}]
	var incoming := [{"clientId": "a", "x": 9.0, "y": 9.0, "facing": "r", "name": "new"}]
	var kept: Array = PetSync.keep_visual_people(prev, incoming)
	failed += _check("keep xy", kept[0].x == 1.0 and kept[0].y == 2.0 and kept[0].facing == "l")
	failed += _check("keep name", kept[0].name == "new")
	var people := [{"clientId": "a", "x": 0.0, "y": 0.0, "facing": "l"}, {"clientId": "me", "x": 3.0, "y": 3.0, "facing": "r"}]
	var items := [{"id": "a", "x": 5.0, "y": 6.0, "facing": "r"}, {"id": "me", "x": 99.0, "y": 99.0, "facing": "l"}]
	var after: Array = PetSync.apply_pose_items(people, items, "me")
	failed += _check("apply other", after[0].x == 5.0 and after[0].facing == "r")
	failed += _check("skip self", after[1].x == 3.0)
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("sync: %s" % label)
	return 1
