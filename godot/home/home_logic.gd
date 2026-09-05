# 源：shared/homeActions.ts, shared/world.ts
class_name HomeLogic
extends RefCounted

const SLOT_W := 72
const SLOT_H := 94
const YARD_PAD_X := 24
const YARD_PAD_TOP := 40
const MENU_RESERVE := 80
const BAR_H := 30
const BAR_MIN_W := 144
const MAX_COLS := 4
const LOG_PAD := 6
const LOG_LINE := 15
const LOG_MAX_LINES := 3
const EMOTE_COOLDOWN_MS := 5000

const HOME_ACTIONS := {
	"wave": {
		"duration": 1600,
		"actorPose": "wave",
		"targetPose": "wave",
		"actorLabel": "挥手",
		"targetLabel": "挥手",
	},
	"hug": {
		"duration": 1800,
		"actorPose": "talk",
		"targetPose": "talk",
		"actorLabel": "抱抱",
		"targetLabel": "抱抱",
	},
	"pour": {
		"duration": 1800,
		"actorPose": "drink",
		"targetPose": "drink",
		"actorLabel": "倒水",
		"targetLabel": "咕嘟",
	},
	"wake": {
		"duration": 1800,
		"actorPose": "wave",
		"targetPose": "wake",
		"actorLabel": "拍醒",
		"targetLabel": "伸懒腰",
	},
	"kick": {
		"duration": 2800,
		"actorPose": "wake",
		"targetPose": "peek",
		"actorLabel": "飞踢",
		"targetLabel": "转圈飞走",
	},
}


static func home_place_id(owner_id: String) -> String:
	return "home:%s" % owner_id


static func home_owner_id(place_id: String) -> String:
	if place_id.begins_with("home:"):
		return place_id.substr(5)
	return ""


static func is_friend_at_home(card: Dictionary) -> bool:
	if not card.get("online", false):
		return false
	var client_id := String(card.get("clientId", ""))
	return String(card.get("homeId", "")) == home_place_id(client_id)


static func is_home_gathering(you: Dictionary, home_people: Array, my_id: String) -> bool:
	if you.is_empty():
		return false
	if home_owner_id(String(you.get("homeId", ""))) != my_id:
		return true
	return home_people.size() > 0


static func yard_metrics(people: int, chatting: bool, log_lines: int = 0) -> Dictionary:
	var n := maxi(1, people)
	var cols := mini(n, MAX_COLS)
	var rows := int(ceil(float(n) / float(cols)))
	var pets_w := cols * SLOT_W
	var log_h := chat_log_h(log_lines) if chatting else 0
	var bar_w := maxi(BAR_MIN_W, pets_w)
	return {
		"cols": cols,
		"rows": rows,
		"petsW": pets_w,
		"logH": log_h,
		"barW": bar_w,
		"barLeft": YARD_PAD_X,
		"width": YARD_PAD_X + maxi(BAR_MIN_W, pets_w) + MENU_RESERVE,
		"height": YARD_PAD_TOP + rows * SLOT_H + BAR_H + log_h,
	}


static func slot_offset(index: int, people: int) -> Dictionary:
	var cols: int = yard_metrics(people, false).cols
	var col := maxi(0, index) % cols
	var row := int(floor(float(maxi(0, index)) / float(cols)))
	return {
		"x": YARD_PAD_X + col * SLOT_W,
		"y": YARD_PAD_TOP + row * SLOT_H,
	}


static func chat_log_h(lines: int) -> int:
	var n := maxi(0, int(floor(lines)))
	if n <= 0:
		return 0
	return mini(LOG_PAD + LOG_MAX_LINES * LOG_LINE, LOG_PAD + n * LOG_LINE)


static func pose_for_action(emote: Dictionary, client_id: String, resting: String) -> String:
	var role := _role_in_action(emote, client_id)
	if emote.is_empty() or role == "":
		return resting
	var kind := String(emote.get("kind", ""))
	if not HOME_ACTIONS.has(kind):
		return resting
	var spec: Dictionary = HOME_ACTIONS[kind]
	if role == "to" and kind == "wake" and resting != "sleep":
		return "wave"
	return spec.actorPose if role == "from" else spec.targetPose


static func label_for_action(emote: Dictionary, client_id: String) -> String:
	var role := _role_in_action(emote, client_id)
	if emote.is_empty() or role == "":
		return ""
	var kind := String(emote.get("kind", ""))
	if not HOME_ACTIONS.has(kind):
		return ""
	var spec: Dictionary = HOME_ACTIONS[kind]
	return spec.actorLabel if role == "from" else spec.targetLabel


static func emote_label(kind: String) -> String:
	if HOME_ACTIONS.has(kind):
		return HOME_ACTIONS[kind].actorLabel
	return ""


static func gathering_title(you: Dictionary, guests: Array, my_id: String) -> String:
	var owner_id := home_owner_id(String(you.get("homeId", "")))
	if owner_id == my_id:
		return "自家"
	for guest in guests:
		if guest is Dictionary and String(guest.get("clientId", "")) == owner_id:
			var guest_name := String(guest.get("name", ""))
			if guest_name != "":
				return guest_name + "家"
			break
	return "好友家"


static func _role_in_action(emote: Dictionary, client_id: String) -> String:
	if emote.is_empty():
		return ""
	if String(emote.get("fromId", "")) == client_id:
		return "from"
	if String(emote.get("targetId", "")) == client_id:
		return "to"
	return ""
