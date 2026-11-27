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
const Night = preload("res://scripts/rules/night.gd")

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
## Energy getting low (a warning before he tires).
const ENERGY_LOW := 60
## A tyre gone soft (slower until pumped).
const FLAT := 24
## Stuck in deep water in the rain (push to get out), and out again.
const STUCK := 25
const FREED := 26
## Rain with a passenger aboard and the hood down: put it up (by hand).
const HOOD := 27
## Paid by phone: check the SMS (settle_phone with what the player said).
const PHONE_PAY := 28
## The chain came off the gear: standing until it is put back (fix_chain).
const CHAIN := 29
## Something a passenger left on the seat has been found: where did they
## get off? (return_lost with the choice).
const LOST_ITEM := 30
## Today's race (race.gd): at the finish.
const RACE_DONE := 31
## The night shift: a pothole in an unlit lane (without the hands: a
## jolt and a moment's stop; with them it is a FLAT), and a night guard's
## question (settle_guard).
const POTHOLE := 32
const GUARD := 33

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
var _was_low := false
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
## The hood: up in the rain (a little slower, but the passenger stays
## dry); asked for once per rider and shower.
## Easy driving (a setting): fares a little lower, fines halved (and the
## police keep him half as long); the scene also thins the traffic.
var easy := false
var hood_up := false
var _hood_asked := false
## A ride paid by phone, waiting for the SMS to be checked: {fare, sms,
## npc}; or {}. The mohalla level makes the fakes cleverer. Results today.
var phone_pay := {}
var level := 1
var phone_log: Array = []
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
## Ramadan: in the afternoon more people hurry to be home for iftar.
var ramadan := false
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
## Phase 6 (hands on): the chain coming off now and then with a passenger
## aboard (standing until put back); things left on the seat, found a
## ride or two later: {item, type, npc, place, choices} while Rahim Chacha
## remembers where they got off; how many went back to their owners, and
## what the owners gave. Their own dice, so the rest plays the same.
var chain_off := false
var chains := 0
var lost := {}
var returned := 0
var lost_rewards := 0
var drops: Array = []
var _left_behind := {}
var _chain_rng := RandomNumberGenerator.new()
var _lost_rng := RandomNumberGenerator.new()
## Phase 7: friends' tea stalls in this town (friends.gd shop_places);
## now and then a passenger wants to go to one. Customers taken to each,
## by friend's account (they are paid for them at their end).
var friend_places: Array = []
## Today's race (race.gd), when racing: the place to reach; no passengers
## then, and the clock is the race's.
var race_to := {}
## Ratul's deliveries (delivery.gd), on his days: orders instead of
## passengers.
var delivery = null
## Whose working hours the clock shows ("delivery": 4 pm to 10 pm).
var hours_key := "rickshaw"
## The night shift (night.gd): on, the unlit lanes, the guards and the
## ones met tonight, a guard's question waiting ({at, question}), the
## rickshaw's lamp (an upgrade: fewer potholes).
var night := false
var dark := {}
var guards: Array = []
var guard_ask := {}
var lamp := false
var potholes := 0
var _guards_met := {}
var _guard_qs: Array = []
var _night_rng := RandomNumberGenerator.new()
var friend_visits := {}
var _friend_rng := RandomNumberGenerator.new()
var _last_remaining := -1
var _last_dest := Vector2i(-1, -1)


## `trip`: the shortest ride, in tiles (shorter in the first days).
func _init(road_map: RoadMap, b: Balance, seed_value := -1, date := "", trip := 8) -> void:
	balance = b
	if seed_value >= 0:
		_hand_rng.seed = seed_value + 13
		_chain_rng.seed = seed_value + 19
		_lost_rng.seed = seed_value + 23
		_friend_rng.seed = seed_value + 29
	else:
		_friend_rng.randomize()
		_hand_rng.randomize()
		_chain_rng.randomize()
		_lost_rng.randomize()
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
	elif date != "":
		# The same weather for everyone on a date, so Rafiq Chacha's paper
		# can say today whether it rains tomorrow (Calendar.rains_on).
		weather.seed = Calendar.weather_seed(date)
	else:
		weather.randomize()
	var chance := b.n("rickshaw.rain_chance_per_day")
	var calendar := Calendar.new()
	if date != "":
		chance = calendar.rain_chance(chance, date)
		festival = calendar.festival(date)
		ramadan = calendar.ramadan(date)
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
	var from := balance.n(hours_key + ".start_hour")
	var to := balance.n(hours_key + ".end_hour")
	return lerpf(from, to, clampf(clock / day_seconds, 0.0, 1.0))


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
	# The hood catches the wind: slower while it is up, rain or not.
	if hood_up:
		speed_factor *= balance.n("rickshaw.hood_drag")
	# The bell rung: people step aside for a moment.
	if clear_left > 0.0:
		clear_left -= dt
		room = maxf(room, 0.75)
	if stuck or chain_off:
		speed_factor = 0.0
		speed_now = 0.0
	# Held by the police: standing still, whatever the pedal says.
	if held > 0.0:
		held -= dt
		speed_factor = 0.0
		speed_now = 0.0
	# Easy driving waits at a red light instead of running it.
	if easy and driver.moving and driver.progress > 0.5 and red_at(driver.next_cell(), driver.heading):
		room = 0.0
	# Easy driving: slow down beside a waiting passenger and stand while
	# the fare is talked over, so the offer is not driven past.
	if easy and riding.is_empty() and (not offer_for.is_empty() or _passenger_close()):
		room = minf(room, 0.0 if not offer_for.is_empty() else balance.n("rickshaw.easy_stop_room"))
	var events := super(dt)
	events.append_array(early)
	_time(dt)
	_hood(events)
	if events.has(Driver.Event.WRONG_WAY):
		_police(events)
	_talk(events)
	_tea(events)
	_found(events)
	if delivery != null:
		delivery.raining = raining
		var got: Array = delivery.update(dt, driver.cell)
		if not got.is_empty():
			events.append_array(got)
			_aim()
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
		# Without the hands, the hood goes up by itself and comes down when
		# the rain stops. With them, it stays up until he lowers it.
		if not interactive:
			hood_up = now
		_hood_asked = false


## Rain on a passenger with the hood down: ask for the hood, once.
func _hood(events: Array) -> void:
	if interactive and raining and not hood_up and not _hood_asked and not riding.is_empty():
		_hood_asked = true
		events.append(HOOD)


## The hood put up, with how well it went (0..1, activities): quick and
## the passenger stays dry and tips; slow and they get wet (half a star).
func raise_hood(score: float) -> void:
	hood_up = true
	if riding.is_empty():
		return
	if score >= 0.7:
		riding["dry"] = true
	elif score < 0.4:
		riding.flooded += 1


## The hood folded down again (after the rain): full speed back.
func lower_hood() -> void:
	hood_up = false


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
	var fine := int(balance.n("rickshaw.wrong_way_fine") * _fine_share())
	money -= fine
	fines += fine
	police_fines += fine
	held = balance.n("rickshaw.wrong_way_stop_s") * _fine_share()
	_police_rest = held + 15.0
	speed_now = 0.0
	events.append(POLICE)


func _fine_share() -> float:
	return balance.n("rickshaw.easy_fine") if easy else 1.0


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
	_was_low = energy < balance.n("rickshaw.energy_warn")
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
	if night:
		cost *= balance.n("night.energy")
	energy = maxf(0.0, energy - cost * energy_factor)
	if energy < balance.n("rickshaw.energy_warn") and not _was_low:
		_was_low = true
		events.append(ENERGY_LOW)
	if energy < balance.n("rickshaw.tired_below") and not _was_tired:
		_was_tired = true
		events.append(TIRED)
	if energy <= 0.0 and not worn_out:
		worn_out = true
		events.append(WORN_OUT)
	# Into a junction against the red light: a fine.
	if red_at(driver.cell, driver.heading):
		var fine := int(balance.n("rickshaw.red_light_fine") * _fine_share())
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
	# Now and then the chain comes off with a passenger aboard.
	if interactive and not riding.is_empty() and not chain_off and not stuck \
			and chains < int(balance.n("rickshaw.chain_max_per_day")) and _chain_rng.randf() < balance.n("rickshaw.chain_per_tile"):
		chain_off = true
		chains += 1
		speed_now = 0.0
		events.append(CHAIN)
	if delivery != null:
		var got: Array = delivery.arrive(driver.cell)
		events.append_array(got)
	if night:
		_night_tile(events)
	if not race_to.is_empty() and driver.cell == race_to.at and not over:
		over = true
		events.append(RACE_DONE)
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


## A passenger (not one who said no) waiting within a tile.
func _passenger_close() -> bool:
	for w in waiting:
		if not w.refused and _near(w.at) <= 1:
			return true
	return false


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


## The chain put back on the gear; `held`: seconds more standing (done
## without care, by the quick button).
func fix_chain(held_s := 0.0) -> void:
	chain_off = false
	held = maxf(held, held_s)


## A thing left behind, found once the ride or two after it are under
## way: LOST_ITEM, and `lost` says what and offers three places.
func _found(events: Array) -> void:
	if _left_behind.is_empty() or not lost.is_empty() or riding.is_empty() or trips < int(_left_behind.found_at):
		return
	var d: Dictionary = _left_behind
	_left_behind = {}
	# Today's other drop-offs first (the latest first), then anywhere.
	var pool := drops.map(func(x): return x.place)
	pool.reverse()
	var anywhere := map.places.duplicate()
	for i in anywhere.size():
		var j := _lost_rng.randi_range(i, anywhere.size() - 1)
		var x = anywhere[i]
		anywhere[i] = anywhere[j]
		anywhere[j] = x
	pool.append_array(anywhere)
	lost = {
		"item": Hands.lost_item(str(d.type)), "type": d.type, "npc": d.npc, "place": d.place,
		"choices": Hands.lost_choices(_lost_rng, d.place, pool, 3, "id"),
	}
	events.append(LOST_ITEM)


## Where the owner of the lost thing got off, as Rahim Chacha remembers it
## (an index into lost.choices; −1: he hands it in at the police box).
## Right: it goes back, the owner gives something for it and a neighbour
## thinks better of him. Returns "right", "wrong" or "police".
func return_lost(choice: int) -> String:
	if lost.is_empty():
		return ""
	var result := "police"
	if choice >= 0 and choice < (lost.choices as Array).size():
		result = "right" if lost.choices[choice].id == lost.place.id else "wrong"
	if result == "right":
		var reward := int(balance.n("rickshaw.lost_reward"))
		money += reward
		lost_rewards += reward
		returned += 1
		if str(lost.npc) != "":
			npc_log.append({"id": lost.npc, "delta": 2, "what": "returned"})
	lost = {}
	return result


## The SMS checked: the player said it was fake, or not. Returns
## phone_result's word; the money and the rating follow from it.
func settle_phone(said_fake: bool) -> String:
	if phone_pay.is_empty():
		return ""
	var result := Hands.phone_result(phone_pay.sms, said_fake)
	if result != "fooled":
		money += int(phone_pay.fare)
	if result == "wrong":
		# Called a cheat for nothing: a star less, and a neighbour remembers.
		stars_sum = maxf(0.0, stars_sum - 1.0)
		if phone_pay.npc != "":
			npc_log.append({"id": phone_pay.npc, "delta": -1, "what": "doubted"})
	phone_log.append(result)
	phone_pay = {}
	return result


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
	# Boarding under a hood already up in the rain: they stay dry.
	if hood_up and raining:
		riding["dry"] = true
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
	# Kept dry under the hood in the rain.
	# Seen safely past a night guard.
	if riding.get("safe", false):
		tip += int(balance.n("night.guard_tip"))
	if riding.get("dry", false):
		tip += int(balance.n("rickshaw.hood_tip"))
	# A festival puts everyone in a giving mood.
	tip += int(festival.get("tip", 0))
	if npc != "":
		if given >= 4.5:
			npc_log.append({"id": npc, "delta": 1, "what": "good_ride"})
		elif given < 3.0:
			npc_log.append({"id": npc, "delta": -1, "what": "bad_ride"})
	if given >= 4.0:
		good_trips += 1
	# Now and then they pay by phone: the fare waits until the SMS is checked.
	if interactive and _hand_rng.randf() < balance.n("rickshaw.phone_pay_chance"):
		var fake := _hand_rng.randf() < balance.n("rickshaw.phone_fake_chance")
		phone_pay = {"fare": riding.fare, "npc": npc, "sms": Hands.phone_sms(_hand_rng, riding.fare, level, fake)}
		money += tip
		events.append(PHONE_PAY)
	else:
		money += riding.fare + tip
	trips += 1
	stars_sum += given
	drops.append({"place": riding.place, "type": riding.type, "npc": npc})
	var friend := str(riding.place.get("friend", ""))
	if friend != "":
		friend_visits[friend] = int(friend_visits.get(friend, 0)) + 1
	# Now and then they leave something on the seat, found a ride or two on.
	if interactive and _left_behind.is_empty() and lost.is_empty() and returned < 3 \
			and _lost_rng.randf() < balance.n("rickshaw.lost_chance"):
		_left_behind = {"place": riding.place, "type": riding.type, "npc": npc, "found_at": trips + _lost_rng.randi_range(0, 1)}
	trip_time["tiles"] = riding.get("tiles", 0)
	trip_times.append(trip_time)
	last_trip = {"fare": riding.fare, "tip": tip, "stars": given, "npc": npc, "thanks": thanks, "time": trip_time,
		"friend": str(riding.place.get("name", "")) if friend != "" else ""}
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
	if map == null or map.places.is_empty() or not race_to.is_empty() or delivery != null:
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
		# Now and then: to a friend's tea stall.
		if not friend_places.is_empty() and _friend_rng.randf() < balance.n("rickshaw.friend_shop_chance"):
			var stalls := friend_places.filter(func(pl): return dist.has(pl.at) and dist[pl.at] >= min_trip)
			if not stalls.is_empty():
				place_to = stalls[_friend_rng.randi() % stalls.size()]
		var tiles: int = dist[place_to.at]
		var who := fares.pick_type(rng)
		if night and who == "normal" and _night_rng.randf() < balance.n("night.hurry_share"):
			who = "hurry"
		if ramadan and who == "normal" and hour() >= 15.0 and _hand_rng.randf() < 0.5:
			who = "hurry"
		var fair_fare := fares.fair(tiles)
		if easy:
			fair_fare = fares.round_fare(fair_fare * balance.n("rickshaw.easy_fare"))
		if night:
			fair_fare = fares.round_fare(fair_fare * balance.n("night.fare"))
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
	if not race_to.is_empty():
		destination = race_to.at
		place = race_to
	elif delivery != null:
		var stop: Dictionary = delivery.current()
		destination = stop.at if not stop.is_empty() else driver.cell
		place = {}
	elif riding.has("at"):
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


## Race today's ride (race.gd route): from its start, to its place, with
## nobody waiting by the road; the day's clock and energy do not matter.
func start_race(route: Dictionary) -> void:
	race_to = route.place
	waiting.clear()
	offer_for = {}
	riding = {}
	driver.cell = route.start
	driver.progress = 0.0
	driver.heading = driver._first_exit()
	day_seconds = 1e9
	energy_factor = 0.0
	_aim()


## The night shift: ten to two, fewer people about, higher fares, the
## unlit lanes and the guards, one tea stall still open.
func start_night(seed_value := -1) -> void:
	night = true
	hours_key = "night"
	day_seconds = balance.n("night.day_seconds")
	if seed_value >= 0:
		_night_rng.seed = seed_value + 37
	else:
		_night_rng.randomize()
	var range_of: Array = balance.at("night.waiting_passengers")
	_want_waiting = _night_rng.randi_range(int(range_of[0]), int(range_of[1]))
	while waiting.size() > _want_waiting:
		waiting.pop_back()
	dark = Night.dark_tiles(map, balance.n("night.dark_share"))
	guards = Night.guard_tiles(map, int(balance.n("night.guards")))
	_guard_qs = Night.questions()
	if _tea_tiles.size() > 1:
		_tea_tiles = [_tea_tiles[0]]
	_aim()


## Into a tile at night: a pothole in an unlit lane now and then, a night
## guard's question once each.
func _night_tile(events: Array) -> void:
	var cell := driver.cell
	if dark.has(cell) and not flat:
		var chance := balance.n("night.pothole_chance") * (balance.n("night.lamp_potholes") if lamp else 1.0)
		if _night_rng.randf() < chance:
			potholes += 1
			events.append(POTHOLE)
			if interactive:
				flat = true
				events.append(FLAT)
			else:
				held = maxf(held, 1.5)
	if guards.has(cell) and not _guards_met.has(cell) and guard_ask.is_empty():
		_guards_met[cell] = true
		var q: Dictionary = _guard_qs[_night_rng.randi() % _guard_qs.size()] if not _guard_qs.is_empty() else {}
		guard_ask = {"at": cell, "question": q}
		events.append(GUARD)


## A night guard's question answered: a good answer and the passenger
## feels safe (a tip at the end); a bad one and he keeps Rahim Chacha a
## while.
func settle_guard(ok: bool) -> void:
	if guard_ask.is_empty():
		return
	guard_ask = {}
	if ok:
		if not riding.is_empty():
			riding["safe"] = true
	else:
		held = maxf(held, balance.n("night.guard_hold_s"))


## Ratul's evening: orders instead of passengers.
func start_delivery(d) -> void:
	delivery = d
	waiting.clear()
	offer_for = {}
	riding = {}
	_aim()


## Without passengers (tests of plain driving), behave as before.
func _pick() -> void:
	if fares == null:
		super()
	else:
		_aim()
