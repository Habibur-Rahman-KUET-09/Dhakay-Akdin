## The rest of the street: rickshaws, CNGs and buses driving on the left,
## people walking on the pavements. They use the same driving rules as
## Rahim Chacha and turn at random; buses keep to the main roads. They do
## not get in his way yet (that is week 4's jam).
extends Node3D

const RoadMap = preload("res://scripts/rules/road_map.gd")
const Driver = preload("res://scripts/rules/driver.gd")
const City = preload("res://scripts/world/city.gd")
const Vehicles = preload("res://scripts/world/vehicles.gd")

## Sideways from the middle of the road: vehicles keep left; people walk
## on the pavement.
const KEEP_LEFT := 1.3
const PAVEMENT_SIDE := City.T / 2 + City.PAVEMENT * 0.5

var map: RoadMap
var rng := RandomNumberGenerator.new()
var _agents: Array = []


func setup(road_map: RoadMap, avoid: Vector2i, counts := {"rickshaw": 28, "cng": 10, "bus": 5, "person": 45}) -> void:
	map = road_map
	rng.seed = 2026
	var roads := map.roads().filter(func(p): return absi(p.x - avoid.x) + absi(p.y - avoid.y) > 3)
	var mains := roads.filter(func(p): return map.kind_at(p) == RoadMap.Kind.MAIN_ROAD)
	var material := Vehicles.material()
	var meshes := {
		"rickshaw": [Vehicles.rickshaw(rng, true), Vehicles.rickshaw(rng), Vehicles.rickshaw(rng, true), Vehicles.rickshaw(rng)],
		"cng": [Vehicles.cng(rng), Vehicles.cng(rng)],
		"bus": [Vehicles.bus(rng), Vehicles.bus(rng), Vehicles.bus(rng)],
		"person": [Vehicles.person(rng), Vehicles.person(rng), Vehicles.person(rng), Vehicles.person(rng), Vehicles.person(rng), Vehicles.person(rng)],
	}
	var speeds := {"rickshaw": [0.9, 1.3], "cng": [1.8, 2.3], "bus": [1.4, 1.7], "person": [0.18, 0.28]}
	for kind in counts:
		var pool: Array = mains if kind == "bus" and not mains.is_empty() else roads
		for i in counts[kind]:
			var start: Vector2i = pool[rng.randi() % pool.size()]
			var d := Driver.new(map, rng.randf_range(speeds[kind][0], speeds[kind][1]), start)
			var mi := MeshInstance3D.new()
			var choices: Array = meshes[kind]
			mi.mesh = choices[rng.randi() % choices.size()]
			mi.material_override = material
			mi.visibility_range_end = 70.0 if kind == "person" else 110.0
			add_child(mi)
			var side := KEEP_LEFT if kind != "person" else PAVEMENT_SIDE * (1.0 if rng.randf() < 0.5 else -1.0)
			_agents.append({"kind": kind, "driver": d, "node": mi, "side": side, "phase": rng.randf() * TAU})
			_place(_agents.back(), 0.0, true)


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
	var node: Node3D = a.node
	var pos := d.position()
	var f := Vector3(RoadMap.DX[d.heading], 0, RoadMap.DY[d.heading])
	var left := Vector3(f.z, 0, -f.x)
	var target: Vector3 = Vector3((pos.x + 0.5) * City.T, 0, (pos.y + 0.5) * City.T) + left * a.side
	if a.kind == "person":
		target.y = 0.15 + absf(sin(Time.get_ticks_msec() / 180.0 + a.phase)) * 0.05
	var yaw := -d.heading * PI / 2
	if snap:
		node.position = target
		node.rotation.y = yaw
	else:
		node.position = node.position.lerp(target, minf(1.0, dt * 8.0))
		node.rotation.y = lerp_angle(node.rotation.y, yaw, minf(1.0, dt * 8.0))
