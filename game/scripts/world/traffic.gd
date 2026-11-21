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

## Sideways from the middle of the road: vehicles keep left; people walk
## on the pavement.
const KEEP_LEFT := 1.4
const PAVEMENT_SIDE := City.T / 2 + City.PAVEMENT * 0.5

## Colours swapped into the models (indices 0–7 bright, 8–15 darker).
const PALETTE := [
	"F6B800", "2D8BD6", "2E9E6B", "E2432A", "C2185B", "F2F2F2", "6A1B9A", "0F7C8C",
	"8B1A3A", "1F4F2F", "1C3E7B", "3E2A20", "2B2B2B", "6D6A64", "9E2A1E", "37474F",
]

var map: RoadMap
var rng := RandomNumberGenerator.new()
var _agents: Array = []


func setup(road_map: RoadMap, avoid: Vector2i, counts := {"rickshaw": 22, "rickshaw_full": 14, "cng": 10, "bus": 5, "person": 50}) -> void:
	map = road_map
	rng.seed = 2026
	var roads := map.roads().filter(func(p): return absi(p.x - avoid.x) + absi(p.y - avoid.y) > 3)
	var mains := roads.filter(func(p): return map.kind_at(p) == RoadMap.Kind.MAIN_ROAD)
	var palette := PackedColorArray()
	for hex in PALETTE:
		palette.append(Color(hex))
	var material := Models.traffic_material(palette)
	var meshes := {
		"rickshaw": Models.rickshaw(false),
		"rickshaw_full": Models.rickshaw(true),
		"cng": Models.cng(),
		"bus": Models.bus(),
		"person": Models.person(),
	}
	var speeds := {"rickshaw": [0.8, 1.2], "rickshaw_full": [0.7, 1.0], "cng": [1.7, 2.2], "bus": [1.3, 1.6], "person": [0.16, 0.26]}
	for kind in counts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[kind]
		mm.instance_count = counts[kind]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material
		# They move all over the map: never cull the whole set.
		mmi.custom_aabb = AABB(Vector3(-50, -5, -50), Vector3(map.width * City.T + 100, 30, map.height * City.T + 100))
		add_child(mmi)
		var pool: Array = mains if kind == "bus" and not mains.is_empty() else roads
		for i in counts[kind]:
			var start: Vector2i = pool[rng.randi() % pool.size()]
			var d := Driver.new(map, rng.randf_range(speeds[kind][0], speeds[kind][1]), start)
			var side := KEEP_LEFT if kind != "person" else PAVEMENT_SIDE * (1.0 if rng.randf() < 0.5 else -1.0)
			var a_colour := rng.randi_range(0, 7)
			var b_colour := rng.randi_range(8, 15) if kind != "bus" else rng.randi_range(0, 7)
			var agent := {
				"kind": kind, "driver": d, "mm": mm, "i": i, "side": side,
				"phase": rng.randf() * TAU, "a": a_colour, "b": b_colour, "at": Vector3.ZERO, "yaw": 0.0,
			}
			_agents.append(agent)
			_place(agent, 0.0, true)


func _process(dt: float) -> void:
	for a in _agents:
		var d: Driver = a.driver
		var events := d.update(dt)
		if events.has(Driver.Event.ENTERED):
			_steer(a, rng.randf() < 0.35)
		if not d.moving:
			_steer(a, true)
		_place(a, dt)


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
