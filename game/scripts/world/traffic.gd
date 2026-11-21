## The rest of the street: rickshaws (some with passengers), CNGs and buses
## driving on the left, people walking on the pavements. They use the same
## driving rules as Rahim Chacha and turn at random; buses keep to the main
## roads. One multimesh per kind, so the whole crowd is a handful of draw
## calls. They do not get in his way yet (that is week 4's jam).
extends Node3D

const RoadMap = preload("res://scripts/rules/road_map.gd")
const Driver = preload("res://scripts/rules/driver.gd")
const City = preload("res://scripts/world/city.gd")
const Models = preload("res://scripts/world/models.gd")
const Signals = preload("res://scripts/rules/signals.gd")

## Sideways from the middle of the road: vehicles keep left; people walk
## on the pavement.
## Small vehicles keep 1 m left of the middle, clear of the oncoming lane
## and of rickshaws parked at the edge; buses (main roads only) 1.4 m.
const KEEP_LEFT := 1.0
const BUS_LEFT := 1.4
const PAVEMENT_SIDE := City.T / 2 + City.PAVEMENT * 0.5

## Colours swapped into the models (indices 0–7 bright, 8–15 darker).
const PALETTE := [
	"F6B800", "2D8BD6", "2E9E6B", "E2432A", "C2185B", "F2F2F2", "6A1B9A", "0F7C8C",
	"8B1A3A", "1F4F2F", "1C3E7B", "3E2A20", "2B2B2B", "6D6A64", "9E2A1E", "37474F",
]

var map: RoadMap
var rng := RandomNumberGenerator.new()
var _agents: Array = []
var _roads: Array = []
var _mains: Array = []
## The rickshaw the crowd gathers round (set by the scene).
var focus: Driver
## Agents further than this (tiles) are moved back near the focus, so the
## street round the player is always busy.
const NEAR := 13
var _recycle_left := 0.0
## The day's clock and the signal cycle, set by the scene, for red lights.
var clock := 0.0
var signal_cycle := 12.0
## How long before a vehicle stuck at a crossing pushes through anyway.
const CROSSING_PATIENCE := 3.0
## Who is where on the road this frame: cell -> [[heading, progress, length]].
var _lanes := {}
## Vehicle lengths in tiles (a tile is 6 m).
const LENGTH := {"rickshaw": 0.45, "rickshaw_full": 0.45, "cng": 0.45, "bus": 1.5, "player": 0.45}


func setup(road_map: RoadMap, avoid: Vector2i, counts := {"rickshaw": 20, "rickshaw_full": 14, "cng": 9, "bus": 4, "person": 60}) -> void:
	map = road_map
	rng.seed = 2026
	var roads := map.roads().filter(func(p): return absi(p.x - avoid.x) + absi(p.y - avoid.y) > 3)
	var mains := roads.filter(func(p): return map.kind_at(p) == RoadMap.Kind.MAIN_ROAD)
	_roads = roads
	_mains = mains
	var palette := PackedColorArray()
	for hex in PALETTE:
		palette.append(Color(hex))
	var material := Models.traffic_material(palette)
	# Rickshaws come in every style of decoration: one multimesh each.
	var meshes := {
		"rickshaw": [], "rickshaw_full": [],
		"cng": [Models.cng()], "bus": [Models.bus()], "person": [Models.person()],
	}
	for style in Models.STYLES:
		meshes.rickshaw.append(Models.rickshaw(false, true, style))
		meshes.rickshaw_full.append(Models.rickshaw(true, true, style))
	var speeds := {"rickshaw": [0.8, 1.2], "rickshaw_full": [0.7, 1.0], "cng": [1.7, 2.2], "bus": [1.3, 1.6], "person": [0.16, 0.26]}
	for kind in counts:
		var variants: Array = meshes[kind]
		var total: int = counts[kind]
		for v in variants.size():
			var count: int = total / variants.size() + (1 if v < total % variants.size() else 0)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			# Colours on (all white): without them some phones (Mali) multiply
			# the paint by black.
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = variants[v]
			mm.instance_count = count
			for i in count:
				mm.set_instance_color(i, Color.WHITE)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = material
			# They move all over the map: never cull the whole set.
			mmi.custom_aabb = AABB(Vector3(-50, -5, -50), Vector3(map.width * City.T + 100, 30, map.height * City.T + 100))
			add_child(mmi)
			var pool: Array = mains if kind == "bus" and not mains.is_empty() else roads
			_spawn(kind, mm, count, speeds[kind], pool)


## Puts count agents of a kind on the road, copies 0..count-1 of mm.
func _spawn(kind: String, mm: MultiMesh, count: int, speed: Array, pool: Array) -> void:
	for i in count:
		var start: Vector2i = pool[rng.randi() % pool.size()]
		var d := Driver.new(map, rng.randf_range(speed[0], speed[1]), start)
		var side := KEEP_LEFT
		if kind == "bus":
			side = BUS_LEFT
		elif kind == "person":
			side = PAVEMENT_SIDE * (1.0 if rng.randf() < 0.5 else -1.0)
		var a_colour := rng.randi_range(0, 7)
		var b_colour := rng.randi_range(8, 15) if kind != "bus" else rng.randi_range(0, 7)
		var agent := {
			"kind": kind, "driver": d, "mm": mm, "i": i, "side": side,
			"phase": rng.randf() * TAU, "a": a_colour, "b": b_colour, "at": Vector3.ZERO, "yaw": 0.0,
			"speed": d.speed, "wait": 0.0,
		}
		_agents.append(agent)
		_place(agent, 0.0, true)


func _process(dt: float) -> void:
	_recycle_left -= dt
	if _recycle_left <= 0.0 and focus != null:
		_recycle_left = 0.5
		_recycle()
	_lanes.clear()
	for a in _agents:
		if a.kind != "person":
			_occupy(a.driver, LENGTH[a.kind])
	if focus != null:
		_occupy(focus, LENGTH.player)
	for a in _agents:
		var d: Driver = a.driver
		if a.kind != "person":
			# Keep a gap to whoever is ahead in the same lane: slow, then stop.
			var gap := gap_ahead(d, LENGTH[a.kind])
			var go := clampf((gap - 0.12) / 0.5, 0.0, 1.0)
			# Near the end of a tile: stop for red, and for anyone crossing the
			# junction ahead (but not forever, or the town would lock up).
			if d.progress > 0.45:
				if red_ahead(d):
					go = 0.0
				elif crossing_blocked(d):
					a.wait += dt
					if a.wait < CROSSING_PATIENCE:
						go = 0.0
				else:
					a.wait = 0.0
			d.speed = a.speed * go
		var events := d.update(dt)
		if events.has(Driver.Event.ENTERED):
			_steer(a, rng.randf() < 0.35)
		if not d.moving:
			_steer(a, true)
		_place(a, dt)


## Moves agents that drifted far from the focus to a road 6–12 tiles from
## it, where the haze hides them appearing.
func _recycle() -> void:
	var me := focus.cell
	for a in _agents:
		var d: Driver = a.driver
		if absi(d.cell.x - me.x) + absi(d.cell.y - me.y) <= NEAR:
			continue
		var pool: Array = _mains if a.kind == "bus" and not _mains.is_empty() else _roads
		for attempt in 12:
			var p: Vector2i = pool[rng.randi() % pool.size()]
			var far := absi(p.x - me.x) + absi(p.y - me.y)
			if far >= 6 and far <= 12:
				d.cell = p
				d.progress = 0.0
				d.moving = true
				_steer(a, true)
				_place(a, 0.0, true)
				break


func _occupy(d: Driver, length: float) -> void:
	if not _lanes.has(d.cell):
		_lanes[d.cell] = []
	_lanes[d.cell].append([d.heading, d.progress, length])


## Free road ahead of d in its lane, in tiles (bumper to bumper): anyone
## heading the same way in its tile or the next two. INF when clear.
func gap_ahead(d: Driver, length := 0.45) -> float:
	var best := INF
	var cell := d.cell
	for step in 3:
		for o in _lanes.get(cell, []):
			if o[0] != d.heading:
				continue
			var ahead: float = step + o[1] - d.progress
			if ahead <= 0.001:
				continue
			best = minf(best, ahead - (o[2] + length) / 2.0)
		if best < INF:
			return best
		cell = RoadMap.step(cell, d.heading)
	return best


## Someone in the tile ahead of d going across its way.
func crossing_blocked(d: Driver) -> bool:
	for o in _lanes.get(d.next_cell(), []):
		if o[0] % 2 != d.heading % 2:
			return true
	return false


## The tile ahead of d is a signal showing red to d.
func red_ahead(d: Driver) -> bool:
	var next := d.next_cell()
	return map.kind_at(next) == RoadMap.Kind.SIGNAL and Signals.red_for(next, d.heading, clock, signal_cycle)


## A vehicle waiting right behind d, for an impatient horn; else INF.
func behind(d: Driver) -> Vector3:
	for a in _agents:
		if a.kind == "person":
			continue
		var o: Driver = a.driver
		if o.heading != d.heading:
			continue
		var back: float = d.progress - o.progress
		if o.cell == RoadMap.step(d.cell, RoadMap.opposite(d.heading)):
			back += 1.0
		elif o.cell != d.cell:
			continue
		if back > 0.0 and back < 1.2:
			return a.at
	return Vector3.INF


## A spot near the focus where something is driving, for a horn.
func somewhere_near(max_tiles: int) -> Vector3:
	var picks := []
	for a in _agents:
		if a.kind == "person" or focus == null:
			continue
		var d: Driver = a.driver
		if absi(d.cell.x - focus.cell.x) + absi(d.cell.y - focus.cell.y) <= max_tiles:
			picks.append(a)
	if picks.is_empty():
		return Vector3.INF
	var a: Dictionary = picks[rng.randi() % picks.size()]
	return a.at


## Which kind is at a spot returned by somewhere_near (for its horn).
func kind_at_spot(spot: Vector3) -> String:
	for a in _agents:
		if a.at == spot:
			return a.kind
	return ""


## At a tile: buses stay on main roads; the others sometimes turn, and
## always pick a way on when stopped.
func _steer(a: Dictionary, turn: bool) -> void:
	var d: Driver = a.driver
	var options := []
	for t in [Driver.AHEAD, Driver.RIGHT, Driver.LEFT]:
		var dir := RoadMap.turn(d.heading, t)
		if map.move(d.cell, dir) == RoadMap.Move.OK:
			options.append(dir)
	if a.kind == "bus":
		var main := options.filter(func(x): return map.kind_at(RoadMap.step(d.cell, x)) == RoadMap.Kind.MAIN_ROAD)
		if main.has(d.heading):
			return
		options = main
	elif not turn and d.moving:
		return
	if options.is_empty():
		d.heading = RoadMap.opposite(d.heading)
	else:
		d.heading = options[rng.randi() % options.size()]
	d.moving = map.move(d.cell, d.heading) != RoadMap.Move.BLOCKED


func _place(a: Dictionary, dt: float, snap := false) -> void:
	var d: Driver = a.driver
	var pos := d.position()
	var f := Vector3(RoadMap.DX[d.heading], 0, RoadMap.DY[d.heading])
	var left := Vector3(f.z, 0, -f.x)
	var target: Vector3 = Vector3((pos.x + 0.5) * City.T, 0, (pos.y + 0.5) * City.T) + left * a.side
	if a.kind == "person":
		target.y = 0.15
	var yaw := -d.heading * PI / 2
	var k := 1.0 if snap else minf(1.0, dt * 8.0)
	var at: Vector3 = a.at
	a.at = at.lerp(target, k)
	a.yaw = lerp_angle(a.yaw, yaw, k)
	var mm: MultiMesh = a.mm
	mm.set_instance_transform(a.i, Transform3D(Basis(Vector3.UP, a.yaw), a.at))
	var moving := 1.0 if d.moving else 0.0
	mm.set_instance_custom_data(a.i, Color(a.phase, moving, a.a, a.b))
