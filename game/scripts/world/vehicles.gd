## Other road users from simple shapes, each merged into one mesh (one draw
## call): rickshaws, CNG auto-rickshaws, buses and people. All face -Z.
extends RefCounted

const Look = preload("res://scripts/ui/look.gd")

const RICKSHAW_HOODS := [Color("F6B800"), Color("2D8BD6"), Color("2E9E6B"), Color("E2432A"), Color("C2185B")]
const RICKSHAW_BODIES := [Color("C2185B"), Color("1F6F43"), Color("1C4E9B"), Color("D63A2F"), Color("6A1B9A")]
const BUS_COLOURS := [Color("B71C1C"), Color("1B5E20"), Color("0D47A1"), Color("E0E0E0"), Color("F57F17")]
const SHIRTS := [Color("F2F2F2"), Color("1C4E9B"), Color("C2185B"), Color("2E9E6B"), Color("F2B705"), Color("6D4C41"), Color("90A4AE"), Color("E57373")]
const LOWER := [Color("2E6E9E"), Color("37474F"), Color("5D4037"), Color("1B5E20"), Color("263238"), Color("8E24AA")]
const SKIN := [Color("8D5A3B"), Color("A0694A"), Color("7A4B30"), Color("B07A55")]


## Joins primitive shapes into one mesh with vertex colours.
## parts: [mesh, transform, colour] each.
static func merge(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var mesh: PrimitiveMesh = part[0]
		var xf: Transform3D = part[1]
		var colour: Color = part[2]
		var arrays := mesh.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if index.is_empty():
			index = PackedInt32Array(range(verts.size()))
		for i in index:
			st.set_color(colour)
			st.set_normal((xf.basis * normals[i]).normalized())
			st.add_vertex(xf * verts[i])
	return st.commit()


static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.8
	return m


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl(radius: float, height: float, sides := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return c


static func ball(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2
	s.radial_segments = 8
	s.rings = 4
	return s


static func at(pos: Vector3, rot_deg := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot_deg * PI / 180.0), pos)


static func _wheel(pos: Vector3, radius: float) -> Array:
	return [cyl(radius, 0.12, 12), at(pos, Vector3(0, 0, 90)), Look.OUTLINE]


## A rider or a walker, standing at the origin.
static func person_parts(rng: RandomNumberGenerator, origin := Vector3.ZERO, seated := false) -> Array:
	var shirt: Color = SHIRTS[rng.randi() % SHIRTS.size()]
	var lower: Color = LOWER[rng.randi() % LOWER.size()]
	var skin: Color = SKIN[rng.randi() % SKIN.size()]
	var hip := 0.95 if not seated else 0.55
	var parts := [
		[cyl(0.17, hip, 8), at(origin + Vector3(0, hip / 2, 0)), lower],
		[cyl(0.21, 0.62, 8), at(origin + Vector3(0, hip + 0.3, 0)), shirt],
		[ball(0.13), at(origin + Vector3(0, hip + 0.76, 0)), skin],
		[cyl(0.06, 0.55, 6), at(origin + Vector3(0.26, hip + 0.25, 0)), shirt],
		[cyl(0.06, 0.55, 6), at(origin + Vector3(-0.26, hip + 0.25, 0)), shirt],
	]
	if rng.randf() < 0.3:
		parts.append([cyl(0.14, 0.06, 8), at(origin + Vector3(0, hip + 0.88, 0)), Color("F2F2F2")])
	return parts


static func person(rng: RandomNumberGenerator) -> ArrayMesh:
	return merge(person_parts(rng))


static func rickshaw(rng: RandomNumberGenerator, passenger := false) -> ArrayMesh:
	var hood: Color = RICKSHAW_HOODS[rng.randi() % RICKSHAW_HOODS.size()]
	var body: Color = RICKSHAW_BODIES[rng.randi() % RICKSHAW_BODIES.size()]
	var metal := Color("444444")
	var parts := [
		_wheel(Vector3(-0.62, 0.45, 0.45), 0.42),
		_wheel(Vector3(0.62, 0.45, 0.45), 0.42),
		_wheel(Vector3(0, 0.38, -1.15), 0.38),
		[box(Vector3(0.12, 0.12, 1.5)), at(Vector3(0, 0.75, -0.45), Vector3(-12, 0, 0)), metal],
		[box(Vector3(1.3, 0.08, 0.08)), at(Vector3(0, 0.45, 0.45)), metal],
		[box(Vector3(1.15, 0.55, 0.85)), at(Vector3(0, 0.95, 0.45)), body],
		[box(Vector3(1.0, 0.18, 0.6)), at(Vector3(0, 1.3, 0.45)), Color("2D8BD6")],
		[box(Vector3(1.0, 0.55, 0.12)), at(Vector3(0, 1.55, 0.82)), hood],
		[cyl(0.55, 1.12, 10), at(Vector3(0, 1.75, 0.6), Vector3(0, 0, 90)), hood],
		[box(Vector3(0.7, 0.06, 0.06)), at(Vector3(0, 1.2, -1.0)), metal],
	]
	parts.append_array(person_parts(rng, Vector3(0, 0.55, -0.55), true))
	if passenger:
		parts.append_array(person_parts(rng, Vector3(0, 0.85, 0.45), true))
	return merge(parts)


## A green CNG auto-rickshaw with its black canopy and grilled sides.
static func cng(rng: RandomNumberGenerator) -> ArrayMesh:
	var green := Color("2E8B3A").lerp(Color("3FA34D"), rng.randf())
	var parts := [
		_wheel(Vector3(-0.6, 0.3, 0.6), 0.3),
		_wheel(Vector3(0.6, 0.3, 0.6), 0.3),
		_wheel(Vector3(0, 0.3, -0.95), 0.3),
		[box(Vector3(1.35, 0.7, 2.4)), at(Vector3(0, 0.75, 0)), green],
		[box(Vector3(1.3, 0.9, 1.6)), at(Vector3(0, 1.55, 0.35)), Color("1D1D1D")],
		[box(Vector3(1.25, 0.6, 0.06)), at(Vector3(0, 1.45, -0.72)), Color("9CC7DD")],
		[box(Vector3(1.4, 0.12, 2.5)), at(Vector3(0, 2.05, 0.1)), green.darkened(0.2)],
		[box(Vector3(0.3, 0.2, 0.1)), at(Vector3(0, 0.9, -1.22)), Color("FFF3B0")],
	]
	return merge(parts)


## A city bus, dented and colourful, with a band of windows.
static func bus(rng: RandomNumberGenerator) -> ArrayMesh:
	var paint: Color = BUS_COLOURS[rng.randi() % BUS_COLOURS.size()]
	var parts := [
		_wheel(Vector3(-1.15, 0.5, 2.8), 0.5),
		_wheel(Vector3(1.15, 0.5, 2.8), 0.5),
		_wheel(Vector3(-1.15, 0.5, -2.6), 0.5),
		_wheel(Vector3(1.15, 0.5, -2.6), 0.5),
		[box(Vector3(2.4, 2.6, 8.5)), at(Vector3(0, 1.85, 0)), paint],
		[box(Vector3(2.44, 0.9, 7.6)), at(Vector3(0, 2.35, 0.3)), Color("26323A")],
		[box(Vector3(2.2, 1.0, 0.06)), at(Vector3(0, 2.3, -4.26)), Color("9CC7DD")],
		[box(Vector3(2.44, 0.25, 8.5)), at(Vector3(0, 1.3, 0)), Color("F2F2F2")],
		[box(Vector3(2.3, 0.1, 8.3)), at(Vector3(0, 3.2, 0)), paint.darkened(0.25)],
	]
	return merge(parts)
