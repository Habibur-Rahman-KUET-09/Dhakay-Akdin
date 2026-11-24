## Babu's bus trip (§৪.২, bus_day.gd).
extends "res://tests/check.gd"

const BusDay = preload("res://scripts/rules/bus_day.gd")
const Balance = preload("res://scripts/rules/balance.gd")


func _bus(seed_value := 1) -> BusDay:
	return BusDay.new(Balance.new(), seed_value)


## A rider waiting to pay `fare` with `note`.
func _rider(t: BusDay, fare: int, note: int, kind := "normal") -> int:
	t.riders.append({"id": 900, "from": 0, "to": 5, "fare": fare, "kind": kind, "note": note, "paid": false, "owed": 0,
		"woman": false, "evader": false, "seat": 23})
	return 900


func test_fares_by_distance() -> void:
	var t := _bus()
	eq(t.route.size(), 9, "nine stops")
	eq(t.fare(0, 1), 10, "one stop: 10")
	eq(t.fare(0, 3), 20, "three stops: 20")
	eq(t.fare(0, 8), 35, "all the way: 35 at most")
	eq(t.bag_value(), 200, "200 taka of change to start")
	check(not t.riders.is_empty(), "people get on at Mirpur 10")


func test_right_change_settles() -> void:
	var t := _bus()
	t.ask(_rider(t, 20, 50))
	eq(t.change_due(), 30, "30 back from 50")
	var got := t.give({20: 1, 10: 1})
	eq(got, [BusDay.Event.SETTLED], "settled")
	eq(t.bag_value(), 200 + 20, "the bag is 20 up")
	eq(t.earned(), 20, "earned the fare")


func test_short_change_starts_an_argument() -> void:
	var t := _bus()
	t.ask(_rider(t, 20, 50))
	eq(t.give({20: 1}), [BusDay.Event.ARGUMENT], "20 is short of 30")
	near(t.rating, 4.5, "rating down")
	eq(t.bag_value(), 200, "nothing changed hands")
	eq(t.give({20: 1, 10: 1}), [], "held up while they argue")
	for i in 40:
		t.update(0.1)
	eq(t.give({20: 1, 10: 1}), [BusDay.Event.SETTLED], "then settled")


func test_too_much_change_is_babus_loss() -> void:
	var t := _bus()
	t.ask(_rider(t, 20, 50))
	eq(t.give({50: 1}), [BusDay.Event.OVERPAID], "50 back instead of 30")
	eq(t.overpaid, 20, "20 lost")
	eq(t.earned(), 0, "the fare went back out")


func test_no_change_owe_it_or_ask_round() -> void:
	var t := _bus()
	t.bag = {5: 0, 10: 0, 20: 0, 50: 0, 100: 1, 500: 0}
	t.bag_start = t.bag_value()
	t.ask(_rider(t, 20, 100))
	check(not t.can_make(t.change_due()), "no change for 80")
	eq(t.swap(), [BusDay.Event.SWAPPED], "ask round for change")
	check(t.can_make(80), "the 100 broken: now 80 can be made")
	for i in 40:
		t.update(0.1)
	eq(t.give(t.make_change(80)), [BusDay.Event.SETTLED], "settled after all")
	# Owing: settled now, paid at their stop.
	var u := _bus()
	u.bag = {5: 0, 10: 0, 20: 0, 50: 0, 100: 0, 500: 0}
	u.ask(_rider(u, 20, 50))
	eq(u.later(), [BusDay.Event.SETTLED], "owed")
	eq(u.riders.back().owed, 30, "30 owed")
	near(u.rating, 4.5, "they are not pleased")


func test_change_is_found_when_greedy_would_miss_it() -> void:
	var t := _bus()
	t.bag = {5: 0, 10: 0, 20: 3, 50: 1, 100: 0, 500: 0}
	var got := t.make_change(60)
	eq(got.get(20, 0), 3, "three 20s")
	check(not got.has(50), "not the 50")


func test_students_offer_half() -> void:
	var t := _bus()
	var id := _rider(t, 20, 10, "student")
	t.ask(id, false)
	eq(t.asking_fare, 10, "half fare taken")
	check(t.rating > 5.0 - 0.01, "they are pleased")
	var u := _bus()
	u.ask(_rider(u, 20, 10, "student"), true)
	eq(u.asking_fare, 20, "full fare asked")
	check(u.asking.note >= 20, "they pay with a big enough note")
	near(u.rating, 4.8, "grudgingly")


func test_calling_the_stop_brings_more() -> void:
	var t := _bus()
	t.dwell_left = 0.0
	t.update(0.01)
	check(not t.at_stop, "off from Mirpur 10")
	var opened := false
	while not opened:
		opened = t.update(0.05).has(BusDay.Event.CALL_OPEN)
	t.call_t = 0.5 / 1.3
	near(t.marker(), 0.5, "marker in the middle", 1e-4)
	t.call_stop()
	eq(t.last_call, "perfect", "a perfect call")
	eq(t.extra_boarders, 2, "two more")
	t.call_t = 0.0
	t.call_open = true
	t.call_stop()
	eq(t.last_call, "miss", "at the end of the bar: missed")


func test_a_whole_trip() -> void:
	var t := _bus(4)
	var got := []
	var i := 0
	while not t.over and i < 40000:
		var e := t.update(0.05)
		got.append_array(e)
		if e.has(BusDay.Event.CALL_OPEN):
			t.call_t = 0.5 / 1.3
			t.call_stop()
		# Catch anyone slipping out, and put seat problems right.
		while not t.at_door.is_empty():
			t.catch()
		for problem in t.problems():
			t.fix(problem)
		# Take every fare, with the right change when there is some.
		for r in t.unpaid():
			t.ask(r.id)
			var due := t.change_due()
			if due == 0:
				t.give({})
			elif t.can_make(due):
				t.give(t.make_change(due))
			else:
				t.later()
		i += 1
	check(t.over and got.has(BusDay.Event.DAY_OVER), "the day is done")
	eq(got.count(BusDay.Event.TRIP_OVER), 2, "two trips")
	eq(t.stop_id(t.stop_i), "mirpur10", "back at Mirpur 10")
	check(t.boarded > 15, "many got on (%d)" % t.boarded)
	eq(t.slipped, 0, "nobody slipped off: every fare was taken")
	check(t.earned() > 200, "a good day's fares (%d)" % t.earned())
	check(t.riders.is_empty(), "everyone off")


# --- Week 9: seats, crowding, slipping out, the checker, two trips, upgrades


## A rider for seat tests.
func _person(t: BusDay, id: int, kind: String, woman: bool, seat: int) -> Dictionary:
	var r := {"id": id, "from": 0, "to": 8, "fare": 35, "kind": kind, "note": 50, "paid": true, "owed": 0,
		"woman": woman, "evader": false, "seat": seat}
	t.riders.append(r)
	return r


func test_an_elder_standing_while_his_seat_is_taken() -> void:
	var t := _bus()
	t.riders.clear()
	var young := _person(t, 1, "normal", false, BusDay.ELDER_SEATS[0])
	_person(t, 2, "normal", false, BusDay.ELDER_SEATS[1])
	var old := _person(t, 3, "elder", false, BusDay.SEATS)
	eq(t.problems(), ["elder"], "an elder stands while others have the elder seats")
	t.update(10.0)
	check(t.rating < 5.0, "the passengers grumble")
	eq(t.fix("elder"), [BusDay.Event.SEATED], "Babu moves the young man")
	check(BusDay.ELDER_SEATS.has(old.seat), "the elder sits")
	eq(young.seat, BusDay.SEATS, "the young man stands")
	eq(t.problems(), [], "all right now")


func test_a_man_in_a_womens_seat() -> void:
	var t := _bus()
	t.riders.clear()
	_person(t, 1, "normal", false, BusDay.WOMEN_SEATS[0])
	var woman := _person(t, 2, "normal", true, BusDay.SEATS + 1)
	eq(t.problems(), ["women"], "a woman stands while a man has her seat")
	t.fix("women")
	eq(woman.seat, BusDay.WOMEN_SEATS[0], "she sits")


func test_seats_are_given_out_sensibly() -> void:
	var t := _bus()
	t.riders.clear()
	var elder := {"kind": "elder", "woman": false}
	check(BusDay.ELDER_SEATS.has(t._place_for(elder)), "an elder to the elder seats")
	var woman := {"kind": "normal", "woman": true}
	check(BusDay.WOMEN_SEATS.has(t._place_for(woman)), "a woman to the women's seats")
	var man := {"kind": "normal", "woman": false}
	var seat := t._place_for(man)
	check(not BusDay.WOMEN_SEATS.has(seat) and not BusDay.ELDER_SEATS.has(seat), "a man to an ordinary seat")


func test_crowding_costs_rating() -> void:
	var t := _bus()
	t.riders.clear()
	for i in 32:
		_person(t, 100 + i, "normal", false, i if i < 24 else -1)
	t.update(10.0)
	check(t.rating < 5.0, "over 30 aboard: grumbling")


func test_slipping_out_at_the_door() -> void:
	var t := _bus()
	t.riders.clear()
	t.riders.append({"id": 1, "from": 0, "to": 1, "fare": 10, "kind": "normal", "note": 20, "paid": false, "owed": 0,
		"woman": false, "evader": true, "seat": 5})
	eq(t.unpaid(), [], "keeps out of Babu's way")
	t.at_stop = false
	t.travel_left = 0.01
	t.called = true
	var got := t.update(0.05)
	check(got.has(BusDay.Event.AT_DOOR), "makes for the door")
	var before := t.bag_value()
	check(t.catch().has(BusDay.Event.CAUGHT), "caught")
	eq(t.bag_value(), before + 10, "paid 10")
	# And one who gets away.
	var u := _bus()
	u.riders.clear()
	u.riders.append({"id": 1, "from": 0, "to": 1, "fare": 10, "kind": "normal", "note": 20, "paid": false, "owed": 0,
		"woman": false, "evader": true, "seat": 5})
	u.at_stop = false
	u.travel_left = 0.01
	u.called = true
	u.update(0.05)
	for i in 60:
		u.update(0.05)
	eq(u.slipped, 1, "got away")


func test_the_notebook_shows_who_has_not_paid() -> void:
	var t := BusDay.new(Balance.new(), 1, ["notebook"])
	t.riders.clear()
	t.riders.append({"id": 1, "from": 0, "to": 3, "fare": 15, "kind": "normal", "note": 20, "paid": false, "owed": 0,
		"woman": false, "evader": true, "seat": 5})
	eq(t.unpaid().size(), 1, "noted down: can be asked")


func test_the_checker_fines_fares_not_taken() -> void:
	var t := _bus()
	t.riders.clear()
	_person(t, 1, "normal", false, 8).paid = false
	_person(t, 2, "normal", false, 9)
	t.checker_at = 1
	t.at_stop = false
	t.travel_left = 0.01
	t.called = true
	var got := t.update(0.05)
	check(got.has(BusDay.Event.CHECKER), "the checker gets on")
	eq(t.last_fine, 20, "20 for the one who has not paid")
	eq(t.earned(), -20, "out of the day's money")


func test_upgrades_bag_and_voice() -> void:
	var t := BusDay.new(Balance.new(), 1, ["change_bag", "loud_voice"])
	eq(t.bag_value(), 400, "a bigger bag: 400 of change")
	near(t.perfect_zone(), 0.12, "a louder voice: a wider perfect call", 1e-6)


func test_asking_someone_to_stand_for_a_mother() -> void:
	var t := _bus()
	t.riders.clear()
	_person(t, 1, "elder", false, BusDay.ELDER_SEATS[0])
	_person(t, 2, "elder", false, BusDay.ELDER_SEATS[1])
	var tired := _person(t, 3, "normal", false, 10)
	tired["trait"] = "tired"
	var phone := _person(t, 4, "normal", false, 11)
	phone["trait"] = "phone"
	var mother := _person(t, 5, "needy", true, BusDay.SEATS)
	mother["need"] = "mother"
	eq(t.problems(), ["need"], "a mother stands, the front seats rightly taken")
	eq(t.seat_candidates().size(), 2, "two who could stand")
	var before := t.rating
	eq(t.give_seat(4), [BusDay.Event.SEATED], "the young man on his phone gets up")
	eq(mother.seat, 11, "she sits")
	check(t.rating > before, "everyone is pleased")
	eq(t.problems(), [], "all right now")
	var sick := _person(t, 6, "needy", false, BusDay.SEATS + 1)
	sick["need"] = "sick"
	eq(t.give_seat(3), [BusDay.Event.SEATED, BusDay.Event.ARGUMENT], "the tired man is cross")
	eq(sick.seat, 10, "but gives up his seat")
	eq(t.last_seat, "tired", "")


func test_the_needy_go_to_the_front_seats_first() -> void:
	var t := _bus()
	t.riders.clear()
	check(BusDay.ELDER_SEATS.has(t._place_for({"kind": "needy", "woman": false})), "an ill man to the front")
	var young := _person(t, 1, "normal", false, BusDay.ELDER_SEATS[0])
	_person(t, 2, "elder", false, BusDay.ELDER_SEATS[1])
	_person(t, 3, "needy", false, BusDay.SEATS)
	eq(t.problems(), ["elder"], "a young man in a front seat while someone ill stands")
	t.fix("elder")
	eq(young.seat, BusDay.SEATS, "he stands")
