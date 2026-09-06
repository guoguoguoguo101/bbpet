class_name PetColors
extends RefCounted

const PetTemplates = preload("res://pet/templates.gd")


static func palette_from_primary(primary: String, accent: String, species: String) -> Dictionary:
	var fallback: Dictionary = PetTemplates.DEFAULT_COLORS[species if PetTemplates.DEFAULT_COLORS.has(species) else "blob"]
	var body := primary if not primary.is_empty() else String(fallback.body)
	var accent_hex := accent if not accent.is_empty() else _mix(body, "#E76F51", 0.35)
	return {
		"outline": _mix(body, "#1A1210", 0.62),
		"body": body,
		"shadow": _mix(body, "#2A1814", 0.28),
		"light": _mix(body, "#FFF8F2", 0.45),
		"accent": accent_hex,
		"eye": "#FFF8F0",
		"pupil": "#2B211E",
		"blush": _mix(body, "#FF8FAB", 0.4),
	}


static func extract_palette(image: Image, species: String) -> Dictionary:
	if image == null or image.is_empty():
		return PetTemplates.DEFAULT_COLORS[species if PetTemplates.DEFAULT_COLORS.has(species) else "blob"].duplicate(true)
	var scaled := Image.new()
	scaled.copy_from(image)
	scaled.resize(48, 48, Image.INTERPOLATE_NEAREST)
	var buckets: Dictionary = {}
	for y in scaled.get_height():
		for x in scaled.get_width():
			var color := scaled.get_pixel(x, y)
			if color.a < 140.0 / 255.0:
				continue
			var r := int(round(color.r * 255.0))
			var g := int(round(color.g * 255.0))
			var b := int(round(color.b * 255.0))
			var mx := maxi(r, maxi(g, b))
			var mn := mini(r, mini(g, b))
			if mx < 40 or mn > 230:
				continue
			if mx - mn < 18 and mx > 180:
				continue
			var key := "%d-%d-%d" % [roundi(float(r) / 24.0), roundi(float(g) / 24.0), roundi(float(b) / 24.0)]
			var current: Dictionary = buckets.get(key, {"count": 0, "r": 0, "g": 0, "b": 0})
			current.count = int(current.count) + 1
			current.r = int(current.r) + r
			current.g = int(current.g) + g
			current.b = int(current.b) + b
			buckets[key] = current
	if buckets.is_empty():
		return PetTemplates.DEFAULT_COLORS[species if PetTemplates.DEFAULT_COLORS.has(species) else "blob"].duplicate(true)
	var ranked: Array = buckets.values()
	ranked.sort_custom(func(a, b): return int(a.count) > int(b.count))
	var main: Dictionary = ranked[0]
	var primary := _rgb_to_hex(int(main.r) / float(main.count), int(main.g) / float(main.count), int(main.b) / float(main.count))
	var accent := ""
	var primary_lum := _luminance(primary)
	for item in ranked:
		var hex := _rgb_to_hex(int(item.r) / float(item.count), int(item.g) / float(item.count), int(item.b) / float(item.count))
		if absf(_luminance(hex) - primary_lum) > 28.0:
			accent = hex
			break
	return palette_from_primary(primary, accent, species)


static func _hex_to_rgb(hex: String) -> Dictionary:
	var raw := hex.replace("#", "")
	if raw.length() < 6:
		return {"r": 0, "g": 0, "b": 0}
	return {
		"r": raw.substr(0, 2).hex_to_int(),
		"g": raw.substr(2, 2).hex_to_int(),
		"b": raw.substr(4, 2).hex_to_int(),
	}


static func _rgb_to_hex(r: float, g: float, b: float) -> String:
	return "#%02x%02x%02x" % [_clamp_byte(r), _clamp_byte(g), _clamp_byte(b)]


static func _clamp_byte(value: float) -> int:
	return clampi(int(round(value)), 0, 255)


static func _mix(hex: String, toward: String, amount: float) -> String:
	var a := _hex_to_rgb(hex)
	var b := _hex_to_rgb(toward)
	return _rgb_to_hex(
		float(a.r) + (float(b.r) - float(a.r)) * amount,
		float(a.g) + (float(b.g) - float(a.g)) * amount,
		float(a.b) + (float(b.b) - float(a.b)) * amount
	)


static func _luminance(hex: String) -> float:
	var rgb := _hex_to_rgb(hex)
	return (float(rgb.r) * 299.0 + float(rgb.g) * 587.0 + float(rgb.b) * 114.0) / 1000.0
