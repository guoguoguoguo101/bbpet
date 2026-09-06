# Godot Desk Weather Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add city settings, timed weather/news bubble window, weather dress overlays, and principal `dress` sync to the Godot client without changing the protocol.

**Architecture:** Pure helpers port cities, `dressFor`, and RSS parse. `WeatherClient` autoload fetches Open-Meteo and RSS on timers. A native `BubbleWindow` sits beside the pet. `WeatherDress` overlays gear/fx on solo pet and gathering slots. `RoomClient` sends/receives existing `dress` messages. Subwindows stay un-embedded.

**Tech Stack:** Godot 4.4+ GDScript, `HTTPRequest`, existing Node principal. Headless tests via `res://tests/run_tests.gd`.

**Spec:** `docs/superpowers/specs/2026-09-06-godot-desk-weather-design.md`

## Global Constraints

- Godot 4.4+ / GDScript only; client work under `godot/`. Do not modify `server/`, `shared/` protocol shape, or Electron except one README sentence.
- Do not send `enterPlace("away")` on close. Home snapshots must not `show_world`.
- `embed_subwindows=false`. Bubble is a separate Window, not a fourth home window.
- User-visible failure copy: `{宠物名}：外网有点安静，我稍后再探探天气和新闻。`
- News line: `{宠物名}：[{source}] {title}`
- Default city Beijing `beijing` 39.9042, 116.4074. `pushIntervalMin` default 30, clamp ≥ 5.
- Weather every 20 minutes; push alternates weather/news.
- Bubble hold: 8s without url, 16s with url.
- Tests: `c:\Users\huangyazhe\Projects\bbpet\.tools\godot\Godot_v4.4.1-stable_win64.exe --headless --path godot --script res://tests/run_tests.gd` if `godot` is not on PATH. Malformed-JSON log may appear; exit 0 matters.
- Git commits English. PowerShell: `git commit -m "message"`. Do not amend or push unless asked.
- No LLM, gomoku, slack poses, flyer, photo gen, Godot-as-principal, or visual polish.

## File Structure

- Create: `godot/weather/cities.gd`
- Create: `godot/tests/test_cities.gd`
- Create: `godot/weather/dress_logic.gd`
- Create: `godot/tests/test_dress_logic.gd`
- Create: `godot/weather/feeds.gd`
- Create: `godot/tests/test_feeds.gd`
- Modify: `godot/autoload/app_state.gd`
- Modify: `godot/tests/test_app_state.gd`
- Modify: `godot/net/room_messages.gd`
- Modify: `godot/tests/test_room_messages.gd`
- Modify: `godot/autoload/room_client.gd`
- Modify: `godot/tests/test_room_client_flow.gd`
- Modify: `godot/windows/panel_window.gd`
- Modify: `godot/tests/test_panel_window.gd`
- Create: `godot/autoload/weather_client.gd`
- Create: `godot/tests/test_weather_client.gd`
- Modify: `godot/project.godot` (autoload + embed_subwindows)
- Modify: `godot/tests/test_sanity.gd`
- Create: `godot/windows/bubble_window.gd`
- Modify: `godot/autoload/window_hub.gd`
- Create: `godot/weather/weather_dress.gd`
- Modify: `godot/windows/pet_root.gd`
- Create: `godot/tests/test_weather_ui.gd`
- Modify: `README.md`

---

### Task 1: City table

**Files:**
- Create: `godot/weather/cities.gd`
- Create: `godot/tests/test_cities.gd`

**Interfaces:**
- Produces: `class_name WeatherCities` with `CITIES: Array` of `{id, name, latitude, longitude}` matching `shared/cities.ts` order; `DEFAULT_CITY`; `func by_id(id: String) -> Dictionary` unknown → Beijing.

- [ ] **Step 1: Write failing test** `godot/tests/test_cities.gd`

```gdscript
extends RefCounted
const WeatherCities = preload("res://weather/cities.gd")
func run() -> int:
	var failed := 0
	failed += _check("twelve cities", WeatherCities.CITIES.size() == 12)
	failed += _check("first beijing", WeatherCities.CITIES[0].id == "beijing")
	failed += _check("default", WeatherCities.DEFAULT_CITY.id == "beijing")
	failed += _check("lat", is_equal_approx(float(WeatherCities.DEFAULT_CITY.latitude), 39.9042))
	failed += _check("unknown", WeatherCities.by_id("nope").id == "beijing")
	failed += _check("shanghai", WeatherCities.by_id("shanghai").name == "上海")
	return failed
func _check(label: String, ok: bool) -> int:
	if ok: return 0
	push_error("cities: %s" % label)
	return 1
```

- [ ] **Step 2: Run suite — expect FAIL missing cities.gd**

- [ ] **Step 3: Implement `cities.gd` by copying the twelve cities from `shared/cities.ts`.** `by_id` loops `CITIES`, else `DEFAULT_CITY.duplicate(true)`.

- [ ] **Step 4: Run suite — expect PASS**

- [ ] **Step 5: Commit** `Add Godot city table matching Electron.`

---

### Task 2: dressFor port

**Files:**
- Create: `godot/weather/dress_logic.gd`
- Create: `godot/tests/test_dress_logic.gd`

**Interfaces:**
- Produces: `class_name DressLogic`
- `func dress_for(code: int, temperature: float, is_day: bool, wind: float) -> Dictionary` keys `gear: Array`, `fx: Array`, `dressLine: String`
- `func clamp_push_minutes(n: int) -> int` → `maxi(5, n)`
- `func quiet_line(pet_name: String) -> String` → `"%s：外网有点安静，我稍后再探探天气和新闻。" % pet_name`
- `func news_line(pet_name: String, source: String, title: String) -> String` → `"%s：[%s] %s" % [pet_name, source, title]`
- Night (`not is_day`): `gear=[]`, `fx=["stars"]`. Storm (code>=95 or 82 or 99): raincoat+umbrella, rain+storm.

Copy `WEATHER_MAP`, `dressFor` branching, and `WEATHER_LINES` from `electron/services/weather.ts` and `shared/weatherLines.ts`. `pick_line(lines)` may pick `lines[0]` in tests by seeding: implement `pick_line(lines, index := 0)` using `index % lines.size()` so tests are deterministic; production callers pass `randi()`.

- [ ] **Step 1: Test**

```gdscript
	var night: Dictionary = DressLogic.dress_for(0, 20.0, false, 0.0)
	failed += _check("night stars", night.fx == ["stars"] and night.gear.is_empty())
	var storm: Dictionary = DressLogic.dress_for(95, 18.0, true, 5.0)
	failed += _check("storm gear", storm.gear.has("raincoat") and storm.gear.has("umbrella"))
	failed += _check("storm fx", storm.fx.has("rain") and storm.fx.has("storm"))
	failed += _check("clamp", DressLogic.clamp_push_minutes(2) == 5 and DressLogic.clamp_push_minutes(30) == 30)
	failed += _check("quiet", DressLogic.quiet_line("豆豆") == "豆豆：外网有点安静，我稍后再探探天气和新闻。")
	failed += _check("news", DressLogic.news_line("豆豆", "少数派", "标题") == "豆豆：[少数派] 标题")
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Port `dressFor` exactly (unique gear/fx). `pick_line` uses provided index.**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `Port weather dress rules into Godot.`

---

### Task 3: RSS parse

**Files:**
- Create: `godot/weather/feeds.gd`
- Create: `godot/tests/test_feeds.gd`

**Interfaces:**
- Produces: `class_name WeatherFeeds`
- `const FEEDS` three entries: 少数派 `https://sspai.com/feed`, Solidot `https://www.solidot.org/index.rss`, 人民网 `http://www.people.com.cn/rss/politics.xml`
- `func items_from_feed(xml: String, source: String) -> Array` of `{title, source, url}`
- `func pick_item(items: Array) -> Dictionary` prefers items with url, else first; empty → `{}`

Port decode/link logic from `electron/services/news.ts` (`itemsFromFeed`, `linkFromBlock`, `decodeXml`). Zhihu fallback is optional; not required if three RSS fixtures pass.

- [ ] **Step 1: Test with a tiny RSS string containing one `<item><title>Hello</title><link>https://ex.test/a</link></item>` → title Hello, url https://ex.test/a, source 少数派.**

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement parser**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `Parse RSS news feeds for Godot bubbles.`

---

### Task 4: Persist city and interval

**Files:**
- Modify: `godot/autoload/app_state.gd`
- Modify: `godot/tests/test_app_state.gd`

**Interfaces:**
- `_default_state.settings` includes city fields from `WeatherCities.DEFAULT_CITY` and `pushIntervalMin: 30`
- `load_from` / `save_to` round-trip those keys
- `func set_city(id: String) -> void` uses `WeatherCities.by_id`
- `func set_push_interval_min(n: int) -> void` stores `DressLogic.clamp_push_minutes(n)`

- [ ] **Step 1: Extend `test_app_state.gd`:** default city beijing; save_to/load_from keeps shanghai + interval 10; interval 2 becomes 5.

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement load/save/setters. Do not persist apiKey/photo.**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `Persist city and bubble interval in Godot settings.`

---

### Task 5: dress messages

**Files:**
- Modify: `godot/net/room_messages.gd`
- Modify: `godot/tests/test_room_messages.gd`
- Modify: `godot/autoload/room_client.gd`
- Modify: `godot/tests/test_room_client_flow.gd`

**Interfaces:**
- `HANDLED` includes `"dress"`; still ignore `gameState`
- `signal dress_updated`
- `var dresses: Dictionary` # clientId -> {gear, fx}
- `func send_dress(dress: Dictionary) -> void` no-op if not connected or `home_id().is_empty()` or dress equals last uploaded; else `_send({type:dress, dress, placeId: home_id()})`
- Incoming `dress`: store `dresses[clientId]`, patch home_people/school people `dress` field, `dress_updated.emit()`. Do not `snapshot_ready`.

- [ ] **Step 1: Tests:** parse dress accepted; gameState ignored; `send_dress` while `connected` and `_you.homeId=home:x` sets `last_sent.type==dress`; disconnected does not send; applying server dress does not set `place_id` or emit snapshot_ready (reuse existing snapshot_ready spy).

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement. `disconnect_room` clears `dresses`.**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `Sync weather dress through the existing principal message.`

---

### Task 6: Wizard and settings city

**Files:**
- Modify: `godot/windows/panel_window.gd`
- Modify: `godot/tests/test_panel_window.gd`

**Interfaces:**
- Wizard: OptionButton `City` after name, items = city names, metadata = id, default current `cityId`
- Settings: heading 城市, same OptionButton; heading 冒泡间隔（分钟）, LineEdit `PushMin` with current minutes; save calls `set_city` / `set_push_interval_min`
- Confirm wizard also `set_city`

- [ ] **Step 1: Tests:** hub still 去上学; wizard has `City`; settings source contains `"城市"` and `"冒泡间隔（分钟）"` and `set_city`.

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Wire OptionButton from `WeatherCities.CITIES`. Keep existing save/confirm behavior. After successful settings save, if `WeatherClient` autoload exists later, Task 7 will refresh; for now call `AppState.save_to` as today. If WeatherClient is already an autoload by the time you implement, call `WeatherClient.refresh_after_settings()`.**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `Let Godot pick a city and bubble interval.`

---

### Task 7: WeatherClient

**Files:**
- Create: `godot/autoload/weather_client.gd`
- Create: `godot/tests/test_weather_client.gd`
- Modify: `godot/project.godot` add autoload `WeatherClient="*res://autoload/weather_client.gd"` after RoomClient

**Interfaces:**
- `signal weather_changed(info: Dictionary)`
- `signal bubble_requested(payload: Dictionary)` # {kind, text, url}
- `var last_weather: Dictionary`
- `var last_dress: Dictionary` # {gear, fx}
- `func parse_weather_payload(city_name: String, data: Dictionary) -> Dictionary` maps Open-Meteo `current` + `DressLogic.dress_for` + lookup description/emoji
- `func apply_weather(info: Dictionary) -> void` sets last_*, emits weather_changed, `RoomClient.send_dress({gear, fx})` if connected
- `func request_bubble(kind: String, text: String, url: String = "") -> void`
- `func quiet_bubble() -> void` uses `DressLogic.quiet_line(AppState.state.pet.name)`
- `func refresh_after_settings() -> void` restarts timers (20*60 weather, pushIntervalMin*60 alternate)
- HTTP: `https://api.open-meteo.com/v1/forecast?latitude=&longitude=&current=temperature_2m,weather_code,is_day,wind_speed_10m&timezone=Asia/Shanghai`
- Alternate push: even ticks weather `dressLine` kind weather; odd ticks news. Fail → quiet_bubble. Do not change dress on fetch fail.

Tests cannot hit the network. Test `parse_weather_payload` with a fixture:

```gdscript
{"current":{"temperature_2m":26.2,"weather_code":0,"is_day":1,"wind_speed_10m":1.2}}
```

Expect cityName passed in, temperature 26, code 0.

Also test `apply_weather` does not throw; `send_dress` only when a RoomClient stub `connected` — if autoload hard to stub, source-check `send_dress` in weather_client.gd and unit-test `parse_weather_payload` only.

- [ ] **Step 1: Failing tests for parse + quiet_bubble copy**

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement autoload. `_ready` skip timers if `DisplayServer.get_name()=="headless"`. Production `_ready` starts refresh.**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `Fetch Open-Meteo and RSS on a desk-pet timer.`

---

### Task 8: Bubble window

**Files:**
- Create: `godot/windows/bubble_window.gd` (extends Window)
- Modify: `godot/autoload/window_hub.gd`
- Modify: `godot/project.godot` `[display] window/subwindows/embed_subwindows=false`
- Modify: `godot/tests/test_sanity.gd` require that line
- Modify: `godot/tests/test_window_hub.gd` source contains `func show_bubble`

**Interfaces:**
- `WindowHub.show_bubble(payload: Dictionary)` / `hide_bubble()`
- BubbleWindow: borderless, transparent, always_on_top, unresizable; Label with payload.text; if url, Button or clickable that `OS.shell_open(url)` then hide
- Place left of pet root window, clamp to `screen_get_usable_rect`
- Auto-hide 8s, or 16s if url nonempty
- Connect `WeatherClient.bubble_requested`

- [ ] **Step 1: Sanity test FAIL without embed line if not already present (working tree may already have it — keep it).** Hub source check `show_bubble`.

- [ ] **Step 2: FAIL or already green for embed — still add show_bubble API**

- [ ] **Step 3: Implement. Size ~ Vector2i(220, 80) min, grow with text autowrap ~240px wide.**

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `Show weather and news in a native bubble window.`

---

### Task 9: WeatherDress overlay

**Files:**
- Create: `godot/weather/weather_dress.gd` (Control)
- Modify: `godot/windows/pet_root.gd`
- Create: `godot/tests/test_weather_ui.gd`

**Interfaces:**
- `WeatherDress.apply(dress: Dictionary)` shows/hides child nodes for each gear/fx. Rain/snow: a few ColorRect/Label particles (8–14), no new pixel art files required; umbrella/beanie/scarf/raincoat/snowman/juice/shades as simple colored Control/Label markers overlapping the 64×64 pet (CSS class names from `src/pet/WeatherDress.tsx` as a layout guide, not pixel-perfect).
- PetRoot: child `WeatherDress` on solo PixelPet; gathering slots each get a WeatherDress from `RoomClient.dresses.get(id, last_dress for self)`
- Connect `WeatherClient.weather_changed` and `RoomClient.dress_updated` to refresh overlays and `update_passthrough` (include overlay opaque pixels in `_image_points` / extra rects)
- Tray stays idle without dress

- [ ] **Step 1: `test_weather_ui.gd` source checks: `WeatherDress`, `weather_changed`, `raincoat`, no `FLYER`, passthrough still `DisplayServer.window_set_mouse_passthrough`**

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement overlays. Keep kick in-slot. Do not change menu embed behavior except already-false.**

- [ ] **Step 4: PASS full suite**

- [ ] **Step 5: Commit** `Overlay weather gear and effects on the desk pet.`

---

### Task 10: README

**Files:**
- Modify: `README.md` Godot experimental paragraph: 会按城市冒天气和新闻气泡，并按天气穿衣服；和 Electron 同学同场时应能看见雨衣/围巾。

- [ ] **Step 1: Edit README**

- [ ] **Step 2: Full Godot tests PASS**

- [ ] **Step 3: Commit** `Document Godot weather bubbles and dress sync.`

---

## Self-review

| Spec item | Task |
| --- | --- |
| Cities + default Beijing | 1, 4, 6 |
| dressFor + lines | 2 |
| RSS news | 3, 7 |
| Persist city/interval | 4 |
| dress send/recv | 5 |
| Wizard/settings | 6 |
| 20min weather, push alternate, quiet copy | 2, 7 |
| Bubble window 8s/16s, url open | 8 |
| embed_subwindows false | 8 |
| WeatherDress + passthrough | 9 |
| README | 10 |
| No LLM/gomoku/flyer/polish | all |

**Type names:** `dress_for`, `send_dress`, `show_bubble`, `parse_weather_payload`, `WeatherCities.by_id` used consistently.

**No placeholders.** WeatherDress may be geometric stand-ins; spec allows overlay without new sprite sheets.
