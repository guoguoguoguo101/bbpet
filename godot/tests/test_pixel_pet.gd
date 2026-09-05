extends RefCounted

func run() -> int:
	var failed := 0
	var pet: TextureRect = preload("res://pet/pixel_pet.tscn").instantiate()
	pet.species = "cat"
	pet.colors = PetTemplates.DEFAULT_COLORS["cat"]
	pet.pose = "idle"
	pet.pixel_size = 2
	pet.redraw()
	var img: Image = pet.current_image()
	failed += _check("school size", img.get_width() == 32)
	failed += _check("opaque", PetTemplates.opaque_count(img) > 0)
	pet.queue_free()
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("pixel_pet: %s" % label)
	return 1
