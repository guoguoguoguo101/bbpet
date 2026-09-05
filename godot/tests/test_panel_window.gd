extends RefCounted

const PANEL_SCENE = preload("res://windows/panel_window.tscn")


func run() -> int:
	var failed := 0
	var panel: Window = PANEL_SCENE.instantiate()

	panel.call("show_kind", "wizard")
	failed += _check("wizard size", panel.size == Vector2i(340, 520))
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
	failed += _check("wizard confirm", panel.get_node("Margin/Content/Confirm").text == "确定")

	panel.call("show_kind", "hub")
	failed += _check("hub size", panel.size == Vector2i(300, 430))
	failed += _check("hub preview", panel.has_node("Margin/Content/Preview"))
	failed += _check("hub school", panel.get_node("Margin/Content/School").text == "去上学")
	failed += _check("hub friends", panel.get_node("Margin/Content/Friends").text == "好友")
	failed += _check(
		"hub button order",
		panel.get_node("Margin/Content/School").get_index()
		< panel.get_node("Margin/Content/Friends").get_index()
		and panel.get_node("Margin/Content/Friends").get_index()
		< panel.get_node("Margin/Content/Settings").get_index()
	)
	failed += _check("hub settings", panel.get_node("Margin/Content/Settings").text == "设置")

	panel.call("show_kind", "settings")
	failed += _check("settings size", panel.size == Vector2i(340, 640))
	failed += _check("settings save", panel.get_node("Margin/Content/Save").text == "保存")
	var species: OptionButton = panel.get_node("Margin/Content/Species")
	failed += _check("settings species count", species.item_count == 6)
	for index in species.item_count:
		var key: String = PetTemplates.SPECIES[index]
		failed += _check("settings species id %s" % key, species.get_item_metadata(index) == key)

	panel.call("show_kind", "friends")
	failed += _check("friends size", panel.size == Vector2i(300, 480))
	failed += _check("friends title", panel.title == "好友")
	failed += _check("friends empty hint", panel.get_node("Margin/Content/Empty").text == "去学校点别的同学，点「加好友」就会出现在这里。")
	failed += _check("no visit button", panel.get_node_or_null("Margin/Content/Visit") == null)

	panel.free()
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("panel_window: %s" % label)
	return 1
