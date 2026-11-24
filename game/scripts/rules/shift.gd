## One stretch of driving on a map, with a real place to reach: the part of
## Rahim Chacha's day that week 2 needs (§৪.১). Passengers, fares and the
## clock come on top of this in week 3. No drawing here, so it can be tested.
extends RefCounted

const RoadMap = preload("res://scripts/rules/road_map.gd")
const Driver = preload("res://scripts/rules/driver.gd")

var map: RoadMap
var driver: Driver
var base_speed := 2.5
## Speed factor on a waterlogged tile.
var flood_speed := 0.5
## The shortest legal trip, in tiles, to a new destination.
var min_trip := 8
var rng := RandomNumberGenerator.new()

## The player's pedal and brake (§৪.১, speed in the player's hands): the
## rickshaw gathers speed while pedalling, rolls to a stop when not, and
## stops quicker when braking. Rates in tiles per second per second.
var pedal := false
var brake := false
## Cruise: a tap on the pedal keeps it pedalling with no finger held, until
## the brake (or another tap) stops it.
var cruise := false
## Easy driving: at a junction where it would stop and wait, it takes the
## way to the destination by itself.
var follow_route := false
var accel := 0.45
var coast := 0.3
var braking := 1.5
## Current speed, tiles per second.
var speed_now := 0.0
## How much of the top speed the road ahead allows (0 when someone is
## right in front), set by the scene from the traffic.
var room := 1.0
## Top speed factor for how Rahim Chacha is (tired: less), set by the day.
var speed_factor := 1.0

var destination := Vector2i.ZERO
## The real place being driven to, when the map has places; else {}.
var place := {}
var delivered := 0
## Tiles left on the shortest legal way from the last tile entered; -1 if
## there is none (the rickshaw went the wrong way into a dead end).
var remaining := -1


func _init(road_map: RoadMap, speed: float, waterlog := 0.5, trip := 8, seed_value := -1) -> void:
	map = road_map
	base_speed = speed
	flood_speed = waterlog
	min_trip = trip
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	driver = Driver.new(map, speed)
	_pick()
	_measure()


func on_flood() -> bool:
	return map.kind_at(driver.cell) == RoadMap.Kind.FLOOD \
		or (driver.moving and map.kind_at(driver.next_cell()) == RoadMap.Kind.FLOOD)


func swipe(t: int) -> Array:
	return driver.swipe(t)


func update(dt: float) -> Array:
	var top := base_speed * speed_factor * (flood_speed if on_flood() else 1.0)
	if brake:
		cruise = false
		speed_now = maxf(0.0, speed_now - braking * dt)
	elif pedal or cruise:
		speed_now = minf(top, speed_now + accel * dt) if speed_now <= top else maxf(top, speed_now - braking * dt)
	else:
		speed_now = maxf(0.0, speed_now - coast * dt)
	speed_now = minf(speed_now, top * room)
	driver.speed = speed_now
	var events := driver.update(dt)
	if follow_route and events.has(Driver.Event.WAITING):
		var way := next_turn()
		if way.turn >= 0 and way.tiles == 0:
			events.erase(Driver.Event.WAITING)
			events.append_array(swipe(way.turn))
	# Stopped at a junction or a dead end: the rickshaw stands still.
	if not driver.moving:
		speed_now = 0.0
	if events.has(Driver.Event.ENTERED):
		_entered(events)
	return events


## A new tile was entered. Here: reaching the destination picks another
## (the day with passengers, day.gd, does more).
func _entered(events: Array) -> void:
	if driver.cell == destination:
		delivered += 1
		_pick()
		events.append(Driver.Event.ARRIVED)
	_measure()


func _measure() -> void:
	remaining = map.distance(driver.cell, destination)


## The next turn the way to the destination needs, at a junction where
## there is a choice (bends the road takes by itself are skipped):
## {turn: Driver.RIGHT / LEFT / BACK, tiles: how many tiles ahead it is
## (0: here)}; turn -1 when it is straight on all the way (tiles: to the
## destination) or there is no legal way (tiles -1).
func next_turn() -> Dictionary:
	var start := driver.cell
	var tiles := 0
	if driver.moving and driver.progress > 0.0:
		start = driver.next_cell()
		tiles = 1
	if start == destination:
		return {"turn": -1, "tiles": tiles}
	var path = map.route(start, destination)
	if path == null:
		return {"turn": -1, "tiles": -1}
	var h := driver.heading
	var c := start
	for q in path:
		var d := _direction(c, q)
		if d != h:
			var rel := (d - h + 4) % 4
			if rel == Driver.BACK or _ways_on(c, h) >= 2:
				return {"turn": rel, "tiles": tiles}
			h = d
		c = q
		tiles += 1
	return {"turn": -1, "tiles": tiles}


## How many ways on (ahead, right, left; legally) a tile has for someone
## coming in heading h.
func _ways_on(at: Vector2i, h: int) -> int:
	var n := 0
	for t in [Driver.AHEAD, Driver.RIGHT, Driver.LEFT]:
		if map.move(at, RoadMap.turn(h, t)) == RoadMap.Move.OK:
			n += 1
	return n


static func _direction(from: Vector2i, to: Vector2i) -> int:
	for d in 4:
		if RoadMap.step(from, d) == to:
			return d
	return -1


## A real place at least min_trip legal tiles away, other than the last
## one; on a map without places, a dry road tile. The farthest one if the
## map is too small for that.
func _pick() -> void:
	var dist := map.distances_from(driver.cell)
	var options := []
	if not map.places.is_empty():
		for p in map.places:
			if p != place and dist.has(p.at):
				options.append({"at": p.at, "place": p})
	else:
		for at in dist:
			var k := map.kind_at(at)
			if k in [RoadMap.Kind.ROAD, RoadMap.Kind.MAIN_ROAD, RoadMap.Kind.TEA, RoadMap.Kind.SIGNAL]:
				options.append({"at": at, "place": {}})
	if options.is_empty():
		push_error("%s: nowhere to drive to" % map.id)
		return
	var far := options.filter(func(o): return dist[o.at] >= min_trip)
	var pick: Dictionary
	if not far.is_empty():
		pick = far[rng.randi_range(0, far.size() - 1)]
	else:
		pick = options[0]
		for o in options:
			if dist[o.at] > dist[pick.at]:
				pick = o
	destination = pick.at
	place = pick.place
