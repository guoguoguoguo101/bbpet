class_name DressLogic
extends RefCounted

# Sources: electron/services/weather.ts and shared/weatherLines.ts

const WEATHER_MAP: Dictionary = {
	0: {"description": "晴朗", "emoji": "☀️"},
	1: {"description": "大部晴朗", "emoji": "🌤️"},
	2: {"description": "多云", "emoji": "⛅"},
	3: {"description": "阴天", "emoji": "☁️"},
	45: {"description": "有雾", "emoji": "🌫️"},
	48: {"description": "雾凇", "emoji": "🌫️"},
	51: {"description": "小毛毛雨", "emoji": "🌦️"},
	53: {"description": "毛毛雨", "emoji": "🌦️"},
	55: {"description": "大毛毛雨", "emoji": "🌧️"},
	56: {"description": "冻毛毛雨", "emoji": "🌧️"},
	57: {"description": "强冻毛毛雨", "emoji": "🌧️"},
	61: {"description": "小雨", "emoji": "🌧️"},
	63: {"description": "中雨", "emoji": "🌧️"},
	65: {"description": "大雨", "emoji": "🌧️"},
	66: {"description": "冻雨", "emoji": "🌧️"},
	67: {"description": "强冻雨", "emoji": "🌧️"},
	71: {"description": "小雪", "emoji": "🌨️"},
	73: {"description": "中雪", "emoji": "🌨️"},
	75: {"description": "大雪", "emoji": "❄️"},
	77: {"description": "雪粒", "emoji": "🌨️"},
	80: {"description": "阵雨", "emoji": "🌦️"},
	81: {"description": "强阵雨", "emoji": "🌧️"},
	82: {"description": "暴雨", "emoji": "⛈️"},
	85: {"description": "小阵雪", "emoji": "🌨️"},
	86: {"description": "强阵雪", "emoji": "❄️"},
	95: {"description": "雷阵雨", "emoji": "⛈️"},
	96: {"description": "雷阵雨带冰雹", "emoji": "⛈️"},
	99: {"description": "强雷暴", "emoji": "⛈️"},
}

const WEATHER_LINES: Dictionary = {
	"night": ["晚上了，陪你一起数星星。", "月亮出来了，我还不困。", "夜色刚刚好，我守着你。"],
	"storm": ["打雷了，我躲到小伞下面。", "轰隆隆，有点怕，抓稳我。", "雷阵雨好吵，我们靠紧一点。"],
	"snow": ["下雪啦，帽子围巾全副武装。", "好冷！我堆了个小雪人作伴。", "雪花粘在鼻子上了。"],
	"rain": ["下雨了，披上小黄衣出门。", "路上滑，我慢慢走。", "滴答滴答，雨点打在伞上。"],
	"drizzle": ["毛毛雨，撑一下免得头发湿。", "细雨凉凉的，还好有小伞。", "这点雨，打湿刘海就不美了。"],
	"fog": ["有雾，我眯着眼慢慢走。", "前面模模糊糊的，我跟着你。", "雾把世界变成棉花糖了。"],
	"sun": ["大晴天，戴上墨镜出门透气。", "阳光正好，我喝一口再走。", "天这么蓝，心情也亮亮的。"],
	"sunHot": ["晒化了，墨镜必须戴上。", "热热热，先灌一口降降温。", "太阳好热情，我有点化。"],
	"partly": ["多云，太阳在云后面躲猫猫。", "云缝里漏下来一点光。", "半阴半晴，适合发呆。"],
	"overcast": ["阴天，云把天盖住了。", "灰蒙蒙的，我陪你发呆。", "没有太阳，我也是你的小太阳。"],
	"cold": ["好冷，把围巾裹紧一点。", "耳朵要冻红了，帽子戴上。", "冷风往领口钻，我缩成一团。"],
	"wind": ["风有点大，我站稳了。", "被风推了一下，还好没摔倒。", "发型要乱了，你别笑我。"],
	"fallback": ["我先看一眼天。", "今天的天气，我记下了。"],
}


static func dress_for(
	code: int,
	temperature: float,
	is_day: bool,
	wind: float,
	pick_index: int = -1
) -> Dictionary:
	var line_index := randi() if pick_index < 0 else pick_index
	if not is_day:
		return {
			"gear": [],
			"fx": ["stars"],
			"dressLine": pick_line(WEATHER_LINES.night, line_index),
		}

	var gear: Array = []
	var fx: Array = []
	var dress_line: String = pick_line(WEATHER_LINES.fallback, line_index)

	var storm := code >= 95 or code == 82 or code == 99
	var snow := code in [71, 73, 75, 77, 85, 86]
	var rain := storm or code in [55, 61, 63, 65, 66, 67, 80, 81, 82]
	var drizzle := code in [51, 53, 56, 57]
	var fog := code == 45 or code == 48
	var clear := code == 0 or code == 1
	var partly := code == 2
	var overcast := code == 3

	if storm:
		gear.append_array(["raincoat", "umbrella"])
		fx.append_array(["rain", "storm"])
		dress_line = pick_line(WEATHER_LINES.storm, line_index)
	elif snow:
		gear.append_array(["beanie", "scarf", "snowman"])
		fx.append("snow")
		dress_line = pick_line(WEATHER_LINES.snow, line_index)
	elif rain:
		gear.append_array(["raincoat", "umbrella"])
		fx.append("rain")
		dress_line = pick_line(WEATHER_LINES.rain, line_index)
	elif drizzle:
		gear.append("umbrella")
		fx.append("rain")
		dress_line = pick_line(WEATHER_LINES.drizzle, line_index)
	elif fog:
		fx.append("fog")
		dress_line = pick_line(WEATHER_LINES.fog, line_index)
	elif clear:
		gear.append_array(["shades", "juice"])
		fx.append("sun")
		dress_line = pick_line(
			WEATHER_LINES.sunHot if temperature >= 30 else WEATHER_LINES.sun,
			line_index
		)
	elif partly:
		fx.append_array(["cloud", "sun"])
		if temperature >= 30:
			gear.append_array(["shades", "juice"])
			dress_line = pick_line(WEATHER_LINES.sunHot, line_index)
		else:
			dress_line = pick_line(WEATHER_LINES.partly, line_index)
	elif overcast:
		fx.append("cloud")
		dress_line = pick_line(WEATHER_LINES.overcast, line_index)

	if temperature <= 6 and not rain and not drizzle and not storm:
		if not gear.has("scarf"):
			gear.append("scarf")
		if not gear.has("beanie"):
			gear.append("beanie")
		if not snow:
			dress_line = pick_line(WEATHER_LINES.cold, line_index)

	if temperature >= 30 and (rain or drizzle) and not gear.has("raincoat"):
		gear.append("raincoat")

	if wind >= 28 and not storm:
		fx.append("wind")
		dress_line = pick_line(WEATHER_LINES.wind, line_index)

	if gear.is_empty() and fx.is_empty():
		if temperature >= 28:
			gear.append_array(["shades", "juice"])
			fx.append("sun")
			dress_line = pick_line(WEATHER_LINES.sunHot, line_index)
		elif temperature <= 6:
			gear.append_array(["scarf", "beanie"])
			dress_line = pick_line(WEATHER_LINES.cold, line_index)
		else:
			fx.append("cloud")
			dress_line = pick_line(WEATHER_LINES.fallback, line_index)

	return {
		"gear": _unique(gear),
		"fx": _unique(fx),
		"dressLine": dress_line,
	}


static func pick_line(lines: Array, index: int = 0) -> String:
	if lines.is_empty():
		return ""
	return str(lines[index % lines.size()])


static func clamp_push_minutes(n: int) -> int:
	return maxi(5, n)


static func quiet_line(pet_name: String) -> String:
	return "%s：外网有点安静，我稍后再探探天气和新闻。" % pet_name


static func news_line(pet_name: String, source: String, title: String) -> String:
	return "%s：[%s] %s" % [pet_name, source, title]


static func _unique(items: Array) -> Array:
	var result: Array = []
	for item in items:
		if not result.has(item):
			result.append(item)
	return result
