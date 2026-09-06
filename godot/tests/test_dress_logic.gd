extends RefCounted

const DressLogic = preload("res://weather/dress_logic.gd")


func run() -> int:
	var failed := 0
	var night: Dictionary = DressLogic.dress_for(0, 20.0, false, 0.0)
	failed += _check("night stars", night.fx == ["stars"] and night.gear.is_empty())
	failed += _check("night line", night.dressLine == "晚上了，陪你一起数星星。")
	var storm: Dictionary = DressLogic.dress_for(95, 18.0, true, 5.0)
	failed += _check("storm gear", storm.gear.has("raincoat") and storm.gear.has("umbrella"))
	failed += _check("storm fx", storm.fx.has("rain") and storm.fx.has("storm"))
	failed += _check("storm line", storm.dressLine == "打雷了，我躲到小伞下面。")
	var snow: Dictionary = DressLogic.dress_for(71, -2.0, true, 5.0)
	failed += _check("snow", snow.gear == ["beanie", "scarf", "snowman"] and snow.fx == ["snow"])
	var rain: Dictionary = DressLogic.dress_for(61, 18.0, true, 5.0)
	failed += _check("rain", rain.gear == ["raincoat", "umbrella"] and rain.fx == ["rain"])
	var hot_drizzle: Dictionary = DressLogic.dress_for(51, 31.0, true, 5.0)
	failed += _check(
		"hot drizzle",
		hot_drizzle.gear == ["umbrella", "raincoat"] and hot_drizzle.fx == ["rain"]
	)
	var fog: Dictionary = DressLogic.dress_for(45, 18.0, true, 5.0)
	failed += _check("fog", fog.gear.is_empty() and fog.fx == ["fog"])
	var sun: Dictionary = DressLogic.dress_for(0, 20.0, true, 5.0)
	failed += _check("sun", sun.gear == ["shades", "juice"] and sun.fx == ["sun"])
	var hot_partly: Dictionary = DressLogic.dress_for(2, 31.0, true, 5.0)
	failed += _check(
		"hot partly",
		hot_partly.gear == ["shades", "juice"] and hot_partly.fx == ["cloud", "sun"]
	)
	var overcast: Dictionary = DressLogic.dress_for(3, 18.0, true, 5.0)
	failed += _check("overcast", overcast.gear.is_empty() and overcast.fx == ["cloud"])
	var cold: Dictionary = DressLogic.dress_for(3, 6.0, true, 5.0)
	failed += _check("cold", cold.gear == ["scarf", "beanie"] and cold.fx == ["cloud"])
	var wind: Dictionary = DressLogic.dress_for(-1, 18.0, true, 28.0)
	failed += _check("wind", wind.gear.is_empty() and wind.fx == ["wind"])
	var fallback: Dictionary = DressLogic.dress_for(-1, 18.0, true, 5.0)
	failed += _check("fallback", fallback.gear.is_empty() and fallback.fx == ["cloud"])
	failed += _check("pick line", DressLogic.pick_line(["甲", "乙", "丙"], 4) == "乙")
	failed += _check("empty line", DressLogic.pick_line([], 0) == "")
	failed += _check(
		"weather map",
		DressLogic.WEATHER_MAP[0].description == "晴朗"
		and DressLogic.WEATHER_MAP[99].emoji == "⛈️"
	)
	failed += _check(
		"clamp",
		DressLogic.clamp_push_minutes(2) == 5 and DressLogic.clamp_push_minutes(30) == 30
	)
	failed += _check(
		"quiet",
		DressLogic.quiet_line("豆豆") == "豆豆：外网有点安静，我稍后再探探天气和新闻。"
	)
	failed += _check(
		"news",
		DressLogic.news_line("豆豆", "少数派", "标题") == "豆豆：[少数派] 标题"
	)
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("dress_logic: %s" % label)
	return 1
