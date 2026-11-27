## The player's own ways, kept with the other settings: a tick and a buzz
## on every button, the left hand for the game's buttons, bigger text,
## Banglish words, and the home page by day or by night.
extends RefCounted

const SETTINGS := "user://settings.cfg"
const SCALES := [1.0, 1.15, 1.3]
const THEMES := ["auto", "day", "night"]

static var _cache := {}


static func _read(key: String, fallback):
	if _cache.has(key):
		return _cache[key]
	var c := ConfigFile.new()
	var v = fallback
	if c.load(SETTINGS) == OK:
		v = c.get_value("prefs", key, fallback)
	_cache[key] = v
	return v


static func _write(key: String, value) -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("prefs", key, value)
	c.save(SETTINGS)
	_cache[key] = value


static func taps() -> bool:
	return bool(_read("taps", true))


static func save_taps(on: bool) -> void:
	_write("taps", on)


static func left_hand() -> bool:
	return bool(_read("left_hand", false))


static func save_left_hand(on: bool) -> void:
	_write("left_hand", on)


static func text_scale() -> float:
	var v := float(_read("text_scale", 1.0))
	return v if SCALES.has(v) else 1.0


static func save_text_scale(v: float) -> void:
	_write("text_scale", v)


static func banglish() -> bool:
	return bool(_read("banglish", false))


static func save_banglish(on: bool) -> void:
	_write("banglish", on)


static func theme() -> String:
	var v := str(_read("theme", "auto"))
	return v if THEMES.has(v) else "auto"


static func save_theme(v: String) -> void:
	_write("theme", v)


## Night on the home page: chosen, or (auto) from 6 in the evening to 6 in
## the morning by the phone's clock.
static func night(hour := -1) -> bool:
	match theme():
		"night":
			return true
		"day":
			return false
	var h := hour if hour >= 0 else int(Time.get_datetime_dict_from_system().hour)
	return h >= 18 or h < 6


## Forget what was read (tests change the file under it).
static func reload() -> void:
	_cache.clear()
