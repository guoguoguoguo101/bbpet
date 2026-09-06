extends Node

signal weather_changed(info: Dictionary)
signal bubble_requested(payload: Dictionary)

const DressLogic = preload("res://weather/dress_logic.gd")
const WeatherFeeds = preload("res://weather/feeds.gd")
const WEATHER_SECONDS := 20 * 60
const OPEN_METEO := (
	"https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s"
	+ "&current=temperature_2m,weather_code,is_day,wind_speed_10m&timezone=Asia/Shanghai"
)

var last_weather: Dictionary = {}
var last_dress: Dictionary = {}

var _push_tick := 0
var _weather_timer: Timer
var _push_timer: Timer


func _ready() -> void:
	_weather_timer = Timer.new()
	_weather_timer.one_shot = false
	add_child(_weather_timer)
	_weather_timer.timeout.connect(_on_weather_timer)
	_push_timer = Timer.new()
	_push_timer.one_shot = false
	add_child(_push_timer)
	_push_timer.timeout.connect(_on_push_timer)
	if DisplayServer.get_name()=="headless":
		return
	refresh_after_settings()


func parse_weather_payload(city_name: String, data: Dictionary) -> Dictionary:
	var current: Variant = data.get("current")
	if not current is Dictionary:
		return {}
	var temperature := roundi(float(current.get("temperature_2m", 0)))
	var code := int(current.get("weather_code", -1))
	var is_day := int(current.get("is_day", 1)) != 0
	var wind := float(current.get("wind_speed_10m", 0.0))
	var mapped: Dictionary = DressLogic.WEATHER_MAP.get(code, {
		"description": "天气微妙",
		"emoji": "🌈",
	})
	var dressed: Dictionary = DressLogic.dress_for(code, float(temperature), is_day, wind)
	return {
		"cityName": city_name,
		"temperature": temperature,
		"code": code,
		"isDay": is_day,
		"wind": wind,
		"description": str(mapped.get("description", "天气微妙")),
		"emoji": str(mapped.get("emoji", "🌈")),
		"gear": dressed.get("gear", []),
		"fx": dressed.get("fx", []),
		"dressLine": str(dressed.get("dressLine", "")),
	}


func apply_weather(info: Dictionary) -> void:
	last_weather = info.duplicate(true)
	var gear: Variant = info.get("gear", [])
	var fx: Variant = info.get("fx", [])
	last_dress = {
		"gear": gear.duplicate() if gear is Array else [],
		"fx": fx.duplicate() if fx is Array else [],
	}
	weather_changed.emit(last_weather)
	var room := _named_autoload("RoomClient")
	if room != null and room.connected:
		room.send_dress(last_dress)


func request_bubble(kind: String, text: String, url: String = "") -> void:
	bubble_requested.emit({"kind": kind, "text": text, "url": url})


func quiet_bubble() -> void:
	var pet_name := ""
	var app := _named_autoload("AppState")
	if app != null:
		pet_name = str(app.state.pet.name)
	request_bubble("info", DressLogic.quiet_line(pet_name))


func refresh_after_settings() -> void:
	_push_tick = 0
	if _weather_timer == null or _push_timer == null:
		return
	_weather_timer.stop()
	_push_timer.stop()
	_weather_timer.wait_time = float(WEATHER_SECONDS)
	var minutes := 30
	var app := _named_autoload("AppState")
	if app != null:
		minutes = int(app.state.settings.pushIntervalMin)
	_push_timer.wait_time = float(DressLogic.clamp_push_minutes(minutes) * 60)
	if DisplayServer.get_name()=="headless":
		return
	_weather_timer.start()
	_push_timer.start()
	_fetch_weather(false)


func _on_weather_timer() -> void:
	_fetch_weather(false)


func _on_push_timer() -> void:
	var even := _push_tick % 2 == 0
	_push_tick += 1
	if even:
		_fetch_weather(true)
	else:
		_fetch_news()


func _fetch_weather(with_bubble: bool) -> void:
	if DisplayServer.get_name()=="headless":
		return
	var app := _named_autoload("AppState")
	if app == null:
		if with_bubble:
			quiet_bubble()
		return
	var settings: Dictionary = app.state.settings
	var body := await _get_text(OPEN_METEO % [str(settings.latitude), str(settings.longitude)])
	var json := JSON.new()
	if body.is_empty() or json.parse(body) != OK or not json.data is Dictionary:
		if with_bubble:
			quiet_bubble()
		return
	var payload: Dictionary = json.data
	if not payload.get("current") is Dictionary:
		if with_bubble:
			quiet_bubble()
		return
	var parsed: Dictionary = parse_weather_payload(str(settings.cityName), payload)
	if parsed.is_empty():
		if with_bubble:
			quiet_bubble()
		return
	apply_weather(parsed)
	if with_bubble:
		request_bubble("weather", str(parsed.get("dressLine", "")))


func _fetch_news() -> void:
	if DisplayServer.get_name()=="headless":
		return
	for feed in WeatherFeeds.FEEDS:
		var xml := await _get_text(str(feed.url))
		if xml.is_empty():
			continue
		var item: Dictionary = WeatherFeeds.pick_item(
			WeatherFeeds.items_from_feed(xml, str(feed.source))
		)
		if item.is_empty():
			continue
		request_bubble(
			"news",
			DressLogic.news_line(
				str(_pet_name()),
				str(item.get("source", "")),
				str(item.get("title", ""))
			),
			str(item.get("url", ""))
		)
		return
	quiet_bubble()


func _get_text(url: String) -> String:
	if DisplayServer.get_name()=="headless":
		return ""
	var http := HTTPRequest.new()
	http.timeout = 12
	add_child(http)
	var err := http.request(
		url,
		PackedStringArray(["User-Agent: BbPet/1.0 (internal desktop pet)"])
	)
	if err != OK:
		http.queue_free()
		return ""
	var completed: Array = await http.request_completed
	http.queue_free()
	var result: int = completed[0]
	var code: int = completed[1]
	var body: PackedByteArray = completed[3]
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		return ""
	return body.get_string_from_utf8()


func _pet_name() -> String:
	var app := _named_autoload("AppState")
	if app == null:
		return ""
	return str(app.state.pet.name)


func _named_autoload(node_name: String) -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/%s" % node_name)
	return null
