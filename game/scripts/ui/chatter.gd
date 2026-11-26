## Passing talk: now and then a passenger or customer says something about
## the city (the jam, an exam, cricket, a diet), shown on screen and, when
## the speech has been made, spoken. The lines are groups in voices.json
## ("ride_chat", "tea_chat", "bus_chat", "fuchka_chat") with Bangla and
## English words.
extends RefCounted

const CONTENT := "res://content/voices.json"

static var _lines := {}


## A random line of a group: {id (its speech file), text}, or {}.
static func pick(group: String, lang: String) -> Dictionary:
	if _lines.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONTENT))
		if typeof(parsed) == TYPE_DICTIONARY:
			_lines = parsed.get("lines", {})
	var all: Array = _lines.get(group, [])
	if all.is_empty():
		return {}
	var i := randi() % all.size()
	var line: Dictionary = all[i]
	return {"id": "%s_%d" % [group, i], "text": str(line.get(lang, line.get("bn", "")))}


## Seconds until the next line: every 20–35 s.
static func gap() -> float:
	return randf_range(20.0, 35.0)
