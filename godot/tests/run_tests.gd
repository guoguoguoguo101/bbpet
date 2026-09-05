extends SceneTree

func _init() -> void:
	var failed := 0
	var dir := DirAccess.open("res://tests")
	if dir == null:
		push_error("missing res://tests")
		quit(1)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.begins_with("test_") and name.ends_with(".gd"):
			var script: GDScript = load("res://tests/%s" % name)
			var inst: RefCounted = script.new()
			var code := int(inst.call("run"))
			if code != 0:
				failed += 1
		name = dir.get_next()
	dir.list_dir_end()
	quit(1 if failed > 0 else 0)
