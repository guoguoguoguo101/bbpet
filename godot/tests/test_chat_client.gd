extends RefCounted

const ChatClient = preload("res://llm/chat_client.gd")


func run() -> int:
	var failed := 0
	failed += _check(
		"completions append",
		ChatClient.completions_url("https://openrouter.ai/api/v1") == "https://openrouter.ai/api/v1/chat/completions"
	)
	failed += _check(
		"completions keep",
		ChatClient.completions_url("https://x/chat/completions/") == "https://x/chat/completions"
	)
	var placeholder: Dictionary = ChatClient.reply_without_key(0)
	failed += _check("placeholder flag", placeholder.placeholder == true)
	failed += _check("placeholder copy", String(placeholder.reply).contains("API Key"))
	var parsed := ChatClient.parse_reply('{"choices":[{"message":{"content":" 喝水呀 "}}]}')
	failed += _check("parse content", parsed == "喝水呀")
	failed += _check("parse empty", ChatClient.parse_reply("{}") == "")
	var busy: Dictionary = ChatClient.error_reply("HTTP 429: no")
	failed += _check("429 copy", String(busy.reply).contains("额度"))
	var prompt := ChatClient.system_prompt("豆豆", "一团")
	failed += _check("system name", prompt.contains("豆豆") and prompt.contains("一团"))
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("chat_client: %s" % label)
	return 1
