## Rahim Chacha's night shift (phase 8): ten at night to two in the
## morning. Which lanes have no street lights (the same ones every night:
## potholes there can catch the rickshaw out), and where the night guards
## stand with their whistles (each asks a question once a night). The day
## itself (day.gd) does the rest: fewer passengers, higher fares, more in a
## hurry, one tea stall still open, more tiring. No drawing, testable.
extends RefCounted

const RoadMap = preload("res://scripts/rules/road_map.gd")
const PATH := "res://content/night.json"


static func _noise(p: Vector2i, salt: int) -> float:
	return float(absi(hash(Vector3i(p.x, p.y, salt))) % 1000) / 1000.0


## The ordinary lanes without street lights: about `share` of them.
static func dark_tiles(map: RoadMap, share: float) -> Dictionary:
	var out := {}
	for p in map.roads():
		if map.kind_at(p) == RoadMap.Kind.ROAD and _noise(p, 77) < share:
			out[p] = true
	return out


## Where the night guards stand: `n` junction-like ordinary lanes, spread
## out, the same every night.
static func guard_tiles(map: RoadMap, n: int) -> Array:
	var spots := map.roads().filter(func(p): return map.kind_at(p) == RoadMap.Kind.ROAD)
	spots.sort_custom(func(a, b): return _noise(a, 91) < _noise(b, 91))
	var out := []
	for p in spots:
		if out.size() >= n:
			break
		if out.any(func(q): return absi(q.x - p.x) + absi(q.y - p.y) < 8):
			continue
		out.append(p)
	return out


static func questions() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed.get("guards", []) if typeof(parsed) == TYPE_DICTIONARY else []
