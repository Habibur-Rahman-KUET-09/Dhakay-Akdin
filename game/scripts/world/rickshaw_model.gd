## Rahim Chacha on his rickshaw, from simple shapes, facing -Z (Godot's
## forward). About 2.6 units long; a map tile is 4.
extends RefCounted

const Look = preload("res://scripts/ui/look.gd")


static func _part(mesh: Mesh, at: Vector3, colour: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.8
	mi.material_override = m
	mi.position = at
	mi.rotation_degrees = rot
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cyl(radius: float, height: float, sides := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = sides
	return c


static func build() -> Node3D:
	var r := Node3D.new()
	r.name = "Rickshaw"
	var wheels: Array[Node3D] = []
	# Wheels: two at the back under the seat, one in front.
	for at in [Vector3(-0.62, 0.45, 0.45), Vector3(0.62, 0.45, 0.45), Vector3(0, 0.4, -1.15)]:
		var w := _part(_cyl(0.42 if at.z > 0 else 0.38, 0.1), at, Look.OUTLINE, Vector3(0, 0, 90))
		var hub := _part(_cyl(0.12, 0.14, 8), Vector3.ZERO, Color("C0C0C0"))
		w.add_child(hub)
		r.add_child(w)
		wheels.append(w)
	# Frame from the front wheel to the seat, and the axle.
	r.add_child(_part(_box(Vector3(0.12, 0.12, 1.5)), Vector3(0, 0.75, -0.45), Color("444444"), Vector3(-12, 0, 0)))
	r.add_child(_part(_box(Vector3(1.3, 0.08, 0.08)), Vector3(0, 0.45, 0.45), Color("444444")))
	# The passenger box and seat, painted.
	r.add_child(_part(_box(Vector3(1.15, 0.55, 0.85)), Vector3(0, 0.95, 0.45), Look.MAGENTA))
	r.add_child(_part(_box(Vector3(1.0, 0.18, 0.6)), Vector3(0, 1.3, 0.45), Look.SKY))
	r.add_child(_part(_box(Vector3(1.0, 0.55, 0.12)), Vector3(0, 1.55, 0.82), Look.YELLOW))
	# Folded hood over the seat.
	r.add_child(_part(_cyl(0.55, 1.12, 10), Vector3(0, 1.75, 0.6), Look.YELLOW, Vector3(0, 0, 90)))
	# Handlebar and the rider.
	r.add_child(_part(_box(Vector3(0.7, 0.06, 0.06)), Vector3(0, 1.2, -1.0), Color("444444")))
	r.add_child(_part(_box(Vector3(0.36, 0.08, 0.3)), Vector3(0, 1.05, -0.55), Color("222222")))
	var body := CapsuleMesh.new()
	body.radius = 0.22
	body.height = 0.9
	r.add_child(_part(body, Vector3(0, 1.45, -0.55), Color("F2F2F2")))
	var lungi := _cyl(0.2, 0.5, 10)
	r.add_child(_part(lungi, Vector3(0, 0.95, -0.55), Color("2E6E9E")))
	var head := SphereMesh.new()
	head.radius = 0.17
	head.height = 0.34
	r.add_child(_part(head, Vector3(0, 2.02, -0.6), Color("8D5A3B")))
	r.add_child(_part(_cyl(0.18, 0.08, 10), Vector3(0, 2.12, -0.6), Look.VERMILION))
	r.set_meta("wheels", wheels)
	return r
