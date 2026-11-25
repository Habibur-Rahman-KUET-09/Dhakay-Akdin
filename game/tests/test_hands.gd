## The hand activities: their scores (activities.gd) and what they do in
## each character's day.
extends "res://tests/check.gd"

const Hands = preload("res://scripts/rules/activities.gd")
const Day = preload("res://scripts/rules/day.gd")
const TeaDay = preload("res://scripts/rules/tea_day.gd")
const BusDay = preload("res://scripts/rules/bus_day.gd")
const RoadMap = preload("res://scripts/rules/road_map.gd")
const Balance = preload("res://scripts/rules/balance.gd")


func test_scores() -> void:
	eq(Hands.pour_score([0.6, 0.7, 0.5, 0.9], false), 1.0, "four high strokes: a perfect pour")
	eq(Hands.pour_score([0.6, 0.2], false), 0.25, "one good stroke of four")
	eq(Hands.pour_score([0.6, 0.7, 0.5, 0.9], true), 0.4, "spilt")
	eq(Hands.sugar_score(2, 2, 3.0), 1.0, "right spoons, stirred well")
	check(Hands.sugar_score(3, 1, 3.0) < 0.2, "far too sweet")
	eq(Hands.paan_score(["areca", "lime"], false, true), 1.0, "a paan as wanted")
	near(Hands.paan_score(["areca", "lime", "zarda"], false, true), 0.8, "zarda nobody asked for")
	eq(Hands.pump_result(0.5), "soft", "not enough")
	eq(Hands.pump_result(0.9), "ok", "in the green")
	eq(Hands.pump_result(1.2), "burst", "too much")
	check(Hands.push_amount(0, 1) > Hands.push_amount(1, 1), "hand over hand pushes best")
	eq(Hands.slaps([1.0]), "one", "one slap")
	eq(Hands.slaps([1.0, 1.3]), "two", "two quick slaps")
	eq(Hands.slaps([1.0, 2.0]), "one", "two slow slaps are two single ones")
	eq([Hands.finger_for(10), Hands.finger_for(20), Hands.finger_for(50), Hands.finger_for(500)], [0, 1, 2, 3], "fingers")
	check(Hands.steady(0.2) and not Hands.steady(0.6), "steady at the door")


func _day(seed_value := 5) -> Day:
	var d := Day.new(RoadMap.load_area("mirpur"), Balance.new(), seed_value)
	d.interactive = true
	return d


func _stop_by(d: Day) -> Dictionary:
	var w: Dictionary = d.waiting[0]
	d.driver.cell = w.at
	d.driver.progress = 0.0
	d.update(0.01)
	return w


func test_haggling_up_to_their_limit() -> void:
	var d := _day()
	var w := _stop_by(d)
	check(int(w.limit) >= int(w.offer), "they will pay at least what they offer")
	eq(d.mood(int(w.offer)), 0.0, "happy at their own offer")
	near(d.mood(int(w.limit)), 1.0 if int(w.limit) > int(w.offer) else 0.0, "at the edge at their limit")
	check(d.haggle(int(w.limit)), "they agree at their limit")
	eq(int(d.riding.fare), int(w.limit), "and ride at it")


func test_asking_too_much_sends_them_off() -> void:
	var d := _day()
	var w := _stop_by(d)
	check(not d.haggle(int(w.limit) + 50), "too much")
	check(d.riding.is_empty() and not d.waiting.has(w), "walked off")


func test_the_bell() -> void:
	var d := _day()
	eq(d.ring(), "single", "one ring")
	eq(d.ring(), "double", "again straight away")
	check(d.clear_left > 2.0, "people step aside for longer")


func test_a_soft_tyre_and_the_pump() -> void:
	var d := _day()
	d.flat = true
	d.pedal = true
	d.accel = 100.0
	d.update(0.2)
	check(d.speed_now <= d.base_speed * 0.6, "slow on a soft tyre")
	eq(d.pump(0.5), "soft", "not enough")
	check(d.flat, "still soft")
	eq(d.pump(0.9), "ok", "in the green")
	check(not d.flat, "mended")
	d.flat = true
	var before := d.money
	eq(d.pump(1.3), "burst", "too much")
	eq(before - d.money, 30, "a new tube")


func test_stuck_in_deep_water_and_pushed_out() -> void:
	var d := _day()
	d.stuck = true
	d.pedal = true
	d.update(0.5)
	eq(d.speed_now, 0.0, "does not move")
	var got := []
	var hand := 0
	for i in 20:
		got = d.push(hand)
		hand = 1 - hand
		if not got.is_empty():
			break
	eq(got, [Day.FREED], "out after pushing hand over hand")
	check(not d.stuck, "free")


func _stall(items: Array) -> TeaDay:
	var t := TeaDay.new(Balance.new(), 1)
	t.interactive = true
	t.rahim_at = -1.0
	t.babu_at = -1.0
	t.customers = [{
		"id": 1, "seat": 0, "kind": "normal", "items": items.duplicate(), "ordered": items,
		"patience": 12.0, "left": 12.0, "bill": 0, "sugar": 3, "zarda": true,
	}]
	for it in items:
		t.customers[0].bill += t.price(it)
	return t


func test_tea_made_just_right_earns_more() -> void:
	var t := _stall(["liquor_tea"])
	t.tap("cup")
	t.tap("kettle", 1.0)
	eq(t.money, 10 + 1 + 3, "fare, tip and three for a perfect cup")
	eq(t.perfect, 1, "a perfect cup")
	check(t.last_served.perfect, "the screen hears of it")


func test_badly_made_tea_gets_no_tip() -> void:
	var t := _stall(["liquor_tea"])
	t.tap("cup")
	t.tap("kettle", 0.1)
	eq(t.money, 10, "just the price")
	check(not t.last_served.happy, "not happy")


func test_what_they_want_in_it() -> void:
	var t := _stall(["milk_tea", "paan"])
	eq(t.sugar_wanted(), 3, "three spoons")
	check(t.zarda_wanted(), "with zarda")


func test_fanning_the_stove() -> void:
	var t := _stall(["liquor_tea"])
	check(not t.fan(1.0), "nothing filling")
	t.refill_left = 5.0
	check(t.fan(1.0), "fanned")
	near(t.refill_left, 4.0, "a second sooner")


func _bus() -> BusDay:
	var t := BusDay.new(Balance.new(), 1)
	t.interactive = true
	return t


func test_fares_go_into_the_hand_until_sorted() -> void:
	var t := _bus()
	t.riders.append({"id": 900, "from": 0, "to": 5, "fare": 20, "kind": "normal", "note": 50, "paid": false, "owed": 0,
		"woman": false, "evader": false, "seat": 23})
	t.ask(900)
	t.give({20: 1, 10: 1})
	eq(t.loose, [50], "the 50 crumpled in his hand")
	eq(t.earned(), 20, "still counts as earned")
	eq(int(t.bag.get(50, 0)), 1, "not yet between the fingers")
	check(t.sort_note(50), "sorted")
	eq(int(t.bag.get(50, 0)), 2, "now it can be given as change")
	check(not t.sort_note(50), "none left")


func test_two_slaps_to_go() -> void:
	var t := _bus()
	t.dwell_left = 1.0
	eq(t.slap_go(), [BusDay.Event.TOO_EARLY], "people still getting on")
	t.dwell_left = 0.0
	t.at_door.clear()
	var got := t.update(0.1)
	check(not got.has(BusDay.Event.DEPARTED), "waits for the slaps")
	t.slap_go()
	got = t.update(0.1)
	check(got.has(BusDay.Event.DEPARTED), "off it goes")


func test_ostad_goes_by_himself_in_the_end() -> void:
	var t := _bus()
	t.dwell_left = 0.0
	t.at_door.clear()
	var went := false
	for i in 40:
		if t.update(0.1).has(BusDay.Event.DEPARTED):
			went = true
			break
	check(went, "went without the slaps, after a wait")


func test_pushing_the_crowd_back() -> void:
	var t := _bus()
	t.jam_waiting = 2
	var before := t.riders.size()
	eq(t.push_in(), [BusDay.Event.BOARDED, BusDay.Event.PUSHED], "one more on")
	eq(t.riders.size(), before + 1, "aboard")
	eq(t.jam_waiting, 1, "one still outside")


func test_the_hood_quick_or_slow() -> void:
	near(Hands.hood_score(2.0), 1.0, "within 3 seconds")
	near(Hands.hood_score(5.5), 0.5, "half by 5.5")
	near(Hands.hood_score(9.0), 0.0, "none by 8")


func test_the_phone_sms_real_or_fake() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var real := Hands.phone_sms(rng, 80, 1, false)
	eq([real.amount, real.from_service, real.name_ok, real.today], [80, true, true, true], "a real one is all right")
	for i in 30:
		var f := Hands.phone_sms(rng, 80, 1, true)
		eq(f.kind, "amount", "at level 1 only the amount is wrong")
		check(int(f.amount) != 80, "the amount is off (%d)" % f.amount)
	var kinds := {}
	for i in 200:
		kinds[Hands.phone_sms(rng, 80, 9, true).kind] = true
	eq(kinds.size(), 4, "all four tricks by level 8")
	eq(Hands.phone_result(real, false), "fine", "")
	eq(Hands.phone_result(real, true), "wrong", "")
	var fake := Hands.phone_sms(rng, 80, 1, true)
	eq(Hands.phone_result(fake, true), "caught", "")
	eq(Hands.phone_result(fake, false), "fooled", "")


func test_settling_a_phone_payment() -> void:
	var d := Day.new(RoadMap.load_area("mirpur"), Balance.new(), 3)
	var rng := RandomNumberGenerator.new()
	d.phone_pay = {"fare": 60, "npc": "", "sms": Hands.phone_sms(rng, 60, 1, true)}
	var before := d.money
	eq(d.settle_phone(true), "caught", "spotted")
	eq(d.money - before, 60, "paid in cash")
	d.phone_pay = {"fare": 60, "npc": "", "sms": Hands.phone_sms(rng, 60, 1, true)}
	eq(d.settle_phone(false), "fooled", "taken in")
	eq(d.money - before, 60, "nothing more")
	d.stars_sum = 4.0
	d.phone_pay = {"fare": 60, "npc": "", "sms": Hands.phone_sms(rng, 60, 1, false)}
	eq(d.settle_phone(true), "wrong", "a real one called fake")
	near(d.stars_sum, 3.0, "a star less")
	eq(d.money - before, 120, "still paid")


func test_phone_payments_at_the_stall_and_on_the_bus() -> void:
	var b := Balance.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var t := TeaDay.new(b, 4)
	t.money = 100
	t.happy = 2
	t.phone_pay = {"fare": 30, "npc": "", "sms": Hands.phone_sms(rng, 30, 1, true)}
	eq(t.settle_phone(true), "caught", "a fake spotted at the stall")
	eq(t.money, 130, "they pay cash")
	t.phone_pay = {"fare": 30, "npc": "", "sms": Hands.phone_sms(rng, 30, 1, true)}
	eq(t.settle_phone(false), "fooled", "a fake believed")
	eq(t.money, 130, "the bill is lost")
	t.phone_pay = {"fare": 30, "npc": "rafiq", "sms": Hands.phone_sms(rng, 30, 1, false)}
	eq(t.settle_phone(true), "wrong", "a real one doubted")
	eq(t.money, 160, "still paid")
	eq(t.happy, 1, "but not happy")
	eq(t.npc_log.back().what, "doubted", "and a neighbour remembers")
	eq(t.settle_phone(false), "", "nothing waiting")
	var bus := BusDay.new(b, 5)
	check(not bus.offer_phone(), "no phone payments without the hands")
	bus.interactive = true
	var start := bus.earned()
	bus.asking = {"id": 1, "fare": 20, "note": 20, "paid": false, "npc": ""}
	bus.asking_fare = 20
	var r: Dictionary = bus.asking
	bus.phone_pay = {"fare": 20, "npc": "", "sms": Hands.phone_sms(rng, 20, 1, false)}
	eq(bus.settle_phone(false), "fine", "a real SMS on the bus")
	eq(bus.earned(), start + 20, "the fare counts")
	check(r.paid and bus.asking.is_empty(), "paid, and the next one can be asked")
