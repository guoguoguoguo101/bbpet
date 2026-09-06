class_name IdleLife
extends RefCounted

const SLACK_POSES := ["phone", "snack", "peek", "game", "coffee", "toilet"]
const ACTION_HOLD_MS := 10000
const DRINK_MS := 2800
const NAP_SLEEP_MIN_MS := 12000
const NAP_SLEEP_SPAN_MS := 8000
const WAKE_MS := 1600
const SLACK_HOLD_MIN_MS := 3400
const SLACK_HOLD_SPAN_MS := 1600


static func can_nap(pose: String) -> bool:
	return pose != "talk" and pose != "type"


static func can_slack(pose: String) -> bool:
	return pose == "idle" or pose == "blink"


static func is_slack(pose: String) -> bool:
	return SLACK_POSES.has(pose)


static func pick_slack(index: int) -> String:
	if SLACK_POSES.is_empty():
		return "phone"
	return SLACK_POSES[posmod(index, SLACK_POSES.size())]


static func has_juice(dress: Dictionary) -> bool:
	var gear: Variant = dress.get("gear", [])
	return gear is Array and gear.has("juice")


static func demo_weather(kind: String) -> Dictionary:
	if kind == "rain":
		return {
			"cityName": "演示",
			"description": "中雨",
			"emoji": "🌧️",
			"temperature": 16,
			"code": 63,
			"isDay": true,
			"wind": 6.0,
			"gear": ["raincoat", "umbrella"],
			"fx": ["rain"],
			"dressLine": "下雨了，雨衣帽子先扣上。",
		}
	return {
		"cityName": "演示",
		"description": "晴朗",
		"emoji": "☀️",
		"temperature": 24,
		"code": 0,
		"isDay": true,
		"wind": 6.0,
		"gear": ["shades", "juice"],
		"fx": ["sun"],
		"dressLine": "太阳很好，墨镜戴上。",
	}
