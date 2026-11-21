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
const Strings = preload("res://scripts/ui/strings.gd")
const Look = preload("res://scripts/ui/look.gd")
const City = preload("res://scripts/world/city.gd")
const Clutter = preload("res://scripts/world/clutter.gd")
const Models = preload("res://scripts/world/models.gd")
const Traffic = preload("res://scripts/world/traffic.gd")
const CrashWatch = preload("res://scripts/ui/crash_watch.gd")

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
}

var strings := Strings.new()
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
var _rahim_rickshaw: Node3D
var _layer: CanvasLayer
var _status: Label
var _tray: Label
var _give: Button
var _kettle_button: Button
var _notice: Label
var _notice_box: PanelContainer
var _notice_left := 0.0
var _ding: AudioStreamPlayer
var _alive_left := 10.0


func _ready() -> void:
	strings.lang = Strings.saved_lang()
	b = Balance.new()
	progress = Progress.new(b)
	day = TeaDay.new(b)
	set_process(false)
	var loading := _loading_screen()
	await _step("map")
	var map: RoadMap = RoadMap.load_area("mirpur")
	var tile := _stall_tile(map)
	await _step("environment")
	_environment()
	await _step("town")
	add_child(City.build(map, strings.lang, tile))
	await _step("clutter")
	for hex in Traffic.PALETTE:
		_palette.append(Color(hex))
	add_child(Clutter.build(map, _palette))
	await _step("stall")
	_build_stall(map, tile)
	await _step("sounds")
	_sounds()
	await _step("hud")
	_build_hud()
	await _step("done")
	loading.queue_free()
	set_process(true)


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
	env.fog_density = 0.014
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.06
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
	board.pixel_size = 0.008
	board.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	board.position = Vector3(0, 2.95, -0.8)
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


func _sounds() -> void:
	var hum := AudioStreamPlayer.new()
	hum.stream = load("res://sounds/hum.wav")
	hum.volume_db = -12.0
	add_child(hum)
	hum.finished.connect(hum.play)
	hum.play()
	_ding = AudioStreamPlayer.new()
	_ding.stream = load("res://sounds/bell.wav")
	_ding.volume_db = -8.0
	add_child(_ding)


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
	_give = Look.button(strings.t("give"), Look.PARROT, 16)
	_give.pressed.connect(_on_give)
	hand_row.add_child(_give)
	var drop := Look.button(strings.t("discard"), Look.VERMILION, 14)
	drop.pressed.connect(_on_discard)
	hand_row.add_child(drop)
	bottom.add_child(hand)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for step in TeaDay.STEPS:
		var button := Look.button(strings.t("step_" + step), STEP_COLOURS[step], 17)
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_step.bind(step))
		grid.add_child(button)
		if step == "kettle":
			_kettle_button = button
	bottom.add_child(grid)
	_refresh()


func _say(text: String, colour := Look.OUTLINE, seconds := 2.5) -> void:
	_notice.text = text
	_notice.add_theme_color_override("font_color", colour)
	_notice_box.visible = true
	_notice_left = seconds


func _process(dt: float) -> void:
	_alive_left -= dt
	if _alive_left <= 0.0:
		_alive_left = 10.0
		print("[alive] ", Time.get_ticks_msec(), " ms, ", Engine.get_frames_per_second(), " fps")
	var events := day.update(dt)
	_handle(events)
	if not is_processing():
		return
	if _notice_left > 0.0:
		_notice_left -= dt
		if _notice_left <= 0.0:
			_notice_box.visible = false
	_light()
	_refresh()


func _handle(events: Array) -> void:
	if events.has(TeaDay.Event.ARRIVED):
		for c in day.customers:
			if c.kind == "rahim" and not _seated.has(c.id):
				_say(strings.t("rahimArrived"), Look.MAGENTA, 3.0)
	if events.has(TeaDay.Event.SERVED):
		var last: Dictionary = day.last_served
		if last.kind == "rahim":
			_say(_rahim_line(), Look.MAGENTA, 5.0)
		elif last.happy:
			_say(strings.t("servedHappy", {"bill": last.bill, "tip": last.tip}), Look.PARROT)
		else:
			_say(strings.t("servedPlain", {"bill": last.bill}), Look.OUTLINE)
		_ding.play()
	if events.has(TeaDay.Event.LEFT):
		_say(strings.t("customerLeft"), Look.VERMILION)
	if events.has(TeaDay.Event.WRONG_STEP):
		_say(strings.t("wrongStep"), Look.VERMILION, 2.0)
	if events.has(TeaDay.Event.NOBODY_WANTS):
		_say(strings.t("nobodyWants"), Look.VERMILION, 2.0)
	if events.has(TeaDay.Event.KETTLE_EMPTY):
		_say(strings.t("kettleEmptyNote"), Look.YELLOW.darkened(0.3), 3.0)
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
	if not is_processing():
		return
	_handle(day.tap(step))
	_refresh()


func _on_give() -> void:
	_handle(day.give())
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
		_card_titles[i].text = strings.t("kind_" + c.kind)
		var names := PackedStringArray()
		for it in c.items:
			names.append(strings.t("item_" + it))
		_card_items[i].text = "\n".join(names)
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
	if day.refill_left > 0.0:
		_kettle_button.text = strings.t("kettleFilling")
	elif day.kettle <= 0:
		_kettle_button.text = strings.t("kettleEmpty")
	else:
		_kettle_button.text = strings.t("kettleCups", {"n": day.kettle})
	_status.text = "%s\n%s" % [_clock_text(), strings.t("taka", {"n": day.money})]


## Shirt and trousers from the street's colours; Rahim Chacha in his own.
func _sitter_paint(c: Dictionary) -> ShaderMaterial:
	var paint: ShaderMaterial
	if c.kind == "rahim":
		paint = Models.traffic_material(PackedColorArray([Color("3A6EA5"), Color("4E4A44")]), false)
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


func _end_day() -> void:
	set_process(false)
	var result := {"earned": day.money, "served": day.served, "happy": day.happy, "lost": day.lost, "stars": day.stars()}
	var got := progress.apply_tea_day(result)
	progress.save()
	CrashWatch.stop()
	var lines := [
		strings.t("earned", {"money": day.money}),
		strings.t("teaSold", {"n": day.sold}),
		strings.t("teaServed", {"served": day.served, "happy": day.happy}),
	]
	if day.lost > 0:
		lines.append(strings.t("teaLost", {"n": day.lost}))
	if day.tips > 0:
		lines.append(strings.t("teaTips", {"n": day.tips}))
	lines.append(strings.t("teaRating", {"stars": "%.1f" % day.stars()}))
	lines.append(strings.t("teaKept", {"n": got.kept}))
	lines.append(strings.t("gainFund", {"n": got.fund}))
	lines.append(strings.t("gainXp", {"n": got.xp}))
	if got.level_up:
		lines.append(strings.t("levelUp", {"level": progress.level()}))
	if got.best:
		lines.append(strings.t("newBest"))
	if got.project != "":
		lines.append(strings.t("projectFinished", {"project": strings.t("project_" + got.project)}))
	_show_day_end(lines)


func _show_day_end(lines: Array) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(Look.CREAM, 18, 3))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(400, 0)
	shade.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var title := Look.label(strings.t("dayOver"), 28, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	for line in lines:
		var l := Look.label(line, 17)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var again := Look.button(strings.t("nextDay"), Look.MAGENTA, 18)
	again.pressed.connect(_again)
	row.add_child(again)
	var home := Look.button(strings.t("toMohalla"), Look.PARROT, 18)
	home.pressed.connect(_go_home)
	row.add_child(home)
	col.add_child(row)


func _again() -> void:
	CrashWatch.start("tea")
	get_tree().reload_current_scene()


func _go_home() -> void:
	CrashWatch.stop()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
