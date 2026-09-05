extends RefCounted

const APP_STATE_SCRIPT = preload("res://autoload/app_state.gd")

func run() -> int:
	var failed := 0
	var path := "user://test-bbpet-state.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var s: APP_STATE_SCRIPT = APP_STATE_SCRIPT.new()
	s.load_from(path)
	failed += _check("default name", s.state.pet.name == "豆豆")
	failed += _check("default species", s.state.pet.species == "blob")
	failed += _check("not onboarded", s.state.onboarded == false)
	failed += _check("clientId", String(s.state.clientId).length() >= 8)
	failed += _check("room", s.state.settings.roomUrl == SchoolLogic.DEFAULT_ROOM_URL)
	failed += _check("default world size", s.state.settings.worldWidth == 820 and s.state.settings.worldHeight == 560)
	failed += _check("empty name", s.set_pet_name("   ") == false)
	failed += _check("trim name", s.set_pet_name("  豆包豆包豆包豆包  ") and s.state.pet.name == "豆包豆包豆包豆包".substr(0, 12))
	s.set_species("cat")
	failed += _check("cat colors", s.state.pet.colors.body == PetTemplates.DEFAULT_COLORS["cat"].body)
	failed += _check("bad url", s.set_room_url("http://x") == "学校地址要以 ws:// 或 wss:// 开头")
	failed += _check("ws url", s.set_room_url("ws://127.0.0.1:18765") == "")
	s.save_world_size(1024, 768)
	failed += _check("world size", s.state.settings.worldWidth == 1024 and s.state.settings.worldHeight == 768)
	s.mark_onboarded()
	s.state.apiKey = "secret"
	s.state.pet.photoDataUrl = "data:image/png;base64,secret"
	s.state.pet.colors = {"body": "#000000"}
	s.save_to(path)
	var raw := FileAccess.get_file_as_string(path)
	failed += _check("no apiKey", not raw.contains("apiKey"))
	failed += _check("no photo", not raw.contains("photoDataUrl"))
	s.state = {}
	s.load_from(path)
	failed += _check("reload onboarded", s.state.onboarded == true)
	failed += _check("reload cat", s.state.pet.species == "cat")
	failed += _check("reload default colors", s.state.pet.colors == PetTemplates.DEFAULT_COLORS["cat"])
	failed += _check("reload world size", s.state.settings.worldWidth == 1024 and s.state.settings.worldHeight == 768)
	var hello: Dictionary = s.pet_for_hello()
	failed += _check("hello keys", hello.has("name") and hello.has("species") and hello.has("colors") and not hello.has("photoDataUrl"))
	var bad := "user://test-bbpet-bad.json"
	var f := FileAccess.open(bad, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	s.load_from(bad)
	failed += _check("corrupt reset", s.state.onboarded == false and s.state.pet.species == "blob")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad))
	s.free()
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("app_state: %s" % label)
	return 1
