## A character in 3D on the home page, the star of it: cute, outlined, in
## their outfit (heroes.gd), standing on their own ground (the road, the
## paving by the stall, the park, the ghat) in front of their own things
## (the rickshaw, the stall, the cart, the bus, the boat). They breathe,
## blink and now and then do their thing (ring the bell, pour, wave, call,
## row); a tap (poke) makes them jump and say their line.
extends SubViewportContainer

const Models = preload("res://scripts/world/models.gd")
const Look = preload("res://scripts/ui/look.gd")
const Graphics = preload("res://scripts/ui/graphics.gd")
const Heroes = preload("res://scripts/world/heroes.gd")
const Voice = preload("res://scripts/ui/voice.gd")
const People = preload("res://scripts/world/people.gd")

var who := "rickshaw"
var progress: Object
var open := true
## By night: blue moonlight and a warm street lamp.
var night := false
var _vp: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _hero: Node3D
var _voice: Node
var _t := 0.0
var _blink_in := 2.0
var _blink_left := 0.0
var _gesture_in := 2.5
var _busy := false
## A real-looking person (people.gd) instead of a cartoon hero: softer,
## warmer light with shadows, and their own idle and gestures.
var _real := false
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
	_real = People.has(who)
	if _real:
		_real_light()
	else:
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
	if night and not _real:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(1.6, 3.0, -1.6)
		lamp.omni_range = 9.0
		lamp.light_energy = 2.2
		lamp.light_color = Color("FFC46B")
		_vp.add_child(lamp)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_build()
	_camera = Camera3D.new()
	_camera.fov = 36
	_vp.add_child(_camera)
	_place_camera()
	_voice = Voice.new()
	add_child(_voice)
	if not open:
		modulate = Color(0.55, 0.55, 0.55, 0.9)


func _process(dt: float) -> void:
	_t += dt
	_pivot.rotation.y = sin(_t * 0.3) * 0.32
	if _camera != null:
		_camera.position.y = _look_y + 0.75 + sin(_t * 0.8) * 0.02
	if _hero == null:
		return
	if _real:
		_hero.idle(dt)
		_gesture_in -= dt
		if _gesture_in <= 0.0 and not _busy:
			gesture(_hero.gesture_kind)
			_gesture_in = randf_range(5.5, 9.0)
		return
	# Breathing, the head swaying a little.
	_hero.scale = Vector3(1.0, 1.0 + sin(_t * 2.2) * 0.012, 1.0)
	var head: Node3D = _hero.get_meta("head")
	head.rotation.z = sin(_t * 0.9) * 0.05
	head.rotation.x = sin(_t * 0.6) * 0.03
	# A blink every few seconds.
	var lids: Node3D = _hero.get_meta("lids")
	if _blink_left > 0.0:
		_blink_left -= dt
		lids.visible = _blink_left > 0.0
	else:
		_blink_in -= dt
		if _blink_in <= 0.0:
			_blink_left = 0.12
			lids.visible = true
			_blink_in = randf_range(2.0, 4.5)
	# Their thing, now and then.
	_gesture_in -= dt
	if _gesture_in <= 0.0 and not _busy:
		gesture(str(_hero.get_meta("gesture")))
		_gesture_in = randf_range(4.5, 7.5)


func _place_camera() -> void:
	# The models look along -Z: the camera stands in front of them.
	_camera.position = Vector3(0.45, _look_y + 0.75, -_dist)
	_camera.look_at(Vector3(0.15, _look_y, 0.4), Vector3.UP)


## A tap on them: a jump, a wave and their line.
func poke() -> void:
	if _hero == null or not open:
		return
	if _real:
		_busy = false
		gesture("wave")
		if _voice != null:
			_voice.say("catch_" + who, true)
		return
	var up := create_tween()
	up.tween_property(_hero, "position:y", _hero.position.y + 0.32, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_property(_hero, "position:y", _hero.position.y, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_busy = false
	gesture("wave")
	if _voice != null:
		_voice.say("catch_" + who, true)


## Their thing: ring (the bell held out and shaken), pour (the kettle
## tipped), wave, thumb (a thumbs up held out), call (a hand up to call
## people), row (both arms forward and back).
func gesture(kind: String) -> void:
	if _hero == null or _busy:
		return
	_busy = true
	if _real:
		var t: Tween = _hero.gesture(kind)
		t.tween_callback(func(): _busy = false)
		return
	var r: Node3D = _hero.get_meta("arm_r")
	var l: Node3D = _hero.get_meta("arm_l")
	var tw := create_tween()
	match kind:
		"wave":
			tw.tween_property(r, "rotation", Vector3(0, 0, 2.5), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			for k in 3:
				tw.tween_property(r, "rotation:z", 2.15, 0.14).set_trans(Tween.TRANS_SINE)
				tw.tween_property(r, "rotation:z", 2.65, 0.14).set_trans(Tween.TRANS_SINE)
		"ring":
			tw.tween_property(r, "rotation", Vector3(1.25, 0, 0.3), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			for k in 4:
				tw.tween_property(r, "rotation:z", 0.5, 0.07)
				tw.tween_property(r, "rotation:z", 0.1, 0.07)
		"pour":
			tw.tween_property(r, "rotation", Vector3(0.9, 0, 0.35), 0.35).set_trans(Tween.TRANS_SINE)
			tw.tween_property(r, "rotation", Vector3(1.1, 0, 0.75), 0.4).set_trans(Tween.TRANS_SINE)
			tw.tween_interval(0.5)
		"thumb":
			tw.tween_property(r, "rotation", Vector3(1.5, 0, 0.2), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.7)
		"call":
			tw.tween_property(r, "rotation", Vector3(2.4, 0, 0.5), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			for k in 2:
				tw.tween_property(r, "rotation:x", 2.1, 0.18)
				tw.tween_property(r, "rotation:x", 2.5, 0.18)
		"row":
			for k in 2:
				tw.tween_property(r, "rotation:x", 0.7, 0.35).set_trans(Tween.TRANS_SINE)
				tw.parallel().tween_property(l, "rotation:x", 0.7, 0.35).set_trans(Tween.TRANS_SINE)
				tw.tween_property(r, "rotation:x", -0.35, 0.35).set_trans(Tween.TRANS_SINE)
				tw.parallel().tween_property(l, "rotation:x", -0.35, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(r, "rotation", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(l, "rotation", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _busy = false)


func _look(slot: String, owner := "") -> Dictionary:
	if progress == null:
		return {}
	return progress.worn(owner if owner != "" else who, slot)


## A thing of theirs, painted and outlined.
func _painted(mesh: Mesh, a: Color, b: Color, at := Vector3.ZERO, yaw := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var paint := Models.traffic_material(PackedColorArray([a, b]), false)
	paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	paint.next_pass = Heroes.outline(0.02)
	m.material_override = paint
	m.position = at
	m.rotation.y = yaw
	_pivot.add_child(m)
	return m


func _plain(mesh: Mesh, at := Vector3.ZERO, yaw := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := Models.material()
	mat.next_pass = Heroes.outline(0.02)
	m.material_override = mat
	m.position = at
	m.rotation.y = yaw
	_pivot.add_child(m)
	return m


## Their ground: a round of road, paving, park or river, with its marks.
func _ground(fill: Color, radius := 2.6) -> void:
	var g := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.12
	disc.radial_segments = 48
	g.mesh = disc
	var m := StandardMaterial3D.new()
	m.albedo_color = fill.darkened(0.35) if night else fill
	m.roughness = 1.0
	m.next_pass = Heroes.outline(0.03)
	g.material_override = m
	g.position.y = -0.06
	_pivot.add_child(g)


func _marks(colour: Color, at: Array, size: Vector3) -> void:
	for p in at:
		var mark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mark.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = colour.darkened(0.35) if night else colour
		mark.material_override = m
		mark.position = p
		_pivot.add_child(mark)


func _build() -> void:
	_dist = 4.6
	_look_y = 0.85
	var hero_at := Vector3(-0.45, 0, -0.35)
	match who:
		"rickshaw":
			_ground(Color("6B6E76"))
			_marks(Color("F2F0EA"), [Vector3(-1.6, 0.005, 0.9), Vector3(-0.4, 0.005, 0.9), Vector3(0.8, 0.005, 0.9), Vector3(2.0, 0.005, 0.9)], Vector3(0.7, 0.02, 0.12))
			var paint := _look("paint")
			var art := _look("art")
			var r := Models.player_rickshaw(Color(str(paint.get("hood", Look.YELLOW.to_html(false)))), Color(str(paint.get("body", Look.MAGENTA.to_html(false)))), int(art.get("style", 0)))
			(r.get_meta("rider") as MeshInstance3D).visible = false
			_paint_vehicle(r)
			r.position = Vector3(1.0, 0, 1.1)
			r.rotation.y = -0.75
			_pivot.add_child(r)
		"delivery":
			_ground(Color("6B6E76"))
			_marks(Color("F6B800"), [Vector3(-1.2, 0.005, 0.8), Vector3(0.2, 0.005, 0.8), Vector3(1.6, 0.005, 0.8)], Vector3(0.9, 0.02, 0.1))
			hero_at = Vector3(-0.2, 0, -0.3)
		"tea":
			_ground(Color("B9714F"))
			_marks(Color("9C5A3E"), [Vector3(-1.5, 0.005, -0.5), Vector3(0, 0.005, -1.3), Vector3(1.3, 0.005, -0.4), Vector3(-0.6, 0.005, 1.4)], Vector3(0.5, 0.02, 0.25))
			_plain(Models.tea_stall(), Vector3(0.7, 0, 1.5), -0.3)
		"fuchka":
			_ground(Color("8BC34A"))
			_marks(Color("D7CCB0"), [Vector3(0.8, 0.005, 0.6)], Vector3(2.2, 0.02, 1.6))
			var cart := _look("cart")
			var m := _plain(Models.fuchka_cart(Color(str(cart.get("body", "1C7C54"))), Color(str(cart.get("trim", "F6B800")))), Vector3(0.9, 0, 0.9), -0.5)
			m.name = "Cart"
		"bus", "hawker":
			_ground(Color("6B6E76"), 3.2)
			_marks(Color("F2F0EA"), [Vector3(-1.4, 0.005, -1.0), Vector3(0.2, 0.005, -1.0), Vector3(1.8, 0.005, -1.0)], Vector3(0.9, 0.02, 0.12))
			_painted(Models.bus(), Color("C62828") if who == "bus" else Color("1E6FB0"), Color("F6B800"), Vector3(2.2, 0, 3.8), PI / 2 - 0.25)
			hero_at = Vector3(-0.3, 0, -0.5)
			_dist = 5.6
			_look_y = 1.0
		"boat":
			_ground(Color("4F8DB8"), 3.0)
			var look := _look("boat")
			var hull := _painted(Models.boat(false), Color(str(look.get("body", "2E7D4F"))), Color(str(look.get("trim", "F6B800"))), Vector3(1.0, 0.04, 1.4), PI / 2.3)
			hull.scale = Vector3.ONE * 0.75
			# The ghat's wooden steps where he stands.
			_marks(Color("8D6E63"), [Vector3(-0.45, 0.06, -0.35)], Vector3(1.4, 0.12, 1.1))
			hero_at = Vector3(-0.45, 0.12, -0.35)
	if _real:
		_hero = People.make(who)
		_real = _hero != null and _hero.has_rig()
		if _real:
			_hero.wear(_look("outfit"))
		if _hero != null and not _real:
			_hero.free()
			_hero = null
	if _real:
		# Life size, so the camera comes closer to see his face.
		_dist = 3.5
		_look_y = 1.0
		hero_at.x += 0.15
	if _hero == null:
		_hero = Heroes.hero(who, _look("outfit") if who in ["rickshaw", "tea", "fuchka"] else {})
	_hero.position = hero_at
	_hero.rotation.y = 0.25
	_pivot.add_child(_hero)
	if who == "tea":
		_steam()


func _paint_vehicle(v: Node3D) -> void:
	var colours: Array = v.get_meta("colours")
	var paint := Models.traffic_material(PackedColorArray([colours[0], colours[1]]), false)
	paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	paint.next_pass = Heroes.outline(0.02)
	(v.get_meta("body") as MeshInstance3D).material_override = paint
	var plain := Models.material()
	for w in v.get_meta("wheels"):
		(w as MeshInstance3D).material_override = plain


## Light for a real-looking person: a soft sky all round (no HDRI file to
## carry), a warm low sun with soft shadows, and a cool light from behind
## that draws their edge out of the background. Filmic tones so skin and
## cloth do not burn out.
func _real_light() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("1B2A4A") if night else Color("6F9BD1")
	sky_mat.sky_horizon_color = Color("4A4E68") if night else Color("E9D9C2")
	sky_mat.ground_bottom_color = Color("1A1A1E") if night else Color("5A4A3C")
	sky_mat.ground_horizon_color = Color("3A3A44") if night else Color("C9B79F")
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45 if night else 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -150, 0)
	sun.light_energy = 0.4 if night else 1.5
	sun.light_color = Color("AFC2FF") if night else Color("FFE6C7")
	sun.shadow_enabled = Graphics.level() != "low"
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 12.0
	_vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 35, 0)
	rim.light_energy = 0.35 if night else 0.75
	rim.light_color = Color("BFD4FF")
	_vp.add_child(rim)
	if night:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(1.6, 3.0, -1.6)
		lamp.omni_range = 9.0
		lamp.light_energy = 2.2
		lamp.light_color = Color("FFC46B")
		_vp.add_child(lamp)


## Steam rising from Monir's kettle.
func _steam() -> void:
	var p := CPUParticles3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.04
	ball.height = 0.08
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	ball.material = m
	p.mesh = ball
	p.amount = 14
	p.lifetime = 1.6
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 0.35, 0)
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.3
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0)])
	p.color_ramp = fade
	var arm: Node3D = _hero.get_meta("arm_r")
	p.position = Vector3(0, -0.45, -0.2)
	arm.add_child(p)
