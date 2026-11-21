## The rickshaw's movement on a road map, without any drawing, so the rules
## can be tested (§৪.১). It follows the road by itself. The camera sits
## behind it, so a swipe is a turn: right or left is used at the next
## junction that allows it, back turns round at once, ahead goes straight
## on. At a junction it cannot go straight through, with no turn waiting,
## it stops and waits for a swipe. It never goes the wrong way by itself.
extends RefCounted

const RoadMap = preload("res://scripts/rules/road_map.gd")

enum Event { ENTERED, WRONG_WAY, WAITING, U_TURN, ARRIVED }
## Turns, as quarter turns clockwise from the heading.
enum { AHEAD = 0, RIGHT = 1, BACK = 2, LEFT = 3 }

var map: RoadMap
## Tiles per second.
var speed := 2.5
## The tile last entered, and the heading.
var cell := Vector2i.ZERO
var heading := RoadMap.N
## 0 at `cell`, 1 at the next tile.
var progress := 0.0
var moving := true
## The turn the player asked for, used at the next junction; -1 for none.
var queued := -1


func _init(road_map: RoadMap, tiles_per_s: float, start := Vector2i(-1, -1), head := -1) -> void:
	map = road_map
	speed = tiles_per_s
	cell = start if start.x >= 0 else map.home
	heading = head if head >= 0 else _first_exit()


func _first_exit() -> int:
	for d in 4:
		if map.move(cell, d) == RoadMap.Move.OK:
			return d
	push_error("%s: no road leaves %s" % [map.id, cell])
	return RoadMap.N


## Where to draw the rickshaw, in tiles.
func position() -> Vector2:
	return Vector2(cell) + Vector2(RoadMap.DX[heading], RoadMap.DY[heading]) * progress


func next_cell() -> Vector2i:
	return RoadMap.step(cell, heading)


## A swipe, as a turn relative to the heading.
func swipe(t: int) -> Array:
	if t == BACK:
		if moving and progress > 0.0:
			cell = next_cell()
			progress = 1.0 - progress
		heading = RoadMap.opposite(heading)
		queued = -1
		var m := map.move(cell, heading)
		moving = m != RoadMap.Move.BLOCKED
		return [Event.U_TURN, Event.WRONG_WAY] if m == RoadMap.Move.WRONG_WAY else [Event.U_TURN]
	queued = t
	if not moving:
		return _choose()
	return []


func update(dt: float) -> Array:
	if not moving:
		return []
	var events := []
	progress += speed * dt
	while moving and progress >= 1.0:
		progress -= 1.0
		cell = next_cell()
		events.append(Event.ENTERED)
		events.append_array(_choose())
		if not moving:
			progress = 0.0
	return events


## Ways on from `cell`, other than back: physically, and legally.
func _exits(legal_only: bool) -> Array:
	var out := []
	for t in [AHEAD, RIGHT, LEFT]:
		var m := map.move(cell, RoadMap.turn(heading, t))
		if m == RoadMap.Move.OK or (not legal_only and m == RoadMap.Move.WRONG_WAY):
			out.append(RoadMap.turn(heading, t))
	return out


## At `cell`: take the waiting turn if this is a junction that has it,
## else go straight, else follow a bend with a single way on, else wait.
func _choose() -> Array:
	if queued >= 0:
		var d := RoadMap.turn(heading, queued)
		var m := map.move(cell, d)
		if m != RoadMap.Move.BLOCKED and (queued == AHEAD or _exits(false).size() >= 2 or not moving):
			heading = d
			queued = -1
			moving = true
			return [Event.WRONG_WAY] if m == RoadMap.Move.WRONG_WAY else []
	if map.move(cell, heading) == RoadMap.Move.OK:
		moving = true
		return []
	var ways := _exits(true)
	if ways.size() == 1:
		# A bend: follow it. If it is the turn that was asked for, that turn
		# is done.
		if queued >= 0 and RoadMap.turn(heading, queued) == ways[0]:
			queued = -1
		heading = ways[0]
		moving = true
		return []
	# About to stop: a waiting turn the road allows is taken, even the
	# wrong way up a one-way lane (that is the player's choice, and costs).
	if queued >= 0:
		var d := RoadMap.turn(heading, queued)
		var m := map.move(cell, d)
		if m != RoadMap.Move.BLOCKED:
			heading = d
			queued = -1
			moving = true
			return [Event.WRONG_WAY] if m == RoadMap.Move.WRONG_WAY else []
	moving = false
	return [Event.WAITING]
