## Today's race with a ghost rickshaw (phase 7): everyone gets the same
## ride on a date, from the same corner to the same place. The way Rahim
## Chacha rode it is written down every fifth of a second; the best ride
## of the day goes on the public card, and a friend's best (or one's own
## earlier best) rides alongside as a pale ghost to race against. Stars
## for the first finish of the day and for beating a friend's ghost.
## No drawing, no network, so it can be tested.
extends RefCounted

const Balance = preload("res://scripts/rules/balance.gd")
const RoadMap = preload("res://scripts/rules/road_map.gd")
const Friends = preload("res://scripts/rules/friends.gd")

## Seconds between two points of a ride.
const STEP := 0.2
## Five minutes at most.
const MAX_POINTS := 1500

## Set by the home screen just before the rickshaw scene opens: race.
static var next := false


static func fresh() -> Dictionary:
	# Today's best: when, how long, the way; stars paid today.
	return {"date": "", "best": 0.0, "path": "", "paid": false, "beat": false}


static func of(data: Dictionary) -> Dictionary:
	var have = data.get("race", null)
	if typeof(have) != TYPE_DICTIONARY:
		have = {}
		data["race"] = have
	var base := fresh()
	for k in base:
		if not have.has(k):
			have[k] = base[k]
	return have


## The day's ride, the same for everyone on a map and a date: {start,
## place}, the start a ride of `low` to `high` tiles from the place.
static func route(map: RoadMap, date: String, low := 14, high := 26) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(date + "/" + map.id)
	var roads := map.roads().filter(func(p): return map.kind_at(p) == RoadMap.Kind.ROAD or map.kind_at(p) == RoadMap.Kind.MAIN_ROAD)
	for attempt in 60:
		var place: Dictionary = map.places[rng.randi() % map.places.size()]
		var start: Vector2i = roads[rng.randi() % roads.size()]
		var d := map.distance(start, place.at)
		if d >= low and d <= high:
			return {"start": start, "place": place}
	return {}


## A ride's points (x, z in metres) packed small for the card: two bytes
## each, in tenths of a metre.
static func encode(points: PackedVector2Array) -> String:
	var bytes := PackedByteArray()
	bytes.resize(points.size() * 4)
	for i in points.size():
		bytes.encode_s16(i * 4, clampi(roundi(points[i].x * 10.0), -32768, 32767))
		bytes.encode_s16(i * 4 + 2, clampi(roundi(points[i].y * 10.0), -32768, 32767))
	return Marshalls.raw_to_base64(bytes)


static func decode(text: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	if text == "":
		return out
	var bytes := Marshalls.base64_to_raw(text)
	for i in range(0, bytes.size() - 3, 4):
		out.append(Vector2(bytes.decode_s16(i), bytes.decode_s16(i + 2)) / 10.0)
	return out


## Where a ride was `t` seconds in (between its points; the end once over).
static func at_time(points: PackedVector2Array, t: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var f := clampf(t / STEP, 0.0, float(points.size() - 1))
	var i := floori(f)
	if i >= points.size() - 1:
		return points[points.size() - 1]
	return points[i].lerp(points[i + 1], f - i)


## The ghost to race today: the fastest friend's ride on this date, else
## my own best of today, else {}. {name, time, path, friend}.
static func ghost(data: Dictionary, date: String) -> Dictionary:
	var best := {}
	var f := Friends.of(data)
	for p in f.list:
		var c: Dictionary = f.cards.get(p.uid, {})
		var r = c.get("race", {})
		if typeof(r) != TYPE_DICTIONARY or str(r.get("date", "")) != date or float(r.get("time", 0.0)) <= 0.0:
			continue
		if best.is_empty() or float(r.time) < float(best.time):
			best = {"name": str(p.name), "time": float(r.time), "path": str(r.get("path", "")), "friend": true}
	if not best.is_empty():
		return best
	var mine := of(data)
	if str(mine.date) == date and float(mine.best) > 0.0:
		return {"name": "", "time": float(mine.best), "path": str(mine.path), "friend": false}
	return {}


## A ride finished in `seconds`: today's best kept (and on the card), and
## stars for the first finish today and for beating a friend's ghost.
## Returns {stars, best (a new best today), beat (the friend's ghost)}.
static func finish(data: Dictionary, b: Balance, date: String, seconds: float, path: String, ghost_ride: Dictionary) -> Dictionary:
	var r := of(data)
	if str(r.date) != date:
		r.date = date
		r.best = 0.0
		r.path = ""
		r.paid = false
		r.beat = false
	var out := {"stars": 0, "best": false, "beat": false}
	if float(r.best) <= 0.0 or seconds < float(r.best):
		r.best = snappedf(seconds, 0.1)
		r.path = path
		out.best = true
	if not r.paid:
		r.paid = true
		out.stars += int(b.n("race.finish_tara"))
	if bool(ghost_ride.get("friend", false)) and seconds < float(ghost_ride.get("time", 0.0)):
		out.beat = true
		if not r.beat:
			r.beat = true
			out.stars += int(b.n("race.beat_tara"))
	data.tara = int(data.get("tara", 0)) + int(out.stars)
	return out


## Today's challenge board: my best and my friends' bests on this date,
## fastest first: [{name, time, me}].
static func board(data: Dictionary, date: String) -> Array:
	var out := []
	var f := Friends.of(data)
	for p in f.list:
		var c: Dictionary = f.cards.get(p.uid, {})
		var r = c.get("race", {})
		if typeof(r) == TYPE_DICTIONARY and str(r.get("date", "")) == date and float(r.get("time", 0.0)) > 0.0:
			out.append({"name": str(p.name), "time": float(r.time), "me": false})
	var mine := of(data)
	if str(mine.date) == date and float(mine.best) > 0.0:
		out.append({"name": "", "time": float(mine.best), "me": true})
	out.sort_custom(func(a, b): return float(a.time) < float(b.time))
	return out


## Today's best for the public card ({} when there is none today).
static func card(data: Dictionary, date: String) -> Dictionary:
	var r := of(data)
	if str(r.date) != date or float(r.best) <= 0.0:
		return {}
	return {"race": {"date": date, "time": float(r.best), "path": str(r.path)}}
