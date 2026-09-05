extends Node

const PET_TEMPLATES = preload("res://pet/templates.gd")
const SCHOOL_LOGIC = preload("res://school/school_logic.gd")
const DEFAULT_STATE_PATH := "user://bbpet-state.json"
const ROOM_URL_ERROR := "学校地址要以 ws:// 或 wss:// 开头"

var state: Dictionary = {}


func _ready() -> void:
	load_from(DEFAULT_STATE_PATH)


func load_from(path: String) -> void:
	state = _default_state()
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return
	var saved: Dictionary = parsed
	if saved.has("onboarded") and saved.onboarded is bool:
		state.onboarded = saved.onboarded
	if saved.has("clientId") and saved.clientId is String and not saved.clientId.is_empty():
		state.clientId = saved.clientId
	if saved.has("pet") and saved.pet is Dictionary:
		var pet: Dictionary = saved.pet
		if pet.has("name") and pet.name is String and not sanitize_name(pet.name).is_empty():
			state.pet.name = sanitize_name(pet.name)
		if pet.has("species") and PET_TEMPLATES.DEFAULT_COLORS.has(pet.species):
			state.pet.species = pet.species
		if pet.has("colors") and pet.colors is Dictionary:
			state.pet.colors = pet.colors.duplicate(true)
	if saved.has("settings") and saved.settings is Dictionary:
		var settings: Dictionary = saved.settings
		if settings.has("roomUrl") and settings.roomUrl is String:
			state.settings.roomUrl = settings.roomUrl
		if settings.has("worldWidth") and (settings.worldWidth is int or settings.worldWidth is float):
			state.settings.worldWidth = settings.worldWidth
		if settings.has("worldHeight") and (settings.worldHeight is int or settings.worldHeight is float):
			state.settings.worldHeight = settings.worldHeight


func save_to(path: String) -> void:
	var archive := {
		"onboarded": state.onboarded,
		"clientId": state.clientId,
		"pet": {
			"name": state.pet.name,
			"species": state.pet.species,
			"colors": state.pet.colors.duplicate(true),
		},
		"settings": {
			"roomUrl": state.settings.roomUrl,
			"worldWidth": state.settings.worldWidth,
			"worldHeight": state.settings.worldHeight,
		},
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save app state: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(archive))


func sanitize_name(text: String) -> String:
	return text.strip_edges().substr(0, 12)


func set_species(species: String) -> void:
	if not PET_TEMPLATES.DEFAULT_COLORS.has(species):
		return
	state.pet.species = species
	state.pet.colors = PET_TEMPLATES.DEFAULT_COLORS[species].duplicate(true)


@warning_ignore("native_method_override")
func set_name(text: String):
	var sanitized := sanitize_name(text)
	if sanitized.is_empty():
		return false
	state.pet.name = sanitized
	return true


func set_room_url(url: String) -> String:
	if not url.begins_with("ws://") and not url.begins_with("wss://"):
		return ROOM_URL_ERROR
	state.settings.roomUrl = url
	return ""


func mark_onboarded() -> void:
	state.onboarded = true


func save_world_size(w: int, h: int) -> void:
	state.settings.worldWidth = w
	state.settings.worldHeight = h


func pet_for_hello() -> Dictionary:
	return {
		"name": state.pet.name,
		"species": state.pet.species,
		"colors": state.pet.colors.duplicate(true),
	}


func _default_state() -> Dictionary:
	return {
		"onboarded": false,
		"clientId": _generate_client_id(),
		"pet": {
			"name": "豆豆",
			"species": "blob",
			"colors": PET_TEMPLATES.DEFAULT_COLORS["blob"].duplicate(true),
		},
		"settings": {
			"roomUrl": SCHOOL_LOGIC.DEFAULT_ROOM_URL,
			"worldWidth": 820,
			"worldHeight": 560,
		},
	}


func _generate_client_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	var hex := ""
	for byte in bytes:
		hex += "%02x" % byte
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]
