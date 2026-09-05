# Godot Client Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Godot 4.4+ Windows client that is a transparent desk pet and can walk the existing school maps on the current Node principal, interoperable with the Electron client.

**Architecture:** New `godot/` project. Main window is the 64×86 pet. Hub/settings/wizard and school are extra `Window`s. Autoloads (`AppState`, `RoomClient`, `WindowHub`) own archive, WebSocket, and window lifetime. Pixel frames and school tiles are runtime-painted from ports of `templates.ts` / `world.ts`. Principal protocol is unchanged.

**Tech Stack:** Godot 4.4+ GDScript, `WebSocketPeer`, `StatusIndicator` for tray, existing Node `ws` principal on port 18765. Headless tests via `godot --headless --script res://tests/run_tests.gd`. No Electron helper, no TileMap, no LLM/weather.

**Spec:** `docs/superpowers/specs/2026-09-05-godot-client-vertical-slice-design.md`

## Global Constraints

- Godot 4.4 or newer; GDScript only; project lives in `godot/`. Application name `bbpet`.
- Do not modify `server/`, `shared/` protocol, or the Electron client except README.
- Desk pet window is 64×86. School entity size `PET_SIZE = 32`, `TILE = 32`, `MOVE_SPEED = 110`, `MOVE_SEND_MS = 100`, `POSE_TICK_MS = 100`, `SCHOOL_CROWD_CAP = 100`.
- Send only `hello` / `enterPlace` / `move`. Handle only `welcome` / `snapshot` / `join` / `leave` / `move` / `poses` / `error` / `notice`; drop everything else.
- Default room URL `ws://127.0.0.1:18765`. Archive `user://bbpet-state.json`, never Electron userData.
- Names trim + max 12 chars; species only `cat|dog|rabbit|bird|hamster|blob`; colors from `DEFAULT_COLORS` for that species.
- User-visible strings are the exact Chinese in each task. Git commits stay English.
- Tests: `godot --headless --path godot --script res://tests/run_tests.gd` (Godot 4.4+ on PATH as `godot`). Exit 0 pass, 1 fail.
- Do not add blackboard, friends, home, emotes, gomoku, LLM, weather, photo import, or Godot-as-principal.

## File Structure

- Create: `godot/project.godot` — display 64×86, transparent, borderless, always-on-top; autoloads; input map.
- Create: `godot/.gitignore` — ignore `.godot/`.
- Modify: `.gitignore` — also ignore `godot/.godot/` and `godot/export/`.
- Create: `godot/tests/run_tests.gd` — SceneTree runner, sums failures, `quit`.
- Create: `godot/school/school_logic.gd` — maps, collision, doors, spawn, camera, tile colors.
- Create: `godot/school/sync.gd` — pose interpolation helpers.
- Create: `godot/school/paint.gd` — draw place to `Image`.
- Create: `godot/pet/templates.gd` — idle/blink frames, colors, labels, `paint_image`.
- Create: `godot/pet/pixel_pet.gd` + `pixel_pet.tscn` — `TextureRect` from painted image.
- Create: `godot/autoload/app_state.gd` — JSON archive.
- Create: `godot/net/room_messages.gd` — encode/decode JSON.
- Create: `godot/autoload/room_client.gd` — `WebSocketPeer`.
- Create: `godot/autoload/window_hub.gd` — panel/world/tray/quit.
- Create: `godot/windows/pet_root.gd` + `pet_root.tscn` — main scene.
- Create: `godot/windows/panel_window.gd` + `panel_window.tscn`.
- Create: `godot/windows/world_window.gd` + `world_window.tscn`.
- Create: `godot/tests/test_*.gd` — one per logic module.
- Modify: `README.md` — Godot experimental section.
- Modify: `package.json` — `test:godot` script.
- Create: `godot/export_presets.cfg` — Windows desktop export.

---

### Task 1: Godot project and headless test runner

**Files:**
- Create: `godot/project.godot`
- Create: `godot/.gitignore`
- Create: `godot/tests/run_tests.gd`
- Create: `godot/tests/test_sanity.gd`
- Modify: `.gitignore`
- Modify: `package.json`

**Interfaces:**
- Consumes: nothing
- Produces: Godot project with main-window size 64×86 and transparent flags; `res://tests/run_tests.gd` exits 0 when all `test_*.gd` `run()` return 0

- [ ] **Step 1: Write the failing sanity test and runner**

Create `godot/tests/test_sanity.gd`:

```gdscript
extends RefCounted

func run() -> int:
	if 1 + 1 != 2:
		push_error("sanity math failed")
		return 1
	return 0
```

Create `godot/tests/run_tests.gd`:

```gdscript
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
			failed += int(inst.call("run"))
		name = dir.get_next()
	dir.list_dir_end()
	quit(1 if failed > 0 else 0)
```

- [ ] **Step 2: Run the runner without a project (expect fail)**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL because `godot/project.godot` does not exist yet (Godot prints it is not a valid project).

- [ ] **Step 3: Create the project files**

`godot/.gitignore`:

```
.godot/
export/
```

Append to repo `.gitignore`:

```
godot/.godot/
godot/export/
```

`godot/project.godot`:

```ini
; Engine configuration file.
config_version=5

[application]
config/name="bbpet"
config/version="1.0.0"
run/main_scene="res://windows/pet_root.tscn"
config/features=PackedStringArray("4.4", "GL Compatibility")
boot_splash/show_image=false

[autoload]
AppState="*res://autoload/app_state.gd"
RoomClient="*res://autoload/room_client.gd"
WindowHub="*res://autoload/window_hub.gd"

[display]
window/size/viewport_width=64
window/size/viewport_height=86
window/size/resizable=false
window/size/borderless=true
window/size/always_on_top=true
window/size/transparent=true
window/per_pixel_transparency/allowed=true

[rendering]
renderer/rendering_method="gl_compatibility"
viewport/transparent_background=true
```

Do not add an Input Map. School movement in Task 11 reads `KEY_A/D/W/S` and `KEY_LEFT/RIGHT/UP/DOWN` with `Input.is_physical_key_pressed` so the `project.godot` file stays hand-editable.

Do **not** create the autoload scripts or `pet_root.tscn` in this task. Godot will warn they are missing; that is OK until later tasks. If the editor refuses to open, create three stub autoloads and a stub main scene as follows (only if needed to run `--script`):

`godot/autoload/app_state.gd`, `room_client.gd`, `window_hub.gd`:

```gdscript
extends Node
```

`godot/windows/pet_root.tscn`:

```
[gd_scene load_steps=2 format=3 uid="uid://bbpetpetroot"]

[ext_resource type="Script" path="res://windows/pet_root.gd" id="1_pet"]

[node name="PetRoot" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_pet")
```

`godot/windows/pet_root.gd`:

```gdscript
extends Control
```

In `package.json` `scripts`, add:

```json
"test:godot": "godot --headless --path godot --script res://tests/run_tests.gd"
```

- [ ] **Step 4: Run tests**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: process exit code 0.

- [ ] **Step 5: Commit**

```bash
git add .gitignore package.json godot
git commit -m "Add a Godot 4 project and headless test runner."
```

---

### Task 2: School map logic

**Files:**
- Create: `godot/school/school_logic.gd`
- Create: `godot/tests/test_school_logic.gd`

**Interfaces:**
- Consumes: nothing
- Produces: `class_name SchoolLogic` with constants `TILE`, `PET_SIZE`, `MOVE_SPEED`, `MOVE_SEND_MS`, `POSE_TICK_MS`, `SCHOOL_CROWD_CAP`, `DEFAULT_ROOM_URL`; `PLACES` Dictionary keyed by `school:campus` and `school:class-1`…`class-4`; functions listed in Step 3

- [ ] **Step 1: Write the failing tests**

Create `godot/tests/test_school_logic.gd`:

```gdscript
extends RefCounted

func run() -> int:
	var failed := 0
	failed += _check("tile 32", SchoolLogic.TILE == 32)
	failed += _check("pet size 32", SchoolLogic.PET_SIZE == 32)
	failed += _check("speed 110", SchoolLogic.MOVE_SPEED == 110)
	failed += _check("url", SchoolLogic.DEFAULT_ROOM_URL == "ws://127.0.0.1:18765")
	var campus: Dictionary = SchoolLogic.PLACES["school:campus"]
	failed += _check("campus title", campus.title == "学校操场")
	var spawn: Dictionary = SchoolLogic.default_spawn("school:campus")
	failed += _check("campus spawn x", is_equal_approx(spawn.x, 384.0))
	failed += _check("campus spawn y", is_equal_approx(spawn.y, 348.0))
	var from_class: Dictionary = SchoolLogic.spawn_after_enter("school:class-1", "school:campus")
	var door_a: Dictionary = SchoolLogic.spawn_on_tile(campus, "a", SchoolLogic.TILE - 6)
	failed += _check("back to door a x", is_equal_approx(from_class.x, door_a.x))
	failed += _check("back to door a y", is_equal_approx(from_class.y, door_a.y))
	var into_1: Dictionary = SchoolLogic.spawn_after_enter("school:campus", "school:class-1")
	var g: Dictionary = SchoolLogic.default_spawn("school:class-1")
	failed += _check("class spawn", is_equal_approx(into_1.x, g.x) and is_equal_approx(into_1.y, g.y))
	var grass_x := 384.0
	var grass_y := 220.0
	failed += _check("can walk grass", SchoolLogic.can_walk(campus, grass_x, grass_y))
	var into_wall: Dictionary = SchoolLogic.clamp_move(campus, grass_x, grass_y, grass_x, -40.0)
	failed += _check("stop at wall y", into_wall.y >= grass_y or SchoolLogic.can_walk(campus, into_wall.x, into_wall.y))
	failed += _check("not inside wall", SchoolLogic.can_walk(campus, into_wall.x, into_wall.y))
	var feet_on_a: Dictionary = SchoolLogic.spawn_on_tile(campus, "a", 0)
	var trig: Variant = SchoolLogic.trigger_at(campus, feet_on_a.x, feet_on_a.y)
	failed += _check("door a", trig != null and trig.kind == "classroom" and trig.place_id == "school:class-1")
	var class1: Dictionary = SchoolLogic.PLACES["school:class-1"]
	var feet_g: Dictionary = SchoolLogic.spawn_on_tile(class1, "g", 0)
	var trig_g: Variant = SchoolLogic.trigger_at(class1, feet_g.x, feet_g.y)
	failed += _check("door g", trig_g != null and trig_g.kind == "campus")
	var feet_x: Dictionary = SchoolLogic.spawn_on_tile(campus, "x", 0)
	var trig_x: Variant = SchoolLogic.trigger_at(campus, feet_x.x, feet_x.y)
	failed += _check("exit x", trig_x != null and trig_x.kind == "exit")
	failed += _check("class-2", SchoolLogic.trigger_at(campus, SchoolLogic.spawn_on_tile(campus, "b", 0).x, SchoolLogic.spawn_on_tile(campus, "b", 0).y).place_id == "school:class-2")
	failed += _check("class-3", SchoolLogic.trigger_at(campus, SchoolLogic.spawn_on_tile(campus, "c", 0).x, SchoolLogic.spawn_on_tile(campus, "c", 0).y).place_id == "school:class-3")
	failed += _check("class-4", SchoolLogic.trigger_at(campus, SchoolLogic.spawn_on_tile(campus, "d", 0).x, SchoolLogic.spawn_on_tile(campus, "d", 0).y).place_id == "school:class-4")
	failed += _check("title class", SchoolLogic.place_title("school:class-2") == "二班教室")
	failed += _check("title away", SchoolLogic.place_title("away") == "桌面")
	var cam: Dictionary = SchoolLogic.camera_for(1.8, 384.0, 348.0, 820.0, 560.0, 25 * 32, 14 * 32)
	failed += _check("camera has left", cam.has("left") and cam.has("top") and cam.scale == 1.8)
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("school_logic: %s" % label)
	return 1
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL with parse/load error `SchoolLogic` not found, or failed checks.

- [ ] **Step 3: Implement `school_logic.gd`**

Create `godot/school/school_logic.gd`. Header comment `# 源：shared/world.ts`. Port the campus/classroom tile strings and helpers exactly (same `#` walls, door letters, `x` / `g` markers). Required API:

```gdscript
class_name SchoolLogic
extends RefCounted

const TILE := 32
const PET_SIZE := 32
const MOVE_SPEED := 110
const MOVE_SEND_MS := 100
const POSE_TICK_MS := 100
const SCHOOL_CROWD_CAP := 100
const DEFAULT_ROOM_URL := "ws://127.0.0.1:18765"

const CAMPUS := PackedStringArray([
	"#########################",
	"#rrrrr#rrrrr#rrrrr#rrrrr#",
	"#fffff#fffff#fffff#fffff#",
	"#fffff#fffff#fffff#fffff#",
	"###a#####b#####c#####d###",
	"#ppppppppppppppppppppppp#",
	"#.......................#",
	"#.......................#",
	"#.......................#",
	"#.......................#",
	"#.......................#",
	"#.......................#",
	"#...........x...........#",
	"#########################",
])

const CLASSROOM := PackedStringArray([
	"####################",
	"#kkkkkkkkkkkkkkkkkk#",
	"#..................#",
	"#..................#",
	"#..ss....ss....ss..#",
	"#..................#",
	"#..ss....ss....ss..#",
	"#..................#",
	"#..................#",
	"#........g.........#",
	"#..................#",
	"####################",
])
```

Build `PLACES` as Dictionaries `{ id, title, kind, tiles, labels }` matching `shared/world.ts` (campus labels 一班/二班/三班/活动室 at tx 3/9/15/21 ty 2; each classroom one blackboard label).

Implement, with the same arithmetic as the TypeScript:

- `map_size(place) -> {cols, rows}`
- `tile_at(place, tx, ty) -> String` (OOB is `#`)
- `find_tile(place, code) -> {tx, ty}`
- `spawn_on_tile(place, code, dy= -8) -> {x, y}` where `x = tx*TILE + (TILE-PET_SIZE)/2`, `y = ty*TILE + dy`
- `default_spawn(place_id)` campus uses code `x` and `dy = -TILE-4`; classroom uses `g` and `dy = -TILE-4`
- `spawn_after_enter(from_id, to_id)` : if going to campus from a class, spawn on that class's door letter with `dy = TILE-6`; else `default_spawn(to)`
- `is_solid(code)` true for `# s k r`
- `feet_box(x, y) -> {x, y, w, h}` with `x+8, y+20, 16, 10`
- `can_walk` / `clamp_move` (try full, then x-only, then y-only)
- `trigger_at` returns `{kind:"exit"}` for `x`, `{kind:"campus"}` for `g`, `{kind:"classroom", place_id:...}` for `a|b|c|d`, else `null`
- `tile_color(code, kind)` / `tile_accent(code)` copy the hex strings from `shared/world.ts`
- `place_title(place_id)` 桌面 / 房间 / place title
- `is_school_place(id) -> bool`
- `camera_for(scale, me_x, me_y, stage_w, stage_h, map_w, map_h) -> {scale, left, top}` port of `cameraFor` in `src/world/WorldApp.tsx`

Door map: `a→school:class-1`, `b→school:class-2`, `c→school:class-3`, `d→school:class-4`.

- [ ] **Step 4: Run tests**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot/school/school_logic.gd godot/tests/test_school_logic.gd
git commit -m "Port school tiles, collision, and door spawns to GDScript."
```

---

### Task 3: Presence interpolation helpers

**Files:**
- Create: `godot/school/sync.gd`
- Create: `godot/tests/test_sync.gd`

**Interfaces:**
- Consumes: `SchoolLogic.MOVE_SPEED`, `SchoolLogic.POSE_TICK_MS`
- Produces: `class_name PetSync` with `round_pose(x, y) -> Vector2`, `interpolate_pose(from_x, from_y, to_x, to_y, from_at, now, dur = POSE_TICK_MS+40) -> Dictionary {x,y,t}`, `pose_facing(from, to, t) -> String`, `keep_visual_people(prev: Array, incoming: Array) -> Array`, `apply_pose_items(people, items, self_id) -> Array`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends RefCounted

func run() -> int:
	var failed := 0
	var r: Vector2 = PetSync.round_pose(1.26, 2.24)
	failed += _check("round", is_equal_approx(r.x, 1.3) and is_equal_approx(r.y, 2.2))
	var mid: Dictionary = PetSync.interpolate_pose(0.0, 0.0, 10.0, 0.0, 0.0, 70.0, 140.0)
	failed += _check("lerp t", is_equal_approx(mid.t, 0.5) and is_equal_approx(mid.x, 5.0))
	failed += _check("facing early", PetSync.pose_facing("l", "r", 0.2) == "l")
	failed += _check("facing late", PetSync.pose_facing("l", "r", 0.4) == "r")
	var prev := [{"clientId": "a", "x": 1.0, "y": 2.0, "facing": "l", "name": "old"}]
	var incoming := [{"clientId": "a", "x": 9.0, "y": 9.0, "facing": "r", "name": "new"}]
	var kept: Array = PetSync.keep_visual_people(prev, incoming)
	failed += _check("keep xy", kept[0].x == 1.0 and kept[0].y == 2.0 and kept[0].facing == "l")
	failed += _check("keep name", kept[0].name == "new")
	var people := [{"clientId": "a", "x": 0.0, "y": 0.0, "facing": "l"}, {"clientId": "me", "x": 3.0, "y": 3.0, "facing": "r"}]
	var items := [{"id": "a", "x": 5.0, "y": 6.0, "facing": "r"}, {"id": "me", "x": 99.0, "y": 99.0, "facing": "l"}]
	var after: Array = PetSync.apply_pose_items(people, items, "me")
	failed += _check("apply other", after[0].x == 5.0 and after[0].facing == "r")
	failed += _check("skip self", after[1].x == 3.0)
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("sync: %s" % label)
	return 1
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL (`PetSync` missing).

- [ ] **Step 3: Implement `sync.gd`**

`# 源：shared/sync.ts`

```gdscript
class_name PetSync
extends RefCounted

static func round_pose(x: float, y: float) -> Vector2:
	return Vector2(snapped(x, 0.1), snapped(y, 0.1))

static func interpolate_pose(from_x: float, from_y: float, to_x: float, to_y: float, from_at: float, now: float, dur: float = -1.0) -> Dictionary:
	if dur < 0.0:
		dur = float(SchoolLogic.POSE_TICK_MS + 40)
	var t := 1.0 if dur <= 0.0 else clampf((now - from_at) / dur, 0.0, 1.0)
	return { "x": from_x + (to_x - from_x) * t, "y": from_y + (to_y - from_y) * t, "t": t }

static func pose_facing(from_facing: String, to_facing: String, t: float) -> String:
	return to_facing if t >= 0.35 else from_facing

static func keep_visual_people(prev: Array, incoming: Array) -> Array:
	if prev.is_empty():
		return incoming.duplicate(true)
	var prev_by := {}
	for person in prev:
		prev_by[person.clientId] = person
	var out: Array = []
	for person in incoming:
		var next: Dictionary = person.duplicate(true)
		if prev_by.has(person.clientId):
			var old: Dictionary = prev_by[person.clientId]
			next.x = old.x
			next.y = old.y
			next.facing = old.facing
		out.append(next)
	return out

static func apply_pose_items(people: Array, items: Array, self_id: String) -> Array:
	if items.is_empty():
		return people
	var by_id := {}
	for item in items:
		if item.id != self_id:
			by_id[item.id] = item
	if by_id.is_empty():
		return people
	var out: Array = []
	for person in people:
		if by_id.has(person.clientId):
			var item: Dictionary = by_id[person.clientId]
			var next: Dictionary = person.duplicate(true)
			next.x = item.x
			next.y = item.y
			next.facing = item.facing
			out.append(next)
		else:
			out.append(person)
	return out
```

`snapped(x, 0.1)` matches TS `Math.round(x * 10) / 10`.

- [ ] **Step 4: Run tests**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot/school/sync.gd godot/tests/test_sync.gd
git commit -m "Port school pose interpolation helpers to GDScript."
```

---

### Task 4: Pixel templates and image paint

**Files:**
- Create: `godot/pet/templates.gd`
- Create: `godot/tests/test_templates.gd`

**Interfaces:**
- Consumes: nothing
- Produces: `class_name PetTemplates` with `SPECIES` PackedStringArray, `SPECIES_LABELS`, `DEFAULT_COLORS`, `get_frame(species, pose) -> PackedStringArray`, `paint_image(frame, colors, pixel_size) -> Image`, `opaque_count(image) -> int`

This slice only needs `idle` and `blink`. Unknown pose returns `idle`. Do not port weather gear.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends RefCounted

func run() -> int:
	var failed := 0
	failed += _check("six species", PetTemplates.SPECIES.size() == 6)
	failed += _check("blob label", PetTemplates.SPECIES_LABELS["blob"] == "软萌团")
	failed += _check("cat body", PetTemplates.DEFAULT_COLORS["cat"].body == "#F4A261")
	var frame: PackedStringArray = PetTemplates.get_frame("blob", "idle")
	failed += _check("16 rows", frame.size() == 16)
	failed += _check("16 cols", frame[0].length() == 16)
	var img: Image = PetTemplates.paint_image(frame, PetTemplates.DEFAULT_COLORS["blob"], 4)
	failed += _check("size", img.get_width() == 64 and img.get_height() == 64)
	failed += _check("opaque", PetTemplates.opaque_count(img) > 0)
	for species in PetTemplates.SPECIES:
		var idle: PackedStringArray = PetTemplates.get_frame(species, "idle")
		var blink: PackedStringArray = PetTemplates.get_frame(species, "blink")
		failed += _check("%s idle" % species, idle.size() == 16 and idle[0].length() == 16)
		failed += _check("%s blink" % species, blink.size() == 16)
	var fallback: PackedStringArray = PetTemplates.get_frame("blob", "wave")
	failed += _check("fallback idle", fallback == PetTemplates.get_frame("blob", "idle"))
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("templates: %s" % label)
	return 1
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL (`PetTemplates` missing).

- [ ] **Step 3: Implement `templates.gd`**

`# 源：src/pet/templates.ts` and `# 源：shared/types.ts DEFAULT_COLORS / SPECIES_LABELS`

Copy `idle` and `blink` string arrays for all six species from `src/pet/templates.ts` (`CAT_IDLE` / `CAT_BLINK` … `BLOB_IDLE` / `BLOB_BLINK`). Pad every row with:

```gdscript
static func pad_row(row: String) -> String:
	return (row + "................").substr(0, 16)
```

`get_frame` returns 16 padded rows. `DEFAULT_COLORS` is a Dictionary of Dictionaries with keys `outline body shadow light accent eye pupil blush` and the hex values from `shared/types.ts` (cat body `#F4A261`, blob body `#FFC2D4`, etc.). Labels: 小猫 小狗 兔子 小鸟 仓鼠 软萌团.

`paint_image`: create `Image` `16*pixel_size` square, `FORMAT_RGBA8`, fill transparent. For each cell `.` skip; otherwise map `#BDL AEPC` to those color keys (`#→outline`, `B→body`, `D→shadow`, `L→light`, `A→accent`, `E→eye`, `P→pupil`, `C→blush`) and fill a `pixel_size` square with `Color.html(hex)`.

```gdscript
static func opaque_count(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return n
```

- [ ] **Step 4: Run tests**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot/pet/templates.gd godot/tests/test_templates.gd
git commit -m "Port idle and blink pixel templates into Godot images."
```

---

### Task 5: Local archive

**Files:**
- Create: `godot/autoload/app_state.gd` (replace stub)
- Create: `godot/tests/test_app_state.gd`

**Interfaces:**
- Consumes: `PetTemplates.DEFAULT_COLORS`, `SchoolLogic.DEFAULT_ROOM_URL`
- Produces: Autoload `AppState` with `state: Dictionary`, `load_from(path)`, `save_to(path)`, `sanitize_name(text) -> String`, `set_species(species)`, `set_name(text) -> bool`, `set_room_url(url) -> String` (empty string means OK, otherwise error), `mark_onboarded()`, `save_world_size(w, h)`, `pet_for_hello() -> Dictionary`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends RefCounted

func run() -> int:
	var failed := 0
	var path := "user://test-bbpet-state.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var s: Node = AppState
	s.load_from(path)
	failed += _check("default name", s.state.pet.name == "豆豆")
	failed += _check("default species", s.state.pet.species == "blob")
	failed += _check("not onboarded", s.state.onboarded == false)
	failed += _check("clientId", String(s.state.clientId).length() >= 8)
	failed += _check("room", s.state.settings.roomUrl == SchoolLogic.DEFAULT_ROOM_URL)
	failed += _check("empty name", s.set_name("   ") == false)
	failed += _check("trim name", s.set_name("  豆包豆包豆包豆包  ") and s.state.pet.name == "豆包豆包豆包豆包".substr(0, 12))
	s.set_species("cat")
	failed += _check("cat colors", s.state.pet.colors.body == PetTemplates.DEFAULT_COLORS["cat"].body)
	failed += _check("bad url", s.set_room_url("http://x") != "")
	failed += _check("ws url", s.set_room_url("ws://127.0.0.1:18765") == "")
	s.mark_onboarded()
	s.save_to(path)
	var raw := FileAccess.get_file_as_string(path)
	failed += _check("no apiKey", not raw.contains("apiKey"))
	s.state = {}
	s.load_from(path)
	failed += _check("reload onboarded", s.state.onboarded == true)
	failed += _check("reload cat", s.state.pet.species == "cat")
	var hello: Dictionary = s.pet_for_hello()
	failed += _check("hello keys", hello.has("name") and hello.has("species") and hello.has("colors") and not hello.has("photoDataUrl"))
	var bad := "user://test-bbpet-bad.json"
	var f := FileAccess.open(bad, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	s.load_from(bad)
	failed += _check("corrupt reset", s.state.onboarded == false and s.state.pet.species == "blob")
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("app_state: %s" % label)
	return 1
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL on missing methods.

- [ ] **Step 3: Implement `app_state.gd`**

Default pet blob/豆豆/`DEFAULT_COLORS.blob`. Generate `clientId` with `Crypto.generate_random_bytes` formatted as 8-4-4-4-12 hex. `sanitize_name`: strip edges, slice to 12, reject empty. `set_room_url`: must begin with `ws://` or `wss://`; on failure return `学校地址要以 ws:// 或 wss:// 开头`. Persist only the spec JSON subset (`onboarded`, `clientId`, `pet`, `settings.roomUrl`, `settings.worldWidth`, `settings.worldHeight`). Defaults 820×560. `_ready` calls `load_from("user://bbpet-state.json")`.

- [ ] **Step 4: Run tests**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot/autoload/app_state.gd godot/tests/test_app_state.gd
git commit -m "Store Godot pet profile in a local JSON archive."
```

---

### Task 6: Room JSON messages

**Files:**
- Create: `godot/net/room_messages.gd`
- Create: `godot/tests/test_room_messages.gd`

**Interfaces:**
- Consumes: nothing
- Produces: `class_name RoomMessages` with `encode(dict) -> PackedByteArray` UTF-8 JSON; `parse_server(text) -> Dictionary` either `{ "ignored": true }` or `{ "ignored": false, "type": String, "msg": Dictionary }`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends RefCounted

func run() -> int:
	var failed := 0
	var hello := RoomMessages.parse_client_roundtrip({
		"type": "hello",
		"clientId": "abc",
		"pet": {"name": "豆豆", "species": "blob", "colors": {"body": "#fff"}},
	})
	failed += _check("hello type", hello.type == "hello" and hello.clientId == "abc")
	var parsed: Dictionary = RoomMessages.parse_server('{"type":"notice","text":"满员"}')
	failed += _check("notice", parsed.ignored == false and parsed.type == "notice")
	var drop: Dictionary = RoomMessages.parse_server('{"type":"chat","line":{}}')
	failed += _check("drop chat", drop.ignored == true)
	var drop2: Dictionary = RoomMessages.parse_server('{"type":"gameState"}')
	failed += _check("drop game", drop2.ignored == true)
	var bad: Dictionary = RoomMessages.parse_server("not-json")
	failed += _check("bad json", bad.ignored == true)
	var welcome: Dictionary = RoomMessages.parse_server('{"type":"welcome","you":{"clientId":"a","placeId":"home:a"}}')
	failed += _check("welcome", welcome.type == "welcome" and welcome.msg.you.clientId == "a")
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("room_messages: %s" % label)
	return 1
```

`parse_client_roundtrip` can be a test helper: `JSON.parse_string(RoomMessages.encode(d).get_string_from_utf8())`.

Handled types: `welcome snapshot join leave move poses error notice`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL.

- [ ] **Step 3: Implement `room_messages.gd`**

```gdscript
class_name RoomMessages
extends RefCounted

const HANDLED := ["welcome", "snapshot", "join", "leave", "move", "poses", "error", "notice"]

static func encode(msg: Dictionary) -> PackedByteArray:
	return JSON.stringify(msg).to_utf8_buffer()

static func parse_server(text: String) -> Dictionary:
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not data.has("type"):
		return { "ignored": true }
	var kind := String(data.type)
	if kind not in HANDLED:
		return { "ignored": true }
	return { "ignored": false, "type": kind, "msg": data }
```

- [ ] **Step 4: Run tests**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot/net/room_messages.gd godot/tests/test_room_messages.gd
git commit -m "Parse the principal JSON subset used by the Godot client."
```

---

### Task 7: PixelPet control

**Files:**
- Create: `godot/pet/pixel_pet.gd`
- Create: `godot/pet/pixel_pet.tscn`
- Create: `godot/tests/test_pixel_pet.gd`

**Interfaces:**
- Consumes: `PetTemplates.get_frame`, `PetTemplates.paint_image`
- Produces: `PixelPet` (`TextureRect`) with exported/settable `species`, `colors`, `pose`, `pixel_size`, `flip`; `redraw()`; `current_image() -> Image`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends RefCounted

func run() -> int:
	var failed := 0
	var pet: TextureRect = preload("res://pet/pixel_pet.tscn").instantiate()
	pet.species = "cat"
	pet.colors = PetTemplates.DEFAULT_COLORS["cat"]
	pet.pose = "idle"
	pet.pixel_size = 2
	pet.redraw()
	var img: Image = pet.current_image()
	failed += _check("school size", img.get_width() == 32)
	failed += _check("opaque", PetTemplates.opaque_count(img) > 0)
	pet.queue_free()
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("pixel_pet: %s" % label)
	return 1
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL missing scene.

- [ ] **Step 3: Implement**

`pixel_pet.gd` extends `TextureRect`. `texture_filter = TEXTURE_FILTER_NEAREST`. `flip_h = flip`. `redraw` paints with `PetTemplates` and sets `texture` from `ImageTexture.create_from_image`. School uses `pixel_size = 2` (32×32). Desk pet uses `pixel_size = 4` (64×64) centered in the 64×86 window (leave 22px vertical padding; draw at y offset 11 or similar so the sprite sits in the box).

- [ ] **Step 4: Run tests**

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot/pet/pixel_pet.gd godot/pet/pixel_pet.tscn godot/tests/test_pixel_pet.gd
git commit -m "Draw template pets as nearest-neighbor textures."
```

---

### Task 8: Transparent desk pet window

**Files:**
- Modify: `godot/windows/pet_root.gd`
- Modify: `godot/windows/pet_root.tscn`
- Modify: `godot/autoload/window_hub.gd` (click/toggle API used here; implement the methods this task needs even if panels are still empty)

**Interfaces:**
- Consumes: `AppState.state`, `PixelPet`, `WindowHub.toggle_panel()`, `WindowHub.hide_pet()`, `WindowHub.quit_app()`
- Produces: Main window: transparent, always-on-top, 64×86, bottom-right first placement; drag if move > 4px; click toggles panel; right-click menu 隐藏/退出; idle/blink; `mouse_passthrough_polygon` from opaque pixels (fallback: empty polygon / whole window receives clicks)

- [ ] **Step 1: No new unit test** — window flags cannot be asserted headless. Keep `test_pixel_pet` green.

- [ ] **Step 2: Implement `pet_root.gd`**

On `_ready`:

```gdscript
var win := get_window()
win.borderless = true
win.unresizable = true
win.always_on_top = true
win.transparent = true
win.size = Vector2i(64, 86)
var wa := DisplayServer.screen_get_usable_rect()
win.position = Vector2i(wa.end.x - 72, wa.end.y - 94)
```

Add a `PixelPet` child, `pixel_size = 4`, species/colors from `AppState`. Blink: after 2.5–4.5s random idle, pose `blink` for 0.12s, back to idle.

Input: `_gui_input`. Left button down stores origin. Mouse motion with button: if distance > 4, set `_dragging` and move `win.position` by relative motion. Left button up: if not dragging, `WindowHub.toggle_panel()`. Right button up: `PopupMenu` with 隐藏 (id 0) and 退出 (id 1).

After each redraw, build passthrough:

```gdscript
func _update_passthrough() -> void:
	var img: Image = $PixelPet.current_image()
	var points := PackedVector2Array()
	# convex hull of pixels with alpha > 0.5, plus the 11px vertical offset of the sprite
	# if fewer than 3 points: get_window().mouse_passthrough = false
	# else: get_window().mouse_passthrough = true
	#        get_window().mouse_passthrough_polygon = hull
```

Use a simple monotone-chain convex hull on the opaque pixel corners.

Stub in `window_hub.gd` if not yet complete:

```gdscript
extends Node
signal panel_toggled
func toggle_panel() -> void: panel_toggled.emit()
func hide_pet() -> void:
	if _has_tray:
		get_window().hide()
	else:
		get_window().mode = Window.MODE_MINIMIZED
func quit_app() -> void:
	get_tree().quit()
func show_pet() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().always_on_top = true
var _has_tray := false
```

Place pet in the bottom-right only when `not FileAccess.file_exists` of a saved position; optional YAGNI: always bottom-right on first launch of a process is enough.

- [ ] **Step 3: Manual check in editor**

Run the main scene. Expected: tiny transparent pet, desktop clicks pass through empty corners, pet is draggable, left click does not crash.

- [ ] **Step 4: Run headless tests**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot/windows/pet_root.gd godot/windows/pet_root.tscn godot/autoload/window_hub.gd
git commit -m "Make the Godot main window a transparent draggable desk pet."
```

---

### Task 9: Wizard, hub, and settings panels

**Files:**
- Create: `godot/windows/panel_window.gd`
- Create: `godot/windows/panel_window.tscn`
- Modify: `godot/autoload/window_hub.gd`

**Interfaces:**
- Consumes: `AppState`, `PixelPet`, `WindowHub.open_world()` (may stub until Task 11)
- Produces: Extra `Window` sized per kind: wizard 340×520, hub 300×430, settings 340×640. `WindowHub.open_panel(kind)`, `close_panel()`, `toggle_panel()`, `panel_is_open() -> bool`. Kind is `wizard|hub|settings`.

- [ ] **Step 1: Implement panel contents**

Wizard: six `Button`s labeled with `PetTemplates.SPECIES_LABELS`; `LineEdit` for name (placeholder 名字); `Button` 确定. 确定 calls `set_species`, `set_name` (if false, show 请给宠物起个名字), `mark_onboarded`, `save`, `close_panel`, tell pet to redraw.

Hub: `PixelPet` preview; buttons 去上学 and 设置. 去上学 → `WindowHub.go_to_school()`. 设置 → `open_panel("settings")`.

Settings: name, species OptionButton (Chinese labels, ids = species keys), room URL LineEdit. Save button 保存: `set_name`, `set_species`, `set_room_url` (if error, show that string). Then `save`. If `RoomClient.connected`: disconnect, close world. Close panel.

`WindowHub.toggle_panel()`: if any panel visible, `close_panel()`; else if not `AppState.state.onboarded` open `wizard` else open `hub`.

Position panel: `pet_pos + Vector2i(pet_w + 8, 0)`; if that exceeds usable rect, put it on the left (`pet_pos.x - panel_w - 8`).

Unstyled Control theme is fine; use a solid `ColorRect` background `#fff8f2` so the extra window is opaque.

On `_ready` of WindowHub: if not onboarded, `open_panel("wizard")`.

Stub `go_to_school()` as `push_warning("go_to_school")` until Task 11, but the hub button must call it.

- [ ] **Step 2: Manual check**

First launch shows wizard. After confirm, left click opens hub. Settings persist across editor restarts (`user://bbpet-state.json`).

- [ ] **Step 3: Run headless tests**

Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add godot/windows/panel_window.gd godot/windows/panel_window.tscn godot/autoload/window_hub.gd godot/autoload/app_state.gd
git commit -m "Add onboarding, hub, and settings windows beside the pet."
```

---

### Task 10: Tray, hide, and quit

**Files:**
- Modify: `godot/autoload/window_hub.gd`
- Modify: `godot/windows/pet_root.gd` (right-click already wired)

**Interfaces:**
- Consumes: Godot `StatusIndicator`
- Produces: Tray menu 显示 / 隐藏 / 退出. `quit_app()` disconnects `RoomClient` then `get_tree().quit()`. Hide with tray: `pet window visible = false` (not destroy). Hide without tray: `MODE_MINIMIZED`. Never `visible=false` without a restore path.

- [ ] **Step 1: Implement tray**

In `WindowHub._ready`:

```gdscript
var indicator := StatusIndicator.new()
indicator.tooltip = "BbPet"
var img := PetTemplates.paint_image(PetTemplates.get_frame(AppState.state.pet.species, "idle"), AppState.state.pet.colors, 1)
indicator.icon = ImageTexture.create_from_image(img)
var menu := PopupMenu.new()
menu.add_item("显示", 1)
menu.add_item("隐藏", 2)
menu.add_separator()
menu.add_item("退出", 3)
add_child(menu)
indicator.menu = menu.get_path()
indicator.pressed.connect(_on_tray_pressed)
menu.id_pressed.connect(_on_tray_menu)
add_child(indicator)
_has_tray = true
```

If adding `StatusIndicator` errors at runtime, catch by checking `indicator.get_class()` and set `_has_tray = false`.

`quit_app`:

```gdscript
func quit_app() -> void:
	RoomClient.disconnect_room()
	get_tree().quit()
```

`RoomClient.disconnect_room()` may still be a stub `pass` until Task 11.

- [ ] **Step 2: Manual check**

Tray or right-click 退出 leaves the process. Without tray, 隐藏 minimizes; taskbar restores.

- [ ] **Step 3: Run headless tests**

Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add godot/autoload/window_hub.gd
git commit -m "Add tray and quit paths for the Godot desk pet."
```

---

### Task 11: School window rendering and local movement

**Files:**
- Create: `godot/school/paint.gd`
- Create: `godot/windows/world_window.gd`
- Create: `godot/windows/world_window.tscn`
- Create: `godot/tests/test_paint.gd`
- Modify: `godot/autoload/window_hub.gd`

**Interfaces:**
- Consumes: `SchoolLogic`, `PetSync`, `PixelPet`, `RoomClient` signals (connect in Task 12; this task must work with injected snapshot dictionaries)
- Produces: `class_name PlacePaint.image_for(place) -> Image`; `WorldWindow.apply_snapshot(you, people, place_id)`; WASD only while the school `Window` has focus; door `enterPlace` callback; campus `x` trigger closes world

- [ ] **Step 1: Write paint tests**

```gdscript
extends RefCounted

func run() -> int:
	var failed := 0
	var campus: Dictionary = SchoolLogic.PLACES["school:campus"]
	var img: Image = PlacePaint.image_for(campus)
	var size: Dictionary = SchoolLogic.map_size(campus)
	failed += _check("w", img.get_width() == size.cols * SchoolLogic.TILE)
	failed += _check("h", img.get_height() == size.rows * SchoolLogic.TILE)
	var px: Color = img.get_pixel(12 * 32 + 16, 12 * 32 + 16)
	failed += _check("spawn tile not black", px.a > 0.5)
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("paint: %s" % label)
	return 1
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL.

- [ ] **Step 3: Implement `paint.gd`**

`# 源：src/world/paint.ts`

Fill each tile with `SchoolLogic.tile_color`, 2px inset stroke `tile_accent`. Campus `f` on `ty==2`: extra `#8ecae6` inner rect like the TS. Draw labels: dark `#3d2c29` box, text `#fff8f2`, font size 12. `image_smoothing` is not a thing on `Image`; just set pixels. For text, `Font.get_string_size` with ThemeDB fallback font, blit via `font.draw_string` onto an `Image` using a temporary `BitMap` **or** draw labels in the `WorldWindow` `_draw` on a `Control` overlay instead of baking text into the Image. Prefer overlay `Label`s positioned at `tx*TILE+TILE/2` so paint tests only check tile pixels.

- [ ] **Step 4: Implement `world_window.gd`**

Extra `Window`: title 学校, size from `AppState.state.settings.worldWidth/Height`, min 520×380, opaque (not transparent), not always-on-top. On close request: `WindowHub.close_world()`.

Scene tree: `Window` → `VBox` → top `Label` (place title + status) → `Control` map stage (`clip_contents`). Map stage draws `TextureRect` of the place image with `TEXTURE_FILTER_NEAREST`, positioned at `camera_for` left/top, scale 1.8 (use `scale` on a `Node2D` parent). Pets are `PixelPet` instances parented to that `Node2D` at `(x, y)` with `pixel_size=2`, `flip = facing=="l"`. Everyone including self uses pose `idle`.

`_physics_process(delta)`:

```
if not has_focus(): return
read WASD/arrows via `Input.is_physical_key_pressed` on `KEY_A/D/W/S` and `KEY_LEFT/RIGHT/UP/DOWN` (build a Vector2 yourself; diagonal normalize)
if vector == 0: maybe send a trailing move once (match WorldApp)
else: clamp_move, update facing, every MOVE_SEND_MS RoomClient.send_move(round_pose...)
if Time.now > ignore_door_until:
  trigger_at → exit: WindowHub.close_world()
  campus: RoomClient.enter_place("school:campus"); ignore_door_until = now+0.8
  classroom: RoomClient.enter_place(id); ignore_door_until = now+0.8
```

Do not overwrite local `you.x/y` from `poses`. On `apply_snapshot`, set place, rebuild map texture, set `you` from snapshot `you`, set `others` via `keep_visual_people`.

Interpolate others each frame with `PetSync.interpolate_pose` using last `poses` time.

- [ ] **Step 5: Run tests**

Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add godot/school/paint.gd godot/windows/world_window.gd godot/windows/world_window.tscn godot/tests/test_paint.gd godot/autoload/window_hub.gd
git commit -m "Render school maps and walk them with WASD in a Godot window."
```

---

### Task 12: WebSocket client and go-to-school flow

**Files:**
- Modify: `godot/autoload/room_client.gd`
- Modify: `godot/autoload/window_hub.gd`
- Create: `godot/tests/test_room_client_flow.gd`

**Interfaces:**
- Consumes: `RoomMessages`, `AppState.pet_for_hello()`, `AppState.state.clientId`, `AppState.state.settings.roomUrl`
- Produces: `RoomClient.connect_room(url)`, `disconnect_room()`, `enter_place(place_id)`, `send_move(x, y, facing)`, `connected: bool`, `status_text: String`. Signals: `connect_failed(reason)`, `status(text)`, `snapshot_ready(you, people, place_id)`, `others_updated(people)`, `disconnected`

- [ ] **Step 1: Write a flow test that does not need a live server**

Drive a fake by calling internal `_handle_server_text` (keep that function on `RoomClient`):

```gdscript
extends RefCounted

func run() -> int:
	var failed := 0
	var rc: Node = RoomClient
	rc.disconnect_room()
	var saw := {"campus": false}
	var on_snap := func(you, people, place_id):
		if place_id == "school:campus":
			saw.campus = true
	rc.snapshot_ready.connect(on_snap)
	rc.begin_school_flow()
	rc._handle_server_text('{"type":"welcome","you":{"clientId":"x","placeId":"home:x","x":0,"y":0}}')
	failed += _check("queued enter", rc.last_enter_requested == "school:campus")
	rc._handle_server_text('{"type":"snapshot","you":{"clientId":"x","x":384,"y":348,"facing":"r","species":"blob","name":"豆豆","colors":{}},"snapshot":{"placeId":"school:campus","people":[]}}')
	failed += _check("campus snapshot", saw.campus)
	rc._handle_server_text('{"type":"chat","line":{"text":"hi"}}')
	failed += _check("ignored chat", rc.status_text.find("hi") == -1)
	rc._handle_server_text('{"type":"error","message":"学校人满了"}')
	failed += _check("error text", rc.status_text.contains("学校人满了"))
	rc.snapshot_ready.disconnect(on_snap)
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("room_client: %s" % label)
	return 1
```

`begin_school_flow()` sets `pending_enter = "school:campus"`. On `welcome`, call `enter_place("school:campus")`, which sets `last_enter_requested` even if the socket is closed (so the unit test can observe it). Snapshot `place_id` always comes from `msg.snapshot.placeId`. `error.message` is copied into `status_text` truncated to 80 chars, single line.

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL.

- [ ] **Step 3: Implement `room_client.gd`**

`WebSocketPeer` in `_process`: `poll()`. On `STATE_OPEN` first time: send `hello` `{type, clientId, pet: AppState.pet_for_hello()}`. Then if `pending_enter != ""`, send `{type:"enterPlace", placeId}`. Read packets as UTF-8, `RoomMessages.parse_server`. 

- `welcome`: store `you`; if school flow, `enter_place("school:campus")`.
- `snapshot`: emit `snapshot_ready` with `msg.you`, `msg.snapshot.people`, `msg.snapshot.placeId`.
- `join`: append person if same place.
- `leave`: remove by clientId.
- `move` / `poses`: update others (not self).
- `error`: `status_text = String(msg.get("message", msg.get("text", ""))).replace("\n"," ").substr(0, 80)`; emit `status`.
- `notice`: same.
- `STATE_CLOSED` after having been open: `status_text = "已断开"`; emit `disconnected`; do not auto-reconnect.

`connect_room(url)`: if url empty, emit `connect_failed("连不上学校")`. `connect_to_url`. On fail to open, `connect_failed("连不上学校")`.

`send_move` only if connected and (x,y,facing) changed since last send.

`disconnect_room`: close peer, `connected = false`, `pending_enter = ""`.

`WindowHub.go_to_school()`:

```
if world_window visible: world_window.grab_focus(); return
RoomClient.connect_failed.connect once → show 连不上学校 on hub/world top label; do not crash pet
RoomClient.snapshot_ready → show world, apply_snapshot
RoomClient.connect_room(AppState.state.settings.roomUrl)
RoomClient.begin_school_flow()
```

`close_world()`: hide/free world window, `RoomClient.disconnect_room()`, save world size from window.size.

- [ ] **Step 4: Run unit tests**

Expected: exit 0.

- [ ] **Step 5: Manual interop**

Terminal 1: `npm run room`

Godot: 去上学 → walk campus and four classrooms.

Terminal 2: `npm start` Electron pet, go to school. Both see each other; species/colors match.

Close Godot school window: principal logs leave; desk pet remains.

Go to school with principal down: `连不上学校`, pet stays.

- [ ] **Step 6: Commit**

```bash
git add godot/autoload/room_client.gd godot/autoload/window_hub.gd godot/windows/world_window.gd godot/tests/test_room_client_flow.gd
git commit -m "Connect the Godot client to the existing school principal."
```

---

### Task 13: README and Windows export

**Files:**
- Modify: `README.md`
- Create: `godot/export_presets.cfg`

**Interfaces:**
- Consumes: working Godot project
- Produces: README section that does not remove Electron instructions

- [ ] **Step 1: README section** (insert after 本机开发, keep Electron steps)

```markdown
## Godot 客户端（实验）

需要 [Godot 4.4+](https://godotengine.org/download)（编辑器命令行能跑 `godot`）。校长仍是 Node，不要用 Godot 当校长。

用编辑器打开 `godot/project.godot`，或：

```bat
godot --path godot
```

纯函数测试：

```bat
npm run test:godot
```

先另开一个终端跑 `npm run room`。Godot 里左键枢纽 → 去上学。设置里学校地址默认 `ws://127.0.0.1:18765`。

和现在的 Electron 客户端对照时，用两只不同的宠（两份档案、两个 id）。不要把 Godot 的 `user://bbpet-state.json` 拷到 Electron 的 userData。本机可同时 `npm start` 一只 Electron 宠，进同一所学校应能互相看见。

导出给同事：编辑器 项目 → 导出 → Windows Desktop。EXE 不包含校长进程，同事仍要有人跑 `npm run room`，并在设置里填 `ws://内网IP:18765`。
```

- [ ] **Step 2: `export_presets.cfg`**

Add a Windows Desktop preset, `export_path="export/bbpet.exe"`, `application/name="BbPet"`. Runnable from the editor Export dialog. Do not commit built EXE.

- [ ] **Step 3: Commit**

```bash
git add README.md godot/export_presets.cfg
git commit -m "Document the experimental Godot client and Windows export."
```

---

## Self-review

**Spec coverage**

| Spec item | Task |
| --- | --- |
| `godot/` project, Electron kept | 1, 13 |
| Main window = pet 64×86 transparent always-on-top | 1, 8 |
| Panel + world extra windows | 9, 11 |
| Runtime templates + tile paint | 4, 7, 11 |
| `hello` / `enterPlace` / `move` only | 6, 12 |
| Drop chat/friends/game/pose | 6, 12 |
| Archive subset JSON | 5 |
| Wizard + hub + settings | 9 |
| Tray with right-click/minimize fallback | 10 |
| WASD, doors, camera 1.8, idle classmates | 11, 12 |
| Close world = disconnect | 12 |
| Campus `x` exit (Electron parity) | 11 |
| Headless tests | 1–6, 7, 11, 12 |
| README Godot section | 13 |
| No principal / protocol edits | all |

**Not in tasks (intentional YAGNI):** weather gear, full pose overlays, LLM, gomoku, friends, hosting principal, shared JSON for TS+GDScript, PowerShell click-through, `screen-saver` z-order.
