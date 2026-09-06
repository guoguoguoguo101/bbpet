extends RefCounted

const SchoolLogic = preload("res://school/school_logic.gd")

func run() -> int:
	var failed := 0
	failed += _check("tile 32", SchoolLogic.TILE == 32)
	failed += _check("pet size 32", SchoolLogic.PET_SIZE == 32)
	failed += _check("speed 110", SchoolLogic.MOVE_SPEED == 110)
	failed += _check("url", SchoolLogic.DEFAULT_ROOM_URL == "ws://127.0.0.1:18765")
	failed += _check("port from url", SchoolLogic.room_listen_port("ws://192.168.1.8:19001") == 19001)
	failed += _check("port default", SchoolLogic.room_listen_port("ws://127.0.0.1") == 18765)
	var campus: Dictionary = SchoolLogic.PLACES["school:campus"]
	failed += _check("campus title", campus.title == "学校操场")
	var spawn: Dictionary = SchoolLogic.default_spawn("school:campus")
	failed += _check("campus spawn x", is_equal_approx(spawn.x, 384.0))
	failed += _check("campus spawn y", is_equal_approx(spawn.y, 348.0))
	var from_class: Dictionary = SchoolLogic.spawn_after_enter("school:class-1", "school:campus")
	var door_a: Dictionary = SchoolLogic.spawn_on_tile(campus, "a", SchoolLogic.TILE - 6)
	failed += _check("back to door a x", is_equal_approx(from_class.x, door_a.x))
	failed += _check("back to door a y", is_equal_approx(from_class.y, door_a.y))
	var into_1: Dictionary = SchoolLogic.spawn_after_enter("school:campus", "school:class-1")
	var g: Dictionary = SchoolLogic.default_spawn("school:class-1")
	failed += _check("class spawn", is_equal_approx(into_1.x, g.x) and is_equal_approx(into_1.y, g.y))
	var grass_x := 384.0
	var grass_y := 220.0
	failed += _check("can walk grass", SchoolLogic.can_walk(campus, grass_x, grass_y))
	var into_wall: Dictionary = SchoolLogic.clamp_move(campus, grass_x, grass_y, grass_x, -40.0)
	failed += _check("stop at wall y", into_wall.y >= grass_y or SchoolLogic.can_walk(campus, into_wall.x, into_wall.y))
	failed += _check("not inside wall", SchoolLogic.can_walk(campus, into_wall.x, into_wall.y))
	var feet_on_a: Dictionary = SchoolLogic.spawn_on_tile(campus, "a", 0)
	var trig: Variant = SchoolLogic.trigger_at(campus, feet_on_a.x, feet_on_a.y)
	failed += _check("door a", trig != null and trig.kind == "classroom" and trig.place_id == "school:class-1")
	var class1: Dictionary = SchoolLogic.PLACES["school:class-1"]
	var feet_g: Dictionary = SchoolLogic.spawn_on_tile(class1, "g", 0)
	var trig_g: Variant = SchoolLogic.trigger_at(class1, feet_g.x, feet_g.y)
	failed += _check("door g", trig_g != null and trig_g.kind == "campus")
	var feet_x: Dictionary = SchoolLogic.spawn_on_tile(campus, "x", 0)
	var trig_x: Variant = SchoolLogic.trigger_at(campus, feet_x.x, feet_x.y)
	failed += _check("exit x", trig_x != null and trig_x.kind == "exit")
	failed += _check("class-2", SchoolLogic.trigger_at(campus, SchoolLogic.spawn_on_tile(campus, "b", 0).x, SchoolLogic.spawn_on_tile(campus, "b", 0).y).place_id == "school:class-2")
	failed += _check("class-3", SchoolLogic.trigger_at(campus, SchoolLogic.spawn_on_tile(campus, "c", 0).x, SchoolLogic.spawn_on_tile(campus, "c", 0).y).place_id == "school:class-3")
	failed += _check("class-4", SchoolLogic.trigger_at(campus, SchoolLogic.spawn_on_tile(campus, "d", 0).x, SchoolLogic.spawn_on_tile(campus, "d", 0).y).place_id == "school:class-4")
	failed += _check("title class", SchoolLogic.place_title("school:class-2") == "二班教室")
	failed += _check("title away", SchoolLogic.place_title("away") == "桌面")
	var cam: Dictionary = SchoolLogic.camera_for(1.8, 384.0, 348.0, 820.0, 560.0, 25 * 32, 14 * 32)
	failed += _check("camera has left", cam.has("left") and cam.has("top") and cam.scale == 1.8)
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("school_logic: %s" % label)
	return 1
