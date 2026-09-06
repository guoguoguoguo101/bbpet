class_name WeatherDress
extends Control

# Geometric stand-ins for Electron WeatherDress CSS classes (not pixel-perfect).

const PET := Vector2(64, 64)
const RAIN_N := 9
const STORM_RAIN_N := 14
const SNOW_N := 8
const SUN_N := 5
const STARS := [
	{"left": 2, "top": 0, "size": 11},
	{"left": 20, "top": 8, "size": 5},
	{"left": 42, "top": 2, "size": 7},
	{"left": 68, "top": 10, "size": 5},
	{"left": 86, "top": 1, "size": 11},
	{"left": 10, "top": 18, "size": 5},
	{"left": 58, "top": 16, "size": 7},
	{"left": 78, "top": 20, "size": 5},
]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = PET
	size = PET
	_build()
	apply({})


func apply(dress: Dictionary) -> void:
	var gear: Array = _as_array(dress.get("gear", []))
	var fx: Array = _as_array(dress.get("fx", []))
	_set_visible("raincoat", gear.has("raincoat"))
	_set_visible("umbrella", gear.has("umbrella"))
	_set_visible("beanie", gear.has("beanie"))
	_set_visible("scarf", gear.has("scarf"))
	_set_visible("snowman", gear.has("snowman"))
	_set_visible("juice", gear.has("juice"))
	_set_visible("shades", gear.has("shades"))
	_set_visible("fog", fx.has("fog"))
	_set_visible("storm", fx.has("storm"))
	_set_visible("wind", fx.has("wind"))
	_set_visible("cloud", fx.has("cloud"))
	_set_visible("sun", fx.has("sun"))
	_set_visible("stars", fx.has("stars"))
	var raining := fx.has("rain")
	var rain_n := STORM_RAIN_N if fx.has("storm") else RAIN_N
	_show_particles("rain", raining, rain_n)
	_show_particles("snow", fx.has("snow"), SNOW_N)
	_show_particles("sun", fx.has("sun"), SUN_N)


func opaque_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	_collect_rects(self, Vector2.ZERO, rects)
	return rects


func _build() -> void:
	_add_rect("raincoat", Rect2(8, 20, 48, 36), Color("#F4D35E"))
	_add_rect("umbrella", Rect2(10, -2, 44, 18), Color("#e76f51"))
	_add_rect("beanie", Rect2(8, 0, 48, 10), Color("#c45c26"))
	_add_rect("scarf", Rect2(8, 32, 48, 12), Color("#c23b22"))
	_add_rect("juice", Rect2(52, 27, 11, 15), Color("#ff8a3d"))
	_add_rect("shades", Rect2(16, 18, 32, 8), Color("#2b211e"))
	_add_rect("fog", Rect2(0, 0, 64, 64), Color(1, 1, 1, 0.55))
	_add_rect("storm", Rect2(0, 40, 64, 8), Color("#3d2c29"))
	_build_snowman()
	_build_rain()
	_build_snow()
	_build_sun()
	_build_stars()
	_build_clouds()
	_build_wind()


func _build_snowman() -> void:
	var root := _group("snowman")
	root.position = Vector2(-4, 14)
	root.size = Vector2(24, 34)
	root.add_child(_rect("hat", Rect2(7, 0, 10, 6), Color("#2b211e")))
	root.add_child(_rect("head", Rect2(6, 7, 12, 12), Color("#ffffff")))
	root.add_child(_rect("body", Rect2(3, 16, 18, 16), Color("#ffffff")))
	root.add_child(_rect("arm_left", Rect2(0, 20, 9, 2), Color("#8a5a32")))
	root.add_child(_rect("arm_right", Rect2(15, 20, 9, 2), Color("#8a5a32")))


func _build_rain() -> void:
	var root := _group("rain")
	for i in STORM_RAIN_N:
		var drop := _rect("drop_%d" % i, Rect2(_bit_x(i), float((i * 11) % 40), 2, 8), Color("#7ec8e3"))
		root.add_child(drop)


func _build_snow() -> void:
	var root := _group("snow")
	for i in SNOW_N:
		var flake := _rect("flake_%d" % i, Rect2(_bit_x(i), float((i * 13) % 36), 4, 4), Color("#ffffff"))
		root.add_child(flake)


func _build_sun() -> void:
	var root := _group("sun")
	for i in SUN_N:
		var spark := _rect(
			"spark_%d" % i,
			Rect2(_bit_x(i), 8.0 + float(i % 3) * 10.0, 5, 5),
			Color("#ffe566")
		)
		root.add_child(spark)


func _build_stars() -> void:
	var root := _group("stars")
	root.add_child(_rect("moon", Rect2(44, 0, 18, 18), Color("#ffe566")))
	for i in STARS.size():
		var star: Dictionary = STARS[i]
		var side := float(star.size)
		root.add_child(
			_rect(
				"star_%d" % i,
				Rect2(PET.x * float(star.left) / 100.0, float(star.top), side, side),
				Color("#fff6a3")
			)
		)


func _build_clouds() -> void:
	var root := _group("cloud")
	root.add_child(_rect("a", Rect2(2, 8, 24, 10), Color("#ffffff")))
	root.add_child(_rect("b", Rect2(36, 2, 20, 10), Color("#ffffff")))
	root.add_child(_rect("c", Rect2(18, 0, 26, 10), Color("#ffffff")))


func _build_wind() -> void:
	var root := _group("wind")
	root.add_child(_rect("dash_0", Rect2(4, 22, 18, 2), Color("#cfd8e6")))
	root.add_child(_rect("dash_1", Rect2(28, 30, 22, 2), Color("#cfd8e6")))
	root.add_child(_rect("dash_2", Rect2(12, 40, 16, 2), Color("#cfd8e6")))


func _show_particles(group_name: String, shown: bool, count: int) -> void:
	var group := get_node_or_null(group_name)
	if group == null:
		return
	group.visible = shown
	var index := 0
	for child in group.get_children():
		child.visible = shown and index < count
		index += 1


func _set_visible(node_name: String, shown: bool) -> void:
	var node := get_node_or_null(node_name)
	if node != null:
		node.visible = shown


func _group(node_name: String) -> Control:
	var group := Control.new()
	group.name = node_name
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.position = Vector2.ZERO
	group.size = PET
	add_child(group)
	return group


func _add_rect(node_name: String, rect: Rect2, color: Color) -> ColorRect:
	var node := _rect(node_name, rect, color)
	add_child(node)
	return node


func _rect(node_name: String, rect: Rect2, color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.name = node_name
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _bit_x(index: int) -> float:
	return PET.x * (8.0 + float((index * 37) % 84)) / 100.0


func _as_array(value: Variant) -> Array:
	return value if value is Array else []


func _collect_rects(node: Node, origin: Vector2, rects: Array[Rect2]) -> void:
	if node is Control:
		var control := node as Control
		if node != self and not control.visible:
			return
		if node != self:
			if control is ColorRect and (control as ColorRect).color.a > 0.5:
				rects.append(Rect2(origin + control.position, control.size))
			origin += control.position
	for child in node.get_children():
		_collect_rects(child, origin, rects)
