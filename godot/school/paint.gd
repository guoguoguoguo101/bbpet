# 源：src/world/paint.ts
class_name PlacePaint
extends RefCounted


static func image_for(place: Dictionary) -> Image:
	var map_size := SchoolLogic.map_size(place)
	var width: int = map_size.cols * SchoolLogic.TILE
	var height: int = map_size.rows * SchoolLogic.TILE
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var kind: String = place.kind

	for ty in map_size.rows:
		for tx in map_size.cols:
			var code := SchoolLogic.tile_at(place, tx, ty)
			var tile_rect := Rect2i(
				tx * SchoolLogic.TILE,
				ty * SchoolLogic.TILE,
				SchoolLogic.TILE,
				SchoolLogic.TILE
			)
			image.fill_rect(tile_rect, Color(SchoolLogic.tile_color(code, kind)))
			_stroke_rect(image, tile_rect.grow(-1), Color(SchoolLogic.tile_accent(code)), 2)
			if kind == "campus" and code == "f" and ty == 2:
				var inner := tile_rect.grow(-8)
				image.fill_rect(inner, Color("#8ecae6"))
				_stroke_rect(image, inner, Color("#3d2c29"), 1)

	return image


static func _stroke_rect(image: Image, rect: Rect2i, color: Color, width: int) -> void:
	image.fill_rect(Rect2i(rect.position, Vector2i(rect.size.x, width)), color)
	image.fill_rect(
		Rect2i(rect.position + Vector2i(0, rect.size.y - width), Vector2i(rect.size.x, width)),
		color
	)
	image.fill_rect(Rect2i(rect.position, Vector2i(width, rect.size.y)), color)
	image.fill_rect(
		Rect2i(rect.position + Vector2i(rect.size.x - width, 0), Vector2i(width, rect.size.y)),
		color
	)
