extends Window

const HomeLogic = preload("res://home/home_logic.gd")
const PixelPetScene = preload("res://pet/pixel_pet.tscn")

var _pet: PixelPet
var _tween: Tween
var _token := 0


func _init() -> void:
	borderless = true
	unresizable = true
	always_on_top = true
	transparent = true
	transparent_bg = true
	unfocusable = true
	mouse_passthrough = true
	visible = false
	size = Vector2i(HomeLogic.FLYER_SIZE, HomeLogic.FLYER_SIZE)
	title = " "


func _ready() -> void:
	_pet = PixelPetScene.instantiate()
	_pet.pixel_size = 6
	_pet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pet)


func play(payload: Dictionary) -> void:
	_token += 1
	var token := _token
	if _tween != null:
		_tween.kill()
	var species := String(payload.get("species", "blob"))
	_pet.species = species
	_pet.colors = payload.get("colors", {})
	_pet.pose = String(payload.get("pose", "peek"))
	_pet.redraw()
	var start: Vector2 = payload.get("start", Vector2.ZERO)
	var dest: Vector2 = payload.get("dest", start)
	var duration := clampf(float(payload.get("duration", 2800)) / 1000.0, 0.8, 4.0)
	position = Vector2i(int(start.x), int(start.y))
	show()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_tween.tween_method(_move.bind(start, dest, token), 0.0, 1.0, duration)
	_tween.finished.connect(_on_done.bind(token))


func _move(t: float, start: Vector2, dest: Vector2, token: int) -> void:
	if token != _token:
		return
	var point := HomeLogic.flyer_point(t, start, dest)
	position = Vector2i(int(round(point.x)), int(round(point.y)))


func _on_done(token: int) -> void:
	if token != _token:
		return
	hide()
	if WindowHub.has_method("flyer_finished"):
		WindowHub.flyer_finished()


func dismiss() -> void:
	_token += 1
	if _tween != null:
		_tween.kill()
		_tween = null
	hide()
