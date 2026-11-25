## Stories played together on one phone (together.gd, together.json and
## their scenes in story.json).
extends "res://tests/check.gd"

const Together = preload("res://scripts/rules/together.gd")
const Story = preload("res://scripts/rules/story.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Progress = preload("res://scripts/rules/progress.gd")

const GAMES := ["door", "pour", "push", "crowd", "pump", "stir", "balloons", "choose"]

var b := Balance.new()


func test_every_story_is_whole() -> void:
	var t := Together.new()
	var st := Story.new()
	eq(t.stories.map(func(x): return x.id), ["flood", "eid", "bday"], "three stories")
	for s in t.stories:
		check(not st.scene(str(s.opening)).is_empty(), "%s: its opening" % s.id)
		eq((s.endings as Array).size(), 3, "%s: three endings" % s.id)
		for e in s.endings:
			check(not st.scene(str(e)).is_empty(), "%s: ending %s" % [s.id, e])
		var who := []
		for step in s.steps:
			who.append(step.who)
			check(not st.scene(str(step.scene)).is_empty(), "%s: scene %s" % [s.id, step.scene])
			check(GAMES.has(str(step.game)), "%s: a game we have: %s" % [s.id, step.game])
			check(step.has("good") and step.has("bad"), "%s: how it went" % s.id)
			if str(step.game) == "choose":
				for r in step.rounds:
					var n := (r.options as Array).size()
					check(int(r.right) >= 0 and int(r.right) < n, "a right answer among the options")
		who.sort()
		eq(who, ["babu", "monir", "rahim"], "%s: a turn each" % s.id)


func test_stories_open_in_turn() -> void:
	var t := Together.new()
	var d := Progress.fresh()
	check(not t.is_open(d, ["rickshaw", "tea"], "flood"), "not before Babu")
	var all := ["rickshaw", "tea", "bus"]
	check(t.is_open(d, all, "flood"), "the flood night first")
	check(not t.is_open(d, all, "eid"), "Eid after it")
	Together.settle(d, b, "flood", 0)
	check(t.is_open(d, all, "eid"), "open once the flood night is played, however it ended")
	check(not t.is_open(d, all, "bday"), "the birthday after Eid")
	check(not t.is_open(d, all, "nothing"), "no such story")


func test_endings_from_the_turns() -> void:
	eq(Together.ending(b, [1.0, 0.8, 0.7]), 2, "good")
	eq(Together.ending(b, [1.0, 0.0, 0.5]), 1, "so-so")
	eq(Together.ending(b, [0.2, 0.0, 0.5]), 0, "hard")
	eq(Together.ending(b, []), 0, "nothing played")
	eq(Together.step_score(0.9, 0.2), 1.0, "a good choice adds, up to 1")
	eq(Together.step_score(0.2, -0.3), 0.0, "a bad one takes away")
	eq(Together.push_score(3.0), 1.0, "a quick push")
	eq(Together.push_score(12.0), 0.0, "far too slow")


func test_stars_up_to_the_best_ending() -> void:
	var d := Progress.fresh()
	var tara: Array = b.at("together.tara")
	var start := int(d.tara)
	eq(Together.settle(d, b, "flood", 1), {"stars": int(tara[1]), "best": true}, "so-so first")
	eq(Together.settle(d, b, "flood", 0), {"stars": 0, "best": false}, "worse: nothing")
	eq(Together.settle(d, b, "flood", 2), {"stars": int(tara[2]) - int(tara[1]), "best": true}, "better: the difference")
	eq(int(d.tara), start + int(tara[2]), "the best ending's stars in all")
	eq(Together.of(d).best, {"flood": 2}, "remembered")
	eq(int(Together.of(d).played), 3, "played three times")
