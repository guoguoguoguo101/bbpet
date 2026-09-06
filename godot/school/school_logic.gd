# 源：shared/world.ts
class_name SchoolLogic
extends RefCounted

const TILE := 32
const PET_SIZE := 32
const MOVE_SPEED := 110
const MOVE_SEND_MS := 100
const POSE_TICK_MS := 100
const SCHOOL_CROWD_CAP := 100
const DEFAULT_ROOM_URL := "ws://127.0.0.1:18765"
const DEFAULT_ROOM_PORT := 18765

const CAMPUS = [
	"#########################",
	"#rrrrr#rrrrr#rrrrr#rrrrr#",
	"#fffff#fffff#fffff#fffff#",
	"#fffff#fffff#fffff#fffff#",
	"###a#####b#####c#####d###",
	"#ppppppppppppppppppppppp#",
	"#.......................#",
	"#.......................#",
	"#.......................#",
	"#.......................#",
	"#.......................#",
	"#.......................#",
	"#...........x...........#",
	"#########################",
]

const CLASSROOM = [
	"####################",
	"#kkkkkkkkkkkkkkkkkk#",
	"#..................#",
	"#..................#",
	"#..ss....ss....ss..#",
	"#..................#",
	"#..ss....ss....ss..#",
	"#..................#",
	"#..................#",
	"#........g.........#",
	"#..................#",
	"####################",
]

const PLACES := {
	"school:campus": {
		"id": "school:campus",
		"title": "学校操场",
		"kind": "campus",
		"tiles": CAMPUS,
		"labels": [
			{"text": "一班", "tx": 3, "ty": 2},
			{"text": "二班", "tx": 9, "ty": 2},
			{"text": "三班", "tx": 15, "ty": 2},
			{"text": "活动室", "tx": 21, "ty": 2},
		],
	},
	"school:class-1": {
		"id": "school:class-1",
		"title": "一班教室",
		"kind": "classroom",
		"tiles": CLASSROOM,
		"labels": [{"text": "一班黑板", "tx": 7, "ty": 1}],
	},
	"school:class-2": {
		"id": "school:class-2",
		"title": "二班教室",
		"kind": "classroom",
		"tiles": CLASSROOM,
		"labels": [{"text": "二班黑板", "tx": 7, "ty": 1}],
	},
	"school:class-3": {
		"id": "school:class-3",
		"title": "三班教室",
		"kind": "classroom",
		"tiles": CLASSROOM,
		"labels": [{"text": "三班黑板", "tx": 7, "ty": 1}],
	},
	"school:class-4": {
		"id": "school:class-4",
		"title": "活动室",
		"kind": "classroom",
		"tiles": CLASSROOM,
		"labels": [{"text": "活动室黑板", "tx": 6, "ty": 1}],
	},
}

const DOOR_TO_CLASS := {
	"a": "school:class-1",
	"b": "school:class-2",
	"c": "school:class-3",
	"d": "school:class-4",
}


static func map_size(place: Dictionary) -> Dictionary:
	var tiles: Array = place.tiles
	return {"cols": tiles[0].length(), "rows": tiles.size()}


static func tile_at(place: Dictionary, tx: int, ty: int) -> String:
	var tiles: Array = place.tiles
	if ty < 0 or ty >= tiles.size():
		return "#"
	var row: String = tiles[ty]
	if tx < 0 or tx >= row.length():
		return "#"
	return row[tx]


static func find_tile(place: Dictionary, code: String) -> Dictionary:
	var tiles: Array = place.tiles
	for ty in tiles.size():
		var tx: int = tiles[ty].find(code)
		if tx >= 0:
			return {"tx": tx, "ty": ty}
	return {"tx": 1, "ty": 1}


static func spawn_on_tile(place: Dictionary, code: String, dy: int = -8) -> Dictionary:
	var pos: Dictionary = find_tile(place, code)
	var tx: int = pos.tx
	var ty: int = pos.ty
	return {
		"x": tx * TILE + (TILE - PET_SIZE) / 2.0,
		"y": ty * TILE + dy,
	}


static func default_spawn(place_id: String) -> Dictionary:
	if not is_school_place(place_id):
		return {"x": 0.0, "y": 0.0}
	var place: Dictionary = PLACES[place_id]
	if place.kind == "campus":
		return spawn_on_tile(place, "x", -TILE - 4)
	return spawn_on_tile(place, "g", -TILE - 4)


static func spawn_after_enter(from_id: String, to_id: String) -> Dictionary:
	if not is_school_place(to_id):
		return {"x": 0.0, "y": 0.0}
	if to_id == "school:campus" and is_school_place(from_id) and from_id != "school:campus":
		var door := "a"
		for letter in DOOR_TO_CLASS:
			if DOOR_TO_CLASS[letter] == from_id:
				door = letter
				break
		return spawn_on_tile(PLACES[to_id], door, TILE - 6)
	return default_spawn(to_id)


static func is_solid(code: String) -> bool:
	return code == "#" or code == "s" or code == "k" or code == "r"


static func feet_box(x: float, y: float) -> Dictionary:
	return {"x": x + 8.0, "y": y + 20.0, "w": 16.0, "h": 10.0}


static func can_walk(place: Dictionary, x: float, y: float) -> bool:
	var box: Dictionary = feet_box(x, y)
	var points: Array = [
		[box.x, box.y],
		[box.x + box.w, box.y],
		[box.x, box.y + box.h],
		[box.x + box.w, box.y + box.h],
	]
	for pt in points:
		var px: float = pt[0]
		var py: float = pt[1]
		if is_solid(tile_at(place, int(floor(px / TILE)), int(floor(py / TILE)))):
			return false
	return true


static func clamp_move(place: Dictionary, from_x: float, from_y: float, to_x: float, to_y: float) -> Dictionary:
	if can_walk(place, to_x, to_y):
		return {"x": to_x, "y": to_y}
	if can_walk(place, to_x, from_y):
		return {"x": to_x, "y": from_y}
	if can_walk(place, from_x, to_y):
		return {"x": from_x, "y": to_y}
	return {"x": from_x, "y": from_y}


static func trigger_at(place: Dictionary, x: float, y: float) -> Variant:
	var box: Dictionary = feet_box(x, y)
	var cx: float = box.x + box.w / 2.0
	var cy: float = box.y + box.h / 2.0
	var code: String = tile_at(place, int(floor(cx / TILE)), int(floor(cy / TILE)))
	if code == "x":
		return {"kind": "exit"}
	if code == "g":
		return {"kind": "campus"}
	if DOOR_TO_CLASS.has(code):
		return {"kind": "classroom", "place_id": DOOR_TO_CLASS[code]}
	return null


static func tile_color(code: String, kind: String) -> String:
	if code == "#":
		return "#c45c4a" if kind == "campus" else "#8b5e3c"
	if code == "r":
		return "#d64545"
	if code == "f":
		return "#f0d2a8"
	if code == "p":
		return "#e6d3a0"
	if code == "k":
		return "#24382c"
	if code == "s":
		return "#8b5e3c"
	if code == "a" or code == "b" or code == "c" or code == "d" or code == "g":
		return "#ffb347"
	if code == "x":
		return "#7ee0c6"
	if kind == "classroom":
		return "#e2b989"
	if code == "." and kind == "campus":
		return "#6ec15a"
	return "#8fbc6b"


static func tile_accent(code: String) -> String:
	if code == "k":
		return "#4a7a5c"
	if code == "r":
		return "#8e1f1f"
	if code == "#":
		return "#3d2c29"
	if code == "s" or code == "f":
		return "#b07d4f"
	if code == "p":
		return "#c4a574"
	if code == ".":
		return "#4a9a45"
	if code == "x":
		return "#2f6f5e"
	return "#3d2c29"


static func place_title(place_id: String) -> String:
	if place_id == "away":
		return "桌面"
	if place_id.begins_with("home:"):
		return "房间"
	if is_school_place(place_id):
		return PLACES[place_id].title
	return ""


static func is_school_place(place_id: String) -> bool:
	return PLACES.has(place_id)


static func camera_for(scale: float, me_x: float, me_y: float, stage_w: float, stage_h: float, map_w: float, map_h: float) -> Dictionary:
	var drawn_w := map_w * scale
	var drawn_h := map_h * scale
	var left := roundi(stage_w / 2.0 - (me_x + PET_SIZE / 2.0) * scale)
	var top := roundi(stage_h / 2.0 - (me_y + PET_SIZE / 2.0) * scale)
	if drawn_w <= stage_w:
		left = roundi((stage_w - drawn_w) / 2.0)
	else:
		left = mini(0, maxi(roundi(stage_w - drawn_w), left))
	if drawn_h <= stage_h:
		top = roundi((stage_h - drawn_h) / 2.0)
	else:
		top = mini(0, maxi(roundi(stage_h - drawn_h), top))
	return {"scale": scale, "left": left, "top": top}


static func room_listen_port(url: String) -> int:
	var trimmed := url.strip_edges()
	var colon := trimmed.rfind(":")
	if colon <= 4:
		return DEFAULT_ROOM_PORT
	var tail := trimmed.substr(colon + 1)
	if not tail.is_valid_int():
		return DEFAULT_ROOM_PORT
	var port := int(tail)
	if port <= 0 or port > 65535:
		return DEFAULT_ROOM_PORT
	return port
