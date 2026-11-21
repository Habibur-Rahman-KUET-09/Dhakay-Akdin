## The map, driving and shift rules (§৪.১).
extends "res://tests/check.gd"

const RoadMap = preload("res://scripts/rules/road_map.gd")
const Driver = preload("res://scripts/rules/driver.gd")
const Shift = preload("res://scripts/rules/shift.gd")

## A small map: a two-way loop, a one-way lane going east, a dead end.
##   0123456
## 0 #######
## 1 #H....#
## 2 #.##.##
## 3 #.eee.#
## 4 #.##..#
## 5 #######
const SMALL := ["#######", "#H....#", "#.##.##", "#.eee.#", "#.##..#", "#######"]


func small() -> RoadMap:
	return RoadMap.parse("small", PackedStringArray(SMALL))


func p(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)


## Runs the driver until it enters n tiles or stops.
func drive(d: Driver, n: int) -> Array:
	var all := []
	var entered := 0
	var i := 0
	while i < 1000 and entered < n and d.moving:
		var e := d.update(0.1)
		entered += e.count(Driver.Event.ENTERED)
		all.append_array(e)
		i += 1
	return all


func test_tiles_home_and_one_way_rules() -> void:
	var m := small()
	eq(m.home, p(1, 1), "home")
	eq(m.one_way(p(2, 3)), RoadMap.E, "lane direction")
	eq(m.move(p(1, 3), RoadMap.E), RoadMap.Move.OK, "into the lane its way")
	eq(m.move(p(5, 3), RoadMap.W), RoadMap.Move.WRONG_WAY, "into the lane against it")
	eq(m.move(p(3, 3), RoadMap.W), RoadMap.Move.WRONG_WAY, "back along the lane")
	eq(m.move(p(4, 2), RoadMap.S), RoadMap.Move.OK, "crossing the lane")
	eq(m.move(p(1, 1), RoadMap.N), RoadMap.Move.BLOCKED, "into a building")
	check(not m.is_road(p(-1, 0)), "outside the map is not road")


func test_routes_are_shortest_and_legal() -> void:
	var m := small()
	eq(m.distance(p(1, 3), p(5, 3)), 4, "through the lane")
	eq(m.distance(p(5, 3), p(1, 3)), 10, "round the loop, not back through the lane")
	eq(m.route(p(1, 1), p(1, 1)), [], "already there")
	eq(m.distance(p(1, 1), p(5, 4)), 7, "")
	eq(m.distances_from(p(1, 1)).size(), m.roads().size(), "every road reachable from home")


func test_bad_maps_are_refused() -> void:
	check(RoadMap.parse("x", PackedStringArray(["###", "#.#", "###"])) == null, "no home")
	check(RoadMap.parse("x", PackedStringArray(["###", "#H", "###"])) == null, "ragged rows")
	check(RoadMap.parse("x", PackedStringArray(["###", "#H?", "###"])) == null, "unknown tile")
	var bad_place := [{"id": "x", "names": {"en": "X"}, "at": p(0, 0)}]
	check(RoadMap.parse("x", PackedStringArray(["###", "#H#", "###"]), bad_place) == null, "place off the road")


func test_main_roads_and_roundabouts() -> void:
	var m: RoadMap = RoadMap.parse("ring", PackedStringArray(["#####", "#HMM#", "#MOM#", "#MMM#", "#####"]))
	check(not m.is_road(p(2, 2)), "the island is not road")
	eq(m.kind_at(p(2, 1)), RoadMap.Kind.MAIN_ROAD, "main road")
	eq(m.distance(p(1, 1), p(3, 3)), 4, "round the island")


func test_mirpur_every_road_reaches_every_other() -> void:
	var m: RoadMap = RoadMap.load_area("mirpur")
	check(m != null, "loads")
	if m == null:
		return
	var roads := m.roads()
	check(roads.size() > 500, "a real town's worth of roads")
	eq(m.distances_from(m.home).size(), roads.size(), "every road reachable from home")
	# And home reachable from every road: a search backwards from home.
	var seen := {m.home: true}
	var queue: Array[Vector2i] = [m.home]
	var i := 0
	while i < queue.size():
		var c := queue[i]
		i += 1
		for d in 4:
			var n := RoadMap.step(c, d)
			if m.is_road(n) and not seen.has(n) and m.move(n, RoadMap.opposite(d)) == RoadMap.Move.OK:
				seen[n] = true
				queue.append(n)
	eq(seen.size(), roads.size(), "home reachable from every road")
	check(m.credit.contains("OpenStreetMap"), "credits OpenStreetMap")
	check(m.places.size() >= 10, "real places")
	var tiles := {}
	for pl in m.places:
		tiles[pl.at] = true
	eq(tiles.size(), m.places.size(), "one place per tile")
	var one_way := roads.filter(func(r): return m.one_way(r) >= 0)
	check(not one_way.is_empty(), "some one-way lanes")


func test_follows_the_road_and_stops_at_a_dead_end() -> void:
	var d := Driver.new(small(), 2.0, p(1, 1), RoadMap.E)
	var e := drive(d, 10)
	eq([d.cell, d.heading, d.moving], [p(5, 1), RoadMap.E, false], "at the dead end")
	eq(e.count(Driver.Event.ENTERED), 4, "tiles entered")
	eq(e.back(), Driver.Event.WAITING, "waiting")


func test_follows_a_bend_with_one_way_on() -> void:
	var d := Driver.new(small(), 2.0, p(4, 4), RoadMap.E)
	drive(d, 2)
	eq([d.cell, d.heading], [p(5, 3), RoadMap.N], "round the bend")


func test_a_turn_is_used_at_the_next_junction_that_has_it() -> void:
	var d := Driver.new(small(), 2.0, p(1, 1), RoadMap.E)
	d.swipe(Driver.RIGHT)
	drive(d, 1)
	eq(d.queued, Driver.RIGHT, "no road right at (2,1): kept for later")
	drive(d, 2)
	eq([d.cell, d.heading], [p(4, 1), RoadMap.S], "turned right at (4,1)")
	eq(d.queued, -1, "used up")


func test_swiping_back_turns_round_at_once_mid_tile() -> void:
	var d := Driver.new(small(), 2.0, p(1, 1), RoadMap.E)
	d.update(0.25)
	eq(d.swipe(Driver.BACK), [Driver.Event.U_TURN], "events")
	eq([d.cell, d.heading], [p(2, 1), RoadMap.W], "turned round")
	near(d.progress, 0.5, "progress")
	near(d.position().x, 1.5, "same place on screen")


func test_a_t_junction_waits_and_a_swipe_gets_it_going() -> void:
	var d := Driver.new(small(), 2.0, p(4, 3), RoadMap.N)
	var e := drive(d, 2)
	eq(d.cell, p(4, 1), "at the junction")
	eq(e.back(), Driver.Event.WAITING, "left or right?")
	check(not d.moving, "stopped")
	d.swipe(Driver.RIGHT)
	eq([d.moving, d.heading], [true, RoadMap.E], "going right")


func test_going_the_wrong_way_is_allowed_but_reported() -> void:
	var d := Driver.new(small(), 2.0, p(5, 4), RoadMap.N)
	d.swipe(Driver.LEFT)
	var e := drive(d, 1)
	check(e.has(Driver.Event.WRONG_WAY), "reported")
	eq([d.cell, d.heading], [p(5, 3), RoadMap.W], "into the lane")


func test_it_never_goes_the_wrong_way_by_itself() -> void:
	var d := Driver.new(small(), 2.0, p(5, 4), RoadMap.N)
	var e := drive(d, 1)
	check(not e.has(Driver.Event.WRONG_WAY), "no wrong way")
	eq([d.cell, d.moving], [p(5, 3), false], "waits: west is the lane")


func test_destinations_are_real_places_far_enough() -> void:
	var m: RoadMap = RoadMap.load_area("mirpur")
	for seed_value in 20:
		var s := Shift.new(m, 2.0, 0.5, 8, seed_value)
		check(not s.place.is_empty(), "a place")
		eq(s.destination, s.place.get("at"), "at the place")
		check(s.remaining >= 8, "far enough (%d)" % s.remaining)


func test_reaching_the_destination_counts_and_picks_another() -> void:
	var s := Shift.new(small(), 2.0, 0.5, 3, 1)
	s.pedal = true
	s.accel = 10.0
	var events := []
	var i := 0
	# Drive the legal route, swiping each turn a tile ahead as a player would.
	while i < 400 and s.delivered == 0:
		var path = s.map.route(s.driver.cell, s.destination)
		var h := s.driver.heading
		var first := _dir(s.driver.cell, path[0])
		if first != h:
			s.swipe((first - h + 4) % 4)
		elif path.size() > 1:
			s.swipe((_dir(path[0], path[1]) - h + 4) % 4)
		events.append_array(s.update(0.05))
		i += 1
	eq(s.delivered, 1, "delivered")
	check(events.has(Driver.Event.ARRIVED), "arrived event")
	check(not events.has(Driver.Event.WRONG_WAY), "never the wrong way")
	check(s.destination != s.driver.cell, "a new destination")


func test_a_waterlogged_road_halves_the_speed() -> void:
	var m: RoadMap = RoadMap.parse("wet", PackedStringArray(["######", "#HW..#", "######"]))
	var s := Shift.new(m, 2.0, 0.5, 1, 1)
	s.pedal = true
	s.accel = 100.0
	s.update(0.05)
	near(s.driver.speed, 1.0, "top speed on the water is half")


func test_pedal_brake_and_coast() -> void:
	var s := Shift.new(small(), 1.0, 0.5, 3, 1)
	s.update(0.5)
	near(s.speed_now, 0.0, "no pedalling, no moving")
	eq(s.driver.cell, small().home, "still at home")
	s.pedal = true
	for i in 10:
		s.update(0.1)
	near(s.speed_now, minf(1.0, s.accel * 1.0), "gathers speed", 1e-3)
	s.accel = 100.0
	s.update(0.1)
	near(s.speed_now, 1.0, "never above the top speed")
	s.pedal = false
	s.update(1.0)
	near(s.speed_now, 1.0 - s.coast, "rolls on, slowing", 1e-3)
	s.brake = true
	s.update(1.0)
	near(s.speed_now, 0.0, "the brake stops it")


func _dir(a: Vector2i, b: Vector2i) -> int:
	for d in 4:
		if RoadMap.step(a, d) == b:
			return d
	return -1


func test_traffic_ahead_holds_the_rickshaw_back() -> void:
	var s := Shift.new(small(), 1.0, 0.5, 3, 1)
	s.pedal = true
	s.accel = 100.0
	s.room = 0.0
	s.update(0.1)
	near(s.speed_now, 0.0, "blocked: no speed")
	s.room = 0.5
	s.update(0.1)
	near(s.speed_now, 0.5, "half the road free: half speed")


# --- The day with passengers (day.gd, fares.gd) --------------------------

const Day = preload("res://scripts/rules/day.gd")
const Fares = preload("res://scripts/rules/fares.gd")
const Balance = preload("res://scripts/rules/balance.gd")


func test_fares_and_ratings() -> void:
	var f := Fares.new(Balance.new())
	eq(f.fair(30), 65, "20 + 30 x 1.5 = 65")
	eq(f.fair(0), 20, "the base fare")
	eq(f.counter(65), 80, "1.2 x 65 = 78, rounded to 80")
	eq(f.stars(10.0, 10.0, 0, "normal"), 5.0, "on time")
	eq(f.stars(11.5, 10.0, 0, "normal"), 4.0, "15% late: one star off")
	eq(f.stars(12.5, 10.0, 0, "normal"), 3.0, "25% late: two off")
	eq(f.stars(10.0, 10.0, 2, "normal"), 4.0, "two flooded tiles: one off")
	eq(f.stars(30.0, 10.0, 0, "normal"), 1.0, "never below one")
	eq(f.stars(11.5, 10.0, 0, "elder"), 4.5, "elders give half a star more")
	eq(f.tip(5.0), 10, "a tip for five stars")
	eq(f.tip(4.5), 0, "none below")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 50:
		var t := f.pick_type(rng)
		check(Fares.TYPES.has(t), "a known type")
		var o := f.offer(t, 65, rng)
		check(o % 5 == 0 and o >= 35 and o <= 75, "offer %d in range for %s" % [o, t])


func _mirpur() -> RoadMap:
	return RoadMap.load_area("mirpur")


func test_the_day_keeps_passengers_waiting() -> void:
	var d := Day.new(_mirpur(), Balance.new(), 3)
	check(d.waiting.size() >= 3 and d.waiting.size() <= 5, "3 to 5 waiting (%d)" % d.waiting.size())
	for w in d.waiting:
		check(d.map.is_road(w.at), "waiting on a road")
		check(w.tiles >= 8, "a real trip")
		eq(d.map.distance(w.at, w.place.at), w.tiles, "fare distance is the legal route")
	check(d.riding.is_empty(), "nobody aboard yet")
	check(d.waiting.any(func(w): return w.at == d.destination), "the arrow points at a passenger")


func test_bargain_ride_and_get_paid() -> void:
	var d := Day.new(_mirpur(), Balance.new(), 5)
	var w: Dictionary = d.waiting[0]
	# Pull up beside the passenger.
	d.driver.cell = w.at
	d.driver.progress = 0.0
	var events := d.update(0.01)
	check(events.has(Day.OFFER), "stopping beside them opens the bargaining")
	eq(d.offer_for, w, "talking to them")
	d.accept()
	eq(d.riding.fare, w.offer, "rides at the offered fare")
	eq(d.destination, w.place.at, "the arrow points at the drop-off")
	# Drive the route, swiping each turn a tile ahead.
	d.pedal = true
	d.accel = 100.0
	var got := []
	var i := 0
	while i < 6000 and d.trips == 0:
		var path = d.map.route(d.driver.cell, d.destination)
		if path == null or path.is_empty():
			break
		var h := d.driver.heading
		var first := _dir(d.driver.cell, path[0])
		if first != h:
			d.swipe((first - h + 4) % 4)
		elif path.size() > 1:
			d.swipe((_dir(path[0], path[1]) - h + 4) % 4)
		got.append_array(d.update(0.05))
		i += 1
	eq(d.trips, 1, "delivered")
	check(got.has(Day.DELIVERED), "delivered event")
	check(d.money + d.fines >= w.offer, "paid at least the fare (%d, fines %d)" % [d.money, d.fines])
	check(d.riding.is_empty(), "the passenger got off")


func test_counter_offer_and_refusal() -> void:
	var d := Day.new(_mirpur(), Balance.new(), 9)
	var w: Dictionary = d.waiting[0]
	d.driver.cell = w.at
	d.update(0.01)
	d.refuse()
	check(d.offer_for.is_empty() and w.refused, "said no: they stay, refused")
	check(d.waiting.has(w), "still waiting")
	d.update(0.01)
	check(d.offer_for.is_empty(), "not asked again while still beside them")
	var agreed := 0
	for seed_value in 20:
		var e := Day.new(_mirpur(), Balance.new(), 100 + seed_value)
		var p: Dictionary = e.waiting[0]
		e.driver.cell = p.at
		e.update(0.01)
		if e.counter():
			agreed += 1
			eq(e.riding.fare, e.fares.counter(p.fair), "rides at the counter fare")
		else:
			check(not e.waiting.has(p), "said no to the counter: walked off")
	check(agreed > 0 and agreed < 20, "some agree, some walk off (%d of 20)" % agreed)


func test_the_day_ends_and_red_lights_fine() -> void:
	var d := Day.new(_mirpur(), Balance.new(), 2)
	eq(d.hour(), 7.0, "7 in the morning")
	var events := d.update(d.day_seconds / 2.0)
	near(d.hour(), 14.0, "half way: 2 pm")
	events = d.update(d.day_seconds)
	check(events.has(Day.DAY_OVER) and d.over, "the day is over")
	eq(d.update(1.0), [], "nothing happens after")
	# A red light at a signal tile, for one road through it.
	var p := Vector2i(-1, -1)
	for r in d.map.roads():
		if d.map.kind_at(r) == RoadMap.Kind.SIGNAL:
			p = r
			break
	check(p.x >= 0, "the map has a signal")
	var e := Day.new(_mirpur(), Balance.new(), 2)
	check(e.red_at(p, RoadMap.N) != e.red_at(p, RoadMap.E), "one road red, the other green")
	var red := RoadMap.N if e.red_at(p, RoadMap.N) else RoadMap.E
	e.driver.cell = RoadMap.step(p, RoadMap.opposite(red))
	e.driver.heading = red
	e.driver.moving = true
	e.driver.progress = 0.99
	e.speed_now = 1.0
	e.pedal = true
	var before := e.money
	var got := e.update(0.05)
	if e.driver.cell == p:
		check(got.has(Day.FINED), "fined for running the red")
		eq(e.money, before - 50, "50 taka")
