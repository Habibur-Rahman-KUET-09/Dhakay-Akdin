## The street's 3D models, made in code (§১০: until bought or commissioned
## models replace them): a Dhaka cycle rickshaw with spoked wheels, a
## ribbed hood and painted rickshaw art; a CNG auto-rickshaw; a local bus;
## people who swing their arms and legs as they walk.
##
## Every model is one mesh with vertex colours. Two things ride along in
## the vertex data for the traffic shader (traffic.gd):
## - colour alpha: KEEP, or PAINT_A / PAINT_B, parts recoloured per copy
##   (hood and body of a rickshaw, shirt and trousers of a person);
## - UV: limbs that swing (x: +1/-1 right/left leg, +0.5/-0.5 arms; y: the
##   height of the joint).
## All models face -Z, Godot's forward, standing on y = 0.
extends RefCounted

const KEEP := 1.0
const PAINT_A := 0.75
const PAINT_B := 0.5

const SKIN := Color("8A5A3C")
const HAIR := Color("1B1512")
const STEEL := Color("3C3F44")
const CHROME := Color("B8BCC2")
const RUBBER := Color("1A1A1A")
const VINYL := Color("2B5BA8")
const WOOD := Color("7A5230")


class Builder:
	var st := SurfaceTool.new()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func _vertex(v: Vector3, n: Vector3, c: Color, code: float, limb: Vector2) -> void:
		st.set_color(Color(c.r, c.g, c.b, code))
		st.set_uv(limb)
		st.set_normal(n)
		st.add_vertex(v)

	## Any primitive mesh, placed by xf.
	func add(mesh: PrimitiveMesh, xf: Transform3D, c: Color, code := 1.0, limb := Vector2.ZERO) -> void:
		var arrays := mesh.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var index = arrays[Mesh.ARRAY_INDEX]
		var order: PackedInt32Array = index if index != null and index.size() > 0 else PackedInt32Array(range(verts.size()))
		for i in order:
			_vertex(xf * verts[i], (xf.basis * normals[i]).normalized(), c, code, limb)

	func box(size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO, code := 1.0, limb := Vector2.ZERO) -> void:
		var b := BoxMesh.new()
		b.size = size
		add(b, _xf(pos, rot), c, code, limb)

	func cyl(radius: float, height: float, pos: Vector3, c: Color, rot := Vector3.ZERO, sides := 10, code := 1.0, limb := Vector2.ZERO, top := -1.0) -> void:
		var m := CylinderMesh.new()
		m.top_radius = radius if top < 0 else top
		m.bottom_radius = radius
		m.height = height
		m.radial_segments = sides
		m.rings = 1
		add(m, _xf(pos, rot), c, code, limb)

	func ball(radius: float, pos: Vector3, c: Color, scale := Vector3.ONE, code := 1.0, limb := Vector2.ZERO) -> void:
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2
		m.radial_segments = 10
		m.rings = 6
		add(m, Transform3D(Basis.from_scale(scale), pos), c, code, limb)

	## A ring (tyre, rim) whose axle runs along X.
	func ring(inner: float, outer: float, pos: Vector3, c: Color) -> void:
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 16
		m.ring_segments = 6
		add(m, _xf(pos, Vector3(0, 0, 90)), c)

	## A flat quad, visible from both sides.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color, code := 1.0) -> void:
		var n := (b - a).cross(d - a).normalized()
		for v in [a, b, c, a, c, d]:
			_vertex(v, n, colour, code, Vector2.ZERO)
		for v in [a, c, b, a, d, c]:
			_vertex(v, -n, colour, code, Vector2.ZERO)

	## A curved sheet round an axle along X: angle 0 points to +Z (back),
	## 90 straight up. Used for hoods, mudguards, roofs.
	func shell(centre: Vector3, radius: float, from_deg: float, to_deg: float, half_width: float, colour: Color, code := 1.0, segments := 10) -> void:
		for i in segments:
			var a0 := deg_to_rad(lerpf(from_deg, to_deg, float(i) / segments))
			var a1 := deg_to_rad(lerpf(from_deg, to_deg, float(i + 1) / segments))
			var p0 := centre + Vector3(0, sin(a0), cos(a0)) * radius
			var p1 := centre + Vector3(0, sin(a1), cos(a1)) * radius
			quad(p0 + Vector3(-half_width, 0, 0), p0 + Vector3(half_width, 0, 0),
				p1 + Vector3(half_width, 0, 0), p1 + Vector3(-half_width, 0, 0), colour, code)

	## A spoked bicycle wheel, axle along X.
	func wheel(pos: Vector3, radius: float) -> void:
		ring(radius - 0.05, radius, pos, RUBBER)
		ring(radius - 0.075, radius - 0.05, pos, CHROME)
		cyl(0.035, 0.16, pos, CHROME, Vector3(0, 0, 90), 8)
		for k in 12:
			var a := k * TAU / 12
			var dir := Vector3(0, cos(a), sin(a))
			box(Vector3(0.012, radius - 0.07, 0.012), pos + dir * (radius - 0.07) / 2, CHROME, Vector3(rad_to_deg(a), 0, 0))

	func commit() -> ArrayMesh:
		return st.commit()

	static func _xf(pos: Vector3, rot_deg: Vector3) -> Transform3D:
		return Transform3D(Basis.from_euler(rot_deg * PI / 180.0), pos)


static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.8
	return m


# --- People --------------------------------------------------------------


## A person standing at the origin, ready to walk: shirt PAINT_A, trousers
## PAINT_B, legs and arms marked to swing.
static func person() -> ArrayMesh:
	var b := Builder.new()
	_body(b, Vector3.ZERO, false, true)
	return b.commit()


## Adds a body to b. Seated: thighs forward, for riders and passengers.
## swing: mark the legs (and arms) to swing in the shader.
static func _body(b: Builder, at: Vector3, seated: bool, swing: bool, arms_forward := false) -> void:
	var hip := at.y + (0.92 if not seated else 0.0)
	var lx := 0.1
	for side in [-1, 1]:
		var limb := Vector2(side, hip) if swing else Vector2.ZERO
		if seated:
			b.cyl(0.08, 0.45, Vector3(at.x + side * lx, hip, at.z - 0.22), STEEL.lerp(Color.WHITE, 0.1), Vector3(90, 0, 0), 8, PAINT_B)
			b.cyl(0.07, 0.5, Vector3(at.x + side * lx, hip - 0.25, at.z - 0.45), SKIN, Vector3.ZERO, 8, KEEP, limb)
			b.box(Vector3(0.1, 0.06, 0.22), Vector3(at.x + side * lx, hip - 0.5, at.z - 0.5), RUBBER, Vector3.ZERO, KEEP, limb)
		else:
			b.cyl(0.085, 0.5, Vector3(at.x + side * lx, hip - 0.25, at.z), Color.WHITE, Vector3.ZERO, 8, PAINT_B, limb)
			b.cyl(0.07, 0.42, Vector3(at.x + side * lx, hip - 0.68, at.z), SKIN, Vector3.ZERO, 8, KEEP, limb)
			b.box(Vector3(0.1, 0.06, 0.24), Vector3(at.x + side * lx, 0.03, at.z - 0.05), RUBBER, Vector3.ZERO, KEEP, limb)
	# Hips, torso, shoulders.
	b.cyl(0.17, 0.2, Vector3(at.x, hip + 0.02, at.z), Color.WHITE, Vector3.ZERO, 10, PAINT_B)
	b.cyl(0.19, 0.55, Vector3(at.x, hip + 0.32, at.z), Color.WHITE, Vector3.ZERO, 10, PAINT_A, Vector2.ZERO, 0.21)
	b.box(Vector3(0.48, 0.1, 0.22), Vector3(at.x, hip + 0.58, at.z), Color.WHITE, Vector3.ZERO, PAINT_A)
	# Arms: hanging (swing as they walk) or reaching forward (handlebar).
	for side in [-1, 1]:
		var shoulder := Vector3(at.x + side * 0.25, hip + 0.56, at.z)
		if arms_forward:
			b.cyl(0.055, 0.6, shoulder + Vector3(0, -0.12, -0.28), Color.WHITE, Vector3(-65, 0, 0), 8, PAINT_A)
			b.ball(0.05, shoulder + Vector3(0, -0.25, -0.55), SKIN)
		else:
			var limb := Vector2(side * 0.5, hip + 0.56) if swing else Vector2.ZERO
			b.cyl(0.055, 0.3, shoulder + Vector3(0, -0.15, 0), Color.WHITE, Vector3.ZERO, 8, PAINT_A, limb)
			b.cyl(0.045, 0.3, shoulder + Vector3(0, -0.44, 0), SKIN, Vector3.ZERO, 8, KEEP, limb)
	# Neck, head, hair.
	b.cyl(0.05, 0.1, Vector3(at.x, hip + 0.68, at.z), SKIN)
	b.ball(0.115, Vector3(at.x, hip + 0.82, at.z), SKIN, Vector3(1, 1.12, 1))
	b.ball(0.118, Vector3(at.x, hip + 0.87, at.z + 0.015), HAIR, Vector3(1.02, 0.75, 1.02))


# --- Rickshaw ------------------------------------------------------------


## Painted rickshaw art on a flat panel facing +Z: a bordered picture with a
## flower and leaves, as on the back of every Dhaka rickshaw.
static func _art(b: Builder, centre: Vector3, w: float, h: float) -> void:
	var z := centre.z
	var x0 := centre.x - w / 2
	var y0 := centre.y - h / 2
	var r := Rect2(x0, y0, w, h)
	b.quad(Vector3(r.position.x, r.position.y, z), Vector3(r.end.x, r.position.y, z),
		Vector3(r.end.x, r.end.y, z), Vector3(r.position.x, r.end.y, z), Color("1E3A8A"))
	var inner := r.grow(-0.05)
	z += 0.004
	b.quad(Vector3(inner.position.x, inner.position.y, z), Vector3(inner.end.x, inner.position.y, z),
		Vector3(inner.end.x, inner.end.y, z), Vector3(inner.position.x, inner.end.y, z), Color("F6E7B0"))
	z += 0.004
	var c := Vector2(centre.x, centre.y)
	var petals := [Color("E2432A"), Color("C2185B"), Color("F6B800"), Color("E2432A"), Color("C2185B"), Color("F6B800")]
	for i in 6:
		var a := i * TAU / 6
		var p := c + Vector2(cos(a), sin(a)) * h * 0.18
		var s := h * 0.11
		b.quad(Vector3(p.x - s, p.y, z), Vector3(p.x, p.y - s, z), Vector3(p.x + s, p.y, z), Vector3(p.x, p.y + s, z), petals[i])
	z += 0.004
	b.quad(Vector3(c.x - 0.04, c.y - 0.04, z), Vector3(c.x + 0.04, c.y - 0.04, z),
		Vector3(c.x + 0.04, c.y + 0.04, z), Vector3(c.x - 0.04, c.y + 0.04, z), Color("2E9E6B"))
	for side in [-1, 1]:
		var lc := c + Vector2(side * w * 0.33, 0)
		b.quad(Vector3(lc.x - 0.07, lc.y, z), Vector3(lc.x, lc.y - 0.12, z),
			Vector3(lc.x + 0.07, lc.y, z), Vector3(lc.x, lc.y + 0.12, z), Color("2E9E6B"))


## Adds a cycle rickshaw to b: frame, three spoked wheels (unless the
## caller adds turning ones), carriage, hood, art, the rider (legs marked to
## pedal) and maybe a passenger.
static func _rickshaw(b: Builder, rider: bool, passenger: bool, wheels: bool) -> void:
	if wheels:
		for x in [-0.6, 0.6]:
			b.wheel(Vector3(x, 0.34, 0.45), 0.34)
		b.wheel(Vector3(0, 0.34, -1.2), 0.34)
	# Bicycle front: fork, head tube, down tube, top tube, seat post, saddle,
	# handlebar, crank.
	b.box(Vector3(0.04, 0.75, 0.04), Vector3(0, 0.7, -1.16), STEEL, Vector3(-10, 0, 0))
	b.box(Vector3(0.05, 0.62, 0.05), Vector3(0, 0.72, -0.82), STEEL, Vector3(-45, 0, 0))
	b.box(Vector3(0.04, 0.04, 0.55), Vector3(0, 1.0, -0.8), STEEL)
	b.box(Vector3(0.05, 0.62, 0.05), Vector3(0, 0.72, -0.52), STEEL, Vector3(8, 0, 0))
	b.box(Vector3(0.2, 0.06, 0.28), Vector3(0, 1.05, -0.5), RUBBER)
	b.box(Vector3(0.62, 0.035, 0.035), Vector3(0, 1.15, -1.08), CHROME)
	for x in [-0.31, 0.31]:
		b.cyl(0.025, 0.12, Vector3(x, 1.15, -1.08), RUBBER, Vector3(0, 0, 90), 6)
	b.cyl(0.09, 0.03, Vector3(0.06, 0.4, -0.52), CHROME, Vector3(0, 0, 90), 12)
	# Long bars from the crank back to the rear axle, and the axle.
	for x in [-0.12, 0.12]:
		b.box(Vector3(0.035, 0.035, 1.0), Vector3(x, 0.4, -0.05), STEEL)
	b.box(Vector3(1.25, 0.05, 0.05), Vector3(0, 0.34, 0.45), STEEL)
	# Carriage: footboard, seat box (painted PAINT_B), cushion, backrest.
	b.box(Vector3(1.0, 0.04, 0.42), Vector3(0, 0.52, 0.08), WOOD)
	b.box(Vector3(1.12, 0.32, 0.6), Vector3(0, 0.78, 0.6), Color.WHITE, Vector3.ZERO, PAINT_B)
	b.box(Vector3(1.04, 0.1, 0.52), Vector3(0, 0.99, 0.58), VINYL)
	b.box(Vector3(1.04, 0.5, 0.1), Vector3(0, 1.28, 0.88), VINYL, Vector3(-8, 0, 0))
	for x in [-0.56, 0.56]:
		b.box(Vector3(0.04, 0.45, 0.6), Vector3(x, 1.0, 0.6), Color.WHITE, Vector3.ZERO, PAINT_B)
		b.box(Vector3(0.05, 0.05, 0.5), Vector3(x, 1.25, 0.55), CHROME)
	# Mudguards over the rear wheels.
	for x in [-0.6, 0.6]:
		b.shell(Vector3(x, 0.34, 0.45), 0.4, 20, 160, 0.06, Color.WHITE, PAINT_B, 8)
	# Painted art on the back and on the sides of the seat box.
	_art(b, Vector3(0, 0.72, 0.92), 0.95, 0.42)
	# The hood, folded half up over the seat, with ribs and a fringe.
	var hc := Vector3(0, 1.1, 0.62)
	b.shell(hc, 0.6, 5, 120, 0.56, Color.WHITE, PAINT_A, 12)
	for k in 4:
		var a := deg_to_rad(15 + k * 30)
		var p := hc + Vector3(0, sin(a), cos(a)) * 0.61
		b.box(Vector3(1.14, 0.035, 0.035), p, STEEL)
	for side in [-1, 1]:
		b.quad(hc + Vector3(side * 0.565, 0, 0.6), hc + Vector3(side * 0.565, 0.6, 0),
			hc + Vector3(side * 0.565, 0.3, -0.1), hc + Vector3(side * 0.565, -0.05, 0.25), Color("E2432A"))
	var front := deg_to_rad(120)
	var edge := hc + Vector3(0, sin(front), cos(front)) * 0.6
	for i in 9:
		var x := -0.5 + i * 0.125
		b.quad(edge + Vector3(x - 0.03, 0, 0), edge + Vector3(x + 0.03, 0, 0),
			edge + Vector3(x + 0.03, -0.12, 0), edge + Vector3(x - 0.03, -0.12, 0),
			[Color("F6B800"), Color("2E9E6B"), Color("E2432A")][i % 3])
	if rider:
		_body(b, Vector3(0, 1.08, -0.42), true, true, true)
	if passenger:
		_body(b, Vector3(0, 1.04, 0.66), true, false)


## A whole rickshaw in one mesh, for traffic.
static func rickshaw(passenger := false) -> ArrayMesh:
	var b := Builder.new()
	_rickshaw(b, true, passenger, true)
	return b.commit()


## Rahim Chacha's rickshaw: the body in one mesh, the three wheels as
## children that turn, the rider's legs marked to pedal (traffic shader).
static func player_rickshaw(hood: Color, body: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Rickshaw"
	var b := Builder.new()
	_rickshaw(b, true, false, false)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	root.add_child(mi)
	var wheels: Array[Node3D] = []
	for at in [Vector3(-0.6, 0.34, 0.45), Vector3(0.6, 0.34, 0.45), Vector3(0, 0.34, -1.2)]:
		var wb := Builder.new()
		wb.wheel(Vector3.ZERO, 0.34)
		var w := MeshInstance3D.new()
		w.mesh = wb.commit()
		w.position = at
		root.add_child(w)
		wheels.append(w)
	root.set_meta("wheels", wheels)
	root.set_meta("body", mi)
	root.set_meta("colours", [hood, body])
	return root


# --- CNG and bus -----------------------------------------------------------


## A green CNG auto-rickshaw: rounded nose, black canopy, grilled doors.
static func cng() -> ArrayMesh:
	var b := Builder.new()
	var green := Color("2F8F3E")
	for x in [-0.62, 0.62]:
		b.cyl(0.26, 0.14, Vector3(x, 0.26, 0.65), RUBBER, Vector3(0, 0, 90), 12)
	b.cyl(0.26, 0.14, Vector3(0, 0.26, -1.0), RUBBER, Vector3(0, 0, 90), 12)
	b.box(Vector3(1.35, 0.55, 2.2), Vector3(0, 0.72, 0.05), green)
	b.cyl(0.66, 0.55, Vector3(0, 0.72, -1.0), green, Vector3.ZERO, 14)
	b.box(Vector3(1.32, 0.04, 2.0), Vector3(0, 1.0, 0.1), Color("D8D8D8"))
	# Canopy: black, curved, over a steel cage with grilled sides.
	b.shell(Vector3(0, 1.45, 0.2), 0.62, 0, 180, 0.69, Color("151515"), KEEP, 10)
	b.box(Vector3(1.38, 0.08, 1.2), Vector3(0, 2.05, 0.2), Color("151515"))
	for x in [-0.66, 0.66]:
		for k in 9:
			b.box(Vector3(0.02, 0.9, 0.02), Vector3(x, 1.45, -0.3 + k * 0.14), green.darkened(0.3))
		b.box(Vector3(0.03, 0.03, 1.2), Vector3(x, 1.2, 0.25), green.darkened(0.3))
	b.quad(Vector3(-0.62, 1.05, -0.62), Vector3(0.62, 1.05, -0.62), Vector3(0.62, 1.85, -0.5), Vector3(-0.62, 1.85, -0.5), Color("A9CDE0"))
	b.cyl(0.11, 0.06, Vector3(0, 0.95, -1.62), Color("FFF2A8"), Vector3(90, 0, 0), 12)
	b.box(Vector3(0.9, 0.18, 0.04), Vector3(0, 0.55, 1.16), Color("F2F2F2"))
	_body(b, Vector3(0, 1.0, -0.45), true, false, true)
	return b.commit()


## A Dhaka local bus: boxy, dented paint (PAINT_A), a stripe (PAINT_B), a
## row of windows with pillars, an open door, a roof rack.
static func bus() -> ArrayMesh:
	var b := Builder.new()
	for z in [3.0, -2.8]:
		for x in [-1.12, 1.12]:
			b.cyl(0.5, 0.3, Vector3(x, 0.5, z), RUBBER, Vector3(0, 0, 90), 14)
			b.cyl(0.25, 0.32, Vector3(x, 0.5, z), CHROME, Vector3(0, 0, 90), 10)
	b.box(Vector3(2.4, 1.3, 9.0), Vector3(0, 1.25, 0), Color.WHITE, Vector3.ZERO, PAINT_A)
	b.box(Vector3(2.42, 0.22, 9.02), Vector3(0, 1.55, 0), Color.WHITE, Vector3.ZERO, PAINT_B)
	b.box(Vector3(2.4, 0.35, 9.0), Vector3(0, 2.92, 0), Color.WHITE, Vector3.ZERO, PAINT_A)
	# Windows: dark glass behind pillars.
	b.box(Vector3(2.36, 1.0, 8.8), Vector3(0, 2.25, 0), Color("27343C"))
	for k in 10:
		var pillar := -4.3 + k * 0.95
		for x in [-1.21, 1.21]:
			b.box(Vector3(0.04, 1.0, 0.12), Vector3(x, 2.25, pillar), Color.WHITE, Vector3.ZERO, PAINT_A)
	b.quad(Vector3(-1.1, 1.8, -4.52), Vector3(1.1, 1.8, -4.52), Vector3(1.1, 2.75, -4.52), Vector3(-1.1, 2.75, -4.52), Color("9FC3D6"))
	# The open front door on the left, with a man hanging on.
	b.box(Vector3(0.05, 1.9, 0.8), Vector3(-1.22, 1.55, -3.4), Color("111111"))
	_body(b, Vector3(-1.45, 0.62, -3.2), false, false)
	# Roof rack and lights.
	b.box(Vector3(2.0, 0.08, 6.0), Vector3(0, 3.22, 0.5), STEEL)
	for x in [-0.85, 0.85]:
		b.cyl(0.13, 0.06, Vector3(x, 1.2, -4.52), Color("FFF2A8"), Vector3(90, 0, 0), 12)
	b.box(Vector3(1.6, 0.3, 0.05), Vector3(0, 2.92, -4.53), Color("111111"))
	return b.commit()


# --- The shader that colours and moves the traffic --------------------------


static var _shaders := {}


## One material for all traffic and people: swaps PAINT_A/PAINT_B for
## per-copy colours (INSTANCE_CUSTOM.z and .w index `palette`), and swings
## the marked limbs (INSTANCE_CUSTOM.x: phase; .y: 0 standing, 1 walking).
## For a single mesh (multimesh false) the same four numbers come from the
## `custom_data` parameter instead.
static func traffic_material(palette: PackedColorArray, multimesh := true) -> ShaderMaterial:
	if not _shaders.has(multimesh):
		var code := SHADER if multimesh else SHADER.replace("INSTANCE_CUSTOM", "custom_data").replace("uniform vec4 palette[16];", "uniform vec4 palette[16];\nuniform vec4 custom_data;")
		var shader := Shader.new()
		shader.code = code
		_shaders[multimesh] = shader
	var m := ShaderMaterial.new()
	m.shader = _shaders[multimesh]
	var values := PackedVector4Array()
	for i in 16:
		var c: Color = palette[i % palette.size()]
		values.append(Vector4(c.r, c.g, c.b, 1.0))
	m.set_shader_parameter("palette", values)
	return m


const SHADER := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec4 palette[16];
varying vec3 tint;

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec3 c = COLOR.rgb;
	if (COLOR.a < 0.9) {
		float pick = COLOR.a > 0.6 ? INSTANCE_CUSTOM.z : INSTANCE_CUSTOM.w;
		c = palette[clamp(int(pick + 0.5), 0, 15)].rgb * c;
	}
	tint = to_linear(c);
	float limb = UV.x;
	if (abs(limb) > 0.01) {
		float dir = limb > 0.0 ? 1.0 : -1.0;
		float arm = abs(limb) < 0.75 ? -0.8 : 1.0;
		float a = sin(TIME * 7.0 + INSTANCE_CUSTOM.x) * 0.5 * dir * arm * INSTANCE_CUSTOM.y;
		float py = UV.y;
		float ca = cos(a);
		float sa = sin(a);
		vec3 v = VERTEX - vec3(0.0, py, 0.0);
		VERTEX = vec3(v.x, v.y * ca - v.z * sa, v.y * sa + v.z * ca) + vec3(0.0, py, 0.0);
		NORMAL = vec3(NORMAL.x, NORMAL.y * ca - NORMAL.z * sa, NORMAL.y * sa + NORMAL.z * ca);
	}
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.85;
}
"""
