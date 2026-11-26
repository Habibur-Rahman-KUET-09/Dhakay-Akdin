## Julekha Khala's fuchka cart by the gate of Monipur school in Mirpur
## (phase 6): the street round the cart in 3D, up to four customers
## standing at it, a card over each with how sour and how hot they want it,
## and the cart's steps along the bottom (crack the puris, fill, sour,
## chilli, doi). A plate goes to whoever's card is tapped. The rules are in
## rules/fuchka_day.gd.
extends Node3D

const RoadMap = preload("res://scripts/rules/road_map.gd")
const FuchkaDay = preload("res://scripts/rules/fuchka_day.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Progress = preload("res://scripts/rules/progress.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Look = preload("res://scripts/ui/look.gd")
const Sfx = preload("res://scripts/ui/sfx.gd")
const Voice = preload("res://scripts/ui/voice.gd")
const Tips = preload("res://scripts/ui/tips.gd")
const Chatter = preload("res://scripts/ui/chatter.gd")
const Music = preload("res://scripts/ui/music.gd")
const Activity = preload("res://scripts/ui/activity.gd")
const Crack = preload("res://scripts/ui/activities/crack.gd")
const Tamarind = preload("res://scripts/ui/activities/tamarind.gd")
const CallAct = preload("res://scripts/ui/activities/call.gd")
const City = preload("res://scripts/world/city.gd")
const Clutter = preload("res://scripts/world/clutter.gd")
const Models = preload("res://scripts/world/models.gd")
const Traffic = preload("res://scripts/world/traffic.gd")
const CrashWatch = preload("res://scripts/ui/crash_watch.gd")
const Graphics = preload("res://scripts/ui/graphics.gd")
const Reveal = preload("res://scripts/world/reveal.gd")
const Neighbours = preload("res://scripts/rules/neighbours.gd")
const DayEnd = preload("res://scripts/ui/day_end.gd")
const Weather = preload("res://scripts/world/weather.gd")
const ReadAloud = preload("res://scripts/ui/read_aloud.gd")
const HomeCall = preload("res://scripts/rules/home_call.gd")

## Where the customers stand, in the cart's own space (in front, -Z).
const STAND_X := [-1.3, -0.45, 0.45, 1.3]
const STAND_Z := -1.15
const CAMERA_AT := Vector3(0, 3.7, -5.4)
const LOOK_AT := Vector3(0, 0.9, 0.2)
const STEP_COLOURS := {
	"puri": Color("C9902E"), "filling": Color("8B5A2B"), "sour": Color("7A4A2A"),
	"chilli": Color("D7263D"), "doi": Color("2D8BD6"),
}

var strings := Strings.new()
var neighbours := Neighbours.new()
var b: Balance
var day: FuchkaDay
var progress: Progress
var camera: Camera3D
var _cart: Node3D
var _palette := PackedColorArray()
var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial
var _env: Environment
var _people: Array[MeshInstance3D] = []
var _cards: Array[PanelContainer] = []
var _card_titles: Array[Label] = []
var _card_wants: Array[Label] = []
var _card_bars: Array[ProgressBar] = []
var _layer: CanvasLayer
var _activity: Activity
var _call_at := -1.0
var _call_rng := RandomNumberGenerator.new()
var _call_result := {}
var _boost := {}
var _status: Label
var _plate: Label
var _cover: Button
var _notice: Label
var _notice_box: PanelContainer
var _notice_left := 0.0
var _ding: AudioStreamPlayer
var _voice: Voice
var _chat_left := Chatter.gap()
var _rain_k := 0.0
var _drops: CPUParticles3D
var _rain_sound: AudioStreamPlayer
var _alive_left := 10.0


func _ready() -> void:
	strings.lang = Strings.saved_lang()
	b = Balance.new()
	progress = Progress.new(b)
	day = FuchkaDay.new(b, -1, progress.data.fuchka.upgrades, progress.date())
	_boost = progress.take_boost("fuchka")
	day.arrival_factor *= float(_boost.get("arrivals", 1.0))
	_call_rng.randomize()
	var call_share := HomeCall.plan(_call_rng, progress.level())
	if call_share >= 0.0:
		_call_at = call_share * day.day_seconds
	var ids := neighbours.ids()
	ids.shuffle()
	day.npc_pool = ids.slice(0, 6)
	day.relations = progress.data.npcs
	set_process(false)
	var loading := _loading_screen()
	await _step("map")
	var map: RoadMap = RoadMap.load_area("mirpur")
	var tile := _cart_tile(map)
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
	await _step("cart")
	_build_cart(map, tile)
	_clear_signs(town)
	await _step("sounds")
	_sounds()
	await _step("hud")
	_build_hud()
	var blocks := town.get_node("Blocks")
	var poles := town.get_node("Poles")
	var first := [town.get_child(0), town.get_child(1)]
	await Reveal.run(self, "fuchka", [
		["sky", []],
		["roads", first],
		["buildings", Reveal.geometry(blocks, false)],
		["poles and wires", Reveal.geometry(poles, false)],
		["town bits", Reveal.geometry(town, false, first + [blocks, poles])],
		["shop signs", Reveal.geometry(town, true)],
		["roadside", Reveal.geometry(clutter, false) + Reveal.geometry(clutter, true)],
		["cart", Reveal.geometry(_cart, false) + Reveal.geometry(_cart, true)],
	])
	CrashWatch.start("fuchka: graphics " + Graphics.level())
	Graphics.apply(get_viewport(), _env, _sun)
	await get_tree().process_frame
	await get_tree().process_frame
	await _step("done")
	loading.queue_free()
	set_process(true)
	if not _boost.is_empty():
		_say(strings.t("boostUsed", {"name": strings.t("boost_" + str(_boost.id))}), Look.SKY, 4.0)
	elif not day.festival.is_empty():
		_say(str(day.festival.greeting.get(strings.lang, day.festival.greeting.en)), Look.MAGENTA, 6.0)
	elif day.winter:
		_say(strings.t("fuchkaWinter"), Look.SKY, 4.0)
	else:
		_say(strings.t("fuchkaStart"), Look.SKY, 4.0)


func _loading_screen() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var bg := ColorRect.new()
	bg.color = Look.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var text := Look.label(strings.t("fuchkaLoading"), 22, true)
	text.set_anchors_preset(Control.PRESET_CENTER)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(text)
	layer.add_child(Tips.card(strings))
	add_child(layer)
	return layer


func _step(what: String) -> void:
	CrashWatch.start("fuchka: " + what)
	print("[fuchka] ", what, " ", Time.get_ticks_msec(), " ms")
	await get_tree().process_frame


## The pavement nearest Monipur school, where Sumi studies.
func _cart_tile(map: RoadMap) -> Vector2i:
	var school := Vector2i(map.width / 2, map.height / 2)
	for p in map.places:
		if p.id == "monipur":
			school = p.at
	var best := Vector2i(-1, -1)
	for p in map.roads():
		# Not where an electric pole stands (every other tile), nor where
		# the pavement has no wall behind it.
		if City._inward(map, p) == Vector3.ZERO or (p.x + p.y) % 2 == 0:
			continue
		if best.x < 0 or Vector2(p).distance_to(Vector2(school)) < Vector2(best).distance_to(Vector2(school)):
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


## The cart on the pavement, its sign, Julekha Khala behind it, the four
## places to stand, and the camera across the street.
func _build_cart(map: RoadMap, tile: Vector2i) -> void:
	var inward := City._inward(map, tile)
	_cart = Node3D.new()
	_cart.name = "Cart"
	_cart.position = City._side(map, tile) - inward * 0.1
	_cart.basis = Basis(Vector3.UP, atan2(inward.x, inward.z))
	add_child(_cart)
	var plain := Models.material()
	var paint := progress.worn("fuchka", "cart")
	var cart := MeshInstance3D.new()
	cart.mesh = Models.fuchka_cart(Color(str(paint.get("body", "1C7C54"))), Color(str(paint.get("trim", "F6B800"))))
	cart.material_override = plain
	_cart.add_child(cart)
	var board := Label3D.new()
	board.text = strings.t("fuchkaSign")
	board.font = Look.font(Look.BOLD)
	board.font_size = 52
	board.outline_size = 12
	board.modulate = Look.YELLOW
	board.outline_modulate = Look.OUTLINE
	board.pixel_size = 0.0042
	board.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	board.position = Vector3(0, 2.95, 0.3)
	board.rotation.y = PI
	_cart.add_child(board)
	# Julekha Khala behind the cart: a green and magenta sari.
	var khala := MeshInstance3D.new()
	khala.mesh = Models.person(1)
	var sari := Models.traffic_material(PackedColorArray([Color("1C7C54"), Color("C2185B")]), false)
	sari.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	khala.material_override = sari
	khala.position = Vector3(-0.2, 0.0, 0.75)
	khala.rotation.y = PI
	_cart.add_child(khala)
	var mesh := Models.person()
	for i in STAND_X.size():
		var p := MeshInstance3D.new()
		p.mesh = mesh if i % Models.PEOPLE == 0 else Models.person(i % Models.PEOPLE)
		p.position = Vector3(STAND_X[i], 0, STAND_Z)
		# Facing the cart (+Z here; the model looks along -Z).
		p.rotation.y = PI
		p.visible = false
		_cart.add_child(p)
		_people.append(p)
	camera = Camera3D.new()
	camera.fov = 66
	camera.near = 0.2
	camera.far = 160
	add_child(camera)
	camera.global_position = _cart.to_global(CAMERA_AT)
	camera.look_at(_cart.to_global(LOOK_AT))
	camera.current = true


## A shop's lettering on the wall right behind the cart would cover the
## cart's own sign: take down the town's lettering close by.
func _clear_signs(town: Node) -> void:
	var near := _cart.global_position
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
	_rain_sound.finished.connect(func():
		if _rain_k > 0.02:
			_rain_sound.play())
	_drops = Weather.rain_drops()
	add_child(_drops)
	_ding = AudioStreamPlayer.new()
	_ding.stream = Sfx.stream("coin")
	_ding.volume_db = -8.0
	add_child(_ding)
	_voice = Voice.new()
	add_child(_voice)
	var tune := Music.new()
	tune.track = "tune_tea" if day.festival.is_empty() else "tune_festival"
	tune.volume_db = -18.0
	add_child(tune)


# --- The screen --------------------------------------------------------------------


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
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
	# A card over each place at the cart: who, how sour and hot, patience.
	for i in STAND_X.size():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", Look.card(Color.WHITE, 10, 2))
		card.custom_minimum_size = Vector2(112, 0)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(col)
		var title := Look.label("", 12, false, Look.OUTLINE.lerp(Color.WHITE, 0.3))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(title)
		var wants := Look.label("", 14, true)
		wants.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(wants)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.custom_minimum_size = Vector2(0, 8)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color("E8E0CF")
		bar_bg.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bar_bg)
		bar.add_theme_stylebox_override("fill", StyleBoxFlat.new())
		col.add_child(bar)
		card.visible = false
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card.bind(i))
		root.add_child(card)
		_cards.append(card)
		_card_titles.append(title)
		_card_wants.append(wants)
		_card_bars.append(bar)
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
	_cover = Look.button(strings.t("fuchkaCover"), Look.SKY_DARK, 16)
	_cover.name = "Cover"
	_cover.pressed.connect(_on_cover)
	_cover.visible = false
	bottom.add_child(_cover)
	var hand := PanelContainer.new()
	hand.add_theme_stylebox_override("panel", Look.card(Color.WHITE, 12, 2))
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 6)
	hand.add_child(hand_row)
	_plate = Look.label("", 15, true)
	_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hand_row.add_child(_plate)
	var drop := Look.button(strings.t("discard"), Look.VERMILION, 14)
	drop.pressed.connect(func():
		day.discard()
		_refresh())
	hand_row.add_child(drop)
	bottom.add_child(hand)
	var grid := GridContainer.new()
	grid.columns = day.steps().size()
	grid.add_theme_constant_override("h_separation", 8)
	for st in day.steps():
		var button := Look.button(strings.t("fstep_" + st), STEP_COLOURS[st], 16)
		button.name = "Step_" + st
		button.custom_minimum_size = Vector2(0, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_step.bind(st))
		grid.add_child(button)
	bottom.add_child(grid)
	_refresh()


func _say(text: String, colour := Look.OUTLINE, seconds := 2.5) -> void:
	ReadAloud.say(text, strings.lang)
	_notice.text = text
	_notice.add_theme_color_override("font_color", colour)
	_notice_box.visible = true
	_notice_left = seconds


func _process(dt: float) -> void:
	_alive_left -= dt
	if _alive_left <= 0.0:
		_alive_left = 10.0
		print("[alive] %d ms, %d fps, nodes %d" % [Time.get_ticks_msec(), Engine.get_frames_per_second(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	var pace := 0.35 if _activity != null and _activity.slow else 1.0
	_handle(day.update(dt * pace))
	_chat_tick(dt)
	if not is_processing():
		return
	# A call from home when the cart is quiet, or after half a minute.
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
	if events.has(FuchkaDay.Event.ARRIVED):
		for c in day.customers:
			if c.kind == "sumi" and not c.has("greeted"):
				c["greeted"] = true
				_say(strings.t("fuchkaSumi"), Look.MAGENTA, 3.5)
		_voice.say("fuchka_order")
	if events.has(FuchkaDay.Event.SERVED):
		var ls: Dictionary = day.last_served
		_ding.play()
		_say(strings.t("fuchkaVerdict_" + str(ls.verdict), {"tip": int(ls.tip)}),
			Look.PARROT if ls.verdict == "exact" else (Look.SKY if ls.verdict == "close" else Look.VERMILION), 2.5)
		_voice.say("fuchka_happy" if ls.verdict != "wrong" else "fuchka_wrong")
	if events.has(FuchkaDay.Event.LEFT):
		_say(strings.t("customerLeft"), Look.VERMILION, 2.5)
		_voice.say("fuchka_left")
	if events.has(FuchkaDay.Event.NOT_READY):
		_say(strings.t("fuchkaNotReady"), Look.VERMILION, 2.0)
	if events.has(FuchkaDay.Event.RAIN_START):
		_say(strings.t("fuchkaRain") if not day.covered else strings.t("fuchkaRainCovered"), Look.SKY, 3.5)
	if events.has(FuchkaDay.Event.DAY_OVER):
		_end_day()


func _on_step(st: String) -> void:
	if _activity != null:
		return
	if Activity.wanted() and st == "puri":
		var act := Crack.new()
		_open(act, "act_crack", func(score: float): _handle(day.step("puri", score)))
		return
	if Activity.wanted() and st == "sour" and day.plate_ready():
		var act := Tamarind.new()
		act.wants = day.customers.map(func(c): return int(c.sour))
		_open(act, "act_tamarind", func(_score: float): _handle(day.step("sour", act.level)))
		return
	_handle(day.step(st))
	_refresh()


func _open(act: Activity, key: String, then: Callable) -> void:
	print("[fuchka] hands: ", key)
	act.setup(strings, key, key + "_hint")
	act.done.connect(then)
	act.tree_exited.connect(func():
		_activity = null
		_refresh())
	_activity = act
	_layer.add_child(act)


func _on_cover() -> void:
	day.cover()
	_say(strings.t("fuchkaCovered"), Look.PARROT, 2.5)
	_refresh()


## A tap on someone's card: hand them the plate.
func _on_card(event: InputEvent, seat: int) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed or not day.plate_ready():
		return
	_handle(day.give_to(seat))
	_refresh()


func _ring_home() -> void:
	var call := HomeCall.new().pick("fuchka", _call_rng, progress.family("fuchka"))
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
	var now := progress.add_family("fuchka", e.family)
	day.money -= e.cost
	_call_result = {"family": now, "delta": e.family}
	if e.family > 0:
		_say(strings.t("familyUp", {"n": now}), Look.PARROT, 3.0)
	elif e.family < 0:
		_say(strings.t("familyDown", {"n": now}), Look.VERMILION, 3.0)
	if e.end_day:
		day.clock = day.day_seconds


## Brings the screen up to date: who stands where and what they want, the
## plate in hand, the clock and the money.
func _refresh() -> void:
	var by_seat := {}
	for c in day.customers:
		by_seat[c.seat] = c
	for i in STAND_X.size():
		var c = by_seat.get(i)
		var person := _people[i]
		var card := _cards[i]
		if c == null:
			person.visible = false
			card.visible = false
			continue
		if not person.visible or person.get_meta("id", -1) != c.id:
			person.set_meta("id", c.id)
			person.material_override = _paint_for(c)
			var small: bool = c.kind == "child" or c.kind == "sumi"
			person.scale = Vector3.ONE * (0.72 if small else 1.0)
		person.visible = true
		card.visible = true
		_card_titles[i].text = strings.t("fkind_" + c.kind) if str(c.get("npc", "")) == "" else neighbours.name_of(c.npc, strings.lang)
		var wants := strings.t("fuchkaWants", {"sour": int(c.sour), "chilli": int(c.chilli)})
		if c.item == "doi_fuchka":
			wants = strings.t("fstep_doi") + " · " + wants
		_card_wants[i].text = wants
		var share: float = clampf(c.left / c.patience, 0.0, 1.0)
		_card_bars[i].value = share
		var fill := StyleBoxFlat.new()
		fill.bg_color = Look.PARROT if share > 0.5 else (Look.YELLOW if share > 0.25 else Look.VERMILION)
		fill.set_corner_radius_all(4)
		_card_bars[i].add_theme_stylebox_override("fill", fill)
		var head := _cart.to_global(Vector3(STAND_X[i], 1.95, STAND_Z - 0.2))
		var at := camera.unproject_position(head)
		card.position = at - Vector2(card.size.x / 2.0, card.size.y)
	if day.plate.is_empty():
		_plate.text = strings.t("fuchkaPlateEmpty")
	else:
		var p := day.plate
		var parts := PackedStringArray([strings.t("fuchkaPlatePuri")])
		if p.filled:
			parts.append(strings.t("fstep_filling"))
		parts.append(strings.t("fuchkaWants", {"sour": int(p.sour), "chilli": int(p.chilli)}))
		if p.doi:
			parts.append(strings.t("fstep_doi"))
		_plate.text = " · ".join(parts)
	_cover.visible = day.raining and not day.covered
	_status.text = "%s\n%s" % [_clock_text(), strings.t("taka", {"n": day.money})]


func _paint_for(c: Dictionary) -> ShaderMaterial:
	var paint: ShaderMaterial
	match str(c.kind):
		"sumi":
			# Sumi in her school uniform: white and blue.
			paint = Models.traffic_material(PackedColorArray([Color("F4F1E8"), Color("1F4F8B")]), false)
		"office":
			paint = Models.traffic_material(PackedColorArray([Color("F2F2F2"), Color("2B2B2B")]), false)
		"student":
			paint = Models.traffic_material(PackedColorArray([Color("C2185B"), Color("2D8BD6")]), false)
		_:
			paint = Models.traffic_material(PackedColorArray([_palette[c.id % 8], _palette[8 + (c.id * 3) % 8]]), false)
	paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	return paint


func _clock_text() -> String:
	var hour := day.hour()
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	var part := "afternoon"
	if h >= 20:
		part = "night"
	elif h >= 18:
		part = "evening"
	elif h < 15:
		part = "noon"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return strings.t("clock", {"part": strings.t(part), "h": h12, "m": "%02d" % m})


func _weather(dt: float) -> void:
	_rain_k = move_toward(_rain_k, 1.0 if day.raining else 0.0, dt / 4.0)
	_drops.emitting = _rain_k > 0.3 and day.raining
	_drops.position = camera.global_position + (_cart.global_position - camera.global_position).normalized() * 4.0 + Vector3(0, 6.0, 0)
	_rain_sound.volume_db = linear_to_db(maxf(_rain_k, 0.001)) - 4.0
	if _rain_k > 0.02 and not _rain_sound.playing:
		_rain_sound.play()


## Afternoon into night: the light follows the clock (13:00 to 21:00).
func _light() -> void:
	var h := day.hour()
	var noon := clampf(1.0 - absf(h - 13.0) / 5.0, 0.0, 1.0)
	var dusk := clampf((h - 16.5) / 2.5, 0.0, 1.0)
	var night := clampf((h - 18.5) / 1.5, 0.0, 1.0)
	_sun.light_color = Color("FFF6E6").lerp(Color("FF9A4D"), dusk).lerp(Color("8FA3D6"), night)
	_sun.light_energy = lerpf(0.7, 0.95, noon) * lerpf(1.0, 0.35, night)
	_sun.rotation_degrees.x = -lerpf(18.0, 60.0, noon)
	_env.ambient_light_energy = lerpf(0.35, 0.22, night)
	_sky.sky_top_color = Color("9DB4C6").lerp(Color("C9876A"), dusk).lerp(Color("1E2A44"), night)
	_sky.sky_horizon_color = Color("E2DED2").lerp(Color("F0B27A"), dusk).lerp(Color("3A4566"), night)
	_env.fog_light_color = Color("D8D5C8").lerp(Color("E5B48C"), dusk).lerp(Color("2E3650"), night)
	if _rain_k > 0.0:
		_sun.light_energy *= lerpf(1.0, 0.3, _rain_k)
		_sky.sky_top_color = _sky.sky_top_color.lerp(Color("6E7882"), _rain_k * 0.8)
		_env.fog_light_color = _env.fog_light_color.lerp(Color("8F979E"), _rain_k * 0.8)
	_env.fog_density = lerpf(0.006, 0.025, _rain_k)


func _end_day() -> void:
	set_process(false)
	_rain_sound.stop()
	_drops.emitting = false
	var stats := {"happy": day.happy, "exact": day.exact, "earned": day.money}
	var result := {"earned": day.money, "served": day.served, "happy": day.happy, "exact": day.exact, "lost": day.lost,
		"stars": day.stars(), "stats": stats, "npcs": day.npc_log}
	var got := progress.apply_fuchka_day(result)
	progress.save()
	load("res://scripts/ui/cloud.gd").backup(self, progress.data)
	CrashWatch.stop()
	var lines: Array = [
		strings.t("fuchkaServed", {"served": day.served, "happy": day.happy}),
		strings.t("fuchkaExact", {"n": day.exact}),
	]
	if day.lost > 0:
		lines.append(strings.t("teaLost", {"n": day.lost}))
	if day.tips > 0:
		lines.append(strings.t("teaTips", {"n": day.tips}))
	if not _call_result.is_empty():
		lines.append(strings.t("familyLine", {"n": _call_result.family}))
	if int(got.get("samity_payout", 0)) > 0:
		lines.append(strings.t("samityPayoutLine", {"n": int(got.samity_payout)}))
	elif int(got.get("samity_paid", 0)) > 0:
		lines.append(strings.t("samityDayLine", {"n": int(got.samity_paid)}))
	var end := DayEnd.new()
	end.setup(strings, b, progress, got, {
		"title": strings.t("dayOver"),
		"stars": day.stars(),
		"sub": strings.t("teaRating", {"stars": "%.1f" % day.stars()}),
		"money": day.money,
		"lines": lines,
		"share": strings.t("share_fuchka", {"n": day.served, "money": day.money}) if day.served > 0 else "",
	})
	end.home_pressed.connect(_go_home)
	end.again_pressed.connect(func():
		CrashWatch.start("fuchka")
		get_tree().reload_current_scene.call_deferred())
	_layer.add_child(end)


func _go_home() -> void:
	CrashWatch.stop()
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")


## Passing talk now and then, when nothing else is on the notice line.
func _chat_tick(dt: float) -> void:
	_chat_left -= dt
	if _chat_left > 0.0:
		return
	_chat_left = Chatter.gap()
	if _notice_left > 0.0 or day.customers.is_empty() or _activity != null:
		return
	var line := Chatter.pick("fuchka_chat", strings.lang)
	if line.is_empty():
		return
	_voice.play(str(line.id))
	_say(str(line.text), Look.SKY_DARK, 4.0)
