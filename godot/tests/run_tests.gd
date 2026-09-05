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
			var path := "res://tests/%s" % name
			var script: Variant = load(path)
			if script == null or not script is Script or not script.can_instantiate():
				push_error("unable to load test: %s" % path)
				failed += 1
				name = dir.get_next()
				continue
			var inst: Variant = script.new()
			if inst == null or not inst.has_method("run"):
				push_error("test has no run() method: %s" % path)
				failed += 1
			elif int(inst.call("run")) != 0:
				failed += 1
		name = dir.get_next()
	dir.list_dir_end()
	quit(1 if failed > 0 else 0)
