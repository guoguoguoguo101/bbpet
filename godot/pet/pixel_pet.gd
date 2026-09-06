class_name PixelPet
extends TextureRect

const PetTemplates = preload("res://pet/templates.gd")

@export var species := "cat"
@export var colors: Dictionary = PetTemplates.DEFAULT_COLORS["cat"].duplicate()
@export var pose := "idle"
@export var pixel_size := 4
@export var flip := false
@export var look_x := 0
@export var look_y := 0

var _image: Image

func _init() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	expand_mode = EXPAND_IGNORE_SIZE
	stretch_mode = STRETCH_KEEP_CENTERED

func redraw() -> void:
	var frame := PetTemplates.get_frame(species, pose)
	var safe_colors := PetTemplates.colors_for(species, colors)
	_image = PetTemplates.paint_image(frame, safe_colors, pixel_size)
	texture = ImageTexture.create_from_image(_image)
	flip_h = flip
	var control_size := Vector2(16 * pixel_size, 16 * pixel_size)
	custom_minimum_size = control_size
	size = control_size

func current_image() -> Image:
	return _image
