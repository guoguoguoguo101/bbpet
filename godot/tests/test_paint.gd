extends RefCounted

const PlacePaint = preload("res://school/paint.gd")
const SchoolLogic = preload("res://school/school_logic.gd")


func run() -> int:
	var failed := 0
	var campus: Dictionary = SchoolLogic.PLACES["school:campus"]
	var img: Image = PlacePaint.image_for(campus)
	var size: Dictionary = SchoolLogic.map_size(campus)
	failed += _check("w", img.get_width() == size.cols * SchoolLogic.TILE)
	failed += _check("h", img.get_height() == size.rows * SchoolLogic.TILE)
	var px: Color = img.get_pixel(12 * 32 + 16, 12 * 32 + 16)
	failed += _check("spawn tile not black", px.a > 0.5)
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("paint: %s" % label)
	return 1
