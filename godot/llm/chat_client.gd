class_name ChatClient
extends RefCounted

const PLACEHOLDERS := [
	"还没接上大脑呢。去设置里填一下 API Key，我就能认真聊天啦。",
	"呜，现在只能用可爱占位回复。配好模型之后再来找我呀。",
	"我听到了！不过 Key 还没填，先摸摸头，等接入 LLM 再认真说。",
]


static func completions_url(base_url: String) -> String:
	var base := base_url.strip_edges().trim_suffix("/")
	if base.ends_with("/chat/completions"):
		return base
	return "%s/chat/completions" % base


static func system_prompt(pet_name: String, species_label: String) -> String:
	return "".join([
		"你是一只名叫%s的公司内部桌面宠物，形象是%s。" % [pet_name, species_label],
		"用第一人称、短句说话，可爱但克制，适合上班时间。",
		"一次回复不超过 80 字，不要堆表情，最多一个。",
		"可以陪同事闲聊、提醒喝水、用很短的话点评天气或新闻。",
	])


static func placeholder_reply(index: int = 0) -> Dictionary:
	var text: String = PLACEHOLDERS[posmod(index, PLACEHOLDERS.size())]
	return {"reply": text, "usedFallback": false, "placeholder": true}


static func reply_without_key(index: int = 0) -> Dictionary:
	return placeholder_reply(index)


static func parse_reply(raw: String) -> String:
	var json := JSON.new()
	if json.parse(raw) != OK or not json.data is Dictionary:
		return ""
	var data: Dictionary = json.data
	var choices: Variant = data.get("choices", [])
	if not choices is Array or choices.is_empty():
		return ""
	var first: Variant = choices[0]
	if not first is Dictionary:
		return ""
	var message: Variant = first.get("message", {})
	if not message is Dictionary:
		return ""
	return String(message.get("content", "")).strip_edges()


static func error_reply(message: String) -> Dictionary:
	if message.contains("429"):
		return {
			"reply": "额度有点挤，我先打个哈欠。等一会儿再聊，或者换一个模型试试。",
			"usedFallback": true,
			"placeholder": false,
		}
	return {
		"reply": "刚才走神了，没接住。检查一下 Key 和模型名，再跟我说一次呀。",
		"usedFallback": true,
		"placeholder": false,
	}


static func chat_body(model: String, messages: Array, pet_name: String, species_label: String) -> Dictionary:
	var packed: Array = [{"role": "system", "content": system_prompt(pet_name, species_label)}]
	packed.append_array(messages)
	return {
		"model": model,
		"temperature": 0.7,
		"max_tokens": 180,
		"messages": packed,
	}
