# Godot Home Gathering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add home occupancy, visiting, a desk-pet living-room gathering, directed emotes, and home chat to the Godot client without changing the principal.

**Architecture:** Living room is not a new system window. `PetRoot` resizes the 64×86 pet window when `is_home_gathering` is true. `home_logic.gd` ports yard metrics and emote poses. `RoomClient` keeps school `place_id` and home occupancy **separate** so a home snapshot/join never overwrites the school place or opens `WorldWindow`. Pose frames come from `src/pet/templates.ts`. Kick stays in-slot.

**Tech Stack:** Godot 4.4+ GDScript, existing Node principal. Headless tests via `res://tests/run_tests.gd`.

**Spec:** `docs/superpowers/specs/2026-09-05-godot-home-gathering-design.md`

## Global Constraints

- Godot 4.4+ / GDScript only; all client work is under `godot/`. Do not modify `server/`, `shared/`, or Electron except one README sentence.
- Do not send `enterPlace("away")` on close. School window hide-only. Home snapshots must not `show_world`.
- Dual occupancy: school `place_id` is only updated from `school:` snapshots. Home `join`/`leave`/`snapshot`/`chat` use `you.homeId`.
- 「在家」= `online && homeId == home:{clientId}` (at school still counts). Visiting someone else = not at home.
- Emotes: hug/pour/wake/kick only, 5s local disable, no optimistic pose. Kick does not fly out of the window.
- Chat: `sanitize_chat` as today. Home chat uses `you.homeId`. Classroom chat unchanged.
- User-visible strings are the exact Chinese in each task. Git commits stay English.
- Tests: `godot --headless --path godot --script res://tests/run_tests.gd`. If `godot` is not on PATH, use `c:\Users\huangyazhe\Projects\bbpet\.tools\godot\Godot_v4.4.1-stable_win64.exe --headless --path godot --script res://tests/run_tests.gd`.
- No gomoku, LLM, weather dress, slack pose loop, flyer window, or Godot-as-principal.

## File Structure

- Create: `godot/home/home_logic.gd`
- Create: `godot/tests/test_home_logic.gd`
- Modify: `godot/pet/templates.gd` — full pose table
- Modify: `godot/tests/test_templates.gd`
- Modify: `godot/net/room_messages.gd` — HANDLED `emote`, `pose`
- Modify: `godot/tests/test_room_messages.gd`
- Modify: `godot/autoload/room_client.gd` — home cache + go_home/emote/home chat
- Modify: `godot/tests/test_room_client_flow.gd`
- Modify: `godot/autoload/window_hub.gd` — `go_home`
- Modify: `godot/windows/panel_window.gd` — 回家, 进他家
- Modify: `godot/tests/test_panel_window.gd`
- Modify: `godot/windows/world_window.gd` — 去他家
- Modify: `godot/tests/test_world_social.gd`
- Modify: `godot/windows/pet_root.gd` — gathering layout
- Create: `godot/tests/test_pet_gathering.gd`
- Modify: `README.md`

---

### Task 1: Home logic helpers

**Files:**
- Create: `godot/home/home_logic.gd`
- Create: `godot/tests/test_home_logic.gd`

**Interfaces:**
- Consumes: nothing
- Produces: `class_name HomeLogic` with constants `SLOT_W=72`, `SLOT_H=94`, `YARD_PAD_X=24`, `YARD_PAD_TOP=40`, `MENU_RESERVE=80`, `BAR_H=30`, `BAR_MIN_W=144`, `MAX_COLS=4`, `LOG_PAD=6`, `LOG_LINE=15`, `LOG_MAX_LINES=3`, `EMOTE_COOLDOWN_MS=5000`
- `home_place_id(owner_id: String) -> String` → `"home:" + owner_id`
- `home_owner_id(place_id: String) -> String` → slice after `home:` else `""`
- `is_friend_at_home(card: Dictionary) -> bool`
- `is_home_gathering(you: Dictionary, home_people: Array, my_id: String) -> bool`
- `yard_metrics(people: int, chatting: bool, log_lines: int = 0) -> Dictionary` keys `cols, rows, petsW, logH, barW, barLeft, width, height`
- `slot_offset(index: int, people: int) -> Dictionary` keys `x, y`
- `chat_log_h(lines: int) -> int`
- `pose_for_action(emote: Dictionary, client_id: String, resting: String) -> String`
- `label_for_action(emote: Dictionary, client_id: String) -> String`
- `emote_label(kind: String) -> String` → 抱抱/倒水/拍醒/飞踢
- `gathering_title(you: Dictionary, guests: Array, my_id: String) -> String` → `自家` or `{name}家`

- [ ] **Step 1: Write the failing test**

Create `godot/tests/test_home_logic.gd`:

```gdscript
extends RefCounted

const HomeLogic = preload("res://home/home_logic.gd")


func run() -> int:
	var failed := 0
	failed += _check("home id", HomeLogic.home_place_id("abc") == "home:abc")
	failed += _check("owner", HomeLogic.home_owner_id("home:abc") == "abc")
	failed += _check("owner empty", HomeLogic.home_owner_id("school:campus") == "")
	failed += _check(
		"at home while at school",
		HomeLogic.is_friend_at_home({"online": true, "clientId": "a", "homeId": "home:a", "schoolPlaceId": "school:campus"})
	)
	failed += _check(
		"visiting not at home",
		not HomeLogic.is_friend_at_home({"online": true, "clientId": "a", "homeId": "home:b"})
	)
	failed += _check(
		"offline",
		not HomeLogic.is_friend_at_home({"online": false, "clientId": "a", "homeId": "home:a"})
	)
	var me := {"homeId": "home:me"}
	failed += _check("alone not gathering", not HomeLogic.is_home_gathering(me, [], "me"))
	failed += _check("guest gathering", HomeLogic.is_home_gathering(me, [{"clientId": "x"}], "me"))
	failed += _check("visiting gathering", HomeLogic.is_home_gathering({"homeId": "home:host"}, [], "me"))
	var one: Dictionary = HomeLogic.yard_metrics(1, false)
	failed += _check("one width", int(one.width) == 248)
	failed += _check("one height", int(one.height) == 164)
	failed += _check("one barW", int(one.barW) == 144)
	var two: Dictionary = HomeLogic.yard_metrics(2, false)
	failed += _check("two width", int(two.width) == 248)
	failed += _check("two petsW", int(two.petsW) == 144)
	var five: Dictionary = HomeLogic.yard_metrics(5, false)
	failed += _check("five width", int(five.width) == 392)
	failed += _check("five height", int(five.height) == 258)
	failed += _check("chat log 0", HomeLogic.chat_log_h(0) == 0)
	failed += _check("chat log 3", HomeLogic.chat_log_h(3) == 51)
	failed += _check("chat log cap", HomeLogic.chat_log_h(8) == 51)
	var hug := {"kind": "hug", "fromId": "a", "targetId": "b"}
	failed += _check("hug from pose", HomeLogic.pose_for_action(hug, "a", "idle") == "talk")
	failed += _check("hug to pose", HomeLogic.pose_for_action(hug, "b", "idle") == "talk")
	failed += _check("hug from label", HomeLogic.label_for_action(hug, "a") == "抱抱")
	var kick := {"kind": "kick", "fromId": "a", "targetId": "b"}
	failed += _check("kick from pose", HomeLogic.pose_for_action(kick, "a", "idle") == "wake")
	failed += _check("kick to pose", HomeLogic.pose_for_action(kick, "b", "idle") == "peek")
	failed += _check("kick to label", HomeLogic.label_for_action(kick, "b") == "转圈飞走")
	failed += _check("emote hug", HomeLogic.emote_label("hug") == "抱抱")
	failed += _check("emote pour", HomeLogic.emote_label("pour") == "倒水")
	failed += _check("emote wake", HomeLogic.emote_label("wake") == "拍醒")
	failed += _check("emote kick", HomeLogic.emote_label("kick") == "飞踢")
	failed += _check("title home", HomeLogic.gathering_title({"homeId": "home:me", "name": "甲"}, [], "me") == "自家")
	failed += _check(
		"title visit",
		HomeLogic.gathering_title({"homeId": "home:host"}, [{"clientId": "host", "name": "乙"}], "me") == "乙家"
	)
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("home_logic: %s" % label)
	return 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL missing `res://home/home_logic.gd`.

- [ ] **Step 3: Write `godot/home/home_logic.gd`**

Port numbers from `shared/homeActions.ts`. `pose_for_action` matches `poseForAction` (wake target not sleeping → `wave`; hug talk/talk; pour drink/drink; wake from `wave` to `wake`; kick from `wake` to `peek`). `label_for_action` uses actorLabel/targetLabel from HOME_ACTIONS. `yard_metrics` formula:

`width = YARD_PAD_X + max(BAR_MIN_W, cols*SLOT_W) + MENU_RESERVE`

`height = YARD_PAD_TOP + rows*SLOT_H + BAR_H + (chatting ? chat_log_h(log_lines) : 0)`

`chat_log_h`: 0 if lines<=0 else `mini(LOG_PAD + LOG_MAX_LINES*LOG_LINE, LOG_PAD + lines*LOG_LINE)` which equals `LOG_PAD + mini(lines, LOG_MAX_LINES)*LOG_LINE`.

`is_friend_at_home`: `card.get("online", false)` and `String(card.get("homeId","")) == home_place_id(String(card.get("clientId","")))`.

`is_home_gathering`: if you empty false; if `home_owner_id(you.homeId) != my_id` return true; else `home_people.size() > 0`.

`gathering_title`: if owner is me `自家` else find guest with that id and `name + "家"` (fallback `好友家`).

Include `HOME_ACTIONS` dictionary with duration/actorPose/targetPose/actorLabel/targetLabel (no flyer playback).

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```
git commit -m "Add home gathering helpers for yards, visits, and emotes."
```

---

### Task 2: Port pose frames

**Files:**
- Modify: `godot/pet/templates.gd`
- Modify: `godot/tests/test_templates.gd`

**Interfaces:**
- Consumes: idle/blink already in `FRAMES`
- Produces: `get_frame(species, pose)` returns talk/drink/sleep/wake/type/phone/snack/peek/game/wave/coffee/toilet, not idle fallback

- [ ] **Step 1: Change tests**

In `test_templates.gd` replace the `unknown pose falls back to idle` check with:

```gdscript
	for pose in ["talk", "drink", "sleep", "wake", "wave", "peek"]:
		var frame: PackedStringArray = PetTemplates.get_frame("blob", pose)
		failed += _check("blob %s 16" % pose, _is_16_square(frame))
		failed += _check("blob %s differs idle" % pose, frame != PetTemplates.get_frame("blob", "idle"))
	failed += _check(
		"unknown pose falls back to idle",
		PetTemplates.get_frame("blob", "dance") == PetTemplates.get_frame("blob", "idle")
	)
```

- [ ] **Step 2: Run — expect FAIL** `blob wave differs idle` (currently wave==idle).

- [ ] **Step 3: Implement**

Copy from `src/pet/templates.ts`:

1. Each species `*_TALK` 16-row frame (already have idle/blink).
2. Overlay tables `BOWL`, `ZZZ`, `STRETCH`, `KEYBOARD`, `PHONE`, `SNACK`, `SWEAT`, `WAVE`, `COFFEE`, `TOILET`, `GAMEPAD`.
3. `overlay(base, cells)` and `species_poses(idle, blink, talk)` identical to `speciesPoses`.

Rebuild `FRAMES[species]` as the full pose dict. `get_frame`:

```gdscript
	var poses: Dictionary = FRAMES[selected_species]
	var selected_pose := pose if poses.has(pose) else "idle"
```

Do not invent new pixel art.

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```
git commit -m "Port desk-pet pose overlays into Godot templates."
```

---

### Task 3: Parse `emote` and `pose`

**Files:**
- Modify: `godot/net/room_messages.gd`
- Modify: `godot/tests/test_room_messages.gd`

**Interfaces:**
- Produces: `HANDLED` includes `emote` and `pose`; `dress` and `gameState` still ignored

- [ ] **Step 1: Tests**

Add:

```gdscript
	var emote: Dictionary = RoomMessages.parse_server('{"type":"emote","emote":{"kind":"hug"}}')
	failed += _check("parse emote", emote.ignored == false and emote.type == "emote")
	var pose: Dictionary = RoomMessages.parse_server('{"type":"pose","clientId":"a","pose":"drink"}')
	failed += _check("parse pose", pose.ignored == false and pose.type == "pose")
	var dress: Dictionary = RoomMessages.parse_server('{"type":"dress"}')
	failed += _check("drop dress", dress.ignored == true)
```

Keep `gameState` ignored.

- [ ] **Step 2: Run — expect FAIL parse emote**

- [ ] **Step 3: Add `"emote", "pose"` to `HANDLED`**

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```
git commit -m "Accept principal emote and pose messages in Godot."
```

---

### Task 4: RoomClient home occupancy

**Files:**
- Modify: `godot/autoload/room_client.gd`
- Modify: `godot/tests/test_room_client_flow.gd`

**Interfaces:**
- Consumes: `HomeLogic.home_place_id`, `SchoolSocial.should_open_world` / `sanitize_chat` / `append_board`
- Produces:
  - `signal home_updated`
  - `signal emote_received(emote: Dictionary)`
  - `var home_people: Array`, `var home_board: Array`, `var last_emote: Dictionary`, `var home_poses: Dictionary`
  - `func you_dict() -> Dictionary`
  - `func home_id() -> String`
  - `func my_id() -> String`
  - `func go_home(owner_id: String) -> void` → `enter_place("home:"+owner_id)`
  - `func send_home_chat(text: String) -> void` → chat with `placeId: home_id()`
  - `func send_emote(kind: String, target_id: String) -> void`
  - **Critical:** home snapshot must NOT assign `place_id` (school). `join`/`leave` for `home:` update `home_people` when `msg.placeId == home_id()`. School join/leave still keyed on `place_id`.

- [ ] **Step 1: Extend `test_room_client_flow.gd`**

Keep existing school tests. Add (after constructing `rc`):

```gdscript
	failed += _check("go_home API", rc.has_method("go_home") and rc.has_method("send_emote") and rc.has_method("send_home_chat"))
	rc.connected = true
	rc._handle_server_text(
		'{"type":"welcome","you":{"clientId":"x","homeId":"home:x","placeId":"home:x"},'
		+ '"home":{"placeId":"home:x","people":[{"clientId":"y","name":"乙"}],"board":[],"friends":[]}}'
	)
	failed += _check("welcome home people", rc.home_people.size() == 1)
	rc._handle_server_text(
		'{"type":"snapshot","you":{"clientId":"x","homeId":"home:x","schoolPlaceId":"school:campus"},'
		+ '"snapshot":{"placeId":"school:campus","people":[],"board":[]}}'
	)
	var school_place := rc.place_id
	failed += _check("school place", school_place == "school:campus")
	rc._handle_server_text(
		'{"type":"snapshot","you":{"clientId":"x","homeId":"home:x","schoolPlaceId":"school:campus"},'
		+ '"snapshot":{"placeId":"home:x","people":[{"clientId":"y","name":"乙"}],"board":[]}}'
	)
	failed += _check("home snapshot keeps school place", rc.place_id == "school:campus")
	failed += _check("home people from home snap", rc.home_people.size() == 1)
	failed += _check("home must not open world", SchoolSocial.should_open_world("home:x") == false)
	rc._handle_server_text(
		'{"type":"join","placeId":"home:x","person":{"clientId":"z","name":"丙"}}'
	)
	failed += _check("home join while at school", rc.home_people.size() == 2)
	rc.go_home("y")
	failed += _check("visit enter", rc.last_enter_requested == "home:y")
	rc.send_emote("hug", "y")
	failed += _check("emote payload", rc.last_sent.type == "emote" and rc.last_sent.kind == "hug" and rc.last_sent.targetId == "y")
	var pose_before := rc.home_people.duplicate(true)
	rc.send_emote("kick", "y")
	failed += _check("no optimistic emote pose", rc.home_people.size() == pose_before.size())
	rc.send_home_chat("  客厅  ")
	failed += _check("home chat", rc.last_sent.type == "chat" and rc.last_sent.placeId == "home:x" and rc.last_sent.text == "客厅")
```

If `welcome` currently does not fill `home_people`, the new asserts fail first.

- [ ] **Step 2: Run — expect FAIL go_home API or home people**

- [ ] **Step 3: Implement**

Add HomeLogic preload, signals, home fields.

`disconnect_room`: clear `home_people`, `home_board`, `last_emote`, `home_poses`. Keep friends as today.

`welcome`: also `_apply_home_bucket(msg.get("home", {}))` then `home_updated.emit()`.

`snapshot`:

```gdscript
		"snapshot":
			var snapshot: Dictionary = msg.get("snapshot", {})
			_you = msg.get("you", {}).duplicate(true)
			var snap_id := String(snapshot.get("placeId", ""))
			_apply_friends(snapshot)
			if snap_id.begins_with("home:"):
				_apply_home_bucket(snapshot)
				if pending_enter == snap_id:
					pending_enter = ""
				home_updated.emit()
			else:
				place_id = snap_id
				_people = _without_self(snapshot.get("people", []))
				_apply_board(snapshot)
				if pending_enter == place_id:
					pending_enter = ""
				snapshot_ready.emit(_you.duplicate(true), _people.duplicate(true), place_id)
```

`join`/`leave`: if `place_id` school match, existing people update; **also** if `msg.placeId == home_id()`, upsert/remove `home_people` and `home_updated.emit()`.

`chat`: if `line.placeId == home_id()` append `home_board` (cap 80) and `home_updated.emit()`; elif classroom, existing `_apply_chat`. Action lines (`line.action`) still go to home_board for the log.

`emote`: `last_emote = msg.emote`; `emote_received.emit`; `home_updated.emit()`. Do not change poses except via later `pose` messages / `pose_for_action` in UI.

`pose`: update `home_poses[clientId]` and matching `home_people` pose fields; `home_updated.emit()`. Ignore for school actors (school uses `poses` batches already).

```gdscript
func go_home(owner_id: String) -> void:
	if owner_id.is_empty():
		return
	enter_place(HomeLogic.home_place_id(owner_id))

func send_home_chat(text: String) -> void:
	var cleaned := SchoolSocial.sanitize_chat(text)
	if cleaned.is_empty() or not connected or home_id().is_empty():
		return
	_send({"type": "chat", "text": cleaned, "placeId": home_id()})

func send_emote(kind: String, target_id: String) -> void:
	if not connected or kind.is_empty() or target_id.is_empty() or home_id().is_empty():
		return
	_send({"type": "emote", "kind": kind, "targetId": target_id, "placeId": home_id()})

func you_dict() -> Dictionary:
	return _you.duplicate(true)

func home_id() -> String:
	return String(_you.get("homeId", ""))

func my_id() -> String:
	return String(_you.get("clientId", _app_state().state.clientId))
```

`_apply_home_bucket`: people without self → `home_people`; board → `home_board`.

- [ ] **Step 4: Run — expect PASS** (fix `send_home_chat` placeId: after home snapshot `home_id` is `home:x` even if last `go_home("y")` only set `last_enter_requested`)

- [ ] **Step 5: Commit**

```
git commit -m "Track home occupancy beside school without opening the world."
```

---

### Task 5: Hub 回家 and friends 进他家

**Files:**
- Modify: `godot/autoload/window_hub.gd`
- Modify: `godot/windows/panel_window.gd`
- Modify: `godot/tests/test_panel_window.gd`
- Modify: `godot/tests/test_window_hub.gd`

**Interfaces:**
- Consumes: `RoomClient.go_home`, `HomeLogic.is_friend_at_home`
- Produces: `WindowHub.go_home(owner_id: String = "")`; hub button 回家 between 去上学 and 好友; friend rows 进他家 / disabled 不在家

- [ ] **Step 1: Tests**

`test_panel_window.gd` hub section:

```gdscript
	failed += _check("hub home", panel.get_node("Margin/Content/Home").text == "回家")
	failed += _check(
		"hub button order",
		panel.get_node("Margin/Content/School").get_index()
		< panel.get_node("Margin/Content/Home").get_index()
		and panel.get_node("Margin/Content/Home").get_index()
		< panel.get_node("Margin/Content/Friends").get_index()
		and panel.get_node("Margin/Content/Friends").get_index()
		< panel.get_node("Margin/Content/Settings").get_index()
	)
```

Friends: `failed += _check("visit copy in source", FileAccess.get_file_as_string("res://windows/panel_window.gd").contains("进他家"))`

`test_window_hub.gd`: `failed += _check("go home API", source.contains("func go_home"))`

- [ ] **Step 2: Run — expect FAIL hub home**

- [ ] **Step 3: Implement**

`WindowHub.go_home(owner_id: String = "")`:

```gdscript
func go_home(owner_id: String = "") -> void:
	close_panel()
	_ensure_room_signals()
	var target := owner_id
	if target.is_empty():
		target = AppState.state.clientId
	if RoomClient.connected:
		RoomClient.go_home(target)
		return
	RoomClient.pending_enter = HomeLogic.home_place_id(target)
	RoomClient.connect_room(AppState.state.settings.roomUrl)
```

If `pending_enter` is currently only consumed as school campus via `begin_school_flow`, Task 4's open-socket path already `enter_place(pending_enter)` on hello — so `pending_enter = home:...` works. Do **not** call `begin_school_flow`.

Hub: insert Home button (`name=Home`, text `回家`) calling `_window_hub().go_home()`.

Friends rows: after status label, add Button `进他家` or disabled `不在家` from `HomeLogic.is_friend_at_home(card)`; pressed → `WindowHub.go_home(card.clientId)`.

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```
git commit -m "Add hub go-home and friend visit buttons."
```

---

### Task 6: School inspect 去他家

**Files:**
- Modify: `godot/windows/world_window.gd`
- Modify: `godot/tests/test_world_social.gd`

**Interfaces:**
- Consumes: `HomeLogic.is_friend_at_home`, `WindowHub.go_home`, `RoomClient.friends`
- Produces: already-friend menu is 去他家 or disabled 不在家 + 取消 (no 已是好友, no 五子棋)

- [ ] **Step 1: Change tests**

In `test_world_social.gd`:

- Remove or invert `already friend copy` for `"已是好友"` — **must not** contain `"已是好友"` as a button string.
- Add `failed += _check("visit copy", source.contains('"去他家"'))`
- Add `failed += _check("away copy", source.contains('"不在家"'))`
- Keep `no gomoku`.

- [ ] **Step 2: Run — expect FAIL visit copy**

- [ ] **Step 3: Replace already-friend branch in `_open_inspect`**

```gdscript
	if kind == "already":
		var card: Dictionary = {}
		for item in RoomClient.friends:
			if String(item.get("clientId", "")) == client_id:
				card = item
				break
		var visit := Button.new()
		if HomeLogic.is_friend_at_home(card):
			visit.text = "去他家"
			visit.pressed.connect(func():
				WindowHub.go_home(client_id)
				_close_inspect()
			)
		else:
			visit.text = "不在家"
			visit.disabled = true
		box.add_child(visit)
	else:
		# existing 加好友
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```
git commit -m "Let classmates be visited from the school inspect menu."
```

---

### Task 7: Pet window gathering

**Files:**
- Modify: `godot/windows/pet_root.gd`
- Create: `godot/tests/test_pet_gathering.gd`

**Interfaces:**
- Consumes: `HomeLogic.*`, `RoomClient.home_people/home_board/last_emote/home_poses/home_updated/emote_received/disconnected`, `PetTemplates`, PixelPet
- Produces: solo 64×86; gathering resizes to `yard_metrics`; slots; 聊/收; right-click emotes; passthrough; blink paused while gathering

- [ ] **Step 1: Write `godot/tests/test_pet_gathering.gd`**

Source checks on `pet_root.gd`:

```gdscript
extends RefCounted

func run() -> int:
	var failed := 0
	var source := FileAccess.get_file_as_string("res://windows/pet_root.gd")
	failed += _check("gathering layout", source.contains("func _refresh_gathering"))
	failed += _check("chat copy", source.contains('"聊"') and source.contains('"收"') and source.contains("回车发送"))
	failed += _check("title home", source.contains("自家"))
	failed += _check("emote hugs", source.contains("抱抱"))
	failed += _check("no flyer", not source.contains("FLYER") and not source.contains("playFlyer"))
	failed += _check("home chat", source.contains("send_home_chat"))
	failed += _check("send emote", source.contains("send_emote"))
	return failed

func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("pet_gathering: %s" % label)
	return 1
```

- [ ] **Step 2: Run — expect FAIL gathering layout**

- [ ] **Step 3: Implement gathering on `PetRoot`**

Keep `$PixelPet` for solo. Add `$Gathering` `Control` (create in `_ready` if missing) covering the window, hidden when not gathering.

Connect `RoomClient.home_updated`, `emote_received`, `disconnected`, `connect_failed`.

```gdscript
var _gathering := false
var _chatting := false
var _menu_for := ""
var _cool_until_ms := 0
var _bubbles: Dictionary = {} # id -> {text, until}

func _refresh_gathering() -> void:
	var you := RoomClient.you_dict()
	var my_id := RoomClient.my_id()
	var guests: Array = []
	if not you.is_empty():
		guests.append(you)
	for person in RoomClient.home_people:
		guests.append(person)
	var gather := HomeLogic.is_home_gathering(you, RoomClient.home_people, my_id)
	_gathering = gather
	pixel_pet.visible = not gather
	_gathering_root.visible = gather
	if not gather:
		get_window().size = PET_SIZE
		pixel_pet.position = PET_OFFSET
		update_passthrough()
		return
	var log_n := 0
	if _chatting:
		log_n = mini(RoomClient.home_board.size(), 24)
	var yard: Dictionary = HomeLogic.yard_metrics(guests.size(), _chatting, log_n)
	get_window().size = Vector2i(int(yard.width), int(yard.height))
	_rebuild_slots(guests, yard)
	update_passthrough()
```

Slots: for each guest, PixelPet `pixel_size=4`, pose = `HomeLogic.pose_for_action(RoomClient.last_emote if not expired else {}, id, home_poses.get(id, "idle"))`. Expire `last_emote` when `Time.get_ticks_msec() - ts > HOME_ACTIONS[kind].duration`. Kick: do **not** hide the slot.

Right-click guest → menu buttons 抱抱/倒水/拍醒/飞踢 calling `RoomClient.send_emote`. Disable if `Time.get_ticks_msec() < _cool_until_ms`; on press set cooldown 5000. Left-click self → `WindowHub.toggle_panel`. Left-click guest → ignore (don't toggle hub).

Bar: title `HomeLogic.gathering_title`, `{n}人`, 聊 / 收, LineEdit placeholder `回车发送`, `text_submitted` → `RoomClient.send_home_chat`.

Bubbles: on home chat line with not `action`, store 5s caption.

Passthrough: when gathering, union opaque pixels of each slot pet (offset by slot position) **plus** rectangles for the bar (and log if chatting). Reuse convex hull. When solo, existing pet hull.

Blink loop: skip `_set_pose` while `_gathering`.

On disconnect: `_gathering=false`, resize PET_SIZE.

Tray: unchanged (WindowHub uses idle frame).

Drag: gathering root `gui_input` same as pet drag.

- [ ] **Step 4: Run full suite — expect PASS**

- [ ] **Step 5: Commit**

```
git commit -m "Grow the desk pet into a living-room gathering."
```

---

### Task 8: README

**Files:**
- Modify: `README.md`

- [ ] **Step 1:** In the Godot experimental paragraph, add that 枢纽「回家」/好友「进他家」会展开桌宠客厅，可说话和右键动作；上学时家里来客桌宠也会变大。Do not claim 五子棋 or 进他家 from a fourth window.

- [ ] **Step 2:** Run Godot tests — expect PASS.

- [ ] **Step 3:** Manual checklist (record skipped if no live principal). Especially: visit while host is at school; gathering shrinks when guests leave.

- [ ] **Step 4: Commit**

```
git commit -m "Document Godot home visiting and living-room actions."
```

---

## Self-review

**Spec coverage**

| Spec item | Task |
| --- | --- |
| Pose table from templates.ts | 2 |
| yard/gathering/at-home predicates | 1 |
| Dual occupancy, home snap ≠ school place | 4 |
| go_home enterPlace home:id | 4, 5 |
| Hub 回家, friends 进他家 | 5 |
| School 去他家 | 6 |
| Resize pet window gathering, passthrough | 7 |
| Chat 聊/收, emotes, in-slot kick | 7 |
| Errors / no optimistic emote | 4, 7 |
| README | 8 |
| No flyer, gomoku, LLM, weather | all |

**Placeholder scan:** templates copy is from a named source file, not TBD.

**Type consistency:** `go_home(owner_id)`, `send_emote(kind, target_id)`, `send_home_chat`, `home_updated`, `HomeLogic.yard_metrics` / `is_home_gathering` / `is_friend_at_home` used the same way in Tasks 4–7.
