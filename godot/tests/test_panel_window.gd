extends RefCounted

const PANEL_SCENE = preload("res://windows/panel_window.tscn")
const WeatherCities = preload("res://weather/cities.gd")


func run() -> int:
	var failed := 0
	var panel: Window = PANEL_SCENE.instantiate()

	panel.call("show_kind", "wizard")
	failed += _check("wizard size", panel.size == Vector2i(340, 560))
	failed += _check("wizard background", panel.get_node("Background").color == Color("#fff8f2"))
	var wizard_species: GridContainer = panel.get_node("Margin/Content/Species")
	failed += _check("wizard species count", wizard_species.get_child_count() == 6)
	for index in wizard_species.get_child_count():
		var key: String = PetTemplates.SPECIES[index]
		failed += _check(
			"wizard species label %s" % key,
			wizard_species.get_child(index).text == PetTemplates.SPECIES_LABELS[key]
		)
	failed += _check("wizard name placeholder", panel.get_node("Margin/Content/Name").placeholder_text == "名字")
	var wizard_city: OptionButton = panel.get_node("Margin/Content/City")
	failed += _check("wizard city count", wizard_city.item_count == WeatherCities.CITIES.size())
	for index in wizard_city.item_count:
		var city: Dictionary = WeatherCities.CITIES[index]
		failed += _check("wizard city name %s" % city.id, wizard_city.get_item_text(index) == city.name)
		failed += _check("wizard city id %s" % city.id, wizard_city.get_item_metadata(index) == city.id)
	failed += _check(
		"wizard current city",
		wizard_city.get_item_metadata(wizard_city.selected) == WeatherCities.DEFAULT_CITY.id
	)
	failed += _check("wizard confirm", panel.get_node("Margin/Content/Confirm").text == "确定")
	failed += _check("wizard photo", panel.get_node("Margin/Content/Photo").text == "选一张照片取色")

	panel.call("show_kind", "hub")
	failed += _check("hub size", panel.size == Vector2i(300, 580))
	failed += _check("hub preview", panel.has_node("Margin/Content/Hero/Preview"))
	failed += _check("hub chat", panel.get_node("Margin/Content/Chat").text == "和宠物聊")
	failed += _check("hub school", panel.get_node("Margin/Content/School").text == "去上学")
	failed += _check("hub home", panel.get_node("Margin/Content/Home").text == "回家")
	failed += _check("hub friends", panel.get_node("Margin/Content/Friends").text == "好友")
	failed += _check(
		"hub button order",
		panel.get_node("Margin/Content/Chat").get_index()
		< panel.get_node("Margin/Content/School").get_index()
		and panel.get_node("Margin/Content/School").get_index()
		< panel.get_node("Margin/Content/Home").get_index()
		and panel.get_node("Margin/Content/Home").get_index()
		< panel.get_node("Margin/Content/Friends").get_index()
		and panel.get_node("Margin/Content/Friends").get_index()
		< panel.get_node("Margin/Content/Settings").get_index()
	)
	failed += _check("hub settings", panel.get_node("Margin/Content/Settings").text == "设置")
	var panel_source := FileAccess.get_file_as_string("res://windows/panel_window.gd")
	failed += _check("hub title copy", panel_source.contains("今天去哪"))
	failed += _check("hub subtitle", panel_source.contains("去学校不会离开家。客厅聊天一直在桌面上。"))

	panel.call("show_kind", "settings")
	failed += _check("settings size", panel.size == Vector2i(340, 860))
	failed += _check("settings save", panel.get_node("Margin/Content/Save").text == "保存")
	failed += _check("settings photo", panel.get_node("Margin/Content/Photo").text == "选一张照片取色")
	failed += _check("settings api key", panel.has_node("Margin/Content/ApiKey"))
	failed += _check("settings model", panel.has_node("Margin/Content/Model"))
	var species: OptionButton = panel.get_node("Margin/Content/Species")
	failed += _check("settings species count", species.item_count == 6)
	for index in species.item_count:
		var key: String = PetTemplates.SPECIES[index]
		failed += _check("settings species id %s" % key, species.get_item_metadata(index) == key)
	var settings_city: OptionButton = panel.get_node("Margin/Content/City")
	failed += _check("settings city count", settings_city.item_count == WeatherCities.CITIES.size())
	for index in settings_city.item_count:
		var city: Dictionary = WeatherCities.CITIES[index]
		failed += _check("settings city name %s" % city.id, settings_city.get_item_text(index) == city.name)
		failed += _check("settings city id %s" % city.id, settings_city.get_item_metadata(index) == city.id)
	failed += _check(
		"settings current city",
		settings_city.get_item_metadata(settings_city.selected) == WeatherCities.DEFAULT_CITY.id
	)
	failed += _check("settings push minutes", panel.get_node("Margin/Content/PushMin").text == "30")
	failed += _check("settings city heading", panel_source.contains("\"城市\""))
	failed += _check("settings push heading", panel_source.contains("\"冒泡间隔（分钟）\""))
	failed += _check("settings saves city", panel_source.contains("set_city"))

	panel.call("show_kind", "friends")
	failed += _check("friends size", panel.size == Vector2i(300, 560))
	failed += _check("friends title", panel.title == "好友")
	failed += _check("friends incoming", panel.has_node("Margin/Content/Incoming"))
	failed += _check("friends invite", panel.has_node("Margin/Content/Invite"))
	failed += _check("friends empty hint", panel.get_node("Margin/Content/Empty").text == "去学校点别的同学，点「加好友」就会出现在这里。")
	failed += _check("no visit button", panel.get_node_or_null("Margin/Content/Visit") == null)
	failed += _check("visit copy in source", FileAccess.get_file_as_string("res://windows/panel_window.gd").contains("进他家"))
	failed += _check("accept copy", FileAccess.get_file_as_string("res://windows/panel_window.gd").contains("同意"))
	failed += _check("gomoku copy", FileAccess.get_file_as_string("res://windows/panel_window.gd").contains("五子棋"))
	failed += _check("chat kind", FileAccess.get_file_as_string("res://windows/panel_window.gd").contains("_build_chat"))

	panel.call("show_kind", "chat")
	failed += _check("chat size", panel.size == Vector2i(340, 520))
	failed += _check("chat send", panel.get_node("Margin/Content/Composer/Send").text == "发送")

	panel.free()
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("panel_window: %s" % label)
	return 1
