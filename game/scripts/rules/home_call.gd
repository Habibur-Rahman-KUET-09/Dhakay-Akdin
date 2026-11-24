## Calls from home (content/calls.json): now and then, in the middle of a
## working day, the family rings. What the player answers moves the
## family's feeling (progress.gd family, 0–10), may cost money sent home,
## and for Rahim Chacha may end the day early (going home). No drawing
## here, so it can be tested.
extends RefCounted

const PATH := "res://content/calls.json"
## A call comes on some days, from this mohalla level, somewhere in the
## middle of the day.
const CHANCE := 0.4
const FROM_LEVEL := 2

var calls := {}


func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		calls = parsed.calls


## When today's call comes, as a share of the day (0.3–0.7), or -1 for none.
static func plan(rng: RandomNumberGenerator, level: int) -> float:
	if level < FROM_LEVEL or rng.randf() >= CHANCE:
		return -1.0
	return rng.randf_range(0.3, 0.7)


## One of `who`'s calls; a family feeling low hears more of what is wrong.
func pick(who: String, rng: RandomNumberGenerator, family: int) -> Dictionary:
	var list: Array = calls.get(who, [])
	if list.is_empty():
		return {}
	if family <= 3:
		var needs := list.filter(func(c): return c.kind == "need")
		if not needs.is_empty() and rng.randf() < 0.6:
			return needs[rng.randi() % needs.size()]
	return list[rng.randi() % list.size()]


## What an answer does: {family, cost, end_day}.
static func effect(call: Dictionary, option: String) -> Dictionary:
	var o: Dictionary = call.get("options", {}).get(option, {})
	return {"family": int(o.get("family", 0)), "cost": int(o.get("cost", 0)), "end_day": bool(o.get("end_day", false))}
