## A day at Julekha Khala's fuchka cart by the gate of Sumi's school in
## Mirpur (phase 6). Up to four stand round the cart, each with a taste of
## their own: how sour (tamarind water, 1–3) and how hot (chilli, 0–3) they
## want it; a child little chilli, a college student very sour, an office
## worker hot. A plate is made in steps: the puris cracked, filled with
## potato and peas, then the sour and the chilli measured; a doi fuchka
## (once she has the yoghurt pot) gets doi on top. Handed to someone, the
## plate is judged against what they wanted: just right, a little off, or
## wrong. Busiest when the school lets out and in the evening, when
## families come; rain keeps people away and spoils the puris unless the
## cart is covered; winter sells more. Sumi comes by after school.
## No drawing here, so it can be tested.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const Calendar = preload("res://scripts/rules/calendar.gd")

enum Event {
	ARRIVED, ## someone came to the cart
	SERVED, ## a plate handed over and paid for (last_served)
	LEFT, ## someone gave up waiting
	NOT_READY, ## a step out of order, or a plate given before it was ready
	RAIN_START,
	RAIN_END,
	DAY_OVER,
}

const SEATS := [0, 1, 2, 3]
const KINDS := {"child": 30, "student": 30, "office": 20, "family": 20}
## What each kind of customer tends to want: [sour min, max], [chilli min, max].
const TASTES := {
	"child": [[1, 2], [0, 1]],
	"student": [[3, 3], [1, 2]],
	"office": [[1, 2], [2, 3]],
	"family": [[2, 2], [1, 2]],
	"sumi": [[2, 2], [0, 0]],
}
const MAX_LEVEL := 4

var b: Balance
var rng := RandomNumberGenerator.new()
var weather := RandomNumberGenerator.new()
var upgrades: Array = []
var clock := 0.0
var day_seconds := 300.0
var over := false
## At the cart: {id, seat, kind, item ("fuchka" | "doi_fuchka"), sour,
## chilli, patience, left, npc}.
var customers: Array = []
## The plate in hand: {} or {item, cracked, filled, sour, chilli, doi}.
var plate := {}
var money := 0
var tips := 0
var served := 0
var happy := 0
var exact := 0
var lost := 0
## The last plate handed over: {kind, price, tip, verdict ("exact" |
## "close" | "wrong"), npc}.
var last_served := {}
## Rain: a shower from rain_at; the cart covered with plastic (or the
## umbrella bought); winter brings more people.
var raining := false
var rain_at := -1.0
var rain_seconds := 60.0
var covered := false
var winter := false
var festival := {}
## More or fewer people than usual (a boost bought with stars), 1 usual.
var arrival_factor := 1.0
## The named neighbours who may come, how they feel, what happened.
var npc_pool: Array = []
var relations := {}
var npc_log: Array = []
## Sumi comes by when school lets out (once a day).
var sumi_at := -1.0
var _next_in := 2.0
var _next_id := 0


func _init(balance: Balance, seed_value := -1, owned: Array = [], date := "") -> void:
	b = balance
	upgrades = owned
	if seed_value >= 0:
		rng.seed = seed_value
		weather.seed = seed_value + 7
	elif date != "":
		rng.randomize()
		weather.seed = Calendar.weather_seed(date) + 3
	else:
		rng.randomize()
		weather.randomize()
	day_seconds = b.n("fuchka.day_seconds")
	var rain_chance := b.n("fuchka.rain_chance_per_day")
	if date != "":
		var calendar := Calendar.new()
		rain_chance = calendar.rain_chance(rain_chance, date)
		festival = calendar.festival(date)
		arrival_factor *= calendar.crowd(date)
		var m := Calendar.month_of(date)
		winter = m == 12 or m == 1 or m == 2
	if weather.randf() < rain_chance:
		rain_at = weather.randf_range(0.15, 0.75) * day_seconds
		rain_seconds = b.n("fuchka.rain_seconds")
	# School lets out a little after the day starts here.
	sumi_at = _clock_at(b.n("fuchka.school_out_hour")) + rng.randf_range(0.0, 10.0)
	covered = has("umbrella")


func has(upgrade: String) -> bool:
	return upgrades.has(upgrade)


## The hour of the day, from 13:00 to 21:00.
func hour() -> float:
	return lerpf(b.n("fuchka.start_hour"), b.n("fuchka.end_hour"), clampf(clock / day_seconds, 0.0, 1.0))


func _clock_at(h: float) -> float:
	return (h - b.n("fuchka.start_hour")) / (b.n("fuchka.end_hour") - b.n("fuchka.start_hour")) * day_seconds


## When school lets out, and in the evening when families come.
func rush() -> bool:
	var h := hour()
	for r in b.at("fuchka.rush_hours"):
		if h >= float(r[0]) and h < float(r[1]):
			return true
	return false


func price(item: String) -> int:
	return int(b.n("fuchka.price." + item))


## What can be made: doi fuchka too once she has the yoghurt pot.
func items() -> Array:
	return ["fuchka", "doi_fuchka"] if has("doi") else ["fuchka"]


## The buttons on the cart, in order.
func steps() -> Array:
	return ["puri", "filling", "sour", "chilli"] + (["doi"] if has("doi") else [])


## Starts the day's shower now (tests).
func start_rain() -> void:
	rain_at = clock


func update(dt: float) -> Array:
	if over:
		return []
	var events := []
	clock += dt
	if rain_at >= 0.0:
		var now := clock >= rain_at and clock < rain_at + rain_seconds
		if now != raining:
			raining = now
			events.append(Event.RAIN_START if now else Event.RAIN_END)
			if not now and not has("umbrella"):
				covered = false
	for c in customers.duplicate():
		c.left -= dt
		if c.left <= 0.0:
			customers.erase(c)
			lost += 1
			if str(c.get("npc", "")) != "":
				npc_log.append({"id": c.npc, "delta": -1, "what": "waited"})
			events.append(Event.LEFT)
	_next_in -= dt
	if _next_in <= 0.0:
		var every := b.n("fuchka.rush_arrival_every_s" if rush() else "fuchka.arrival_every_s")
		if raining and not covered:
			every /= b.n("fuchka.rain_arrivals")
		if winter:
			every /= b.n("fuchka.winter_arrivals")
		every /= maxf(0.1, arrival_factor)
		_next_in = every * rng.randf_range(0.6, 1.4)
		if _arrive():
			events.append(Event.ARRIVED)
	if sumi_at >= 0.0 and clock >= sumi_at and _arrive("sumi"):
		sumi_at = -1.0
		events.append(Event.ARRIVED)
	if clock >= day_seconds:
		over = true
		customers.clear()
		events.append(Event.DAY_OVER)
	return events


func _free_seat() -> int:
	for seat in SEATS:
		if not customers.any(func(c): return c.seat == seat):
			return seat
	return -1


func _pick(weights: Dictionary) -> String:
	var total := 0
	for k in weights:
		total += int(weights[k])
	var roll := rng.randi_range(1, total)
	for k in weights:
		roll -= int(weights[k])
		if roll <= 0:
			return k
	return weights.keys()[0]


## Someone comes to the cart, if there is room: a passer-by with their
## taste, now and then a named neighbour, or Sumi.
func _arrive(kind := "") -> bool:
	var seat := _free_seat()
	if seat < 0:
		return false
	if kind == "":
		kind = _pick(KINDS)
	var taste: Array = TASTES[kind]
	_next_id += 1
	var npc := ""
	if kind != "sumi" and not npc_pool.is_empty() and rng.randf() < 0.2:
		npc = npc_pool.pop_back()
	var item := "fuchka"
	if has("doi") and kind != "sumi" and rng.randf() < b.n("fuchka.doi_share"):
		item = "doi_fuchka"
	var patience := b.n("fuchka.patience_s." + ("child" if kind == "sumi" else kind))
	if has("stool"):
		patience += b.n("fuchka.upgrades.stool.patience_bonus_s")
	customers.append({
		"id": _next_id, "seat": seat, "kind": kind, "item": item,
		"sour": rng.randi_range(int(taste[0][0]), int(taste[0][1])),
		"chilli": rng.randi_range(int(taste[1][0]), int(taste[1][1])),
		"patience": patience, "left": patience, "npc": npc,
	})
	return true


# --- Making a plate ------------------------------------------------------------------


## One step on the cart. "puri": a fresh plate, its puris cracked
## (`amount`: how many came out whole, 0–1, from the hands; 1 by default);
## "filling": potato and peas in them; "sour"/"chilli": one more measure
## (or, with `amount` >= 0 from the hands, the level poured); "doi":
## yoghurt on top. [] when done, [NOT_READY] when out of order.
func step(what: String, amount := -1.0) -> Array:
	match what:
		"puri":
			plate = {"item": "fuchka", "cracked": clampf(amount if amount >= 0.0 else 1.0, 0.0, 1.0), "filled": false, "sour": 0, "chilli": 0, "doi": false}
			return []
		"filling":
			if plate.is_empty():
				return [Event.NOT_READY]
			plate.filled = true
			return []
		"sour", "chilli":
			if plate.is_empty() or not plate.filled:
				return [Event.NOT_READY]
			if amount >= 0.0:
				plate[what] = clampi(int(roundf(amount)), 0, MAX_LEVEL)
			else:
				plate[what] = mini(int(plate[what]) + 1, MAX_LEVEL)
			return []
		"doi":
			if plate.is_empty() or not plate.filled or not has("doi"):
				return [Event.NOT_READY]
			plate.doi = true
			plate.item = "doi_fuchka"
			return []
	return [Event.NOT_READY]


## The first-day guide: the next thing to do for whoever has waited
## longest: {step: "puri", "filling", "sour", "chilli", "doi", "discard"
## (too much in it) or "give" (tap their card), seat}; {} with nobody here.
func guide_step() -> Dictionary:
	var who: Dictionary = {}
	for c in customers:
		if who.is_empty() or c.left < who.left:
			who = c
	if who.is_empty():
		return {}
	var step := "give"
	if plate.is_empty():
		step = "puri"
	elif not plate.filled:
		step = "filling"
	elif int(plate.sour) > int(who.sour) or int(plate.chilli) > int(who.chilli) \
			or (plate.doi and str(who.item) != "doi_fuchka"):
		step = "discard"
	elif int(plate.sour) < int(who.sour):
		step = "sour"
	elif int(plate.chilli) < int(who.chilli):
		step = "chilli"
	elif str(who.item) == "doi_fuchka" and not plate.doi and has("doi"):
		step = "doi"
	return {"step": step, "seat": int(who.seat)}


func plate_ready() -> bool:
	return not plate.is_empty() and plate.filled


func discard() -> void:
	plate = {}


## How far a plate is from what someone wanted: the sour and the chilli
## off, the wrong kind of plate, puris broken in the cracking, and rain on
## an uncovered cart (soggy puris), each adds.
func distance(p: Dictionary, c: Dictionary) -> int:
	var d := absi(int(p.sour) - int(c.sour)) + absi(int(p.chilli) - int(c.chilli))
	if str(p.item) != str(c.item):
		d += 2
	if float(p.get("cracked", 1.0)) < 0.5:
		d += 1
	if raining and not covered:
		d += 1
	return d


## Hands the plate to whoever stands at `seat`: just right (a tip), a
## little off (paid, glad enough), or wrong (paid, not glad).
func give_to(seat: int) -> Array:
	if not plate_ready():
		return [Event.NOT_READY]
	var who: Dictionary = {}
	for c in customers:
		if c.seat == seat:
			who = c
	if who.is_empty():
		return []
	var d := distance(plate, who)
	var verdict := "exact" if d == 0 else ("close" if d == 1 else "wrong")
	var paid := price(str(who.item))
	var tip := 0
	if verdict != "wrong" and who.left >= who.patience * 0.3:
		happy += 1
		if verdict == "exact":
			exact += 1
			tip += int(b.n("fuchka.tip_exact"))
		tip += roundi(paid * b.n("fuchka.happy_tip_share")) + roundi(float(festival.get("tip", 0)) * 0.5)
	var npc: String = who.get("npc", "")
	if npc != "":
		if int(relations.get(npc, 0)) >= 3:
			tip += 20
		if verdict != "close":
			npc_log.append({"id": npc, "delta": 1 if verdict == "exact" else -1, "what": "fuchka_" + verdict})
	money += paid + tip
	tips += tip
	served += 1
	customers.erase(who)
	last_served = {"kind": who.kind, "price": paid, "tip": tip, "verdict": verdict, "npc": npc}
	plate = {}
	return [Event.SERVED]


## Plastic over the cart against the rain (until it stops).
func cover() -> void:
	covered = true


## The day's rating, 1–5: the share who went away glad.
func stars() -> float:
	var total := served + lost
	if total == 0:
		return 0.0
	return 1.0 + 4.0 * float(happy) / total
