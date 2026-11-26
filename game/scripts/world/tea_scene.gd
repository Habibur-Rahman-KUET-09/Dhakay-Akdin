## Monir Mama's tea stall (§৪.৩) at one of the tea stall corners of the
## real Mirpur map, from the street: the stall, Monir Mama behind the
## counter, customers on the bench in front with their orders over their
## heads. The counter's things are buttons along the bottom: tap them in
## the right order to make each order (tea_day.gd has the rules).
extends Node3D

const RoadMap = preload("res://scripts/rules/road_map.gd")
const TeaDay = preload("res://scripts/rules/tea_day.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Progress = preload("res://scripts/rules/progress.gd")
const Friends = preload("res://scripts/rules/friends.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Look = preload("res://scripts/ui/look.gd")
const Sfx = preload("res://scripts/ui/sfx.gd")
const Voice = preload("res://scripts/ui/voice.gd")
const Tips = preload("res://scripts/ui/tips.gd")
const Chatter = preload("res://scripts/ui/chatter.gd")
const Music = preload("res://scripts/ui/music.gd")
const Activity = preload("res://scripts/ui/activity.gd")
const Pour = preload("res://scripts/ui/activities/pour.gd")
const Stir = preload("res://scripts/ui/activities/stir.gd")
const Paan = preload("res://scripts/ui/activities/paan.gd")
const Stove = preload("res://scripts/ui/activities/stove.gd")
const City = preload("res://scripts/world/city.gd")
const Clutter = preload("res://scripts/world/clutter.gd")
const Models = preload("res://scripts/world/models.gd")
const Traffic = preload("res://scripts/world/traffic.gd")
const CrashWatch = preload("res://scripts/ui/crash_watch.gd")
const Graphics = preload("res://scripts/ui/graphics.gd")
const Reveal = preload("res://scripts/world/reveal.gd")
const Neighbours = preload("res://scripts/rules/neighbours.gd")
const DayLines = preload("res://scripts/ui/day_lines.gd")
const DayEnd = preload("res://scripts/ui/day_end.gd")
const Weather = preload("res://scripts/world/weather.gd")
const CallAct = preload("res://scripts/ui/activities/call.gd")
const Sms = preload("res://scripts/ui/activities/sms.gd")
const Wash = preload("res://scripts/ui/activities/wash.gd")
const LedgerAct = preload("res://scripts/ui/activities/ledger.gd")
const ReadAloud = preload("res://scripts/ui/read_aloud.gd")
const HomeCall = preload("res://scripts/rules/home_call.gd")

## Where the bench and its four seats are, in the stall's own space
## (the stall faces -Z, the street).
const BENCH_Z := -1.7
const SEAT_X := [-1.2, -0.4, 0.4, 1.2]
const CAMERA_AT := Vector3(0, 2.9, -6.5)
const LOOK_AT := Vector3(0, 1.25, 0)
## Button colours by what they are for: tea, snacks, paan.
const STEP_COLOURS := {
	"cup": Color("8B5A2B"), "kettle": Color("8B5A2B"), "milk": Color("8B5A2B"), "sugar": Color("8B5A2B"),
	"banana": Color("C98A00"), "bun_jar": Color("C98A00"),
	"betel_leaf": Color("2E7D32"), "areca": Color("2E7D32"), "lime": Color("2E7D32"),
	"fridge": Color("C62828"),
}

var strings := Strings.new()
var neighbours := Neighbours.new()
var b: Balance
var day: TeaDay
var progress: Progress
var camera: Camera3D
var _stall: Node3D
var _palette := PackedColorArray()
var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial
var _env: Environment
## Per seat: the sitter's mesh (hidden when empty) and their order card.
var _sitters: Array[MeshInstance3D] = []
var _cards: Array[PanelContainer] = []
var _card_titles: Array[Label] = []
var _card_items: Array[Label] = []
var _card_bars: Array[ProgressBar] = []
var _seated := {}
## The order-memory tip, said once a day.
var _memory_told := false
var _rahim_rickshaw: Node3D
var _layer: CanvasLayer
## The hand activity open over the counter, if any.
var _activity: Activity
## Activities that came while another was open, opened after it.
var _queued: Array[Callable] = []
## The wash-up button, and what the credit book did at the day's start.
var _wash: Button
var _collected: Array = []
## A call from home today: when (on the day's clock; -1 when none, or
## once it has rung), and how it went, for the day's end.
var _call_at := -1.0
var _story_effect := {}
var _boost := {}
var _call_rng := RandomNumberGenerator.new()
var _call_result := {}
var _status: Label
var _tray: Label
var _give: Button
var _drop: Button
## The first-day guide (the first few orders of the first tea day): the
## button to press next lights up, the others dim.
var _guide := false
var _guide_label: Label
var _guide_box: PanelContainer
var _step_buttons := {}
var _kettle_button: Button
var _notice: Label
var _notice_box: PanelContainer
var _notice_left := 0.0
var _ding: AudioStreamPlayer
## The glass set down, and the customers and Monir Mama talking.
var _cup: AudioStreamPlayer
var _voice: Voice
var _chat_left := Chatter.gap()
## Rain: how hard (0–1, eased), the drops and their sound.
var _rain_k := 0.0
var _drops: CPUParticles3D
var _rain_sound: AudioStreamPlayer
var _alive_left := 10.0
var _frames_logged := 0


func _ready() -> void:
	strings.lang = Strings.saved_lang()
	b = Balance.new()
	progress = Progress.new(b)
	day = TeaDay.new(b, -1, progress.data.tea.upgrades, progress.date())
	day.interactive = Activity.wanted()
	# Remembering hidden orders was taken out (too fiddly): every order
	# stays on its card.
	day.memory = false
	day.level = progress.level()
	# A chapter's mark on the day: the stall moved on, or the cricket final.
	_story_effect = progress.story_effect("tea")
	day.arrival_factor = float(_story_effect.get("arrivals", 1.0))
	# A loudspeaker bought with stars.
	_boost = progress.take_boost("tea")
	day.arrival_factor *= float(_boost.get("arrivals", 1.0))
	_call_rng.randomize()
	var call_share := HomeCall.plan(_call_rng, progress.level())
	if call_share >= 0.0:
		_call_at = call_share * day.day_seconds
	var ids := neighbours.ids()
	ids.shuffle()
	day.npc_pool = ids.slice(0, 6)
	day.relations = progress.data.npcs
	# The credit book carries over from day to day: those due pay now.
	if typeof(progress.data.get("ledger")) != TYPE_ARRAY:
		progress.data["ledger"] = []
	day.ledger = progress.data.ledger
	if day.interactive:
		_collected = day.collect()
	set_process(false)
	var loading := _loading_screen()
	await _step("map")
	var map: RoadMap = RoadMap.load_area("mirpur")
	var tile := _stall_tile(map)
	await _step("environment")
	_environment()
	await _step("town")
	var town := City.build(map, strings.lang, tile, day.festival)
	add_child(town)
	await _step("clutter")
	for hex in Traffic.PALETTE:
		_palette.append(Color(hex))
	var clutter := Clutter.build(map, _palette)
	add_child(clutter)
	await _step("stall")
	_build_stall(map, tile)
	_clear_signs(town)
	await _step("sounds")
	_sounds()
	await _step("hud")
	_build_hud()
	# A part at a time, so a crash while drawing names the part.
	var blocks := town.get_node("Blocks")
	var poles := town.get_node("Poles")
	var first := [town.get_child(0), town.get_child(1)]
	await Reveal.run(self, "tea", [
		["sky", []],
		["roads", first],
		["buildings", Reveal.geometry(blocks, false)],
		["poles and wires", Reveal.geometry(poles, false)],
		["town bits", Reveal.geometry(town, false, first + [blocks, poles])],
		["shop signs", Reveal.geometry(town, true)],
		["roadside", Reveal.geometry(clutter, false) + Reveal.geometry(clutter, true)],
		["stall", Reveal.geometry(_stall, false) + Reveal.geometry(_stall, true)],
	])
	CrashWatch.start("tea: graphics " + Graphics.level())
	Graphics.apply(get_viewport(), _env, _sun)
	await get_tree().process_frame
	await get_tree().process_frame
	await _step("done")
	loading.queue_free()
	set_process(true)
	if not _story_effect.is_empty():
		_say(strings.t("after_" + str(_story_effect.note), {"n": int(_story_effect.left)}), Look.MAGENTA, 6.0)
	elif not _boost.is_empty():
		_say(strings.t("boostUsed", {"name": strings.t("boost_" + str(_boost.id))}), Look.SKY, 4.0)
	elif not day.festival.is_empty():
		_say(str(day.festival.greeting.get(strings.lang, day.festival.greeting.en)), Look.MAGENTA, 6.0)
	elif day.hot:
		_say(strings.t("teaHotFridge" if day.has("fridge") else "teaHot"), Look.VERMILION, 4.0)
	if not _collected.is_empty():
		get_tree().create_timer(6.0 if _notice_box.visible else 0.5).timeout.connect(_tell_collected)


func _loading_screen() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var bg := ColorRect.new()
	bg.color = Look.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var text := Look.label(strings.t("teaLoading"), 22, true)
	text.set_anchors_preset(Control.PRESET_CENTER)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(text)
	layer.add_child(Tips.card(strings))
	add_child(layer)
	return layer


func _step(what: String) -> void:
	CrashWatch.start("tea: " + what)
	print("[tea] ", what, " ", Time.get_ticks_msec(), " ms")
	await get_tree().process_frame


## The tea stall tile nearest the middle of the map (busy streets).
func _stall_tile(map: RoadMap) -> Vector2i:
	var best := Vector2i(-1, -1)
	var mid := Vector2(map.width, map.height) / 2.0
	for p in map.roads():
		if map.kind_at(p) != RoadMap.Kind.TEA or City._inward(map, p) == Vector3.ZERO:
			continue
		if best.x < 0 or Vector2(p).distance_to(mid) < Vector2(best).distance_to(mid):
			best = p
	return best


func _environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("9DB4C6")
	sky_mat.sky_horizon_color = Color("E2DED2")
	sky_mat.ground_horizon_color = Color("D9D4C6")
	sky_mat.ground_bottom_color = Color("B8B0A0")
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
	env.fog_density = 0.006
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_hdr_threshold = 0.95
	_env = env
	_sky = sky_mat
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-40, -35, 0)
	_sun.light_color = Color("FFF1D6")
	_sun.light_energy = 0.8
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_max_distance = 30.0
	add_child(_sun)
	Graphics.plain(get_viewport(), env, _sun)


## The stall on the pavement at the tea tile, its sign, Monir Mama, the
## bench and the four sitters, and the camera across the street.
func _build_stall(map: RoadMap, tile: Vector2i) -> void:
	var inward := City._inward(map, tile)
	_stall = Node3D.new()
	_stall.name = "Stall"
	_stall.position = City._side(map, tile) - inward * 0.1
	# The stall's -Z (its front) looks out at the street.
	_stall.basis = Basis(Vector3.UP, atan2(inward.x, inward.z))
	add_child(_stall)
	var plain := Models.material()
	var stall_mesh := MeshInstance3D.new()
	stall_mesh.mesh = Models.tea_stall()
	stall_mesh.material_override = plain
	_stall.add_child(stall_mesh)
	var board := Label3D.new()
	board.text = strings.t("teaStallSign")
	board.font = Look.font(Look.BOLD)
	board.font_size = 56
	board.outline_size = 12
	board.modulate = Look.YELLOW
	board.outline_modulate = Look.OUTLINE
	# A bought signboard colour.
	var sign_look := progress.worn("tea", "sign")
	if not sign_look.is_empty():
		board.modulate = Color(str(sign_look.fill))
		board.outline_modulate = Color(str(sign_look.outline))
	board.pixel_size = 0.0045
	board.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	board.position = Vector3(0, 2.9, -0.82)
	board.rotation.y = PI
	_stall.add_child(board)
	# Monir Mama behind the counter: white vest, checked blue lungi.
	var mama := MeshInstance3D.new()
	mama.mesh = Models.person()
	var mama_paint := Models.traffic_material(PackedColorArray([Color("F4F1E8"), Color("2D5D8A")]), false)
	mama_paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	mama.material_override = mama_paint
	mama.position = Vector3(-0.2, 0.05, 0.25)
	mama.rotation.y = PI
	_stall.add_child(mama)
	var bench := MeshInstance3D.new()
	bench.mesh = Models.bench()
	bench.material_override = plain
	bench.position = Vector3(0, 0, BENCH_Z)
	_stall.add_child(bench)
	if not day.upgrades.is_empty():
		var extras := MeshInstance3D.new()
		extras.mesh = Models.tea_extras(day.upgrades, BENCH_Z)
		extras.material_override = plain
		_stall.add_child(extras)
		if day.has("fridge"):
			var cold := Label3D.new()
			cold.text = strings.t("coldSign")
			cold.font = Look.font(Look.BOLD)
			cold.font_size = 32
			cold.pixel_size = 0.004
			cold.modulate = Look.VERMILION
			cold.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			cold.position = Vector3(-1.65, 1.42, -0.43)
			cold.rotation.y = PI
			_stall.add_child(cold)
	var sitter_mesh := Models.bench_sitter()
	for i in SEAT_X.size():
		var sitter := MeshInstance3D.new()
		sitter.mesh = sitter_mesh
		# Facing the counter (+Z here; the model looks along -Z).
		sitter.position = Vector3(SEAT_X[i], 0, BENCH_Z + 0.05)
		sitter.rotation.y = PI
		sitter.visible = false
		_stall.add_child(sitter)
		_sitters.append(sitter)
	# Rahim Chacha's rickshaw, parked by the bench while he has his tea.
	_rahim_rickshaw = Models.player_rickshaw(Look.YELLOW, Look.MAGENTA)
	var paint := Models.traffic_material(_palette, false)
	paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 4))
	(_rahim_rickshaw.get_meta("body") as MeshInstance3D).material_override = paint
	for w in _rahim_rickshaw.get_meta("wheels"):
		(w as MeshInstance3D).material_override = plain
	_rahim_rickshaw.position = Vector3(2.9, 0, -1.9)
	_rahim_rickshaw.rotation.y = PI / 2
	_rahim_rickshaw.visible = false
	_stall.add_child(_rahim_rickshaw)
	camera = Camera3D.new()
	camera.fov = 66
	camera.near = 0.2
	camera.far = 160
	add_child(camera)
	camera.global_position = _stall.to_global(CAMERA_AT)
	camera.look_at(_stall.to_global(LOOK_AT))
	camera.current = true


## The shop's signboard on the wall behind the stall would show through
## the stall's own name: take down the town's lettering close by.
func _clear_signs(town: Node) -> void:
	var near := _stall.global_position
	var todo: Array[Node] = [town]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		todo.append_array(n.get_children())
		if n is Label3D and (n as Label3D).global_position.distance_to(near) < 4.5:
			(n as Label3D).visible = false


func _sounds() -> void:
	var hum := AudioStreamPlayer.new()
	hum.stream = Sfx.stream("hum")
	hum.volume_db = -12.0
	add_child(hum)
	hum.finished.connect(hum.play)
	hum.play()
	_rain_sound = AudioStreamPlayer.new()
	_rain_sound.stream = Sfx.stream("rain")
	_rain_sound.volume_db = -60.0
	add_child(_rain_sound)
	_rain_sound.finished.connect(_rain_again)
	_drops = Weather.rain_drops()
	add_child(_drops)
	_ding = AudioStreamPlayer.new()
	# A served customer pays: coins in the tin.
	_ding.stream = Sfx.stream("coin")
	_ding.volume_db = -8.0
	add_child(_ding)
	_cup = AudioStreamPlayer.new()
	_cup.stream = Sfx.stream("cup", "bell")
	_cup.volume_db = -10.0
	add_child(_cup)
	_voice = Voice.new()
	add_child(_voice)
	var tune := Music.new()
	tune.track = "tune_tea" if day.festival.is_empty() else "tune_festival"
	tune.volume_db = -18.0
	add_child(tune)
	# The talk of the bazar round the stall, where there is a recording.
	var crowd_stream := Sfx.stream("crowd", "none")
	if crowd_stream != null:
		var crowd := AudioStreamPlayer.new()
		crowd.stream = crowd_stream
		crowd.volume_db = -16.0
		add_child(crowd)
		crowd.finished.connect(crowd.play)
		crowd.play()


# --- The screen --------------------------------------------------------------


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	# Top: back, and the clock and money.
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 8
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var back := Look.button(strings.t("back"), Look.OUTLINE, 15)
	back.pressed.connect(_go_home)
	top.add_child(back)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)
	var status_box := PanelContainer.new()
	status_box.add_theme_stylebox_override("panel", Look.card())
	_status = Look.label("", 16, true)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_box.add_child(_status)
	top.add_child(status_box)
	# An order card over each seat.
	for i in SEAT_X.size():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", Look.card(Color.WHITE, 10, 2))
		card.custom_minimum_size = Vector2(112, 0)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		card.add_child(col)
		var title := Look.label("", 12, false, Look.OUTLINE.lerp(Color.WHITE, 0.3))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(title)
		var items := Look.label("", 15, true)
		items.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(items)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.custom_minimum_size = Vector2(0, 8)
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color("E8E0CF")
		bar_bg.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bar_bg)
		bar.add_theme_stylebox_override("fill", StyleBoxFlat.new())
		col.add_child(bar)
		card.visible = false
		# With a cup ready, tapping a card hands it to that customer.
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card.bind(i))
		root.add_child(card)
		_cards.append(card)
		_card_titles.append(title)
		_card_items.append(items)
		_card_bars.append(bar)
	# Bottom: what is in hand, then the counter's things.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 10
	bottom.offset_right = -10
	bottom.offset_bottom = -12
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	_notice_box = PanelContainer.new()
	_notice_box.add_theme_stylebox_override("panel", Look.card(Look.CREAM, 12, 2))
	_notice = Look.label("", 15, true)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_box.add_child(_notice)
	_notice_box.visible = false
	bottom.add_child(_notice_box)
	var hand := PanelContainer.new()
	hand.add_theme_stylebox_override("panel", Look.card(Color.WHITE, 12, 2))
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 6)
	hand.add_child(hand_row)
	_tray = Look.label("", 15, true)
	_tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tray.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hand_row.add_child(_tray)
	_wash = Look.button("", Look.SKY.darkened(0.15), 14)
	_wash.pressed.connect(_open_wash)
	_wash.visible = day.interactive
	hand_row.add_child(_wash)
	_give = Look.button(strings.t("give"), Look.PARROT, 16)
	_give.pressed.connect(_on_give)
	hand_row.add_child(_give)
	var drop := Look.button(strings.t("discard"), Look.VERMILION, 14)
	drop.pressed.connect(_on_discard)
	hand_row.add_child(drop)
	_drop = drop
	bottom.add_child(hand)
	_guide = int(progress.data.tea.get("days", 0)) == 0
	_guide_box = PanelContainer.new()
	_guide_box.add_theme_stylebox_override("panel", Look.card(Color("FFF1F6"), 12, 2))
	_guide_label = Look.label("", 16, true, Look.MAGENTA)
	_guide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide_box.add_child(_guide_label)
	_guide_box.visible = false
	bottom.add_child(_guide_box)
	var grid := GridContainer.new()
	# Three across; four once the fridge makes ten, so it stays three rows.
	grid.columns = 4 if day.steps().size() > 9 else 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for step in day.steps():
		var button := Look.button(strings.t("step_" + step), STEP_COLOURS[step], 17)
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_step.bind(step))
		grid.add_child(button)
		_step_buttons[step] = button
		if step == "kettle":
			_kettle_button = button
	bottom.add_child(grid)
	_refresh()


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
	# A hand activity open: the stall's clock runs slower meanwhile.
	var pace := 0.35 if _activity != null and _activity.slow else 1.0
	var events := day.update(dt * pace)
	_handle(events)
	_chat_tick(dt)
	if not is_processing():
		return
	if _activity == null and not _queued.is_empty():
		_queued.pop_front().call()
	# A call from home comes when the stall is quiet (one waiting at most),
	# or after half a minute's wait for that.
	if _call_at >= 0.0 and day.clock >= _call_at and _activity == null \
			and (day.customers.size() <= 1 or day.clock >= _call_at + 30.0):
		_call_at = -1.0
		_ring_home()
	if _notice_left > 0.0:
		_notice_left -= dt
		if _notice_left <= 0.0:
			_notice_box.visible = false
	_weather(dt)
	_light()
	_refresh()


func _handle(events: Array) -> void:
	if events.has(TeaDay.Event.PHONE_PAY):
		_check_sms.call_deferred()
	if events.has(TeaDay.Event.CREDIT_ASK):
		_queued.append(_ask_credit)
	if events.has(TeaDay.Event.NO_CUPS):
		_say(strings.t("noCups"), Look.VERMILION, 2.5)
		_queued.append(_open_wash)
	if events.has(TeaDay.Event.CHANGED):
		var ch: Dictionary = day.last_change
		var who := strings.t("kind_" + str(ch.kind)) if str(ch.npc) == "" else neighbours.name_of(str(ch.npc), strings.lang)
		_say(strings.t("orderChanged", {"who": who, "item": strings.t("item_" + str(ch.to))}), Look.MAGENTA, 3.5)
	if events.has(TeaDay.Event.ARRIVED):
		var ordered := false
		for c in day.customers:
			if not _seated.has(c.id) and (c.kind == "rahim" or c.kind == "babu"):
				_say(strings.t(c.kind + "Arrived"), Look.MAGENTA, 3.0)
			elif not _seated.has(c.id) and not ordered:
				ordered = true
				_voice.say("tea_order")
	if events.has(TeaDay.Event.SERVED):
		var last: Dictionary = day.last_served
		if last.kind == "rahim":
			_say(_rahim_line(), Look.MAGENTA, 5.0)
		elif last.kind == "babu":
			_say(strings.t("babuLine", {"level": int(b.n("unlocks.bus"))}), Look.SKY, 5.0)
		elif last.get("thanks", false):
			_say(strings.t("npcThanks", {"name": neighbours.name_of(last.npc, strings.lang)}), Look.PARROT, 3.0)
		elif last.get("remembered", false):
			_say(strings.t("servedRemembered", {"bill": last.bill, "tip": last.tip}), Look.PARROT)
			_voice.say("tea_happy")
		elif last.get("perfect", false):
			_say(strings.t("servedPerfect", {"bill": last.bill, "tip": last.tip}), Look.PARROT)
			_voice.say("tea_happy")
		elif last.happy:
			_say(strings.t("servedHappy", {"bill": last.bill, "tip": last.tip}), Look.PARROT)
			_voice.say("tea_happy")
		else:
			_say(strings.t("servedPlain", {"bill": last.bill}), Look.OUTLINE)
		_cup.play()
		_ding.play()
	if events.has(TeaDay.Event.RAIN_START):
		_say(strings.t("teaRainAwning" if day.has("awning") else "teaRain"), Look.SKY, 3.5)
		_voice.say("tea_rain")
		_rain_sound.play()
	if events.has(TeaDay.Event.RAIN_END):
		_say(strings.t("rainEnd"), Look.SKY, 2.0)
	if events.has(TeaDay.Event.LEFT):
		_say(strings.t("customerLeft"), Look.VERMILION)
		# Kept waiting too long: off they go, cursing.
		_voice.say("tea_angry", true)
	if events.has(TeaDay.Event.WRONG_STEP):
		_say(strings.t("wrongStep"), Look.VERMILION, 2.0)
		_voice.say("tea_wrong")
	if events.has(TeaDay.Event.WHO):
		_say(strings.t("whoOrdered"), Look.SKY, 2.5)
		if not _memory_told:
			_memory_told = true
			_say(strings.t("memoryTip"), Look.SKY, 5.0)
	if events.has(TeaDay.Event.WRONG_PERSON):
		_say(strings.t("wrongPerson"), Look.VERMILION, 2.0)
		Activity.buzz(60)
	if events.has(TeaDay.Event.NOBODY_WANTS):
		_say(strings.t("nobodyWants"), Look.VERMILION, 2.0)
	if events.has(TeaDay.Event.KETTLE_EMPTY):
		_say(strings.t("kettleEmptyNote"), Look.YELLOW.darkened(0.3), 3.0)
		_voice.say("monir_kettle")
	if events.has(TeaDay.Event.KETTLE_FULL):
		_say(strings.t("kettleFull", {"n": day.kettle_size}), Look.PARROT, 1.5)
	if events.has(TeaDay.Event.DAY_OVER):
		_end_day()


## What Rahim Chacha says over his tea: how his daughter's school fee is
## coming along (from the save, so the two characters share one story).
func _rahim_line() -> String:
	var saved := int(progress.data.rickshaw.school)
	var goal := progress.school_goal()
	if saved >= goal:
		return strings.t("rahimLineDone")
	return strings.t("rahimLine", {"n": saved, "left": goal - saved})


func _on_step(step: String) -> void:
	if not is_processing() or _activity != null:
		return
	if day.interactive and _by_hand(step):
		return
	var got := day.tap(step)
	_handle(got)
	if day.interactive and got.has(TeaDay.Event.REFILLING):
		_fan_stove()
	_refresh()


## The steps done by hand, when that makes sense now: pouring the tea
## (cup in hand, tea in the kettle), the sugar, the whole paan.
func _by_hand(step: String) -> bool:
	if step == "kettle" and day.tray == ["cup"] and _tea_ready():
		_open(Pour.new(), "act_pour", _poured)
		return true
	if step == "sugar" and day.tray == ["cup", "kettle", "milk"]:
		var stir := Stir.new()
		stir.spoons_wanted = day.sugar_wanted()
		_open(stir, "act_sugar", _sugared)
		return true
	if step == "betel_leaf" and day.tray.is_empty():
		var paan := Paan.new()
		paan.wants_zarda = day.zarda_wanted()
		_open(paan, "act_paan", _folded)
		return true
	return false


## A kettle with tea in it, not filling.
func _tea_ready() -> bool:
	return (day.kettle > 0 and day.refill_left <= 0.0) or (day.has_second and day.kettle2 > 0 and day.refill2_left <= 0.0)


func _open(act: Activity, key: String, then: Callable) -> void:
	print("[tea] hands: ", key)
	act.setup(strings, key, key + "_hint")
	act.done.connect(then)
	act.tree_exited.connect(_closed)
	_activity = act
	_layer.add_child(act)


func _closed() -> void:
	_activity = null
	_refresh()


func _poured(score: float) -> void:
	_handle(day.tap("kettle", score))
	_cup.play()


func _sugared(score: float) -> void:
	_handle(day.tap("sugar", score))


func _folded(score: float) -> void:
	for step in ["betel_leaf", "areca", "lime"]:
		_handle(day.tap(step, score))


## The kettle went on to fill: fan the stove (or blow on it) to hurry it.
func _fan_stove() -> void:
	var stove := Stove.new()
	stove.on_fan = func(seconds: float): return day.fan(seconds)
	stove.filled = _kettle_filled
	stove.fan_s = b.n("tea_stall.fan_s")
	_open(stove, "act_stove", func(_score: float): pass)


## How far the filling kettle has got (1 once neither is filling).
func _kettle_filled() -> float:
	var full := b.n("tea_stall.kettle_refill_s")
	var left := maxf(day.refill_left, day.refill2_left)
	return 1.0 - clampf(left / full, 0.0, 1.0)


## The phone rings: someone from home. The answer moves the family's
## feeling, and may send money home.
func _ring_home() -> void:
	var call := HomeCall.new().pick("tea", _call_rng, progress.family("tea"))
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
	var now := progress.add_family("tea", e.family)
	day.money -= e.cost
	_call_result = {"family": now, "delta": e.family}
	print("[home] call ", act.call.get("id", ""), ": ", option, ", family ", now)
	if e.family > 0:
		_say(strings.t("familyUp", {"n": now}), Look.PARROT, 3.0)
	elif e.family < 0:
		_say(strings.t("familyDown", {"n": now}), Look.VERMILION, 3.0)


func _on_give() -> void:
	_handle(day.give())
	_refresh()


## A tap on a customer's card: hand them what is ready.
func _on_card(event: InputEvent, seat: int) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed or day.made() == "":
		return
	_handle(day.give_to(seat))
	_refresh()


func _on_discard() -> void:
	day.discard()
	_refresh()


## Brings the screen up to date: who sits where, their orders and
## patience, what is in hand, the kettle, the clock and the money.
func _refresh() -> void:
	var by_seat := {}
	for c in day.customers:
		by_seat[c.seat] = c
	var rahim_here := false
	_seated.clear()
	for i in SEAT_X.size():
		var c = by_seat.get(i)
		var sitter := _sitters[i]
		var card := _cards[i]
		if c == null:
			sitter.visible = false
			card.visible = false
			continue
		_seated[c.id] = true
		if not sitter.visible or sitter.get_meta("id", -1) != c.id:
			sitter.set_meta("id", c.id)
			sitter.material_override = _sitter_paint(c)
		sitter.visible = true
		if c.kind == "rahim":
			rahim_here = true
		card.visible = true
		_card_titles[i].text = strings.t("kind_" + c.kind) if c.get("npc", "") == "" else neighbours.name_of(c.npc, strings.lang)
		var names := PackedStringArray()
		for it in c.items:
			names.append(strings.t("item_" + it))
		# An order to remember: shown for a moment, then only "?".
		_card_items[i].text = strings.t("orderHidden") if day.order_hidden(c) else "\n".join(names)
		var share: float = clampf(c.left / c.patience, 0.0, 1.0)
		_card_bars[i].value = share
		var fill := StyleBoxFlat.new()
		fill.bg_color = Look.PARROT if share > 0.5 else (Look.YELLOW if share > 0.25 else Look.VERMILION)
		fill.set_corner_radius_all(4)
		_card_bars[i].add_theme_stylebox_override("fill", fill)
		# Over the sitter's head, on screen.
		var head := _stall.to_global(Vector3(SEAT_X[i], 2.0, BENCH_Z))
		var at := camera.unproject_position(head)
		card.position = at - Vector2(card.size.x / 2.0, card.size.y)
	_rahim_rickshaw.visible = rahim_here
	# In hand.
	if day.tray.is_empty():
		_tray.text = strings.t("trayEmpty")
	else:
		var steps := PackedStringArray()
		for st in day.tray:
			steps.append(strings.t("step_" + st))
		_tray.text = strings.t("tray", {"steps": " + ".join(steps)})
	_give.disabled = day.made() == ""
	_show_guide()
	if day.has_second:
		_kettle_button.text = strings.t("kettleTwo", {"a": _kettle_state(day.kettle, day.refill_left), "b": _kettle_state(day.kettle2, day.refill2_left)})
	elif day.refill_left > 0.0:
		_kettle_button.text = strings.t("kettleFilling")
	elif day.kettle <= 0:
		_kettle_button.text = strings.t("kettleEmpty")
	else:
		_kettle_button.text = strings.t("kettleCups", {"n": day.kettle})
	_status.text = "%s\n%s" % [_clock_text(), strings.t("taka", {"n": day.money})]
	if day.interactive:
		_status.text += "\n" + strings.t("cupsState", {"n": day.cups_clean, "of": day.cups_total})
		_wash.text = strings.t("washButton", {"n": day.cups_dirty})
		_wash.disabled = day.cups_dirty <= 0


## One kettle of two: its cups, or that it is filling.
func _kettle_state(cups: int, filling: float) -> String:
	return strings.t("filling") if filling > 0.0 else str(cups)


## Shirt and trousers from the street's colours; Rahim Chacha in his own.
func _sitter_paint(c: Dictionary) -> ShaderMaterial:
	var paint: ShaderMaterial
	if c.kind == "rahim":
		paint = Models.traffic_material(PackedColorArray([Color("3A6EA5"), Color("4E4A44")]), false)
	elif c.kind == "babu":
		paint = Models.traffic_material(PackedColorArray([Color("1F4F8B"), Color("6D6A64")]), false)
	elif c.kind == "office":
		paint = Models.traffic_material(PackedColorArray([Color("F2F2F2"), Color("2B2B2B")]), false)
	else:
		paint = Models.traffic_material(PackedColorArray([_palette[c.id % 8], _palette[8 + (c.id * 3) % 8]]), false)
	paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	return paint


func _clock_text() -> String:
	var hour := day.hour()
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


## Morning to night: the light follows the clock (dawn at 6, dark by 8).
func _rain_again() -> void:
	if _rain_k > 0.02:
		_rain_sound.play()


## Eases the rain in and out: drops in front of the camera, the sound.
func _weather(dt: float) -> void:
	_rain_k = move_toward(_rain_k, 1.0 if day.raining else 0.0, dt / 4.0)
	_drops.emitting = _rain_k > 0.3 and day.raining
	_drops.position = camera.global_position + (_stall.global_position - camera.global_position).normalized() * 4.0 + Vector3(0, 6.0, 0)
	_rain_sound.volume_db = linear_to_db(maxf(_rain_k, 0.001)) - 4.0


func _light() -> void:
	var h := day.hour()
	var dawn := clampf(1.0 - (h - 6.0) / 1.5, 0.0, 1.0)
	var noon := clampf(1.0 - absf(h - 12.5) / 6.5, 0.0, 1.0)
	var dusk := clampf((h - 16.5) / 3.0, 0.0, 1.0)
	var night := clampf((h - 19.0) / 2.0, 0.0, 1.0)
	_sun.light_color = Color("FFE2B8").lerp(Color("FFF6E6"), noon).lerp(Color("FF9A4D"), dusk).lerp(Color("8FA3D6"), night)
	_sun.light_energy = lerpf(0.65, 0.95, noon) * lerpf(1.0, 0.35, maxf(night, dawn))
	_sun.rotation_degrees.x = -lerpf(18.0, 60.0, noon)
	_env.ambient_light_energy = lerpf(0.35, 0.2, maxf(night, dawn))
	_sky.sky_top_color = Color("9DB4C6").lerp(Color("C9876A"), dusk).lerp(Color("1E2A44"), maxf(night, dawn * 0.6))
	_sky.sky_horizon_color = Color("E2DED2").lerp(Color("F0B27A"), maxf(dusk, dawn)).lerp(Color("3A4566"), night)
	_env.fog_light_color = Color("D8D5C8").lerp(Color("E5B48C"), dusk).lerp(Color("2E3650"), night)
	if _rain_k > 0.0:
		_sun.light_energy *= lerpf(1.0, 0.3, _rain_k)
		_sky.sky_top_color = _sky.sky_top_color.lerp(Color("6E7882"), _rain_k * 0.8)
		_sky.sky_horizon_color = _sky.sky_horizon_color.lerp(Color("9DA4AA"), _rain_k * 0.8)
		_env.fog_light_color = _env.fog_light_color.lerp(Color("8F979E"), _rain_k * 0.8)
	_env.fog_density = lerpf(0.006, 0.025, _rain_k)


## Washing up: the dirty cups, six at a time.
func _open_wash() -> void:
	if _activity != null or day.cups_dirty <= 0 or not is_processing():
		return
	var act := Wash.new()
	act.dirty = mini(day.cups_dirty, 6)
	_open(act, "act_wash", _washed.bind(act))


func _washed(_score: float, act) -> void:
	# Skipped: half of them rinsed in a hurry.
	var n: int = ceili(act.dirty / 2.0) if act.quick else int(act.washed)
	n = day.wash(n)
	if n > 0:
		_say(strings.t("washedSay", {"n": n}), Look.PARROT, 2.0)
	_refresh()


## "Write it in the book": the credit book opens.
func _ask_credit() -> void:
	var ask: Dictionary = day.credit_ask
	if ask.is_empty():
		return
	var act := LedgerAct.new()
	act.who = neighbours.name_of(str(ask.npc), strings.lang)
	var listed := 0
	for it in ask.items:
		act.items.append([strings.t("item_" + str(it)), day.price(str(it))])
		listed += day.price(str(it))
	# Iftar time: the packet with it.
	if int(ask.bill) > listed:
		act.items.append([strings.t("iftarPacket"), int(ask.bill) - listed])
	act.bill = int(ask.bill)
	act.owed = day.owed_total()
	_open(act, "act_ledger", _credit_answered.bind(act))


func _credit_answered(_score: float, act) -> void:
	var bill := int(day.credit_ask.get("bill", 0))
	var result := day.settle_credit(act.give, act.written)
	print("[tea] credit: ", result)
	match result:
		"cash":
			_say(strings.t("credit_cash", {"name": act.who}), Look.SKY, 3.0)
		"right":
			_say(strings.t("credit_right", {"name": act.who, "n": act.written}), Look.PARROT, 3.0)
		"short":
			_say(strings.t("credit_short", {"d": bill - int(act.written)}), Look.VERMILION, 3.5)
		"over":
			_say(strings.t("credit_over"), Look.YELLOW.darkened(0.3), 3.5)
	_refresh()


## What the book brought in this morning, and who still has not paid.
func _tell_collected() -> void:
	var paid := _collected.filter(func(x): return x.paid)
	var text := PackedStringArray()
	if not paid.is_empty():
		var n := 0
		for x in paid:
			n += int(x.amount)
		text.append(strings.t("creditCollected", {"n": n, "k": paid.size()}))
	for x in _collected:
		if not x.paid:
			text.append(strings.t("creditNotPaid", {"name": neighbours.name_of(str(x.npc), strings.lang)}))
	if not text.is_empty():
		_say("\n".join(text), Look.MAGENTA, 5.0)


## Paid by phone: check the SMS on Monir Mama's phone.
func _check_sms() -> void:
	if day.phone_pay.is_empty():
		return
	if _activity != null:
		_sms_checked(1.0, null)
		return
	var act := Sms.new()
	act.sms = day.phone_pay.sms
	act.fare = int(day.phone_pay.fare)
	act.has_phone = progress.has_phone()
	_open(act, "act_sms", _sms_checked.bind(act))


func _sms_checked(_score: float, act) -> void:
	var fare := int(day.phone_pay.get("fare", 0))
	var result := day.settle_phone(act != null and act.said_fake)
	print("[tea] phone pay: ", result)
	var colour: Color = {"fine": Look.PARROT, "caught": Look.PARROT, "fooled": Look.VERMILION, "wrong": Look.VERMILION}.get(result, Look.SKY)
	_say(strings.t("phone_" + result, {"fare": fare}), colour, 3.0)


func _end_day() -> void:
	set_process(false)
	# An SMS not yet checked when the day ends: taken as it is; credit
	# not yet answered goes in the book as it was.
	day.settle_phone(false)
	day.settle_credit(true)
	_rain_sound.stop()
	_drops.emitting = false
	var stats := {"happy": day.happy, "none_lost": 1 if day.lost == 0 and day.served >= 10 else 0, "milk_tea": int(day.sold_items.get("milk_tea", 0))}
	var result := {"earned": day.money, "served": day.served, "happy": day.happy, "lost": day.lost, "stars": day.stars(), "stats": stats, "npcs": day.npc_log}
	var got := progress.apply_tea_day(result)
	progress.save()
	# And a copy online, if this build has it (not waited for).
	load("res://scripts/ui/cloud.gd").backup(self, progress.data)
	CrashWatch.stop()
	var lines: Array = [
		strings.t("teaSold", {"n": day.sold}),
		strings.t("teaServed", {"served": day.served, "happy": day.happy}),
	]
	if day.lost > 0:
		lines.append(strings.t("teaLost", {"n": day.lost}))
	if day.tips > 0:
		lines.append(strings.t("teaTips", {"n": day.tips}))
	if day.washed > 0:
		lines.append(strings.t("washLine", {"n": day.washed}))
	if day.credit_given > 0:
		lines.append(strings.t("creditGivenLine", {"n": day.credit_given}))
	if day.credit_collected > 0:
		lines.append(strings.t("creditCollectedLine", {"n": day.credit_collected}))
	if day.credit_lost > 0:
		lines.append(strings.t("creditLostLine", {"n": day.credit_lost}))
	if not day.ledger.is_empty():
		lines.append(strings.t("ledgerTotalLine", {"n": day.owed_total()}))
	if day.iftar_sold > 0:
		lines.append(strings.t("iftarLine", {"n": day.iftar_sold, "money": day.iftar_sold * int(b.n("tea_stall.iftar_price"))}))
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
		"title": strings.t("dayOver"),
		"stars": day.stars(),
		"sub": strings.t("teaRating", {"stars": "%.1f" % day.stars()}),
		"money": day.money,
		"lines": lines,
		"share": strings.t("share_tea", {"n": day.served, "money": day.money}) if day.served > 0 else "",
	})
	end.home_pressed.connect(_go_home)
	end.again_pressed.connect(_again)
	_layer.add_child(end)


func _again() -> void:
	CrashWatch.start("tea")
	get_tree().reload_current_scene.call_deferred()


func _go_home() -> void:
	CrashWatch.stop()
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")


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


## Passing talk now and then, when nothing else is on the notice line.
func _chat_tick(dt: float) -> void:
	_chat_left -= dt
	if _chat_left > 0.0:
		return
	_chat_left = Chatter.gap()
	if _notice_left > 0.0 or day.customers.is_empty() or _activity != null:
		return
	var line := Chatter.pick("tea_chat", strings.lang)
	if line.is_empty():
		return
	_voice.play(str(line.id))
	_say(str(line.text), Look.SKY_DARK, 4.0)


## The first-day guide: light up what to press next, dim the rest; it goes
## once three orders have been served.
func _show_guide() -> void:
	if _guide and day.served >= 3:
		_guide = false
		_say(strings.t("teaGuideDone"), Look.PARROT_DARK, 3.5)
	var next := day.guide_step() if _guide else ""
	_guide_box.visible = next != ""
	var lit: Array = [_give, _drop]
	lit.append_array(_step_buttons.values())
	for button in lit:
		(button as Control).modulate = Color.WHITE
	if next == "":
		return
	var target: Control = _give if next == "give" else (_drop if next == "discard" else _step_buttons.get(next))
	for button in lit:
		if button != target:
			(button as Control).modulate = Color(1, 1, 1, 0.35)
	if next == "give":
		_guide_label.text = strings.t("teaGuideGive", {"give": strings.t("give")})
	elif next == "discard":
		_guide_label.text = strings.t("teaGuideDiscard", {"discard": strings.t("discard")})
	else:
		_guide_label.text = strings.t("teaGuideNext", {"step": strings.t("step_" + next)})
