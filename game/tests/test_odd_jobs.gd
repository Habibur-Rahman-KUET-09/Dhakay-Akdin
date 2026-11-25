## Phase 6's small jobs between the big ones: the rickshaw's chain, things
## left behind (rickshaw and bus), washing cups and the credit book at the
## tea stall (activities.gd, day.gd, bus_day.gd, tea_day.gd).
extends "res://tests/check.gd"

const Hands = preload("res://scripts/rules/activities.gd")
const Day = preload("res://scripts/rules/day.gd")
const TeaDay = preload("res://scripts/rules/tea_day.gd")
const BusDay = preload("res://scripts/rules/bus_day.gd")
const RoadMap = preload("res://scripts/rules/road_map.gd")
const Balance = preload("res://scripts/rules/balance.gd")


func test_scores() -> void:
	eq(Hands.chain_score(3.0), 1.0, "the chain back on quickly")
	eq(Hands.chain_score(12.0), 0.0, "far too slow")
	near(Hands.chain_score(8.0), 0.5, "half way")
	eq(Hands.lost_item("hurry"), "file", "the office man's file")
	eq(Hands.lost_item("woman"), "purse", "a purse")
	eq(Hands.lost_item("nobody"), "phone", "a phone otherwise")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var c := Hands.lost_choices(rng, "b", ["a", "b", "c", "d"], 3)
	eq(c.size(), 3, "three choices")
	check(c.has("b") and c.has("a") and c.has("c"), "the right one and the first others")
	eq(Hands.lost_choices(rng, "x", ["x"], 3), ["x"], "only what there is")
	var places := [{"id": "p1"}, {"id": "p2"}, {"id": "p1"}, {"id": "p3"}]
	var by_id := Hands.lost_choices(rng, {"id": "p1"}, places, 3, "id").map(func(p): return p.id)
	by_id.sort()
	eq(by_id, ["p1", "p2", "p3"], "places compared by id, no repeats")
	eq(Hands.wash_score(3, 4), 0.75, "three cups of four")
	eq(Hands.wash_score(0, 0), 1.0, "nothing to wash")
	eq([Hands.ledger_result(30, 30), Hands.ledger_result(25, 30), Hands.ledger_result(35, 30)], ["right", "short", "over"], "what was written")
	check(Hands.repay_chance(3) > Hands.repay_chance(0) and Hands.repay_chance(0) > Hands.repay_chance(-2), "friends pay back more")


# --- The rickshaw ----------------------------------------------------------------


func _day(b: Balance) -> Day:
	var d := Day.new(RoadMap.load_area("mirpur"), b, 5)
	d.interactive = true
	return d


func _ride(d: Day, place: Dictionary, type := "hurry", npc := "") -> void:
	d.riding = {"place": place, "at": place.at, "type": type, "fare": 60, "tiles": 10,
		"since": d.clock, "eta": 30.0, "flooded": 0, "npc": npc}


func test_the_chain_comes_off_and_goes_back() -> void:
	var b := Balance.new()
	b.raw.rickshaw.chain_per_tile = 1.0
	var d := _day(b)
	var events := []
	d._entered(events)
	check(not events.has(Day.CHAIN), "not without a passenger")
	_ride(d, d.map.places[0])
	d._entered(events)
	check(events.has(Day.CHAIN) and d.chain_off, "off, with a passenger aboard")
	d.pedal = true
	d.accel = 100.0
	d.update(0.3)
	eq(d.speed_now, 0.0, "standing, pedal or not")
	d.fix_chain(4.0)
	check(not d.chain_off, "back on")
	near(d.held, 4.0, "a while longer, done without care")
	d.chains = int(b.n("rickshaw.chain_max_per_day"))
	events.clear()
	d._entered(events)
	check(not events.has(Day.CHAIN), "not more than twice a day")
	var plain := Day.new(RoadMap.load_area("mirpur"), b, 5)
	_ride(plain, plain.map.places[0])
	events.clear()
	plain._entered(events)
	check(not events.has(Day.CHAIN), "never without the hands")


func test_left_on_the_rickshaw_seat() -> void:
	var b := Balance.new()
	b.raw.rickshaw.lost_chance = 1.0
	var d := _day(b)
	var places: Array = d.map.places
	var first: Dictionary = places[0]
	_ride(d, first, "hurry", "rafiq")
	var events := []
	d._deliver(events)
	check(not d._left_behind.is_empty(), "something left on the seat")
	d._left_behind.found_at = d.trips
	events.clear()
	d._found(events)
	check(not events.has(Day.LOST_ITEM), "found only once someone else is aboard")
	_ride(d, places[1], "normal")
	d._found(events)
	check(events.has(Day.LOST_ITEM), "the next passenger finds it")
	eq(d.lost.item, "file", "an office file")
	var ids: Array = d.lost.choices.map(func(p): return p.id)
	eq(ids.size(), 3, "three places to choose from")
	check(ids.has(first.id), "where he got off is one of them")
	var right: int = ids.find(first.id)
	var before := d.money
	eq(d.return_lost(right), "right", "remembered")
	eq(d.money - before, int(b.n("rickshaw.lost_reward")), "the owner gives something")
	eq(d.returned, 1, "one returned")
	eq(d.npc_log.back(), {"id": "rafiq", "delta": 2, "what": "returned"}, "and a neighbour thinks well of him")
	eq(d.return_lost(0), "", "nothing waiting")
	# Wrong, or to the police: nothing.
	d.lost = {"item": "phone", "place": first, "choices": [places[2], first], "npc": "", "type": "normal"}
	before = d.money
	eq(d.return_lost(0), "wrong", "the wrong place")
	d.lost = {"item": "phone", "place": first, "choices": [first], "npc": "", "type": "normal"}
	eq(d.return_lost(-1), "police", "handed in")
	eq(d.money, before, "no reward either way")


# --- The bus ----------------------------------------------------------------------


func test_left_on_a_bus_seat() -> void:
	var b := Balance.new()
	b.raw.bus.lost_chance = 1.0
	var t := BusDay.new(b, 3)
	t.interactive = true
	t.stop_i = 2
	t._maybe_left_behind({"kind": "student", "woman": false, "seat": 30, "npc": ""})
	check(t._left_behind.is_empty(), "nothing left by someone standing")
	t._maybe_left_behind({"kind": "student", "woman": false, "seat": 5, "npc": "farhan"})
	eq(t._left_behind.stop, t.stop_id(2), "left at this stop")
	var events := []
	t._found(events)
	check(events.is_empty(), "not found at the same stop")
	t.stop_i = int(t._left_behind.found_at)
	t._found(events)
	eq(events, [BusDay.Event.LOST_ITEM], "found a stop or two on")
	eq(t.lost.item, "book", "a student's book")
	check((t.lost.choices as Array).has(t.stop_id(2)), "the stop is one of the choices")
	for c in t.lost.choices:
		var i := t.route.find(c)
		check(i >= 1 and i <= t.stop_i, "only stops passed: " + str(c))
	var start := t.earned()
	var rating := t.rating
	eq(t.return_lost((t.lost.choices as Array).find(t.stop_id(2))), "right", "remembered")
	eq(t.earned() - start, int(b.n("bus.lost_reward")), "the owner's thanks")
	check(t.rating >= rating, "the bus thought better of")
	eq(t.npc_log.back().what, "returned", "Farhan remembers")
	t.lost = {"item": "bag", "stop": "x", "choices": ["y", "x"], "npc": ""}
	eq(t.return_lost(0), "wrong", "the wrong stop")
	t.lost = {"item": "bag", "stop": "x", "choices": ["x"], "npc": ""}
	eq(t.return_lost(-1), "counter", "left at the counter")
	var plain := BusDay.new(b, 3)
	plain._maybe_left_behind({"kind": "normal", "woman": true, "seat": 3, "npc": ""})
	check(plain._left_behind.is_empty(), "never without the hands")


# --- The tea stall ----------------------------------------------------------------


func _stall(items: Array, npc := "") -> TeaDay:
	var t := TeaDay.new(Balance.new(), 1)
	t.interactive = true
	t.rahim_at = -1.0
	t.babu_at = -1.0
	_sit(t, 1, items, npc)
	return t


func _sit(t: TeaDay, id: int, items: Array, npc := "") -> void:
	var c := {
		"id": id, "seat": id - 1, "kind": "normal", "items": items.duplicate(), "ordered": items,
		"patience": 12.0, "left": 12.0, "bill": 0, "sugar": 2, "zarda": false, "npc": npc,
	}
	for it in items:
		c.bill += t.price(it)
	t.customers.append(c)


func test_cups_get_dirty_and_are_washed() -> void:
	var t := _stall(["liquor_tea"])
	eq(t.cups_clean, int(Balance.new().n("tea_stall.cups")), "all clean in the morning")
	t.cups_clean = 1
	t.tap("cup")
	t.tap("kettle")
	eq([t.cups_clean, t.cups_dirty], [0, 1], "drunk from: dirty")
	_sit(t, 2, ["liquor_tea"])
	eq(t.tap("cup"), [TeaDay.Event.NO_CUPS], "no clean cup")
	check(t.tray.is_empty(), "nothing in hand")
	check(not t.tap("banana").has(TeaDay.Event.NO_CUPS), "a banana needs no cup")
	eq(t.wash(5), 1, "only the dirty one")
	eq([t.cups_clean, t.cups_dirty, t.washed], [1, 0, 1], "clean again")
	t.tap("cup")
	t.discard()
	eq(t.cups_dirty, 1, "a cup thrown out is dirty too")
	var plain := TeaDay.new(Balance.new(), 1)
	plain.cups_clean = 0
	plain.customers = []
	check(not plain.tap("cup").has(TeaDay.Event.NO_CUPS), "no cups to count without the hands")


func _credit_stall(npc := "rafiq") -> TeaDay:
	var t := _stall(["milk_tea", "bun"], npc)
	t.b.raw.tea_stall.credit_chance = 1.0
	t.b.raw.tea_stall.phone_pay_chance = 0.0
	return t


func _serve(t: TeaDay) -> Array:
	var got := []
	for s in ["cup", "kettle", "milk", "sugar", "bun_jar"]:
		got.append_array(t.tap(s))
	return got


func test_a_neighbour_asks_for_credit() -> void:
	var t := _credit_stall()
	var got := _serve(t)
	check(got.has(TeaDay.Event.CREDIT_ASK), "write it in the book?")
	eq(t.credit_ask.bill, 35, "milk tea and a bun")
	var before := t.money
	eq(t.settle_credit(false), "cash", "no credit")
	eq(t.money - before, 35, "they pay now")
	eq(t.npc_log.back().what, "no_credit", "a little put out")
	eq(t.settle_credit(true), "", "nothing waiting")
	var u := _credit_stall()
	_serve(u)
	before = u.money
	eq(u.settle_credit(true, 35), "right", "written down right")
	eq(u.money, before, "nothing in the till yet")
	eq(u.ledger.size(), 1, "in the book")
	eq(u.owed_total(), 35, "owed")
	eq(u.npc_log.back().what, "credit", "pleased")
	var plain := _credit_stall()
	plain.interactive = false
	check(not _serve(plain).has(TeaDay.Event.CREDIT_ASK), "no book without the hands")
	var stranger := _credit_stall("")
	check(not _serve(stranger).has(TeaDay.Event.CREDIT_ASK), "only neighbours get credit")


func test_the_book_is_collected() -> void:
	var t := _credit_stall()
	t.relations = {"rafiq": 3}
	t.ledger = [{"npc": "rafiq", "owed": 35, "written": 35, "days": 0, "tries": 0}]
	eq(t.collect(), [], "not due the next day")
	var asked := []
	for i in 5:
		asked.append_array(t.collect())
	check(t.ledger.is_empty(), "settled one way or the other")
	eq(t.credit_collected + t.credit_lost, 35, "paid, or given up")
	check(not asked.is_empty(), "asked when due")
	# Written too much: they pay what they had, put out.
	var u := _credit_stall()
	u.relations = {"rafiq": 5}
	u.ledger = [{"npc": "rafiq", "owed": 30, "written": 40, "days": 5, "tries": 0}]
	for i in 4:
		u.collect()
	if u.credit_collected > 0:
		eq(u.credit_collected, 30, "only what they had")
		eq(u.npc_log[0].what, "overcharged", "and they say so")
	# Never paid: given up after a few times asked.
	var v := _credit_stall()
	v.b.raw.tea_stall.credit_tries = 1
	v.relations = {"rafiq": -5}
	v.ledger = [{"npc": "rafiq", "owed": 30, "written": 30, "days": 5, "tries": 0}]
	var r := v.collect()
	if not r[0].paid:
		eq(v.credit_lost, 30, "written off")
		eq(v.npc_log.back().what, "unpaid", "remembered")
	check(v.ledger.is_empty(), "out of the book either way")
	var w := _credit_stall()
	w.settle_credit(true, 0)
	w.credit_ask = {"npc": "rafiq", "bill": 30, "items": ["milk_tea"]}
	eq(w.settle_credit(true, 25), "short", "written too little")
