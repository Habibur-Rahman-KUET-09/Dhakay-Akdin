## Builds the 3D town from a road map at street scale (1 unit = 1 metre):
## tarmac, pavements, apartment blocks with grilled windows and shop
## shutters, Bangla signboards, electric poles with sagging wires, water
## tanks, trees, roundabouts, tea stalls, signals, home and the names of
## real places. Shapes and textures are made in code for now (§১০); real
## models can replace them later. Few big meshes, so cheap phones keep up.
extends RefCounted

const RoadMap = preload("res://scripts/rules/road_map.gd")
const Look = preload("res://scripts/ui/look.gd")

## Metres per map tile.
const T := 6.0
## Storey height, the pavement between road and building, a window bay.
const FLOOR := 3.0
const PAVEMENT := 0.9
const BAY := 3.0

const TARMAC := Color("6E7178")
const MAIN := Color("55585F")
const PAVING := Color("B9B1A3")
const WATER := Color("5E8FA8")
const GROUND := Color("C9B48E")
const DASH := Color("E9D27A")
const MARK := Color("EEEEEE")
## Dhaka plaster: whitewash, cream, pale pastels, some bare grey concrete.
const WALLS := [
	Color("EDE7DA"), Color("E8DCC2"), Color("D9C9A8"), Color("C9CCC4"),
	Color("E6C9B5"), Color("CFE0D2"), Color("D8D3E6"), Color("A9A59C"),
	Color("E9D7A0"), Color("C7D8E4"),
]
const SIGN_COLOURS := [
	Color("C2185B"), Color("1F6F43"), Color("1C4E9B"), Color("D63A2F"),
	Color("F2B705"), Color("6A1B9A"), Color("0F7C8C"), Color("222222"),
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
	town.add_child(_blocks(map))
	town.add_child(_poles_and_wires(map))
	_features(map, town)
	for pl in map.places:
		var s := _sign(RoadMap.place_name(pl, lang), centre(pl.at, 10.0), 64)
		s.visibility_range_end = 110.0
		town.add_child(s)
	return town


static func _material(colours := true, texture: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = colours
	# The palette is written in sRGB, like every colour picker.
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	if texture:
		m.albedo_texture = texture
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


static func _ground(map: RoadMap) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(map.width * T + 400, map.height * T + 400)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var m := _material(false)
	m.albedo_color = GROUND
	mi.material_override = m
	mi.position = Vector3(map.width * T / 2, -0.02, map.height * T / 2)
	return mi


# --- Textures, drawn once at start --------------------------------------


## One bay of an upper floor: plaster, a window with a steel grill, a sill,
## rain stains. Grey, so each building's colour tints it.
static func _window_texture() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.93, 0.93, 0.92))
	for i in 900:
		var v := rng.randf_range(0.82, 0.95)
		img.set_pixel(rng.randi_range(0, 95), rng.randi_range(0, 95), Color(v, v, v * 0.98))
	img.fill_rect(Rect2i(18, 20, 60, 48), Color(0.17, 0.2, 0.24))
	img.fill_rect(Rect2i(18, 20, 60, 3), Color(0.55, 0.55, 0.53))
	for x in range(22, 78, 7):
		img.fill_rect(Rect2i(x, 20, 2, 48), Color(0.62, 0.62, 0.6))
	for y in [34, 50]:
		img.fill_rect(Rect2i(18, y, 60, 2), Color(0.62, 0.62, 0.6))
	img.fill_rect(Rect2i(14, 68, 68, 5), Color(0.8, 0.8, 0.78))
	for i in 12:
		img.fill_rect(Rect2i(rng.randi_range(16, 80), 73, 2, rng.randi_range(6, 20)), Color(0.72, 0.72, 0.7))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## One bay of a ground-floor shop: a half-raised shutter over a dark shop.
static func _shop_texture() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.85, 0.83))
	img.fill_rect(Rect2i(6, 14, 84, 82), Color(0.13, 0.12, 0.11))
	for y in range(14, 46, 3):
		img.fill_rect(Rect2i(6, y, 84, 2), Color(0.62, 0.64, 0.66))
	img.fill_rect(Rect2i(6, 45, 84, 2), Color(0.35, 0.35, 0.35))
	# Goods on shelves inside.
	for i in 40:
		var c := Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.8), rng.randf_range(0.35, 0.8))
		img.fill_rect(Rect2i(rng.randi_range(10, 82), rng.randi_range(52, 88), 5, 4), c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# --- Roads and pavements -------------------------------------------------


static func _quad(st: SurfaceTool, r: Rect2, y: float, c: Color) -> void:
	var a := Vector3(r.position.x, y, r.position.y)
	var b := Vector3(r.end.x, y, r.position.y)
	var cc := Vector3(r.end.x, y, r.end.y)
	var d := Vector3(r.position.x, y, r.end.y)
	for v in [a, b, cc, a, cc, d]:
		st.set_color(c)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(v.x, v.z) / BAY)
		st.add_vertex(v)


static func _tri(st: SurfaceTool, pts: Array, y: float, c: Color) -> void:
	for v in pts:
		st.set_color(c)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2.ZERO)
		st.add_vertex(Vector3(v.x, y, v.y))


## Tarmac, painted markings and the pavements along the buildings.
static func _roads(map: RoadMap) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in map.roads():
		var o := Vector2(p.x * T, p.y * T)
		var tile := Rect2(o, Vector2(T, T))
		var k := map.kind_at(p)
		var shade := 0.94 + noise(p, 9) * 0.08
		var base_colour := MAIN if k == RoadMap.Kind.MAIN_ROAD else TARMAC
		_quad(st, tile, 0.0, Color(base_colour.r * shade, base_colour.g * shade, base_colour.b * shade))
		if k == RoadMap.Kind.MAIN_ROAD:
			var ew := map.is_road(RoadMap.step(p, RoadMap.E)) and map.is_road(RoadMap.step(p, RoadMap.W))
			var ns := map.is_road(RoadMap.step(p, RoadMap.N)) and map.is_road(RoadMap.step(p, RoadMap.S))
			if ew != ns:
				var dash := Rect2(o + Vector2(T * 0.25, T * 0.48), Vector2(T * 0.5, 0.15)) if ew \
					else Rect2(o + Vector2(T * 0.48, T * 0.25), Vector2(0.15, T * 0.5))
				_quad(st, dash, 0.02, DASH)
		if k == RoadMap.Kind.FLOOD:
			_quad(st, tile.grow(-0.3), 0.03, WATER)
		var one := map.one_way(p)
		if one >= 0:
			_arrow(st, o + Vector2(T, T) / 2, one)
	# Pavements: a raised strip on every building side that faces a road.
	for y in map.height:
		for x in map.width:
			var p := Vector2i(x, y)
			if map.kind_at(p) != RoadMap.Kind.BLOCK:
				continue
			for d in 4:
				if map.is_road(RoadMap.step(p, d)):
					var v := 0.95 + noise(p, d) * 0.08
					_quad(st, _strip(p, d, PAVEMENT), 0.15, Color(PAVING.r * v, PAVING.g * v, PAVING.b * v))
	var mi := MeshInstance3D.new()
	mi.name = "Roads"
	mi.mesh = st.commit()
	mi.material_override = _material()
	return mi


## The strip of tile p, `width` deep, along its side d.
static func _strip(p: Vector2i, d: int, width: float) -> Rect2:
	var o := Vector2(p.x * T, p.y * T)
	if d == RoadMap.N:
		return Rect2(o, Vector2(T, width))
	if d == RoadMap.S:
		return Rect2(o + Vector2(0, T - width), Vector2(T, width))
	if d == RoadMap.W:
		return Rect2(o, Vector2(width, T))
	return Rect2(o + Vector2(T - width, 0), Vector2(width, T))


## A one-way lane's direction painted on the road.
static func _arrow(st: SurfaceTool, c: Vector2, d: int) -> void:
	var f := Vector2(RoadMap.DX[d], RoadMap.DY[d])
	var s := Vector2(-f.y, f.x)
	var tip := c + f * 1.6
	var base := c + f * 0.4
	_tri(st, [tip, base + s * 0.8, base - s * 0.8], 0.02, MARK)
	_tri(st, [base + s * 0.25, c - f * 1.6 + s * 0.25, c - f * 1.6 - s * 0.25], 0.02, MARK)
	_tri(st, [base + s * 0.25, c - f * 1.6 - s * 0.25, base - s * 0.25], 0.02, MARK)


# --- Buildings -----------------------------------------------------------


## A wall quad from a to b (ground points), between heights y0 and y1, its
## texture repeating every bay across and every storey up, counted down
## from `top` so the windows line up with the floors.
static func _wall(st: SurfaceTool, a: Vector2, b: Vector2, y0: float, y1: float, c: Color, top: float) -> void:
	var u1 := a.distance_to(b) / BAY
	var n := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
	var pts := [
		Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3(b.x, y0, b.y), Vector3(a.x, y0, a.y),
	]
	var uvs := [
		Vector2(0, (top - y1) / FLOOR), Vector2(u1, (top - y1) / FLOOR),
		Vector2(u1, (top - y0) / FLOOR), Vector2(0, (top - y0) / FLOOR),
	]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(c)
		st.set_normal(n)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


## Apartment blocks with shops below where they face a road, signboards
## over the shops, water tanks on some roofs, trees in the open ground.
static func _blocks(map: RoadMap) -> Node3D:
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shops := SurfaceTool.new()
	shops.begin(Mesh.PRIMITIVE_TRIANGLES)
	var roofs := SurfaceTool.new()
	roofs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shop_list = JSON.parse_string(FileAccess.get_file_as_string("res://content/shops.json"))
	var names: Array = shop_list.names
	var node := Node3D.new()
	node.name = "Blocks"
	var board_at: Array[Transform3D] = []
	var board_colour: Array[Color] = []
	var tank_at: Array[Transform3D] = []
	var crown_at: Array[Transform3D] = []
	var crown_colour: Array[Color] = []
	var trunk_at: Array[Transform3D] = []
	for y in map.height:
		for x in map.width:
			var p := Vector2i(x, y)
			if map.kind_at(p) != RoadMap.Kind.BLOCK:
				continue
			var faces: Array[int] = []
			for d in 4:
				if map.is_road(RoadMap.step(p, d)):
					faces.append(d)
			if faces.is_empty() and noise(p) < 0.35:
				var s := 0.9 + noise(p, 5) * 0.6
				crown_at.append(Transform3D(Basis.from_scale(Vector3(s, s * 0.9, s)), centre(p, 4.2 * s)))
				crown_colour.append(Color("4E8A45").lerp(Color("2F6B34"), noise(p, 6)))
				trunk_at.append(Transform3D(Basis.from_scale(Vector3(1, 1.6 * s, 1)), centre(p, 1.6 * s)))
				continue
			var floors := 2 + int(noise(p, 1) * 5) if not faces.is_empty() else 1 + int(noise(p, 1) * 3)
			var h := floors * FLOOR + 0.6
			# The footprint: the tile, less the pavements on road sides and
			# a narrow gap between neighbours.
			var x0 := p.x * T + (PAVEMENT if faces.has(RoadMap.W) else 0.12)
			var x1 := (p.x + 1) * T - (PAVEMENT if faces.has(RoadMap.E) else 0.12)
			var z0 := p.y * T + (PAVEMENT if faces.has(RoadMap.N) else 0.12)
			var z1 := (p.y + 1) * T - (PAVEMENT if faces.has(RoadMap.S) else 0.12)
			var wall: Color = WALLS[int(noise(p, 2) * WALLS.size())]
			# Corners of each side, going clockwise seen from above.
			var sides := {
				RoadMap.N: [Vector2(x0, z0), Vector2(x1, z0)],
				RoadMap.E: [Vector2(x1, z0), Vector2(x1, z1)],
				RoadMap.S: [Vector2(x1, z1), Vector2(x0, z1)],
				RoadMap.W: [Vector2(x0, z1), Vector2(x0, z0)],
			}
			for d in 4:
				var a: Vector2 = sides[d][0]
				var b: Vector2 = sides[d][1]
				if not faces.has(d):
					_wall(walls, a, b, 0.0, h, wall.darkened(0.08), h)
					continue
				_wall(shops, a, b, 0.15, FLOOR, Color.WHITE, FLOOR)
				_wall(walls, a, b, FLOOR, h, wall, h)
				# A signboard over the shop, its name facing the road.
				var out := Vector3(RoadMap.DX[d], 0, RoadMap.DY[d])
				var along := Vector3(b.x - a.x, 0, b.y - a.y)
				var mid := Vector3((a.x + b.x) / 2, FLOOR - 0.45, (a.y + b.y) / 2) + out * 0.12
				var board := Basis(along.normalized() * along.length() * 0.92, Vector3.UP * 0.8, out * 0.08)
				board_at.append(Transform3D(board, mid))
				var colour: Color = SIGN_COLOURS[int(noise(p, 10 + d) * SIGN_COLOURS.size())]
				board_colour.append(colour)
				var shop: Dictionary = names[int(noise(p, 20 + d) * names.size())]
				var text: String = shop.bn if noise(p, 30 + d) < 0.8 else shop.en
				var ink := Color.WHITE if colour.get_luminance() < 0.55 else Look.OUTLINE
				var label := _sign(text, mid + out * 0.06, 30, ink, false)
				label.outline_size = 0
				label.rotation.y = atan2(out.x, out.z)
				label.visibility_range_end = 38.0
				node.add_child(label)
			_quad(roofs, Rect2(x0, z0, x1 - x0, z1 - z0), h, wall.darkened(0.3))
			if noise(p, 3) < 0.45:
				tank_at.append(Transform3D(Basis(), Vector3(x0 + 1.4, h + 0.7, z0 + 1.4)))
	var mesh := ArrayMesh.new()
	walls.commit(mesh)
	shops.commit(mesh)
	roofs.commit(mesh)
	var textures := [_window_texture(), _shop_texture(), null]
	for i in mesh.get_surface_count():
		var m := _material(true, textures[i])
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(i, m)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	node.add_child(mi)
	node.add_child(_multi(BoxMesh.new(), board_at, board_colour))
	var tank := CylinderMesh.new()
	tank.top_radius = 0.7
	tank.bottom_radius = 0.7
	tank.height = 1.4
	tank.radial_segments = 8
	node.add_child(_multi(tank, tank_at, [], Color("2B2F36")))
	var crown := SphereMesh.new()
	crown.radius = 2.4
	crown.height = 4.0
	crown.radial_segments = 8
	crown.rings = 4
	node.add_child(_multi(crown, crown_at, crown_colour))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.2
	trunk.bottom_radius = 0.28
	trunk.height = 2.0
	trunk.radial_segments = 6
	node.add_child(_multi(trunk, trunk_at, [], Color("6B4A2B")))
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


# --- Poles and wires -----------------------------------------------------


## Concrete electric poles on the pavement every other tile, and the tangle
## of sagging wires between them that every Dhaka street has.
static func _poles_and_wires(map: RoadMap) -> Node3D:
	var poles := {}
	for y in map.height:
		for x in map.width:
			var p := Vector2i(x, y)
			if not map.is_road(p) or (x + y) % 2 != 0:
				continue
			for d in 4:
				if map.kind_at(RoadMap.step(p, d)) == RoadMap.Kind.BLOCK:
					poles[p] = centre(p) + Vector3(RoadMap.DX[d], 0, RoadMap.DY[d]) * (T / 2 + PAVEMENT * 0.5)
					break
	var pole_at: Array[Transform3D] = []
	var wire_at: Array[Transform3D] = []
	for p in poles:
		var base: Vector3 = poles[p]
		pole_at.append(Transform3D(Basis(), base + Vector3(0, 4.5, 0)))
		# Wires run to the next pole along a straight road (two tiles on).
		for step in [Vector2i(2, 0), Vector2i(0, 2)]:
			var q: Vector2i = p + step
			var between: Vector2i = p + step / 2
			if not poles.has(q) or not map.is_road(between):
				continue
			var other: Vector3 = poles[q]
			for k in 4:
				var high := 7.8 - k * 0.4
				_wire(wire_at, base + Vector3(0, high, 0), other + Vector3(0, high, 0), 0.5 + k * 0.3)
	var node := Node3D.new()
	node.name = "Poles"
	var pole := CylinderMesh.new()
	pole.top_radius = 0.1
	pole.bottom_radius = 0.16
	pole.height = 9.0
	pole.radial_segments = 6
	node.add_child(_multi(pole, pole_at, [], Color("9A968E")))
	var wire := BoxMesh.new()
	wire.size = Vector3(0.04, 0.04, 1.0)
	node.add_child(_multi(wire, wire_at, [], Color("1A1A1A")))
	return node


## A wire from a to b sagging by `sag` in the middle, as four straight bits.
static func _wire(out: Array[Transform3D], a: Vector3, b: Vector3, sag: float) -> void:
	var prev := a
	for i in range(1, 5):
		var t := i / 4.0
		var pt := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var seg := pt - prev
		var length := seg.length()
		if length > 0.01:
			var z := seg / length
			var x := Vector3.UP.cross(z).normalized()
			var yv := z.cross(x)
			out.append(Transform3D(Basis(x, yv, z * length), (prev + pt) / 2))
		prev = pt


# --- Landmarks -----------------------------------------------------------


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
				town.add_child(_box(Vector3(T, 0.02, T), centre(p, 0.0), MAIN))
				town.add_child(_cylinder(T * 0.42, 0.45, centre(p, 0.22), Color("D8D2C4")))
				town.add_child(_cylinder(T * 0.38, 0.5, centre(p, 0.3), Color("5E9E57")))
				town.add_child(_cylinder(0.35, 6.0, centre(p, 3.0), Color("EDE6DA")))
				town.add_child(_box(Vector3(1.6, 1.0, 0.2), centre(p, 6.2), Look.PARROT))
			elif k == RoadMap.Kind.TEA:
				var side := _side(map, p)
				town.add_child(_box(Vector3(2.0, 2.2, 1.6), side + Vector3(0, 1.1, 0), Color("6B4A2B")))
				town.add_child(_box(Vector3(2.6, 0.12, 2.2), side + Vector3(0, 2.3, 0), Look.PARROT))
				town.add_child(_box(Vector3(1.6, 0.45, 0.5), side + Vector3(0, 0.25, 0), Color("8B5A2B")))
				town.add_child(_sign("চা", side + Vector3(0, 3.0, 0), 48, Look.PARROT))
			elif k == RoadMap.Kind.SIGNAL:
				var side := _side(map, p)
				town.add_child(_cylinder(0.12, 4.0, side + Vector3(0, 2.0, 0), Color("333333")))
				town.add_child(_box(Vector3(0.45, 1.2, 0.45), side + Vector3(0, 4.3, 0), Color("222222")))
				town.add_child(_box(Vector3(0.47, 0.32, 0.47), side + Vector3(0, 4.6, 0), Look.VERMILION))
				town.add_child(_box(Vector3(0.47, 0.32, 0.47), side + Vector3(0, 4.0, 0), Look.PARROT))
			elif k == RoadMap.Kind.HOME:
				var side := _side(map, p)
				town.add_child(_box(Vector3(2.6, 2.6, 2.2), side + Vector3(0, 1.3, 0), Color("B5651D")))
				town.add_child(_box(Vector3(3.0, 0.15, 2.6), side + Vector3(0, 2.7, 0), Color("8C8C8C")))
				town.add_child(_sign("বাড়ি", side + Vector3(0, 3.4, 0), 48, Look.MAGENTA))


## A spot at the edge of a road tile, beside a building, for things that
## stand by the road.
static func _side(map: RoadMap, p: Vector2i) -> Vector3:
	for d in 4:
		if not map.is_road(RoadMap.step(p, d)):
			return centre(p) + Vector3(RoadMap.DX[d], 0, RoadMap.DY[d]) * (T * 0.5 - 1.2)
	return centre(p) + Vector3(T * 0.3, 0, T * 0.3)


## Text in the town. Billboards turn to face the camera; flat ones (shop
## boards) stay on their wall.
static func _sign(text: String, at: Vector3, size := 46, colour := Look.OUTLINE, billboard := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Look.font(Look.BOLD)
	l.font_size = size
	l.outline_size = 14
	l.modulate = colour
	l.outline_modulate = Look.CREAM
	l.pixel_size = 0.012
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	l.double_sided = billboard
	l.position = at
	l.visibility_range_end = 80.0
	return l
