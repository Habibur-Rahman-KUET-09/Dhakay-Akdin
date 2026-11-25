## Ratul's evening on the bicycle (phase 8): food orders from the
## kitchens of Mirpur to people's flats, through the rickshaw's streets.
## An order comes in on his phone; he takes it or lets it go. Up to three
## at once: pick each up at its kitchen (waiting if it is still cooking),
## then take it to the flat before it goes cold. Which to do first is his
## choice (the arrow points at one stop; he can switch). The customer's
## rating comes from how hot the food still is; rain cools it quicker (and
## pays a little more), the insulated bag slower. Now and then a guard at
## the gate wants a word first. No drawing here, so it can be tested.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const RoadMap = preload("res://scripts/rules/road_map.gd")

const PATH := "res://content/delivery.json"

## Events (numbers clear of Day's own).
const OFFER := 40 ## an order offered (offer)
const OFFER_GONE := 41 ## not taken in time
const PICKED := 42 ## food picked up (last_picked)
const COOKING := 43 ## at the kitchen, the food not ready yet
const DELIVERED := 44 ## handed over (last_done)
const GATE := 45 ## a guard at the gate: answer (settle_gate)
const COLD := 46 ## an order has gone cold on the way

var b: Balance
var map: RoadMap
var rng := RandomNumberGenerator.new()
var upgrades: Array = []
## Kitchens on the map: {id, name, food, at}. Gates' questions.
var kitchens: Array = []
var gates: Array = []
## The order on offer, or {}: {id, kitchen, to, flat, pay, tiles, left}.
var offer := {}
## Taken: {id, kitchen, to, flat, pay, tiles, picked, heat, ready_left, cold}.
var active: Array = []
## The stop the arrow points at (an index into stops()).
var target := 0
var raining := false
var money := 0
var tips := 0
var delivered := 0
var cold_ones := 0
## Handed over still hot (five stars).
var hot := 0
## More or fewer orders than usual (a boost), 1 as usual.
var offer_factor := 1.0
var stars_sum := 0.0
var declined := 0
var last_picked := {}
var last_done := {}
## Waiting at a gate: the order and the question; {} when not.
var gate := {}
var _next_offer := 2.0
var _next_id := 0


func _init(balance: Balance, road_map: RoadMap, seed_value := -1, owned: Array = []) -> void:
	b = balance
	map = road_map
	upgrades = owned
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	gates = parsed.get("gates", [])
	# Each kitchen at one of the map's places, the same ones every day.
	var spots := map.places.duplicate()
	spots.sort_custom(func(x, y): return str(x.id) < str(y.id))
	var list: Array = parsed.get("kitchens", [])
	for i in mini(list.size(), spots.size()):
		var k: Dictionary = list[i].duplicate()
		var spot: Dictionary = spots[(i * 3) % spots.size()]
		if kitchens.any(func(x): return x.at == spot.at):
			spot = spots[(i * 3 + 1) % spots.size()]
		k["at"] = spot.at
		k["place"] = spot
		kitchens.append(k)


func has(upgrade: String) -> bool:
	return upgrades.has(upgrade)


func average_stars() -> float:
	return stars_sum / delivered if delivered > 0 else 0.0


## Where people live: an ordinary road a fair way from the kitchen.
func _home_for(from: Vector2i) -> Vector2i:
	var roads := map.roads().filter(func(p): return map.kind_at(p) == RoadMap.Kind.ROAD)
	for attempt in 40:
		var p: Vector2i = roads[rng.randi() % roads.size()]
		var d := map.distance(from, p)
		if d >= int(b.n("delivery.min_tiles")) and d <= int(b.n("delivery.max_tiles")):
			return p
	return roads[0]


func _make_offer() -> Dictionary:
	var k: Dictionary = kitchens[rng.randi() % kitchens.size()]
	var to := _home_for(k.at)
	var tiles := map.distance(k.at, to)
	var pay := int(roundf((b.n("delivery.base_pay") + b.n("delivery.pay_per_tile") * tiles) / 5.0) * 5.0)
	_next_id += 1
	return {"id": _next_id, "kitchen": k, "to": to, "tiles": tiles, "pay": pay,
		"flat": "%d/%s" % [rng.randi_range(3, 99), ["ক", "খ", "গ", "ঘ"][rng.randi() % 4]],
		"left": b.n("delivery.offer_s")}


func update(dt: float, cell: Vector2i) -> Array:
	var events := []
	# The order on offer: taken, or it goes to someone else.
	if not offer.is_empty():
		offer.left = float(offer.left) - dt
		if float(offer.left) <= 0.0:
			offer = {}
			declined += 1
			events.append(OFFER_GONE)
	elif active.size() < int(b.n("delivery.max_orders")):
		_next_offer -= dt
		if _next_offer <= 0.0:
			_next_offer = b.n("delivery.offer_every_s") * rng.randf_range(0.7, 1.3) / maxf(0.1, offer_factor)
			offer = _make_offer()
			events.append(OFFER)
	var cool := dt / b.n("delivery.hot_s")
	if raining:
		cool *= b.n("delivery.rain_cooling")
	if has("hot_bag"):
		cool *= b.n("delivery.upgrades.hot_bag.cooling")
	for o in active:
		o.ready_left = maxf(0.0, float(o.ready_left) - dt)
		if o.picked:
			o.heat = maxf(0.0, float(o.heat) - cool)
			if float(o.heat) <= 0.0 and not o.cold:
				o.cold = true
				events.append(COLD)
	# Waiting at a kitchen: picked up as soon as it is ready.
	events.append_array(_pick_up(cell))
	return events


## Takes the order on offer: cooking starts now.
func accept() -> bool:
	if offer.is_empty():
		return false
	var o := offer
	offer = {}
	o.erase("left")
	o["picked"] = false
	o["heat"] = 1.0
	o["cold"] = false
	o["ready_left"] = b.n("delivery.cook_s") * rng.randf_range(0.6, 1.4)
	active.append(o)
	_next_offer = b.n("delivery.offer_every_s") * rng.randf_range(0.7, 1.3)
	return true


func decline() -> void:
	if not offer.is_empty():
		offer = {}
		declined += 1


## Every stop still to make: {order (id), kind ("pick" | "drop"), at}.
func stops() -> Array:
	var out := []
	for o in active:
		if o.picked:
			out.append({"order": o.id, "kind": "drop", "at": o.to})
		else:
			out.append({"order": o.id, "kind": "pick", "at": o.kitchen.at})
	return out


## The stop the arrow points at, or {} with nothing to do.
func current() -> Dictionary:
	var s := stops()
	if s.is_empty():
		return {}
	target = clampi(target, 0, s.size() - 1)
	return s[target]


func order(id: int) -> Dictionary:
	for o in active:
		if o.id == id:
			return o
	return {}


## The arrow on to the next stop.
func switch_target() -> void:
	var n := stops().size()
	target = (target + 1) % maxi(1, n)


func _pick_up(cell: Vector2i) -> Array:
	var events := []
	for o in active:
		if o.picked or o.kitchen.at != cell:
			continue
		if float(o.ready_left) > 0.0:
			if not o.get("told", false):
				o["told"] = true
				events.append(COOKING)
			continue
		o.picked = true
		last_picked = o
		events.append(PICKED)
	return events


## Into a tile: pick-ups there, and hand-overs (a guard first, now and
## then).
func arrive(cell: Vector2i) -> Array:
	var events := _pick_up(cell)
	if not gate.is_empty():
		return events
	for o in active:
		if o.picked and o.to == cell:
			if not gates.is_empty() and rng.randf() < b.n("delivery.gate_chance"):
				gate = {"order": o.id, "question": gates[rng.randi() % gates.size()]}
				events.append(GATE)
				return events
			events.append_array(_hand_over(o, true))
			return events
	return events


## The guard's question answered (well or not): then the hand-over, a
## star less if it went badly.
func settle_gate(ok: bool) -> Array:
	if gate.is_empty():
		return []
	var o := order(int(gate.order))
	gate = {}
	if o.is_empty():
		return []
	return _hand_over(o, ok)


## The customer's stars from how hot it still is.
func stars_for(heat: float) -> float:
	if heat >= 0.6:
		return 5.0
	if heat >= 0.35:
		return 4.0
	if heat > 0.0:
		return 3.0
	return 2.0


func _hand_over(o: Dictionary, gate_ok: bool) -> Array:
	var stars := stars_for(float(o.heat))
	if not gate_ok:
		stars = maxf(1.0, stars - 1.0)
	var tip := 0
	if stars >= 5.0:
		tip += int(b.n("delivery.tip_hot"))
		hot += 1
	if raining:
		tip += int(b.n("delivery.rain_tip"))
	if has("raincoat") and raining:
		tip += int(b.n("delivery.upgrades.raincoat.tip"))
	money += int(o.pay) + tip
	tips += tip
	delivered += 1
	stars_sum += stars
	if o.cold:
		cold_ones += 1
	active.erase(o)
	last_done = {"id": o.id, "pay": int(o.pay), "tip": tip, "stars": stars, "food": o.kitchen.food, "gate_ok": gate_ok}
	target = 0
	return [DELIVERED]
