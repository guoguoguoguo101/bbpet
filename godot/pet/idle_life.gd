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
	match kind:
		"rain":
			return _wx("中雨", "🌧️", 16, 63, ["raincoat", "umbrella"], ["rain"], "下雨了，披上小黄衣出门。")
		"hot":
			return _wx("晴朗", "🥵", 33, 0, ["shades", "juice"], ["sun"], "晒化了，墨镜必须戴上。")
		"drizzle":
			return _wx("小毛毛雨", "🌦️", 18, 51, ["umbrella"], ["rain"], "毛毛雨，撑一下免得头发湿。")
		"storm":
			return _wx("雷阵雨", "⛈️", 19, 95, ["raincoat", "umbrella"], ["rain", "storm"], "打雷了，我躲到小伞下面。")
		"snow":
			return _wx("中雪", "🌨️", -2, 73, ["beanie", "scarf", "snowman"], ["snow"], "下雪啦，帽子围巾全副武装。")
		"cold":
			return _wx("阴天", "☁️", 2, 3, ["scarf", "beanie"], [], "好冷，把围巾裹紧一点。")
		"fog":
			return _wx("有雾", "🌫️", 12, 45, [], ["fog"], "有雾，我眯着眼慢慢走。")
		"night":
			var night := _wx("晴朗", "🌙", 17, 0, [], ["stars"], "晚上了，陪你一起数星星。")
			night.isDay = false
			return night
		"wind":
			var wind := _wx("多云", "💨", 21, 2, [], ["wind"], "风有点大，我站稳了。")
			wind.wind = 34.0
			return wind
		"partly":
			return _wx("多云", "⛅", 22, 2, [], [], "多云，太阳在云后面躲猫猫。")
		"overcast":
			return _wx("阴天", "☁️", 14, 3, [], [], "阴天，云把天盖住了。")
		_:
			return _wx("晴朗", "☀️", 24, 0, ["shades", "juice"], ["sun"], "太阳很好，墨镜戴上。")


static func _wx(description: String, emoji: String, temperature: int, code: int, gear: Array, fx: Array, dress_line: String) -> Dictionary:
	return {
		"cityName": "演示",
		"description": description,
		"emoji": emoji,
		"temperature": temperature,
		"code": code,
		"isDay": true,
		"wind": 6.0,
		"gear": gear,
		"fx": fx,
		"dressLine": dress_line,
	}


const POSE_LINES := {
	"idle": ["发会儿呆。", "想事情呢。", "今天也要认真摸鱼。"],
	"look-right": ["右边好像有东西。", "我看那边一下。"],
	"look-left": ["左边谁在叫我？", "往这边瞅瞅。"],
	"blink": ["眨一下眼睛。", "阳光有点晃。"],
	"talk": ["我有话要说。", "听我说完这一句。", "嘿嘿，想聊天。"],
	"drink": ["先喝一口。", "咕嘟咕嘟，润润嗓子。", "口渴了。"],
	"sleep": ["好困，先眯一下。", "叫我起床要轻轻的。", "Zzz… 再睡五分钟。"],
	"wake": ["伸个懒腰。", "睡醒了，骨头咔咔响。"],
	"type": ["你打字我围观。", "敲得真快，我跟着点头。", "写得认真，我不吵你。"],
	"phone": ["先刷一分钟。", "这个好好笑，领导应该看不见。", "再划两条就工作。"],
	"snack": ["偷偷吃一口。", "抽屉里还有薯片。", "咔嚓，真香。"],
	"peek": ["有人来了吗？", "左右看一眼再摸。", "门口没人，继续。"],
	"game": ["再打一把就干活。", "这关过不去了。", "输了不算，再来。"],
	"coffee": ["来杯美式续命。", "再抿一口就不困了。", "咖啡香，工作先放放。"],
	"toilet": ["嘘嘘一下马上回来。", "憋不住了，先去方便。", "洗手间见，别偷看。"],
}


static func line_for_pose(pose: String, seed := "") -> String:
	if not POSE_LINES.has(pose):
		return ""
	var lines: Array = POSE_LINES[pose]
	if lines.is_empty():
		return ""
	if seed.is_empty():
		return String(lines[randi() % lines.size()])
	var n := 0
	for i in seed.length():
		n = int((n * 33 + seed.unicode_at(i)) & 0xFFFFFFFF)
	return String(lines[posmod(n, lines.size())])
