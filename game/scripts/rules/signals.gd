## Traffic lights at the signal tiles: one road through the junction has
## green while the other has red, swapping every half cycle. Each junction
## starts at its own point in the cycle.
extends RefCounted

const RoadMap = preload("res://scripts/rules/road_map.gd")


static func _offset(p: Vector2i) -> float:
	return float(absi(p.x * 7 + p.y * 13) % 12)


## Whether travelling with `heading` into the signal at p is against red at
## time `t` (seconds), with a full cycle of `cycle` seconds.
static func red_for(p: Vector2i, heading: int, t: float, cycle := 12.0) -> bool:
	var north_south_green := fmod(t + _offset(p), cycle) < cycle / 2.0
	var going_north_south := heading == RoadMap.N or heading == RoadMap.S
	return going_north_south != north_south_green
