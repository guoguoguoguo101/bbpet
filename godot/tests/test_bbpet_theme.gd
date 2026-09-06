extends RefCounted

const BbPetTheme = preload("res://ui/bbpet_theme.gd")


func run() -> int:
	var failed := 0
	failed += _check("ink", BbPetTheme.INK == Color("#3d2c29"))
	failed += _check("bg", BbPetTheme.BG == Color("#fff8f2"))
	failed += _check("mint", BbPetTheme.MINT == Color("#c8f5e4"))
	failed += _check("yellow", BbPetTheme.YELLOW == Color("#ffe8a3"))
	failed += _check("hint", BbPetTheme.HINT == Color("#7a5a52"))
	failed += _check("game board", BbPetTheme.GAME_BOARD == Color("#d7b07a"))
	failed += _check("stone last", BbPetTheme.STONE_LAST == Color("#e76f51"))
	failed += _check("stone win", BbPetTheme.STONE_WIN == Color("#2f6f5e"))
	var main: StyleBoxFlat = BbPetTheme.button_style("main")
	failed += _check("main bg", main.bg_color == BbPetTheme.MINT)
	failed += _check("main radius", main.corner_radius_top_left == 12)
	failed += _check("main border", main.border_width_left == 2 and main.border_color == BbPetTheme.INK)
	var pill: StyleBoxFlat = BbPetTheme.button_style("pill")
	failed += _check("pill bg", pill.bg_color == BbPetTheme.YELLOW)
	var hub: StyleBoxFlat = BbPetTheme.button_style("hub")
	failed += _check("hub bg", hub.bg_color == BbPetTheme.CREAM)
	var field: StyleBoxFlat = BbPetTheme.input_style()
	failed += _check("input bg", field.bg_color == BbPetTheme.CREAM)
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("bbpet_theme: %s" % label)
	return 1
