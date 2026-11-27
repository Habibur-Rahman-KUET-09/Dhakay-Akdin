## The school league: each player may pick where they study (a university,
## a college, "school", or "somewhere else"); their weekly tournament
## points (ranked.gd) go on the public card under that place
## (sc_<week>_<id>), and the board sums each place's players. No network
## here: testable.
extends RefCounted

const Friends = preload("res://scripts/rules/friends.gd")
const Ranked = preload("res://scripts/rules/ranked.gd")
const PATH := "res://content/schools.json"

static var _list := []


static func list() -> Array:
	if _list.is_empty():
		_list = JSON.parse_string(FileAccess.get_file_as_string(PATH)).schools
	return _list


static func name_of(id: String, lang: String) -> String:
	for s in list():
		if s.id == id:
			return str(s.get(lang, s.en))
	return ""


static func field(id: String, week: String) -> String:
	return "sc_%s_%s" % [week, id]


static func mine(data: Dictionary) -> String:
	return str(data.get("school", ""))


## Picks (or with "" clears) where the player studies.
static func choose(data: Dictionary, id: String) -> void:
	if id == "" or not name_of(id, "en").is_empty():
		data["school"] = id


## The card's field: this week's points under my place ({} if none).
static func fields(data: Dictionary, date: String) -> Dictionary:
	var id := mine(data)
	var points := Ranked.points(data, date)
	if id == "" or points <= 0:
		return {}
	return {field(id, Friends.week_of(date)): points}


## The board from each place's {count, sum}: [{id, players, points}],
## most points first, places with nobody left out.
static func board(stats: Dictionary) -> Array:
	var out := []
	for id in stats:
		var st: Dictionary = stats[id]
		if int(st.get("count", 0)) > 0:
			out.append({"id": str(id), "players": int(st.count), "points": int(st.get("sum", 0))})
	out.sort_custom(func(a, b): return int(a.points) > int(b.points))
	return out
