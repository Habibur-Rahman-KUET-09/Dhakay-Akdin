## The game's sounds: a real recording from Freesound (sounds/real/, fetched
## by tool/fetch_sounds.py) where there is one, else the made-up sound of
## tool/make_sounds.py.
extends RefCounted

const CREDITS := "res://sounds/real/credits.json"


## The sound called `name`; `fallback` names the made-up one to use when
## there is no recording (by default the same name).
static func stream(name: String, fallback := "") -> AudioStream:
	var real := "res://sounds/real/%s.ogg" % name
	if ResourceLoader.exists(real):
		return load(real)
	var made := "res://sounds/%s.wav" % (fallback if fallback != "" else name)
	return load(made) if ResourceLoader.exists(made) else null


## Who recorded the sounds in use: ["rain: \"…\" by … (CC0)", …].
static func credits() -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(CREDITS):
		return out
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CREDITS))
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	for name in parsed:
		var c: Dictionary = parsed[name]
		var licence := str(c.get("licence", ""))
		licence = "CC0" if licence.contains("zero") else ("CC BY" if licence.contains("/by/") else licence)
		out.append("\"%s\" · %s · %s" % [c.get("title", name), c.get("by", ""), licence])
	return out
