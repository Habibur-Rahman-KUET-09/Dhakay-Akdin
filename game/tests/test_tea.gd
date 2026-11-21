## Monir Mama's tea stall (§৪.৩, tea_day.gd).
extends "res://tests/check.gd"

const TeaDay = preload("res://scripts/rules/tea_day.gd")
const Balance = preload("res://scripts/rules/balance.gd")


## A stall with one customer waiting for the given things.
func _stall(items: Array, kind := "normal") -> TeaDay:
	var t := TeaDay.new(Balance.new(), 1)
	t.rahim_at = -1.0
	t.customers = [{
		"id": 1, "seat": 0, "kind": kind, "items": items.duplicate(), "ordered": items,
		"patience": 12.0, "left": 12.0, "bill": 0,
	}]
	for it in items:
		t.customers[0].bill += t.price(it)
	return t


func test_milk_tea_is_made_step_by_step() -> void:
	var t := _stall(["milk_tea"])
	eq(t.tap("cup"), [], "a cup")
	eq(t.tap("kettle"), [], "tea poured: still wanted further, so not handed over")
	eq(t.kettle, 7, "one cup out of the kettle")
	t.tap("milk")
	var got := t.tap("sugar")
	check(got.has(TeaDay.Event.GAVE) and got.has(TeaDay.Event.SERVED), "milk tea handed over and paid")
	eq(t.money, 15 + 2, "15 taka and a tip for quick service")
	eq(t.happy, 1, "happy")
	check(t.customers.is_empty(), "went off")


func test_liquor_tea_goes_at_once_when_nobody_wants_milk() -> void:
	var t := _stall(["liquor_tea"])
	t.tap("cup")
	var got := t.tap("kettle")
	check(got.has(TeaDay.Event.SERVED), "handed over straight away")
	eq(t.money, 10 + 1, "10 taka and a tip")


func test_both_teas_wanted_give_hands_over_the_plain_one() -> void:
	var t := _stall(["liquor_tea", "milk_tea"])
	t.tap("cup")
	eq(t.tap("kettle"), [], "could still become milk tea: waits")
	check(t.give().has(TeaDay.Event.GAVE), "hand it over as it is")
	eq(t.customers[0].items, ["milk_tea"], "milk tea still to come")


func test_a_wrong_step_spoils_it() -> void:
	var t := _stall(["milk_tea"])
	t.tap("cup")
	eq(t.tap("sugar"), [TeaDay.Event.WRONG_STEP], "sugar before tea: wrong")
	eq(t.tray, [], "start again")
	eq(t.tap("kettle"), [TeaDay.Event.WRONG_STEP], "tea without a cup: wrong")
	eq(t.kettle, 8, "nothing poured")


func test_paan_banana_and_bun() -> void:
	var t := _stall(["paan", "banana", "bun"])
	t.tap("betel_leaf")
	t.tap("areca")
	check(t.tap("lime").has(TeaDay.Event.GAVE), "paan: leaf, areca nut, lime")
	check(t.tap("banana").has(TeaDay.Event.GAVE), "a banana")
	check(t.tap("bun_jar").has(TeaDay.Event.SERVED), "a bun, and all done")
	eq(t.sold, 3, "three things sold")


func test_nobody_wants_it() -> void:
	var t := _stall(["banana"])
	eq(t.tap("bun_jar"), [TeaDay.Event.NOBODY_WANTS], "a bun nobody ordered")
	eq(t.money, 0, "no money for it")


func test_the_kettle_runs_dry_and_is_filled() -> void:
	var t := _stall([])
	t.customers.clear()
	t.kettle = 1
	t.tap("cup")
	var got := t.tap("kettle")
	check(got.has(TeaDay.Event.KETTLE_EMPTY), "the last cup")
	t.discard()
	t.tap("cup")
	eq(t.tap("kettle"), [TeaDay.Event.REFILLING], "empty: put on to fill")
	eq(t.tray, ["cup"], "the cup waits")
	var full := false
	for i in 60:
		if t.update(0.1).has(TeaDay.Event.KETTLE_FULL):
			full = true
			break
	check(full, "full again after a few seconds")
	eq(t.kettle, 8, "eight cups")


func test_impatient_customers_leave() -> void:
	var t := _stall(["milk_tea"], "office")
	t.customers[0].left = 0.5
	var got := t.update(0.6)
	check(got.has(TeaDay.Event.LEFT), "gave up")
	eq(t.lost, 1, "one lost")


func test_slow_service_gets_no_tip() -> void:
	var t := _stall(["banana"])
	t.customers[0].left = 3.0
	t.tap("banana")
	eq(t.money, 10, "paid, no tip")
	eq(t.happy, 0, "not happy")


func test_a_day_of_customers_with_rush_hours_and_rahim_chacha() -> void:
	var t := TeaDay.new(Balance.new(), 7)
	near(t.hour(), 6.0, "opens at 6 am")
	var arrived := 0
	var rush_arrivals := 0
	var rahim := false
	while not t.over:
		var got := t.update(0.25)
		if got.has(TeaDay.Event.ARRIVED):
			arrived += 1
			if t.rush():
				rush_arrivals += 1
		for c in t.customers:
			if c.kind == "rahim":
				rahim = true
				eq(c.items, ["milk_tea", "bun"], "Rahim Chacha: milk tea and a bun")
		# Nobody is served, so seats free up only when people give up.
	check(arrived > 10, "customers came all day (%d)" % arrived)
	check(rush_arrivals > 0, "some in the rush")
	check(rahim, "Rahim Chacha came")
	check(t.customers.is_empty(), "closed at night")
	near(t.hour(), 23.0, "closes at 11 pm")
	check(t.stars() >= 1.0, "a rating for the day")


# --- Week 7: upgrades, weather, Babu --------------------------------------


func test_second_kettle_pours_while_the_first_fills() -> void:
	var t := TeaDay.new(Balance.new(), 1, ["second_kettle"])
	t.rahim_at = -1.0
	t.babu_at = -1.0
	t.kettle = 1
	t.tap("cup")
	var got := t.tap("kettle")
	check(got.has(TeaDay.Event.REFILLING), "the empty one goes on to fill by itself")
	t.discard()
	t.tap("cup")
	t.tap("kettle")
	eq(t.kettle2, 7, "the second kettle pours meanwhile")
	eq(t.kettle, 0, "the first still filling")


func test_bench_brings_more_and_more_patient_customers() -> void:
	var plain := TeaDay.new(Balance.new(), 3)
	var bench := TeaDay.new(Balance.new(), 3, ["bench"])
	for t in [plain, bench]:
		t.rahim_at = -1.0
		t.babu_at = -1.0
		t.rain_at = -1.0
	plain._arrive()
	bench._arrive()
	near(bench.customers[0].patience - plain.customers[0].patience, 3.0, "+3 seconds")


func test_rain_keeps_customers_away_unless_there_is_an_awning() -> void:
	var counts := {}
	for owned in [[], ["awning"]]:
		var t := TeaDay.new(Balance.new(), 5, owned)
		t.rahim_at = -1.0
		t.babu_at = -1.0
		t.start_rain()
		t.rain_seconds = 1000.0
		var arrived := 0
		var rained := false
		for i in 400:
			var got := t.update(0.25)
			rained = rained or got.has(TeaDay.Event.RAIN_START)
			arrived += got.count(TeaDay.Event.ARRIVED)
			t.customers.clear()
		check(rained, "it rained")
		counts[owned.size()] = arrived
	check(counts[1] > counts[0] * 1.4, "more come under an awning (%d against %d)" % [counts[1], counts[0]])


func test_fridge_sells_cold_drinks() -> void:
	var t := TeaDay.new(Balance.new(), 1, ["fridge"])
	check(t.steps().has("fridge"), "a fridge on the counter")
	t.customers = [{"id": 1, "seat": 0, "kind": "normal", "items": ["cold_drink"], "ordered": ["cold_drink"], "patience": 12.0, "left": 12.0, "bill": 25}]
	check(t.tap("fridge").has(TeaDay.Event.SERVED), "a cold drink")
	eq(t.money, 25 + 3, "25 taka and a tip")
	var plain := TeaDay.new(Balance.new(), 1)
	check(not plain.steps().has("fridge"), "no fridge, no cold drinks")


func test_babu_comes_for_black_tea_and_paan() -> void:
	var t := TeaDay.new(Balance.new(), 2)
	t.rahim_at = -1.0
	t.babu_at = 1.0
	t.update(1.5)
	var babu = t.customers.filter(func(c): return c.kind == "babu")
	check(not babu.is_empty(), "Babu sat down")
	if not babu.is_empty():
		eq(babu[0].items, ["liquor_tea", "paan"], "black tea and paan")


func test_a_neighbour_who_likes_the_stall_tips_more() -> void:
	var t := _stall(["banana"])
	t.customers[0].npc = "rafiq"
	t.relations = {"rafiq": 3}
	t.tap("banana")
	eq(t.money, 10 + 1 + 20, "10, a tip, and 20 more from Rafiq Chacha")
	eq(t.npc_log.size(), 1, "he remembers")
	eq(t.npc_log[0].delta, 1, "fondly")
	eq(t.sold_items.get("banana", 0), 1, "a banana counted")
