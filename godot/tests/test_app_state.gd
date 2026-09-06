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
	failed += _check(
		"default city",
		s.state.settings.cityId == "beijing"
		and s.state.settings.cityName == "北京"
		and is_equal_approx(float(s.state.settings.latitude), 39.9042)
		and is_equal_approx(float(s.state.settings.longitude), 116.4074)
	)
	failed += _check("default push interval", s.state.settings.pushIntervalMin == 30)
	failed += _check("default llm base", s.state.settings.apiBaseUrl == "https://openrouter.ai/api/v1")
	failed += _check("default model", s.state.settings.model == "minimax/minimax-m3:free")
	failed += _check("default fallback", s.state.settings.fallbackModel == "minimax/minimax-m2.7:free")
	var default_path := APP_STATE_SCRIPT.DEFAULT_STATE_PATH
	var had_default := FileAccess.file_exists(default_path)
	var previous_default := FileAccess.get_file_as_string(default_path) if had_default else ""
	s.save_world_size(901, 607)
	var persisted: APP_STATE_SCRIPT = APP_STATE_SCRIPT.new()
	persisted.load_from(default_path)
	failed += _check(
		"save world size persists",
		persisted.state.settings.worldWidth == 901 and persisted.state.settings.worldHeight == 607
	)
	persisted.free()
	if had_default:
		var restored := FileAccess.open(default_path, FileAccess.WRITE)
		restored.store_string(previous_default)
		restored.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(default_path))
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
	s.set_city("shanghai")
	s.set_push_interval_min(10)
	s.set_llm("https://openrouter.ai/api/v1", "secret-key", "minimax/minimax-m3:free", "minimax/minimax-m2.7:free")
	s.save_to(path)
	var raw := FileAccess.get_file_as_string(path)
	var saved: Variant = JSON.parse_string(raw)
	failed += _check("settings apiKey", saved is Dictionary and saved.settings.apiKey == "secret-key")
	failed += _check("no pet apiKey", saved is Dictionary and not saved.pet.has("apiKey"))
	failed += _check("no photo", not raw.contains("photoDataUrl"))
	s.state = {}
	s.load_from(path)
	failed += _check("reload onboarded", s.state.onboarded == true)
	failed += _check("reload cat", s.state.pet.species == "cat")
	failed += _check("reload default colors", s.state.pet.colors == PetTemplates.DEFAULT_COLORS["cat"])
	failed += _check("reload world size", s.state.settings.worldWidth == 1024 and s.state.settings.worldHeight == 768)
	failed += _check(
		"reload city",
		s.state.settings.cityId == "shanghai"
		and s.state.settings.cityName == "上海"
		and is_equal_approx(float(s.state.settings.latitude), 31.2304)
		and is_equal_approx(float(s.state.settings.longitude), 121.4737)
	)
	failed += _check("reload push interval", s.state.settings.pushIntervalMin == 10)
	failed += _check("reload apiKey", s.state.settings.apiKey == "secret-key")
	s.set_push_interval_min(2)
	failed += _check("clamp push interval", s.state.settings.pushIntervalMin == 5)
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
