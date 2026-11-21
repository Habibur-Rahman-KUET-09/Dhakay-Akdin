## The traffic lights at signal junctions: a pole on the pavement with a
## head facing each way into the junction, red over green, lit by the same
## rule the drivers obey (rules/signals.gd).
extends Node3D

const RoadMap = preload("res://scripts/rules/road_map.gd")
const Signals = preload("res://scripts/rules/signals.gd")
const City = preload("res://scripts/world/city.gd")

## [tile, heading of the traffic it faces, red lamp, green lamp, lit red?]
var _heads: Array = []
var _mats := {}


static func _mat(colour: Color, lit: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour if lit else colour.darkened(0.75)
	if lit:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = 2.0
	return m


func setup(map: RoadMap) -> void:
	_mats = {
		"red_on": _mat(Color("FF3B2F"), true), "red_off": _mat(Color("FF3B2F"), false),
		"green_on": _mat(Color("2EE86B"), true), "green_off": _mat(Color("2EE86B"), false),
	}
	var pole_mat := _mat(Color("8A8A8A"), true)
	pole_mat.emission_enabled = false
	pole_mat.albedo_color = Color("3A3A3A")
	for p in map.roads():
		if map.kind_at(p) != RoadMap.Kind.SIGNAL:
			continue
		var base := City._side(map, p)
		var pole := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.1
		c.bottom_radius = 0.12
		c.height = 4.6
		pole.mesh = c
		pole.material_override = pole_mat
		pole.position = base + Vector3(0, 2.3, 0)
		add_child(pole)
		for heading in 4:
			# The head faces drivers coming in going `heading`.
			var toward := -Vector3(RoadMap.DX[heading], 0, RoadMap.DY[heading])
			var at := base + Vector3(0, 4.0 + (0.0 if heading % 2 == 0 else 0.9), 0) + toward * 0.22
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.36, 0.8, 0.36)
			box.mesh = bm
			box.material_override = pole_mat
			box.position = at - toward * 0.05
			add_child(box)
			var lamps := []
			for k in 2:
				var lamp := MeshInstance3D.new()
				var disc := CylinderMesh.new()
				disc.top_radius = 0.12
				disc.bottom_radius = 0.12
				disc.height = 0.06
				disc.radial_segments = 12
				lamp.mesh = disc
				lamp.position = at + toward * 0.15 + Vector3(0, 0.18 if k == 0 else -0.18, 0)
				lamp.basis = Basis(Vector3(1, 0, 0) if heading % 2 == 0 else Vector3(0, 0, 1), PI / 2)
				add_child(lamp)
				lamps.append(lamp)
			_heads.append([p, heading, lamps[0], lamps[1], null])


func update_lights(clock: float, cycle: float) -> void:
	for h in _heads:
		var red := Signals.red_for(h[0], h[1], clock, cycle)
		if h[4] == red:
			continue
		h[4] = red
		(h[2] as MeshInstance3D).material_override = _mats.red_on if red else _mats.red_off
		(h[3] as MeshInstance3D).material_override = _mats.green_off if red else _mats.green_on
