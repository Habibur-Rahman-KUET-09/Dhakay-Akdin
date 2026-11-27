## Haripada Majhi's day on the Buriganga (phase 8): his ferry between
## Sadarghat (the launch terminal's quay, launches tied up along it) and
## the Jinjira ghat (a low bank, trees, small houses). The camera rides
## behind the boat looking across. At a ghat people step aboard; push off
## when he likes. Then two big oar buttons: one and then the other to go
## straight, the same one twice to turn against the current. A map of the
## river shows the ghats, the boat and the launches coming. river_day.gd
## has the rules; the bus scene lends its sky, notices and calls home.
extends "res://scripts/world/bus_scene.gd"

const RiverDay = preload("res://scripts/rules/river_day.gd")
const Weather = preload("res://scripts/world/weather.gd")

## Seats on the planks (x, z), by boat size.
const SEATS_8 := [Vector2(-0.3, -2.2), Vector2(0.3, -2.2), Vector2(-0.3, -1.1), Vector2(0.3, -1.1),
	Vector2(-0.3, 0.0), Vector2(0.3, 0.0), Vector2(-0.3, 1.1), Vector2(0.3, 1.1)]
const SEATS_12 := [Vector2(-0.42, -2.2), Vector2(0.0, -2.2), Vector2(0.42, -2.2), Vector2(-0.42, -1.1), Vector2(0.0, -1.1),
	Vector2(0.42, -1.1), Vector2(-0.42, 0.0), Vector2(0.0, 0.0), Vector2(0.42, 0.0), Vector2(-0.42, 1.1), Vector2(0.0, 1.1), Vector2(0.42, 1.1)]

var river: RiverDay
var _boat: Node3D
var _oars: Array[Node3D] = []
var _oar_swing := [0.0, 0.0]
var _riders := {}
var _launch_nodes := {}
var _launch_mesh: ArrayMesh
var _launch_paint: ShaderMaterial
var _water: StandardMaterial3D
var _yaw := 0.0
var _roll := 0.0
var _shake := 0.0
var _t := 0.0
var _map: Control
var _dock_box: VBoxContainer
var _patience_row: HBoxContainer
var _go_button: Button
var _oar_row: HBoxContainer
var _stroke_label: Label
var _horn: AudioStreamPlayer
var _splash: AudioStreamPlayer
var _rain_sound: AudioStreamPlayer
var _drops: CPUParticles3D
var _rain_k := 0.0
var _sun_energy := 0.85
var _ending := false
var _boost: Dictionary = {}


func _ready() -> void:
	strings.lang = Strings.saved_lang()
	b = Balance.new()
	progress = Progress.new(b)
	river = RiverDay.new(b, -1, progress.data.boat.upgrades, progress.date())
	_boost = progress.take_boost("boat")
	if not _boost.is_empty():
		river.arrival_factor = float(_boost.get("arrivals", 1.0))
		_boost_name = strings.t("boost_" + str(_boost.id))
	_call_rng.randomize()
	var call_share := HomeCall.plan(_call_rng, progress.level())
	if call_share >= 0.0:
		_call_at = call_share * river.day_seconds
	set_process(false)
	var loading := _loading_screen()
	await _step("environment")
	_environment()
	_sun.rotation_degrees = Vector3(-42, -130, 0)
	_sun_energy = _sun.light_energy
	# Clearer air over the water: the far bank in sight.
	_env.fog_density = 0.004
	await _step("river")
	for hex in Traffic.PALETTE:
		_palette.append(Color(hex))
	_build_river()
	await _step("boat")
	_build_boat()
	_launch_mesh = Models.launch()
	_launch_paint = Models.traffic_material(PackedColorArray([Color("1C4E9B"), Color("C62828")]), false)
	_launch_paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	_sitter_mesh = Models.bench_sitter()
	for k in Models.PEOPLE:
		_sitter_meshes.append(Models.bench_sitter(k))
	camera = Camera3D.new()
	camera.fov = 65
	camera.near = 0.1
	camera.far = 500
	add_child(camera)
	_drops = Weather.rain_drops()
	camera.add_child(_drops)
	await _step("sounds")
	_river_sounds()
	await _step("hud")
	_build_hud()
	_place_boat(0.0, true)
	CrashWatch.start("boat: graphics " + Graphics.level())
	Graphics.apply(get_viewport(), _env, _sun)
	await _step("done")
	loading.queue_free()
	set_process(true)
	var hello := strings.t("boatStart")
	if _boost_name != "":
		hello += "\n" + strings.t("boostUsed", {"name": _boost_name})
	_say(hello, Look.SKY, 4.0)


func _loading_screen() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var bg := ColorRect.new()
	bg.color = Look.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var text := Look.label(strings.t("boatLoading"), 22, true)
	text.set_anchors_preset(Control.PRESET_CENTER)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(text)
	layer.add_child(Tips.card(strings))
	add_child(layer)
	return layer


func _step(what: String) -> void:
	CrashWatch.start("boat: " + what)
	print("[boat] ", what, " ", Time.get_ticks_msec(), " ms")
	await get_tree().process_frame


# --- The river and its banks ---------------------------------------------------


func _build_river() -> void:
	var w := river.width
	# Brown-green water with ripples drifting downstream.
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(w + 160.0, 700.0)
	water.mesh = plane
	water.position = Vector3(w / 2.0, 0.0, 0.0)
	_water = StandardMaterial3D.new()
	_water.albedo_color = Color("566650")
	_water.roughness = 0.18
	_water.metallic_specular = 0.6
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	var ripples := NoiseTexture2D.new()
	ripples.noise = noise
	ripples.seamless = true
	ripples.as_normal_map = true
	ripples.bump_strength = 6.0
	ripples.width = 256
	ripples.height = 256
	_water.normal_enabled = true
	_water.normal_texture = ripples
	_water.normal_scale = 0.6
	_water.uv1_scale = Vector3(30, 80, 1)
	water.material_override = _water
	add_child(water)
	var concrete := City._photo("plaster")
	var plaster := City._grain(concrete, 192, 0.8, 0.98)
	# Sadarghat: a high concrete quay, the terminal's buildings behind,
	# steps down to a floating pontoon at the ghat, launches tied up.
	_bank(Vector3(-25.0, 0.75, 0.0), Vector3(50.0, 1.5, 700.0), Color("B9B2A3"))
	var front := _facade(700.0, 9.0, City._window_bay(plaster), Color("E8DCC4"))
	front.position = Vector3(-14.0, 6.0, 0.0)
	front.rotation.y = PI / 2
	add_child(front)
	var shops := _facade(700.0, 3.0, City._shop_bay(plaster, City._photo("shutter")), Color("D9CDB4"))
	shops.position = Vector3(-13.9, 3.0, 0.0)
	shops.rotation.y = PI / 2
	add_child(shops)
	_pontoon(Vector3(2.5, 0.3, 0.0))
	for z in [-75.0, 62.0, 110.0]:
		var moored := MeshInstance3D.new()
		moored.mesh = Models.launch()
		moored.material_override = Models.traffic_material(PackedColorArray([Color(["1C4E9B", "2E7D4F", "B3261E"][int(absf(z)) % 3]), Color("F6B800")]), false)
		(moored.material_override as ShaderMaterial).set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
		moored.position = Vector3(5.5, 0.0, z)
		add_child(moored)
	# Jinjira: a low muddy bank, trees and small houses, a bamboo ghat.
	_bank(Vector3(w + 30.0, 0.35, 0.0), Vector3(60.0, 0.7, 700.0), Color("7A6A4F"))
	var houses := _facade(700.0, 5.0, City._window_bay(City._photo("brick")), Color.WHITE)
	houses.position = Vector3(w + 22.0, 3.2, 0.0)
	houses.rotation.y = -PI / 2
	add_child(houses)
	var trees := Builder3D.new()
	for i in 40:
		var z := -340.0 + i * 17.0 + sin(i * 3.1) * 5.0
		trees.tree(Vector3(w + 9.0 + absf(sin(i * 1.7)) * 8.0, 0.7, z), 1.0 + absf(sin(i * 2.3)) * 0.6)
	var tree_mi := MeshInstance3D.new()
	tree_mi.mesh = trees.done()
	tree_mi.material_override = Models.material()
	add_child(tree_mi)
	_pontoon(Vector3(w - 2.5, 0.25, 0.0), true)
	# Signs and the yellow buoys that mark each landing.
	# Just upstream of each landing, clear of the view across.
	for at in [[Vector3(-1.0, 4.5, -river.ghat_half - 10.0), "ghat_sadarghat"], [Vector3(w + 1.0, 4.0, -river.ghat_half - 10.0), "ghat_jinjira"]]:
		var sign_label := Label3D.new()
		sign_label.text = strings.t(at[1])
		sign_label.font = Look.font(Look.BOLD)
		sign_label.font_size = 72
		sign_label.outline_size = 14
		sign_label.modulate = Look.YELLOW
		sign_label.outline_modulate = Look.OUTLINE
		sign_label.pixel_size = 0.012
		sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign_label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		sign_label.position = at[0]
		add_child(sign_label)
	var buoy := SphereMesh.new()
	buoy.radius = 0.4
	buoy.height = 0.8
	var buoy_paint := StandardMaterial3D.new()
	buoy_paint.albedo_color = Look.YELLOW
	for x in [6.0, w - 6.0]:
		for z in [-river.ghat_half, river.ghat_half]:
			var mi := MeshInstance3D.new()
			mi.mesh = buoy
			mi.material_override = buoy_paint
			mi.position = Vector3(x, 0.15, z)
			add_child(mi)


func _bank(centre: Vector3, size: Vector3, colour: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var m := _tiled(City._texture(City._photo("pavement")), Vector2(size.x / 6.0, size.z / 6.0))
	m.albedo_color = colour
	mi.material_override = m
	mi.position = centre
	add_child(mi)


## A floating landing stage at a ghat: a rusty steel pontoon at Sadarghat,
## bamboo and planks at Jinjira.
func _pontoon(at: Vector3, bamboo := false) -> void:
	var bb := Models.Builder.new()
	if bamboo:
		bb.box(Vector3(5.0, 0.2, 16.0), Vector3(0, 0, 0), Color("9B7246"))
		for z in [-7.5, -2.5, 2.5, 7.5]:
			bb.cyl(0.08, 2.4, Vector3(-2.3, 0.6, z), Color("C9A86A"))
	else:
		bb.box(Vector3(5.0, 0.8, 22.0), Vector3(0, 0, 0), Color("6E4A3A"))
		bb.box(Vector3(5.1, 0.1, 22.1), Vector3(0, 0.45, 0), Color("3C3F44"))
		for z in [-10.0, 0.0, 10.0]:
			bb.box(Vector3(0.1, 0.8, 0.1), Vector3(2.4, 0.9, z), Color("C62828"))
	var mi := MeshInstance3D.new()
	mi.mesh = bb.commit()
	mi.material_override = Models.material()
	mi.position = at
	add_child(mi)


## Trees by the Jinjira bank: a trunk and a round crown, in one mesh.
class Builder3D:
	var bb := Models.Builder.new()

	func tree(at: Vector3, s: float) -> void:
		bb.cyl(0.18 * s, 3.0 * s, at + Vector3(0, 1.5 * s, 0), Color("5B4330"))
		bb.ball(1.6 * s, at + Vector3(0, 3.6 * s, 0), Color("3E6B35"), Vector3(1.0, 0.8, 1.0))

	func done() -> ArrayMesh:
		return bb.commit()


# --- The boat ------------------------------------------------------------------


func _build_boat() -> void:
	var look := progress.worn("boat", "boat")
	var band := Color(str(look.get("body", "2E7D4F")))
	var rim := Color(str(look.get("trim", "F6B800")))
	_boat = Node3D.new()
	add_child(_boat)
	var hull := MeshInstance3D.new()
	hull.mesh = Models.boat(river.has("chhoi"))
	var paint := Models.traffic_material(PackedColorArray([band, rim]), false)
	paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	hull.material_override = paint
	_boat.add_child(hull)
	var oar_mesh := Models.boat_oar()
	var wood := Models.material()
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.7, 1.35, 1.8)
		_boat.add_child(pivot)
		var oar := MeshInstance3D.new()
		oar.mesh = oar_mesh
		oar.material_override = wood
		oar.position = Vector3(0, 0.5, 0)
		pivot.add_child(oar)
		pivot.rotation = Vector3(0, 0, side * deg_to_rad(55))
		_oars.append(pivot)


## The passengers on the planks.
func _sync_riders() -> void:
	var seats: Array = SEATS_12 if river.capacity > 8 else SEATS_8
	var here := {}
	for i in river.aboard.size():
		here[int(river.aboard[i].id)] = i
	for id in _riders.keys():
		if not here.has(id):
			(_riders[id] as Node3D).queue_free()
			_riders.erase(id)
	var taken := {}
	for id in _riders:
		taken[int((_riders[id] as Node3D).get_meta("seat"))] = true
	for p in river.aboard:
		var id := int(p.id)
		if _riders.has(id):
			continue
		var seat := 0
		while taken.has(seat) and seat < seats.size() - 1:
			seat += 1
		taken[seat] = true
		var mi := MeshInstance3D.new()
		mi.mesh = _sitter_meshes[int(id) % Models.PEOPLE]
		var paint := Models.traffic_material(PackedColorArray([_palette[id * 5 % 8], _palette[8 + id * 3 % 8]]), false)
		paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
		mi.material_override = paint
		var at: Vector2 = seats[seat]
		mi.position = Vector3(at.x, -0.15, at.y + 0.1)
		mi.set_meta("seat", seat)
		_boat.add_child(mi)
		_riders[id] = mi


## The boat where the rules put it, turned the way it goes, rocking; the
## camera behind it.
func _place_boat(dt: float, snap := false) -> void:
	var h := float(river.heading())
	var drift := 0.0 if river.docked else clampf((river.vel.y + river.current) * 0.12, -0.5, 0.5)
	var want := atan2(-h, -drift * h)
	_yaw = want if snap else lerp_angle(_yaw, want, minf(1.0, dt * 2.0))
	_roll = move_toward(_roll, 0.0, dt * 0.4)
	_boat.position = Vector3(_vx(river.pos.x), sin(_t * 1.3) * 0.05, river.pos.y)
	_boat.rotation = Vector3(sin(_t * 0.9) * 0.015, _yaw, sin(_t * 1.1) * 0.02 + sin(_t * 5.0) * _roll)
	for i in 2:
		_oar_swing[i] = move_toward(_oar_swing[i], 0.0, dt * 2.5)
		_oars[i].rotation.x = -_oar_swing[i] * 0.9
	var back := Vector3(-h * 11.0, 5.5, 0.0)
	var look_at_point := _boat.position + Vector3(h * 16.0, 0.5, 0.0)
	var cam := _boat.position + back
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - dt)
		cam += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.15 * _shake
	camera.position = cam if snap else camera.position.lerp(cam, minf(1.0, dt * 3.0))
	camera.look_at(look_at_point)


## Where a river x is drawn: the rules' banks are the ends of the
## landing stages, 8 m out from each shore.
func _vx(x: float) -> float:
	return 8.0 + x * (river.width - 16.0) / river.width


func _sync_launches() -> void:
	var here := {}
	for l in river.launches:
		here[int(l.id)] = l
	for id in _launch_nodes.keys():
		if not here.has(id):
			(_launch_nodes[id] as Node3D).queue_free()
			_launch_nodes.erase(id)
	for id in here:
		var l: Dictionary = here[id]
		var mi: MeshInstance3D = _launch_nodes.get(id)
		if mi == null:
			mi = MeshInstance3D.new()
			mi.mesh = _launch_mesh
			mi.material_override = _launch_paint
			mi.rotation.y = PI if int(l.dir) > 0 else 0.0
			add_child(mi)
			_launch_nodes[id] = mi
		mi.position = Vector3(_vx(float(l.x)), 0.0, float(l.y))


func _river_sounds() -> void:
	_thump = AudioStreamPlayer.new()
	_thump.stream = Sfx.stream("thump")
	_thump.volume_db = -4.0
	add_child(_thump)
	_splash = AudioStreamPlayer.new()
	_splash.stream = Sfx.stream("splash", "thump")
	_splash.volume_db = -16.0
	_splash.pitch_scale = 1.6
	add_child(_splash)
	_coin = AudioStreamPlayer.new()
	_coin.stream = Sfx.stream("coin")
	_coin.volume_db = -6.0
	add_child(_coin)
	_horn = AudioStreamPlayer.new()
	_horn.stream = Sfx.stream("horn_launch", "horn_bus")
	_horn.pitch_scale = 0.55
	_horn.volume_db = -4.0
	add_child(_horn)
	_rain_sound = AudioStreamPlayer.new()
	_rain_sound.stream = Sfx.stream("rain")
	_rain_sound.volume_db = -60.0
	add_child(_rain_sound)
	_voice = Voice.new()
	add_child(_voice)
	var tune := Music.new()
	tune.track = "tune"
	tune.volume_db = -20.0
	add_child(tune)


func _stop_name(i: int) -> String:
	return strings.t("ghat_jinjira" if i == 1 else "ghat_sadarghat")


# --- The screen ----------------------------------------------------------------


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)
	var room := Look.safe_insets(get_viewport())
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = room.x
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 6)
	_root.add_child(top)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	top.add_child(row)
	var back := Look.button(strings.t("back"), Look.OUTLINE, 15)
	back.pressed.connect(_go_home)
	row.add_child(back)
	# Photo mode: the scene as it is, in a frame, to share.
	row.add_child(Photo.button(self, _layer, strings, progress.data.get("frames", [])))
	var where := PanelContainer.new()
	where.add_theme_stylebox_override("panel", Look.card(Look.CREAM.lerp(Color.WHITE, 0.3)))
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_stop = Look.label("", 16, true)
	_next_stop.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	where.add_child(_next_stop)
	row.add_child(where)
	var status_box := PanelContainer.new()
	status_box.add_theme_stylebox_override("panel", Look.card())
	_status = Look.label("", 15, true)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_box.add_child(_status)
	row.add_child(status_box)
	# The river from above: the two banks, the ghats, the boat, launches.
	var map_box := PanelContainer.new()
	map_box.add_theme_stylebox_override("panel", Look.card(Color("DCEEF3"), 12, 2))
	map_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map = Control.new()
	_map.custom_minimum_size = Vector2(0, 96)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_map)
	map_box.add_child(_map)
	top.add_child(map_box)
	# Bottom: the notice; at a ghat, who is aboard and pushing off; on the
	# water, the oars.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 10
	bottom.offset_right = -10
	bottom.offset_bottom = -room.y
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	_notice_box = PanelContainer.new()
	_notice_box.add_theme_stylebox_override("panel", Look.card(Look.CREAM, 12, 2))
	_notice = Look.label("", 15, true)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_box.add_child(_notice)
	_notice_box.visible = false
	bottom.add_child(_notice_box)
	_dock_box = VBoxContainer.new()
	_dock_box.add_theme_constant_override("separation", 6)
	bottom.add_child(_dock_box)
	var wait_label := Look.label(strings.t("boatPatience"), 14, true, Color.WHITE)
	wait_label.add_theme_color_override("font_outline_color", Look.OUTLINE)
	wait_label.add_theme_constant_override("outline_size", 6)
	wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_box.add_child(wait_label)
	_patience_row = HBoxContainer.new()
	_patience_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_patience_row.add_theme_constant_override("separation", 4)
	_patience_row.custom_minimum_size = Vector2(0, 26)
	_dock_box.add_child(_patience_row)
	_go_button = Look.button("", Look.MAGENTA, 20)
	_go_button.name = "CastOff"
	_go_button.custom_minimum_size = Vector2(0, 64)
	_go_button.pressed.connect(_on_cast_off)
	_dock_box.add_child(_go_button)
	_stroke_label = Look.label(strings.t("boatRowHint"), 15, true, Color.WHITE)
	_stroke_label.add_theme_color_override("font_outline_color", Look.OUTLINE)
	_stroke_label.add_theme_constant_override("outline_size", 6)
	_stroke_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stroke_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_stroke_label)
	_oar_row = HBoxContainer.new()
	_oar_row.add_theme_constant_override("separation", 10)
	for hand in [-1, 1]:
		var oar := Look.button(strings.t("oarLeft" if hand < 0 else "oarRight"), Color("1F6E8C") if hand < 0 else Color("134B60"), 22)
		oar.name = "OarLeft" if hand < 0 else "OarRight"
		oar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		oar.custom_minimum_size = Vector2(0, 110)
		oar.button_down.connect(_on_stroke.bind(hand))
		_oar_row.add_child(oar)
	bottom.add_child(_oar_row)
	_refresh()


func _refresh() -> void:
	if river.docked:
		_next_stop.text = strings.t("boatAtGhat", {"ghat": _stop_name(river.side), "n": river.aboard.size(), "cap": river.capacity})
	elif river.at_bank:
		_next_stop.text = strings.t("boatPoling", {"ghat": _stop_name(1 - river.side)})
	else:
		_next_stop.text = strings.t("boatCrossing", {"ghat": _stop_name(1 - river.side), "m": int(river.left_share() * river.width)})
	var h := int(river.hour())
	var clock := strings.num("%d:%02d" % [((h - 1) % 12) + 1, int((river.hour() - h) * 60.0)])
	_status.text = "%s\n%s\n%s" % [clock, strings.t("taka", {"n": river.earned()}), strings.t("boatTrips", {"n": river.crossings})]
	_dock_box.visible = river.docked and not river.over
	_oar_row.visible = not river.docked and not river.over
	_stroke_label.visible = _oar_row.visible
	if river.docked:
		_go_button.text = strings.t("boatGo", {"n": river.aboard.size()}) if not river.aboard.is_empty() else strings.t("boatWaiting")
		_go_button.disabled = river.aboard.is_empty()
		_fill_patience()
	_map.queue_redraw()


## A little bar for each one aboard: how much patience is left.
func _fill_patience() -> void:
	while _patience_row.get_child_count() < river.aboard.size():
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(28, 22)
		_patience_row.add_child(bar)
	while _patience_row.get_child_count() > river.aboard.size():
		var k := _patience_row.get_child(_patience_row.get_child_count() - 1)
		_patience_row.remove_child(k)
		k.queue_free()
	for i in river.aboard.size():
		var p: Dictionary = river.aboard[i]
		var left := 1.0 - float(p.wait) / float(p.patience)
		(_patience_row.get_child(i) as ColorRect).color = Look.PARROT if left > 0.5 else (Look.YELLOW if left > 0.25 else Look.VERMILION)


## The map: Sadarghat on the left, Jinjira on the right, downstream down.
func _draw_map() -> void:
	var w := _map.size.x
	var hgt := _map.size.y
	var span := 60.0
	var to_px := func(x: float, y: float) -> Vector2:
		return Vector2(lerpf(18.0, w - 18.0, x / river.width), hgt / 2.0 + clampf(y / span, -1.0, 1.0) * (hgt / 2.0 - 6.0))
	_map.draw_rect(Rect2(0, 0, 16, hgt), Color("B9B2A3"))
	_map.draw_rect(Rect2(w - 16, 0, 16, hgt), Color("7A6A4F"))
	for x in [0.0, river.width]:
		var a: Vector2 = to_px.call(x, -river.ghat_half)
		var c: Vector2 = to_px.call(x, river.ghat_half)
		_map.draw_rect(Rect2(a.x - 6, a.y, 12, c.y - a.y), Look.YELLOW)
	# The current, small arrows down the middle.
	for k in 3:
		var at := Vector2(w * (0.3 + 0.2 * k), hgt * 0.2 + fmod(_t * 12.0 * river.current, hgt * 0.6))
		_map.draw_line(at, at + Vector2(0, 10), Color("6FA3B5"), 2.0)
		_map.draw_line(at + Vector2(0, 10), at + Vector2(-4, 5), Color("6FA3B5"), 2.0)
		_map.draw_line(at + Vector2(0, 10), at + Vector2(4, 5), Color("6FA3B5"), 2.0)
	for l in river.launches:
		var p: Vector2 = to_px.call(float(l.x), float(l.y))
		var half: float = float(l.half_len) / span * (hgt / 2.0 - 6.0)
		if absf(float(l.y)) < span + float(l.half_len):
			_map.draw_rect(Rect2(p.x - 5, p.y - half, 10, half * 2.0), Look.VERMILION if float(l.dir) * (river.pos.y - float(l.y)) > 0 else Color("1C4E9B"))
	var bp: Vector2 = to_px.call(river.pos.x, river.pos.y)
	_map.draw_circle(bp, 7.0, Look.MAGENTA)
	_map.draw_arc(bp, 7.0, 0, TAU, 14, Look.OUTLINE, 2.0)


func _process(dt: float) -> void:
	_alive_left -= dt
	if _alive_left <= 0.0:
		_alive_left = 10.0
		# With the river's state, so a report of a stall shows where it was.
		print("[alive] %d ms, %d fps, clock %.0f, %s, rain %s, launches %d%s" % [Time.get_ticks_msec(), Engine.get_frames_per_second(),
			river.clock, "docked" if river.docked else "crossing", river.raining, river.launches.size(), ", call open" if _activity != null else ""])
	_t += dt
	var pace := 0.35 if _activity != null and _activity.slow else 1.0
	var was_raining := river.raining
	_handle(river.update(dt * pace))
	if not is_processing():
		return
	if river.raining and not was_raining:
		_say(strings.t("boatRain"), Look.SKY, 3.0)
	if _call_at >= 0.0 and river.clock >= _call_at and _activity == null \
			and (river.docked or river.clock >= _call_at + 30.0):
		_call_at = -1.0
		_ring_home()
	_place_boat(dt)
	_sync_launches()
	_water.uv1_offset.y -= dt * river.current * 0.004
	_water.uv1_offset.x += dt * 0.001
	# The rain: darker, the drops round the camera, the sound.
	_rain_k = move_toward(_rain_k, 1.0 if river.raining else 0.0, dt / 4.0)
	_drops.emitting = _rain_k > 0.3 and river.raining
	_rain_sound.volume_db = linear_to_db(maxf(_rain_k, 0.001)) - 4.0
	if _rain_k > 0.02 and not _rain_sound.playing:
		_rain_sound.play()
	_sun.light_energy = _sun_energy * lerpf(1.0, 0.35, _rain_k)
	if _notice_left > 0.0:
		_notice_left -= dt
		if _notice_left <= 0.0:
			_notice_box.visible = false
	_refresh()


func _handle(events: Array) -> void:
	if events.has(RiverDay.Event.BOARDED) or events.has(RiverDay.Event.LEFT):
		_sync_riders()
	if events.has(RiverDay.Event.LEFT):
		_say(strings.t("boatGaveUp"), Look.VERMILION, 2.5)
	if events.has(RiverDay.Event.HORN):
		_horn.play()
		_say(strings.t("boatHorn"), Look.VERMILION, 3.0)
	if events.has(RiverDay.Event.WAKE):
		_roll = 0.08
		_shake = 1.0
		_say(strings.t("boatWake"), Look.SKY.darkened(0.2), 2.5)
	if events.has(RiverDay.Event.BUMP):
		_thump.play()
		_roll = 0.15
		_shake = 1.6
		_say(strings.t("boatBump"), Look.VERMILION, 3.0)
	if events.has(RiverDay.Event.OFF_GHAT):
		_say(strings.t("boatOffGhat"), Look.VERMILION, 3.5)
	if events.has(RiverDay.Event.ARRIVED):
		var trip := river.last_trip
		print("[boat] crossing %d: %d aboard, %d s, %.1f stars" % [river.crossings, int(trip.n), int(trip.secs), float(trip.stars)])
		_coin.play()
		var text := strings.t("boatArrived", {"n": int(trip.n), "fares": int(trip.fares)})
		if int(trip.tip) > 0:
			text += "\n" + strings.t("boatTip", {"n": int(trip.tip)})
		_say(text, Look.PARROT, 3.0)
		_sync_riders()
		if river.clock >= river.day_seconds:
			river.over = true
			_end_day()
	if events.has(RiverDay.Event.DAY_OVER):
		_end_day()


func _on_cast_off() -> void:
	if river.cast_off().has(RiverDay.Event.CAST_OFF):
		print("[boat] off from ", _stop_name(river.side), " with ", river.aboard.size())
		_say(strings.t("boatOff"), Look.SKY, 2.0)
		_refresh()


func _on_stroke(hand: int) -> void:
	if river.docked:
		return
	river.stroke(hand)
	_oar_swing[0 if hand < 0 else 1] = 1.0
	_splash.play()
	var key := "stroke_" + river.last_stroke
	if river.at_bank:
		key = "stroke_pole"
	_stroke_label.text = strings.t(key)
	_stroke_label.add_theme_color_override("font_color", Color.WHITE if river.last_stroke == "good" else Look.YELLOW)


func _closed() -> void:
	_activity = null
	_refresh()


func _ring_home() -> void:
	var call := HomeCall.new().pick("boat", _call_rng, progress.family("boat"))
	if call.is_empty():
		return
	var act := CallAct.new()
	act.call = call
	_open(act, "act_call", _answered.bind(act))


func _answered(_score: float, act) -> void:
	var options: Dictionary = act.call.get("options", {})
	var option: String = act.option
	if option == "" and not options.is_empty():
		option = str(options.keys().back())
	var e := HomeCall.effect(act.call, option)
	var now := progress.add_family("boat", e.family)
	river.money -= e.cost
	_call_result = {"family": now, "delta": e.family}
	print("[home] call ", act.call.get("id", ""), ": ", option, ", family ", now)
	if e.family > 0:
		_say(strings.t("familyUp", {"n": now}), Look.PARROT, 3.0)
	elif e.family < 0:
		_say(strings.t("familyDown", {"n": now}), Look.VERMILION, 3.0)
	if e.end_day:
		river.clock = river.day_seconds


func _end_day() -> void:
	if _ending:
		return
	_ending = true
	print("[boat] day over ", Time.get_ticks_msec(), " ms")
	set_process(false)
	river.over = true
	_dock_box.visible = false
	_oar_row.visible = false
	_stroke_label.visible = false
	var earned := river.earned()
	var stars := river.stars()
	var stats := {"crossings": river.crossings, "carried": river.carried, "earned": earned,
		"clean": 1 if river.bumps == 0 and river.crossings >= 4 else 0}
	var got := progress.apply_boat_day({"earned": earned, "carried": river.carried, "stars": stars, "stats": stats})
	progress.save()
	load("res://scripts/ui/cloud.gd").backup(self, progress.data)
	CrashWatch.stop()
	var lines := [strings.t("boatCrossLine", {"n": river.crossings}), strings.t("boatCarriedLine", {"n": river.carried})]
	if river.tips > 0:
		lines.append(strings.t("boatTipsLine", {"n": river.tips}))
	if river.bumps > 0:
		lines.append(strings.t("boatBumpsLine", {"n": river.bumps}))
	if river.gave_up > 0:
		lines.append(strings.t("boatGaveUpLine", {"n": river.gave_up}))
	if not _call_result.is_empty():
		lines.append(strings.t("familyLine", {"n": _call_result.family}))
	if int(got.get("samity_payout", 0)) > 0:
		lines.append(strings.t("samityPayoutLine", {"n": int(got.samity_payout)}))
	elif int(got.get("samity_paid", 0)) > 0:
		lines.append(strings.t("samityDayLine", {"n": int(got.samity_paid)}))
	if int(got.get("relay_bonus", 0)) > 0:
		lines.append(strings.t("relayBonusLine", {"n": int(got.relay_bonus)}))
	if bool(got.get("relay_done", false)):
		lines.append(strings.t("relayDoneLine", {"n": int(progress.b.n("friends.relay_tara"))}))
	var end := DayEnd.new()
	end.setup(strings, b, progress, got, {
		"title": strings.t("boatDayOver"),
		"stars": stars,
		"sub": strings.t("boatRatingLine", {"stars": "%.1f" % stars}),
		"money": earned,
		"lines": lines,
		"share": strings.t("share_boat", {"n": river.carried, "money": earned}) if river.carried > 0 else "",
	})
	end.home_pressed.connect(_go_home)
	end.again_pressed.connect(_again)
	_layer.add_child(end)


func _again() -> void:
	CrashWatch.start("boat")
	get_tree().reload_current_scene.call_deferred()
