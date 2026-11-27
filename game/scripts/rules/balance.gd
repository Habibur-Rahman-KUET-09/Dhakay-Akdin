## Every number of the game, from content/balance.json (no numbers in code).
extends RefCounted

const PATH := "res://content/balance.json"

var raw: Dictionary
## A quick day (chosen before a day): every "*.day_seconds" is the quick
## day's length, and every "*.daily_target" shrinks with it.
static var quick := false


func _init(data: Dictionary = {}) -> void:
	raw = data if not data.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(PATH))


## A number by dotted path, e.g. "rickshaw.speed_tiles_per_s".
func n(path: String) -> float:
	var v := plain(path)
	if quick and path.ends_with(".day_seconds") and raw.has("quick_day"):
		return float(raw.quick_day.seconds)
	if quick and path.ends_with(".daily_target"):
		return roundf(v * quick_share(path.get_slice(".", 0)))
	return v


## A number as written, quick day or not.
func plain(path: String) -> float:
	var v = at(path)
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		push_error("balance: %s is not a number" % path)
		return 0.0
	return float(v)


## How much of a usual day a quick day is for `section` (1 if no quick day).
func quick_share(section: String) -> float:
	if not quick or not raw.has("quick_day") or not (raw.get(section, {}) as Dictionary).has("day_seconds"):
		return 1.0
	return float(raw.quick_day.seconds) / maxf(1.0, plain(section + ".day_seconds"))


func at(path: String):
	var v = raw
	for key in path.split("."):
		if typeof(v) != TYPE_DICTIONARY or not v.has(key):
			push_error("balance: no %s" % path)
			return null
		v = v[key]
	return v
