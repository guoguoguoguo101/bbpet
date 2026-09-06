extends RefCounted

const IdleLife = preload("res://pet/idle_life.gd")


func run() -> int:
	var failed := 0
	failed += _check("six slack poses", IdleLife.SLACK_POSES.size() == 6)
	failed += _check("slack set", IdleLife.is_slack("phone") and IdleLife.is_slack("toilet"))
	failed += _check("idle not slack", not IdleLife.is_slack("idle"))
	failed += _check("talk skips nap", not IdleLife.can_nap("talk") and not IdleLife.can_nap("type"))
	failed += _check("idle can nap", IdleLife.can_nap("idle") and IdleLife.can_nap("sleep"))
	failed += _check("slack only idle blink", IdleLife.can_slack("idle") and IdleLife.can_slack("blink") and not IdleLife.can_slack("talk"))
	failed += _check("pick wrap", IdleLife.pick_slack(7) == IdleLife.SLACK_POSES[1])
	failed += _check("juice", IdleLife.has_juice({"gear": ["juice"]}) and not IdleLife.has_juice({"gear": ["scarf"]}))
	var sun: Dictionary = IdleLife.demo_weather("sun")
	failed += _check("sun gear", sun.gear.has("shades") and sun.gear.has("juice"))
	var rain: Dictionary = IdleLife.demo_weather("rain")
	failed += _check("rain gear", rain.gear.has("raincoat") and rain.fx.has("rain"))
	failed += _check("hold ms", IdleLife.ACTION_HOLD_MS == 10000)
	failed += _check("sleep lines", IdleLife.POSE_LINES["sleep"].size() == 3)
	failed += _check("unknown pose line", IdleLife.line_for_pose("nope") == "")
	failed += _check("storm demo", IdleLife.demo_weather("storm").fx.has("storm"))
	failed += _check("snow demo", IdleLife.demo_weather("snow").gear.has("snowman"))
	var pet_src := FileAccess.get_file_as_string("res://windows/pet_root.gd")
	failed += _check("drink interval", pet_src.contains("randf_range(150.0, 300.0)"))
	failed += _check("nap interval", pet_src.contains("randf_range(55.0, 75.0)"))
	failed += _check("slack interval", pet_src.contains("randf_range(14.0, 30.0)"))
	failed += _check("demo idle", pet_src.contains('"发呆"'))
	failed += _check("look threshold", pet_src.contains("dx < -42") and pet_src.contains("dx > 42"))
	failed += _check("look y threshold", pet_src.contains("-28") and pet_src.contains("36"))
	failed += _check("watch keys", pet_src.contains("watch-keys.ps1"))
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("idle_life: %s" % label)
	return 1
