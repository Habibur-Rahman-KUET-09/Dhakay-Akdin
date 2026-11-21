## Rahim Chacha's day on the real Mirpur map in 3D (§৪.১): passengers to
## find and bargain with, trips against the clock, from 7 am to 9 pm; his
## energy and tea at the stalls, the traffic police, a sudden shower. The
## camera rides behind the rickshaw, so swipes are turns. Left or right:
## the next junction. Down: turn round now. Up: straight on.
extends Node3D

const RoadMap = preload("res://scripts/rules/road_map.gd")
const Driver = preload("res://scripts/rules/driver.gd")
const Day = preload("res://scripts/rules/day.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Look = preload("res://scripts/ui/look.gd")
const City = preload("res://scripts/world/city.gd")
const Models = preload("res://scripts/world/models.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const Traffic = preload("res://scripts/world/traffic.gd")
const Clutter = preload("res://scripts/world/clutter.gd")
const CrashWatch = preload("res://scripts/ui/crash_watch.gd")
const SignalLights = preload("res://scripts/world/signal_lights.gd")
const Progress = preload("res://scripts/rules/progress.gd")

const SWIPE_PX := 36.0
## The camera rides just behind and above the rickshaw, at street level.
const CAMERA_BACK := 6.2
const CAMERA_UP := 3.9
## Bangladesh drives on the left.
const KEEP_LEFT := 1.0

var strings := Strings.new()
var shift: Day
var signals: SignalLights
## People waiting by the road, by passenger id.
var _waiting_nodes := {}
var _person_mesh: ArrayMesh
var _rider_seat: MeshInstance3D
var _palette := PackedColorArray()
var _crossing_wait := 0.0
var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial
var _env: Environment
var _target_money := 600
var progress: Progress
var rickshaw: Node3D
## The rickshaw body's material: paints hood and body, pedals the legs.
var _paint: ShaderMaterial
var camera: Camera3D
var marker: Node3D
var hud: Hud
var traffic: Traffic
var _bell: AudioStreamPlayer
var _horns: Array[AudioStreamPlayer] = []
var _alive_left := 10.0
var _horn_sounds: Dictionary = {}
var _horn_left := 2.0
var _stopped_for := 0.0
var _bob := 0.0
var _yaw := 0.0
var _side := Vector3.ZERO
var _back := CAMERA_BACK
var _notice := ""
var _notice_colour := Look.OUTLINE
var _notice_left := 0.0
var _pedal_fingers := {}
var _brake_fingers := {}
var _swipes := {}
var _key_pedal := false
var _key_brake := false
## The traffic policeman who stops a wrong-way rickshaw, and his whistle.
var _police: Node3D
var _police_left := 0.0
var _whistle: AudioStreamPlayer
## Rain: how hard (0–1, eased), the drops, the sound, the water that
## spreads on the roads.
var _rain_k := 0.0
var _drops: CPUParticles3D
var _rain_sound: AudioStreamPlayer
var _rain_water: MeshInstance3D


func _ready() -> void:
	strings.lang = Strings.saved_lang()
	var map: RoadMap = RoadMap.load_area("mirpur")
	var b := Balance.new()
	shift = Day.new(map, b)
	_target_money = int(b.n("rickshaw.daily_target"))
	# What carries over from earlier days: a faster rickshaw, for one.
	progress = Progress.new(b)
	shift.base_speed *= progress.speed_factor()
	shift.energy_factor = progress.energy_factor()
	# Built a step per frame behind a loading screen, so a slow phone keeps
	# responding, and the log shows which step a crash happened in.
	set_process(false)
	var loading := _loading_screen()
	await _step("environment")
	_environment()
	await _step("town")
	add_child(City.build(map, strings.lang))
	await _step("clutter")
	for hex in Traffic.PALETTE:
		_palette.append(Color(hex))
	add_child(Clutter.build(map, _palette))
	signals = SignalLights.new()
	add_child(signals)
	signals.setup(map)
	await _step("traffic")
	traffic = Traffic.new()
	add_child(traffic)
	traffic.setup(map, map.home)
	traffic.focus = shift.driver
	traffic.signal_cycle = shift.signal_cycle
	_person_mesh = Models.person()
	await _step("sounds")
	_sounds()
	await _step("rickshaw and hud")
	# Rahim Chacha's own rickshaw: yellow hood, magenta body.
	# The street's colours too, for the decorations (hood 0, body 1).
	rickshaw = Models.player_rickshaw(Look.YELLOW, Look.MAGENTA)
	var own := _palette.duplicate()
	own[0] = Look.YELLOW
	own[1] = Look.MAGENTA
	_paint = Models.traffic_material(own, false)
	(rickshaw.get_meta("body") as MeshInstance3D).material_override = _paint
	var plain := Models.material()
	for w in rickshaw.get_meta("wheels"):
		(w as MeshInstance3D).material_override = plain
	# A passenger on the seat, shown during a trip.
	_rider_seat = MeshInstance3D.new()
	_rider_seat.mesh = Models.seated_passenger()
	var seat_paint := Models.traffic_material(PackedColorArray([Color("1C4E9B"), Color("37474F")]), false)
	seat_paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	_rider_seat.material_override = seat_paint
	_rider_seat.visible = false
	rickshaw.add_child(_rider_seat)
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
	hud.back_pressed.connect(_go_home)
	hud.again_pressed.connect(_play_again)
	hud.offer_accept.connect(_on_accept)
	hud.offer_counter.connect(_on_counter)
	hud.offer_refuse.connect(_on_refuse)
	hud.tea_pressed.connect(_on_tea)
	add_child(hud)
	_police = _police_man()
	add_child(_police)
	_drops = _rain_drops()
	add_child(_drops)
	_rain_water = _spreading_water(map)
	add_child(_rain_water)
	_sync_waiting()
	_yaw = _yaw_for(shift.driver.heading)
	_place_marker()
	_follow(0.0, true)
	await _step("done")
	loading.queue_free()
	set_process(true)


## The bell, horn players for passing traffic, the road's hum: WAV files
## made by tool/make_sounds.py and imported like any recording. The hum is
## replayed when it ends rather than looped.
func _sounds() -> void:
	print("[sounds] bell")
	_bell = AudioStreamPlayer.new()
	_bell.stream = load("res://sounds/bell.wav")
	add_child(_bell)
	print("[sounds] hum")
	var hum := AudioStreamPlayer.new()
	hum.stream = load("res://sounds/hum.wav")
	hum.volume_db = -10.0
	add_child(hum)
	hum.finished.connect(_hum_again.bind(hum))
	hum.play()
	print("[sounds] horns")
	var bell: AudioStream = _bell.stream
	_horn_sounds = {
		"cng": load("res://sounds/horn_cng.wav"),
		"bus": load("res://sounds/horn_bus.wav"),
		"rickshaw": bell,
		"rickshaw_full": bell,
	}
	for i in 3:
		var h := AudioStreamPlayer.new()
		add_child(h)
		_horns.append(h)
	_whistle = AudioStreamPlayer.new()
	_whistle.stream = load("res://sounds/whistle.wav")
	add_child(_whistle)
	_rain_sound = AudioStreamPlayer.new()
	_rain_sound.stream = load("res://sounds/rain.wav")
	_rain_sound.volume_db = -60.0
	add_child(_rain_sound)
	_rain_sound.finished.connect(_rain_again)


func _rain_again() -> void:
	if _rain_k > 0.02:
		_rain_sound.play()


func _hum_again(hum: AudioStreamPlayer) -> void:
	hum.play()


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
	var far := spot.distance_to(rickshaw.position)
	for h in _horns:
		if not h.playing:
			h.stream = _horn_sounds[kind]
			h.volume_db = (-4.0 if kind == "bus" else -8.0) - far * 0.35
			h.play()
			return


func _loading_screen() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var bg := ColorRect.new()
	bg.color = Look.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var text := Look.label(strings.t("loading"), 22, true)
	text.set_anchors_preset(Control.PRESET_CENTER)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(text)
	add_child(layer)
	return layer


## Lets a frame pass and notes the next step in the log.
func _step(what: String) -> void:
	CrashWatch.start("rickshaw: " + what)
	print("[rickshaw] ", what, " ", Time.get_ticks_msec(), " ms, ", int(OS.get_static_memory_usage() / 1048576), " MB")
	await get_tree().process_frame


func _go_home() -> void:
	CrashWatch.stop()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


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
	# A little more colour and contrast than the camera sees, and a soft
	# glow round the brightest things (signals, the sky, lamps at night).
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.06
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 0.9
	env.glow_hdr_threshold = 0.95
	_env = env
	_sky = sky_mat
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_color = Color("FFF1D6")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 35.0
	add_child(sun)
	_sun = sun


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
	# A line in the log every 10 s, with the frame rate, for crash reports.
	_alive_left -= dt
	if _alive_left <= 0.0:
		_alive_left = 10.0
		print("[alive] ", Time.get_ticks_msec(), " ms, ", Engine.get_frames_per_second(), " fps")
	var gap := traffic.gap_ahead(shift.driver)
	shift.room = clampf((gap - 0.12) / 0.5, 0.0, 1.0)
	# Someone crossing the junction ahead: wait for them (a little while).
	if shift.driver.progress > 0.45 and traffic.crossing_blocked(shift.driver):
		_crossing_wait += dt
		if _crossing_wait < Traffic.CROSSING_PATIENCE:
			shift.room = 0.0
	else:
		_crossing_wait = 0.0
	var events := shift.update(dt)
	traffic.clock = shift.clock
	signals.update_lights(shift.clock, shift.signal_cycle)
	_day_light()
	_handle(events)
	if not is_processing():
		return
	if events.has(Driver.Event.WRONG_WAY) and not events.has(Day.POLICE):
		_say(strings.t("rickshawWrongWay"), Look.VERMILION)
	if events.has(Driver.Event.WAITING):
		_say(strings.t("rickshawWhichWay"), Look.SKY, INF)
	if _notice != "":
		_notice_left -= dt
		if _notice_left <= 0.0 or (_notice_left > 1e6 and shift.driver.moving):
			_notice = ""
	_follow(dt)
	_honk(dt)
	_weather(dt)
	if _police_left > 0.0:
		_police_left -= dt
		_police.visible = _police_left > 0.0
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
	# Behind the rickshaw may be a building: then the camera comes closer
	# (and a little higher) until it stands over the road.
	var back := CAMERA_BACK
	for k in [1.0, 0.75, 0.5, 0.3]:
		back = CAMERA_BACK * k
		var at := rickshaw.position - forward * back
		if shift.map.is_road(Vector2i(floori(at.x / City.T), floori(at.z / City.T))):
			break
	_back = back if snap else lerpf(_back, back, minf(1.0, dt * 6.0))
	# A gentle sway with each push of the pedals.
	if pedalling:
		_bob += dt * d.speed * 9.0
	var sway := Vector3(0, sin(_bob * 2.0) * 0.05, 0) + Vector3(-forward.z, 0, forward.x) * sin(_bob) * 0.04
	camera.position = rickshaw.position - forward * _back + Vector3.UP * (CAMERA_UP + (CAMERA_BACK - _back) * 0.4) + sway
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
		if not shift.riding.is_empty():
			target = strings.t("rickshawToPlace", {"place": RoadMap.place_name(shift.riding.place, strings.lang), "tiles": shift.remaining})
		else:
			target = strings.t("toPassenger", {"tiles": shift.remaining})
	hud.show_controls(shift.pedal, shift.brake, shift.speed_now * City.T * 3.6)
	hud.show_energy(shift.energy)
	var status := "%s\n%s" % [_clock_text(), strings.t("taka", {"n": shift.money})]
	hud.refresh(target, status, angle, _notice, _notice_colour, me, shift.destination)


## "সকাল 9:15" from the day's clock.
func _clock_text() -> String:
	var hour := shift.hour()
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	var part := "morning"
	if h >= 20:
		part = "night"
	elif h >= 18:
		part = "evening"
	elif h >= 15:
		part = "afternoon"
	elif h >= 12:
		part = "noon"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return strings.t("clock", {"part": strings.t(part), "h": h12, "m": "%02d" % m})


## What the day's events mean on screen.
func _handle(events: Array) -> void:
	if events.has(Day.OFFER):
		var w: Dictionary = shift.offer_for
		hud.show_offer(
			strings.t("offerTitle", {"place": RoadMap.place_name(w.place, strings.lang), "fare": w.offer}),
			strings.t("type_" + w.type),
			strings.t("counter", {"fare": shift.fares.counter(w.fair)}))
	if events.has(Day.OFFER_GONE):
		hud.hide_offer()
	if events.has(Day.DELIVERED):
		var t: Dictionary = shift.last_trip
		var tip_text := strings.t("tipText", {"tip": t.tip}) if t.tip > 0 else ""
		_say(strings.t("delivered", {"fare": t.fare, "tip": tip_text, "stars": _stars(t.stars)}), Look.PARROT, 3.5)
		_rider_seat.visible = false
		_bell.play()
		_place_marker()
		_sync_waiting()
	if events.has(Day.FINED):
		_say(strings.t("redLight", {"fine": int(shift.balance.n("rickshaw.red_light_fine"))}), Look.VERMILION, 3.0)
	if events.has(Day.POLICE):
		_say(strings.t("police", {"fine": int(shift.balance.n("rickshaw.wrong_way_fine"))}), Look.VERMILION, shift.held)
		_stop_by_police()
	if events.has(Day.TEA_NEAR):
		hud.show_tea(true, int(shift.balance.n("rickshaw.tea_cost")))
	if events.has(Day.TEA_GONE):
		hud.show_tea(false)
	if events.has(Day.TIRED):
		_say(strings.t("tired"), Look.YELLOW.darkened(0.2), 4.0)
	if events.has(Day.RAIN_START):
		_say(strings.t("rainStart"), Look.SKY, 3.5)
		_rain_sound.play()
	if events.has(Day.RAIN_END):
		_say(strings.t("rainEnd"), Look.SKY, 2.5)
	if events.has(Day.DAY_OVER):
		_end_day()


## The policeman steps out in front of the rickshaw, whistling.
func _stop_by_police() -> void:
	var forward := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var left := Vector3(forward.z, 0, -forward.x)
	_police.position = rickshaw.position + forward * 2.6 + left * 0.6 + Vector3(0, 0.15, 0)
	_police.rotation.y = _yaw + PI
	_police.visible = true
	_police_left = shift.held + 1.0
	_whistle.play()


func _police_man() -> Node3D:
	var node := Node3D.new()
	node.name = "Police"
	var body := MeshInstance3D.new()
	body.mesh = _person_mesh
	# White shirt, navy trousers.
	var paint := Models.traffic_material(PackedColorArray([Color("F2F2F2"), Color("1C2A44")]), false)
	paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	body.material_override = paint
	node.add_child(body)
	# A white cap with a dark peak, and a baton.
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.14
	cap_mesh.bottom_radius = 0.12
	cap_mesh.height = 0.08
	cap.mesh = cap_mesh
	cap.position = Vector3(0, 1.8, 0)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("F4F4F0")
	cap.material_override = white
	node.add_child(cap)
	var peak := MeshInstance3D.new()
	var peak_mesh := BoxMesh.new()
	peak_mesh.size = Vector3(0.2, 0.02, 0.1)
	peak.mesh = peak_mesh
	peak.position = Vector3(0, 1.77, -0.15)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("1C2A44")
	peak.material_override = dark
	node.add_child(peak)
	var label := Label3D.new()
	label.text = strings.t("policeName")
	label.font = Look.font(Look.BOLD)
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.position = Vector3(0, 2.25, 0)
	node.add_child(label)
	node.visible = false
	return node


func _on_tea() -> void:
	if shift.drink_tea():
		hud.show_tea(false)
		_say(strings.t("teaDrunk", {"n": int(shift.balance.n("rickshaw.tea_energy"))}), Look.PARROT, 2.5)


## Rain drops falling round the camera.
func _rain_drops() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Rain"
	p.amount = 600
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(13, 0.5, 13)
	p.direction = Vector3(0.05, -1, 0)
	p.spread = 4.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 19.0
	p.gravity = Vector3(0, -9.8, 0)
	var streak := BoxMesh.new()
	streak.size = Vector3(0.012, 0.45, 0.012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.82, 0.86, 0.92, 0.4)
	streak.material = m
	p.mesh = streak
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	return p


## Water on the tiles next to the flooded ones, shown while it rains.
func _spreading_water(map: RoadMap) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for p in map.roads():
		if map.kind_at(p) == RoadMap.Kind.FLOOD:
			continue
		for d in 4:
			if map.kind_at(RoadMap.step(p, d)) == RoadMap.Kind.FLOOD:
				var tile := Rect2(Vector2(p.x, p.y) * City.T, Vector2(City.T, City.T))
				City._quad(st, tile.grow(-0.6), 0.035, City.WATER)
				any = true
				break
	var mi := MeshInstance3D.new()
	mi.name = "RainWater"
	if any:
		mi.mesh = st.commit()
		mi.material_override = City._material(true)
	mi.visible = false
	return mi


## Eases the rain in and out: drops, sound, dark sky (in _day_light).
func _weather(dt: float) -> void:
	var want := 1.0 if shift.raining else 0.0
	_rain_k = move_toward(_rain_k, want, dt / 4.0)
	_drops.emitting = _rain_k > 0.3 and shift.raining
	if _rain_k > 0.0:
		var forward := Vector3(-sin(_yaw), 0, -cos(_yaw))
		_drops.position = camera.position + forward * 6.0 + Vector3(0, 7.0, 0)
	_rain_sound.volume_db = linear_to_db(maxf(_rain_k, 0.001)) - 4.0
	_rain_water.visible = _rain_k > 0.5


static func _stars(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x


func _on_accept() -> void:
	shift.accept()
	_boarded()


func _on_counter() -> void:
	if shift.counter():
		_boarded()
	else:
		hud.hide_offer()
		_say(strings.t("counterNo"), Look.VERMILION, 2.5)
		_place_marker()
		_sync_waiting()


func _on_refuse() -> void:
	shift.refuse()
	hud.hide_offer()


func _boarded() -> void:
	hud.hide_offer()
	_rider_seat.visible = true
	_say(strings.t("boarded", {"place": RoadMap.place_name(shift.riding.place, strings.lang), "fare": shift.riding.fare}), Look.SKY, 2.5)
	_place_marker()
	_sync_waiting()


## People waiting by the road, with where they want to go and their offer.
func _sync_waiting() -> void:
	var keep := {}
	for w in shift.waiting:
		keep[w.id] = true
		if _waiting_nodes.has(w.id):
			continue
		var node := Node3D.new()
		var spot := City._side(shift.map, w.at)
		node.position = spot + Vector3(0, 0.15, 0)
		var face := City.centre(w.at) - spot
		node.rotation.y = atan2(-face.x, -face.z)
		var body := MeshInstance3D.new()
		body.mesh = _person_mesh
		var paint := Models.traffic_material(PackedColorArray([_palette[randi() % 8], _palette[8 + randi() % 8]]), false)
		paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
		body.material_override = paint
		node.add_child(body)
		var label := Label3D.new()
		label.text = "%s\n%s" % [RoadMap.place_name(w.place, strings.lang), strings.t("taka", {"n": w.offer})]
		label.font = Look.font(Look.BOLD)
		label.font_size = 40
		label.outline_size = 12
		label.modulate = Look.OUTLINE
		label.outline_modulate = Look.YELLOW
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.position = Vector3(0, 2.4, 0)
		node.add_child(label)
		add_child(node)
		_waiting_nodes[w.id] = node
	for id in _waiting_nodes.keys():
		if not keep.has(id):
			_waiting_nodes[id].queue_free()
			_waiting_nodes.erase(id)


## Morning sun to evening glow to night: the light follows the clock.
func _day_light() -> void:
	var h := shift.hour()
	var noon := clampf(1.0 - absf(h - 12.5) / 6.5, 0.0, 1.0)
	var dusk := clampf((h - 16.5) / 3.0, 0.0, 1.0)
	var night := clampf((h - 19.0) / 2.0, 0.0, 1.0)
	_sun.light_color = Color("FFE2B8").lerp(Color("FFF6E6"), noon).lerp(Color("FF9A4D"), dusk).lerp(Color("8FA3D6"), night)
	_sun.light_energy = lerpf(0.65, 0.95, noon) * lerpf(1.0, 0.35, night)
	_sun.rotation_degrees.x = -lerpf(18.0, 60.0, noon)
	_env.ambient_light_energy = lerpf(0.32, 0.18, night)
	_env.ambient_light_color = Color("F3E9D8").lerp(Color("F2C9A0"), dusk).lerp(Color("5A6A90"), night)
	_sky.sky_top_color = Color("9DB4C6").lerp(Color("C9876A"), dusk).lerp(Color("1E2A44"), night)
	_sky.sky_horizon_color = Color("E2DED2").lerp(Color("F0B27A"), dusk).lerp(Color("3A4566"), night)
	_env.fog_light_color = Color("D8D5C8").lerp(Color("E5B48C"), dusk).lerp(Color("2E3650"), night)
	# Rain: grey sky, dim sun, thicker haze.
	if _rain_k > 0.0:
		var r := _rain_k
		_sun.light_energy *= lerpf(1.0, 0.3, r)
		_env.ambient_light_color = _env.ambient_light_color.lerp(Color("9AA3AD"), r * 0.7)
		_sky.sky_top_color = _sky.sky_top_color.lerp(Color("6E7882"), r * 0.8)
		_sky.sky_horizon_color = _sky.sky_horizon_color.lerp(Color("9DA4AA"), r * 0.8)
		_env.fog_light_color = _env.fog_light_color.lerp(Color("8F979E"), r * 0.8)
	_env.fog_density = lerpf(0.011, 0.028, _rain_k)


func _end_day() -> void:
	set_process(false)
	hud.hide_offer()
	hud.show_tea(false)
	shift.pedal = false
	_rain_sound.stop()
	_drops.emitting = false
	var lines := []
	if shift.worn_out:
		lines.append(strings.t("wornOut"))
	lines.append_array([
		strings.t("earned", {"money": shift.money}),
		strings.t("tripsDone", {"trips": shift.trips}),
		strings.t("avgRating", {"stars": _stars(snappedf(shift.average_stars(), 0.1))}),
	])
	if shift.fines > 0:
		lines.append(strings.t("finesPaid", {"fines": shift.fines}))
	if shift.teas > 0:
		lines.append(strings.t("teaLine", {"n": shift.teas, "money": shift.tea_spent}))
	var met := shift.money >= _target_money
	# Into the save: savings, school fee, fund, XP, the record.
	var got := progress.apply_day({"earned": shift.money, "trips": shift.trips, "stars": shift.average_stars(), "fines": shift.fines, "teas": shift.teas})
	progress.save()
	CrashWatch.stop()
	lines.append(strings.t("gainKept", {"n": got.kept}))
	if got.school > 0:
		lines.append(strings.t("gainSchool", {"n": got.school}))
	lines.append(strings.t("gainFund", {"n": got.fund}))
	lines.append(strings.t("gainXp", {"n": got.xp}))
	if got.level_up:
		lines.append(strings.t("levelUp", {"level": progress.level()}))
	if got.best:
		lines.append(strings.t("newBest"))
	if got.project != "":
		lines.append(strings.t("projectFinished", {"project": strings.t("project_" + got.project)}))
	lines.append(strings.t("targetMet" if met else "targetMissed", {"target": _target_money}))
	hud.show_day_end(lines, met)


func _play_again() -> void:
	CrashWatch.start("rickshaw")
	get_tree().reload_current_scene()


## Touches are read finger by finger: a finger on the pedal or brake holds
## it; any other finger can swipe a turn at the same time.
func _input(event: InputEvent) -> void:
	if not is_processing():
		return
	if event is InputEventScreenTouch:
		var finger: int = event.index
		if event.pressed:
			if hud.offer_rect().has_point(event.position) or hud.tea_rect().has_point(event.position):
				pass
			elif hud.bell_rect().has_point(event.position):
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
	_handle(events)
	if events.has(Day.POLICE):
		pass
	elif events.has(Driver.Event.WRONG_WAY):
		_say(strings.t("rickshawWrongWay"), Look.VERMILION)
	elif _notice_left > 1e6 and shift.driver.moving:
		_notice = ""
