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
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("home_logic: %s" % label)
	return 1
