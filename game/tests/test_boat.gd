## Haripada Majhi's ferry across the Buriganga (river_day.gd).
extends "res://tests/check.gd"

const RiverDay = preload("res://scripts/rules/river_day.gd")
const Balance = preload("res://scripts/rules/balance.gd")

var b := Balance.new()


## A day with some aboard, pushed off, no launches about.
func _afloat(owned: Array = []) -> RiverDay:
	var r := RiverDay.new(b, 3, owned)
	r._next_launch = 9999.0
	for i in 40:
		r.update(0.25)
		if r.aboard.size() >= 3:
			break
	r.cast_off()
	return r


func test_people_board_and_some_give_up() -> void:
	var r := RiverDay.new(b, 3)
	r._next_launch = 9999.0
	var events := []
	for i in 400:
		events.append_array(r.update(0.25))
	check(events.has(RiverDay.Event.BOARDED), "people step aboard")
	check(r.aboard.size() <= r.capacity, "no more than the boat holds")
	check(events.has(RiverDay.Event.LEFT), "a long wait: someone gives up")
	check(r.gave_up > 0, "counted")
	eq(RiverDay.new(b, 3, ["big_boat"]).capacity, int(b.n("boat.upgrades.big_boat.capacity")), "a bigger boat")


func test_pushing_off_needs_someone_aboard() -> void:
	var r := RiverDay.new(b, 3)
	eq(r.cast_off(), [], "nobody aboard yet")
	eq(r.stroke(1), [], "no rowing while tied up")
	r = _afloat()
	check(not r.docked, "off")
	eq(r.heading(), 1, "towards Jinjira")


func test_rowing_one_oar_then_the_other() -> void:
	var r := _afloat()
	r.stroke(-1)
	eq(r.last_stroke, "good", "first stroke")
	r.update(0.5)
	r.stroke(1)
	eq(r.last_stroke, "good", "the other oar")
	var x := r.vel.x
	r.update(0.5)
	r.stroke(1)
	eq(r.last_stroke, "same", "the same oar again")
	r.stroke(-1)
	eq(r.last_stroke, "rushed", "too quick")
	check(r.vel.x > 0.0 and x > 0.0, "moving across")


func test_the_right_oar_turns_him_left() -> void:
	# Going to Jinjira, downstream (+y) is on his right.
	var r := _afloat()
	r.stroke(1)
	check(r.vel.y < 0.0, "right oar: upstream, to his left")
	var k := _afloat()
	k.stroke(-1)
	check(k.vel.y > 0.0, "left oar: downstream")


func test_the_current_carries_him_down() -> void:
	var r := _afloat()
	for i in 20:
		r.update(0.5)
	check(r.pos.y > 3.0, "drifted downstream")


func test_a_crossing_and_the_fares() -> void:
	var r := _afloat()
	var n := r.aboard.size()
	var fares := 0
	for p in r.aboard:
		fares += int(p.fare)
	var events := []
	for i in 400:
		# Keep straight: the right oar when carried down.
		r.stroke(1 if r.pos.y > 2.0 or r.last_hand == -1 else -1)
		events.append_array(r.update(0.5))
		if events.has(RiverDay.Event.ARRIVED):
			break
	check(events.has(RiverDay.Event.ARRIVED), "landed at Jinjira")
	eq(r.side, 1, "on the far side")
	check(r.docked and r.aboard.is_empty(), "everyone off")
	eq(r.last_trip.n, n, "carried")
	eq(r.last_trip.fares, fares, "the fares")
	eq(r.money, fares + int(r.last_trip.tip), "paid")
	eq(r.carried, n, "counted")
	eq(r.heading(), -1, "next time back")


func test_missing_the_ghat_and_poling_back() -> void:
	var r := _afloat()
	r.pos = Vector2(r.width - 1.0, 30.0)
	r.vel = Vector2(3.0, 0.0)
	var events := r.update(0.5)
	check(events.has(RiverDay.Event.OFF_GHAT), "at the bank, below the ghat")
	check(r.at_bank, "poling now")
	r.stroke(-1)
	check(r.vel.y < 0.0, "either oar takes him up to the ghat")
	for i in 200:
		r.stroke(1 if i % 2 == 0 else -1)
		events.append_array(r.update(0.5))
		if events.has(RiverDay.Event.ARRIVED):
			break
	check(events.has(RiverDay.Event.ARRIVED), "got there in the end")


func test_launches_horn_wake_and_bump() -> void:
	var r := _afloat()
	r.pos = Vector2(60.0, 0.0)
	r.launches = [{"id": 99, "x": 60.0, "y": -40.0, "dir": 1, "speed": 5.0, "half_len": 15.0, "half_w": 3.5, "horned": false, "waked": false}]
	var events := []
	for i in 30:
		events.append_array(r.update(0.25))
	check(events.has(RiverDay.Event.HORN), "the horn first")
	check(events.has(RiverDay.Event.BUMP), "then a bump")
	eq(r.bumps, 1, "once")
	var k := _afloat()
	k.pos = Vector2(40.0, 0.0)
	k.launches = [{"id": 98, "x": 60.0, "y": -40.0, "dir": 1, "speed": 5.0, "half_len": 15.0, "half_w": 3.5, "horned": false, "waked": false}]
	events = []
	for i in 30:
		events.append_array(k.update(0.25))
	check(events.has(RiverDay.Event.WAKE), "passing close: the wake")
	eq(k.bumps, 0, "no bump")


func test_the_day_ends_at_a_ghat() -> void:
	var r := _afloat()
	r.clock = r.day_seconds
	eq(r.update(0.1), [], "a crossing under way is finished first")
	r.clock = r.day_seconds + 60.0
	check(r.update(0.1).has(RiverDay.Event.DAY_OVER), "but not forever")
	var k := RiverDay.new(b, 3)
	k.clock = k.day_seconds
	check(k.update(0.1).has(RiverDay.Event.DAY_OVER), "tied up: done")
	eq(k.stars(), 1.0, "no crossings, the lowest rating")
