extends RefCounted

const SchoolSocial = preload("res://school/school_social.gd")


func run() -> int:
	var failed := 0
	failed += _check("collapse spaces", SchoolSocial.sanitize_chat("  a   b  ") == "a b")
	failed += _check("empty whitespace", SchoolSocial.sanitize_chat(" \n\t ") == "")
	var vt := char(0x000B)
	var ff := char(0x000C)
	failed += _check(
		"collapse unicode whitespace",
		SchoolSocial.sanitize_chat("  a %s%s b  " % [vt, ff]) == "a b"
	)
	var long := ""
	for _i in 90:
		long += "字"
	failed += _check("max 80", SchoolSocial.sanitize_chat(long).length() == 80)
	var board: Array = []
	for i in 81:
		board = SchoolSocial.append_board(board, {"id": str(i), "text": str(i)})
	failed += _check("board cap 80", board.size() == 80)
	failed += _check("board dropped oldest", str(board[0].id) == "1")
	var visible: Array = SchoolSocial.visible_board(board)
	failed += _check("visible 7", visible.size() == 7)
	failed += _check("visible last", str(visible[6].id) == "80")
	failed += _check("menu add", SchoolSocial.friend_menu_kind("b", ["a"]) == "add")
	failed += _check("menu already", SchoolSocial.friend_menu_kind("a", ["a"]) == "already")
	failed += _check("offline", SchoolSocial.friend_status_text({"online": false}) == "离线")
	failed += _check(
		"at school",
		SchoolSocial.friend_status_text({"online": true, "schoolPlaceId": "school:campus"}) == "在学校"
	)
	failed += _check("online", SchoolSocial.friend_status_text({"online": true}) == "在线")
	failed += _check("null school id", SchoolSocial.friend_status_text({"online": true, "schoolPlaceId": null}) == "在线")
	failed += _check("open campus", SchoolSocial.should_open_world("school:campus") == true)
	failed += _check("skip home", SchoolSocial.should_open_world("home:abc") == false)
	failed += _check("skip away", SchoolSocial.should_open_world("away") == false)
	failed += _check("classroom", SchoolSocial.is_classroom_place({"kind": "classroom"}) == true)
	failed += _check("campus not classroom", SchoolSocial.is_classroom_place({"kind": "campus"}) == false)
	failed += _check("campus place", SchoolSocial.is_campus_place({"kind": "campus"}))
	failed += _check("chat campus", SchoolSocial.can_chat_here({"kind": "campus"}))
	failed += _check("kind board", SchoolSocial.chat_kind_for({"kind": "classroom"}) == "board")
	failed += _check("kind nearby", SchoolSocial.chat_kind_for({"kind": "campus"}) == "nearby")
	failed += _check("nearby in range", SchoolSocial.nearby_visible(0, 0, 100, 0))
	failed += _check("nearby out", not SchoolSocial.nearby_visible(0, 0, 200, 0))
	failed += _check("nearby range", is_equal_approx(SchoolSocial.NEARBY_RANGE, 140.0))
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("school_social: %s" % label)
	return 1
