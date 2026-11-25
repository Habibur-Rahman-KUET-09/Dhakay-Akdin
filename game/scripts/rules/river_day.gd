## Haripada Majhi's day on the Buriganga (phase 8): a rowing ferry (kheya)
## between Sadarghat and the Jinjira ghat across the river. At a ghat
## people step aboard one by one; the longer the first ones wait, the
## crosser they get, and a few give up and step off, so it is his choice
## when to push off. Then he rows: one oar and then the other keeps the
## boat going straight and quick; the same oar twice turns it (the right
## oar turns it to the left of the way he faces, the left oar to the
## right), and the current carries it downstream all the while, so he has
## to aim above the ghat. Miss it and he poles slowly along the bank.
## Launches run up and down the middle of the river: their horn warns, a
## wake rocks the boat, and a bump is a fright. Fares are paid on landing,
## with a tip for a quick, calm crossing. No drawing here: testable.
##
## The river: x across, 0 at Sadarghat to `width` at Jinjira; y along it,
## downstream positive; both ghats at y = 0. Metres, roughly.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const Calendar = preload("res://scripts/rules/calendar.gd")

enum Event {
	BOARDED, ## someone stepped aboard
	LEFT, ## someone gave up waiting and stepped off
	CAST_OFF,
	ARRIVED, ## landed at the other ghat (last_trip)
	OFF_GHAT, ## reached the bank away from the ghat
	HORN, ## a launch is coming
	WAKE, ## a launch's wake rocks the boat
	BUMP, ## hit a launch's side
	DAY_OVER,
}

var b: Balance
var rng := RandomNumberGenerator.new()
var weather := RandomNumberGenerator.new()
var upgrades: Array = []
var clock := 0.0
var day_seconds := 300.0
var over := false
var width := 120.0
var ghat_half := 12.0
var capacity := 8
## Where the boat is and how it moves; which bank it is at or left from
## (0 Sadarghat, 1 Jinjira); tied up at a ghat or crossing.
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var side := 0
var docked := true
var at_bank := false
## Aboard: {id, wait (seconds since boarding), patience, luggage, fare}.
var aboard: Array = []
## Launches: {id, x, y, dir (+1 downstream), speed, half_len, half_w,
## horned, waked}.
var launches: Array = []
var current := 0.5
var raining := false
var rain_at := -1.0
## More or fewer people coming to the ghat than usual (a boost).
var arrival_factor := 1.0
var money := 0
var tips := 0
var crossings := 0
var carried := 0
var bumps := 0
var waves := 0
var gave_up := 0
var stars_sum := 0.0
var last_trip := {}
## How the last stroke went: "good", "same" (the same oar again) or
## "rushed" (too quick), and on which side.
var last_stroke := ""
var last_hand := 0
var trip_time := 0.0
var _trip_bumps := 0
var _trip_waves := 0
var _since_stroke := 9.0
var _bump_cool := 0.0
var _off_told := false
var _next_arrival := 1.0
var _next_launch := 6.0
var _next_id := 0


func _init(balance: Balance, seed_value := -1, owned: Array = [], date := "") -> void:
	b = balance
	upgrades = owned
	if seed_value >= 0:
		rng.seed = seed_value
		weather.seed = seed_value + 11
	elif date != "":
		rng.randomize()
		weather.seed = Calendar.weather_seed(date) + 9
	else:
		rng.randomize()
		weather.randomize()
	day_seconds = b.n("boat.day_seconds")
	width = b.n("boat.width")
	ghat_half = b.n("boat.ghat_half")
	capacity = int(b.n("boat.upgrades.big_boat.capacity")) if has("big_boat") else int(b.n("boat.capacity"))
	current = b.n("boat.current")
	var rain_chance := b.n("boat.rain_chance_per_day")
	if date != "":
		rain_chance = Calendar.new().rain_chance(rain_chance, date)
	if weather.randf() < rain_chance:
		rain_at = weather.randf_range(0.15, 0.7) * day_seconds
	_next_arrival = rng.randf_range(0.5, 1.5)
	_next_launch = rng.randf_range(4.0, 8.0)


func has(upgrade: String) -> bool:
	return upgrades.has(upgrade)


func hour() -> float:
	return lerpf(b.n("boat.start_hour"), b.n("boat.end_hour"), clampf(clock / day_seconds, 0.0, 1.0))


## Which way across he is going (or would go next): +1 to Jinjira, -1 back.
func heading() -> int:
	return 1 if side == 0 else -1


## The far bank's x.
func target_x() -> float:
	return width if side == 0 else 0.0


## How far still to row, 0–1 of the way.
func left_share() -> float:
	return absf(target_x() - pos.x) / width


func update(dt: float) -> Array:
	if over:
		return []
	var events := []
	clock += dt
	if rain_at >= 0.0:
		raining = clock >= rain_at and clock < rain_at + b.n("boat.rain_seconds")
	current = b.n("boat.rain_current") if raining else b.n("boat.current")
	# The day ends at a ghat (a crossing under way is finished first).
	if clock >= day_seconds and (docked or clock >= day_seconds + 60.0):
		over = true
		events.append(Event.DAY_OVER)
		return events
	_move_launches(dt, events)
	if docked:
		_boarding(dt, events)
		return events
	trip_time += dt
	_since_stroke += dt
	_bump_cool = maxf(0.0, _bump_cool - dt)
	vel *= exp(-b.n("boat.drag") * dt)
	# The current is weaker by the bank.
	var flow := current * (0.3 if at_bank else 1.0)
	pos += (vel + Vector2(0, flow)) * dt
	var goal := target_x()
	var reached := pos.x >= goal if heading() > 0 else pos.x <= goal
	pos.x = clampf(pos.x, 0.0, width)
	# Pushed back to the bank he left from: he stays afloat just off it.
	if heading() > 0:
		pos.x = maxf(pos.x, 1.0)
	else:
		pos.x = minf(pos.x, width - 1.0)
	if reached:
		pos.x = goal
		vel.x = 0.0
		if absf(pos.y) <= ghat_half:
			_arrive(events)
			return events
		at_bank = true
		if not _off_told:
			_off_told = true
			events.append(Event.OFF_GHAT)
	else:
		at_bank = false
	_meet_launches(events)
	return events


func _boarding(dt: float, events: Array) -> void:
	_next_arrival -= dt * arrival_factor * (b.n("boat.rain_arrivals") if raining and not has("chhoi") else 1.0)
	if _next_arrival <= 0.0:
		var gap: Array = b.at("boat.arrive_s")
		_next_arrival = rng.randf_range(float(gap[0]), float(gap[1]))
		if aboard.size() < capacity:
			_next_id += 1
			var luggage := rng.randf() < b.n("boat.luggage_chance")
			aboard.append({"id": _next_id, "wait": 0.0, "patience": b.n("boat.patience_s") * rng.randf_range(0.8, 1.2),
				"luggage": luggage, "fare": int(b.n("boat.luggage_fare" if luggage else "boat.fare"))})
			events.append(Event.BOARDED)
	for p in aboard.duplicate():
		p.wait = float(p.wait) + dt
		if float(p.wait) >= float(p.patience):
			aboard.erase(p)
			gave_up += 1
			events.append(Event.LEFT)


## Pushes off from the ghat (with at least one aboard).
func cast_off() -> Array:
	if not docked or aboard.is_empty() or over:
		return []
	docked = false
	at_bank = false
	_off_told = false
	trip_time = 0.0
	_trip_bumps = 0
	_trip_waves = 0
	_since_stroke = 9.0
	last_hand = 0
	vel = Vector2.ZERO
	return [Event.CAST_OFF]


## One pull on an oar: hand -1 left, +1 right.
func stroke(hand: int) -> Array:
	if docked or over:
		return []
	var power := b.n("boat.stroke") * (b.n("boat.upgrades.new_oars.stroke") if has("new_oars") else 1.0)
	var turn := b.n("boat.turn")
	if _since_stroke < b.n("boat.rushed_s"):
		last_stroke = "rushed"
		power *= b.n("boat.rushed")
	elif hand == last_hand:
		last_stroke = "same"
		power *= b.n("boat.same_hand")
		turn *= 1.5
	else:
		last_stroke = "good"
	_since_stroke = 0.0
	last_hand = hand
	var h := heading()
	# Facing across, downstream is to his right going to Jinjira and to
	# his left coming back; the right oar turns the boat to his left.
	var dy := -float(hand) * float(h) * turn
	if at_bank:
		# Along the bank he poles, either oar, towards the ghat.
		dy = -signf(pos.y) * b.n("boat.pole")
	vel += Vector2(0.0 if at_bank else h * power, dy)
	return []


func _move_launches(dt: float, events: Array) -> void:
	_next_launch -= dt
	if _next_launch <= 0.0:
		var every: Array = b.at("boat.launch_every_s")
		_next_launch = rng.randf_range(float(every[0]), float(every[1]))
		var dir := 1 if rng.randf() < 0.5 else -1
		var speeds: Array = b.at("boat.launch_speed")
		_next_id += 1
		launches.append({"id": _next_id, "x": width * rng.randf_range(0.35, 0.65), "y": -170.0 * dir, "dir": dir,
			"speed": rng.randf_range(float(speeds[0]), float(speeds[1])), "half_len": b.n("boat.launch_half_len"),
			"half_w": b.n("boat.launch_half_w"), "horned": false, "waked": false})
	for l in launches.duplicate():
		l.y = float(l.y) + float(l.dir) * float(l.speed) * dt
		if absf(float(l.y)) > 200.0:
			launches.erase(l)


func _meet_launches(events: Array) -> void:
	for l in launches:
		var dx := absf(pos.x - float(l.x))
		var dy := pos.y - float(l.y)
		# Its horn: coming his way, a few seconds off.
		var ahead := dy * float(l.dir)
		if not l.horned and dx < 30.0 and ahead > 0.0 and ahead < float(l.speed) * 6.0 + float(l.half_len):
			l.horned = true
			events.append(Event.HORN)
		if dx < float(l.half_w) + 1.0 and absf(dy) < float(l.half_len) + 1.5:
			# Once a launch: then he is clear of it.
			if _bump_cool <= 0.0 and not l.get("bumped", false):
				l["bumped"] = true
				l.waked = true
				_bump_cool = 3.0
				bumps += 1
				_trip_bumps += 1
				# Pushed back the way he came.
				vel = Vector2(-heading() * 3.0, 0.0)
				events.append(Event.BUMP)
		elif not l.waked and dx < 25.0 and absf(dy) < float(l.half_len):
			l.waked = true
			waves += 1
			_trip_waves += 1
			events.append(Event.WAKE)


func _arrive(events: Array) -> void:
	var n := aboard.size()
	var fares := 0
	for p in aboard:
		fares += int(p.fare)
	var slow := maxf(0.0, (trip_time - b.n("boat.good_trip_s")) / 15.0)
	var stars := clampf(5.0 - _trip_bumps - 0.3 * _trip_waves - slow, 1.0, 5.0)
	var tip := n * int(b.n("boat.tip")) if stars >= 4.5 else 0
	money += fares + tip
	tips += tip
	crossings += 1
	carried += n
	stars_sum += stars
	last_trip = {"n": n, "fares": fares, "tip": tip, "secs": trip_time, "stars": stars}
	aboard.clear()
	side = 1 - side
	pos = Vector2(width if side == 1 else 0.0, 0.0)
	vel = Vector2.ZERO
	docked = true
	at_bank = false
	_next_arrival = rng.randf_range(0.5, 1.5)
	events.append(Event.ARRIVED)


func earned() -> int:
	return money


## The day's rating, 1–5: the crossings' average.
func stars() -> float:
	return stars_sum / crossings if crossings > 0 else 1.0
