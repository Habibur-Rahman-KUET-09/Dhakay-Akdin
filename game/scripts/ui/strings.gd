## The game's text in Bangla and English, from content/strings.json.
## {name} in a text is filled from the values given.
extends RefCounted

const PATH := "res://content/strings.json"
const SETTINGS := "user://settings.cfg"

var lang := "bn"
var _all: Dictionary


func _init() -> void:
	_all = JSON.parse_string(FileAccess.get_file_as_string(PATH))


func has(key: String) -> bool:
	return _all.has(key)


func t(key: String, values: Dictionary = {}) -> String:
	if not _all.has(key):
		return key
	var s: String = _all[key].get(lang, _all[key].get("en", key))
	for k in values:
		s = s.replace("{%s}" % k, str(values[k]))
	return s


## The language last chosen, Bangla the first time.
static func saved_lang() -> String:
	var c := ConfigFile.new()
	if c.load(SETTINGS) != OK:
		return "bn"
	return c.get_value("ui", "lang", "bn")


static func save_lang(value: String) -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("ui", "lang", value)
	c.save(SETTINGS)
