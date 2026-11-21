## Rahim Chacha on the real Mirpur map in 3D (§৪.১): the camera rides
## behind the rickshaw, so swipes are turns. Left or right: the next
## junction. Down: turn round now. Up: straight on.
extends Node3D

const RoadMap = preload("res://scripts/rules/road_map.gd")
const Driver = preload("res://scripts/rules/driver.gd")
const Shift = preload("res://scripts/rules/shift.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Look = preload("res://scripts/ui/look.gd")
const City = preload("res://scripts/world/city.gd")
const Models = preload("res://scripts/world/models.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const Traffic = preload("res://scripts/world/traffic.gd")
const Sounds = preload("res://scripts/world/sounds.gd")
const Clutter = preload("res://scripts/world/clutter.gd")

const SWIPE_PX := 36.0
## The camera rides just behind and above the rickshaw, at street level.
const CAMERA_BACK := 6.2
const CAMERA_UP := 3.9
## Bangladesh drives on the left.
const KEEP_LEFT := 1.2

var strings := Strings.new()
var shift: Shift
var rickshaw: Node3D
## The rickshaw body's material: paints hood and body, pedals the legs.
var _paint: ShaderMaterial
var camera: Camera3D
var marker: Node3D
var hud: Hud
var traffic: Traffic
var _bell: AudioStreamPlayer
var _horns: Array[AudioStreamPlayer3D] = []
var _horn_sounds: Dictionary = {}
var _horn_left := 2.0
var _stopped_for := 0.0
var _bob := 0.0
var _yaw := 0.0
var _side := Vector3.ZERO
var _notice := ""
var _notice_colour := Look.OUTLINE
var _notice_left := 0.0
var _pedal_fingers := {}
var _brake_fingers := {}
var _swipes := {}
var _key_pedal := false
var _key_brake := false


func _ready() -> void:
	strings.lang = Strings.saved_lang()
	var map: RoadMap = RoadMap.load_area("mirpur")
	var b := Balance.new()
	shift = Shift.new(map, b.n("rickshaw.speed_tiles_per_s"), b.n("rickshaw.waterlog_speed"))
	shift.accel = b.n("rickshaw.accel_tiles_per_s2")
	shift.coast = b.n("rickshaw.coast_decel")
	shift.braking = b.n("rickshaw.brake_decel")
	_environment()
	add_child(City.build(map, strings.lang))
	var palette := PackedColorArray()
	for hex in Traffic.PALETTE:
		palette.append(Color(hex))
	add_child(Clutter.build(map, palette))
	traffic = Traffic.new()
	add_child(traffic)
	traffic.setup(map, map.home)
	traffic.focus = shift.driver
	_sounds()
	# Rahim Chacha's own rickshaw: yellow hood, magenta body.
	rickshaw = Models.player_rickshaw(Look.YELLOW, Look.MAGENTA)
	_paint = Models.traffic_material(PackedColorArray([Look.YELLOW, Look.MAGENTA]), false)
	(rickshaw.get_meta("body") as MeshInstance3D).material_override = _paint
	var plain := Models.material()
	for w in rickshaw.get_meta("wheels"):
		(w as MeshInstance3D).material_override = plain
	add_child(rickshaw)
	marker = _marker()
	add_child(marker)
	camera = Camera3D.new()
	camera.fov = 68
	camera.near = 0.2
	camera.far = 220
	add_child(camera)
	camera.current = true
	hud = Hud.new()
	hud.setup(strings, map)
	hud.back_pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	add_child(hud)
	_yaw = _yaw_for(shift.driver.heading)
	_place_marker()
	_follow(0.0, true)


## The bell, a few horn players placed on passing traffic, the road's hum.
func _sounds() -> void:
	_bell = AudioStreamPlayer.new()
	_bell.stream = Sounds.bell()
	add_child(_bell)
	var hum := AudioStreamPlayer.new()
	hum.stream = Sounds.street_hum()
	hum.volume_db = -10.0
	hum.autoplay = true
	add_child(hum)
	_horn_sounds = {
		"cng": Sounds.horn(560.0, 700.0, 0.35),
		"bus": Sounds.horn(290.0, 370.0, 0.9),
		"rickshaw": Sounds.bell(),
		"rickshaw_full": Sounds.bell(),
	}
	for i in 3:
		var h := AudioStreamPlayer3D.new()
		h.unit_size = 8.0
		h.max_distance = 80.0
		add_child(h)
		_horns.append(h)


func _honk(dt: float) -> void:
	_horn_left -= dt
	_stopped_for = _stopped_for + dt if shift.speed_now < 0.05 else 0.0
	if _horn_left > 0.0:
		return
	_horn_left = randf_range(1.2, 4.5)
	var spot := traffic.somewhere_near(8)
	# Standing still with someone behind: they let you know.
	if _stopped_for > 1.5:
		var queued := traffic.behind(shift.driver)
		if queued != Vector3.INF:
			spot = queued
			_horn_left = randf_range(0.8, 2.0)
	if spot == Vector3.INF:
		return
	var kind := traffic.kind_at_spot(spot)
	if not _horn_sounds.has(kind):
		return
	for h in _horns:
		if not h.playing:
			h.stream = _horn_sounds[kind]
			h.position = spot + Vector3(0, 1.2, 0)
			h.volume_db = -4.0 if kind == "bus" else -8.0
			h.play()
			return


func _environment() -> void:
	var env := Environment.new()
	# A hazy Dhaka sky: pale, almost white near the horizon.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("9DB4C6")
	sky_mat.sky_horizon_color = Color("E2DED2")
	sky_mat.ground_horizon_color = Color("D9D4C6")
	sky_mat.ground_bottom_color = Color("B8B0A0")
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("F3E9D8")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("D8D5C8")
	env.fog_density = 0.011
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_color = Color("FFF1D6")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


## A tall glowing post where the passenger is going.
func _marker() -> Node3D:
	var m := Node3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 0.7
	beam.bottom_radius = 0.7
	beam.height = 14.0
	var mi := MeshInstance3D.new()
	mi.mesh = beam
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(Look.VERMILION, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position.y = 7.0
	m.add_child(mi)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.1
	ring.outer_radius = 1.5
	var ri := MeshInstance3D.new()
	ri.name = "Ring"
	ri.mesh = ring
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Look.VERMILION
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ri.material_override = rmat
	ri.position.y = 0.15
	m.add_child(ri)
	return m


func _place_marker() -> void:
	marker.position = City.centre(shift.destination)


## Heading on the grid to a rotation about Y: north is -Z, Godot's forward.
static func _yaw_for(d: int) -> float:
	return -d * PI / 2


func _process(dt: float) -> void:
	var gap := traffic.gap_ahead(shift.driver)
	shift.room = clampf((gap - 0.12) / 0.5, 0.0, 1.0)
	var events := shift.update(dt)
	if events.has(Driver.Event.ARRIVED):
		_place_marker()
		_say(strings.t("rickshawArrived"), Look.PARROT)
	if events.has(Driver.Event.WRONG_WAY):
		_say(strings.t("rickshawWrongWay"), Look.VERMILION)
	if events.has(Driver.Event.WAITING):
		_say(strings.t("rickshawWhichWay"), Look.SKY, INF)
	if _notice != "":
		_notice_left -= dt
		if _notice_left <= 0.0 or (_notice_left > 1e6 and shift.driver.moving):
			_notice = ""
	_follow(dt)
	_honk(dt)
	var ring := marker.get_node("Ring") as Node3D
	var k := fmod(Time.get_ticks_msec() / 1000.0, 1.2) / 1.2
	ring.scale = Vector3.ONE * (1.0 + k)
	_update_hud()


func _say(text: String, colour: Color, seconds := 2.0) -> void:
	_notice = text
	_notice_colour = colour
	_notice_left = seconds


func _follow(dt: float, snap := false) -> void:
	var d := shift.driver
	var pos := d.position()
	var f := Vector3(RoadMap.DX[d.heading], 0, RoadMap.DY[d.heading])
	var left := Vector3(f.z, 0, -f.x)
	_side = _side.lerp(left * KEEP_LEFT, 1.0 if snap else minf(1.0, dt * 4.0))
	rickshaw.position = Vector3((pos.x + 0.5) * City.T, 0, (pos.y + 0.5) * City.T) + _side
	var want := _yaw_for(d.heading)
	if snap:
		rickshaw.rotation.y = want
		_yaw = want
	else:
		rickshaw.rotation.y = lerp_angle(rickshaw.rotation.y, want, minf(1.0, dt * 10.0))
		_yaw = lerp_angle(_yaw, want, minf(1.0, dt * 3.5))
	if d.moving:
		for w in rickshaw.get_meta("wheels"):
			w.rotate_x(-dt * d.speed * City.T / 0.34)
	var pedalling := shift.pedal and d.moving
	_paint.set_shader_parameter("custom_data", Vector4(0.0, 1.0 if pedalling else 0.0, 0.0, 1.0))
	var forward := Vector3(-sin(_yaw), 0, -cos(_yaw))
	# A gentle sway with each push of the pedals.
	if pedalling:
		_bob += dt * d.speed * 9.0
	var sway := Vector3(0, sin(_bob * 2.0) * 0.05, 0) + Vector3(-forward.z, 0, forward.x) * sin(_bob) * 0.04
	camera.position = rickshaw.position - forward * CAMERA_BACK + Vector3.UP * CAMERA_UP + sway
	camera.look_at(rickshaw.position + forward * 8.0 + Vector3.UP * 1.2 + sway * 0.5)


func _update_hud() -> void:
	var d := shift.driver
	var me := d.position()
	var to := Vector2(shift.destination) - me
	var ahead := Vector2(RoadMap.DX[d.heading], RoadMap.DY[d.heading])
	# Grid y grows down the screen, so this angle is clockwise.
	var angle := ahead.angle_to(to) if to.length() > 0.01 else 0.0
	var target := strings.t("rickshawNoRoute")
	if shift.remaining >= 0:
		var place_label := RoadMap.place_name(shift.place, strings.lang) if not shift.place.is_empty() else ""
		target = strings.t("rickshawToPlace", {"place": place_label, "tiles": shift.remaining}) if place_label != "" \
			else strings.t("rickshawToGo", {"tiles": shift.remaining})
	hud.show_controls(shift.pedal, shift.brake, shift.speed_now * City.T * 3.6)
	hud.refresh(target, shift.delivered, angle, _notice, _notice_colour, me, shift.destination)


## Touches are read finger by finger: a finger on the pedal or brake holds
## it; any other finger can swipe a turn at the same time.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var finger: int = event.index
		if event.pressed:
			if hud.bell_rect().has_point(event.position):
				_bell.play()
			elif hud.pedal_rect().has_point(event.position):
				_pedal_fingers[finger] = true
			elif hud.brake_rect().has_point(event.position):
				_brake_fingers[finger] = true
			else:
				_swipes[finger] = {"start": event.position, "used": false}
		else:
			_pedal_fingers.erase(finger)
			_brake_fingers.erase(finger)
			_swipes.erase(finger)
		_apply_controls()
		return
	if event is InputEventScreenDrag:
		var swipe = _swipes.get(event.index)
		if swipe != null and not swipe.used:
			var moved: Vector2 = event.position - swipe.start
			if moved.length() >= SWIPE_PX:
				swipe.used = true
				_turn(_swipe_turn(moved))
		return
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_SPACE:
			_key_pedal = event.pressed
			_apply_controls()
			return
		if event.keycode == KEY_B:
			_key_brake = event.pressed
			_apply_controls()
			return
	if event.is_action_pressed("ui_left"):
		_turn(Driver.LEFT)
	elif event.is_action_pressed("ui_right"):
		_turn(Driver.RIGHT)
	elif event.is_action_pressed("ui_down"):
		_turn(Driver.BACK)
	elif event.is_action_pressed("ui_up"):
		_turn(Driver.AHEAD)


func _apply_controls() -> void:
	shift.pedal = _key_pedal or not _pedal_fingers.is_empty()
	shift.brake = _key_brake or not _brake_fingers.is_empty()


## A finger's movement on screen as a turn: the camera looks ahead, so up
## is straight on and down is back.
static func _swipe_turn(moved: Vector2) -> int:
	if absf(moved.x) > absf(moved.y):
		return Driver.RIGHT if moved.x > 0 else Driver.LEFT
	return Driver.BACK if moved.y > 0 else Driver.AHEAD


func _turn(t: int) -> void:
	var events := shift.swipe(t)
	if events.has(Driver.Event.WRONG_WAY):
		_say(strings.t("rickshawWrongWay"), Look.VERMILION)
	elif _notice_left > 1e6 and shift.driver.moving:
		_notice = ""
