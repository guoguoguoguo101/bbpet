extends Control

const PET_SIZE := Vector2i(64, 86)
const PET_OFFSET := Vector2(0, 11)
const DRAG_THRESHOLD := 4.0
const MENU_HIDE := 0
const MENU_QUIT := 1

@onready var pixel_pet := $PixelPet
@onready var context_menu: PopupMenu = $ContextMenu

var _dragging := false
var _press_position := Vector2i.ZERO


func _ready() -> void:
	var win := get_window()
	win.borderless = true
	win.unresizable = true
	win.always_on_top = true
	win.transparent = true
	win.size = PET_SIZE
	var usable_area := DisplayServer.screen_get_usable_rect()
	win.position = Vector2i(usable_area.end.x - 72, usable_area.end.y - 94)

	pixel_pet.position = PET_OFFSET
	var pet: Dictionary = AppState.state.pet
	pixel_pet.species = pet.species
	pixel_pet.colors = pet.colors.duplicate(true)
	pixel_pet.pixel_size = 4
	_set_pose("idle")

	context_menu.add_item("隐藏", MENU_HIDE)
	context_menu.add_item("退出", MENU_QUIT)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	_blink_loop()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_dragging = false
				_press_position = DisplayServer.mouse_get_position()
				accept_event()
			else:
				if not _dragging:
					WindowHub.toggle_panel()
				_dragging = false
				accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT and not button.pressed:
			context_menu.position = DisplayServer.mouse_get_position()
			context_menu.popup()
			accept_event()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var motion := event as InputEventMouseMotion
		if not _dragging:
			var mouse_position := DisplayServer.mouse_get_position()
			_dragging = Vector2(mouse_position - _press_position).length() > DRAG_THRESHOLD
		if _dragging:
			get_window().position += Vector2i(motion.relative.round())
			accept_event()


func _set_pose(next_pose: String) -> void:
	pixel_pet.pose = next_pose
	pixel_pet.redraw()
	_update_passthrough()


func _blink_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(2.5, 4.5)).timeout
		if not is_inside_tree():
			return
		_set_pose("blink")
		await get_tree().create_timer(0.12).timeout
		if not is_inside_tree():
			return
		_set_pose("idle")


func _update_passthrough() -> void:
	var image: Image = pixel_pet.current_image()
	if image == null:
		get_window().mouse_passthrough = false
		return

	var unique_points := {}
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.5:
				continue
			for corner in [
				Vector2i(x, y),
				Vector2i(x + 1, y),
				Vector2i(x, y + 1),
				Vector2i(x + 1, y + 1),
			]:
				unique_points[corner] = true

	var points: Array[Vector2] = []
	for point: Vector2i in unique_points:
		points.append(Vector2(point) + pixel_pet.position)
	var hull := _convex_hull(points)
	if hull.size() < 3:
		get_window().mouse_passthrough = false
		get_window().mouse_passthrough_polygon = PackedVector2Array()
		return
	get_window().mouse_passthrough = true
	get_window().mouse_passthrough_polygon = hull


func _convex_hull(points: Array[Vector2]) -> PackedVector2Array:
	if points.size() < 3:
		return PackedVector2Array(points)
	points.sort_custom(
		func(a: Vector2, b: Vector2) -> bool:
			return a.x < b.x or (a.x == b.x and a.y < b.y)
	)

	var lower: Array[Vector2] = []
	for point in points:
		while lower.size() >= 2 and _cross(lower[-2], lower[-1], point) <= 0.0:
			lower.pop_back()
		lower.append(point)

	var upper: Array[Vector2] = []
	for index in range(points.size() - 1, -1, -1):
		var point := points[index]
		while upper.size() >= 2 and _cross(upper[-2], upper[-1], point) <= 0.0:
			upper.pop_back()
		upper.append(point)

	lower.pop_back()
	upper.pop_back()
	lower.append_array(upper)
	return PackedVector2Array(lower)


func _cross(origin: Vector2, a: Vector2, b: Vector2) -> float:
	return (a - origin).cross(b - origin)


func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		MENU_HIDE:
			WindowHub.hide_pet()
		MENU_QUIT:
			WindowHub.quit_app()
