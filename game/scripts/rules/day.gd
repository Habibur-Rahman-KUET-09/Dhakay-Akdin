## Rahim Chacha's working day (§৪.১): 7 am to 9 pm in a few minutes,
## passengers waiting by the road with an offer, bargaining, the trip, the
## rating and the tip, fines for running a red light. His energy, which
## every tile costs and tea at a stall brings back; the police, who stop
## him for going the wrong way up a one-way lane; and a sudden shower that
## floods the roads (§৪.১ বাধা, এনার্জি). Driving itself is the shift's
## (shift.gd). No drawing here, so it can be tested.
extends "res://scripts/rules/shift.gd"

const Fares = preload("res://scripts/rules/fares.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Signals = preload("res://scripts/rules/signals.gd")
const Calendar = preload("res://scripts/rules/calendar.gd")
const Hands = preload("res://scripts/rules/activities.gd")

## Events added to the driver's (which run 0-4).
const OFFER := 10
const OFFER_GONE := 11
const BOARDED := 12
const DECLINED := 13
const DELIVERED := 14
const FINED := 15
const DAY_OVER := 16
## Stopped by the police: a fine, and standing still for a while.
const POLICE := 17
## Stopped beside a tea stall (tea on offer), and driven off again.
const TEA_NEAR := 18
const TEA_GONE := 19
const RAIN_START := 20
const RAIN_END := 21
## Energy fell low: slower until he has tea.
const TIRED := 22
## Energy gone: he goes home (DAY_OVER comes too).
const WORN_OUT := 23
## A tyre gone soft (slower until pumped).
const FLAT := 24
## Stuck in deep water in the rain (push to get out), and out again.
const STUCK := 25
const FREED := 26

var fares: Fares
var balance: Balance
## Passengers waiting by the road: {at, place, type, tiles, fair, offer, refused}.
var waiting: Array = []
## The passenger aboard: {place, at, type, fare, since, eta, flooded}; or {}.
var riding := {}
## The waiting passenger Rahim Chacha has stopped beside; or {}.
var offer_for := {}
## The last finished trip, for the HUD: {fare, tip, stars}.
var last_trip := {}
var money := 0
var trips := 0
var stars_sum := 0.0
var fines := 0
## Seconds since 7 am, and the length of the day.
var clock := 0.0
var day_seconds := 240.0
var over := false
var signal_cycle := 12.0
var _want_waiting := 4
var _next_id := 1

## Energy: 100 at the start of the day, less every tile (more in rain);
## low, the rickshaw is slower; gone, the day is over. The battery
## rickshaw halves the cost (energy_factor, set by the scene).
var energy := 100.0
var energy_max := 100.0
var energy_factor := 1.0
var worn_out := false
var _was_tired := false
## Tea: on offer when stopped beside a stall.
var at_tea := false
var teas := 0
var tea_spent := 0
var _tea_tiles: Array = []
## The hand activities (scripts/ui/activities/), on when the scene says
## so; the plain rule tests leave them off. A passenger's most they will
## pay ("limit", hidden; their face shows how near it the asking is). A
## soft tyre now and then after a trip; deep water in the rain to push
## through; the bell clearing the way (rung twice, wider, but a passenger
## aboard tires of it). Their own dice, so the rest plays the same.
var interactive := false
var flat := false
var stuck := false
var repairs := 0
var clear_left := 0.0
var _push := 0.0
var _last_hand := -1
var _pushed_at := Vector2i(-1, -1)
var _last_ring := -10.0
var _hand_rng := RandomNumberGenerator.new()
## The police: seconds still held, and what they have fined today.
var held := 0.0
var police_fines := 0
var _police_rest := 0.0
## Weather: the day's one shower (if any), from `rain_at` for
## `rain_seconds` of the clock. Its own dice, so the rest of the day plays
## the same with or without it.
var raining := false
var rain_at := -1.0
var rain_seconds := 60.0
var weather := RandomNumberGenerator.new()
## The month's weather and the date's festival (when the scene gives the
## date): rain likelier in the monsoon, fog on winter mornings, and on a
## festival day an extra tip every ride.
var foggy := false
var festival := {}
## Trips rated 4 stars or more (for the day's challenge).
var good_trips := 0
## The named neighbours who may need a ride today (set by the scene), how
## they feel (id -> -5..5), and what happened with them: [{id, delta, what}].
var npc_pool: Array = []
var relations := {}
var npc_log: Array = []
## Where the time goes, from one drop-off to the next (for the log, and to
## tune the day): seconds finding the next passenger and riding with them,
## and of all that, how long standing at a junction waiting for a swipe,
## held up by traffic or a red light, held (police, deep water), or just
## standing (bargaining, no pedal); tiles that took it further away
## ("detours"). Each finished trip's goes into `trip_times`.
var trip_time := {}
var trip_times: Array = []
var _last_remaining := -1
var _last_dest := Vector2i(-1, -1)


## `trip`: the shortest ride, in tiles (shorter in the first days).
func _init(road_map: RoadMap, b: Balance, seed_value := -1, date := "", trip := 8) -> void:
	balance = b
	if seed_value >= 0:
		_hand_rng.seed = seed_value + 13
	else:
		_hand_rng.randomize()
	fares = Fares.new(b)
	_new_trip_time()
	super(road_map, b.n("rickshaw.speed_tiles_per_s"), b.n("rickshaw.waterlog_speed"), trip, seed_value)
	accel = b.n("rickshaw.accel_tiles_per_s2")
	coast = b.n("rickshaw.coast_decel")
	braking = b.n("rickshaw.brake_decel")
	day_seconds = b.n("rickshaw.day_seconds")
	signal_cycle = b.n("rickshaw.signal_cycle_s")
	var range_of: Array = b.at("rickshaw.waiting_passengers")
	_want_waiting = rng.randi_range(int(range_of[0]), int(range_of[1]))
	_top_up()
	_aim()
	energy_max = b.n("rickshaw.energy_start")
	energy = energy_max
	_tea_tiles = map.roads().filter(func(p): return map.kind_at(p) == RoadMap.Kind.TEA)
	rain_seconds = b.n("rickshaw.rain_seconds")
	if seed_value >= 0:
		weather.seed = seed_value + 7
	else:
		weather.randomize()
	var chance := b.n("rickshaw.rain_chance_per_day")
	var calendar := Calendar.new()
	if date != "":
		chance = calendar.rain_chance(chance, date)
		festival = calendar.festival(date)
	if weather.randf() < chance:
		rain_at = weather.randf_range(0.15, 0.75) * day_seconds
	if date != "":
		foggy = weather.randf() < calendar.fog_chance(date)


## How thick the morning fog is, 1 at dawn thinning to 0 by mid-morning.
func fog() -> float:
	if not foggy:
		return 0.0
	return clampf(1.0 - clock / (0.3 * day_seconds), 0.0, 1.0)


## The hour of the day, 7.0 to 21.0.
func hour() -> float:
	return lerpf(balance.n("rickshaw.start_hour"), balance.n("rickshaw.end_hour"), clampf(clock / day_seconds, 0.0, 1.0))


func average_stars() -> float:
	return stars_sum / trips if trips > 0 else 0.0


func update(dt: float) -> Array:
	if over:
		return []
	clock += dt
	var early := []
	_weather(early)
	_police_rest = maxf(0.0, _police_rest - dt)
	speed_factor = balance.n("rickshaw.tired_speed") if energy < balance.n("rickshaw.tired_below") else 1.0
	if flat:
		speed_factor *= balance.n("rickshaw.flat_speed")
	# The bell rung: people step aside for a moment.
	if clear_left > 0.0:
		clear_left -= dt
		room = maxf(room, 0.75)
	if stuck:
		speed_factor = 0.0
		speed_now = 0.0
	# Held by the police: standing still, whatever the pedal says.
	if held > 0.0:
		held -= dt
		speed_factor = 0.0
		speed_now = 0.0
	var events := super(dt)
	events.append_array(early)
	_time(dt)
	if events.has(Driver.Event.WRONG_WAY):
		_police(events)
	_talk(events)
	_tea(events)
	if clock >= day_seconds or worn_out:
		over = true
		events.append(DAY_OVER)
	return events


func swipe(t: int) -> Array:
	var events := super(t)
	if events.has(Driver.Event.WRONG_WAY):
		_police(events)
	return events


## A shower now, for testing (and for a forecast, one day).
func start_rain() -> void:
	rain_at = clock


func _weather(events: Array) -> void:
	if rain_at < 0.0:
		return
	var now := clock >= rain_at and clock < rain_at + rain_seconds
	if now != raining:
		raining = now
		events.append(RAIN_START if now else RAIN_END)


## Is p under water? Flooded tiles always; in rain, the tiles next to them
## too (the water spreads).
func wet(p: Vector2i) -> bool:
	if map.kind_at(p) == RoadMap.Kind.FLOOD:
		return true
	if not raining:
		return false
	for d in 4:
		if map.kind_at(RoadMap.step(p, d)) == RoadMap.Kind.FLOOD:
			return true
	return false


func on_flood() -> bool:
	return wet(driver.cell) or (driver.moving and wet(driver.next_cell()))


## Up a one-way lane the wrong way: the police stop him, fine him and keep
## him standing. Not again straight away for the same stretch.
func _police(events: Array) -> void:
	if _police_rest > 0.0:
		return
	var fine := int(balance.n("rickshaw.wrong_way_fine"))
	money -= fine
	fines += fine
	police_fines += fine
	held = balance.n("rickshaw.wrong_way_stop_s")
	_police_rest = held + 15.0
	speed_now = 0.0
	events.append(POLICE)


## Stopped next to a tea stall, not bargaining, and not full of energy.
func _tea(events: Array) -> void:
	var near := speed_now < 0.6 and offer_for.is_empty() and energy < energy_max - 5.0 \
		and _tea_tiles.any(func(t): return _near(t) <= 1)
	if near != at_tea:
		at_tea = near
		events.append(TEA_NEAR if near else TEA_GONE)


## A cup of tea: costs a little, brings energy back. False if no stall is
## at hand.
func drink_tea() -> bool:
	if not at_tea:
		return false
	var cost := int(balance.n("rickshaw.tea_cost"))
	money -= cost
	tea_spent += cost
	teas += 1
	energy = minf(energy_max, energy + balance.n("rickshaw.tea_energy"))
	_was_tired = energy < balance.n("rickshaw.tired_below")
	at_tea = false
	return true


## Whether the signal at p shows red to someone going `heading` now.
func red_at(p: Vector2i, heading: int) -> bool:
	return map.kind_at(p) == RoadMap.Kind.SIGNAL and Signals.red_for(p, heading, clock, signal_cycle)


## The trip's shortest trip length for a mohalla level: short rides at
## first, the full length from level 7.
static func trip_for_level(level: int) -> int:
	return clampi(4 + int((level + 1) / 2.0), 5, 8)


func _new_trip_time() -> void:
	trip_time = {"finding": 0.0, "riding": 0.0, "junction": 0.0, "traffic": 0.0, "held": 0.0, "standing": 0.0, "detours": 0}


func _time(dt: float) -> void:
	trip_time["riding" if not riding.is_empty() else "finding"] += dt
	if held > 0.0 or stuck:
		trip_time.held += dt
	elif not driver.moving:
		trip_time.junction += dt
	elif speed_now < 0.2 and (room < 0.3 or brake):
		trip_time.traffic += dt
	elif speed_now < 0.2:
		trip_time.standing += dt


## Seconds a finished trip took on average today (finding + riding).
func average_trip_seconds() -> float:
	if trip_times.is_empty():
		return 0.0
	var total := 0.0
	for t in trip_times:
		total += float(t.finding) + float(t.riding)
	return total / trip_times.size()


func _entered(events: Array) -> void:
	# A tile that took the rickshaw further from where it is going.
	var before := _last_remaining
	# Every tile costs energy, more in the rain.
	var cost := balance.n("rickshaw.energy_per_tile_rain" if raining else "rickshaw.energy_per_tile")
	energy = maxf(0.0, energy - cost * energy_factor)
	if energy < balance.n("rickshaw.tired_below") and not _was_tired:
		_was_tired = true
		events.append(TIRED)
	if energy <= 0.0 and not worn_out:
		worn_out = true
		events.append(WORN_OUT)
	# Into a junction against the red light: a fine.
	if red_at(driver.cell, driver.heading):
		var fine := int(balance.n("rickshaw.red_light_fine"))
		money -= fine
		fines += fine
		events.append(FINED)
	# Deep water in the rain: the rickshaw sticks until pushed out.
	if interactive and raining and map.kind_at(driver.cell) == RoadMap.Kind.FLOOD and driver.cell != _pushed_at:
		stuck = true
		_push = 0.0
		_last_hand = -1
		_pushed_at = driver.cell
		speed_now = 0.0
		events.append(STUCK)
	if not riding.is_empty():
		if wet(driver.cell):
			riding.flooded += 1
		if driver.cell == riding.at:
			_deliver(events)
	_aim()
	if before >= 0 and destination == _last_dest and remaining > before:
		trip_time.detours += 1
	_last_remaining = remaining
	_last_dest = destination


## Stopping beside a waiting passenger opens the bargaining; driving off
## ends it. A passenger said no to stays until Rahim Chacha has gone.
func _talk(events: Array) -> void:
	for w in waiting:
		if w.refused and _near(w.at) > 2:
			w.refused = false
	if not offer_for.is_empty():
		if _near(offer_for.at) > 1:
			offer_for = {}
			events.append(OFFER_GONE)
		return
	if not riding.is_empty() or speed_now > 0.6:
		return
	for w in waiting:
		if not w.refused and _near(w.at) <= 1:
			offer_for = w
			events.append(OFFER)
			return


func _near(p: Vector2i) -> int:
	return absi(p.x - driver.cell.x) + absi(p.y - driver.cell.y)


## Takes the passenger at the fare they offered.
func accept() -> void:
	if not offer_for.is_empty():
		_board(offer_for, offer_for.offer)


## Asks for more: the passenger may agree (at the counter fare) or walk
## off. Returns whether they agreed.
func counter() -> bool:
	if offer_for.is_empty():
		return false
	var w: Dictionary = offer_for
	if fares.accepts_counter(w.type, rng, raining):
		_board(w, fares.counter(w.fair))
		return true
	waiting.erase(w)
	offer_for = {}
	if w.get("npc", "") != "":
		npc_log.append({"id": w.npc, "delta": -1, "what": "haggled"})
	_top_up()
	_aim()
	return false


## The most a passenger of this kind will pay: a little over the fair
## fare for a miser, a lot for someone in a hurry; more in the rain.
func _limit_for(type: String, fair_fare: int, offered: int) -> int:
	var r: Array = balance.at("rickshaw.passengers.%s.haggle" % type)
	var extra := _hand_rng.randf_range(float(r[0]), float(r[1]))
	if raining:
		extra += balance.n("rickshaw.haggle_rain_bonus")
	return maxi(offered, fares.round_fare(fair_fare * (1.0 + extra)))


## How the passenger takes being asked `asked`: 0 at their own offer,
## 1 at the most they will pay, more past it (their face shows it).
func mood(asked: int) -> float:
	if offer_for.is_empty():
		return 0.0
	var lo := int(offer_for.offer)
	var hi := int(offer_for.get("limit", lo))
	if asked <= lo:
		return 0.0
	return float(asked - lo) / float(maxi(1, hi - lo))


## Haggling by hand: asks `asked`. Up to their limit, they ride at it;
## past it, they walk off. Returns whether they agreed.
func haggle(asked: int) -> bool:
	if offer_for.is_empty():
		return false
	var w: Dictionary = offer_for
	if asked <= int(w.get("limit", w.offer)):
		_board(w, maxi(asked, int(w.offer)))
		return true
	waiting.erase(w)
	offer_for = {}
	if w.get("npc", "") != "":
		npc_log.append({"id": w.npc, "delta": -1, "what": "haggled"})
	_top_up()
	_aim()
	return false


## The bell: "single", or "double" when rung again straight away (clears
## the way longer; a passenger aboard counts it).
func ring() -> String:
	var kind := "double" if clock - _last_ring <= 0.45 else "single"
	_last_ring = clock
	clear_left = 3.0 if kind == "double" else 1.5
	if kind == "double" and not riding.is_empty():
		riding["rings"] = int(riding.get("rings", 0)) + 1
	return kind


## Pumps the soft tyre to `pressure` (activities.gd pump_result): in the
## green, mended; past it, it bursts (a new tube, paid for); short of it,
## still soft.
func pump(pressure: float) -> String:
	var result := Hands.pump_result(pressure)
	if result == "soft":
		return result
	flat = false
	if result == "burst":
		var cost := int(balance.n("rickshaw.tube_cost"))
		money -= cost
		repairs += cost
	return result


## A push on the stuck rickshaw with one hand (0 left, 1 right). Returns
## [FREED] once it is out.
func push(hand: int) -> Array:
	if not stuck:
		return []
	_push += Hands.push_amount(hand, _last_hand)
	_last_hand = hand
	if _push >= 1.0:
		stuck = false
		return [FREED]
	return []


## Says no: the passenger stays, Rahim Chacha moves on.
func refuse() -> void:
	if not offer_for.is_empty():
		offer_for.refused = true
		offer_for = {}


func _board(w: Dictionary, fare: int) -> void:
	waiting.erase(w)
	offer_for = {}
	riding = {
		"place": w.place, "at": w.place.at, "type": w.type, "fare": fare, "tiles": w.tiles,
		"since": clock, "eta": fares.eta(w.tiles, base_speed), "flooded": 0, "npc": w.get("npc", ""),
	}
	_top_up()
	_aim()


func _deliver(events: Array) -> void:
	var given := fares.stars(clock - riding.since, riding.eta, riding.flooded, riding.type)
	# Rung at all the way: the passenger is fed up with the bell.
	if int(riding.get("rings", 0)) > 3:
		given = maxf(1.0, given - 0.5)
	var tip := fares.tip(given)
	# A neighbour who thinks well of the mohalla tips more.
	var npc: String = riding.get("npc", "")
	var thanks := npc != "" and int(relations.get(npc, 0)) >= 3
	if thanks:
		tip += 20
	# A festival puts everyone in a giving mood.
	tip += int(festival.get("tip", 0))
	if npc != "":
		if given >= 4.5:
			npc_log.append({"id": npc, "delta": 1, "what": "good_ride"})
		elif given < 3.0:
			npc_log.append({"id": npc, "delta": -1, "what": "bad_ride"})
	if given >= 4.0:
		good_trips += 1
	money += riding.fare + tip
	trips += 1
	stars_sum += given
	trip_time["tiles"] = riding.get("tiles", 0)
	trip_times.append(trip_time)
	last_trip = {"fare": riding.fare, "tip": tip, "stars": given, "npc": npc, "thanks": thanks, "time": trip_time}
	_new_trip_time()
	riding = {}
	delivered += 1
	events.append(DELIVERED)
	# Now and then a tyre goes soft after a trip.
	if interactive and not flat and _hand_rng.randf() < balance.n("rickshaw.flat_chance"):
		flat = true
		events.append(FLAT)
	_top_up()


## Keeps a few passengers waiting by the road, a short ride away.
func _top_up() -> void:
	if map == null or map.places.is_empty():
		return
	var roads := map.roads()
	var tries := 0
	while waiting.size() < _want_waiting and tries < 60:
		tries += 1
		var at: Vector2i = roads[rng.randi() % roads.size()]
		var k := map.kind_at(at)
		if k != RoadMap.Kind.ROAD and k != RoadMap.Kind.MAIN_ROAD:
			continue
		var d := _near(at)
		if d < 4 or d > 18 or waiting.any(func(o): return absi(o.at.x - at.x) + absi(o.at.y - at.y) < 3):
			continue
		var dist := map.distances_from(at)
		var choices := map.places.filter(func(pl): return dist.has(pl.at) and dist[pl.at] >= min_trip)
		if choices.is_empty():
			continue
		var place_to: Dictionary = choices[rng.randi() % choices.size()]
		var tiles: int = dist[place_to.at]
		var who := fares.pick_type(rng)
		var fair_fare := fares.fair(tiles)
		_next_id += 1
		var offered := fares.offer(who, fair_fare, rng)
		var w := {
			"id": _next_id, "at": at, "place": place_to, "type": who, "tiles": tiles,
			"fair": fair_fare, "offer": offered, "refused": false, "npc": "",
			"limit": _limit_for(who, fair_fare, offered),
		}
		# Now and then one of the named neighbours.
		if not npc_pool.is_empty() and rng.randf() < 0.25:
			w.npc = npc_pool.pop_back()
		waiting.append(w)


## Where the arrow points: the drop-off with a passenger aboard, else the
## nearest waiting passenger.
func _aim() -> void:
	if riding.has("at"):
		destination = riding.at
		place = riding.place
	elif not waiting.is_empty():
		var best: Dictionary = waiting[0]
		for w in waiting:
			if _near(w.at) < _near(best.at):
				best = w
		destination = best.at
		place = {}
	else:
		destination = driver.cell
		place = {}
	_measure()


## Without passengers (tests of plain driving), behave as before.
func _pick() -> void:
	if fares == null:
		super()
	else:
		_aim()
