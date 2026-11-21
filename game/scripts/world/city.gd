## Builds the 3D town from a road map: roads, buildings, trees, the
## roundabouts, tea stalls, signals, home and the names of real places.
## Placeholder shapes for now (§১০); real models can replace them later.
## A few big meshes and multimeshes, so cheap phones keep up.
extends RefCounted

const RoadMap = preload("res://scripts/rules/road_map.gd")
const Look = preload("res://scripts/ui/look.gd")

## World units per map tile.
const T := 4.0

const ASPHALT := Color("8A8F96")
const LANE_ONE_WAY := Color("A2A8AF")
const MAIN := Color("50555E")
const WATER := Color("5FA8DE")
const GROUND := Color("E3D3B1")
const DASH := Color("F6D365")
const MARK := Color("F4F4F4")
const WALLS := [
	Color("D9668F"), Color("5FAE86"), Color("E8B53A"), Color("5B97C9"),
	Color("E08A63"), Color("C9BFAE"), Color("8F8A84"), Color("A8C25E"),
	Color("B57FB3"), Color("D9D2C3"),
]


static func centre(p: Vector2i, y := 0.0) -> Vector3:
	return Vector3((p.x + 0.5) * T, y, (p.y + 0.5) * T)


## A stable pseudo-random number in [0, 1) for a tile.
static func noise(p: Vector2i, salt := 0) -> float:
	var h := (p.x * 73856093) ^ (p.y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 10007) / 10007.0


static func build(map: RoadMap, lang: String) -> Node3D:
	var town := Node3D.new()
	town.name = "Town"
	town.add_child(_ground(map))
	town.add_child(_roads(map))
	town.add_child(_buildings(map))
	_features(map, town)
	for pl in map.places:
		town.add_child(_sign(RoadMap.place_name(pl, lang), centre(pl.at, 7.0), 46))
	return town


static func _material(vertex_colours := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = vertex_colours
	m.roughness = 1.0
	return m


static func _ground(map: RoadMap) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(map.width * T + 200, map.height * T + 200)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var m := _material(false)
	m.albedo_color = GROUND
	mi.material_override = m
	mi.position = Vector3(map.width * T / 2, 0, map.height * T / 2)
	return mi


static func _quad(st: SurfaceTool, r: Rect2, y: float, c: Color) -> void:
	var a := Vector3(r.position.x, y, r.position.y)
	var b := Vector3(r.end.x, y, r.position.y)
	var cc := Vector3(r.end.x, y, r.end.y)
	var d := Vector3(r.position.x, y, r.end.y)
	for v in [a, b, cc, a, cc, d]:
		st.set_color(c)
		st.set_normal(Vector3.UP)
		st.add_vertex(v)


static func _tri(st: SurfaceTool, pts: Array, y: float, c: Color) -> void:
	for v in pts:
		st.set_color(c)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(v.x, y, v.y))


## All road surfaces and markings in one mesh.
static func _roads(map: RoadMap) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const INSET := 0.9
	for p in map.roads():
		var o := Vector2(p.x * T, p.y * T)
		var tile := Rect2(o, Vector2(T, T))
		var k := map.kind_at(p)
		var one := map.one_way(p)
		if k == RoadMap.Kind.MAIN_ROAD:
			_quad(st, tile, 0.02, MAIN)
			var ew := map.is_road(RoadMap.step(p, RoadMap.E)) and map.is_road(RoadMap.step(p, RoadMap.W))
			var ns := map.is_road(RoadMap.step(p, RoadMap.N)) and map.is_road(RoadMap.step(p, RoadMap.S))
			if ew != ns:
				var dash := Rect2(o + Vector2(T * 0.3, T * 0.46), Vector2(T * 0.4, T * 0.08)) if ew \
					else Rect2(o + Vector2(T * 0.46, T * 0.3), Vector2(T * 0.08, T * 0.4))
				_quad(st, dash, 0.04, DASH)
			continue
		# A lane is narrower than its tile, joined to the roads beside it.
		var colour := LANE_ONE_WAY if one >= 0 else ASPHALT
		_quad(st, tile.grow(-INSET), 0.02, colour)
		for d in 4:
			if not map.is_road(RoadMap.step(p, d)):
				continue
			var r := Rect2(o + Vector2(INSET, 0), Vector2(T - 2 * INSET, INSET))
			if d == RoadMap.S:
				r = Rect2(o + Vector2(INSET, T - INSET), Vector2(T - 2 * INSET, INSET))
			elif d == RoadMap.E:
				r = Rect2(o + Vector2(T - INSET, INSET), Vector2(INSET, T - 2 * INSET))
			elif d == RoadMap.W:
				r = Rect2(o + Vector2(0, INSET), Vector2(INSET, T - 2 * INSET))
			_quad(st, r, 0.02, colour)
		if k == RoadMap.Kind.FLOOD:
			_quad(st, tile.grow(-0.4), 0.05, WATER)
		if one >= 0:
			_arrow(st, o + Vector2(T, T) / 2, one)
	var mi := MeshInstance3D.new()
	mi.name = "Roads"
	mi.mesh = st.commit()
	mi.material_override = _material()
	return mi


## A one-way lane's direction painted on the road.
static func _arrow(st: SurfaceTool, c: Vector2, d: int) -> void:
	var f := Vector2(RoadMap.DX[d], RoadMap.DY[d])
	var s := Vector2(-f.y, f.x)
	var tip := c + f * 1.1
	var base := c + f * 0.2
	_tri(st, [tip, base + s * 0.6, base - s * 0.6], 0.05, MARK)
	_tri(st, [base + s * 0.2, c - f * 1.0 + s * 0.2, c - f * 1.0 - s * 0.2], 0.05, MARK)
	_tri(st, [base + s * 0.2, c - f * 1.0 - s * 0.2, base - s * 0.2], 0.05, MARK)


## Buildings along the streets, lower ones and trees behind, water tanks
## on some roofs: a few multimeshes.
static func _buildings(map: RoadMap) -> Node3D:
	var house_at: Array[Transform3D] = []
	var house_colour: Array[Color] = []
	var tank_at: Array[Transform3D] = []
	var crown_at: Array[Transform3D] = []
	var crown_colour: Array[Color] = []
	var trunk_at: Array[Transform3D] = []
	for y in map.height:
		for x in map.width:
			var p := Vector2i(x, y)
			if map.kind_at(p) != RoadMap.Kind.BLOCK:
				continue
			var street := false
			for d in 4:
				if map.is_road(RoadMap.step(p, d)):
					street = true
			if not street and noise(p) < 0.3:
				var s := 0.8 + noise(p, 5) * 0.5
				crown_at.append(Transform3D(Basis.from_scale(Vector3(s, s, s)), centre(p, 2.6 * s)))
				crown_colour.append(Color("4E9A52").lerp(Color("2F7A3A"), noise(p, 6)))
				trunk_at.append(Transform3D(Basis(), centre(p, 1.0)))
				continue
			var floors := 1 + int(noise(p, 1) * (4 if street else 2))
			var h := 0.6 + floors * 1.1
			var size := T * (0.86 if noise(p, 4) < 0.7 else 0.7)
			house_at.append(Transform3D(Basis.from_scale(Vector3(size, h, size)), centre(p, h / 2)))
			house_colour.append(WALLS[int(noise(p, 2) * WALLS.size())])
			if noise(p, 3) < 0.35:
				tank_at.append(Transform3D(Basis(), centre(p, h) + Vector3(0.8, 0.45, -0.6)))
	var node := Node3D.new()
	node.name = "Buildings"
	node.add_child(_multi(BoxMesh.new(), house_at, house_colour))
	var tank := CylinderMesh.new()
	tank.top_radius = 0.45
	tank.bottom_radius = 0.45
	tank.height = 0.9
	tank.radial_segments = 8
	node.add_child(_multi(tank, tank_at, [], Color("3A3F47")))
	var crown := SphereMesh.new()
	crown.radius = 1.4
	crown.height = 2.4
	crown.radial_segments = 8
	crown.rings = 4
	node.add_child(_multi(crown, crown_at, crown_colour))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.22
	trunk.height = 2.0
	trunk.radial_segments = 6
	node.add_child(_multi(trunk, trunk_at, [], Color("7A5230")))
	return node


## A multimesh: one copy per transform, coloured from `colours` or `colour`.
static func _multi(mesh: Mesh, at: Array[Transform3D], colours: Array, colour := Color.WHITE) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = at.size()
	for i in at.size():
		mm.set_instance_transform(i, at[i])
		mm.set_instance_color(i, colours[i] if i < colours.size() else colour)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _material()
	return mi


static func _box(size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	var m := _material(false)
	m.albedo_color = colour
	mi.material_override = m
	mi.position = at
	return mi


static func _cylinder(radius: float, height: float, at: Vector3, colour: Color) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = c
	var m := _material(false)
	m.albedo_color = colour
	mi.material_override = m
	mi.position = at
	return mi


## Roundabout islands, tea stalls, signals and home.
static func _features(map: RoadMap, town: Node3D) -> void:
	for y in map.height:
		for x in map.width:
			var p := Vector2i(x, y)
			var k := map.kind_at(p)
			if k == RoadMap.Kind.ISLAND:
				town.add_child(_box(Vector3(T, 0.04, T), centre(p, 0.02), MAIN))
				town.add_child(_cylinder(T * 0.45, 0.5, centre(p, 0.25), Color("6DBE6F")))
				town.add_child(_cylinder(0.25, 4.0, centre(p, 2.0), Color("EDE6DA")))
			elif k == RoadMap.Kind.TEA:
				var side := _side(map, p)
				town.add_child(_box(Vector3(1.4, 1.6, 1.4), side + Vector3(0, 0.8, 0), Look.PARROT))
				town.add_child(_box(Vector3(1.9, 0.12, 1.9), side + Vector3(0, 1.75, 0), Look.YELLOW))
				town.add_child(_sign("চা", side + Vector3(0, 2.6, 0), 40, Look.PARROT))
			elif k == RoadMap.Kind.SIGNAL:
				var side := _side(map, p)
				town.add_child(_cylinder(0.1, 3.4, side + Vector3(0, 1.7, 0), Color("333333")))
				town.add_child(_box(Vector3(0.4, 1.0, 0.4), side + Vector3(0, 3.6, 0), Color("222222")))
				town.add_child(_box(Vector3(0.42, 0.28, 0.42), side + Vector3(0, 3.85, 0), Look.VERMILION))
				town.add_child(_box(Vector3(0.42, 0.28, 0.42), side + Vector3(0, 3.35, 0), Look.PARROT))
			elif k == RoadMap.Kind.HOME:
				var side := _side(map, p)
				town.add_child(_box(Vector3(1.8, 2.0, 1.8), side + Vector3(0, 1.0, 0), Look.MAGENTA))
				town.add_child(_sign("বাড়ি", side + Vector3(0, 3.0, 0), 40, Look.MAGENTA))


## A spot on the edge of a road tile, beside a building, for things that
## stand by the road.
static func _side(map: RoadMap, p: Vector2i) -> Vector3:
	for d in 4:
		if not map.is_road(RoadMap.step(p, d)):
			return centre(p) + Vector3(RoadMap.DX[d], 0, RoadMap.DY[d]) * (T * 0.5 - 0.6)
	return centre(p) + Vector3(T * 0.3, 0, T * 0.3)


## A name floating over the town, always facing the camera, hidden when far.
static func _sign(text: String, at: Vector3, size := 46, colour := Look.OUTLINE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Look.font(Look.BOLD)
	l.font_size = size
	l.outline_size = 14
	l.modulate = colour
	l.outline_modulate = Look.CREAM
	l.pixel_size = 0.02
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at
	l.visibility_range_end = 70.0
	return l
