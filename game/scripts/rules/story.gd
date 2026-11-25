## The story chapters (§৬.২, content/story.json): which are open to read
## from the save, and the first chapter each character starts with. No
## drawing here, so it can be tested.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const PATH := "res://content/story.json"

var cast: Dictionary
var chapters: Array
## Short family scenes (not chapters): for things bought for the home.
var scenes: Array = []
var school_goal := 3000


func _init(path := PATH) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	cast = parsed.cast
	chapters = parsed.chapters
	scenes = parsed.get("scenes", [])
	school_goal = int(Balance.new().n("rickshaw.school_fee_goal"))


func chapter(id: String) -> Dictionary:
	for c in chapters:
		if c.id == id:
			return c
	return {}


## A family scene ("home_bed"…), or {}.
func scene(id: String) -> Dictionary:
	for c in scenes:
		if c.id == id:
			return c
	return {}


## A character's opening chapter if it has not been read: shown before
## their first day.
func opening(who: String, data: Dictionary) -> Dictionary:
	for c in chapters:
		if c.unlock.get("start", "") == who and not _seen(c, data):
			return c
	return {}


## Chapters now open and not yet read (openings aside), in order.
func waiting(data: Dictionary) -> Array:
	return chapters.filter(func(c): return not c.unlock.has("start") and not _seen(c, data) and met(c.unlock, data))


## Chapters read, to read again.
func read(data: Dictionary) -> Array:
	return chapters.filter(func(c): return _seen(c, data))


func _seen(c: Dictionary, data: Dictionary) -> bool:
	return (data.get("story", {}).get("seen", []) as Array).has(c.id)


## Whether a chapter's condition holds for the save `data`: days played as
## a character, money earned as one, an upgrade bought, the school fee.
func met(unlock: Dictionary, data: Dictionary) -> bool:
	var record := {"rickshaw": data.get("rickshaw", {}), "tea": data.get("tea", {}), "bus": data.get("bus", {}), "fuchka": data.get("fuchka", {}), "delivery": data.get("delivery", {}), "hawker": data.get("hawker", {})}
	if unlock.has("days"):
		return int(record[unlock.days[0]].get("days", 0)) >= int(unlock.days[1])
	if unlock.has("earned"):
		return int(record[unlock.earned[0]].get("earned", 0)) >= int(unlock.earned[1])
	if unlock.has("upgrade"):
		return (record[unlock.upgrade[0]].get("upgrades", []) as Array).has(unlock.upgrade[1])
	if unlock.has("school_full"):
		return int(record.rickshaw.get("school", 0)) >= school_goal
	return false


## A person's name in the story: the cast, else the neighbours' list.
func speaker(id: String, lang: String) -> String:
	if cast.has(id):
		return cast[id][lang]
	return id


func colour(id: String) -> Color:
	return Color(cast[id].colour) if cast.has(id) else Color("37474F")
