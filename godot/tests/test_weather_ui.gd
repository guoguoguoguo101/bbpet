extends RefCounted


func run() -> int:
	var failed := 0
	var pet_src := FileAccess.get_file_as_string("res://windows/pet_root.gd")
	var dress_src := FileAccess.get_file_as_string("res://weather/weather_dress.gd")
	var hub_src := FileAccess.get_file_as_string("res://autoload/window_hub.gd")

	failed += _check("WeatherDress source", dress_src.contains("class_name WeatherDress"))
	failed += _check("apply API", dress_src.contains("func apply"))
	failed += _check("raincoat marker", dress_src.contains("raincoat"))
	failed += _check("pet uses WeatherDress", pet_src.contains("WeatherDress"))
	failed += _check("weather_changed", pet_src.contains("weather_changed"))
	failed += _check("dress_updated", pet_src.contains("dress_updated"))
	failed += _check(
		"passthrough API",
		pet_src.contains("DisplayServer.window_set_mouse_passthrough")
	)
	failed += _check("passthrough still hull", pet_src.contains("_image_points"))
	failed += _check(
		"no FLYER",
		not pet_src.contains("FLYER")
		and not pet_src.contains("playFlyer")
		and not dress_src.contains("FLYER")
	)
	failed += _check("kick kept", pet_src.contains('["kick", "飞踢"]'))
	failed += _check("menu always on top", pet_src.contains("context_menu.always_on_top = true"))
	failed += _check(
		"tray idle without dress",
		hub_src.contains('get_frame(pet.species, "idle")')
		and not _setup_tray_mentions_dress(hub_src)
	)
	failed += _check("self last_dress", pet_src.contains("last_dress"))
	failed += _check("slot dresses lookup", pet_src.contains("dresses"))
	failed += _check(
		"slot dress falls back to person",
		_dress_for_falls_back_to_person(pet_src)
	)

	var world_src := FileAccess.get_file_as_string("res://windows/world_window.gd")
	failed += _check("school uses WeatherDress", world_src.contains("WeatherDress"))
	failed += _check("school dress_updated", world_src.contains("dress_updated"))
	failed += _check(
		"school apply person or cache",
		world_src.contains('get("dress"') or world_src.contains("person.dress")
	)

	var script: Variant = load("res://weather/weather_dress.gd")
	if script == null or not script is Script or not script.can_instantiate():
		push_error("weather_ui: missing WeatherDress script")
		return failed + 1
	var overlay: Control = script.new()
	failed += _check("is Control", overlay is Control)
	failed += _check("apply method", overlay.has_method("apply"))
	failed += _check("opaque rects API", overlay.has_method("opaque_rects"))

	overlay.apply({"gear": ["raincoat", "umbrella", "beanie", "scarf", "snowman", "juice", "shades"], "fx": []})
	failed += _check("raincoat visible", _node_visible(overlay, "raincoat"))
	failed += _check("umbrella visible", _node_visible(overlay, "umbrella"))
	failed += _check("beanie visible", _node_visible(overlay, "beanie"))
	failed += _check("scarf visible", _node_visible(overlay, "scarf"))
	failed += _check("snowman visible", _node_visible(overlay, "snowman"))
	failed += _check("juice visible", _node_visible(overlay, "juice"))
	failed += _check("shades visible", _node_visible(overlay, "shades"))
	failed += _check("empty fx hidden", not _node_visible(overlay, "rain") and not _node_visible(overlay, "snow"))

	overlay.apply({"gear": [], "fx": ["rain"]})
	failed += _check("raincoat hidden", not _node_visible(overlay, "raincoat"))
	var rain_n := _visible_particles(overlay, "rain")
	failed += _check("rain count", rain_n >= 8 and rain_n <= 14)

	overlay.apply({"gear": ["raincoat", "umbrella"], "fx": ["rain", "storm"]})
	failed += _check("storm raincoat", _node_visible(overlay, "raincoat"))
	var storm_rain := _visible_particles(overlay, "rain")
	failed += _check("storm rain count", storm_rain >= 8 and storm_rain <= 14)

	overlay.apply({"gear": ["beanie", "scarf", "snowman"], "fx": ["snow"]})
	var snow_n := _visible_particles(overlay, "snow")
	failed += _check("snow count", snow_n >= 8 and snow_n <= 14)
	failed += _check("snowman with snow", _node_visible(overlay, "snowman"))

	overlay.apply({"gear": [], "fx": []})
	failed += _check("cleared raincoat", not _node_visible(overlay, "raincoat"))
	failed += _check("cleared rain", _visible_particles(overlay, "rain") == 0)
	failed += _check("empty opaque", overlay.call("opaque_rects").is_empty())

	overlay.apply({"gear": ["umbrella"], "fx": []})
	var rects: Array = overlay.call("opaque_rects")
	failed += _check("umbrella opaque", not rects.is_empty())

	overlay.free()
	return failed


func _dress_for_falls_back_to_person(source: String) -> bool:
	var start := source.find("func _dress_for")
	if start < 0:
		return false
	var nxt := source.find("\nfunc ", start + 1)
	var body := source.substr(start, nxt - start if nxt > start else source.length() - start)
	return body.contains("dresses") and body.contains("home_people") and body.contains('get("dress"')


func _setup_tray_mentions_dress(source: String) -> bool:
	var start := source.find("func _setup_tray")
	if start < 0:
		return true
	var nxt := source.find("\nfunc ", start + 1)
	var body := source.substr(start, nxt - start if nxt > start else source.length() - start)
	return body.contains("dress") or body.contains("WeatherDress") or body.contains("last_dress")


func _node_visible(root: Node, node_name: String) -> bool:
	var node := root.get_node_or_null(node_name)
	return node != null and bool(node.get("visible"))


func _visible_particles(root: Node, group_name: String) -> int:
	var group := root.get_node_or_null(group_name)
	if group == null or not bool(group.get("visible")):
		return 0
	var count := 0
	for child in group.get_children():
		if bool(child.get("visible")):
			count += 1
	return count


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("weather_ui: %s" % label)
	return 1
