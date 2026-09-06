extends RefCounted

const WeatherFeeds = preload("res://weather/feeds.gd")


func run() -> int:
	var failed := 0
	var rss := "<rss><channel><item><title>Hello</title><link>https://ex.test/a</link></item></channel></rss>"
	var items: Array = WeatherFeeds.items_from_feed(rss, "少数派")
	failed += _check("one RSS item", items.size() == 1)
	if items.size() == 1:
		failed += _check("RSS title", items[0].title == "Hello")
		failed += _check("RSS URL", items[0].url == "https://ex.test/a")
		failed += _check("RSS source", items[0].source == "少数派")

	var atom := (
		"<feed><entry><title><![CDATA[Rock &amp; <b>Roll</b>]]></title>"
		+ "<link href=\"https://ex.test/b?x=1&amp;y=2\" /></entry></feed>"
	)
	var atom_items: Array = WeatherFeeds.items_from_feed(atom, "Solidot")
	failed += _check("one Atom entry", atom_items.size() == 1)
	if atom_items.size() == 1:
		failed += _check("decoded title", atom_items[0].title == "Rock & Roll")
		failed += _check("Atom href", atom_items[0].url == "https://ex.test/b?x=1&y=2")

	var guid_feed := (
		"<rss><item><title>Guid Link</title><guid>https://ex.test/g</guid></item>"
		+ "<item><title>Bad</title><link>/relative</link></item></rss>"
	)
	var guid_items: Array = WeatherFeeds.items_from_feed(guid_feed, "人民网")
	failed += _check("filters short titles", guid_items.size() == 1)
	if guid_items.size() == 1:
		failed += _check("GUID fallback", guid_items[0].url == "https://ex.test/g")

	var first := {"title": "First", "source": "A", "url": ""}
	var linked := {"title": "Linked", "source": "B", "url": "https://ex.test"}
	failed += _check("pick linked item", WeatherFeeds.pick_item([first, linked]) == linked)
	failed += _check("pick first fallback", WeatherFeeds.pick_item([first]) == first)
	failed += _check("pick empty", WeatherFeeds.pick_item([]).is_empty())
	failed += _check("three feeds", WeatherFeeds.FEEDS.size() == 3)
	return failed


func _check(label: String, ok: bool) -> int:
	if ok:
		return 0
	push_error("feeds: %s" % label)
	return 1
