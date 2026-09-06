extends Window

const GameView = preload("res://game/game_view.gd")
const BbPetTheme = preload("res://ui/bbpet_theme.gd")

var _held: Dictionary = {}
var _bar: Label
var _hint: Label
var _resign: Button
var _close: Button
var _board: BoardView
var _tick: Timer


func _init() -> void:
	title = "BbPet 五子棋"
	unresizable = true
	always_on_top = false
	transparent = false
	borderless = false
	unfocusable = false
	visible = false
	size = Vector2i(560, 640)


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = BbPetTheme.GAME_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var bar_panel := PanelContainer.new()
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = BbPetTheme.GAME_BAR
	bar_style.border_color = BbPetTheme.INK
	bar_style.border_width_bottom = 3
	bar_style.content_margin_left = 12.0
	bar_style.content_margin_right = 12.0
	bar_style.content_margin_top = 8.0
	bar_style.content_margin_bottom = 8.0
	bar_panel.add_theme_stylebox_override("panel", bar_style)
	root.add_child(bar_panel)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	bar_panel.add_child(head)
	_bar = Label.new()
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bar.add_theme_color_override("font_color", Color("#fff8f2"))
	head.add_child(_bar)
	_resign = Button.new()
	_resign.text = "认输"
	BbPetTheme.apply_button(_resign, "pill")
	_resign.pressed.connect(_on_resign)
	head.add_child(_resign)
	_close = Button.new()
	_close.text = "关闭"
	BbPetTheme.apply_button(_close, "pill")
	_close.pressed.connect(_on_close)
	head.add_child(_close)
	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 12)
	root.add_child(pad)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	pad.add_child(body)
	_board = BoardView.new()
	_board.custom_minimum_size = Vector2(GameView.BOARD, GameView.BOARD)
	_board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_board.gui_input.connect(_on_board_input)
	body.add_child(_board)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", BbPetTheme.GAME_HINT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_hint)
	_tick = Timer.new()
	_tick.wait_time = 0.2
	_tick.timeout.connect(_refresh)
	add_child(_tick)
	_tick.start()
	_refresh()


func present(game: Dictionary) -> void:
	if not game.is_empty():
		_held = game.duplicate(true)
	elif _room_connected():
		_held = {}
	_board.game = _held
	_board.queue_redraw()
	_refresh()


func _room_connected() -> bool:
	if not is_inside_tree():
		return false
	var room := get_node_or_null("/root/RoomClient")
	return room != null and bool(room.connected) and not bool(room.connecting)


func _reconnecting() -> bool:
	if not is_inside_tree():
		return false
	var room := get_node_or_null("/root/RoomClient")
	if room == null:
		return false
	return bool(room.connecting) or not bool(room.connected)


func _can_move() -> bool:
	if _held.is_empty() or _reconnecting():
		return false
	if String(_held.get("status", "")) != "playing":
		return false
	if not GameView.my_turn(_held):
		return false
	var now_ms := int(Time.get_unix_time_from_system() * 1000.0)
	return GameView.seconds_left(int(_held.get("deadlineAt", 0)), now_ms) > 0


func _waiting_confirm() -> bool:
	if _held.is_empty() or _reconnecting():
		return false
	if String(_held.get("status", "")) != "playing":
		return false
	var now_ms := int(Time.get_unix_time_from_system() * 1000.0)
	return GameView.seconds_left(int(_held.get("deadlineAt", 0)), now_ms) == 0


func _refresh() -> void:
	if _bar == null:
		return
	_board.game = _held
	_board.queue_redraw()
	if _held.is_empty():
		_bar.text = "正在重连" if _reconnecting() else "对局已中断"
		_hint.text = ""
		_resign.visible = false
		_close.visible = not _reconnecting()
		return
	var bits: PackedStringArray = []
	bits.append(GameView.opponent_name(_held))
	bits.append("你执黑" if String(_held.get("you", "")) == "black" else "你执白")
	if _reconnecting():
		bits.append("正在重连")
	elif String(_held.get("status", "")) == "playing":
		if _waiting_confirm():
			bits.append("等待校长确认...")
		else:
			bits.append("轮到你" if GameView.my_turn(_held) else "等待对方")
			var now_ms := int(Time.get_unix_time_from_system() * 1000.0)
			bits.append("%ds" % GameView.seconds_left(int(_held.get("deadlineAt", 0)), now_ms))
	elif String(_held.get("status", "")) == "ended":
		var result: Dictionary = _held.get("result", {})
		var client_id := ""
		if is_inside_tree() and get_node_or_null("/root/AppState") != null:
			client_id = String(get_node("/root/AppState").state.clientId)
		var copy := GameView.result_copy(result if result is Dictionary else {}, client_id)
		if not copy.is_empty():
			bits.append(copy)
	_bar.text = " · ".join(bits)
	var playing := String(_held.get("status", "")) == "playing" and not _reconnecting()
	_resign.visible = playing
	_close.visible = not playing and not _reconnecting()
	if playing:
		_hint.text = "关闭窗口 = 认输"
	elif String(_held.get("status", "")) == "ended":
		_hint.text = _bar.text
	else:
		_hint.text = ""


func _on_board_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _can_move():
		return
	var point := GameView.point_from_click(event.position.x, event.position.y)
	if point.x < 0:
		return
	var room := get_node_or_null("/root/RoomClient")
	if room:
		room.game_move(String(_held.get("id", "")), point.x, point.y)


func _on_resign() -> void:
	if String(_held.get("status", "")) != "playing":
		return
	var room := get_node_or_null("/root/RoomClient")
	if room:
		room.game_resign(String(_held.get("id", "")))


func _on_close() -> void:
	var hub := get_node_or_null("/root/WindowHub")
	if hub and hub.has_method("close_game"):
		hub.close_game()


class BoardView extends Control:
	const POINTS := 15
	const CELL := 28
	const PAD := 22
	const STONE := 22
	const BOARD := PAD * 2 + CELL * 14
	var game: Dictionary = {}

	func _ready() -> void:
		custom_minimum_size = Vector2(BOARD, BOARD)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var wood := BbPetTheme.GAME_BOARD
		draw_rect(Rect2(Vector2.ZERO, Vector2(BOARD, BOARD)), wood)
		draw_rect(Rect2(Vector2.ZERO, Vector2(BOARD, BOARD)), BbPetTheme.INK, false, 4.0)
		var line := BbPetTheme.INK
		var end := float(PAD + CELL * 14)
		for i in POINTS:
			var p := float(PAD + i * CELL)
			draw_line(Vector2(PAD, p), Vector2(end, p), line, 1.0)
			draw_line(Vector2(p, PAD), Vector2(p, end), line, 1.0)
		var last: Dictionary = game.get("lastMove", {}) if game.get("lastMove") is Dictionary else {}
		var win: Dictionary = {}
		var win_raw: Variant = game.get("winLine", [])
		if win_raw is Array:
			for item in win_raw:
				if item is Dictionary:
					win["%d,%d" % [int(item.x), int(item.y)]] = true
		var board: Variant = game.get("board", [])
		if not board is Array:
			return
		for y in board.size():
			var row: Variant = board[y]
			if not row is Array:
				continue
			for x in row.size():
				var stone := int(row[x])
				if stone == 0:
					continue
				var center := Vector2(PAD + x * CELL, PAD + y * CELL)
				var radius := STONE / 2.0
				draw_circle(center, radius, BbPetTheme.STONE_BLACK if stone == 1 else BbPetTheme.STONE_WHITE)
				draw_arc(center, radius, 0.0, TAU, 24, BbPetTheme.INK, 2.0)
				var key := "%d,%d" % [x, y]
				if win.has(key):
					draw_arc(center, radius + 3.0, 0.0, TAU, 24, BbPetTheme.STONE_WIN, 3.0)
				elif int(last.get("x", -1)) == x and int(last.get("y", -1)) == y:
					draw_arc(center, radius + 3.0, 0.0, TAU, 24, BbPetTheme.STONE_LAST, 3.0)
