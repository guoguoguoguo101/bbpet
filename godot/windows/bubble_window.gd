extends Window

signal dismissed

const MIN_SIZE := Vector2i(220, 80)
const WRAP_WIDTH := 240
const HOLD_NO_URL := 8.0
const HOLD_WITH_URL := 16.0

var _label: Label
var _link: Button
var _hold: Timer
var _url := ""


func _init() -> void:
	visible = false
	unfocusable = true
	borderless = true
	transparent = true
	always_on_top = true
	unresizable = true
	transparent_bg = true
	size = MIN_SIZE
	_build()


func present(payload: Dictionary) -> void:
	_url = str(payload.get("url", ""))
	_label.text = str(payload.get("text", ""))
	_link.visible = not _url.is_empty()
	_fit_size()
	var hold := HOLD_WITH_URL if not _url.is_empty() else HOLD_NO_URL
	_hold.start(hold)


func dismiss() -> void:
	_hold.stop()
	hide()
	dismissed.emit()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	_label = Label.new()
	_label.name = "Text"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_label.gui_input.connect(_on_clicked)
	box.add_child(_label)
	_link = Button.new()
	_link.name = "OpenUrl"
	_link.text = "打开"
	_link.visible = false
	_link.pressed.connect(_open_url)
	box.add_child(_link)
	_hold = Timer.new()
	_hold.one_shot = true
	_hold.timeout.connect(dismiss)
	add_child(_hold)
	close_requested.connect(dismiss)


func _fit_size() -> void:
	var extra := 36 if _link.visible else 16
	var text_h := 40
	var font := _label.get_theme_default_font()
	var font_size := _label.get_theme_default_font_size()
	if font != null:
		var measured := font.get_multiline_string_size(
			_label.text, HORIZONTAL_ALIGNMENT_LEFT, float(WRAP_WIDTH), font_size
		)
		text_h = int(ceil(measured.y))
	size = Vector2i(maxi(MIN_SIZE.x, WRAP_WIDTH), maxi(MIN_SIZE.y, text_h + extra))


func _on_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_url()


func _open_url() -> void:
	if _url.is_empty():
		return
	OS.shell_open(_url)
	dismiss()
