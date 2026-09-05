# 源：shared/sync.ts
class_name PetSync
extends RefCounted

const SchoolLogic = preload("res://school/school_logic.gd")

static func _js_round_1(x: float) -> float:
	return floor(x * 10.0 + 0.5) / 10.0

static func round_pose(x: float, y: float) -> Vector2:
	return Vector2(_js_round_1(x), _js_round_1(y))

static func interpolate_pose(from_x: float, from_y: float, to_x: float, to_y: float, from_at: float, now: float, dur: float = -1.0) -> Dictionary:
	if dur < 0.0:
		dur = float(SchoolLogic.POSE_TICK_MS + 40)
	var t := 1.0 if dur <= 0.0 else clampf((now - from_at) / dur, 0.0, 1.0)
	return {"x": from_x + (to_x - from_x) * t, "y": from_y + (to_y - from_y) * t, "t": t}

static func pose_facing(from_facing: String, to_facing: String, t: float) -> String:
	return to_facing if t >= 0.35 else from_facing

static func keep_visual_people(prev: Array, incoming: Array) -> Array:
	if prev.is_empty():
		return incoming.duplicate(true)
	var prev_by := {}
	for person in prev:
		prev_by[person.clientId] = person
	var out: Array = []
	for person in incoming:
		var next: Dictionary = person.duplicate(true)
		if prev_by.has(person.clientId):
			var old: Dictionary = prev_by[person.clientId]
			next.x = old.x
			next.y = old.y
			next.facing = old.facing
		out.append(next)
	return out

static func apply_pose_items(people: Array, items: Array, self_id: String) -> Array:
	if items.is_empty():
		return people
	var by_id := {}
	for item in items:
		if item.id != self_id:
			by_id[item.id] = item
	if by_id.is_empty():
		return people
	var out: Array = []
	for person in people:
		if by_id.has(person.clientId):
			var item: Dictionary = by_id[person.clientId]
			var next: Dictionary = person.duplicate(true)
			next.x = item.x
			next.y = item.y
			next.facing = item.facing
			out.append(next)
		else:
			out.append(person)
	return out
