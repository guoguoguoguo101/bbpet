extends RefCounted

const PetTemplates = preload("res://pet/templates.gd")

const EXPECTED_LABELS := {
	"cat": "小猫",
	"dog": "小狗",
	"rabbit": "兔子",
	"bird": "小鸟",
	"hamster": "仓鼠",
	"blob": "软萌团",
}

const EXPECTED_COLORS := {
	"cat": {"outline": "#3D2C29", "body": "#F4A261", "shadow": "#E0762F", "light": "#FFE0B8", "accent": "#E76F51", "eye": "#FFF8F0", "pupil": "#2B211E", "blush": "#FFB4C8"},
	"dog": {"outline": "#3D2C29", "body": "#D4A373", "shadow": "#B07D4F", "light": "#F5E1C8", "accent": "#8B5E3C", "eye": "#FFF8F0", "pupil": "#2B211E", "blush": "#FFB4C8"},
	"rabbit": {"outline": "#3D2C29", "body": "#F3D6D8", "shadow": "#E2B3B8", "light": "#FFF4F5", "accent": "#E8919A", "eye": "#FFF8F0", "pupil": "#2B211E", "blush": "#FFB4C8"},
	"bird": {"outline": "#3D2C29", "body": "#8ED8C4", "shadow": "#5FB89F", "light": "#E4FFF6", "accent": "#F4A261", "eye": "#FFF8F0", "pupil": "#2B211E", "blush": "#FFB4C8"},
	"hamster": {"outline": "#3D2C29", "body": "#F2C6A0", "shadow": "#D59A6A", "light": "#FFE9D2", "accent": "#E76F51", "eye": "#FFF8F0", "pupil": "#2B211E", "blush": "#FFB4C8"},
	"blob": {"outline": "#3D2C29", "body": "#FFC2D4", "shadow": "#F49AB3", "light": "#FFE6F0", "accent": "#FF8FAB", "eye": "#FFF8F0", "pupil": "#2B211E", "blush": "#FF9EBB"},
}

func run() -> int:
	var failed := 0
	failed += _check("six species", PetTemplates.SPECIES.size() == 6)
	failed += _check("species order", PetTemplates.SPECIES == PackedStringArray(["cat", "dog", "rabbit", "bird", "hamster", "blob"]))
	failed += _check("labels", PetTemplates.SPECIES_LABELS == EXPECTED_LABELS)
	failed += _check("colors", PetTemplates.DEFAULT_COLORS == EXPECTED_COLORS)
	for species in PetTemplates.SPECIES:
		var idle: PackedStringArray = PetTemplates.get_frame(species, "idle")
		var blink: PackedStringArray = PetTemplates.get_frame(species, "blink")
		failed += _check("%s idle dimensions" % species, _is_16_square(idle))
		failed += _check("%s blink dimensions" % species, _is_16_square(blink))
		failed += _check("%s blink differs" % species, blink != idle)
	var fallback: PackedStringArray = PetTemplates.get_frame("blob", "wave")
	failed += _check("unknown pose falls back to idle", fallback == PetTemplates.get_frame("blob", "idle"))
	var frame: PackedStringArray = PetTemplates.get_frame("blob", "idle")
	var image: Image = PetTemplates.paint_image(frame, PetTemplates.DEFAULT_COLORS["blob"], 4)
	failed += _check("paint size", image.get_width() == 64 and image.get_height() == 64)
	failed += _check("transparent background", image.get_pixel(0, 0).a == 0.0)
	failed += _check("painted outline", image.get_pixel(16, 4) == Color.html("#3D2C29"))
	failed += _check("opaque pixels", PetTemplates.opaque_count(image) > 0)
	return failed

func _is_16_square(frame: PackedStringArray) -> bool:
	if frame.size() != 16:
		return false
	for row in frame:
		if row.length() != 16:
			return false
	return true

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("templates: %s" % label)
	return 1
