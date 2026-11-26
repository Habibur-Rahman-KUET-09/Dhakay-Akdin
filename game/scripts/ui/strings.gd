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


## A text in every language ({bn, en}), for things that keep both.
func both(key: String) -> Dictionary:
	return (_all.get(key, {"bn": key, "en": key}) as Dictionary).duplicate()


## Values written as they are, never in Bangla digits: names people
## chose, links and error codes.
const AS_IS := ["name", "url", "e"]
const BN_DIGITS := "০১২৩৪৫৬৭৮৯"


func t(key: String, values: Dictionary = {}) -> String:
	if not _all.has(key):
		return key
	var s: String = _all[key].get(lang, _all[key].get("en", key))
	for k in values:
		var v := str(values[k])
		s = s.replace("{%s}" % k, v if AS_IS.has(k) else num(v))
	return s


## Numbers in Bangla digits when the game is in Bangla (12:05 → ১২:০৫).
func num(text) -> String:
	var v := str(text)
	return bangla_digits(v) if lang == "bn" else v


static func bangla_digits(text: String) -> String:
	var out := ""
	for ch in text:
		var i := "0123456789".find(ch)
		out += BN_DIGITS[i] if i >= 0 else ch
	return out


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
