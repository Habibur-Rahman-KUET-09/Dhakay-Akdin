## Kashem Bhai's day selling peanuts on the buses (phase 8): along Babu's
## route, Mirpur 10 to Motijheel and back. He waits at a stop for a bus,
## gets on, calls out ("Badam! Badam!": the better the call, the more of
## those who want some put a hand up), sells to whoever wants a packet or
## two, and gets off before the conductor throws him off (two stops free;
## Babu lets him ride four). Then the next bus. His basket holds so many
## packets, taken on credit from the wholesaler in the morning: at the end
## of the day he pays for what he sold (and dropped). Masala peanuts (an upgrade) sell dearer; with the cooler box
## he sells water too, most on a hot day. No drawing here: testable.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const Calendar = preload("res://scripts/rules/calendar.gd")

enum Event {
	BUS_CAME, ## a bus at the stop: on he gets (boarded)
	BABU_BUS, ## …and it is Babu's
	ARRIVED, ## the bus at the next stop
	WARNED, ## the conductor: "off at the next one, brother!"
	THROWN_OFF, ## stayed too long: put off, a packet or two dropped
	GOT_OFF, ## got off himself
	SOLD, ## a sale (last_sale)
	SOLD_OUT,
	DEPARTED,
	DAY_OVER,
}

var b: Balance
var rng := RandomNumberGenerator.new()
var route: Array = []
var upgrades: Array = []
var clock := 0.0
var day_seconds := 300.0
var over := false
## Where he is: on a bus or waiting at stop `stop_i`; which way he goes.
var on_bus := false
var at_stop := true
var stop_i := 0
var dir := 1
var ridden := 0
var free_stops := 2
var babus := false
var wait_left := 3.0
var travel_left := 0.0
var dwell_left := 0.0
## Whether he has called out since the last stop (once a stretch).
var called := false
var last_call := ""
## On the bus: {id, seat, wants (packets), item ("badam" | "water"),
## shown (hand up), to (stop index)}.
var riders: Array = []
var stock := 0
var capacity := 30
var money := 0
var sold := 0
var water_sold := 0
var thrown := 0
var buses := 0
var dropped := 0
var last_sale := {}
var hot := false
var raining := false
var rain_at := -1.0
var weather := RandomNumberGenerator.new()
## More or fewer people wanting some than usual (a boost), 1 as usual.
var want_factor := 1.0
var _babu_at := -1
var _next_id := 0


func _init(balance: Balance, seed_value := -1, owned: Array = [], date := "") -> void:
	b = balance
	upgrades = owned
	if seed_value >= 0:
		rng.seed = seed_value
		weather.seed = seed_value + 7
	elif date != "":
		rng.randomize()
		weather.seed = Calendar.weather_seed(date) + 5
	else:
		rng.randomize()
		weather.randomize()
	route = (b.at("bus.route") as Array).duplicate()
	day_seconds = b.n("hawker.day_seconds")
	capacity = int(b.n("hawker.upgrades.big_basket.capacity")) if has("big_basket") else int(b.n("hawker.capacity"))
	stock = capacity
	var rain_chance := b.n("hawker.rain_chance_per_day")
	var hot_chance := b.n("hawker.hot_chance_per_day")
	if date != "":
		var calendar := Calendar.new()
		rain_chance = calendar.rain_chance(rain_chance, date)
		hot_chance = calendar.hot_chance(hot_chance, date)
	if weather.randf() < rain_chance:
		rain_at = weather.randf_range(0.15, 0.75) * day_seconds
	elif weather.randf() < hot_chance:
		hot = true
	# One bus today is Babu's (the third to the sixth).
	_babu_at = rng.randi_range(3, 6)
	wait_left = rng.randf_range(2.0, 4.0)


func has(upgrade: String) -> bool:
	return upgrades.has(upgrade)


func price(item: String) -> int:
	if item == "water":
		return int(b.n("hawker.water_price"))
	return int(b.n("hawker.upgrades.masala.price")) if has("masala") else int(b.n("hawker.price"))


func hour() -> float:
	return lerpf(b.n("hawker.start_hour"), b.n("hawker.end_hour"), clampf(clock / day_seconds, 0.0, 1.0))


func stop_id(i: int) -> String:
	return route[clampi(i, 0, route.size() - 1)]


## How the call came out from where the moving marker was (0–1, the
## middle best): "perfect", "good" or "miss".
static func call_quality(marker: float) -> String:
	var off := absf(marker - 0.5)
	if off <= 0.08:
		return "perfect"
	if off <= 0.2:
		return "good"
	return "miss"


func update(dt: float) -> Array:
	if over:
		return []
	var events := []
	clock += dt
	if rain_at >= 0.0:
		raining = clock >= rain_at and clock < rain_at + b.n("hawker.rain_seconds")
	if clock >= day_seconds:
		over = true
		events.append(Event.DAY_OVER)
		return events
	if not on_bus:
		wait_left -= dt
		if wait_left <= 0.0:
			_board(events)
		return events
	if at_stop:
		dwell_left -= dt
		if dwell_left <= 0.0:
			# Leaving: stayed past his free stops, he is put off first.
			if ridden > free_stops:
				_thrown_off(events)
				return events
			at_stop = false
			called = false
			var between: Array = b.at("bus.seconds_between_stops")
			travel_left = rng.randf_range(float(between[0]), float(between[1]))
			events.append(Event.DEPARTED)
		return events
	travel_left -= dt
	if travel_left <= 0.0:
		_arrive(events)
	return events


func _board(events: Array) -> void:
	on_bus = true
	at_stop = true
	ridden = 0
	buses += 1
	babus = buses == _babu_at
	free_stops = int(b.n("hawker.babu_free_stops")) if babus else int(b.n("hawker.free_stops"))
	riders.clear()
	var range_of: Array = b.at("hawker.riders")
	for i in rng.randi_range(int(range_of[0]), int(range_of[1])):
		_add_rider(i)
	dwell_left = b.n("hawker.dwell_s")
	called = false
	events.append(Event.BUS_CAME)
	if babus:
		events.append(Event.BABU_BUS)


func _add_rider(seat: int) -> void:
	_next_id += 1
	var chance := b.n("hawker.want_chance") * want_factor
	if raining:
		chance *= b.n("hawker.rain_wants")
	var r := {"id": _next_id, "seat": seat, "wants": 0, "item": "badam", "shown": false,
		"to": _next_stop(rng.randi_range(1, 3))}
	if rng.randf() < chance:
		r.wants = rng.randi_range(1, 2)
		var water_share := b.n("hawker.hot_water_share") if hot else b.n("hawker.water_share")
		if has("cooler") and rng.randf() < water_share:
			r.item = "water"
			r.wants = 1
	riders.append(r)


func _next_stop(k: int) -> int:
	return clampi(stop_i + dir * k, 0, route.size() - 1)


func _arrive(events: Array) -> void:
	stop_i += dir
	at_stop = true
	ridden += 1
	# The end of the line: the next bus he takes goes back.
	if stop_i <= 0 or stop_i >= route.size() - 1:
		dir = -dir
	# Some get off; others get on, not yet asked.
	for r in riders.duplicate():
		if int(r.to) == stop_i:
			riders.erase(r)
	var seats := []
	for r in riders:
		seats.append(int(r.seat))
	for k in rng.randi_range(1, 4):
		var seat := 0
		while seats.has(seat):
			seat += 1
		if seat >= 24:
			break
		seats.append(seat)
		_add_rider(seat)
	dwell_left = b.n("hawker.dwell_s")
	events.append(Event.ARRIVED)
	if ridden == free_stops:
		events.append(Event.WARNED)


func _thrown_off(events: Array) -> void:
	on_bus = false
	riders.clear()
	thrown += 1
	var lost := mini(stock, int(b.n("hawker.dropped")))
	stock -= lost
	dropped += lost
	wait_left = rng.randf_range(4.0, 7.0)
	events.append(Event.THROWN_OFF)


## Gets off at this stop (only while the bus stands there).
func get_off() -> Array:
	if not on_bus or not at_stop:
		return []
	on_bus = false
	riders.clear()
	wait_left = rng.randf_range(2.5, 6.0)
	return [Event.GOT_OFF]


## The call down the bus, once a stretch (between stops, or at a stop):
## the better it is, the more of those who want some put a hand up.
func shout(quality: String) -> int:
	if not on_bus or called:
		return 0
	called = true
	last_call = quality
	var share: float = {"perfect": 1.0, "good": 0.7}.get(quality, 0.35)
	var n := 0
	for r in riders:
		if int(r.wants) > 0 and not r.shown and rng.randf() < share:
			r.shown = true
			n += 1
	return n


## Those with a hand up, waiting to buy (what is still in the basket).
func buyers() -> Array:
	return riders.filter(func(r): return r.shown and int(r.wants) > 0 and (r.item == "water" or stock > 0))


## Nothing left to sell: the peanuts gone, and no cooler of water.
func sold_out() -> bool:
	return stock <= 0 and not has("cooler")


## Hands a buyer what they want (as much as is left in the basket).
func sell(id: int) -> Array:
	for r in riders:
		if r.id != id or not r.shown or int(r.wants) <= 0:
			continue
		var n := int(r.wants)
		if r.item == "badam":
			n = mini(n, stock)
			if n <= 0:
				return []
			stock -= n
			sold += n
		else:
			water_sold += n
		var got := n * price(str(r.item))
		money += got
		r.wants = 0
		last_sale = {"item": r.item, "n": n, "taka": got}
		var events := [Event.SOLD]
		if stock <= 0:
			events.append(Event.SOLD_OUT)
		return events
	return []


## What he owes the wholesaler: the packets sold and dropped.
func cost() -> int:
	return (sold + dropped) * int(b.n("hawker.wholesale"))


## The day's takings less what he owes the wholesaler.
func earned() -> int:
	return money - cost()


## The day's rating, 1–5: sales against what the basket held, less for
## being thrown off.
func stars() -> float:
	var share := float(sold) / maxf(1.0, capacity)
	return clampf(1.0 + 4.0 * minf(1.0, share * 1.3) - 0.5 * thrown, 1.0, 5.0)
