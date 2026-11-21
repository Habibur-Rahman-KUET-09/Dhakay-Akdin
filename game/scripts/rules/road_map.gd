## The road grid of one area, read from content/maps/<id>.json: rows of
## characters (the legend is in the file). tool/build_map.py makes it from
## the area's real streets (OpenStreetMap). No drawing here, so the rules
## can be tested (docs/DETAILED_DESIGN.md §৪.১).
extends RefCounted

const SELF := "res://scripts/rules/road_map.gd"

## Compass directions on the grid; y grows southwards.
enum { N, E, S, W }
const DX := [0, 1, 0, -1]
const DY := [-1, 0, 1, 0]

enum Kind { BLOCK, ISLAND, ROAD, MAIN_ROAD, FLOOD, TEA, SIGNAL, HOME }
enum Move { BLOCKED, OK, WRONG_WAY }

const TILES := {
	"#": [Kind.BLOCK, -1], "O": [Kind.ISLAND, -1],
	".": [Kind.ROAD, -1], "M": [Kind.MAIN_ROAD, -1],
	"n": [Kind.ROAD, N], "e": [Kind.ROAD, E], "s": [Kind.ROAD, S], "w": [Kind.ROAD, W],
	"W": [Kind.FLOOD, -1], "T": [Kind.TEA, -1], "P": [Kind.SIGNAL, -1], "H": [Kind.HOME, -1],
}

var id := ""
var width := 0
var height := 0
## Where the day starts.
var home := Vector2i(-1, -1)
## Real places passengers ask for: {id, names: {bn, en}, at: Vector2i}.
var places: Array = []
## Whom the map data must be credited to, shown on screen.
var credit := ""
var _kind := PackedByteArray()
var _one_way := PackedInt32Array()


static func opposite(d: int) -> int:
	return (d + 2) % 4


static func step(p: Vector2i, d: int) -> Vector2i:
	return p + Vector2i(DX[d], DY[d])


## Turning right (1), back (2) or left (3) from heading d.
static func turn(d: int, by: int) -> int:
	return (d + by) % 4


## Builds a map from its rows, or returns null and reports why.
static func parse(map_id: String, rows: PackedStringArray, place_list: Array = [], credit_text := ""):
	var m = load(SELF).new()
	m.id = map_id
	m.height = rows.size()
	m.width = rows[0].length() if rows.size() > 0 else 0
	m.credit = credit_text
	m._kind.resize(m.width * m.height)
	m._one_way.resize(m.width * m.height)
	for y in m.height:
		if rows[y].length() != m.width:
			push_error("%s: rows have different lengths" % map_id)
			return null
		for x in m.width:
			var ch := rows[y][x]
			if not TILES.has(ch):
				push_error("%s: unknown tile '%s' at %d,%d" % [map_id, ch, x, y])
				return null
			m._kind[y * m.width + x] = TILES[ch][0]
			m._one_way[y * m.width + x] = TILES[ch][1]
			if ch == "H":
				m.home = Vector2i(x, y)
	if m.home.x < 0:
		push_error("%s: no home tile (H)" % map_id)
		return null
	for p in place_list:
		if not m.is_road(p.at):
			push_error("%s: place %s is not on a road" % [map_id, p.id])
			return null
	m.places = place_list
	return m


static func from_json(text: String):
	var j = JSON.parse_string(text)
	if typeof(j) != TYPE_DICTIONARY:
		push_error("map: not a JSON object")
		return null
	var list := []
	for p in j.get("places", []):
		list.append({"id": p.id, "names": p.name, "at": Vector2i(int(p.x), int(p.y))})
	return parse(j.id, PackedStringArray(j.rows), list, j.get("credit", ""))


static func load_area(area: String):
	var f := FileAccess.open("res://content/maps/%s.json" % area, FileAccess.READ)
	return from_json(f.get_as_text()) if f else null


func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func kind_at(p: Vector2i) -> int:
	return _kind[p.y * width + p.x] if inside(p) else Kind.BLOCK


## For a one-way lane, the only direction of travel; -1 when two-way.
func one_way(p: Vector2i) -> int:
	return _one_way[p.y * width + p.x] if inside(p) else -1


func is_road(p: Vector2i) -> bool:
	var k := kind_at(p)
	return k != Kind.BLOCK and k != Kind.ISLAND


## Moving from p one tile in d: travelling against a one-way lane, on the
## tile being left or the one being entered, is wrong way. Crossing a lane,
## or turning into or out of it its own way, is fine.
func move(p: Vector2i, d: int) -> int:
	var to := step(p, d)
	if not is_road(to):
		return Move.BLOCKED
	if one_way(p) == opposite(d) or one_way(to) == opposite(d):
		return Move.WRONG_WAY
	return Move.OK


func roads() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in height:
		for x in width:
			if is_road(Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out


## Legal distance from p to every road tile it can reach.
func distances_from(from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	var i := 0
	while i < queue.size():
		var p := queue[i]
		i += 1
		for d in 4:
			if move(p, d) != Move.OK:
				continue
			var q := step(p, d)
			if dist.has(q):
				continue
			dist[q] = dist[p] + 1
			queue.append(q)
	return dist


## The shortest legal route, tile by tile (start excluded), or null when
## `to` cannot be reached without going the wrong way.
func route(from: Vector2i, to: Vector2i):
	if from == to:
		return []
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	var i := 0
	while i < queue.size():
		var p := queue[i]
		i += 1
		for d in 4:
			if move(p, d) != Move.OK:
				continue
			var q := step(p, d)
			if prev.has(q):
				continue
			prev[q] = p
			if q == to:
				var path: Array[Vector2i] = [q]
				var c := p
				while c != from:
					path.push_front(c)
					c = prev[c]
				return path
			queue.append(q)
	return null


## Tiles on the shortest legal route, or -1.
func distance(from: Vector2i, to: Vector2i) -> int:
	var r = route(from, to)
	return -1 if r == null else r.size()


static func place_name(place: Dictionary, lang: String) -> String:
	return place.names.get(lang, place.names.get("en", place.id))
