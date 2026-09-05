extends RefCounted

const REQUIRED_LINES := [
	'config/name="bbpet"',
	"window/size/viewport_width=64",
	"window/size/viewport_height=86",
]

func run() -> int:
	var path := ProjectSettings.globalize_path("res://project.godot")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("missing res://project.godot")
		return 1
	var text := file.get_as_text()
	file.close()
	for line in REQUIRED_LINES:
		if not text.contains(line):
			push_error("project.godot missing required line: %s" % line)
			return 1
	return 0
