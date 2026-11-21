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
var accel := 0.45
var coast := 0.3
var braking := 1.5
## Current speed, tiles per second.
var speed_now := 0.0

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
	var top := base_speed * (flood_speed if on_flood() else 1.0)
	if brake:
		speed_now = maxf(0.0, speed_now - braking * dt)
	elif pedal:
		speed_now = minf(top, speed_now + accel * dt) if speed_now <= top else maxf(top, speed_now - braking * dt)
	else:
		speed_now = maxf(0.0, speed_now - coast * dt)
	driver.speed = speed_now
	var events := driver.update(dt)
	if not events.has(Driver.Event.ENTERED):
		return events
	if driver.cell == destination:
		delivered += 1
		_pick()
		events.append(Driver.Event.ARRIVED)
	_measure()
	return events


func _measure() -> void:
	remaining = map.distance(driver.cell, destination)


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
