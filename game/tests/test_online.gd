## Rooms for playing at the same time on several phones (online.gd).
extends "res://tests/check.gd"

const Online = preload("res://scripts/rules/online.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Friends = preload("res://scripts/rules/friends.gd")

var b := Balance.new()


func test_who_plays_whom() -> void:
	eq(Online.owner_of(["h"], "babu"), "h", "alone: everyone")
	eq(Online.owner_of(["h", "f"], "rahim"), "h", "two: the host is Rahim Chacha")
	eq(Online.owner_of(["h", "f"], "monir"), "f", "the friend Monir Mama")
	eq(Online.owner_of(["h", "f"], "babu"), "h", "the host Babu too")
	eq(Online.owner_of(["h", "f", "g"], "babu"), "g", "three: one each")
	eq(Online.roles(["h", "f"]), {"h": ["rahim", "babu"], "f": ["monir"]}, "the roles")
	eq(Online.owner_of([], "babu"), "", "nobody")


func test_scores_from_the_others() -> void:
	var moves := {"f": {"name": "Rina", "s0": 0.8}}
	eq(Online.score_of(moves, "f", 0), 0.8, "played")
	eq(Online.score_of(moves, "f", 1), -1.0, "not yet")
	eq(Online.score_of(moves, "x", 0), -1.0, "not in the room")
	eq(Online.present(["h", "f", "g"], {"h": {}, "g": {}}), ["h", "g"], "who is here")


func test_race_places() -> void:
	var moves := {"a": {"name": "A", "t": 30.0}, "b": {"name": "B", "done": true, "time": 52.0},
		"c": {"name": "C", "done": true, "time": 48.5}}
	var rows := Online.standings(["a", "b", "c"], moves)
	eq(rows.map(func(r): return r.uid), ["c", "b", "a"], "finished first, quickest first")
	eq(rows[0].time, 48.5, "the time")


func test_live_race_stars() -> void:
	var data := {"tara": 0}
	var win := int(b.n("online.finish_tara")) + int(b.n("online.win_tara"))
	eq(Online.race_prize(data, b, "2026-11-25", 1, 2), win, "a win")
	eq(Online.race_prize(data, b, "2026-11-25", 2, 2), int(b.n("online.finish_tara")), "second")
	eq(Online.race_prize(data, b, "2026-11-25", 1, 1), int(b.n("online.finish_tara")), "alone is no win")
	eq(Online.race_prize(data, b, "2026-11-25", 1, 2), 0, "enough for today")
	eq(Online.race_prize(data, b, "2026-11-26", 1, 3), win, "a new day")
	eq(data.tara, win * 2 + 2 * int(b.n("online.finish_tara")), "kept")


func test_room_codes_fit_the_rules() -> void:
	# The Firestore rules take [A-HJ-NP-Z2-9]{6}.
	var re := RegEx.create_from_string("^[A-HJ-NP-Z2-9]{6}$")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 50:
		check(re.search(Friends.make_code(rng)) != null, "a code the rules allow")
