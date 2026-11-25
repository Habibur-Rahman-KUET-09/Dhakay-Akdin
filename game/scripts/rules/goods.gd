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


## Things bought with stars for a character's next day.
static func boosts(who: String) -> Array:
	return (data().get("boosts", []) as Array).filter(func(x): return x.who == who)


static func boost(id: String) -> Dictionary:
	for x in data().get("boosts", []):
		if x.id == id:
			return x
	return {}


static func phone() -> Dictionary:
	return data().get("phone", {})


static func samity() -> Dictionary:
	return data().get("samity", {})
