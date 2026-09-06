extends RefCounted

const HomeLogic = preload("res://home/home_logic.gd")


func run() -> int:
	var failed := 0
	failed += _check("home id", HomeLogic.home_place_id("abc") == "home:abc")
	failed += _check("owner", HomeLogic.home_owner_id("home:abc") == "abc")
	failed += _check("owner empty", HomeLogic.home_owner_id("school:campus") == "")
	failed += _check(
		"at home while at school",
		HomeLogic.is_friend_at_home({"online": true, "clientId": "a", "homeId": "home:a", "schoolPlaceId": "school:campus"})
	)
	failed += _check(
		"visiting not at home",
		not HomeLogic.is_friend_at_home({"online": true, "clientId": "a", "homeId": "home:b"})
	)
	failed += _check(
		"offline",
		not HomeLogic.is_friend_at_home({"online": false, "clientId": "a", "homeId": "home:a"})
	)
	var me := {"homeId": "home:me"}
	failed += _check("alone not gathering", not HomeLogic.is_home_gathering(me, [], "me"))
	failed += _check("guest gathering", HomeLogic.is_home_gathering(me, [{"clientId": "x"}], "me"))
	failed += _check("visiting gathering", HomeLogic.is_home_gathering({"homeId": "home:host"}, [], "me"))
	var one: Dictionary = HomeLogic.yard_metrics(1, false)
	failed += _check("one width", int(one.width) == 248)
	failed += _check("one height", int(one.height) == 164)
	failed += _check("one barW", int(one.barW) == 144)
	var two: Dictionary = HomeLogic.yard_metrics(2, false)
	failed += _check("two width", int(two.width) == 248)
	failed += _check("two petsW", int(two.petsW) == 144)
	var five: Dictionary = HomeLogic.yard_metrics(5, false)
	failed += _check("five width", int(five.width) == 392)
	failed += _check("five height", int(five.height) == 258)
	failed += _check("chat log 0", HomeLogic.chat_log_h(0) == 0)
	failed += _check("chat log 3", HomeLogic.chat_log_h(3) == 51)
	failed += _check("chat log cap", HomeLogic.chat_log_h(8) == 51)
	var hug := {"kind": "hug", "fromId": "a", "targetId": "b"}
	failed += _check("hug from pose", HomeLogic.pose_for_action(hug, "a", "idle") == "talk")
	failed += _check("hug to pose", HomeLogic.pose_for_action(hug, "b", "idle") == "talk")
	failed += _check("hug from label", HomeLogic.label_for_action(hug, "a") == "抱抱")
	var kick := {"kind": "kick", "fromId": "a", "targetId": "b"}
	failed += _check("kick from pose", HomeLogic.pose_for_action(kick, "a", "idle") == "wake")
	failed += _check("kick to pose", HomeLogic.pose_for_action(kick, "b", "idle") == "peek")
	failed += _check("kick to label", HomeLogic.label_for_action(kick, "b") == "转圈飞走")
	failed += _check("emote hug", HomeLogic.emote_label("hug") == "抱抱")
	failed += _check("emote pour", HomeLogic.emote_label("pour") == "倒水")
	failed += _check("emote wake", HomeLogic.emote_label("wake") == "拍醒")
	failed += _check("emote kick", HomeLogic.emote_label("kick") == "飞踢")
	failed += _check("title home", HomeLogic.gathering_title({"homeId": "home:me", "name": "甲"}, [], "me") == "自家")
	failed += _check(
		"title visit",
		HomeLogic.gathering_title({"homeId": "home:host"}, [{"clientId": "host", "name": "乙"}], "me") == "乙家"
	)
	failed += _check(
		"title visit fallback",
		HomeLogic.gathering_title({"homeId": "home:host"}, [{"clientId": "host"}], "me") == "好友家"
	)
	var slot0: Dictionary = HomeLogic.slot_offset(0, 5)
	failed += _check("slot 0", int(slot0.x) == 24 and int(slot0.y) == 40)
	var slot_row2: Dictionary = HomeLogic.slot_offset(4, 5)
	failed += _check("slot second row", int(slot_row2.x) == 24 and int(slot_row2.y) == 134)
	var pour := {"kind": "pour", "fromId": "a", "targetId": "b"}
	failed += _check("pour from pose", HomeLogic.pose_for_action(pour, "a", "idle") == "drink")
	failed += _check("pour to pose", HomeLogic.pose_for_action(pour, "b", "idle") == "drink")
	var wake := {"kind": "wake", "fromId": "a", "targetId": "b"}
	failed += _check("wake from pose", HomeLogic.pose_for_action(wake, "a", "sleep") == "wave")
	failed += _check("wake to pose", HomeLogic.pose_for_action(wake, "b", "sleep") == "wake")
	failed += _check("wake to wave when awake", HomeLogic.pose_for_action(wake, "b", "idle") == "wave")
	var usable := Rect2i(0, 0, 1920, 1080)
	failed += _check(
		"anchor grow bottom-right",
		HomeLogic.anchor_window(Vector2i(1848, 986), Vector2i(64, 86), Vector2i(248, 164), usable) == Vector2i(1664, 908)
	)
	failed += _check(
		"anchor shrink bottom-right",
		HomeLogic.anchor_window(Vector2i(1664, 908), Vector2i(248, 164), Vector2i(64, 86), usable) == Vector2i(1848, 986)
	)
	var inset := Rect2i(10, 20, 800, 600)
	failed += _check(
		"anchor clamp min",
		HomeLogic.anchor_window(Vector2i(10, 20), Vector2i(64, 86), Vector2i(400, 300), inset) == Vector2i(14, 24)
	)
	failed += _check("flyer dir index", HomeLogic.flyer_dir("x", 0, 2) == 1 and HomeLogic.flyer_dir("x", 2, 0) == -1)
	var start := HomeLogic.flyer_point(0.0, Vector2(100, 200), Vector2(300, 180))
	failed += _check("flyer start", start == Vector2(100, 200))
	var mid := HomeLogic.flyer_point(0.3, Vector2(100, 200), Vector2(300, 180))
	failed += _check("flyer mid lifted", mid.y < 200.0)
	var seat := HomeLogic.flyer_seat(100, 200, 24, 40)
	failed += _check("flyer seat", is_equal_approx(seat.x, 100 + 24 + (72 - 96) / 2.0))
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("home_logic: %s" % label)
	return 1
