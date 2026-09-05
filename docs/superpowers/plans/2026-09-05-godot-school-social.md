# Godot School Social Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add classmate friend requests, a hub friends list, and classroom blackboard chat to the existing Godot client, while keeping the WebSocket connected after the school window closes.

**Architecture:** Keep the three windows. Pure helpers live in `school_social.gd`. `RoomClient` becomes a process-lifetime connection: it now sends `chat` / `friendRequest` and caches `friends` / `board`. `WindowHub` only opens the school window for `school:` snapshots. Hub gains a `friends` panel kind.

**Post-review correction:** Do not send `enterPlace("away")` when closing the school window. The principal treats `away` as "go to my home" and no-ops if `homeId` is already own home, which leaves the pet at school and makes "去上学" unable to get a new snapshot. Close = hide the window (Electron parity); quit/settings = `discard_world()` then `disconnect_room()`. Spec: `docs/superpowers/specs/2026-09-05-godot-school-social-design.md`.

**Tech Stack:** Godot 4.4+ GDScript, existing Node principal (`npm run room`, `ws://127.0.0.1:18765`). Headless tests via `res://tests/run_tests.gd`. No `server/` or protocol shape changes.

**Spec:** `docs/superpowers/specs/2026-09-05-godot-school-social-design.md`

## Global Constraints

- Godot 4.4+ / GDScript only; all client work is under `godot/`. Do not modify `server/`, `shared/`, or Electron except one README sentence.
- Send `hello` / `enterPlace` / `move` / `chat` / `friendRequest`. Handle `welcome` / `snapshot` / `join` / `leave` / `move` / `poses` / `chat` / `friends` / `error` / `notice`. Still drop `pose` / `dress` / `emote` / `gameState`.
- Close school window = hide the world window, keep `connected == true`, stay on the current school map. Disconnect only on quit, settings save that changes pet/url, or explicit `disconnect_room()`.
- Only `placeId` starting with `school:` may open `WorldWindow`. Home/`away` snapshots must not.
- Chat: sanitize like `shared/world.ts` (`\s+` → space, trim, max 80). Send `{type:chat,text,placeId}` only in a classroom, with current classroom id. Do not optimistic-insert on send.
- Board cache max 80; on-screen last 7. Campus has no input and no bubbles.
- Friend menu: 加好友 / 已是好友 / 取消. No 去他家, 五子棋, or incoming-request UI.
- User-visible strings are the exact Chinese in each task. Git commits stay English.
- Tests: `godot --headless --path godot --script res://tests/run_tests.gd`. If `godot` is not on PATH, use `c:\Users\huangyazhe\Projects\bbpet\.tools\godot\Godot_v4.4.1-stable_win64.exe --headless --path godot --script res://tests/run_tests.gd`. Exit 0 pass, 1 fail.
- Do not add home maps, visiting, emotes, gomoku, LLM, weather, or Godot-as-principal.

## File Structure

- Create: `godot/school/school_social.gd` — sanitize, board slice, friend menu/status, should-open-world.
- Create: `godot/tests/test_school_social.gd`
- Modify: `godot/net/room_messages.gd` — HANDLED includes `chat`, `friends`.
- Modify: `godot/tests/test_room_messages.gd`
- Modify: `godot/autoload/room_client.gd` — long-lived connection APIs and caches.
- Modify: `godot/tests/test_room_client_flow.gd`
- Modify: `godot/autoload/window_hub.gd` — friends entry, snapshot gate, close = leave school.
- Modify: `godot/tests/test_window_hub.gd`
- Modify: `godot/windows/panel_window.gd` — hub 好友 button, friends panel.
- Modify: `godot/tests/test_panel_window.gd`
- Modify: `godot/windows/world_window.gd` — inspect menu, blackboard, chat bar, WASD guard.
- Modify: `godot/windows/world_window.tscn` — chat bar nodes.
- Create: `godot/tests/test_world_social.gd`
- Modify: `README.md` — one Godot friends/blackboard sentence.

---

### Task 1: School social pure helpers

**Files:**
- Create: `godot/school/school_social.gd`
- Create: `godot/tests/test_school_social.gd`

**Interfaces:**
- Consumes: nothing
- Produces: `class_name SchoolSocial` with `BOARD_LIMIT=80`, `BOARD_VISIBLE=7`, `sanitize_chat(text: String) -> String`, `append_board(board: Array, line: Dictionary) -> Array`, `visible_board(board: Array) -> Array`, `friend_menu_kind(client_id: String, friend_ids: Array) -> String` (`"add"` or `"already"`), `friend_status_text(card: Dictionary) -> String`, `should_open_world(place_id: String) -> bool`, `is_classroom_place(place: Dictionary) -> bool`

- [ ] **Step 1: Write the failing test**

Create `godot/tests/test_school_social.gd`:

```gdscript
extends RefCounted

const SchoolSocial = preload("res://school/school_social.gd")


func run() -> int:
	var failed := 0
	failed += _check("collapse spaces", SchoolSocial.sanitize_chat("  a   b  ") == "a b")
	failed += _check("empty whitespace", SchoolSocial.sanitize_chat(" \n\t ") == "")
	var long := ""
	for _i in 90:
		long += "字"
	failed += _check("max 80", SchoolSocial.sanitize_chat(long).length() == 80)
	var board: Array = []
	for i in 81:
		board = SchoolSocial.append_board(board, {"id": str(i), "text": str(i)})
	failed += _check("board cap 80", board.size() == 80)
	failed += _check("board dropped oldest", str(board[0].id) == "1")
	var visible: Array = SchoolSocial.visible_board(board)
	failed += _check("visible 7", visible.size() == 7)
	failed += _check("visible last", str(visible[6].id) == "80")
	failed += _check("menu add", SchoolSocial.friend_menu_kind("b", ["a"]) == "add")
	failed += _check("menu already", SchoolSocial.friend_menu_kind("a", ["a"]) == "already")
	failed += _check("offline", SchoolSocial.friend_status_text({"online": false}) == "离线")
	failed += _check(
		"at school",
		SchoolSocial.friend_status_text({"online": true, "schoolPlaceId": "school:campus"}) == "在学校"
	)
	failed += _check("online", SchoolSocial.friend_status_text({"online": true}) == "在线")
	failed += _check("null school id", SchoolSocial.friend_status_text({"online": true, "schoolPlaceId": null}) == "在线")
	failed += _check("open campus", SchoolSocial.should_open_world("school:campus") == true)
	failed += _check("skip home", SchoolSocial.should_open_world("home:abc") == false)
	failed += _check("skip away", SchoolSocial.should_open_world("away") == false)
	failed += _check("classroom", SchoolSocial.is_classroom_place({"kind": "classroom"}) == true)
	failed += _check("campus not classroom", SchoolSocial.is_classroom_place({"kind": "campus"}) == false)
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("school_social: %s" % label)
	return 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL, unable to load `res://school/school_social.gd` or `class_name SchoolSocial` missing.

- [ ] **Step 3: Write minimal implementation**

Create `godot/school/school_social.gd`:

```gdscript
class_name SchoolSocial
extends RefCounted

const BOARD_LIMIT := 80
const BOARD_VISIBLE := 7
const BOARD_LEFT := 32.0
const BOARD_TOP := 6.0
const BOARD_HEIGHT := 78.0
const BOARD_SIDE_PAD := 32.0


static func sanitize_chat(text: String) -> String:
	var collapsed := ""
	var in_space := false
	for i in text.length():
		var ch := text.substr(i, 1)
		if ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
			if not in_space:
				collapsed += " "
				in_space = true
		else:
			collapsed += ch
			in_space = false
	return collapsed.strip_edges().substr(0, 80)


static func append_board(board: Array, line: Dictionary) -> Array:
	var next: Array = board.duplicate()
	next.append(line.duplicate(true))
	if next.size() > BOARD_LIMIT:
		next = next.slice(next.size() - BOARD_LIMIT)
	return next


static func visible_board(board: Array) -> Array:
	if board.size() <= BOARD_VISIBLE:
		return board.duplicate()
	return board.slice(board.size() - BOARD_VISIBLE)


static func friend_menu_kind(client_id: String, friend_ids: Array) -> String:
	return "already" if friend_ids.has(client_id) else "add"


static func _as_text(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	return value


static func friend_status_text(card: Dictionary) -> String:
	if not card.get("online", false):
		return "离线"
	if not _as_text(card.get("schoolPlaceId")).is_empty():
		return "在学校"
	return "在线"


static func should_open_world(place_id: String) -> bool:
	return place_id.begins_with("school:")


static func is_classroom_place(place: Dictionary) -> bool:
	return String(place.get("kind", "")) == "classroom"


static func friend_ids(friends: Array) -> Array:
	var ids: Array = []
	for card in friends:
		if card is Dictionary:
			var id := String(card.get("clientId", ""))
			if not id.is_empty():
				ids.append(id)
	return ids
```

- [ ] **Step 4: Run tests and make sure they pass**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: PASS (exit 0).

- [ ] **Step 5: Commit**

```bash
git add godot/school/school_social.gd godot/tests/test_school_social.gd
git commit -m "Add school social helpers for chat, board, and friends."
```

---

### Task 2: Parse `chat` and `friends`

**Files:**
- Modify: `godot/net/room_messages.gd`
- Modify: `godot/tests/test_room_messages.gd`

**Interfaces:**
- Consumes: `RoomMessages.parse_server`
- Produces: `HANDLED` includes `chat` and `friends`; `gameState` still ignored

- [ ] **Step 1: Change the test so `chat` / `friends` must parse**

In `godot/tests/test_room_messages.gd`, replace the `drop chat` assertion with parse-success checks. Keep `gameState` ignored:

```gdscript
	var chat: Dictionary = RoomMessages.parse_server(
		'{"type":"chat","line":{"id":"1","name":"豆豆","text":"hi","placeId":"school:class-1"}}'
	)
	failed += _check("parse chat", chat.ignored == false and chat.type == "chat")
	var friends: Dictionary = RoomMessages.parse_server('{"type":"friends","friends":[],"incoming":[]}')
	failed += _check("parse friends", friends.ignored == false and friends.type == "friends")
	var drop2: Dictionary = RoomMessages.parse_server('{"type":"gameState"}')
	failed += _check("drop game", drop2.ignored == true)
```

Delete the old `drop chat` lines.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL `room_messages: parse chat` (chat still ignored).

- [ ] **Step 3: Update HANDLED**

In `godot/net/room_messages.gd`:

```gdscript
const HANDLED := [
	"welcome", "snapshot", "join", "leave", "move", "poses",
	"chat", "friends", "error", "notice",
]
```

- [ ] **Step 4: Run tests and make sure they pass**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/net/room_messages.gd godot/tests/test_room_messages.gd
git commit -m "Accept principal chat and friends messages in Godot."
```

---

### Task 3: RoomClient long-lived school connection

**Files:**
- Modify: `godot/autoload/room_client.gd`
- Modify: `godot/tests/test_room_client_flow.gd`

**Interfaces:**
- Consumes: `RoomMessages.parse_server`, `SchoolSocial.*`, `SchoolLogic.PLACES`
- Produces:
  - signals `chat_received(line: Dictionary)`, `friends_changed(friends: Array)` (keep existing signals)
  - `var friends: Array`, `var incoming: Array`, `var board: Array`, `var last_notice: String`, `var place_id: String` (rename `_place_id` → `place_id`), `var connecting: bool` (replace `_connecting`)
  - `send_chat(text: String) -> void`
  - `request_friend(target_id: String) -> void`
  - `leave_school() -> void`
  - `is_friend(client_id: String) -> bool`
  - `connect_room(url)` no-ops when already `connected` to the same URL
  - welcome copies `home.friends`; snapshot copies `friends`/`board`; `{type:friends}` updates list; chat appends only when `line.placeId == place_id` and current place is classroom
  - `leave_school()` sends `enterPlace("away")` and leaves `connected` true
  - error/notice still go to `status_text` and also `last_notice` (80 chars)

- [ ] **Step 1: Rewrite `test_room_client_flow.gd` for the new contract**

Replace `godot/tests/test_room_client_flow.gd` with:

```gdscript
extends RefCounted

const ROOM_CLIENT_SCRIPT = preload("res://autoload/room_client.gd")
const SchoolSocial = preload("res://school/school_social.gd")


func run() -> int:
	var failed := 0
	var rc: Node = ROOM_CLIENT_SCRIPT.new()
	if not rc.has_method("leave_school") or not rc.has_method("send_chat") or not rc.has_method("request_friend"):
		rc.free()
		return _check("social API", false)
	rc.disconnect_room()
	var saw := {"campus": false, "home": false, "friends": 0, "chats": 0}
	rc.snapshot_ready.connect(func(_you, _people, place_id):
		if place_id == "school:campus":
			saw.campus = true
		if str(place_id).begins_with("home:"):
			saw.home = true
	)
	rc.friends_changed.connect(func(friends):
		saw.friends = friends.size()
	)
	rc.chat_received.connect(func(_line):
		saw.chats += 1
	)
	rc.begin_school_flow()
	rc._handle_server_text(
		'{"type":"welcome","you":{"clientId":"x","placeId":"home:x","x":0,"y":0},'
		+ '"home":{"placeId":"home:x","friends":[{"clientId":"y","name":"乙","online":true}],"incoming":[]}}'
	)
	failed += _check("queued enter", rc.last_enter_requested == "school:campus")
	failed += _check("welcome friends", saw.friends == 1 and rc.is_friend("y"))
	rc.connected = true
	rc._handle_server_text(
		'{"type":"snapshot","you":{"clientId":"x","x":384,"y":348,"facing":"r",'
		+ '"species":"blob","name":"豆豆","colors":{}},'
		+ '"snapshot":{"placeId":"school:campus","people":[],"board":[],"friends":[{"clientId":"y","name":"乙","online":true}]}}'
	)
	failed += _check("campus snapshot", saw.campus)
	rc.leave_school()
	failed += _check("leave away", rc.last_enter_requested == "away")
	failed += _check("still connected", rc.connected == true)
	failed += _check("friends kept", rc.is_friend("y"))
	rc._handle_server_text(
		'{"type":"snapshot","you":{"clientId":"x","placeId":"home:x"},'
		+ '"snapshot":{"placeId":"home:x","people":[],"board":[],"friends":[{"clientId":"y","name":"乙","online":true}]}}'
	)
	failed += _check("home snapshot emitted", saw.home)
	failed += _check("home must not open world", SchoolSocial.should_open_world("home:x") == false)
	rc._handle_server_text(
		'{"type":"snapshot","you":{"clientId":"x","x":40,"y":40,"name":"豆豆"},'
		+ '"snapshot":{"placeId":"school:class-1","people":[],"board":['
		+ '{"id":"old","clientId":"z","name":"丙","text":"先写的","placeId":"school:class-1"}]}}'
	)
	failed += _check("snapshot board", rc.board.size() == 1)
	rc._handle_server_text(
		'{"type":"chat","line":{"id":"n1","clientId":"y","name":"乙","text":"你好","kind":"board","placeId":"school:class-1"}}'
	)
	failed += _check("same-class chat", saw.chats == 1 and rc.board.size() == 2)
	rc._handle_server_text(
		'{"type":"chat","line":{"id":"n2","clientId":"z","name":"丁","text":"隔壁","kind":"board","placeId":"school:class-2"}}'
	)
	failed += _check("other-class dropped", saw.chats == 1 and rc.board.size() == 2)
	rc.send_chat("  黑板字  ")
	failed += _check("send chat payload", rc.last_sent.type == "chat" and rc.last_sent.text == "黑板字" and rc.last_sent.placeId == "school:class-1")
	failed += _check("no optimistic board", rc.board.size() == 2)
	rc.request_friend("y")
	failed += _check("friend request", rc.last_sent.type == "friendRequest" and rc.last_sent.targetId == "y")
	rc._handle_server_text('{"type":"friends","friends":[{"clientId":"y","name":"乙","online":true}],"incoming":[{"clientId":"z"}]}')
	failed += _check("incoming stored unused", rc.incoming.size() == 1)
	rc._handle_server_text('{"type":"notice","text":"已添加 乙"}')
	failed += _check("last notice", rc.last_notice.contains("已添加"))
	rc._handle_server_text('{"type":"error","message":"学校人满了"}')
	failed += _check("error text", rc.status_text.contains("学校人满了"))
	rc.free()
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("room_client: %s" % label)
	return 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL `room_client: social API` or missing signals/`last_sent`.

- [ ] **Step 3: Implement RoomClient social methods**

In `godot/autoload/room_client.gd`:

1. Preload helpers:

```gdscript
const SchoolSocial = preload("res://school/school_social.gd")
const SchoolLogic = preload("res://school/school_logic.gd")
```

2. Add signals after the existing ones:

```gdscript
signal chat_received(line: Dictionary)
signal friends_changed(friends: Array)
```

3. Add public fields (and rename `_place_id` to `place_id` everywhere in this file):

```gdscript
var friends: Array = []
var incoming: Array = []
var board: Array = []
var last_notice := ""
var last_sent: Dictionary = {}
var place_id := ""
var connecting := false
var _url := ""
```

Remove `var _place_id := ""` and `var _connecting := false`. Use `connecting` everywhere `_connecting` was used.

4. Replace `connect_room` so the same URL stays up:

```gdscript
func connect_room(url: String) -> void:
	if connected and _url == url:
		return
	disconnect_room()
	if url.is_empty():
		status_text = "连不上学校"
		connect_failed.emit(status_text)
		return
	_peer = WebSocketPeer.new()
	_intentional_disconnect = false
	connecting = true
	_url = url
	var result := _peer.connect_to_url(url)
	if result != OK:
		_peer = null
		connecting = false
		_url = ""
		status_text = "连不上学校"
		connect_failed.emit(status_text)
```

5. In `disconnect_room`, keep `friends` / `incoming` (last list). Still clear `pending_enter`, `place_id`, `_people`, `board`, `_url`, `connected`. Do not clear `last_notice`.

6. Add:

```gdscript
func send_chat(text: String) -> void:
	var cleaned := SchoolSocial.sanitize_chat(text)
	if cleaned.is_empty() or not connected:
		return
	if not SchoolSocial.is_classroom_place(SchoolLogic.PLACES.get(place_id, {})):
		return
	_send({"type": "chat", "text": cleaned, "placeId": place_id})


func request_friend(target_id: String) -> void:
	if not connected or target_id.is_empty():
		return
	_send({"type": "friendRequest", "targetId": target_id})


func leave_school() -> void:
	if not connected:
		return
	enter_place("away")


func is_friend(client_id: String) -> bool:
	return SchoolSocial.friend_ids(friends).has(client_id)
```

7. Change `_send` to also store `last_sent = message.duplicate(true)` before sending (tests inspect this; sending still no-ops when the socket is closed).

8. In `_handle_server_text`:

- `welcome`: keep `_you` assignment and `pending_enter` enter. Also `_apply_friends(msg.get("home", {}))`.
- `snapshot`: set `place_id`, people, you as today. Then `_apply_friends(snapshot)` and `_apply_board(snapshot)`.
- `friends`: `_apply_friends(msg)`.
- `chat`: `_apply_chat(msg.get("line", {}))`.
- `error`/`notice`: set both `status_text` and `last_notice` with the existing 80-char sanitize.

```gdscript
func _apply_friends(source: Dictionary) -> void:
	var next: Array = source.get("friends", [])
	friends = []
	for card in next:
		if card is Dictionary:
			friends.append(card.duplicate(true))
	incoming = []
	var raw_in: Array = source.get("incoming", [])
	for card in raw_in:
		if card is Dictionary:
			incoming.append(card.duplicate(true))
	friends_changed.emit(friends.duplicate(true))


func _apply_board(snapshot: Dictionary) -> void:
	board = []
	if not SchoolSocial.is_classroom_place(SchoolLogic.PLACES.get(place_id, {})):
		return
	var raw: Array = snapshot.get("board", [])
	for line in raw:
		if line is Dictionary:
			board = SchoolSocial.append_board(board, line)


func _apply_chat(line: Dictionary) -> void:
	if line.is_empty():
		return
	if String(line.get("placeId", "")) != place_id:
		return
	if not SchoolSocial.is_classroom_place(SchoolLogic.PLACES.get(place_id, {})):
		return
	board = SchoolSocial.append_board(board, line)
	chat_received.emit(line.duplicate(true))
```

Keep `join` / `leave` / `move` / `poses` behavior, but they must compare against `place_id` (the renamed field).

- [ ] **Step 4: Run tests and make sure they pass**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: PASS. If `SchoolLogic.PLACES.get` typing fails, use `SchoolLogic.PLACES[place_id]` only when `SchoolLogic.PLACES.has(place_id)` else `{}`.

- [ ] **Step 5: Commit**

```bash
git add godot/autoload/room_client.gd godot/tests/test_room_client_flow.gd
git commit -m "Keep the Godot room socket after leaving school."
```

---

### Task 4: WindowHub friends entry and close-without-disconnect

**Files:**
- Modify: `godot/autoload/window_hub.gd`
- Modify: `godot/tests/test_window_hub.gd`

**Interfaces:**
- Consumes: `RoomClient.connect_room` / `begin_school_flow` / `leave_school` / `enter_place` / `place_id` / `connected`; `SchoolSocial.should_open_world`
- Produces: `open_panel("friends")` allowed; `open_friends()`; `go_to_school()` reuses an existing connection; `close_world()` calls `leave_school()` and does **not** call `disconnect_room()`; `_on_room_snapshot` opens world only when `should_open_world(place_id)`; `quit_app()` still disconnects

- [ ] **Step 1: Extend window hub source tests**

Append to `godot/tests/test_window_hub.gd` after the existing quit check:

```gdscript
	failed += _check("close world leaves school", source.contains("RoomClient.leave_school()"))
	failed += _check(
		"close world does not disconnect",
		_close_world_does_not_disconnect(source)
	)
	failed += _check("friends panel kind", source.contains('"friends"'))
	failed += _check("open friends API", source.contains("func open_friends"))
	failed += _check("school snapshot gate", source.contains("SchoolSocial.should_open_world"))
```

Add helper in the same file:

```gdscript
func _close_world_does_not_disconnect(source: String) -> bool:
	var start := source.find("func close_world")
	if start < 0:
		return false
	var nxt := source.find("\nfunc ", start + 1)
	var body := source.substr(start, nxt - start if nxt > start else source.length() - start)
	return body.contains("leave_school") and not body.contains("disconnect_room")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL `window_hub: close world leaves school`.

- [ ] **Step 3: Update WindowHub**

At top of `godot/autoload/window_hub.gd` add:

```gdscript
const SchoolSocial = preload("res://school/school_social.gd")
```

Change `open_panel` allowed kinds to `["wizard", "hub", "settings", "friends"]`.

Replace `go_to_school`:

```gdscript
func go_to_school() -> void:
	_ensure_room_signals()
	if is_instance_valid(_world) and RoomClient.connected and SchoolSocial.should_open_world(RoomClient.place_id):
		_world.show()
		_world.grab_focus()
		return
	_show_room_status("")
	if RoomClient.connected:
		RoomClient.begin_school_flow()
		RoomClient.enter_place(RoomClient.SCHOOL_CAMPUS)
		return
	RoomClient.connect_room(AppState.state.settings.roomUrl)
	RoomClient.begin_school_flow()
```

Add:

```gdscript
func open_friends() -> void:
	_ensure_room_signals()
	open_panel("friends")
	if RoomClient.connected:
		return
	_show_room_status("")
	RoomClient.pending_enter = ""
	RoomClient.connect_room(AppState.state.settings.roomUrl)
```

Replace `_on_room_snapshot`:

```gdscript
func _on_room_snapshot(you: Dictionary, people: Array, place_id: String) -> void:
	if not SchoolSocial.should_open_world(place_id):
		return
	close_panel()
	show_world(you, people, place_id)
```

Replace `close_world`:

```gdscript
func close_world() -> void:
	if is_instance_valid(_world):
		AppState.save_world_size(_world.size.x, _world.size.y)
		_world.hide()
		_world.queue_free()
		_world = null
	RoomClient.leave_school()
```

Leave `quit_app()` calling `RoomClient.disconnect_room()`.

In `_show_room_status`, if the open panel is friends, still set/create `RoomStatus` as today (friends panel will also read `last_notice` in Task 5).

- [ ] **Step 4: Run tests and make sure they pass**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/autoload/window_hub.gd godot/tests/test_window_hub.gd
git commit -m "Open friends without a school window and leave without disconnecting."
```

---

### Task 5: Hub friends button and friends panel

**Files:**
- Modify: `godot/windows/panel_window.gd`
- Modify: `godot/tests/test_panel_window.gd`

**Interfaces:**
- Consumes: `WindowHub.open_friends` / `open_panel`; `RoomClient.friends`, `connected`, `status_text`, `last_notice`, `friends_changed`, `connect_failed`, `disconnected`, `status`
- Produces: hub buttons in order 去上学, 好友, 设置; panel kind `friends` size `300×480`; each row 16×16 preview `pixel_size=2`, name, status via `SchoolSocial.friend_status_text`; empty hint `去学校点别的同学，点「加好友」就会出现在这里。`; connecting `正在连学校...`; failure uses RoomClient `连不上学校` / `已断开`; notice label from `last_notice`; no 进他家 / 五子棋
- Settings save: if connected, `close_world()` then `disconnect_room()` (must disconnect, because `close_world` no longer does)

- [ ] **Step 1: Extend panel tests**

In `godot/tests/test_panel_window.gd` hub section, after the school button check, add:

```gdscript
	failed += _check("hub friends", panel.get_node("Margin/Content/Friends").text == "好友")
	failed += _check(
		"hub button order",
		panel.get_node("Margin/Content/School").get_index()
		< panel.get_node("Margin/Content/Friends").get_index()
		and panel.get_node("Margin/Content/Friends").get_index()
		< panel.get_node("Margin/Content/Settings").get_index()
	)
```

After settings checks, add:

```gdscript
	panel.call("show_kind", "friends")
	failed += _check("friends size", panel.size == Vector2i(300, 480))
	failed += _check("friends title", panel.title == "好友")
	failed += _check("friends empty hint", panel.get_node("Margin/Content/Empty").text == "去学校点别的同学，点「加好友」就会出现在这里。")
	failed += _check("no visit button", panel.get_node_or_null("Margin/Content/Visit") == null)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL `panel_window: hub friends`.

- [ ] **Step 3: Implement panel UI**

In `godot/windows/panel_window.gd`:

Add to `PANEL_SIZES`:

```gdscript
	"friends": Vector2i(300, 480),
```

Preload:

```gdscript
const SchoolSocial = preload("res://school/school_social.gd")
```

In `show_kind` match, add `"friends": _build_friends()`.

In `_build_hub`, insert the friends button between school and settings:

```gdscript
	var friends := Button.new()
	friends.name = "Friends"
	friends.text = "好友"
	friends.pressed.connect(_open_friends)
	content.add_child(friends)
```

Add:

```gdscript
func _open_friends() -> void:
	_window_hub().open_friends()


func _build_friends() -> void:
	title = "好友"
	var status := Label.new()
	status.name = "RoomStatus"
	status.modulate = Color("#b3261e")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status)
	var notice := Label.new()
	notice.name = "Notice"
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(notice)
	var empty := Label.new()
	empty.name = "Empty"
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.text = "去学校点别的同学，点「加好友」就会出现在这里。"
	content.add_child(empty)
	var list := VBoxContainer.new()
	list.name = "List"
	content.add_child(list)
	_refresh_friends()
	var room := _room_client_or_null()
	if room:
		if not room.friends_changed.is_connected(_on_friends_changed):
			room.friends_changed.connect(_on_friends_changed)
		if not room.status.is_connected(_on_friends_status):
			room.status.connect(_on_friends_status)
		if not room.connect_failed.is_connected(_on_friends_status):
			room.connect_failed.connect(_on_friends_status)
		if not room.disconnected.is_connected(_on_friends_disconnected):
			room.disconnected.connect(_on_friends_disconnected)


func _on_friends_changed(_friends: Array) -> void:
	_refresh_friends()


func _on_friends_status(_text: String) -> void:
	_refresh_friends()


func _on_friends_disconnected() -> void:
	_refresh_friends()


func _refresh_friends() -> void:
	var status: Label = content.get_node_or_null("RoomStatus")
	var notice: Label = content.get_node_or_null("Notice")
	var empty: Label = content.get_node_or_null("Empty")
	var list: VBoxContainer = content.get_node_or_null("List")
	if status == null or empty == null or list == null or notice == null:
		return
	for child in list.get_children():
		child.free()
	var room := _room_client_or_null()
	var cards: Array = room.friends if room else []
	var connected := room.connected if room else false
	var connecting := room.connecting if room else false
	status.text = ""
	if room:
		if not connected and connecting:
			status.text = "正在连学校..."
		elif not connected and not room.status_text.is_empty():
			status.text = room.status_text
		elif not connected:
			status.text = "连不上学校"
	notice.text = room.last_notice if room else ""
	empty.visible = cards.is_empty()
	if cards.is_empty():
		empty.text = "去学校点别的同学，点「加好友」就会出现在这里。"
		return
	for card in cards:
		if not card is Dictionary:
			continue
		var row := HBoxContainer.new()
		var preview: TextureRect = PixelPetScene.instantiate()
		preview.species = String(card.get("species", "blob"))
		preview.colors = PET_TEMPLATES.colors_for(preview.species, card.get("colors", {}))
		preview.pixel_size = 2
		preview.pose = "idle"
		row.add_child(preview)
		preview.redraw()
		var meta := VBoxContainer.new()
		var name_label := Label.new()
		name_label.text = String(card.get("name", ""))
		meta.add_child(name_label)
		var state_label := Label.new()
		state_label.text = SchoolSocial.friend_status_text(card)
		meta.add_child(state_label)
		row.add_child(meta)
		list.add_child(row)
```

Use RoomClient's public `connecting` from Task 3 (do not read `_connecting`).

Add:

```gdscript
func _room_client_or_null() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/RoomClient")
```

Keep `_room_client()` for settings.

In `_save_settings`, replace the disconnect block with:

```gdscript
	var room_client := _room_client()
	if room_client.connected:
		_window_hub().close_world()
		room_client.disconnect_room()
```

- [ ] **Step 4: Run tests and make sure they pass**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/windows/panel_window.gd godot/tests/test_panel_window.gd godot/autoload/room_client.gd
git commit -m "Add a Godot hub friends list that can connect without opening school."
```

---

### Task 6: Click-classmate friend menu

**Files:**
- Modify: `godot/windows/world_window.gd`
- Create: `godot/tests/test_world_social.gd`

**Interfaces:**
- Consumes: `RoomClient.request_friend`, `RoomClient.is_friend` / `friends`, `SchoolSocial.friend_menu_kind`
- Produces: left-click a non-self classmate opens a small menu near them with name + `加好友` or disabled `已是好友` + `取消`; click blank map or 取消 closes it; no 五子棋 / 去他家

- [ ] **Step 1: Write world social tests (menu copy + inspect wiring)**

Create `godot/tests/test_world_social.gd`:

```gdscript
extends RefCounted


func run() -> int:
	var failed := 0
	var source := FileAccess.get_file_as_string("res://windows/world_window.gd")
	failed += _check("inspect menu helper", source.contains("func _open_inspect"))
	failed += _check("add friend copy", source.contains('"加好友"'))
	failed += _check("already friend copy", source.contains('"已是好友"'))
	failed += _check("cancel copy", source.contains('"取消"'))
	failed += _check("no visit", not source.contains("去他家"))
	failed += _check("no gomoku", not source.contains("五子棋"))
	failed += _check("request friend", source.contains("RoomClient.request_friend"))
	failed += _check("board empty copy", source.contains("黑板还是空的，回车写一句。"))
	failed += _check("board hint", source.contains("黑板只有本班听得见"))
	failed += _check("chat placeholder", source.contains("点这里或按 Enter 写黑板"))
	failed += _check("send copy", source.contains('"发送"'))
	failed += _check("no bubble hint", not source.contains("走近才看得到气泡"))
	failed += _check("chat send", source.contains("RoomClient.send_chat"))
	failed += _check("focus blocks walk", source.contains("_chat_focused"))
	var tscn := FileAccess.get_file_as_string("res://windows/world_window.tscn")
	failed += _check("chat bar scene", tscn.contains("name=\"ChatBar\""))
	failed += _check("chat input scene", tscn.contains("name=\"ChatInput\""))
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("world_social: %s" % label)
	return 1
```

This task only needs the inspect-menu assertions to start passing; chat assertions will fail until Task 7. **Do not add the chat/board assertions yet.** Stop the test file after the `request friend` check for this task:

```gdscript
	failed += _check("request friend", source.contains("RoomClient.request_friend"))
	return failed
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL `world_social: inspect menu helper`.

- [ ] **Step 3: Add inspect menu to WorldWindow**

In `godot/windows/world_window.gd`:

Add:

```gdscript
const SchoolSocial = preload("res://school/school_social.gd")
```

Add fields:

```gdscript
var _inspect_id := ""
var _inspect_menu: Control
```

In `_ready`, after `_stage.resized.connect`:

```gdscript
	_stage.gui_input.connect(_on_stage_input)
	_map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

In `_configure_pet`, after `pet.redraw()`:

```gdscript
	pet.mouse_filter = Control.MOUSE_FILTER_STOP
	if id == "self":
		if pet.gui_input.is_connected(_on_self_pet_input):
			pet.gui_input.disconnect(_on_self_pet_input)
		if not pet.gui_input.is_connected(_on_self_pet_input):
			pet.gui_input.connect(_on_self_pet_input)
	else:
		if pet.gui_input.is_connected(_on_self_pet_input):
			pet.gui_input.disconnect(_on_self_pet_input)
		var cb := _on_other_pet_input.bind(id)
		if not pet.gui_input.is_connected(cb):
			pet.gui_input.connect(cb)
```

Godot cannot reliably `is_connected` a bound lambda across rebuilds. Instead disconnect all `gui_input` on that pet then connect once:

```gdscript
	for conn in pet.gui_input.get_connections():
		pet.gui_input.disconnect(conn.callable)
	if id == "self":
		pet.gui_input.connect(_on_self_pet_input)
	else:
		pet.gui_input.connect(_on_other_pet_input.bind(id))
```

Add methods:

```gdscript
func _on_self_pet_input(event: InputEvent) -> void:
	if _is_left_click(event):
		_close_inspect()


func _on_other_pet_input(event: InputEvent, client_id: String) -> void:
	if not _is_left_click(event):
		return
	_open_inspect(client_id)


func _on_stage_input(event: InputEvent) -> void:
	if not _is_left_click(event):
		return
	_close_inspect()
	var focus := get_viewport().gui_get_focus_owner()
	if focus:
		focus.release_focus()


func _is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func _open_inspect(client_id: String) -> void:
	var person: Dictionary = {}
	for item in _others:
		if String(item.get("clientId", "")) == client_id:
			person = item
			break
	if person.is_empty():
		return
	_inspect_id = client_id
	if is_instance_valid(_inspect_menu):
		_inspect_menu.queue_free()
	var menu := PanelContainer.new()
	_inspect_menu = menu
	var box := VBoxContainer.new()
	menu.add_child(box)
	var name_label := Label.new()
	name_label.text = String(person.get("name", ""))
	box.add_child(name_label)
	var kind := SchoolSocial.friend_menu_kind(client_id, SchoolSocial.friend_ids(RoomClient.friends))
	if kind == "already":
		var already := Button.new()
		already.text = "已是好友"
		already.disabled = true
		box.add_child(already)
	else:
		var add := Button.new()
		add.text = "加好友"
		add.pressed.connect(func():
			RoomClient.request_friend(client_id)
			_close_inspect()
		)
		box.add_child(add)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(_close_inspect)
	box.add_child(cancel)
	_stage.add_child(menu)
	var screen := _map_root.position + Vector2(float(person.x), float(person.y)) * _map_root.scale
	menu.position = Vector2(maxi(8, int(screen.x + 36)), maxi(8, int(screen.y)))


func _close_inspect() -> void:
	_inspect_id = ""
	if is_instance_valid(_inspect_menu):
		_inspect_menu.queue_free()
	_inspect_menu = null
```

In `apply_snapshot` / `apply_others`, after syncing pets, if `_inspect_id` is no longer in `_others`, `_close_inspect()`.

Do not add 五子棋 or 去他家 buttons.

- [ ] **Step 4: Run tests and make sure they pass**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/windows/world_window.gd godot/tests/test_world_social.gd
git commit -m "Let Godot classmates be added from a small inspect menu."
```

---

### Task 7: Classroom blackboard and WASD-safe input

**Files:**
- Modify: `godot/windows/world_window.tscn`
- Modify: `godot/windows/world_window.gd`
- Modify: `godot/tests/test_world_social.gd`

**Interfaces:**
- Consumes: `RoomClient.board`, `RoomClient.send_chat`, `RoomClient.chat_received`, `SchoolSocial.visible_board`, `SchoolSocial.is_classroom_place`, `SchoolSocial.BOARD_*`
- Produces: classroom overlay over `k` tiles (dark `#24382c`, chalk `#e8f0c8`); empty `黑板还是空的，回车写一句。`; lines `{name}：{text}` last 7; bottom bar only in classroom with placeholder `点这里或按 Enter 写黑板`, hint `黑板只有本班听得见`, button `发送`, max 80; campus hides bar and overlay; focused chat input skips WASD; map click blurs input; no optimistic local insert

- [ ] **Step 1: Add remaining assertions to `test_world_social.gd`**

Append before `return failed`:

```gdscript
	failed += _check("board empty copy", source.contains("黑板还是空的，回车写一句。"))
	failed += _check("board hint", source.contains("黑板只有本班听得见"))
	failed += _check("chat placeholder", source.contains("点这里或按 Enter 写黑板"))
	failed += _check("send copy", source.contains('"发送"'))
	failed += _check("no bubble hint", not source.contains("走近才看得到气泡"))
	failed += _check("chat send", source.contains("RoomClient.send_chat"))
	failed += _check("focus blocks walk", source.contains("_chat_focused"))
	var tscn := FileAccess.get_file_as_string("res://windows/world_window.tscn")
	failed += _check("chat bar scene", tscn.contains("name=\"ChatBar\""))
	failed += _check("chat input scene", tscn.contains("name=\"ChatInput\""))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: FAIL `world_social: board empty copy` or `chat bar scene`.

- [ ] **Step 3: Add ChatBar to the scene and wire blackboard UI**

Append to `godot/windows/world_window.tscn` inside `VBox`, after `Stage`:

```
[node name="ChatBar" type="VBoxContainer" parent="VBox"]
visible = false
layout_mode = 2

[node name="ChatHint" type="Label" parent="VBox/ChatBar"]
layout_mode = 2
text = "黑板只有本班听得见"

[node name="ChatRow" type="HBoxContainer" parent="VBox/ChatBar"]
layout_mode = 2

[node name="ChatInput" type="LineEdit" parent="VBox/ChatBar/ChatRow"]
layout_mode = 2
size_flags_horizontal = 3
placeholder_text = "点这里或按 Enter 写黑板"
max_length = 80

[node name="ChatSend" type="Button" parent="VBox/ChatBar/ChatRow"]
layout_mode = 2
text = "发送"
```

In `world_window.gd` add onready:

```gdscript
@onready var _chat_bar: VBoxContainer = $VBox/ChatBar
@onready var _chat_input: LineEdit = $VBox/ChatBar/ChatRow/ChatInput
@onready var _chat_send: Button = $VBox/ChatBar/ChatRow/ChatSend
```

Add:

```gdscript
var _board_overlay: Control
```

In `_ready`:

```gdscript
	_chat_send.pressed.connect(_submit_chat)
	_chat_input.text_submitted.connect(func(_t): _submit_chat())
	if not RoomClient.chat_received.is_connected(_on_chat_received):
		RoomClient.chat_received.connect(_on_chat_received)
	if not RoomClient.friends_changed.is_connected(_on_friends_changed_world):
		RoomClient.friends_changed.connect(_on_friends_changed_world)
```

`_on_friends_changed_world` should rebuild the inspect menu if it is open (so 加好友 becomes 已是好友).

At the start of `_physics_process` movement, skip walking when `_chat_focused()`:

```gdscript
func _chat_focused() -> bool:
	return is_instance_valid(_chat_input) and _chat_input.has_focus()
```

In `_physics_process`, change the movement guard to:

```gdscript
	if _place.is_empty() or _you.is_empty() or not has_focus() or _chat_focused():
		return
```

Add:

```gdscript
func _submit_chat() -> void:
	if not is_instance_valid(_chat_input):
		return
	RoomClient.send_chat(_chat_input.text)
	_chat_input.text = ""


func _on_chat_received(_line: Dictionary) -> void:
	_refresh_board()


func _classroom_now() -> bool:
	return SchoolSocial.is_classroom_place(_place)


func _refresh_board() -> void:
	if is_instance_valid(_board_overlay):
		_board_overlay.queue_free()
		_board_overlay = null
	_chat_bar.visible = _classroom_now()
	if not _classroom_now():
		return
	var overlay := Control.new()
	_board_overlay = overlay
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var map_w := SchoolLogic.map_size(_place).cols * SchoolLogic.TILE
	overlay.position = Vector2(SchoolSocial.BOARD_LEFT, SchoolSocial.BOARD_TOP)
	overlay.size = Vector2(map_w - SchoolSocial.BOARD_SIDE_PAD * 2.0, SchoolSocial.BOARD_HEIGHT)
	var bg := ColorRect.new()
	bg.color = Color("#24382c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)
	var lines := VBoxContainer.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.add_theme_constant_override("separation", 2)
	overlay.add_child(lines)
	var visible: Array = SchoolSocial.visible_board(RoomClient.board)
	if visible.is_empty():
		var empty := Label.new()
		empty.text = "黑板还是空的，回车写一句。"
		empty.add_theme_color_override("font_color", Color("#e8f0c8"))
		empty.add_theme_font_size_override("font_size", 12)
		lines.add_child(empty)
	else:
		for line in visible:
			var row := Label.new()
			row.text = "%s：%s" % [String(line.get("name", "")), String(line.get("text", ""))]
			row.add_theme_color_override("font_color", Color("#e8f0c8"))
			row.add_theme_font_size_override("font_size", 12)
			lines.add_child(row)
	_map_root.add_child(overlay)
```

Call `_refresh_board()` at the end of `apply_snapshot` (after `_rebuild_map`). Campus must hide ChatBar.

`_update_status`: if `_alert` empty and classroom, keep `"%s · %d人"`. Do not use `走近才看得到气泡`. Prefer `RoomClient.last_notice` when `_alert` is empty and `last_notice` is set (WindowHub already pushes notices into `_alert` via `status`).

- [ ] **Step 4: Run tests and make sure they pass**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add godot/windows/world_window.gd godot/windows/world_window.tscn godot/tests/test_world_social.gd
git commit -m "Show classroom boards and send chat without walking while typing."
```

---

### Task 8: README and manual check notes

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: shipped Tasks 1–7
- Produces: Godot README mentions blackboard + friends; still says principal stays Node

- [ ] **Step 1: Update the Godot experimental paragraph**

In `README.md`, replace:

```
先另开一个终端跑 `npm run room`。Godot 里左键枢纽 → 去上学。设置里学校地址默认 `ws://127.0.0.1:18765`。
```

with:

```
先另开一个终端跑 `npm run room`。Godot 里左键枢纽 → 去上学；教室可写黑板、点同学加好友。枢纽「好友」会连校长，但不自动打开学校窗。关掉学校窗后连接还在，列表仍能看谁在线。设置里学校地址默认 `ws://127.0.0.1:18765`。和 Electron 同学同班时，黑板和加好友应互通。
```

Do not claim Godot can 进他家.

- [ ] **Step 2: Run automated tests once more**

Run: `godot --headless --path godot --script res://tests/run_tests.gd`

Expected: PASS.

- [ ] **Step 3: Manual checklist (do not skip; record pass/fail in the commit message body only if something fails and you stop)**

1. `npm run room`, run two Godot pets (or Godot + `npm start`). Same class: A types on the board, B sees `名字：正文` within about 1s. Neighbor class does not.
2. Enter a class that already has board history: last 7 lines show.
3. Campus has no chat bar. Click a classmate → 加好友; click again → 已是好友.
4. Hub 好友 shows online/在学校. Close school window: list remains, connection stays. Friend still 在线 if they stayed connected.
5. Stop the principal, click 好友: `连不上学校`, desk pet still runs.
6. Settings save while connected disconnects; going to school connects again.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Document Godot friends and classroom boards."
```

---

## Self-review

**Spec coverage**

| Spec item | Task |
| --- | --- |
| `chat` / `friends` parsed; `gameState` dropped | 2, 3 |
| `sanitize_chat`, board 80 / visible 7, menu predicates | 1 |
| send `chat` with classroom `placeId`; no optimistic insert | 3, 7 |
| `friendRequest`; welcome/snapshot/friends cache; incoming stored not drawn | 3, 5 |
| Hub 去上学 / 好友 / 设置; friends panel 300×480 | 5 |
| Friends-only connect does not `begin_school_flow` | 4 |
| Home snapshot does not open school window | 1, 3, 4 |
| `close_world` → `away`, `connected` stays true | 3, 4 |
| Quit / settings still disconnect | 4, 5 |
| Click menu 加好友 / 已是好友 / 取消 | 6 |
| Classroom board + input; campus none; WASD ignored while typing | 7 |
| Notices on school top bar and friends panel via `last_notice` | 3, 4, 5 |
| README Godot friends/blackboard | 8 |
| No server/protocol/Electron/home/gomoku/bubbles | all |

**Placeholder scan:** none. Commands and Chinese copy are exact.

**Type consistency:** `SchoolSocial.should_open_world` / `friend_menu_kind` / `friend_status_text` / `sanitize_chat` / `append_board` / `visible_board` are defined in Task 1 and reused later. RoomClient public names `send_chat`, `request_friend`, `leave_school`, `place_id`, `friends`, `board`, `last_notice`, `last_sent`, `connecting` are defined in Task 3 and used by Tasks 4–7.
