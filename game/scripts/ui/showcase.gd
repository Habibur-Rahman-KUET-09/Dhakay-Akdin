## A character in 3D on the home page: their own things (rickshaw,
## bicycle, stall, cart, bus, boat) and themselves in their outfit, turning
## slowly on a round of pavement, swaying a little as if breathing.
extends SubViewportContainer

const Models = preload("res://scripts/world/models.gd")
const Look = preload("res://scripts/ui/look.gd")
const Graphics = preload("res://scripts/ui/graphics.gd")

var who := "rickshaw"
var progress: Object
var open := true
## By night: blue moonlight and a warm street lamp.
var night := false
var _vp: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _bodies: Array[ShaderMaterial] = []
var _t := 0.0
## How far the camera stands, and the height it looks at (per character).
var _dist := 5.0
var _look_y := 1.0


func setup(p_who: String, p_progress: Object, p_open := true, p_night := false) -> SubViewportContainer:
	who = p_who
	progress = p_progress
	open = p_open
	night = p_night
	return self


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED if Graphics.level() == "low" else Viewport.MSAA_2X
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8FA3D9") if night else Color("FFF4E0")
	env.ambient_light_energy = 0.5 if night else 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.35 if night else 1.15
	sun.light_color = Color("AFC2FF") if night else Color.WHITE
	_vp.add_child(sun)
	if night:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(1.6, 3.0, -1.6)
		lamp.omni_range = 9.0
		lamp.light_energy = 2.2
		lamp.light_color = Color("FFC46B")
		_vp.add_child(lamp)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.9
	disc.bottom_radius = 2.9
	disc.height = 0.12
	disc.radial_segments = 40
	ground.mesh = disc
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("8C8A92") if night else Color("D9CDB4")
	stone.roughness = 1.0
	ground.material_override = stone
	ground.position.y = -0.06
	_pivot.add_child(ground)
	_build()
	_camera = Camera3D.new()
	_camera.fov = 38
	_vp.add_child(_camera)
	_place_camera()
	if not open:
		modulate = Color(0.55, 0.55, 0.55, 0.9)


func _process(dt: float) -> void:
	_t += dt
	_pivot.rotation.y = sin(_t * 0.35) * 0.55
	for m in _bodies:
		m.set_shader_parameter("custom_data", Vector4(_t * 0.6, 0.12, 0, 1))
	if _camera != null:
		_camera.position.y = _look_y + 0.9 + sin(_t * 0.8) * 0.03


func _place_camera() -> void:
	# The models look along -Z: the camera stands in front of them.
	_camera.position = Vector3(0.6, _look_y + 0.9, -_dist)
	_camera.look_at(Vector3(0, _look_y, 0), Vector3.UP)


func _look(slot: String, owner := "") -> Dictionary:
	if progress == null:
		return {}
	return progress.worn(owner if owner != "" else who, slot)


func _person(style: int, shirt: Color, lower: Color, at: Vector3, yaw := 0.0) -> MeshInstance3D:
	var p := MeshInstance3D.new()
	p.mesh = Models.person(style)
	var paint := Models.traffic_material(PackedColorArray([shirt, lower]), false)
	paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	p.material_override = paint
	p.position = at
	p.rotation.y = yaw
	_pivot.add_child(p)
	return p


func _painted(mesh: Mesh, a: Color, b: Color, at := Vector3.ZERO, yaw := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var paint := Models.traffic_material(PackedColorArray([a, b]), false)
	paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	m.material_override = paint
	m.position = at
	m.rotation.y = yaw
	_pivot.add_child(m)
	return m


func _plain(mesh: Mesh, at := Vector3.ZERO, yaw := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = Models.material()
	m.position = at
	m.rotation.y = yaw
	_pivot.add_child(m)
	return m


func _build() -> void:
	match who:
		"rickshaw":
			var paint := _look("paint")
			var art := _look("art")
			var style := int(art.get("style", 0))
			var r := Models.player_rickshaw(Color(str(paint.get("hood", Look.YELLOW.to_html(false)))), Color(str(paint.get("body", Look.MAGENTA.to_html(false)))), style)
			_paint_vehicle(r)
			var outfit := _look("outfit")
			var rider_paint := Models.traffic_material(PackedColorArray([Color(str(outfit.get("shirt", "E8892B"))), Color(str(outfit.get("lower", "2D5D8A")))]), false)
			rider_paint.set_shader_parameter("custom_data", Vector4(0, 1, 0, 1))
			(r.get_meta("rider") as MeshInstance3D).material_override = rider_paint
			_bodies.append(rider_paint)
			r.rotation.y = -0.5
			_pivot.add_child(r)
			_dist = 6.2
			_look_y = 1.0
		"delivery":
			var cycle := _look("cycle")
			var c := Models.player_bicycle(Color(str(cycle.get("box", "F26B1D"))), Color(str(cycle.get("frame", "1E6FB0"))))
			_paint_vehicle(c)
			c.rotation.y = -0.6
			_pivot.add_child(c)
			_dist = 5.0
			_look_y = 1.0
		"tea":
			_plain(Models.tea_stall(), Vector3(0, 0, 1.0))
			var outfit := _look("outfit")
			_breathe(_person(0, Color(str(outfit.get("shirt", "F4F1E8"))), Color(str(outfit.get("lower", "2D5D8A"))), Vector3(0.4, 0, -0.6)))
			_dist = 6.8
			_look_y = 1.2
		"fuchka":
			var cart := _look("cart")
			var m := MeshInstance3D.new()
			m.mesh = Models.fuchka_cart(Color(str(cart.get("body", "1C7C54"))), Color(str(cart.get("trim", "F6B800"))))
			m.material_override = Models.material()
			m.position = Vector3(0, 0, 0.5)
			_pivot.add_child(m)
			var outfit := _look("outfit")
			_breathe(_person(1, Color(str(outfit.get("shirt", "1C7C54"))), Color(str(outfit.get("lower", "C2185B"))), Vector3(-0.3, 0, -0.4)))
			_dist = 6.0
			_look_y = 1.1
		"bus":
			_painted(Models.bus(), Color("C62828"), Color("F6B800"), Vector3(1.2, 0, 3.4), PI / 2)
			_breathe(_person(0, Color("2D8BD6"), Color("37474F"), Vector3(-0.4, 0, -0.4)))
			_dist = 11.0
			_look_y = 1.5
		"hawker":
			_painted(Models.bus(), Color("1E6FB0"), Color("F6B800"), Vector3(1.2, 0, 3.4), PI / 2)
			_breathe(_person(2, Color("A0722F"), Color("5D4037"), Vector3(-0.4, 0, -0.4)))
			_dist = 11.0
			_look_y = 1.5
		"boat":
			var look := _look("boat")
			var hull := _painted(Models.boat(false), Color(str(look.get("body", "2E7D4F"))), Color(str(look.get("trim", "F6B800"))), Vector3(0, 0.05, 0.6), PI / 2.4)
			hull.scale = Vector3.ONE * 0.8
			_breathe(_person(2, Color("F4F1E8"), Color("1F6E8C"), Vector3(-0.2, 0.2, -0.3)))
			_dist = 8.0
			_look_y = 1.1


func _paint_vehicle(v: Node3D) -> void:
	var colours: Array = v.get_meta("colours")
	var paint := Models.traffic_material(PackedColorArray([colours[0], colours[1]]), false)
	paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	(v.get_meta("body") as MeshInstance3D).material_override = paint
	var plain := Models.material()
	for w in v.get_meta("wheels"):
		(w as MeshInstance3D).material_override = plain


func _breathe(p: MeshInstance3D) -> void:
	_bodies.append(p.material_override as ShaderMaterial)
