## What the savings buy besides upgrades (content/goods.json): looks for
## the rickshaw, stall and bus; things for the home; a phone; the samity.
## Read once. No drawing here, so it can be tested.
extends RefCounted

const PATH := "res://content/goods.json"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_data = parsed
	return _data


## The looks on sale for `who` ("rickshaw", "tea", "bus").
static func looks(who: String) -> Array:
	return (data().get("looks", {}) as Dictionary).get(who, [])


static func look(who: String, id: String) -> Dictionary:
	for l in looks(who):
		if l.id == id:
			return l
	return {}


static func home_items() -> Array:
	return data().get("home", [])


static func home_item(id: String) -> Dictionary:
	for h in home_items():
		if h.id == id:
			return h
	return {}


static func phone() -> Dictionary:
	return data().get("phone", {})


static func samity() -> Dictionary:
	return data().get("samity", {})
