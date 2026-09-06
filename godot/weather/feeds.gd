class_name WeatherFeeds
extends RefCounted

const FEEDS: Array = [
	{"source": "少数派", "url": "https://sspai.com/feed"},
	{"source": "Solidot", "url": "https://www.solidot.org/index.rss"},
	{"source": "人民网", "url": "http://www.people.com.cn/rss/politics.xml"},
]


static func items_from_feed(xml: String, source: String) -> Array:
	var items: Array = []
	var block_regex := RegEx.new()
	block_regex.compile("(?is)<(?:item|entry)\\b.*?</(?:item|entry)>")
	for block_match in block_regex.search_all(xml):
		var block: String = block_match.get_string()
		var title := _decode_xml(_capture(block, "(?is)<title(?:\\s[^>]*)?>(.*?)</title>"))
		if title.length() <= 4 or title.length() >= 80:
			continue
		items.append({"title": title, "source": source, "url": _link_from_block(block)})
	return items


static func pick_item(items: Array) -> Dictionary:
	for item in items:
		if item is Dictionary and not str(item.get("url", "")).is_empty():
			return item
	if not items.is_empty() and items[0] is Dictionary:
		return items[0]
	return {}


static func _link_from_block(block: String) -> String:
	var href := _absolute_url(
		_capture(block, "(?is)<link[^>]*href=[\"']([^\"']+)[\"'][^>]*/?>")
	)
	if not href.is_empty():
		return href
	var link := _absolute_url(
		_capture(block, "(?is)<link(?:\\s[^>]*)?>(.*?)</link>")
	)
	if not link.is_empty():
		return link
	return _absolute_url(
		_capture(block, "(?is)<guid(?:\\s[^>]*)?>(.*?)</guid>")
	)


static func _absolute_url(raw: String) -> String:
	var url := _decode_xml(raw)
	var url_regex := RegEx.new()
	url_regex.compile("(?i)^https?://")
	return url if url_regex.search(url) != null else ""


static func _decode_xml(text: String) -> String:
	var decoded := text
	decoded = _replace_all(decoded, "(?is)<!\\[CDATA\\[(.*?)\\]\\]>", "$1")
	decoded = decoded.replace("&amp;", "&")
	decoded = decoded.replace("&lt;", "<")
	decoded = decoded.replace("&gt;", ">")
	decoded = decoded.replace("&quot;", "\"")
	decoded = decoded.replace("&#39;", "'")
	decoded = _replace_all(decoded, "(?s)<[^>]+>", "")
	decoded = _replace_all(decoded, "\\s+", " ")
	return decoded.strip_edges()


static func _capture(text: String, pattern: String) -> String:
	var regex := RegEx.new()
	regex.compile(pattern)
	var result := regex.search(text)
	return result.get_string(1) if result != null else ""


static func _replace_all(text: String, pattern: String, replacement: String) -> String:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.sub(text, replacement, true)
