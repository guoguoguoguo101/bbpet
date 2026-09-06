extends RefCounted

const FIXTURE := {
	"current": {
		"temperature_2m": 26.2,
		"weather_code": 0,
		"is_day": 1,
		"wind_speed_10m": 1.2,
	},
}


func run() -> int:
	var failed := 0
	var script: Variant = load("res://autoload/weather_client.gd")
	if script == null or not script is Script or not script.can_instantiate():
		push_error("weather_client: missing script")
		return 1
	var wc: Node = script.new()
	failed += _check("parse API", wc.has_method("parse_weather_payload"))
	failed += _check("apply API", wc.has_method("apply_weather"))
	failed += _check("quiet API", wc.has_method("quiet_bubble"))
	failed += _check("refresh API", wc.has_method("refresh_after_settings"))
	failed += _check("request API", wc.has_method("request_bubble"))
	failed += _check("weather signal", wc.has_signal("weather_changed"))
	failed += _check("bubble signal", wc.has_signal("bubble_requested"))
	if failed:
		wc.free()
		return failed

	var info: Dictionary = wc.parse_weather_payload("北京", FIXTURE)
	failed += _check("city name", info.get("cityName", "") == "北京")
	failed += _check("temperature", int(info.get("temperature", -1)) == 26)
	failed += _check("code", int(info.get("code", -1)) == 0)
	failed += _check("is day", info.get("isDay", false) == true)
	failed += _check("description", info.get("description", "") == "晴朗")
	failed += _check("emoji", info.get("emoji", "") == "☀️")
	failed += _check("gear", info.get("gear", []) == ["shades", "juice"])
	failed += _check("fx", info.get("fx", []) == ["sun"])
	failed += _check("dress line", not str(info.get("dressLine", "")).is_empty())

	var bubbled := {"payload": {}}
	wc.bubble_requested.connect(func(payload: Dictionary) -> void:
		bubbled.payload = payload
	)
	wc.quiet_bubble()
	var quiet_text := str(bubbled.payload.get("text", ""))
	failed += _check(
		"quiet copy",
		quiet_text.ends_with("：外网有点安静，我稍后再探探天气和新闻。")
		and quiet_text.contains("：")
	)
	failed += _check("quiet text", not quiet_text.is_empty())
	failed += _check("quiet kind", bubbled.payload.get("kind", "") == "info")
	failed += _check("quiet url", bubbled.payload.get("url", "missing") == "")

	wc.apply_weather(info)
	failed += _check("last weather city", wc.last_weather.get("cityName", "") == "北京")
	failed += _check("last dress gear", wc.last_dress.get("gear", []) == info.gear)
	failed += _check("last dress fx", wc.last_dress.get("fx", []) == info.fx)

	var source := FileAccess.get_file_as_string("res://autoload/weather_client.gd")
	failed += _check("headless skip", source.contains('DisplayServer.get_name()=="headless"'))
	failed += _check("weather interval", source.contains("20 * 60") or source.contains("20*60"))
	failed += _check("push interval", source.contains("pushIntervalMin"))
	failed += _check(
		"open meteo url",
		source.contains(
			"https://api.open-meteo.com/v1/forecast?latitude="
		)
		and source.contains("current=temperature_2m,weather_code,is_day,wind_speed_10m")
		and source.contains("timezone=Asia/Shanghai")
	)
	failed += _check("send dress", source.contains("send_dress"))
	failed += _check("connected guard", source.contains("connected"))
	failed += _check("uses dress_for", source.contains("dress_for"))
	failed += _check("uses quiet_line", source.contains("quiet_line"))
	failed += _check("uses news_line", source.contains("news_line"))
	failed += _check("uses feeds", source.contains("items_from_feed") and source.contains("pick_item"))
	failed += _check("no zhihu", not source.contains("zhihu"))

	var project := FileAccess.get_file_as_string("res://project.godot")
	failed += _check(
		"autoload after room",
		project.contains("RoomClient=\"*res://autoload/room_client.gd\"")
		and project.contains("WeatherClient=\"*res://autoload/weather_client.gd\"")
		and project.find("WeatherClient=") > project.find("RoomClient=")
		and project.find("WeatherClient=") < project.find("WindowHub=")
	)
	failed += _check(
		"embed kept",
		project.contains("window/subwindows/embed_subwindows=false")
	)

	var panel := FileAccess.get_file_as_string("res://windows/panel_window.gd")
	failed += _check("panel refresh hook", panel.contains("refresh_after_settings"))

	wc.free()
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("weather_client: %s" % label)
	return 1
