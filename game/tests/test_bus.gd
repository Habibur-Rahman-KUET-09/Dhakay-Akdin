## Babu's bus trip (§৪.২, bus_day.gd).
extends "res://tests/check.gd"

const BusDay = preload("res://scripts/rules/bus_day.gd")
const Balance = preload("res://scripts/rules/balance.gd")


func _bus(seed_value := 1) -> BusDay:
	return BusDay.new(Balance.new(), seed_value)


## A rider waiting to pay `fare` with `note`.
func _rider(t: BusDay, fare: int, note: int, kind := "normal") -> int:
	t.riders.append({"id": 900, "from": 0, "to": 5, "fare": fare, "kind": kind, "note": note, "paid": false, "owed": 0})
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
	while not t.over and i < 20000:
		var e := t.update(0.05)
		got.append_array(e)
		if e.has(BusDay.Event.CALL_OPEN):
			t.call_t = 0.5 / 1.3
			t.call_stop()
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
	check(t.over and got.has(BusDay.Event.TRIP_OVER), "reached Motijheel")
	eq(t.stop_i, 8, "the last stop")
	check(t.boarded > 15, "many got on (%d)" % t.boarded)
	eq(t.slipped, 0, "nobody slipped off: every fare was taken")
	check(t.earned() > 200, "a good day's fares (%d)" % t.earned())
	check(t.riders.is_empty(), "everyone off")
