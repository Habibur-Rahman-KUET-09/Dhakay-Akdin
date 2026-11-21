## Monir Mama's day at his tea stall (§৪.৩): 6 am to 11 pm in a few
## minutes. Customers sit down on the bench with an order of one or two
## things and wait as long as their patience lasts. Each thing is made by
## tapping its steps in order (cup, kettle, milk, sugar for milk tea); the
## wrong step spoils it. The kettle holds eight cups and takes a while to
## fill again. More customers in the morning and evening rush. Rahim
## Chacha stops by once a day. No drawing here, so it can be tested.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")

enum Event {
	ARRIVED, ## someone sat down
	GAVE, ## a thing was handed over
	SERVED, ## a customer got everything and paid
	LEFT, ## a customer gave up and went
	WRONG_STEP, ## that step does not make anything: start again
	NOBODY_WANTS, ## a finished thing nobody is waiting for: thrown away
	KETTLE_EMPTY, ## the last cup poured: fill it again
	REFILLING, ## the kettle is being filled
	KETTLE_FULL, ## and is full again
	DAY_OVER,
}

## What can be ordered, in the order shown on the counter.
const STEPS := ["cup", "kettle", "milk", "sugar", "banana", "bun_jar", "betel_leaf", "areca", "lime"]
## How often each thing is ordered (out of 100).
const ORDER_WEIGHTS := {"milk_tea": 40, "liquor_tea": 20, "bun": 14, "paan": 14, "banana": 12}
## Customer kinds (out of 100): patience comes from the balance file.
const KIND_WEIGHTS := {"normal": 60, "office": 25, "elder": 15}
const SEATS := 4

var b: Balance
var rng := RandomNumberGenerator.new()
var menu: Dictionary
var clock := 0.0
var day_seconds := 240.0
var over := false
## On the bench: {id, seat, kind, items (left to give), ordered (all),
## patience, left (seconds), bill, name}.
var customers: Array = []
## The steps tapped so far for the thing being made.
var tray: Array = []
var kettle := 8
var kettle_size := 8
var refill_left := 0.0
var money := 0
var tips := 0
var sold := 0
var served := 0
var happy := 0
var lost := 0
## The customer just served, for the screen: {name, kind, bill, tip, happy}.
var last_served := {}
## When Rahim Chacha comes (seconds into the day); -1 once he has.
var rahim_at := -1.0
var _next_in := 2.0
var _next_id := 0


func _init(balance: Balance, seed_value := -1) -> void:
	b = balance
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	menu = b.at("tea_stall.menu")
	day_seconds = b.n("tea_stall.day_seconds")
	kettle_size = int(b.n("tea_stall.kettle_cups"))
	kettle = kettle_size
	rahim_at = rng.randf_range(0.2, 0.7) * day_seconds


## The hour of the day, 6.0 to 23.0.
func hour() -> float:
	return lerpf(b.n("tea_stall.start_hour"), b.n("tea_stall.end_hour"), clampf(clock / day_seconds, 0.0, 1.0))


## In the morning or evening rush?
func rush() -> bool:
	var h := hour()
	for r in b.at("tea_stall.rush_hours"):
		if h >= float(r[0]) and h < float(r[1]):
			return true
	return false


func price(item: String) -> int:
	return int(menu[item].price)


func steps_of(item: String) -> Array:
	return menu[item].steps


## Average rating for the day, 1–5: the share of customers who went away
## happy.
func stars() -> float:
	var total := served + lost
	if total == 0:
		return 0.0
	return 1.0 + 4.0 * float(happy) / total


func update(dt: float) -> Array:
	if over:
		return []
	var events := []
	clock += dt
	if refill_left > 0.0:
		refill_left -= dt
		if refill_left <= 0.0:
			refill_left = 0.0
			kettle = kettle_size
			events.append(Event.KETTLE_FULL)
	for c in customers.duplicate():
		c.left -= dt
		if c.left <= 0.0:
			customers.erase(c)
			lost += 1
			events.append(Event.LEFT)
	_next_in -= dt
	if _next_in <= 0.0:
		var every := b.n("tea_stall.rush_arrival_every_s" if rush() else "tea_stall.arrival_every_s")
		_next_in = every * rng.randf_range(0.6, 1.4)
		if _arrive(false):
			events.append(Event.ARRIVED)
	if rahim_at >= 0.0 and clock >= rahim_at and _arrive(true):
		rahim_at = -1.0
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


## Someone sits down, if there is room. Rahim Chacha always has milk tea
## and a bun.
func _arrive(rahim: bool) -> bool:
	var seat := _free_seat()
	if seat < 0:
		return false
	var kind := "rahim" if rahim else _pick(KIND_WEIGHTS)
	var items := ["milk_tea", "bun"] if rahim else [_pick(ORDER_WEIGHTS)]
	if not rahim and rng.randf() < 0.35:
		items.append(_pick(ORDER_WEIGHTS))
	var patience := b.n("tea_stall.patience_s." + ("normal" if rahim else kind)) + (4.0 if rahim else 0.0)
	var bill := 0
	for it in items:
		bill += price(it)
	_next_id += 1
	customers.append({
		"id": _next_id, "seat": seat, "kind": kind, "items": items.duplicate(), "ordered": items,
		"patience": patience, "left": patience, "bill": bill,
	})
	return true


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


## The thing the tray makes exactly, or "".
func made() -> String:
	for item in menu:
		if steps_of(item) == tray:
			return item
	return ""


## Some menu thing starts with these steps.
func _leads_somewhere(steps: Array) -> bool:
	for item in menu:
		var s := steps_of(item)
		if s.size() >= steps.size() and s.slice(0, steps.size()) == steps:
			return true
	return false


## A waiting customer wants something that goes on from what is in the
## tray (milk tea after cup and kettle).
func _wanted_further() -> bool:
	for c in customers:
		for it in c.items:
			var s := steps_of(it)
			if s.size() > tray.size() and s.slice(0, tray.size()) == tray:
				return true
	return false


## Taps a step at the counter.
func tap(step: String) -> Array:
	if over:
		return []
	if step == "kettle":
		if refill_left > 0.0:
			return []
		if kettle <= 0:
			# Empty: tapping it puts it on to fill.
			refill_left = b.n("tea_stall.kettle_refill_s")
			return [Event.REFILLING]
	var next := tray.duplicate()
	next.append(step)
	if not _leads_somewhere(next):
		tray.clear()
		return [Event.WRONG_STEP]
	var events := []
	if step == "kettle":
		kettle -= 1
		if kettle == 0:
			events.append(Event.KETTLE_EMPTY)
	tray = next
	# Done, and nobody waits for more on top of it: hand it over.
	if made() != "" and not _wanted_further():
		events.append_array(give())
	return events


## Hands over what is in the tray to whoever has waited longest for it.
func give() -> Array:
	var item := made()
	if item == "":
		return []
	tray.clear()
	var who: Dictionary = {}
	for c in customers:
		if c.items.has(item) and (who.is_empty() or c.left < who.left):
			who = c
	if who.is_empty():
		return [Event.NOBODY_WANTS]
	who.items.erase(item)
	money += price(item)
	sold += 1
	var events := [Event.GAVE]
	if who.items.is_empty():
		customers.erase(who)
		served += 1
		# Quick service (more than half their patience left): happy, and a tip.
		var glad: bool = who.left >= who.patience * 0.5
		var tip := 0
		if glad:
			happy += 1
			tip = maxi(1, roundi(who.bill * b.n("tea_stall.happy_tip_share")))
			money += tip
			tips += tip
		last_served = {"kind": who.kind, "bill": who.bill, "tip": tip, "happy": glad}
		events.append(Event.SERVED)
	return events


## Throws away what is in the tray.
func discard() -> void:
	tray.clear()
