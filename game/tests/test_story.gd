## The story chapters and the day's structure (story.gd, daily.gd).
extends "res://tests/check.gd"

const Story = preload("res://scripts/rules/story.gd")
const Daily = preload("res://scripts/rules/daily.gd")
const Progress = preload("res://scripts/rules/progress.gd")


func test_eleven_chapters_each_all_whole() -> void:
	var s := Story.new()
	eq(s.chapters.size(), 38, "thirty-eight chapters (Julekha Khala has five)")
	for who in ["rickshaw", "tea", "bus"]:
		eq(s.chapters.filter(func(c): return c.who == who).size(), 11, "ten and a side story for %s" % who)
	for c in s.chapters:
		check(c.panels.size() >= 1, "%s has panels" % c.id)
		for p in c.panels:
			check(p.lines.size() >= 1, "%s: every panel has lines" % c.id)
			for line in p.lines:
				check(s.cast.has(line.by), "%s: %s is in the cast" % [c.id, line.by])
		if c.has("choice"):
			for o in c.choice.options:
				for line in o.lines:
					check(s.cast.has(line.by), "%s: %s is in the cast" % [c.id, line.by])


func test_openings_and_what_opens_later() -> void:
	var s := Story.new()
	var data := Progress.fresh()
	eq(s.opening("rickshaw", data).id, "rahim_1", "Rahim Chacha starts with his first day")
	eq(s.waiting(data), [], "nothing else yet")
	data.story.seen.append("rahim_1")
	check(s.opening("rickshaw", data).is_empty(), "read once")
	data.rickshaw.days = 3
	eq(s.waiting(data).map(func(c): return c.id), ["rahim_2"], "three days: Sumi's news")
	data.rickshaw.earned = 3000
	data.rickshaw.upgrades = ["new_rickshaw"]
	data.rickshaw.school = 3000
	eq(s.waiting(data).size(), 4, "money, the new rickshaw, the school fee")
	data.tea.upgrades = ["bench", "fridge"]
	data.bus.days = 8
	check(s.waiting(data).any(func(c): return c.id == "monir_5"), "the fridge: Monir Mama's café dream")
	check(s.waiting(data).any(func(c): return c.id == "babu_5"), "eight days on the bus: Babu's dream")


func test_todays_character_turns() -> void:
	var open := ["rickshaw", "tea", "bus"]
	var seen := {}
	for i in 3:
		var d := Time.get_date_string_from_unix_time((Daily.day_number("2026-11-02") + i) * 86400)
		seen[Daily.featured(d, open)] = true
	eq(seen.size(), 3, "each character in turn")
	eq(Daily.featured("2026-11-02", ["rickshaw"]), "rickshaw", "only one open")
	eq(Daily.yesterday("2026-11-01"), "2026-10-31", "yesterday")


func test_challenges_suit_whats_open() -> void:
	for i in 10:
		var d := Time.get_date_string_from_unix_time((Daily.day_number("2026-11-02") + i) * 86400)
		eq(Daily.challenge(d, ["rickshaw"]).who, "rickshaw", "only rickshaw challenges at first")
	var c := Daily.challenge("2026-11-02", ["rickshaw", "tea", "bus"])
	check(Daily.met(c, c.who, {c.stat: c.goal}), "met at the goal")
	check(not Daily.met(c, c.who, {c.stat: int(c.goal) - 1}), "not below it")
	var other := "tea" if c.who != "tea" else "bus"
	check(not Daily.met(c, other, {c.stat: c.goal}), "only as the right character")


func test_every_speaker_has_a_voice() -> void:
	var v = JSON.parse_string(FileAccess.get_file_as_string("res://content/voices.json"))
	var story := Story.new()
	for id in story.cast:
		check(v.voices.has(id), "a voice for %s" % id)
	for group in v.lines:
		for line in v.lines[group]:
			check(v.voices.has(line.by), "%s: a voice for %s" % [group, line.by])
	# The game finds a story line's speech by the same name the tool gave it.
	var Voice = load("res://scripts/ui/voice.gd")
	eq(Voice.story_id("rahim", "সুমির মা, আজ থেকে মিরপুরের রাস্তায় রিকশা চালাব।"), "story_941206e428", "same name as tool/make_voices.py")
	check(Voice.ids_of("no_such_group").is_empty(), "an unknown group says nothing")


func test_choices_do_only_what_the_game_knows() -> void:
	var s := Story.new()
	var npcs = JSON.parse_string(FileAccess.get_file_as_string("res://content/npcs.json"))
	var ids: Array = npcs.people.map(func(p): return p.id)
	for c in s.chapters:
		if not c.has("choice"):
			continue
		eq(c.choice.options.size(), 2, "%s: two ways" % c.id)
		for o in c.choice.options:
			for k in o.effects:
				check(k in ["taka", "npc", "family", "after"], "%s: knows the effect %s" % [c.id, k])
			if o.effects.has("after"):
				for a in o.effects.after:
					check(a in ["days", "speed", "day_share", "target", "arrivals", "note"], "%s: knows the after %s" % [c.id, a])
			if o.effects.has("npc"):
				check(ids.has(o.effects.npc[0]), "%s: %s is a neighbour" % [c.id, o.effects.npc[0]])
			if o.effects.has("family"):
				check(o.effects.family[0] in ["rickshaw", "tea", "bus", "fuchka"], "%s: whose family" % c.id)


func test_a_story_choice_moves_the_family() -> void:
	var p := Progress.new(preload("res://scripts/rules/balance.gd").new(), "user://test_story_family.json")
	p.data = Progress.fresh()
	p.data.taka = 100
	p.finish_chapter("rahim_6", {"family": ["rickshaw", 2], "taka": -500})
	eq(p.family("rickshaw"), 7, "the family is glad")
	eq(int(p.data.taka), 0, "a cost never goes below nothing")
