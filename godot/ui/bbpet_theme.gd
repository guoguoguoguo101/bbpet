class_name BbPetTheme
extends RefCounted

const INK := Color("#3d2c29")
const BG := Color("#fff8f2")
const BG_PINK := Color("#ffe6f0")
const CREAM := Color("#fffdf9")
const MINT := Color("#c8f5e4")
const YELLOW := Color("#ffe8a3")
const HINT := Color("#7a5a52")
const ERROR := Color("#c23b4a")
const ERROR_ALT := Color("#b3261e")
const GAME_BG := Color("#1c1410")
const GAME_BAR := Color("#2a1c18")
const GAME_BOARD := Color("#d7b07a")
const STONE_BLACK := Color("#2b211e")
const STONE_WHITE := Color("#fff8f2")
const STONE_LAST := Color("#e76f51")
const STONE_WIN := Color("#2f6f5e")
const GAME_HINT := Color("#e2b3b8")
const GAME_INK := Color("#3d2c29")


static func box(bg: Color, radius: int, border: int = 2, pad: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = INK
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.content_margin_left = float(pad)
	style.content_margin_right = float(pad)
	style.content_margin_top = float(pad) - 1.0
	style.content_margin_bottom = float(pad) - 1.0
	return style


static func button_style(kind: String) -> StyleBoxFlat:
	match kind:
		"main":
			return box(MINT, 12, 2, 10)
		"hub":
			return box(CREAM, 12, 2, 10)
		"ghost":
			return box(Color(0, 0, 0, 0), 999, 2, 6)
		"card":
			return box(BG, 18, 3, 8)
		_:
			return box(YELLOW, 999, 2, 8)


static func input_style() -> StyleBoxFlat:
	return box(CREAM, 12, 2, 8)


static func apply_button(button: Button, kind: String = "pill") -> void:
	var normal := button_style(kind)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", button_style("main" if kind == "pill" else kind))
	button.add_theme_stylebox_override("pressed", button_style("main"))
	button.add_theme_stylebox_override("disabled", button_style("ghost"))
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", HINT)
	button.add_theme_color_override("font_focus_color", INK)


static func apply_input(edit: Control) -> void:
	var style := input_style()
	edit.add_theme_stylebox_override("normal", style)
	edit.add_theme_stylebox_override("focus", style)
	if edit is LineEdit:
		edit.add_theme_stylebox_override("read_only", style)
	if edit is OptionButton:
		edit.add_theme_stylebox_override("hover", style)
		edit.add_theme_stylebox_override("pressed", style)
	edit.add_theme_color_override("font_color", INK)
	edit.add_theme_color_override("font_placeholder_color", HINT)


static func apply_hint(label: Label) -> void:
	label.add_theme_color_override("font_color", HINT)
	label.add_theme_font_size_override("font_size", 11)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func apply_heading(label: Label) -> void:
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", 13)


static func apply_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", button_style("card"))


static func apply_popup(menu: PopupMenu) -> void:
	menu.add_theme_stylebox_override("panel", box(BG, 12, 2, 6))
	menu.add_theme_stylebox_override("hover", box(YELLOW, 8, 0, 4))
	menu.add_theme_color_override("font_color", INK)
	menu.add_theme_color_override("font_hover_color", INK)
	menu.add_theme_color_override("font_separator_color", INK)
