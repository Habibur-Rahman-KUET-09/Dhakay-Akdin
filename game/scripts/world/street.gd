## A Mirpur street as it really looks (the reference photos): kerbs painted
## in black and white stripes, red brick pavements, a narrow divider down
## the middle of the main roads with a clipped hedge on it and tall lamp
## posts with two arms, white edge lines, big leafy trees along the
## pavements, and blue road signs at the main crossings ("মিরপুর ↑").
## Old Dhaka keeps its plain grey kerbs and no divider. Every copy of a
## kind is one multimesh, so a cheap phone keeps up.
extends RefCounted

const RoadMap = preload("res://scripts/rules/road_map.gd")
const Look = preload("res://scripts/ui/look.gd")

const T := 6.0
const PAVEMENT := 0.9
## The kerb along the pavement's road edge, its stripes.
const KERB_H := 0.2
const KERB_W := 0.16
const STRIPE := 0.6
## The divider: narrow enough that vehicles keeping left (1 m, buses 1.4 m)
## pass it.
const DIVIDER_W := 0.3
const DIVIDER_H := 0.28

const BLACK := Color("1E1E1E")
const WHITE := Color("EDEDE6")
const GREY_KERB := Color("9C988F")
const HEDGE := [Color("2F5A26"), Color("3A6A2C"), Color("284F22"), Color("44732F")]
const LEAVES := [Color("2F6224"), Color("3C7129"), Color("4A7F30"), Color("28561F"), Color("557F33")]
const BARK := Color("5A4A3A")
const LAMP_GREY := Color("8E9096")
const SIGN_BLUE := Color("1F5FB4")


static func noise(p: Vector2i, salt := 0) -> float:
	var h := (p.x * 73856093) ^ (p.y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 10007) / 10007.0


static func centre(p: Vector2i, y := 0.0) -> Vector3:
	return Vector3((p.x + 0.5) * T, y, (p.y + 0.5) * T)


## Whether this map is dressed as Mirpur (new roads) or Old Dhaka.
static func modern(map: RoadMap) -> bool:
	return map.id != "old_dhaka"


## A straight stretch of main road (not a crossing): it gets the divider.
## Returns the direction it runs: 0 east-west, 1 north-south, -1 none.
static func straight_main(map: RoadMap, p: Vector2i) -> int:
	if map.kind_at(p) != RoadMap.Kind.MAIN_ROAD:
		return -1
	var ew := map.is_road(RoadMap.step(p, RoadMap.E)) and map.is_road(RoadMap.step(p, RoadMap.W))
	var ns := map.is_road(RoadMap.step(p, RoadMap.N)) and map.is_road(RoadMap.step(p, RoadMap.S))
	if ew == ns:
		return -1
	# Not where a side road joins: there vehicles turn across it.
	var sides := [RoadMap.N, RoadMap.S] if ew else [RoadMap.E, RoadMap.W]
	for d in sides:
		if map.is_road(RoadMap.step(p, d)):
			return -1
	return 0 if ew else 1


static func build(map: RoadMap, lang: String) -> Node3D:
	var node := Node3D.new()
	node.name = "Street"
	# Kerbs: the top and the road face of each, as quads; the stripes come
	# from a two-pixel texture (u runs one stripe pair per 2 * STRIPE).
	var striped := SurfaceTool.new()
	striped.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plain := SurfaceTool.new()
	plain.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hedge_at: Array[Transform3D] = []
	var hedge_col: Array[Color] = []
	var trunk_at: Array[Transform3D] = []
	var leaf_at: Array[Transform3D] = []
	var leaf_col: Array[Color] = []
	var post_at: Array[Transform3D] = []
	var arm_at: Array[Transform3D] = []
	var head_at: Array[Transform3D] = []
	var new_town := modern(map)
	for y in map.height:
		for x in map.width:
			var p := Vector2i(x, y)
			if map.kind_at(p) != RoadMap.Kind.BLOCK:
				continue
			for d in 4:
				var road := RoadMap.step(p, d)
				if not map.is_road(road):
					continue
				var main := map.kind_at(road) == RoadMap.Kind.MAIN_ROAD
				var out := Vector3(RoadMap.DX[d], 0, RoadMap.DY[d])
				var along := Vector3(-RoadMap.DY[d], 0, RoadMap.DX[d])
				# The pavement's road edge, on this block's side d.
				var edge := centre(p) + out * (T / 2)
				# The kerb in stripes (or plain grey in Old Dhaka's lanes).
				var a := edge - along * (T / 2)
				var b := edge + along * (T / 2)
				var u0 := float((p.x + p.y) % 2) * 0.5
				if new_town and (main or noise(p, 40 + d) < 0.5):
					_kerb(striped, a, b, out, KERB_W, KERB_H, u0, Color.WHITE)
				else:
					_kerb(plain, a, b, out, KERB_W, KERB_H, 0.0, GREY_KERB)
				# A white line along the main road's edge, a little off the kerb.
				if new_town and main:
					_flat(plain, a + out * 0.39, b + out * 0.39, out, 0.12, 0.02, Color.WHITE)
				# A big tree on the pavement every other tile (Mirpur), clear
				# of the poles (which stand near the tile's edge).
				if new_town and (p.x * 3 + p.y + d) % 2 == 0 and noise(p, 60 + d) < 0.8:
					var foot := centre(p) + out * (T / 2 - PAVEMENT * 0.45) - along * (T * 0.12)
					var tall := 3.0 + noise(p, 61 + d) * 1.2
					trunk_at.append(Transform3D(_ls(Basis(), Vector3(1, tall, 1)), foot + Vector3(0, tall / 2, 0)))
					# The crown: a few squashed balls, leaning over the pavement.
					for k in 5:
						var ang := k * 1.05 + noise(p, 63 + d) * 3.0
						var r := 0.75 + noise(p, 62 + d * 6 + k) * 0.45
						var ring := 0.0 if k == 0 else 0.85
						var off := (along * cos(ang) + out * sin(ang) * 0.6) * ring + out * 0.15 \
							+ Vector3(0, tall + 0.9 + noise(p, 70 + k) * 0.7 + (0.5 if k == 0 else 0.0), 0)
						leaf_at.append(Transform3D(_ls(Basis(Vector3.UP, ang), Vector3(r, r * 0.75, r)), foot + off))
						leaf_col.append(LEAVES[int(noise(p, 80 + d * 6 + k) * LEAVES.size()) % LEAVES.size()])
	# The divider down straight main roads, a hedge on it, lamps with two arms.
	if new_town:
		for p in map.roads():
			var way := straight_main(map, p)
			if way < 0:
				continue
			var run := Vector3(1, 0, 0) if way == 0 else Vector3(0, 0, 1)
			var across := Vector3(0, 0, 1) if way == 0 else Vector3(1, 0, 0)
			var c := centre(p)
			# Both faces of the divider, striped, and its top under the bushes.
			for side in [-1, 1]:
				var face: Vector3 = c + across * (side * DIVIDER_W / 2)
				_kerb(striped, face - run * (T / 2), face + run * (T / 2), -across * side, DIVIDER_W / 2, DIVIDER_H, float((p.x + p.y) % 2) * 0.5, Color.WHITE)
			# Clipped bushes in clumps, a little uneven, not a green wall.
			var clumps := 14
			for i in clumps:
				var q := noise(p, 90 + i)
				var at := c + run * (-T / 2 + (i + 0.5) * T / clumps) + Vector3(0, DIVIDER_H + 0.12 + q * 0.06, 0)
				hedge_at.append(Transform3D(_ls(Basis(Vector3.UP, q * 3.0), Vector3(0.6 + q * 0.15, 0.34 + q * 0.1, 0.36)), at))
				hedge_col.append(HEDGE[int(noise(p, 120 + i) * HEDGE.size()) % HEDGE.size()])
			if (p.x + p.y) % 2 == 0:
				post_at.append(Transform3D(_ls(Basis(), Vector3(1, 9.0, 1)), c + Vector3(0, DIVIDER_H + 4.5, 0)))
				for s in [-1, 1]:
					var tip: Vector3 = c + across * (s * 1.3) + Vector3(0, DIVIDER_H + 8.9, 0)
					var mid: Vector3 = c + across * (s * 0.65) + Vector3(0, DIVIDER_H + 8.95, 0)
					arm_at.append(Transform3D(_ls(Basis.looking_at(across * s, Vector3.UP), Vector3(0.08, 0.08, 1.3)), mid))
					head_at.append(Transform3D(_ls(Basis.looking_at(across * s, Vector3.UP), Vector3(0.22, 0.1, 0.5)), tip - Vector3(0, 0.05, 0)))
	var box := BoxMesh.new()
	var kerbs := ArrayMesh.new()
	striped.commit(kerbs)
	plain.commit(kerbs)
	var stripes := Image.create(2, 1, false, Image.FORMAT_RGB8)
	stripes.set_pixel(0, 0, BLACK)
	stripes.set_pixel(1, 0, WHITE)
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_texture = ImageTexture.create_from_image(stripes)
	stripe_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	stripe_mat.roughness = 0.8
	var plain_mat := StandardMaterial3D.new()
	plain_mat.vertex_color_use_as_albedo = true
	plain_mat.vertex_color_is_srgb = true
	plain_mat.roughness = 0.85
	if kerbs.get_surface_count() > 0:
		kerbs.surface_set_material(0, stripe_mat)
	if kerbs.get_surface_count() > 1:
		kerbs.surface_set_material(1, plain_mat)
	var kerb_mi := MeshInstance3D.new()
	kerb_mi.name = "Kerbs"
	kerb_mi.mesh = kerbs
	node.add_child(kerb_mi)
	if not hedge_at.is_empty():
		var bush := SphereMesh.new()
		bush.radius = 0.5
		bush.height = 1.0
		bush.radial_segments = 7
		bush.rings = 4
		node.add_child(_multi("Hedges", bush, hedge_at, hedge_col, 1.0))
	if not trunk_at.is_empty():
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.12
		trunk.bottom_radius = 0.2
		trunk.height = 1.0
		trunk.radial_segments = 7
		trunk.rings = 1
		node.add_child(_multi("Trunks", trunk, trunk_at, [], 1.0, BARK))
		var crown := SphereMesh.new()
		crown.radius = 1.0
		crown.height = 2.0
		crown.radial_segments = 6
		crown.rings = 4
		node.add_child(_multi("Crowns", crown, leaf_at, leaf_col, 1.0))
	if not post_at.is_empty():
		var post := CylinderMesh.new()
		post.top_radius = 0.07
		post.bottom_radius = 0.13
		post.height = 1.0
		post.radial_segments = 6
		post.rings = 1
		node.add_child(_multi("LampPosts", post, post_at, [], 0.5, LAMP_GREY))
		node.add_child(_multi("LampArms", box, arm_at, [], 0.5, LAMP_GREY))
		node.add_child(_multi("LampHeads", box, head_at, [], 0.4, Color("DADBD2")))
	if new_town:
		_signs(map, lang, node)
	return node


## Blue road signs on the corners of main-road crossings, pointing the way
## along the road to a named place, in Bangla and English.
static func _signs(map: RoadMap, lang: String, node: Node3D) -> void:
	if map.places.is_empty():
		return
	var made := 0
	for p in map.roads():
		if made >= 8 or map.kind_at(p) != RoadMap.Kind.MAIN_ROAD:
			continue
		var exits := 0
		for d in 4:
			if map.is_road(RoadMap.step(p, d)):
				exits += 1
		if exits < 3 or noise(p, 300) > 0.6:
			continue
		# A corner block beside the crossing, and the road running past it.
		for d in 4:
			var block := RoadMap.step(p, d)
			if map.kind_at(block) != RoadMap.Kind.BLOCK:
				continue
			var out := -Vector3(RoadMap.DX[d], 0, RoadMap.DY[d])
			var foot := centre(block) + out * (T / 2 + PAVEMENT * 0.5)
			var place: Dictionary = map.places[(p.x * 7 + p.y * 3) % map.places.size()]
			_sign_post(node, foot, out, RoadMap.place_name(place, "bn"), RoadMap.place_name(place, "en"))
			made += 1
			break


static func _sign_post(node: Node3D, foot: Vector3, facing: Vector3, bn: String, en: String) -> void:
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.08
	cyl.height = 3.4
	cyl.radial_segments = 6
	post.mesh = cyl
	post.material_override = _material(Color("8B8E94"), 0.6)
	post.position = foot + Vector3(0, 1.7, 0)
	node.add_child(post)
	var panel := Node3D.new()
	panel.position = foot + Vector3(0, 3.6, 0)
	panel.basis = Basis.looking_at(-facing, Vector3.UP)
	node.add_child(panel)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.3, 0.95, 0.05)
	board.mesh = bm
	board.material_override = _material(Color("F2F2F2"), 0.5)
	panel.add_child(board)
	var face := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(2.2, 0.85, 0.06)
	face.mesh = fm
	face.material_override = _material(SIGN_BLUE, 0.5)
	panel.add_child(face)
	for side in [1, -1]:
		var lines := [[bn, 46, 0.16], [en, 34, -0.2]]
		for l in lines:
			var t := Label3D.new()
			t.text = str(l[0])
			t.font = Look.font(Look.BOLD)
			t.font_size = int(l[1])
			t.pixel_size = 0.0055
			t.modulate = Color.WHITE
			t.outline_size = 0
			t.double_sided = false
			t.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			t.position = Vector3(-0.2, float(l[2]), 0.04 * side)
			t.rotation.y = 0.0 if side == 1 else PI
			t.visibility_range_end = 70.0
			panel.add_child(t)
		var arrow := Label3D.new()
		arrow.text = "↑"
		arrow.font = Look.font(Look.BOLD)
		arrow.font_size = 80
		arrow.pixel_size = 0.0055
		arrow.position = Vector3(0.85 * side, 0, 0.04 * side)
		arrow.rotation.y = 0.0 if side == 1 else PI
		arrow.double_sided = false
		arrow.visibility_range_end = 70.0
		panel.add_child(arrow)


## A kerb from a to b, its road face looking along `out` (its top is
## `width` deep, back from the face, and `height` high). u runs along it,
## one texture width (a black and a white stripe) per 2 * STRIPE.
static func _kerb(st: SurfaceTool, a: Vector3, b: Vector3, out: Vector3, width: float, height: float, u0: float, colour: Color) -> void:
	var len := a.distance_to(b)
	var u1 := u0 + len / (2.0 * STRIPE)
	var up := Vector3(0, height, 0)
	var back := -out * width
	# The road face.
	_quad(st, a, b, b + up, a + up, out, u0, u1, colour)
	# The top.
	_quad(st, a + up, b + up, b + up + back, a + up + back, Vector3.UP, u0, u1, colour)


## A flat strip from a to b, `width` wide towards `out`, at height y.
static func _flat(st: SurfaceTool, a: Vector3, b: Vector3, out: Vector3, width: float, y: float, colour: Color) -> void:
	var h := Vector3(0, y, 0)
	_quad(st, a + h, b + h, b + h + out * width, a + h + out * width, Vector3.UP, 0.0, 0.0, colour)


## Two triangles, wound so they face `normal`.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, u0: float, u1: float, colour: Color) -> void:
	var pts := [a, b, c, d]
	var uvs := [Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(u0, 0)]
	var order := [0, 1, 2, 0, 2, 3]
	# Godot's front faces are clockwise seen from the front.
	if (b - a).cross(c - a).dot(normal) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		st.set_color(colour)
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


## b scaled along its own axes.
static func _ls(b: Basis, sc: Vector3) -> Basis:
	return b * Basis.from_scale(sc)


static func _material(colour: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	return m


## Copies of mesh in chunks of the town (CHUNK metres square), each drawn
## only near the camera, so a phone draws a few hundred, not thousands.
const CHUNK := 36.0
const DRAW := 95.0


static func _multi(name: String, mesh: Mesh, at: Array[Transform3D], colours: Array, rough: float, colour := Color.WHITE) -> Node3D:
	var groups := {}
	for i in at.size():
		var key := Vector2i(floori(at[i].origin.x / CHUNK), floori(at[i].origin.z / CHUNK))
		if not groups.has(key):
			groups[key] = [[], []]
		groups[key][0].append(at[i])
		groups[key][1].append(colours[i] if i < colours.size() else colour)
	var holder := Node3D.new()
	holder.name = name
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	for key in groups:
		var part := _multi_one(mesh, groups[key][0], groups[key][1], m)
		part.visibility_range_end = DRAW
		holder.add_child(part)
	return holder


static func _multi_one(mesh: Mesh, at: Array, colours: Array, m: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = at.size()
	for i in at.size():
		mm.set_instance_transform(i, at[i])
		mm.set_instance_color(i, colours[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	return mi
