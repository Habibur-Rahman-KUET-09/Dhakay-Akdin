## Rahim Chacha's night shift (night.gd, day.gd's night).
extends "res://tests/check.gd"

const Night = preload("res://scripts/rules/night.gd")
const Day = preload("res://scripts/rules/day.gd")
const RoadMap = preload("res://scripts/rules/road_map.gd")
const Balance = preload("res://scripts/rules/balance.gd")


func _night(b: Balance) -> Day:
	var d := Day.new(RoadMap.load_area("mirpur"), b, 5)
	d.interactive = true
	d.start_night(5)
	return d


func test_unlit_lanes_and_guards() -> void:
	var map: RoadMap = RoadMap.load_area("mirpur")
	var dark := Night.dark_tiles(map, 0.3)
	var ordinary := map.roads().filter(func(p): return map.kind_at(p) == RoadMap.Kind.ROAD).size()
	check(dark.size() > ordinary * 0.15 and dark.size() < ordinary * 0.45, "about a third unlit: %d of %d" % [dark.size(), ordinary])
	eq(Night.dark_tiles(map, 0.3), dark, "the same every night")
	var g := Night.guard_tiles(map, 3)
	eq(g.size(), 3, "three guards")
	for i in g.size():
		for j in range(i + 1, g.size()):
			check(absi(g[i].x - g[j].x) + absi(g[i].y - g[j].y) >= 8, "spread out")
	check(Night.questions().size() >= 3, "questions to ask")


func test_the_night_shift() -> void:
	var b := Balance.new()
	var day_d := Day.new(RoadMap.load_area("mirpur"), b, 5)
	var d := _night(b)
	eq(d.hour(), 22.0, "ten at night")
	d.clock = d.day_seconds
	eq(d.hour(), 26.0, "until two")
	check(d.waiting.size() <= 3, "few people about")
	check(d._tea_tiles.size() == 1, "one stall still open")
	var nf := 0
	for w in d.waiting:
		nf += int(w.fair)
	check(nf > 0, "fares")
	# The same ride costs more at night.
	var dist := 10
	eq(d.fares.round_fare(d.fares.fair(dist) * b.n("night.fare")) > d.fares.fair(dist), true, "half as much again")
	var e0 := d.energy
	d._entered([])
	var night_cost := e0 - d.energy
	var e1 := day_d.energy
	day_d._entered([])
	check(night_cost > e1 - day_d.energy, "more tiring")


func test_potholes_in_unlit_lanes() -> void:
	var b := Balance.new()
	b.raw.night.pothole_chance = 1.0
	var d := _night(b)
	d.driver.cell = d.dark.keys()[0]
	var events := []
	d._night_tile(events)
	check(events.has(Day.POTHOLE) and events.has(Day.FLAT), "a pothole: a soft tyre (with the hands)")
	check(d.flat, "soft")
	var plain := Day.new(RoadMap.load_area("mirpur"), b, 5)
	plain.start_night(5)
	plain.driver.cell = plain.dark.keys()[0]
	events = []
	plain._night_tile(events)
	eq(events, [Day.POTHOLE], "without the hands: a jolt")
	check(plain.held > 0.0 and not plain.flat, "a moment's stop")
	b.raw.night.pothole_chance = 0.0
	plain.driver.cell = plain.dark.keys()[1]
	events = []
	plain._night_tile(events)
	check(not events.has(Day.POTHOLE), "lit or lucky: nothing")


func test_the_night_guards() -> void:
	var b := Balance.new()
	b.raw.night.pothole_chance = 0.0
	var d := _night(b)
	d.driver.cell = d.guards[0]
	var events := []
	d._night_tile(events)
	eq(events, [Day.GUARD], "a guard's question")
	eq((d.guard_ask.question.options as Array).size(), 3, "three answers")
	d.riding = {"fare": 50}
	d.settle_guard(true)
	check(d.riding.get("safe", false), "a good answer: the passenger feels safe")
	events = []
	d._night_tile(events)
	check(events.is_empty(), "once a night")
	d.driver.cell = d.guards[1]
	d._night_tile(events)
	d.settle_guard(false)
	near(d.held, b.n("night.guard_hold_s"), "a bad one: held a while")
