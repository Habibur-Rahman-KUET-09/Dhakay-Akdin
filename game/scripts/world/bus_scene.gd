## Babu's local bus (§৪.২), from inside: the camera stands at the back
## looking up the aisle, past the seats, to the windscreen and the street
## going by. Mirpur 10 to Motijheel and back. Before each stop, call it;
## take every fare and give the right change from the bag; see the elderly
## and women to their seats; catch whoever slips out at the door
## (bus_day.gd has the rules).
extends Node3D

const BusDay = preload("res://scripts/rules/bus_day.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Progress = preload("res://scripts/rules/progress.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Look = preload("res://scripts/ui/look.gd")
const Sfx = preload("res://scripts/ui/sfx.gd")
const Voice = preload("res://scripts/ui/voice.gd")
const Music = preload("res://scripts/ui/music.gd")
const Activity = preload("res://scripts/ui/activity.gd")
const Hands = preload("res://scripts/rules/activities.gd")
const Notes = preload("res://scripts/ui/activities/notes.gd")
const Door = preload("res://scripts/ui/activities/door.gd")
const Seat = preload("res://scripts/ui/activities/seat.gd")
const Crowd = preload("res://scripts/ui/activities/crowd.gd")
const City = preload("res://scripts/world/city.gd")
const Models = preload("res://scripts/world/models.gd")
const Traffic = preload("res://scripts/world/traffic.gd")
const CrashWatch = preload("res://scripts/ui/crash_watch.gd")
const Graphics = preload("res://scripts/ui/graphics.gd")
const Neighbours = preload("res://scripts/rules/neighbours.gd")
const DayLines = preload("res://scripts/ui/day_lines.gd")
const DayEnd = preload("res://scripts/ui/day_end.gd")
const CallAct = preload("res://scripts/ui/activities/call.gd")
const ReadAloud = preload("res://scripts/ui/read_aloud.gd")
const HomeCall = preload("res://scripts/rules/home_call.gd")

## How fast the street goes by, metres a second, between stops.
const SPEED := 9.0
## The scenery repeats every PERIOD metres (bays are 3 m, dashes 6 m).
const PERIOD := 6.0
## The bag's notes, as buttons.
const BAG_NOTES := [5, 10, 20, 50, 100]

var strings := Strings.new()
var neighbours := Neighbours.new()
var b: Balance
var bus: BusDay
var progress: Progress
var camera: Camera3D
var _palette := PackedColorArray()
var _env: Environment
var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial
var _scenery: Node3D
var _stop_sign: Node3D
var _stop_label: Label3D
var _speed := 0.0
var _distance := 0.0
## People on the bus by rider id: their mesh.
var _people := {}
var _seats: Array[Vector2] = []
var _standing: Array[Vector2] = []
var _sitter_mesh: ArrayMesh
var _stander_mesh: ArrayMesh
# The screen.
var _layer: CanvasLayer
var _root: Control
var _status: Label
var _next_stop: Label
var _route_bar: Control
var _notice: Label
var _notice_box: PanelContainer
var _notice_left := 0.0
var _call_box: PanelContainer
var _call_bar: Control
var _call_title: Label
var _badges := {}
var _unpaid_label: Label
var _next_button: Button
var _fare_box: PanelContainer
var _fare_title: Label
var _fare_sub: Label
var _student_row: HBoxContainer
var _change_box: VBoxContainer
var _giving_label: Label
var _note_buttons := {}
var _giving := {}
var _thump: AudioStreamPlayer
var _ding: AudioStreamPlayer
var _coin: AudioStreamPlayer
## Babu calling the stops, passengers, the checker.
var _voice: Voice
## The hand activity open, if any; the slap pad on the bus's side and the
## times of the last slaps; the notes in his hand to sort.
var _activity: Activity
## A call from home today: when (on the day's clock; -1 when none, or
## once it has rung), and how it went, for the day's end.
var _call_at := -1.0
var _call_rng := RandomNumberGenerator.new()
var _call_result := {}
var _slap_button: Button
var _slaps: Array = []
var _notes_button: Button
var _frames_logged := 0
var _alive_left := 10.0
## The turn back was announced under a hand activity: say it again once it closes.
var _trip_news := false
## Where each rider is drawn: their seat number, so a move is noticed.
var _spot_of := {}
var _problem_row: HBoxContainer
var _problem_buttons := {}
var _crowd_label: Label
var _door_button: Button
var _checker: MeshInstance3D
var _checker_left := 0.0


func _ready() -> void:
	strings.lang = Strings.saved_lang()
	b = Balance.new()
	progress = Progress.new(b)
	bus = BusDay.new(b, -1, progress.data.bus.upgrades)
	bus.interactive = Activity.wanted()
	_call_rng.randomize()
	var call_share := HomeCall.plan(_call_rng, progress.level())
	if call_share >= 0.0:
		_call_at = call_share * bus.target_time * bus.trips
	var ids := neighbours.ids()
	ids.shuffle()
	bus.npc_pool = ids.slice(0, 6)
	bus.relations = progress.data.npcs
	set_process(false)
	var loading := _loading_screen()
	await _step("environment")
	_environment()
	await _step("bus")
	for hex in Traffic.PALETTE:
		_palette.append(Color(hex))
	var inside := MeshInstance3D.new()
	inside.mesh = Models.bus_interior()
	inside.material_override = Models.material()
	add_child(inside)
	_seats = Models.bus_seats()
	_standing = Models.bus_standing()
	# Signs over the front windows: the elder seats (left), the women's (right).
	for sign_at in [[Vector3(-0.72, 1.9, -1.6), "seatElder"], [Vector3(0.72, 1.9, -1.4), "seatWomen"]]:
		var board := Label3D.new()
		board.text = strings.t(sign_at[1])
		board.font = Look.font(Look.BOLD)
		board.font_size = 40
		board.outline_size = 8
		board.modulate = Color.WHITE
		board.outline_modulate = Color("1C4E9B")
		board.pixel_size = 0.0035
		board.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		board.position = sign_at[0]
		add_child(board)
	# A bought sign over the windscreen.
	var sticker := progress.worn("bus", "sticker")
	if not sticker.is_empty():
		var words := Label3D.new()
		words.text = strings.t(str(sticker.id))
		words.font = Look.font(Look.BOLD)
		words.font_size = 48
		words.outline_size = 10
		words.modulate = Color(str(sticker.colour))
		words.outline_modulate = Color.WHITE
		words.pixel_size = 0.0035
		words.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		words.position = Vector3(0, 2.15, -1.7)
		add_child(words)
	# The ticket checker, by the door when he gets on.
	_checker = MeshInstance3D.new()
	_checker.mesh = Models.person()
	var checker_paint := Models.traffic_material(PackedColorArray([Color("F2F2F2"), Color("1A1A1A")]), false)
	checker_paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	_checker.material_override = checker_paint
	_checker.position = Vector3(-0.1, 0.02, -2.4)
	_checker.visible = false
	add_child(_checker)
	_sitter_mesh = Models.bench_sitter()
	_stander_mesh = Models.person()
	await _step("street")
	_build_street()
	camera = Camera3D.new()
	camera.fov = 70
	camera.near = 0.1
	camera.far = 200
	add_child(camera)
	# In the aisle, between the two ceiling rails, at eye height.
	camera.position = Vector3(0.0, 1.55, 4.3)
	camera.look_at(Vector3(-0.05, 1.05, -4.5))
	camera.current = true
	await _step("sounds")
	_sounds()
	await _step("hud")
	_build_hud()
	_sync_people()
	CrashWatch.start("bus: graphics " + Graphics.level())
	Graphics.apply(get_viewport(), _env, _sun)
	await _step("done")
	loading.queue_free()
	set_process(true)
	_say(strings.t("busStart"), Look.SKY, 4.0)


func _loading_screen() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var bg := ColorRect.new()
	bg.color = Look.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var text := Look.label(strings.t("busLoading"), 22, true)
	text.set_anchors_preset(Control.PRESET_CENTER)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(text)
	add_child(layer)
	return layer


func _step(what: String) -> void:
	CrashWatch.start("bus: " + what)
	print("[bus] ", what, " ", Time.get_ticks_msec(), " ms")
	await get_tree().process_frame


func _environment() -> void:
	var env := Environment.new()
	_sky = ProceduralSkyMaterial.new()
	_sky.sky_top_color = Color("9DB4C6")
	_sky.sky_horizon_color = Color("E2DED2")
	_sky.ground_horizon_color = Color("D9D4C6")
	_sky.ground_bottom_color = Color("B8B0A0")
	var sky := Sky.new()
	sky.sky_material = _sky
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("F3E9D8")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("D8D5C8")
	env.fog_density = 0.012
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.06
	env.glow_intensity = 0.45
	env.glow_hdr_threshold = 0.95
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50, -60, 0)
	_sun.light_color = Color("FFF1D6")
	_sun.light_energy = 0.85
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_max_distance = 20.0
	add_child(_sun)
	Graphics.plain(get_viewport(), env, _sun)


## The street outside, built once and slid backwards as the bus goes:
## tarmac with lane dashes, pavements, rows of shops with flats over them
## on both sides. It repeats every PERIOD metres, so sliding it by the
## distance modulo PERIOD looks endless.
func _build_street() -> void:
	_scenery = Node3D.new()
	_scenery.name = "Street"
	add_child(_scenery)
	var length := 240.0
	var road := MeshInstance3D.new()
	var road_mesh := PlaneMesh.new()
	road_mesh.size = Vector2(18, length)
	road.mesh = road_mesh
	road.position = Vector3(2.2, -0.9, -length / 2 + 40)
	road.material_override = _tiled(City._texture(City._photo("asphalt")), Vector2(3, length / 6))
	_scenery.add_child(road)
	for side in [-1, 1]:
		# Pavement, then the row of buildings: shops below, flats above.
		var walk := MeshInstance3D.new()
		var walk_mesh := PlaneMesh.new()
		walk_mesh.size = Vector2(2.5, length)
		walk.mesh = walk_mesh
		walk.position = Vector3(2.2 + side * 10.2, -0.75, -length / 2 + 40)
		walk.material_override = _tiled(City._texture(City._photo("pavement")), Vector2(1, length / 3))
		_scenery.add_child(walk)
		var x: float = 2.2 + side * 11.5
		var concrete := City._photo("plaster")
		var plaster := City._grain(concrete, 192, 0.8, 0.98)
		var shops := _facade(length, 3.0, City._shop_bay(plaster, City._photo("shutter")), Color("E8DCC4"))
		shops.position = Vector3(x, -0.75 + 1.5, -length / 2 + 40)
		shops.rotation.y = -side * PI / 2
		_scenery.add_child(shops)
		var flats := _facade(length, 12.0, City._window_bay(plaster if side < 0 else City._photo("brick")), Color("F2E6D0") if side < 0 else Color.WHITE)
		flats.position = Vector3(x, -0.75 + 3.0 + 6.0, -length / 2 + 40)
		flats.rotation.y = -side * PI / 2
		_scenery.add_child(flats)
	# Lane dashes every 6 m.
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.15, 0.02, 3.0)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("E8E6DE")
	for i in int(length / PERIOD):
		var dash := MeshInstance3D.new()
		dash.mesh = dash_mesh
		dash.material_override = white
		dash.position = Vector3(3.2, -0.88, 40.0 - i * PERIOD)
		_scenery.add_child(dash)
	# The stop's sign on the left pavement, shown at each stop.
	_stop_sign = Node3D.new()
	add_child(_stop_sign)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.05
	pole_mesh.bottom_radius = 0.05
	pole_mesh.height = 3.0
	pole.mesh = pole_mesh
	pole.position = Vector3(-7.6, 0.75, 0)
	_stop_sign.add_child(pole)
	_stop_label = Label3D.new()
	_stop_label.font = Look.font(Look.BOLD)
	_stop_label.font_size = 64
	_stop_label.outline_size = 12
	_stop_label.modulate = Look.YELLOW
	_stop_label.outline_modulate = Look.OUTLINE
	_stop_label.pixel_size = 0.01
	_stop_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stop_label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	_stop_label.position = Vector3(-7.6, 2.6, 0)
	_stop_sign.add_child(_stop_label)
	_stop_sign.position = Vector3(0, 0, -2.5)
	_stop_label.text = _stop_name(0)


## A long wall facing the street with a repeating 3 m texture.
func _facade(length: float, height: float, texture: Texture2D, tint: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(length, height)
	mi.mesh = quad
	var m := _tiled(texture, Vector2(length / 3.0, height / 3.0))
	m.albedo_color = tint
	mi.material_override = m
	return mi


func _tiled(texture: Texture2D, scale: Vector2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.uv1_scale = Vector3(scale.x, scale.y, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = 0.95
	return m


func _sounds() -> void:
	var hum := AudioStreamPlayer.new()
	hum.stream = Sfx.stream("bus_inside", "hum")
	hum.volume_db = -6.0
	add_child(hum)
	hum.finished.connect(hum.play)
	hum.play()
	_thump = AudioStreamPlayer.new()
	_thump.stream = Sfx.stream("thump")
	add_child(_thump)
	_ding = AudioStreamPlayer.new()
	_ding.stream = Sfx.stream("bell")
	_ding.volume_db = -10.0
	add_child(_ding)
	_coin = AudioStreamPlayer.new()
	_coin.stream = Sfx.stream("coin")
	_coin.volume_db = -6.0
	add_child(_coin)
	_voice = Voice.new()
	add_child(_voice)
	var tune := Music.new()
	tune.track = "tune_bus"
	tune.volume_db = -20.0
	add_child(tune)


func _stop_name(i: int) -> String:
	return strings.t("stop_" + bus.stop_id(i))


# --- People on the bus -------------------------------------------------------


## Draws the riders where the rules put them (seats 0–23, standing
## places after), and lets off those who left. Whoever is slipping out
## stands at the door.
func _sync_people() -> void:
	var here := {}
	for r in bus.riders:
		here[r.id] = r
	for id in _people.keys():
		if not here.has(id):
			(_people[id] as Node3D).queue_free()
			_people.erase(id)
			_spot_of.erase(id)
	var leaving := {}
	for d in bus.at_door:
		leaving[d.rider.id] = true
	for r in bus.riders:
		var spot: int = -2 if leaving.has(r.id) else int(r.seat)
		if _people.has(r.id) and _spot_of.get(r.id, -3) == spot:
			continue
		var person: MeshInstance3D = _people.get(r.id)
		if person == null:
			person = MeshInstance3D.new()
			person.material_override = _paint_for(r)
			add_child(person)
			_people[r.id] = person
		_spot_of[r.id] = spot
		var seated := spot >= 0 and spot < _seats.size()
		person.mesh = _sitter_mesh if seated else _stander_mesh
		person.visible = spot != -1
		if spot == -2:
			# At the door, front left, looking out.
			person.position = Vector3(-0.85, 0.02, -2.9)
			person.rotation.y = PI / 2
		elif spot >= 0:
			var p: Vector2 = _seats[spot] if seated else _standing[spot - _seats.size()]
			person.position = Vector3(p.x, 0.0 if seated else 0.02, p.y + (0.05 if seated else 0.0))
			person.rotation.y = 0.0


## Clothes: women in a bright kameez (top and bottom one colour), the
## elderly in a white panjabi, everyone else from the street's colours.
func _paint_for(r: Dictionary) -> ShaderMaterial:
	var paint: ShaderMaterial
	var id := int(r.id)
	if r.kind == "elder":
		paint = Models.traffic_material(PackedColorArray([Color("F4F1E8"), Color("E6E2D6")]), false)
	elif r.woman:
		var c: Color = [Color("C2185B"), Color("F6B800"), Color("6A1B9A"), Color("0F7C8C"), Color("E2432A")][id % 5]
		paint = Models.traffic_material(PackedColorArray([c, c.darkened(0.15)]), false)
	else:
		paint = Models.traffic_material(PackedColorArray([_palette[id * 5 % 8], _palette[8 + id * 3 % 8]]), false)
	paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	return paint


# --- The screen ----------------------------------------------------------------


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 8
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
	var stop_box := PanelContainer.new()
	stop_box.add_theme_stylebox_override("panel", Look.card(Look.CREAM.lerp(Color.WHITE, 0.3)))
	stop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_stop = Look.label("", 16, true)
	stop_box.add_child(_next_stop)
	row.add_child(stop_box)
	var status_box := PanelContainer.new()
	status_box.add_theme_stylebox_override("panel", Look.card())
	_status = Look.label("", 15, true)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_box.add_child(_status)
	row.add_child(status_box)
	# The route: nine dots and the bus between them.
	_route_bar = Control.new()
	_route_bar.custom_minimum_size = Vector2(0, 22)
	_route_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route_bar.draw.connect(_draw_route)
	top.add_child(_route_bar)
	# Seat problems: a button for each.
	_problem_row = HBoxContainer.new()
	_problem_row.add_theme_constant_override("separation", 6)
	for problem in ["elder", "women", "need"]:
		var fix := Look.button(strings.t("fix_" + problem), Look.YELLOW.darkened(0.25), 14)
		fix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fix.pressed.connect(_on_fix.bind(problem))
		fix.visible = false
		_problem_row.add_child(fix)
		_problem_buttons[problem] = fix
	top.add_child(_problem_row)
	_crowd_label = Look.label(strings.t("crowded"), 14, true, Look.VERMILION)
	_crowd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crowd_label.visible = false
	top.add_child(_crowd_label)
	# Calling the stop: a bar with a marker running to and fro.
	_call_box = PanelContainer.new()
	_call_box.add_theme_stylebox_override("panel", Look.card(Color.WHITE, 14, 3))
	var call_col := VBoxContainer.new()
	_call_box.add_child(call_col)
	_call_title = Look.label("", 18, true, Look.MAGENTA)
	_call_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	call_col.add_child(_call_title)
	_call_bar = Control.new()
	_call_bar.custom_minimum_size = Vector2(0, 34)
	_call_bar.draw.connect(_draw_call)
	call_col.add_child(_call_bar)
	var call_button := Look.button(strings.t("callButton") if not bus.interactive else strings.t("slapCall"), Look.MAGENTA, 20)
	call_button.custom_minimum_size = Vector2(0, 56)
	call_button.pressed.connect(_on_slap if bus.interactive else _on_call)
	call_col.add_child(call_button)
	_call_box.visible = false
	top.add_child(_call_box)
	# Bottom: the notice, the fares not yet taken, the fare panel.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 10
	bottom.offset_right = -10
	bottom.offset_bottom = -12
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	_notice_box = PanelContainer.new()
	_notice_box.add_theme_stylebox_override("panel", Look.card(Look.CREAM, 12, 2))
	_notice = Look.label("", 15, true)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_box.add_child(_notice)
	_notice_box.visible = false
	bottom.add_child(_notice_box)
	_door_button = Look.button(strings.t("catchDoor"), Look.VERMILION, 20)
	_door_button.custom_minimum_size = Vector2(0, 64)
	_door_button.pressed.connect(_on_catch)
	_door_button.visible = false
	bottom.add_child(_door_button)
	_fare_box = _build_fare_panel()
	_fare_box.visible = false
	bottom.add_child(_fare_box)
	var take := HBoxContainer.new()
	take.add_theme_constant_override("separation", 8)
	_unpaid_label = Look.label("", 16, true, Color.WHITE)
	_unpaid_label.add_theme_color_override("font_outline_color", Look.OUTLINE)
	_unpaid_label.add_theme_constant_override("outline_size", 6)
	_unpaid_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unpaid_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	take.add_child(_unpaid_label)
	_next_button = Look.button(strings.t("nextFare"), Look.PARROT, 18)
	_next_button.custom_minimum_size = Vector2(0, 56)
	_next_button.pressed.connect(_on_next_fare)
	take.add_child(_next_button)
	bottom.add_child(take)
	# By hand: the notes in his fist to sort, and the bus's side to slap.
	var hands := HBoxContainer.new()
	hands.add_theme_constant_override("separation", 8)
	_notes_button = Look.button("", Color("9E7B2F"), 16)
	_notes_button.custom_minimum_size = Vector2(0, 56)
	_notes_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes_button.pressed.connect(_sort_notes)
	hands.add_child(_notes_button)
	_slap_button = Look.button(strings.t("slapPad"), Look.SKY.darkened(0.25), 18)
	_slap_button.custom_minimum_size = Vector2(0, 56)
	_slap_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slap_button.pressed.connect(_on_slap)
	hands.add_child(_slap_button)
	hands.visible = bus.interactive
	bottom.add_child(hands)
	_refresh()


## The fare panel: who, how far, the fare, the note they gave; for a
## student, half or full; then the bag's notes to give the change with.
func _build_fare_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(Color.WHITE, 14, 3))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	_fare_title = Look.label("", 17, true)
	_fare_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_fare_title)
	_fare_sub = Look.label("", 15)
	_fare_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_fare_sub)
	_student_row = HBoxContainer.new()
	_student_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_student_row.add_theme_constant_override("separation", 8)
	var half := Look.button(strings.t("studentHalf"), Look.PARROT, 16)
	half.pressed.connect(_on_student.bind(false))
	_student_row.add_child(half)
	var full := Look.button(strings.t("studentFull"), Look.VERMILION, 16)
	full.pressed.connect(_on_student.bind(true))
	_student_row.add_child(full)
	col.add_child(_student_row)
	_change_box = VBoxContainer.new()
	_change_box.add_theme_constant_override("separation", 6)
	col.add_child(_change_box)
	_giving_label = Look.label("", 16, true, Look.MAGENTA)
	_giving_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_change_box.add_child(_giving_label)
	var notes := HBoxContainer.new()
	notes.add_theme_constant_override("separation", 6)
	for note in BAG_NOTES:
		var button := Look.button("", Color("2E7D4F"), 15)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 52)
		button.pressed.connect(_on_note.bind(note))
		notes.add_child(button)
		_note_buttons[note] = button
	_change_box.add_child(notes)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 6)
	var give := Look.button(strings.t("giveChange"), Look.MAGENTA, 16)
	give.pressed.connect(_on_give)
	actions.add_child(give)
	var recount := Look.button(strings.t("recount"), Look.OUTLINE, 14)
	recount.pressed.connect(_on_recount)
	actions.add_child(recount)
	_change_box.add_child(actions)
	var short := HBoxContainer.new()
	short.alignment = BoxContainer.ALIGNMENT_CENTER
	short.add_theme_constant_override("separation", 6)
	var short_label := Look.label(strings.t("noChange"), 13)
	short_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	short_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	short.add_child(short_label)
	var later := Look.button(strings.t("payLater"), Color("9E7B2F"), 13)
	later.pressed.connect(_on_later)
	short.add_child(later)
	var swap := Look.button(strings.t("askRound"), Color("9E7B2F"), 13)
	swap.pressed.connect(_on_swap)
	short.add_child(swap)
	_change_box.add_child(short)
	return panel


func _say(text: String, colour := Look.OUTLINE, seconds := 2.5) -> void:
	ReadAloud.say(text, strings.lang)
	_notice.text = text
	_notice.add_theme_color_override("font_color", colour)
	_notice_box.visible = true
	_notice_left = seconds


func _process(dt: float) -> void:
	if _frames_logged < 5:
		_frames_logged += 1
		print("[frame] ", _frames_logged, " ", Time.get_ticks_msec(), " ms")
	_alive_left -= dt
	if _alive_left <= 0.0:
		_alive_left = 10.0
		print("[alive] %d ms, %d fps, mem %.0f MB, video %.0f MB, nodes %d, objects %d" % [Time.get_ticks_msec(), Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT)])
	# A hand activity open: the bus's clock runs slower meanwhile.
	var pace := 0.35 if _activity != null and _activity.slow else 1.0
	var events := bus.update(dt * pace)
	_handle(events)
	if not is_processing():
		return
	if _call_at >= 0.0 and bus.clock >= _call_at and _activity == null:
		_call_at = -1.0
		_ring_home()
	# The street slides by; slower into a stop, still while stopped.
	var want := 0.0
	if not bus.at_stop and bus.locked_left <= 0.0:
		want = SPEED * clampf(bus.travel_left / 2.5, 0.25, 1.0)
	_speed = move_toward(_speed, want, dt * 6.0)
	_distance += _speed * dt
	_scenery.position.z = fmod(_distance, PERIOD)
	_stop_sign.position.z += _speed * dt
	# A little sway on the road.
	camera.position.y = 1.55 + sin(_distance * 0.9) * 0.015 * minf(1.0, _speed / SPEED)
	if _notice_left > 0.0:
		_notice_left -= dt
		if _notice_left <= 0.0:
			_notice_box.visible = false
	if _call_box.visible:
		_call_bar.queue_redraw()
	if _checker_left > 0.0:
		_checker_left -= dt
		_checker.visible = _checker_left > 0.0
	_refresh()


func _handle(events: Array) -> void:
	if events.has(BusDay.Event.CALL_OPEN):
		_call_title.text = strings.t("callTitle", {"stop": _stop_name(bus.stop_i + 1)})
		_call_box.visible = true
		# The next stop's sign comes into view up ahead.
		_stop_label.text = _stop_name(bus.stop_i + 1)
		_stop_sign.position.z = -14.0
	if events.has(BusDay.Event.ARRIVED):
		_call_box.visible = false
		if absf(_stop_sign.position.z + 2.5) > 4.0:
			_stop_sign.position.z = -2.5
		_stop_label.text = _stop_name(bus.stop_i)
		var off := events.count(BusDay.Event.ALIGHTED)
		var on := events.count(BusDay.Event.BOARDED)
		print("[bus] stop %d of %d, trip %d: %d off, %d on, %d riders" % [bus.stop_i, bus.route.size() - 1, bus.trip, off, on, bus.riders.size()])
		_say(strings.t("atStop", {"stop": _stop_name(bus.stop_i), "on": on, "off": off}), Look.SKY, 2.5)
		if on > 0:
			_voice.say("bus_board")
		_sync_people()
	if events.has(BusDay.Event.SLIPPED):
		_say(strings.t("slipped", {"n": events.count(BusDay.Event.SLIPPED)}), Look.VERMILION, 3.0)
	if events.has(BusDay.Event.OWED_SHORT):
		_say(strings.t("owedShort"), Look.VERMILION, 3.0)
	if events.has(BusDay.Event.DEPARTED):
		_sync_people()
	if events.has(BusDay.Event.AT_DOOR):
		_say(strings.t("atDoor"), Look.VERMILION, 2.5)
		_voice.say("bus_door")
		if bus.interactive and _activity == null:
			_open(Door.new(), "act_door", _door_done)
	if events.has(BusDay.Event.DOOR_JAM):
		_say(strings.t("doorJam"), Look.VERMILION, 2.5)
		if bus.interactive and _activity == null:
			var crowd := Crowd.new()
			crowd.on_push = bus.push_in
			crowd.waiting = bus.jam_waiting
			_open(crowd, "act_crowd", func(_score: float): _sync_people())
		_sync_people()
	if events.has(BusDay.Event.CHECKER):
		_checker.visible = true
		_checker_left = 4.0
		_voice.say("checker", true)
		if bus.last_fine > 0:
			_say(strings.t("checkerFine", {"n": bus.last_fine}), Look.VERMILION, 4.0)
		else:
			_say(strings.t("checkerClean"), Look.PARROT, 4.0)
	if events.has(BusDay.Event.DAY_OVER):
		_end_trip()
	elif events.has(BusDay.Event.TRIP_OVER):
		print("[bus] trip over")
		# The way back: the route turns round.
		_say(strings.t("tripBack", {"stop": _stop_name(bus.route.size() - 1)}), Look.SKY, 6.0)
		# A hand activity open now would hide that: say it again after.
		_trip_news = _activity != null
		_stop_label.text = _stop_name(0)
		_stop_sign.position.z = -2.5
		_close_fare()
		_sync_people()


func _open(act: Activity, key: String, then: Callable) -> void:
	print("[bus] hands: ", key)
	act.setup(strings, key, key + "_hint")
	act.done.connect(then)
	act.tree_exited.connect(_closed)
	_activity = act
	_layer.add_child(act)


func _closed() -> void:
	_activity = null
	if _trip_news:
		_trip_news = false
		_say(strings.t("tripBack", {"stop": _stop_name(bus.route.size() - 1)}), Look.SKY, 6.0)
	_refresh()


func _door_done(score: float) -> void:
	if score >= 1.0:
		_on_catch()


## Slaps on the bus's side: one while the call is open calls the stop;
## two quick ones at a stop tell Ostad to go.
func _on_slap() -> void:
	Activity.buzz(20)
	if not bus.at_stop:
		if bus.call_open:
			_on_call()
		else:
			_thump.play()
		return
	_thump.play()
	var now := Time.get_ticks_msec() / 1000.0
	_slaps.append(now)
	if _slaps.size() > 2:
		_slaps.pop_front()
	if Hands.slaps(_slaps) == "two":
		_slaps.clear()
		if bus.slap_go().has(BusDay.Event.TOO_EARLY):
			_say(strings.t("tooEarly"), Look.VERMILION, 2.0)
	_refresh()


## The crumpled notes in his hand: sort them between his fingers.
func _sort_notes() -> void:
	if _activity != null or bus.loose.is_empty():
		return
	var act := Notes.new()
	act.notes = bus.loose.duplicate()
	act.on_sort = bus.sort_note
	_open(act, "act_notes", _sorted.bind(act))


func _sorted(_score: float, act: Notes) -> void:
	if act.quick:
		bus.sort_all()
	_refresh()


func _on_fix(problem: String) -> void:
	if problem == "need":
		_ask_to_stand()
		return
	if bus.fix(problem).has(BusDay.Event.SEATED):
		_say(strings.t("fixed_" + problem), Look.PARROT, 2.0)
		_sync_people()
	_refresh()


## Someone ill, or a mother with a baby, standing: whom to ask to stand?
## Without the hands (or busy), the first one asked.
func _ask_to_stand() -> void:
	var who := bus.seat_candidates()
	if who.is_empty():
		return
	var need := "sick"
	for r in bus.riders:
		if r.kind == "needy" and int(r.seat) >= BusDay.SEATS:
			need = str(r.get("need", "sick"))
			break
	if _activity != null or not bus.interactive:
		_seat_given(1.0, null, int(who[0].id))
		return
	var act := Seat.new()
	act.candidates = who
	act.need = need
	_open(act, "act_seat", _seat_given.bind(act, -1))


func _seat_given(_score: float, act, id: int) -> void:
	if act != null:
		id = act.picked
	if id < 0:
		return
	var got := bus.give_seat(id)
	if got.has(BusDay.Event.SEATED):
		var cross := got.has(BusDay.Event.ARGUMENT)
		_say(strings.t("seat_" + bus.last_seat), Look.VERMILION if cross else Look.PARROT, 3.0)
		_sync_people()
	_refresh()


## The phone rings: someone from home. The answer moves the family's
## feeling, and may send money home.
func _ring_home() -> void:
	var call := HomeCall.new().pick("bus", _call_rng, progress.family("bus"))
	if call.is_empty():
		return
	var act := CallAct.new()
	act.call = call
	_open(act, "act_call", _answered.bind(act))


func _answered(_score: float, act) -> void:
	var options: Dictionary = act.call.get("options", {})
	var option: String = act.option
	if option == "" and not options.is_empty():
		# Not answered: as if busy (the last answer).
		option = str(options.keys().back())
	var e := HomeCall.effect(act.call, option)
	var now := progress.add_family("bus", e.family)
	bus.sent_home += e.cost
	_call_result = {"family": now, "delta": e.family}
	print("[home] call ", act.call.get("id", ""), ": ", option, ", family ", now)
	if e.family > 0:
		_say(strings.t("familyUp", {"n": now}), Look.PARROT, 3.0)
	elif e.family < 0:
		_say(strings.t("familyDown", {"n": now}), Look.VERMILION, 3.0)


func _on_catch() -> void:
	if bus.catch().has(BusDay.Event.CAUGHT):
		_ding.play()
		_voice.say("bus_caught", true)
		_say(strings.t("caught"), Look.PARROT, 2.0)
		_sync_people()
	_refresh()


func _on_call() -> void:
	if bus.call_stop().has(BusDay.Event.CALLED):
		_call_box.visible = false
		_thump.play()
		# Babu shouts the stop's name.
		_voice.say("stop_" + bus.stop_id(bus.stop_i + 1), true)
		var stop := _stop_name(bus.stop_i + 1)
		var shout := "%s! %s! %s!" % [stop, stop, stop]
		var result := strings.t("call_" + bus.last_call)
		_say("%s\n%s" % [shout, result], Look.PARROT if bus.last_call != "miss" else Look.OUTLINE, 2.5)


## Asks the passenger who has been on longest for their fare.
func _on_next_fare() -> void:
	var waiting := bus.unpaid()
	if waiting.is_empty():
		return
	_open_fare(int(waiting[0].id))
	# Now and then the passenger has something to say about it.
	if randf() < 0.35:
		_voice.say("bus_fare")


func _open_fare(id: int) -> void:
	var r: Dictionary = {}
	for x in bus.riders:
		if x.id == id:
			r = x
	if r.is_empty():
		return
	bus.asking = r
	bus.asking_fare = int(r.fare)
	_giving = {}
	_fare_box.visible = true
	if r.kind == "student":
		_student_row.visible = true
		_change_box.visible = false
	else:
		bus.ask(id)
		_student_row.visible = false
		_change_box.visible = true
	_refresh()


func _on_student(full: bool) -> void:
	var id := int(bus.asking.get("id", -1))
	bus.asking = {}
	bus.ask(id, full)
	_student_row.visible = false
	_change_box.visible = true
	_refresh()


func _on_note(note: int) -> void:
	if int(_giving.get(note, 0)) < int(bus.bag.get(note, 0)):
		_giving[note] = int(_giving.get(note, 0)) + 1
	_refresh()


func _on_recount() -> void:
	_giving = {}
	_refresh()


func _on_give() -> void:
	var got := bus.give(_giving)
	if got.has(BusDay.Event.ARGUMENT):
		_say(strings.t("argument"), Look.VERMILION, float(b.n("bus.argument_s")))
		_voice.say("bus_argument", true)
		_giving = {}
	elif got.has(BusDay.Event.OVERPAID):
		_say(strings.t("overpaid", {"n": bus.overpaid}), Look.VERMILION, 2.5)
		_close_fare()
	elif got.has(BusDay.Event.SETTLED):
		_coin.play()
		_say(strings.t("settled"), Look.PARROT, 1.5)
		_close_fare()
	_refresh()


func _on_later() -> void:
	if not bus.later().is_empty():
		_say(strings.t("owing"), Look.YELLOW.darkened(0.3), 2.5)
		_close_fare()
	_refresh()


func _on_swap() -> void:
	if bus.swap().has(BusDay.Event.SWAPPED):
		_say(strings.t("swapped"), Look.SKY, float(b.n("bus.swap_s")))
	_refresh()


func _close_fare() -> void:
	_giving = {}
	_fare_box.visible = false


## Brings the screen up to date.
func _refresh() -> void:
	var next_i := bus.stop_i if bus.at_stop else bus.stop_i + 1
	_next_stop.text = strings.t("atStopNow" if bus.at_stop else "nextStop", {"stop": _stop_name(next_i)})
	_status.text = "%s\n%s\n%s" % [strings.t("busTripLine", {"n": bus.trip, "all": bus.trips, "to": _stop_name(bus.route.size() - 1)}),
		strings.t("taka", {"n": bus.earned()}), strings.t("busRating", {"stars": "%.1f" % bus.rating})]
	_route_bar.queue_redraw()
	var waiting := bus.unpaid().size()
	_unpaid_label.text = strings.t("faresDue", {"n": waiting})
	var now := bus.problems()
	for problem in _problem_buttons:
		(_problem_buttons[problem] as Button).visible = now.has(problem)
	_crowd_label.visible = bus.riders.size() > int(b.n("bus.crowded_above"))
	_door_button.visible = not bus.at_door.is_empty()
	if bus.interactive:
		_notes_button.visible = not bus.loose.is_empty()
		_notes_button.text = strings.t("notesInHand", {"n": bus.loose.size()})
		var go := bus.at_stop and bus.dwell_left <= 0.0 and bus.at_door.is_empty()
		_slap_button.text = strings.t("slapGo" if go else ("slapCall" if bus.call_open else "slapPad"))
		_slap_button.add_theme_stylebox_override("normal", Look.card(Look.MAGENTA if go or bus.call_open else Look.SKY.darkened(0.25), 12, 3))
	_next_button.disabled = waiting == 0 or _fare_box.visible
	if _fare_box.visible:
		if bus.asking.is_empty():
			_close_fare()
		else:
			var r: Dictionary = bus.asking
			_fare_title.text = strings.t("fareTitle", {"stop": _stop_name(int(r.to)), "fare": bus.asking_fare})
			if r.get("npc", "") != "":
				_fare_title.text = neighbours.name_of(r.npc, strings.lang) + " · " + _fare_title.text
			if r.kind == "student" and _student_row.visible:
				_fare_sub.text = strings.t("studentAsks", {"half": int(r.fare * b.n("bus.student_share"))})
			else:
				_fare_sub.text = strings.t("paidWith", {"note": int(r.note)})
			var given := 0
			for note in _giving:
				given += int(note) * int(_giving[note])
			_giving_label.text = strings.t("givingBack", {"n": given})
			for note in BAG_NOTES:
				var left := int(bus.bag.get(note, 0)) - int(_giving.get(note, 0))
				var button: Button = _note_buttons[note]
				button.text = strings.t("noteButton", {"note": note, "n": left})
				button.disabled = left <= 0 or bus.locked_left > 0.0


func _draw_route() -> void:
	var w := _route_bar.size.x
	var y := _route_bar.size.y / 2.0
	var n := bus.route.size()
	_route_bar.draw_line(Vector2(10, y), Vector2(w - 10, y), Look.OUTLINE, 3.0)
	for i in n:
		var x := lerpf(10.0, w - 10.0, float(i) / (n - 1))
		_route_bar.draw_circle(Vector2(x, y), 6.0, Look.PARROT if i <= bus.stop_i else Color.WHITE)
		_route_bar.draw_arc(Vector2(x, y), 6.0, 0, TAU, 12, Look.OUTLINE, 2.0)
	var along := float(bus.stop_i)
	if not bus.at_stop:
		var between: Array = b.at("bus.seconds_between_stops")
		var whole := (float(between[0]) + float(between[1])) / 2.0
		along += clampf(1.0 - bus.travel_left / whole, 0.0, 0.95)
	var bx := lerpf(10.0, w - 10.0, along / (n - 1))
	_route_bar.draw_rect(Rect2(bx - 9, y - 7, 18, 14), Look.VERMILION)


func _draw_call() -> void:
	var w := _call_bar.size.x
	var h := _call_bar.size.y
	_call_bar.draw_rect(Rect2(0, 6, w, h - 12), Color("E8E0CF"))
	var good := b.n("bus.good_zone")
	var perfect := bus.perfect_zone()
	_call_bar.draw_rect(Rect2(w * (0.5 - good), 6, w * good * 2.0, h - 12), Look.YELLOW)
	_call_bar.draw_rect(Rect2(w * (0.5 - perfect), 6, w * perfect * 2.0, h - 12), Look.PARROT)
	var x := w * bus.marker()
	_call_bar.draw_rect(Rect2(x - 4, 0, 8, h), Look.OUTLINE)


func _end_trip() -> void:
	print("[bus] day over ", Time.get_ticks_msec(), " ms")
	set_process(false)
	_call_box.visible = false
	_fare_box.visible = false
	var earned := bus.earned()
	var stats := {"no_slip": 1 if bus.slipped == 0 and bus.boarded >= 20 else 0, "on_time": bus.bonus / int(b.n("bus.on_time_bonus")), "riders": bus.boarded}
	var got := progress.apply_bus_day({"earned": earned, "riders": bus.boarded, "stars": bus.rating, "stats": stats, "npcs": bus.npc_log})
	progress.save()
	# And a copy online, if this build has it (not waited for).
	load("res://scripts/ui/cloud.gd").backup(self, progress.data)
	CrashWatch.stop()
	var lines := [strings.t("busRiders", {"n": bus.boarded})]
	if bus.bonus > 0:
		lines.append(strings.t("onTime", {"n": bus.bonus}))
	if bus.slipped > 0:
		lines.append(strings.t("busSlipped", {"n": bus.slipped}))
	if bus.arguments > 0:
		lines.append(strings.t("busArguments", {"n": bus.arguments}))
	if bus.overpaid > 0:
		lines.append(strings.t("busOverpaid", {"n": bus.overpaid}))
	if bus.caught > 0:
		lines.append(strings.t("busCaught", {"n": bus.caught}))
	if bus.fines > 0:
		lines.append(strings.t("busFines", {"n": bus.fines}))
	if not _call_result.is_empty():
		lines.append(strings.t("familyLine", {"n": _call_result.family}))
	if int(got.get("samity_payout", 0)) > 0:
		lines.append(strings.t("samityPayoutLine", {"n": int(got.samity_payout)}))
	elif int(got.get("samity_paid", 0)) > 0:
		lines.append(strings.t("samityDayLine", {"n": int(got.samity_paid)}))
	var end := DayEnd.new()
	end.setup(strings, b, progress, got, {
		"title": strings.t("busDayOver"),
		"stars": bus.rating,
		"sub": strings.t("busRatingLine", {"stars": "%.1f" % bus.rating}),
		"money": earned,
		"lines": lines,
	})
	end.home_pressed.connect(_go_home)
	end.again_pressed.connect(_again)
	_layer.add_child(end)


func _again() -> void:
	CrashWatch.start("bus")
	get_tree().reload_current_scene()


func _go_home() -> void:
	CrashWatch.stop()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## Leaving the app, or Android pausing it, goes in the log: the crash
## report then tells a closed game from one that died.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			print("[app] paused ", Time.get_ticks_msec(), " ms")
		NOTIFICATION_APPLICATION_RESUMED:
			print("[app] resumed ", Time.get_ticks_msec(), " ms")
		NOTIFICATION_WM_CLOSE_REQUEST:
			print("[app] closing ", Time.get_ticks_msec(), " ms")
		NOTIFICATION_WM_GO_BACK_REQUEST:
			print("[app] back button ", Time.get_ticks_msec(), " ms")
