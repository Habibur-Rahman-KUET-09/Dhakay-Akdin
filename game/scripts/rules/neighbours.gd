## The named neighbours (§৬.১, content/npcs.json): who they are, and which
## of them to send out today. No drawing here, so it can be tested.
extends RefCounted

const PATH := "res://content/npcs.json"

var people: Array


func _init() -> void:
	people = JSON.parse_string(FileAccess.get_file_as_string(PATH)).people


func find(id: String) -> Dictionary:
	for p in people:
		if p.id == id:
			return p
	return {}


func name_of(id: String, lang: String) -> String:
	var p := find(id)
	return p[lang] if not p.is_empty() else id


func role_of(id: String, lang: String) -> String:
	var p := find(id)
	return p.role[lang] if not p.is_empty() else ""


func ids() -> Array:
	return people.map(func(p): return p.id)
