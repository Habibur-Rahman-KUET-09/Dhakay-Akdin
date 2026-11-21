## Builds the 3D town from a road map at street scale (1 unit = 1 metre):
## tarmac, pavements, apartment blocks with grilled windows and shop
## shutters, Bangla signboards, electric poles with sagging wires, water
## tanks, trees, roundabouts, tea stalls, signals, home and the names of
## real places. Shapes and textures are made in code for now (§১০); real
## models can replace them later. Few big meshes, so cheap phones keep up.
extends RefCounted

const RoadMap = preload("res://scripts/rules/road_map.gd")
const Look = preload("res://scripts/ui/look.gd")
const Clutter = preload("res://scripts/world/clutter.gd")

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
const CLOTHES := [
	Color("C2185B"), Color("F2B705"), Color("2D8BD6"), Color("2E9E6B"), Color("E2432A"),
	Color("F2F2F2"), Color("6A1B9A"), Color("FF8A65"), Color("1C4E9B"),
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


## skip: a tea stall tile left empty (the tea stall scene builds its own).
## `festival` (from content/calendar.json, or {}) decks the lanes in its
## colours and puts its name on the banners.
static func build(map: RoadMap, lang: String, skip := Vector2i(-1, -1), festival := {}) -> Node3D:
	var town := Node3D.new()
	town.name = "Town"
	print("[town] ground and roads")
	town.add_child(_ground(map))
	town.add_child(_roads(map))
	print("[town] blocks")
	town.add_child(_blocks(map))
	print("[town] poles and wires")
	town.add_child(_poles_and_wires(map))
	print("[town] features and banners")
	_features(map, town, skip)
	_banners(map, town, festival)
	if not festival.is_empty():
		_bunting(map, town, festival)
	print("[town] place names")
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


## A photo texture from textures/ (Poly Haven, CC0; textures/SOURCES.json),
## kept as JPEG in the export and decoded here.
static func _photo(name: String) -> Image:
	var img := Image.new()
	var err := img.load_jpg_from_buffer(FileAccess.get_file_as_bytes("res://textures/%s.jpg" % name))
	if err != OK:
		push_error("texture %s missing" % name)
		img = Image.create(64, 64, false, Image.FORMAT_RGB8)
		img.fill(Color(0.8, 0.8, 0.8))
	img.convert(Image.FORMAT_RGBA8)
	return img


static func _texture(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A photo turned into light grey grain, so a wall colour can tint it.
static func _grain(photo: Image, size: int, lo: float, hi: float) -> Image:
	var img: Image = photo.duplicate()
	img.resize(size, size)
	for y in size:
		for x in size:
			var v := lerpf(lo, hi, clampf((img.get_pixel(x, y).get_luminance() - 0.15) / 0.45, 0.0, 1.0))
			img.set_pixel(x, y, Color(v, v, v))
	return img


## One bay of an upper floor (3 m square) drawn over a wall: a window with a
## steel grill, a sill, rain stains below.
static func _window_bay(wall: Image) -> ImageTexture:
	var img: Image = wall.duplicate()
	img.resize(192, 192)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	img.fill_rect(Rect2i(36, 40, 120, 96), Color(0.15, 0.18, 0.22))
	img.fill_rect(Rect2i(36, 40, 120, 6), Color(0.5, 0.5, 0.48))
	for x in range(44, 156, 14):
		img.fill_rect(Rect2i(x, 40, 4, 96), Color(0.6, 0.6, 0.58))
	for y in [68, 100]:
		img.fill_rect(Rect2i(36, y, 120, 4), Color(0.6, 0.6, 0.58))
	img.fill_rect(Rect2i(28, 136, 136, 10), Color(0.78, 0.78, 0.76))
	for i in 14:
		var x := rng.randi_range(32, 160)
		var run := rng.randi_range(12, 44)
		for k in run:
			var c := img.get_pixel(x, 146 + k)
			img.set_pixel(x, 146 + k, c.darkened(0.25 * (1.0 - float(k) / run)))
			img.set_pixel(x + 1, 146 + k, c.darkened(0.15 * (1.0 - float(k) / run)))
	return _texture(img)


## One bay of a ground-floor shop: a half-raised corrugated shutter over a
## dark shop with goods on the shelves.
static func _shop_bay(wall: Image, shutter: Image) -> ImageTexture:
	var img: Image = wall.duplicate()
	img.resize(192, 192)
	# The photo's ribs run up and down; a rolling shutter's run across.
	var metal := _grain(shutter, 168, 0.45, 0.8)
	metal.rotate_90(CLOCKWISE)
	metal.resize(168, 66)
	img.fill_rect(Rect2i(12, 28, 168, 164), Color(0.12, 0.11, 0.1))
	img.blit_rect(metal, Rect2i(0, 0, 168, 66), Vector2i(12, 28))
	img.fill_rect(Rect2i(12, 92, 168, 4), Color(0.3, 0.3, 0.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 60:
		var c := Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.8), rng.randf_range(0.35, 0.85))
		img.fill_rect(Rect2i(rng.randi_range(18, 168), rng.randi_range(104, 180), rng.randi_range(6, 14), rng.randi_range(6, 10)), c)
	return _texture(img)


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
	var walk := SurfaceTool.new()
	walk.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in map.roads():
		var o := Vector2(p.x * T, p.y * T)
		var tile := Rect2(o, Vector2(T, T))
		var k := map.kind_at(p)
		# The photo is the colour; this only shades it tile by tile.
		var shade := (0.82 if k == RoadMap.Kind.MAIN_ROAD else 0.97) * (0.92 + noise(p, 9) * 0.1)
		_quad(st, tile, 0.0, Color(shade, shade, shade * 0.98))
		if k == RoadMap.Kind.MAIN_ROAD:
			var ew := map.is_road(RoadMap.step(p, RoadMap.E)) and map.is_road(RoadMap.step(p, RoadMap.W))
			var ns := map.is_road(RoadMap.step(p, RoadMap.N)) and map.is_road(RoadMap.step(p, RoadMap.S))
			if ew != ns:
				var dash := Rect2(o + Vector2(T * 0.25, T * 0.48), Vector2(T * 0.5, 0.15)) if ew \
					else Rect2(o + Vector2(T * 0.48, T * 0.25), Vector2(0.15, T * 0.5))
				_quad(st, dash, 0.02, DASH)
		if k == RoadMap.Kind.FLOOD:
			_quad(st, tile.grow(-0.3), 0.03, WATER)
		elif k == RoadMap.Kind.ROAD and noise(p, 200) < 0.25:
			# Wear: a dark pothole patch, and in some a puddle.
			var c := o + Vector2(1.0 + noise(p, 201) * 3.0, 1.0 + noise(p, 202) * 3.0)
			var size := Vector2(0.8 + noise(p, 203) * 1.2, 0.6 + noise(p, 204) * 0.9)
			_quad(st, Rect2(c, size), 0.01, Color(0.55, 0.53, 0.5))
			if noise(p, 205) < 0.5:
				_quad(st, Rect2(c + Vector2(0.15, 0.12), size * 0.75), 0.02, Color(0.42, 0.5, 0.56))
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
					var v := 0.9 + noise(p, d) * 0.1
					_quad(walk, _strip(p, d, PAVEMENT), 0.15, Color(v, v * 0.97, v * 0.92))
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	walk.commit(mesh)
	mesh.surface_set_material(0, _material(true, _texture(_photo("asphalt"))))
	mesh.surface_set_material(1, _material(true, _texture(_photo("pavement"))))
	var mi := MeshInstance3D.new()
	mi.name = "Roads"
	mi.mesh = mesh
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
	# Darker at the foot of the street: less sky reaches it.
	var foot := c.darkened(0.3) if y0 < 0.5 else c
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(foot if i >= 2 else c)
		st.set_normal(n)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


## Apartment blocks with shops below where they face a road, signboards
## over the shops, water tanks on some roofs, trees in the open ground.
static func _blocks(map: RoadMap) -> Node3D:
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bricks := SurfaceTool.new()
	bricks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shops := SurfaceTool.new()
	shops.begin(Mesh.PRIMITIVE_TRIANGLES)
	var roofs := SurfaceTool.new()
	roofs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shop_list = JSON.parse_string(FileAccess.get_file_as_string("res://content/shops.json"))
	var names: Array = shop_list.names
	# Old Dhaka: older, lower houses, most of them bare brick, and its own
	# shops (bakarkhani, kacchi, printing presses) beside the usual ones.
	var old := map.id == "old_dhaka"
	if old:
		names = (shop_list.old_dhaka as Array) + names.slice(0, 10)
	var node := Node3D.new()
	node.name = "Blocks"
	var board_at: Array[Transform3D] = []
	var board_colour: Array[Color] = []
	var slab_at: Array[Transform3D] = []
	var slab_colour: Array[Color] = []
	var cloth_at: Array[Transform3D] = []
	var cloth_colour: Array[Color] = []
	var ac_at: Array[Transform3D] = []
	var to_let: Dictionary = shop_list.to_let
	var mosques := {}
	for m in Clutter.mosque_tiles(map):
		mosques[m] = true
	var tank_at: Array[Transform3D] = []
	var crown_at: Array[Transform3D] = []
	var crown_colour: Array[Color] = []
	var trunk_at: Array[Transform3D] = []
	for y in map.height:
		for x in map.width:
			var p := Vector2i(x, y)
			if map.kind_at(p) != RoadMap.Kind.BLOCK or mosques.has(p):
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
			var floors := 2 + int(noise(p, 1) * (3 if old else 5)) if not faces.is_empty() else 1 + int(noise(p, 1) * 3)
			var h := floors * FLOOR + 0.6
			# The footprint: the tile, less the pavements on road sides and
			# a narrow gap between neighbours.
			var x0 := p.x * T + (PAVEMENT if faces.has(RoadMap.W) else 0.12)
			var x1 := (p.x + 1) * T - (PAVEMENT if faces.has(RoadMap.E) else 0.12)
			var z0 := p.y * T + (PAVEMENT if faces.has(RoadMap.N) else 0.12)
			var z1 := (p.y + 1) * T - (PAVEMENT if faces.has(RoadMap.S) else 0.12)
			var wall: Color = WALLS[int(noise(p, 2) * WALLS.size())]
			# About one building in five is bare brick, never plastered.
			var brick := noise(p, 8) < (0.55 if old else 0.2)
			var skin := bricks if brick else walls
			if brick:
				wall = Color(0.95, 0.93, 0.9)
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
					_wall(skin, a, b, 0.0, h, wall.darkened(0.08), h)
					continue
				_wall(shops, a, b, 0.15, FLOOR, Color.WHITE, FLOOR)
				_wall(skin, a, b, FLOOR, h, wall, h)
				_front_details(p, d, a, b, floors, wall, slab_at, slab_colour, cloth_at, cloth_colour, ac_at)
				if floors >= 3 and noise(p, 70 + d) < 0.12:
					var out_dir := Vector3(RoadMap.DX[d], 0, RoadMap.DY[d])
					var spot := Vector3((a.x + b.x) / 2, FLOOR + 1.6, (a.y + b.y) / 2) + out_dir * 0.08
					var along_dir := Vector3(b.x - a.x, 0, b.y - a.y).normalized()
					board_at.append(Transform3D(Basis(along_dir * 1.6, Vector3.UP * 0.7, out_dir * 0.04), spot))
					board_colour.append(Color("F4F1E8"))
					var let_label := _sign(to_let.bn if noise(p, 71 + d) < 0.6 else to_let.en, spot + out_dir * 0.04, 34, Look.VERMILION, false)
					let_label.outline_size = 0
					let_label.rotation.y = atan2(out_dir.x, out_dir.z)
					let_label.visibility_range_end = 30.0
					node.add_child(let_label)
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
			_quad(roofs, Rect2(x0, z0, x1 - x0, z1 - z0), h, wall.lightened(0.3))
			if noise(p, 3) < 0.45:
				tank_at.append(Transform3D(Basis(), Vector3(x0 + 1.4, h + 0.7, z0 + 1.4)))
	var mesh := ArrayMesh.new()
	walls.commit(mesh)
	bricks.commit(mesh)
	shops.commit(mesh)
	roofs.commit(mesh)
	var concrete := _photo("plaster")
	var plaster := _grain(concrete, 192, 0.8, 0.98)
	var textures := [
		_window_bay(plaster),
		_window_bay(_photo("brick")),
		_shop_bay(plaster, _photo("shutter")),
		_texture(concrete),
	]
	for i in mesh.get_surface_count():
		var m := _material(true, textures[i])
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(i, m)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	node.add_child(mi)
	node.add_child(_multi(BoxMesh.new(), board_at, board_colour))
	node.add_child(_multi(BoxMesh.new(), slab_at, slab_colour))
	node.add_child(_multi(BoxMesh.new(), cloth_at, cloth_colour))
	node.add_child(_multi(BoxMesh.new(), ac_at, [], Color("ECECEA")))
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


## On a wall facing a road: balconies with railings (some hung with
## washing) and air-conditioner boxes on the upper floors.
static func _front_details(p: Vector2i, d: int, a: Vector2, b: Vector2, floors: int, wall: Color,
		slab_at: Array[Transform3D], slab_colour: Array[Color], cloth_at: Array[Transform3D],
		cloth_colour: Array[Color], ac_at: Array[Transform3D]) -> void:
	var out := Vector3(RoadMap.DX[d], 0, RoadMap.DY[d])
	var along := Vector3(b.x - a.x, 0, b.y - a.y)
	var length := along.length()
	var t := along / length
	var mid := Vector3((a.x + b.x) / 2, 0, (a.y + b.y) / 2)
	for fl in range(1, floors):
		var y := fl * FLOOR
		var n := noise(p, 40 + d * 7 + fl)
		var shift := (noise(p, 50 + d * 7 + fl) - 0.5) * length * 0.35
		var c := mid + t * shift + Vector3(0, y, 0)
		if n < 0.5:
			var w := length * 0.45
			slab_at.append(Transform3D(Basis(t * w, Vector3.UP * 0.12, out * 0.85), c + out * 0.42))
			slab_colour.append(wall.darkened(0.1))
			var rail := Color("3A3D42") if n < 0.25 else wall.darkened(0.25)
			slab_at.append(Transform3D(Basis(t * w, Vector3.UP * 0.95, out * 0.05), c + out * 0.84 + Vector3(0, 0.55, 0)))
			slab_colour.append(rail)
			if n < 0.32:
				for k in 3:
					cloth_at.append(Transform3D(Basis(t * 0.5, Vector3.UP * 0.75, out * 0.02),
						c + out * 0.89 + Vector3(0, 0.75, 0) + t * (k - 1) * w * 0.3))
					cloth_colour.append(CLOTHES[int(noise(p, 60 + fl * 3 + k + d) * CLOTHES.size())])
		elif n > 0.78:
			ac_at.append(Transform3D(Basis(t * 0.8, Vector3.UP * 0.55, out * 0.4), c + out * 0.22 + Vector3(0, 1.7, 0)))


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
static func _features(map: RoadMap, town: Node3D, skip := Vector2i(-1, -1)) -> void:
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
			elif k == RoadMap.Kind.TEA and p != skip:
				var side := _side(map, p)
				town.add_child(_box(Vector3(1.6, 1.9, 0.9), side + Vector3(0, 0.95, 0), Color("6B4A2B")))
				town.add_child(_box(Vector3(2.0, 0.1, 1.4), side + Vector3(0, 2.0, 0), Look.PARROT))
				town.add_child(_box(Vector3(1.4, 0.4, 0.4), side + Vector3(0, 0.2, 0.0) - _inward(map, p) * 0.9, Color("8B5A2B")))
				town.add_child(_sign("চা", side + Vector3(0, 2.6, 0), 36, Look.PARROT))
			elif k == RoadMap.Kind.HOME:
				# Home is a door in the wall beside the lane, with its name over it.
				var side := _side(map, p)
				town.add_child(_box(Vector3(1.0, 2.1, 0.3), side + Vector3(0, 1.05, 0), Color("6B3E1E")))
				var home_sign := _sign("গ্যারেজ" if map.id == "old_dhaka" else "বাড়ি", side + Vector3(0, 2.5, 0), 26, Look.MAGENTA)
				home_sign.visibility_range_end = 40.0
				town.add_child(home_sign)


## Cloth banners hung across some straight stretches of road, lettered on
## both sides: admissions, discounts, flats for sale.
static func _banners(map: RoadMap, town: Node3D, festival := {}) -> void:
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string("res://content/shops.json")).banners
	if not festival.is_empty():
		# Most banners greet the day.
		list = [festival.name, festival.name, festival.name] + list
	var cloth_at: Array[Transform3D] = []
	var cloth_colour: Array[Color] = []
	for p in map.roads():
		if noise(p, 99) > 0.07:
			continue
		var ew := map.is_road(RoadMap.step(p, RoadMap.E)) and map.is_road(RoadMap.step(p, RoadMap.W))
		var ns := map.is_road(RoadMap.step(p, RoadMap.N)) and map.is_road(RoadMap.step(p, RoadMap.S))
		if ew == ns:
			continue
		# The banner spans the road, facing traffic.
		var face := Vector3(1, 0, 0) if ew else Vector3(0, 0, 1)
		var across := Vector3(0, 0, 1) if ew else Vector3(1, 0, 0)
		var at := centre(p, 5.4)
		var colour: Color = [Color("F4F1E8"), Color("FFF3B0"), Color("D7F0DD")][int(noise(p, 98) * 3)]
		cloth_at.append(Transform3D(Basis(across * (T - 0.6), Vector3.UP * 1.0, face * 0.03), at))
		cloth_colour.append(colour)
		var text: Dictionary = list[int(noise(p, 97) * list.size())]
		for side in [1.0, -1.0]:
			var l := _sign(text.bn, at + face * 0.03 * side, 44, Look.VERMILION if side > 0 else Look.PARROT, false)
			l.outline_size = 0
			l.rotation.y = atan2(face.x * side, face.z * side)
			l.visibility_range_end = 60.0
			town.add_child(l)
	town.add_child(_multi(BoxMesh.new(), cloth_at, cloth_colour))


## Strings of little paper flags across the lanes in the festival's
## colours, sagging between the buildings.
static func _bunting(map: RoadMap, town: Node3D, festival: Dictionary) -> void:
	var colours: Array[Color] = []
	for hex in festival.colours:
		colours.append(Color(hex))
	var flag_at: Array[Transform3D] = []
	var flag_colour: Array[Color] = []
	var flags := 9
	for p in map.roads():
		if noise(p, 120) > 0.2:
			continue
		var ew := map.is_road(RoadMap.step(p, RoadMap.E)) and map.is_road(RoadMap.step(p, RoadMap.W))
		var ns := map.is_road(RoadMap.step(p, RoadMap.N)) and map.is_road(RoadMap.step(p, RoadMap.S))
		if ew == ns:
			continue
		var face := Vector3(1, 0, 0) if ew else Vector3(0, 0, 1)
		var across := Vector3(0, 0, 1) if ew else Vector3(1, 0, 0)
		var mid := centre(p, 6.0)
		for i in flags:
			var k := float(i) / float(flags - 1)
			var at := mid + across * (k - 0.5) * (T - 0.4) - Vector3(0, 0.7 * sin(PI * k), 0)
			flag_at.append(Transform3D(Basis(across * 0.38, Vector3.UP * 0.5, face * 0.02), at))
			flag_colour.append(colours[i % colours.size()])
	if not flag_at.is_empty():
		town.add_child(_multi(BoxMesh.new(), flag_at, flag_colour))


## A spot at the edge of a road tile, beside a building, for things that
## stand by the road.
static func _side(map: RoadMap, p: Vector2i) -> Vector3:
	for d in 4:
		if not map.is_road(RoadMap.step(p, d)):
			return centre(p) + Vector3(RoadMap.DX[d], 0, RoadMap.DY[d]) * (T * 0.5 + PAVEMENT * 0.5)
	return centre(p) + Vector3(T * 0.3, 0, T * 0.3)


## From the road tile p towards the building beside it.
static func _inward(map: RoadMap, p: Vector2i) -> Vector3:
	for d in 4:
		if not map.is_road(RoadMap.step(p, d)):
			return Vector3(RoadMap.DX[d], 0, RoadMap.DY[d])
	return Vector3.ZERO


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
	# Cut-out rather than blended text: much cheaper to draw.
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.position = at
	l.visibility_range_end = 80.0
	return l
