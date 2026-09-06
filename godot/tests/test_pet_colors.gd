extends RefCounted

const PetColors = preload("res://pet/colors.gd")


func run() -> int:
	var failed := 0
	var palette: Dictionary = PetColors.palette_from_primary("#4488cc", "", "blob")
	failed += _check("has body", palette.body == "#4488cc")
	failed += _check("has outline", palette.has("outline") and String(palette.outline).begins_with("#"))
	failed += _check("has blush", palette.has("blush"))
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.2, 0.2))
	var extracted: Dictionary = PetColors.extract_palette(image, "cat")
	failed += _check("extract body", extracted.has("body") and extracted.has("outline"))
	failed += _check("extract not empty", String(extracted.body).length() == 7)
	var empty: Dictionary = PetColors.extract_palette(Image.create(2, 2, false, Image.FORMAT_RGBA8), "blob")
	failed += _check("transparent fallback", empty.body == PetTemplates.DEFAULT_COLORS["blob"].body)
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("pet_colors: %s" % label)
	return 1
