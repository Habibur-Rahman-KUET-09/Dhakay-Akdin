## Stories played together on one phone (phase 7): a flood night, the
## night before Eid, Sumi's birthday (content/together.json). Each step is
## one character's turn (pass the phone to whoever plays them): a story
## scene, then a hand activity scored 0–1. The average of the steps (and
## the choices made) picks one of three endings: hard, so-so, good. Stars
## for the best ending reached, paid up to it once. A story opens once all
## three of Rahim Chacha, Monir Mama and Babu are open, the next ones
## after the one before has been played. No drawing, so it can be tested.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")

const PATH := "res://content/together.json"
## The three who play their part.
const CAST := ["rickshaw", "tea", "bus"]

## Set by the home screen just before the together scene opens.
static var next := ""

var stories: Array = []


func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	stories = parsed.get("stories", []) if typeof(parsed) == TYPE_DICTIONARY else []


func story(id: String) -> Dictionary:
	for st in stories:
		if st.id == id:
			return st
	return {}


static func fresh() -> Dictionary:
	# The best ending reached in each story (0 hard, 1 so-so, 2 good).
	return {"best": {}, "played": 0}


static func of(data: Dictionary) -> Dictionary:
	var have = data.get("together", null)
	if typeof(have) != TYPE_DICTIONARY:
		have = {}
		data["together"] = have
	var base := fresh()
	for k in base:
		if not have.has(k):
			have[k] = base[k]
	return have


## Whether a story can be played: all three characters open, and the
## story before it played.
func is_open(data: Dictionary, characters: Array, id: String) -> bool:
	for c in CAST:
		if not characters.has(c):
			return false
	var st := story(id)
	if st.is_empty():
		return false
	var after := str(st.get("after", ""))
	return after == "" or (of(data).best as Dictionary).has(after)


## The ending for the steps' scores: 2 good, 1 so-so, 0 hard.
static func ending(b: Balance, scores: Array) -> int:
	if scores.is_empty():
		return 0
	var sum := 0.0
	for x in scores:
		sum += clampf(float(x), 0.0, 1.0)
	var avg := sum / scores.size()
	if avg >= b.n("together.good"):
		return 2
	if avg >= b.n("together.ok"):
		return 1
	return 0


## A step's score from the activity's (0–1) and any bonus from a choice.
static func step_score(score: float, bonus := 0.0) -> float:
	return clampf(score + bonus, 0.0, 1.0)


## Pushing through the water: a quick push is best; seconds taken to the
## score (4 s or less full marks, none by 12 s).
static func push_score(seconds: float) -> float:
	return clampf(1.0 - (seconds - 4.0) / 8.0, 0.0, 1.0)


## A story played to `rank`: the best kept, and stars up to that ending's
## (only the difference, if a lower ending was paid before).
## Returns {stars, best (a better ending than before)}.
static func settle(data: Dictionary, b: Balance, id: String, rank: int) -> Dictionary:
	var t := of(data)
	t.played = int(t.played) + 1
	var tara: Array = b.at("together.tara")
	var had := int(t.best.get(id, -1))
	var out := {"stars": 0, "best": rank > had}
	if rank > had:
		var before := int(tara[had]) if had >= 0 else 0
		out.stars = int(tara[clampi(rank, 0, tara.size() - 1)]) - before
		t.best[id] = rank
		data.tara = int(data.get("tara", 0)) + out.stars
	return out
