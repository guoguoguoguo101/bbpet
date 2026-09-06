extends RefCounted

const WeatherCities = preload("res://weather/cities.gd")

func run() -> int:
	var failed := 0
	failed += _check("twelve cities", WeatherCities.CITIES.size() == 12)
	failed += _check("first beijing", WeatherCities.CITIES[0].id == "beijing")
	failed += _check("default", WeatherCities.DEFAULT_CITY.id == "beijing")
	failed += _check("lat", is_equal_approx(float(WeatherCities.DEFAULT_CITY.latitude), 39.9042))
	failed += _check("unknown", WeatherCities.by_id("nope").id == "beijing")
	failed += _check("shanghai", WeatherCities.by_id("shanghai").name == "上海")
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("cities: %s" % label)
	return 1
