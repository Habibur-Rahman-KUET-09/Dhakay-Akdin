## Every number of the game, from content/balance.json (no numbers in code).
extends RefCounted

const PATH := "res://content/balance.json"

var raw: Dictionary


func _init(data: Dictionary = {}) -> void:
	raw = data if not data.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(PATH))


## A number by dotted path, e.g. "rickshaw.speed_tiles_per_s".
func n(path: String) -> float:
	var v = at(path)
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		push_error("balance: %s is not a number" % path)
		return 0.0
	return float(v)


func at(path: String):
	var v = raw
	for key in path.split("."):
		if typeof(v) != TYPE_DICTIONARY or not v.has(key):
			push_error("balance: no %s" % path)
			return null
		v = v[key]
	return v
