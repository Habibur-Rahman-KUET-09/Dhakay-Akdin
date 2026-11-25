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

const Graphics = preload("res://scripts/ui/graphics.gd")

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
## How many decoration styles a rickshaw comes in.
const STYLES := 3


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


## Painted rickshaw art on a flat panel facing +Z, as on the back of every
## Dhaka rickshaw: a bordered picture studded with chrome. Three pictures
## (style): a flower with leaves, a boat on a river at sunset, a heart.
static func _art(b: Builder, centre: Vector3, w: float, h: float, style := 0) -> void:
	var z := centre.z
	var r := Rect2(centre.x - w / 2, centre.y - h / 2, w, h)
	_rect_xy(b, r, z, Color.WHITE, deco(style + 4))
	var dot_z := z + 0.003
	for i in 14:
		var t := (i + 0.5) / 14.0
		for y in [r.position.y + 0.025, r.end.y - 0.025]:
			_dot(b, Vector3(lerpf(r.position.x, r.end.x, t), y, dot_z), 0.013, CHROME)
	for i in 5:
		var t := (i + 0.5) / 5.0
		for x in [r.position.x + 0.025, r.end.x - 0.025]:
			_dot(b, Vector3(x, lerpf(r.position.y, r.end.y, t), dot_z), 0.013, CHROME)
	var inner := r.grow(-0.05)
	z += 0.004
	_rect_xy(b, inner, z, Color("F6E7B0"), KEEP)
	z += 0.004
	var c := Vector2(centre.x, centre.y)
	match style:
		1:
			# Evening sky, the river, the sun going down, a boat with a sail.
			_rect_xy(b, Rect2(inner.position.x, inner.position.y + inner.size.y * 0.4, inner.size.x, inner.size.y * 0.6), z, Color("F9C784"), KEEP)
			_rect_xy(b, Rect2(inner.position.x, inner.position.y, inner.size.x, inner.size.y * 0.4), z, Color("2D8BD6"), KEEP)
			z += 0.004
			_disc_xy(b, Vector3(c.x + w * 0.2, inner.position.y + inner.size.y * 0.62, z), h * 0.11, Color("E2432A"))
			var bx := c.x - w * 0.14
			var hy := inner.position.y + inner.size.y * 0.32
			b.quad(Vector3(bx - 0.11, hy - 0.025, z), Vector3(bx + 0.11, hy - 0.025, z),
				Vector3(bx + 0.16, hy + 0.035, z), Vector3(bx - 0.16, hy + 0.035, z), Color("3E2A20"))
			b.quad(Vector3(bx, hy + 0.04, z), Vector3(bx + 0.11, hy + 0.05, z),
				Vector3(bx, hy + 0.2, z), Vector3(bx, hy + 0.2, z), Color("F2F2F2"))
			for i in 4:
				_dot(b, Vector3(inner.position.x + 0.1 + i * 0.2, inner.position.y + 0.04, z), 0.02, Color("BFE3F2"))
		2:
			# A red heart between two green leaves, little coloured diamonds round it.
			var rr := h * 0.12
			var hc := Vector3(c.x, c.y + rr * 0.3, z)
			for side in [-1, 1]:
				_disc_xy(b, hc + Vector3(side * rr * 0.75, rr * 0.3, 0), rr, Color("C62828"))
			b.quad(Vector3(c.x - rr * 1.72, hc.y + rr * 0.15, z), Vector3(c.x + rr * 1.72, hc.y + rr * 0.15, z),
				Vector3(c.x, hc.y - rr * 1.8, z), Vector3(c.x, hc.y - rr * 1.8, z), Color("C62828"))
			for i in 6:
				var a := i * TAU / 6 + 0.3
				_dot(b, Vector3(c.x + cos(a) * w * 0.25, c.y + sin(a) * h * 0.32, z), 0.025, Color.WHITE, deco(i))
			for side in [-1, 1]:
				var lc := c + Vector2(side * w * 0.36, 0)
				b.quad(Vector3(lc.x - 0.06, lc.y, z), Vector3(lc.x, lc.y - 0.11, z),
					Vector3(lc.x + 0.06, lc.y, z), Vector3(lc.x, lc.y + 0.11, z), Color("2E9E6B"))
		_:
			# A flower with six petals and two leaves.
			for i in 6:
				var a := i * TAU / 6
				var p := c + Vector2(cos(a), sin(a)) * h * 0.18
				var s := h * 0.11
				b.quad(Vector3(p.x - s, p.y, z), Vector3(p.x, p.y - s, z), Vector3(p.x + s, p.y, z), Vector3(p.x, p.y + s, z),
					Color.WHITE, deco(i % 3))
			z += 0.004
			_dot(b, Vector3(c.x, c.y, z), 0.05, Color("F6B800"))
			for side in [-1, 1]:
				var lc := c + Vector2(side * w * 0.33, 0)
				b.quad(Vector3(lc.x - 0.07, lc.y, z), Vector3(lc.x, lc.y - 0.12, z),
					Vector3(lc.x + 0.07, lc.y, z), Vector3(lc.x, lc.y + 0.12, z), Color("2E9E6B"))


## The vertex code of decoration colour k: a bright colour from the
## palette, a different set on every rickshaw (see SHADER).
static func deco(k: int) -> float:
	return (2.0 + k % 6) / 25.5


## A rectangle on a panel facing +Z.
static func _rect_xy(b: Builder, r: Rect2, z: float, colour: Color, code := KEEP) -> void:
	b.quad(Vector3(r.position.x, r.position.y, z), Vector3(r.end.x, r.position.y, z),
		Vector3(r.end.x, r.end.y, z), Vector3(r.position.x, r.end.y, z), colour, code)


## A round disc on a panel facing +Z.
static func _disc_xy(b: Builder, centre: Vector3, radius: float, colour: Color, code := KEEP) -> void:
	for i in 12:
		var a0 := i * TAU / 12
		var a1 := (i + 1) * TAU / 12
		var p0 := centre + Vector3(cos(a0), sin(a0), 0) * radius
		var p1 := centre + Vector3(cos(a1), sin(a1), 0) * radius
		b.quad(centre, p0, p1, p1, colour, code)


## A small diamond on a panel facing +Z (a chrome stud, a sequin).
static func _dot(b: Builder, at: Vector3, s: float, colour: Color, code := KEEP) -> void:
	b.quad(at + Vector3(-s, 0, 0), at + Vector3(0, -s, 0), at + Vector3(s, 0, 0), at + Vector3(0, s, 0), colour, code)


## A slice of a disc in the plane across X (the side of a hood): angle 0
## points to +Z, 90 straight up.
static func _fan(b: Builder, hinge: Vector3, radius: float, from_deg: float, to_deg: float, segments: int, colour: Color, code := KEEP) -> void:
	for i in segments:
		var a0 := deg_to_rad(lerpf(from_deg, to_deg, float(i) / segments))
		var a1 := deg_to_rad(lerpf(from_deg, to_deg, float(i + 1) / segments))
		var p0 := hinge + Vector3(0, sin(a0), cos(a0)) * radius
		var p1 := hinge + Vector3(0, sin(a1), cos(a1)) * radius
		b.quad(hinge, p0, p1, p1, colour, code)


## What is painted on the side of the hood: a sunburst (style 0), rings
## of colour like a rainbow (1), or a peacock's tail (2).
static func _hood_side(b: Builder, hinge: Vector3, side: int, style: int) -> void:
	var out := Vector3(side * 0.002, 0, 0)
	match style:
		1:
			for k in 5:
				_fan(b, hinge + out * k, 0.6 - k * 0.1, 5.0, 120.0, 10, Color.WHITE, deco(k + 1))
		2:
			for i in 9:
				_fan(b, hinge, 0.6, lerpf(5.0, 120.0, i / 9.0), lerpf(5.0, 120.0, (i + 1) / 9.0), 1, Color.WHITE, deco(2 if i % 2 == 0 else 4))
			for i in 9:
				var a := deg_to_rad(lerpf(5.0, 120.0, (i + 0.5) / 9.0))
				var eye := hinge + out * 2 + Vector3(0, sin(a), cos(a)) * 0.47
				for ring in 2:
					var s := 0.06 if ring == 0 else 0.03
					var at := eye + out * ring
					b.quad(at + Vector3(0, -s, 0), at + Vector3(0, 0, s), at + Vector3(0, s, 0), at + Vector3(0, 0, -s),
						Color.WHITE if ring == 0 else Color("1C3E7B"), deco(0) if ring == 0 else KEEP)
			_fan(b, hinge + out * 3, 0.13, 5.0, 120.0, 6, Color("2E9E6B"))
		_:
			for i in 11:
				_fan(b, hinge, 0.6, lerpf(5.0, 120.0, i / 11.0), lerpf(5.0, 120.0, (i + 1) / 11.0), 1, Color.WHITE, deco(i))
			_fan(b, hinge + out, 0.17, 5.0, 120.0, 8, Color("FFD23F"))


## Adds a cycle rickshaw to b: frame, three spoked wheels (unless the
## caller adds turning ones), carriage, hood, art, the rider (legs marked to
## pedal) and maybe a passenger. Three styles of decoration (0–2), each
## in its own colours on every rickshaw (deco codes).
static func _rickshaw(b: Builder, rider: bool, passenger: bool, wheels: bool, style := 0) -> void:
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
	_art(b, Vector3(0, 0.72, 0.92), 0.95, 0.42, style)
	# The hood, folded half up over the seat: painted cloth with ribs, a
	# picture on each side and a fringe along the front.
	var hc := Vector3(0, 1.1, 0.62)
	b.shell(hc, 0.6, 5, 120, 0.56, Color.WHITE, PAINT_A, 12)
	match style:
		1:
			# Studded all over with coloured diamonds.
			for j in 6:
				var a := deg_to_rad(20 + j * 17)
				var row := hc + Vector3(0, sin(a), cos(a)) * 0.606
				var t := Vector3(0, cos(a), -sin(a))
				for i in 7:
					var x := -0.45 + i * 0.15 + (0.075 if j % 2 == 1 else 0.0)
					if absf(x) > 0.5:
						continue
					var p := row + Vector3(x, 0, 0)
					b.quad(p + Vector3(-0.045, 0, 0), p - t * 0.045, p + Vector3(0.045, 0, 0), p + t * 0.045, Color.WHITE, deco(i + j))
		2:
			# A broad band at the back, a thin one in the middle, a row of
			# triangles along the front.
			b.shell(hc, 0.604, 12, 26, 0.562, Color.WHITE, deco(1), 2)
			b.shell(hc, 0.604, 62, 66, 0.562, Color.WHITE, deco(3), 1)
			var base := deg_to_rad(117)
			var tip := deg_to_rad(103)
			for i in 10:
				var x0 := -0.55 + i * 0.11
				var p0 := hc + Vector3(x0, sin(base) * 0.606, cos(base) * 0.606)
				var p1 := p0 + Vector3(0.11, 0, 0)
				var pt := hc + Vector3(x0 + 0.055, sin(tip) * 0.606, cos(tip) * 0.606)
				b.quad(p0, p1, pt, pt, Color.WHITE, deco(i % 2 * 2))
		_:
			# Bands of colour across the hood.
			for k in 5:
				var a0 := 12.0 + k * 22.0
				b.shell(hc, 0.604, a0, a0 + 6.0, 0.562, Color.WHITE, deco(k), 1)
	for k in 4:
		var a := deg_to_rad(15 + k * 30)
		var p := hc + Vector3(0, sin(a), cos(a)) * 0.61
		b.box(Vector3(1.14, 0.035, 0.035), p, STEEL)
	for side in [-1, 1]:
		_hood_side(b, hc + Vector3(side * 0.566, 0, 0), side, style)
	var front := deg_to_rad(120)
	var edge := hc + Vector3(0, sin(front), cos(front)) * 0.6
	for i in 9:
		var x := -0.5 + i * 0.125
		b.quad(edge + Vector3(x - 0.03, 0, 0), edge + Vector3(x + 0.03, 0, 0),
			edge + Vector3(x + 0.03, -0.12, 0), edge + Vector3(x - 0.03, -0.12, 0),
			Color.WHITE, deco(i + style))
	match style:
		0:
			# Two pennants on chrome rods at the front corners.
			for side in [-1, 1]:
				var foot := edge + Vector3(side * 0.5, 0, 0)
				b.box(Vector3(0.015, 0.38, 0.015), foot + Vector3(0, 0.19, 0), CHROME)
				var top := foot + Vector3(0, 0.38, 0)
				b.quad(top, top + Vector3(0, -0.14, 0), top + Vector3(0, -0.07, -0.2), top + Vector3(0, -0.07, -0.2),
					Color.WHITE, deco(3 if side < 0 else 1))
		1:
			# A bunch of plastic flowers on top of the hood.
			var at := edge + Vector3(0, 0.05, 0.05)
			for i in 7:
				var a := i * TAU / 7
				var bloom := at + Vector3(cos(a) * 0.09, 0.16 + 0.04 * (i % 2), sin(a) * 0.06)
				b.box(Vector3(0.012, 0.16, 0.012), (at + bloom) / 2, Color("2E9E6B"))
				b.ball(0.045, bloom, Color.WHITE, Vector3(1, 0.7, 1), deco(i))
		_:
			# A small Bangladesh flag on the right.
			var foot := edge + Vector3(0.5, 0, 0)
			b.box(Vector3(0.015, 0.5, 0.015), foot + Vector3(0, 0.25, 0), CHROME)
			var top := foot + Vector3(0, 0.5, 0)
			b.quad(top + Vector3(0, -0.15, 0), top, top + Vector3(0, 0, -0.25), top + Vector3(0, -0.15, -0.25), Color("006A4E"))
			var disc := top + Vector3(0, -0.075, -0.11)
			for side in [-1, 1]:
				for i in 10:
					var a0 := i * TAU / 10
					var a1 := (i + 1) * TAU / 10
					var q0 := disc + Vector3(side * 0.003, sin(a0) * 0.045, cos(a0) * 0.045)
					var q1 := disc + Vector3(side * 0.003, sin(a1) * 0.045, cos(a1) * 0.045)
					b.quad(disc + Vector3(side * 0.003, 0, 0), q0, q1, q1, Color("F42A41"))
			# Round chrome mirrors on stalks at the ends of the handlebar.
			for side in [-1, 1]:
				b.box(Vector3(0.012, 0.22, 0.012), Vector3(side * 0.29, 1.27, -1.08), CHROME)
				b.cyl(0.055, 0.015, Vector3(side * 0.29, 1.4, -1.08), CHROME, Vector3(90, 0, 0), 12)
	# Plastic flowers and tassels on the handlebar.
	for k in 5:
		var x := -0.24 + k * 0.12
		var at := Vector3(x, 1.2 + 0.03 * (k % 2), -1.08)
		b.box(Vector3(0.012, 0.08, 0.012), at + Vector3(0, -0.04, 0), Color("2E9E6B"))
		b.ball(0.04, at, Color.WHITE, Vector3(1, 0.7, 1), deco(k * 2 + style))
		b.ball(0.015, at + Vector3(0, 0.025, 0), Color("FFE45C"))
	for x in [-0.31, 0.31]:
		for t in 3:
			b.box(Vector3(0.012, 0.16, 0.012), Vector3(x + (t - 1) * 0.015, 1.06, -1.08), Color.WHITE, Vector3.ZERO, deco(t + 3))
	if rider:
		_body(b, Vector3(0, 1.08, -0.42), true, true, true)
	if passenger:
		_body(b, Vector3(0, 1.04, 0.66), true, false)


## A whole rickshaw in one mesh, for traffic (or parked, without a rider).
static func rickshaw(passenger := false, rider := true, style := 0) -> ArrayMesh:
	var b := Builder.new()
	_rickshaw(b, rider, passenger, true, style)
	return b.commit()


## A passenger sitting on the rickshaw seat (shirt PAINT_A, trousers
## PAINT_B), to show on Rahim Chacha's rickshaw during a trip.
static func seated_passenger() -> ArrayMesh:
	var b := Builder.new()
	_body(b, Vector3(0, 1.04, 0.66), true, false)
	return b.commit()


## A fruit seller's van (a flat three-wheeled cart): a plank bed piled with
## bananas, oranges, apples and green coconuts, under a faded umbrella.
static func fruit_cart() -> ArrayMesh:
	var b := Builder.new()
	for x in [-0.62, 0.62]:
		b.wheel(Vector3(x, 0.34, 0.5), 0.34)
	b.wheel(Vector3(0, 0.34, -1.05), 0.34)
	b.box(Vector3(1.3, 0.08, 1.5), Vector3(0, 0.72, 0.2), WOOD)
	b.box(Vector3(0.04, 0.6, 0.04), Vector3(0, 0.5, -0.8), STEEL, Vector3(-30, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var fruit := [Color("F2C230"), Color("F28C28"), Color("C62828"), Color("6FAE3A")]
	for i in 46:
		var c: Color = fruit[i % fruit.size()]
		var r := 0.09 if i % 4 != 3 else 0.13
		var x := rng.randf_range(-0.55, 0.55)
		var z := rng.randf_range(-0.45, 0.85)
		var mound := 0.25 * (1.0 - absf(x) / 0.7) * (1.0 - absf(z - 0.2) / 0.8)
		b.ball(r, Vector3(x, 0.8 + mound + r, z), c)
	b.box(Vector3(0.04, 1.6, 0.04), Vector3(0.5, 1.5, 0.75), STEEL)
	b.shell(Vector3(0.5, 2.0, 0.75), 0.9, 60, 120, 0.9, Color("2D8BD6").lerp(Color.WHITE, 0.35), KEEP, 6)
	b.shell(Vector3(0.5, 2.0, 0.75), 0.9, 60, 120, 0.02, Color("D7263D"), KEEP, 6)
	_body(b, Vector3(-0.9, 0.0, 0.2), false, false)
	return b.commit()


## A mosque: a white prayer hall with a green dome and a tall minaret.
static func mosque() -> ArrayMesh:
	var b := Builder.new()
	var white := Color("F1EEE6")
	var green := Color("2E8B57")
	b.box(Vector3(4.6, 4.2, 4.6), Vector3(0, 2.1, 0), white)
	for x in [-1.4, 0.0, 1.4]:
		b.box(Vector3(0.8, 1.6, 0.06), Vector3(x, 1.6, -2.31), Color("3B6E5A"))
	b.cyl(1.7, 0.5, Vector3(0, 4.45, 0), white, Vector3.ZERO, 16)
	b.ball(1.65, Vector3(0, 4.7, 0), green, Vector3(1, 1.15, 1))
	b.cyl(0.05, 0.9, Vector3(0, 7.0, 0), Color("D4AF37"))
	b.cyl(0.42, 11.0, Vector3(2.0, 5.5, 2.0), white, Vector3.ZERO, 10, KEEP, Vector2.ZERO, 0.36)
	b.cyl(0.62, 0.35, Vector3(2.0, 8.6, 2.0), white, Vector3.ZERO, 12)
	b.ball(0.42, Vector3(2.0, 11.2, 2.0), green, Vector3(1, 1.3, 1))
	b.cyl(0.04, 0.7, Vector3(2.0, 12.0, 2.0), Color("D4AF37"))
	return b.commit()


## A billboard on two steel legs, for a rooftop: a board (lettered by the
## caller) in a steel frame.
static func billboard_frame() -> ArrayMesh:
	var b := Builder.new()
	for x in [-2.2, 2.2]:
		b.box(Vector3(0.18, 3.0, 0.18), Vector3(x, 1.5, 0.3), STEEL)
		b.box(Vector3(0.12, 3.2, 0.12), Vector3(x, 1.6, 1.2), STEEL, Vector3(-18, 0, 0))
	b.box(Vector3(6.2, 3.1, 0.16), Vector3(0, 4.4, 0), STEEL)
	b.box(Vector3(6.0, 2.9, 0.05), Vector3(0, 4.4, -0.1), Color.WHITE, Vector3.ZERO, PAINT_A)
	b.box(Vector3(6.0, 0.6, 0.06), Vector3(0, 3.3, -0.11), Color.WHITE, Vector3.ZERO, PAINT_B)
	return b.commit()


## Rahim Chacha's rickshaw: the body in one mesh, the three wheels as
## children that turn, the rider's legs marked to pedal (traffic shader).
static func player_rickshaw(hood: Color, body: Color, style := 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Rickshaw"
	var b := Builder.new()
	_rickshaw(b, true, false, false, style)
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


# --- Ratul's bicycle (phase 8) ------------------------------------------------


## Ratul's delivery bicycle, facing -Z like the rickshaw: a painted frame
## (PAINT_B), a big insulated food box on the rack (PAINT_A, with a white
## band), Ratul riding in his cap. The same metas as the player's
## rickshaw ("wheels", "body", "colours"), so the street scene treats it
## alike.
static func player_bicycle(box: Color, frame: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Bicycle"
	var b := Builder.new()
	# The frame: top tube, down tube, seat tube, the stays to the back axle.
	b.box(Vector3(0.05, 0.05, 0.72), Vector3(0, 0.82, -0.08), Color.WHITE, Vector3(-6, 0, 0), PAINT_B)
	b.box(Vector3(0.05, 0.05, 0.78), Vector3(0, 0.6, -0.2), Color.WHITE, Vector3(-38, 0, 0), PAINT_B)
	b.box(Vector3(0.05, 0.55, 0.05), Vector3(0, 0.64, 0.12), Color.WHITE, Vector3(-12, 0, 0), PAINT_B)
	for x in [-0.06, 0.06]:
		b.box(Vector3(0.03, 0.03, 0.5), Vector3(x, 0.38, 0.32), Color.WHITE, Vector3(0, 0, 0), PAINT_B)
		b.box(Vector3(0.03, 0.03, 0.5), Vector3(x, 0.6, 0.36), Color.WHITE, Vector3(48, 0, 0), PAINT_B)
	# Fork, handlebar with grips, saddle, crank and the front lamp.
	b.box(Vector3(0.04, 0.62, 0.04), Vector3(0, 0.64, -0.5), STEEL, Vector3(-14, 0, 0))
	b.box(Vector3(0.56, 0.035, 0.035), Vector3(0, 1.0, -0.42), CHROME)
	for x in [-0.28, 0.28]:
		b.cyl(0.025, 0.1, Vector3(x, 1.0, -0.42), RUBBER, Vector3(0, 0, 90), 6)
	b.box(Vector3(0.16, 0.05, 0.26), Vector3(0, 0.92, 0.16), RUBBER)
	b.cyl(0.08, 0.03, Vector3(0.05, 0.38, 0.06), CHROME, Vector3(0, 0, 90), 12)
	b.cyl(0.05, 0.06, Vector3(0, 0.92, -0.5), Color("FFF3B0"), Vector3(90, 0, 0), 8)
	# The rack and the food box, with a band of white round it.
	b.box(Vector3(0.42, 0.03, 0.4), Vector3(0, 0.86, 0.5), STEEL)
	b.box(Vector3(0.46, 0.44, 0.44), Vector3(0, 1.1, 0.52), Color.WHITE, Vector3.ZERO, PAINT_A)
	b.box(Vector3(0.47, 0.07, 0.45), Vector3(0, 1.12, 0.52), Color("F4F1E8"))
	b.box(Vector3(0.48, 0.04, 0.46), Vector3(0, 1.33, 0.52), Color.WHITE, Vector3.ZERO, PAINT_A)
	# Ratul, pedalling, and a cap.
	_body(b, Vector3(0, 0.95, 0.2), true, true, true)
	b.cyl(0.13, 0.08, Vector3(0, 1.86, 0.18), Color.WHITE, Vector3.ZERO, 10, PAINT_A)
	b.box(Vector3(0.18, 0.02, 0.12), Vector3(0, 1.83, 0.06), Color.WHITE, Vector3.ZERO, PAINT_A)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	root.add_child(mi)
	var wheels: Array[Node3D] = []
	for at in [Vector3(0, 0.34, -0.55), Vector3(0, 0.34, 0.58)]:
		var wb := Builder.new()
		wb.wheel(Vector3.ZERO, 0.34)
		var w := MeshInstance3D.new()
		w.mesh = wb.commit()
		w.position = at
		root.add_child(w)
		wheels.append(w)
	root.set_meta("wheels", wheels)
	root.set_meta("body", mi)
	root.set_meta("colours", [box, frame])
	return root


# --- Monir Mama's tea stall ------------------------------------------------


## A Dhaka tong (tea stall) against a wall, facing -Z: a painted wooden
## counter, tin roof on bamboo posts, a shelf of jars, a kettle on a clay
## stove, glasses, a milk can, the sugar pot, a bunch of bananas hanging
## from the roof and the paan tray. The counter's top is at y = 1.0, its
## front at z = -0.45.
static func tea_stall() -> ArrayMesh:
	var b := Builder.new()
	var wood := Color("8B5A2B")
	var green := Color("2E7D4F")
	# Counter: a box with a painted front and a yellow band.
	b.box(Vector3(2.4, 1.0, 0.9), Vector3(0, 0.5, 0), wood)
	b.box(Vector3(2.42, 0.6, 0.02), Vector3(0, 0.45, -0.46), green)
	b.box(Vector3(2.42, 0.1, 0.025), Vector3(0, 0.8, -0.465), Color("F6B800"))
	b.box(Vector3(2.5, 0.05, 1.0), Vector3(0, 1.02, 0), wood.darkened(0.25))
	# Posts and a sloping tin roof with a cloth edge.
	for x in [-1.2, 1.2]:
		for z in [-0.45, 0.5]:
			b.cyl(0.04, 2.5, Vector3(x, 1.25, z), Color("C8A96A"), Vector3.ZERO, 6)
	b.box(Vector3(2.9, 0.04, 1.6), Vector3(0, 2.52, 0.0), Color("9AA3A8"), Vector3(-8, 0, 0))
	b.box(Vector3(2.9, 0.22, 0.02), Vector3(0, 2.52, -0.8), Color("C2185B"))
	for i in 12:
		var x := -1.4 + i * 0.255
		b.quad(Vector3(x, 2.41, -0.81), Vector3(x + 0.12, 2.41, -0.81), Vector3(x + 0.06, 2.3, -0.81), Vector3(x + 0.06, 2.3, -0.81),
			Color("F6B800") if i % 2 == 0 else Color("2E9E6B"))
	# Back wall of the stall and a shelf of jars (biscuits, buns).
	b.box(Vector3(2.4, 2.4, 0.04), Vector3(0, 1.2, 0.5), wood.darkened(0.35))
	b.box(Vector3(2.2, 0.04, 0.3), Vector3(0, 1.75, 0.36), wood)
	var jars := [Color("E8D9B0"), Color("F2C14E"), Color("D98E5A"), Color("E8D9B0"), Color("C9B27C"), Color("F2C14E")]
	for i in jars.size():
		var x := -0.9 + i * 0.36
		b.cyl(0.11, 0.3, Vector3(x, 1.92, 0.36), jars[i], Vector3.ZERO, 10)
		b.cyl(0.115, 0.05, Vector3(x, 2.09, 0.36), Color("D7263D"), Vector3.ZERO, 10)
	# A calendar and a small mirror on the wall.
	b.quad(Vector3(0.55, 1.2, 0.47), Vector3(0.95, 1.2, 0.47), Vector3(0.95, 1.65, 0.47), Vector3(0.55, 1.65, 0.47), Color("F2F2F2"))
	b.quad(Vector3(0.58, 1.45, 0.465), Vector3(0.92, 1.45, 0.465), Vector3(0.92, 1.62, 0.465), Vector3(0.58, 1.62, 0.465), Color("2D8BD6"))
	# Clay stove and the aluminium kettle (right).
	b.cyl(0.2, 0.22, Vector3(0.75, 1.15, 0.05), Color("8A4B2A"), Vector3.ZERO, 12)
	b.cyl(0.13, 0.03, Vector3(0.75, 1.27, 0.05), Color("FF7A1A"), Vector3.ZERO, 12)
	b.cyl(0.17, 0.26, Vector3(0.75, 1.42, 0.05), Color("C9CDD2"), Vector3.ZERO, 14, KEEP, Vector2.ZERO, 0.12)
	b.ball(0.04, Vector3(0.75, 1.58, 0.05), Color("3C3F44"))
	b.cyl(0.025, 0.25, Vector3(0.58, 1.45, -0.05), Color("C9CDD2"), Vector3(0, 0, 55), 8)
	b.shell(Vector3(0.75, 1.45, 0.05), 0.2, 30, 150, 0.01, Color("3C3F44"), KEEP, 6)
	# A row of small glasses, a milk can, the sugar pot (left of centre).
	for i in 6:
		b.cyl(0.035, 0.09, Vector3(-0.15 + i * 0.09, 1.09, -0.25), Color("D9B36C"), Vector3.ZERO, 8)
	b.cyl(0.1, 0.28, Vector3(-0.45, 1.18, 0.1), Color("E6E9EC"), Vector3.ZERO, 12)
	b.cyl(0.08, 0.14, Vector3(-0.2, 1.1, 0.15), Color("D7263D"), Vector3.ZERO, 12)
	# The paan tray (left): a brass plate with green leaves.
	b.cyl(0.2, 0.04, Vector3(-0.85, 1.06, -0.1), Color("C9A13B"), Vector3.ZERO, 16)
	for i in 5:
		var a := i * TAU / 5
		var c := Vector3(-0.85 + cos(a) * 0.09, 1.085, -0.1 + sin(a) * 0.09)
		b.quad(c + Vector3(-0.06, 0, 0), c + Vector3(0, 0, -0.08), c + Vector3(0.06, 0, 0), c + Vector3(0, 0, 0.08), Color("3E8E3A"))
	# Bananas hanging from the roof at the front left.
	b.cyl(0.012, 0.35, Vector3(-1.0, 2.2, -0.55), Color("6B4A2B"), Vector3.ZERO, 5)
	for i in 14:
		var a := i * TAU / 7
		var r := 0.07 + 0.03 * (i % 2)
		b.cyl(0.025, 0.2, Vector3(-1.0 + cos(a) * r, 1.92 - 0.1 * (i / 7), -0.55 + sin(a) * r), Color("F2C230"), Vector3(cos(a) * 20, 0, sin(a) * 20), 6)
	return b.commit()


## What Monir Mama has bought for the stall, in the stall's own space:
## a cushion on the new bench, a second kettle on its own stove, a blue
## tarpaulin awning over the bench on bamboo poles, a red drinks fridge.
static func tea_extras(owned: Array, bench_z: float) -> ArrayMesh:
	var b := Builder.new()
	if owned.has("bench"):
		b.box(Vector3(3.3, 0.06, 0.36), Vector3(0, 0.52, bench_z), Color("C2185B"))
		b.box(Vector3(3.42, 0.04, 0.42), Vector3(0, 0.49, bench_z), Color("F6B800"))
	if owned.has("second_kettle"):
		b.cyl(0.17, 0.2, Vector3(0.35, 1.13, 0.1), Color("8A4B2A"), Vector3.ZERO, 12)
		b.cyl(0.14, 0.24, Vector3(0.35, 1.36, 0.1), Color("B8BCC2"), Vector3.ZERO, 14, KEEP, Vector2.ZERO, 0.1)
		b.ball(0.035, Vector3(0.35, 1.5, 0.1), Color("3C3F44"))
		b.cyl(0.022, 0.22, Vector3(0.2, 1.38, 0.02), Color("B8BCC2"), Vector3(0, 0, 55), 8)
	if owned.has("awning"):
		var front := bench_z - 0.7
		b.quad(Vector3(-1.7, 2.45, -0.85), Vector3(1.7, 2.45, -0.85), Vector3(1.7, 2.15, front), Vector3(-1.7, 2.15, front), Color("1F6FB2"))
		for x in [-1.65, 1.65]:
			b.cyl(0.035, 2.15, Vector3(x, 1.075, front), Color("C8A96A"), Vector3.ZERO, 6)
		b.box(Vector3(3.4, 0.05, 0.05), Vector3(0, 2.15, front), Color("C8A96A"))
	if owned.has("fridge"):
		b.box(Vector3(0.7, 1.5, 0.6), Vector3(-1.65, 0.75, -0.1), Color("D7263D"))
		b.box(Vector3(0.56, 1.1, 0.02), Vector3(-1.65, 0.85, -0.41), Color("BFE3F2"))
		for i in 3:
			for k in 4:
				b.cyl(0.035, 0.18, Vector3(-1.85 + k * 0.13, 0.5 + i * 0.32, -0.3), [Color("2E9E6B"), Color("E2432A"), Color("F6B800"), Color("3E2A20")][k], Vector3.ZERO, 8)
		b.box(Vector3(0.7, 0.18, 0.02), Vector3(-1.65, 1.42, -0.415), Color("F2F2F2"))
	return b.commit()


## A plain wooden bench for customers, 3.4 m long along X.
static func bench() -> ArrayMesh:
	var b := Builder.new()
	var wood := Color("7A5230")
	b.box(Vector3(3.4, 0.06, 0.4), Vector3(0, 0.46, 0), wood)
	for x in [-1.5, 0.0, 1.5]:
		for z in [-0.15, 0.15]:
			b.box(Vector3(0.06, 0.46, 0.06), Vector3(x, 0.23, z), wood.darkened(0.2))
	return b.commit()


## Someone sitting on a bench (seat at y = 0.48), facing -Z: shirt PAINT_A,
## trousers or lungi PAINT_B.
## Julekha Khala's fuchka cart: a painted wooden cart on two wheels, a
## glass case of puris on top, the big pot of potato and peas, the
## tamarind-water jug, the chilli bowl and a stack of plates; a pole with
## a little canopy. Its front (-Z) faces the customers.
static func fuchka_cart(body := Color("1C7C54"), trim := Color("F6B800")) -> ArrayMesh:
	var b := Builder.new()
	var wood := Color("8B5A2B")
	# The cart: a box on two wheels, painted, with a trim band.
	b.box(Vector3(1.9, 0.75, 0.9), Vector3(0, 0.75, 0), body)
	b.box(Vector3(1.92, 0.1, 0.92), Vector3(0, 0.95, 0), trim)
	b.box(Vector3(2.0, 0.05, 1.0), Vector3(0, 1.14, 0), wood.darkened(0.2))
	for x in [-0.7, 0.7]:
		b.cyl(0.36, 0.08, Vector3(x, 0.36, 0.48), Color("3C3F44"), Vector3(90, 0, 0), 16)
		b.cyl(0.06, 0.1, Vector3(x, 0.36, 0.52), Color("C9CDD2"), Vector3(90, 0, 0), 8)
	b.cyl(0.03, 0.4, Vector3(0, 0.2, -0.3), wood, Vector3.ZERO, 6)
	# Rickshaw-art flowers on the front.
	for i in 4:
		var x := -0.6 + i * 0.4
		b.ball(0.07, Vector3(x, 0.72, -0.46), Color("C2185B") if i % 2 == 0 else Color("2D8BD6"), Vector3(1, 1, 0.3))
		b.ball(0.03, Vector3(x, 0.72, -0.48), trim, Vector3(1, 1, 0.3))
	# The glass case of puris (left), its frame and the puris piled inside.
	b.box(Vector3(0.8, 0.5, 0.6), Vector3(-0.45, 1.42, 0.1), Color("CFE8F2"))
	for x in [-0.85, -0.05]:
		b.box(Vector3(0.03, 0.52, 0.62), Vector3(x, 1.42, 0.1), wood)
	for i in 12:
		var x := -0.75 + (i % 6) * 0.12
		var y := 1.25 + (i / 6) * 0.1
		b.ball(0.06, Vector3(x, y, 0.05 + (i % 2) * 0.12), Color("E8C27A"), Vector3(1, 0.8, 1))
	# The big aluminium pot of potato and peas (right), with a ladle.
	b.cyl(0.24, 0.3, Vector3(0.45, 1.32, 0.12), Color("C9CDD2"), Vector3.ZERO, 16)
	b.cyl(0.22, 0.02, Vector3(0.45, 1.48, 0.12), Color("E0C27A"), Vector3.ZERO, 16)
	b.cyl(0.015, 0.4, Vector3(0.55, 1.62, 0.12), Color("9AA3A8"), Vector3(0, 0, 30), 6)
	# The tamarind-water jug, the chilli bowl, the plates.
	b.cyl(0.09, 0.22, Vector3(0.05, 1.28, -0.2), Color("7A4A2A"), Vector3.ZERO, 12)
	b.cyl(0.08, 0.06, Vector3(0.12, 1.2, 0.3), Color("D7263D"), Vector3.ZERO, 12)
	for i in 5:
		b.cyl(0.14, 0.012, Vector3(-0.3, 1.18 + i * 0.015, -0.3), Color("F4F1E8"), Vector3.ZERO, 14)
	# A pole and a little striped canopy.
	b.cyl(0.03, 1.4, Vector3(0.85, 1.85, 0.35), Color("C8A96A"), Vector3.ZERO, 6)
	for i in 6:
		var a := i * TAU / 6
		var c := Vector3(0.85, 2.55, 0.35)
		b.quad(c, c + Vector3(cos(a) * 0.7, -0.25, sin(a) * 0.7), c + Vector3(cos(a + TAU / 6) * 0.7, -0.25, sin(a + TAU / 6) * 0.7), c,
			Color("C2185B") if i % 2 == 0 else trim)
	return b.commit()


static func bench_sitter() -> ArrayMesh:
	var b := Builder.new()
	_body(b, Vector3(0, 0.5, 0), true, false)
	return b.commit()


# --- Inside Babu's bus -----------------------------------------------------


## Seat positions inside the bus (x, z), front rows first: two seats each
## side of the aisle, six rows. The front left two are for the elderly,
## the front right four for women.
static func bus_seats() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for row in 6:
		var z := -2.0 + row * 1.0
		for x in [-0.85, -0.45, 0.45, 0.85]:
			out.append(Vector2(x, z))
	return out


## Places to stand in the aisle, front first.
static func bus_standing() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in 10:
		out.append(Vector2(0.12 if i % 2 == 0 else -0.12, -2.6 + i * 0.6))
	return out


## The inside of a Dhaka local bus, looking forward (-Z) from the back: a
## ribbed floor, blue vinyl seats on steel frames, window pillars, the
## ceiling rails, a battered dashboard and the driver's seat on the right,
## the windscreen, and the door at the front left. Floor at y = 0.
static func bus_interior() -> ArrayMesh:
	var b := Builder.new()
	var paint := Color("C62828")
	var cream := Color("EFE6D2")
	var steel := Color("8C9196")
	# Floor with ribs, the back wall.
	b.box(Vector3(2.4, 0.05, 9.0), Vector3(0, -0.025, 0), Color("3B3B3B"))
	for i in 30:
		b.box(Vector3(0.5, 0.012, 0.03), Vector3(0, 0.006, -4.3 + i * 0.3), Color("2A2A2A"))
	b.box(Vector3(2.4, 2.3, 0.05), Vector3(0, 1.15, 4.5), cream)
	# Side walls: a painted lower panel, pillars between the windows, a
	# cream upper strip; the door gap at the front left.
	for side in [-1, 1]:
		var x: float = side * 1.2
		for k in 9:
			var z0 := -4.5 + k * 1.0
			if side < 0 and k == 1:
				continue
			b.box(Vector3(0.05, 1.0, 1.0), Vector3(x, 0.5, z0 + 0.5), paint)
			b.box(Vector3(0.06, 0.06, 1.0), Vector3(x, 1.0, z0 + 0.5), steel)
		for k in 10:
			b.box(Vector3(0.06, 0.95, 0.08), Vector3(x, 1.47, -4.5 + k * 1.0), cream.darkened(0.1))
		b.box(Vector3(0.05, 0.35, 9.0), Vector3(x, 2.12, 0), cream)
	b.box(Vector3(0.06, 2.0, 0.08), Vector3(-1.2, 1.0, -3.5), steel)
	b.box(Vector3(0.06, 2.0, 0.08), Vector3(-1.2, 1.0, -2.5), steel)
	# Ceiling and the two hand rails along it, with loops.
	b.box(Vector3(2.4, 0.05, 9.0), Vector3(0, 2.3, 0), cream.darkened(0.05))
	for x in [-0.32, 0.32]:
		b.cyl(0.02, 8.6, Vector3(x, 2.0, 0), steel, Vector3(90, 0, 0), 6)
		for k in 12:
			b.box(Vector3(0.015, 0.18, 0.015), Vector3(x, 1.9, -4.0 + k * 0.7), Color("2B2B2B"))
	# Seats: a frame, a blue cushion, a backrest; grab rail on top.
	for p in bus_seats():
		var at := Vector3(p.x, 0, p.y)
		b.box(Vector3(0.38, 0.08, 0.42), at + Vector3(0, 0.45, 0), Color("1C4E9B"))
		b.box(Vector3(0.38, 0.55, 0.06), at + Vector3(0, 0.75, 0.22), Color("1C4E9B"), Vector3(-8, 0, 0))
		b.box(Vector3(0.36, 0.03, 0.03), at + Vector3(0, 1.05, 0.25), steel)
		for dx in [-0.16, 0.16]:
			b.box(Vector3(0.03, 0.42, 0.03), at + Vector3(dx, 0.21, 0), steel)
	# Front: the driver's seat and wheel on the right, a dashboard covered
	# in stickers, the windscreen frame, a route board over it.
	b.box(Vector3(0.45, 0.5, 0.45), Vector3(0.7, 0.25, -3.9), Color("3B3B3B"))
	b.box(Vector3(0.45, 0.6, 0.08), Vector3(0.7, 0.8, -3.7), Color("1C4E9B"))
	b.box(Vector3(2.4, 0.9, 0.4), Vector3(0, 0.45, -4.45), Color("2B2B2B"))
	b.cyl(0.2, 0.03, Vector3(0.7, 1.05, -4.25), Color("1A1A1A"), Vector3(60, 0, 0), 16)
	for i in 5:
		b.quad(Vector3(-0.9 + i * 0.3, 0.92, -4.26), Vector3(-0.75 + i * 0.3, 0.92, -4.26),
			Vector3(-0.75 + i * 0.3, 0.84, -4.26), Vector3(-0.9 + i * 0.3, 0.84, -4.26),
			[Color("F6B800"), Color("2E9E6B"), Color("E2432A"), Color("2D8BD6"), Color("C2185B")][i])
	b.box(Vector3(2.4, 0.08, 0.08), Vector3(0, 0.95, -4.5), steel)
	b.box(Vector3(2.4, 0.3, 0.08), Vector3(0, 2.15, -4.5), Color("1A1A1A"))
	b.box(Vector3(0.08, 1.3, 0.08), Vector3(0, 1.55, -4.5), steel)
	return b.commit()


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
	# Simple graphics: no highlights either (fewer things for a weak chip).
	var simple := Graphics.level() == "low"
	var key := "%s %s" % [multimesh, simple]
	if not _shaders.has(key):
		var code := SHADER if multimesh else SHADER.replace("INSTANCE_CUSTOM", "custom_data").replace("uniform vec4 palette[16];", "uniform vec4 palette[16];\nuniform vec4 custom_data;")
		if simple:
			code = code.replace("render_mode diffuse_lambert;", "render_mode diffuse_lambert, specular_disabled;")
		var shader := Shader.new()
		shader.code = code
		_shaders[key] = shader
	var m := ShaderMaterial.new()
	m.shader = _shaders[key]
	var values := PackedVector4Array()
	for i in 16:
		var c: Color = palette[i % palette.size()]
		values.append(Vector4(c.r, c.g, c.b, 1.0))
	m.set_shader_parameter("palette", values)
	return m


const SHADER := """
shader_type spatial;
render_mode diffuse_lambert;
uniform vec4 palette[16];
varying vec3 tint;
varying float shine;

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec3 c = COLOR.rgb;
	float code = COLOR.a;
	shine = 0.0;
	int pa = clamp(int(INSTANCE_CUSTOM.z + 0.5), 0, 15);
	int pb = clamp(int(INSTANCE_CUSTOM.w + 0.5), 0, 15);
	if (code > 0.9) {
		// Chrome (B8BCC2) catches the light.
		vec3 d = abs(c - vec3(0.722, 0.737, 0.761));
		shine = d.r + d.g + d.b < 0.03 ? 1.0 : 0.0;
	} else if (code > 0.6) {
		c = palette[pa].rgb * c;
	} else if (code > 0.4) {
		c = palette[pb].rgb * c;
	} else {
		// Decoration k: one of the bright colours, shifted per copy, so
		// no two rickshaws are painted alike.
		int k = int(code * 25.5 + 0.5) - 2;
		c = palette[(k + pa * 3 + pb) % 8].rgb * c;
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
	EMISSION = tint * 0.1;
	ROUGHNESS = mix(0.75, 0.25, shine);
	SPECULAR = mix(0.3, 0.9, shine);
}
"""
