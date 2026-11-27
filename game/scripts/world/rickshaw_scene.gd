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
const Sfx = preload("res://scripts/ui/sfx.gd")
const Voice = preload("res://scripts/ui/voice.gd")
const Photo = preload("res://scripts/ui/photo.gd")
const Juice = preload("res://scripts/ui/juice.gd")
const Tips = preload("res://scripts/ui/tips.gd")
const Chatter = preload("res://scripts/ui/chatter.gd")
const City = preload("res://scripts/world/city.gd")
const Models = preload("res://scripts/world/models.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const Traffic = preload("res://scripts/world/traffic.gd")
const Music = preload("res://scripts/ui/music.gd")
const Activity = preload("res://scripts/ui/activity.gd")
const Haggle = preload("res://scripts/ui/activities/haggle.gd")
const Pump = preload("res://scripts/ui/activities/pump.gd")
const Push = preload("res://scripts/ui/activities/push.gd")
const Hood = preload("res://scripts/ui/activities/hood.gd")
const Sms = preload("res://scripts/ui/activities/sms.gd")
const CallAct = preload("res://scripts/ui/activities/call.gd")
const ChainAct = preload("res://scripts/ui/activities/chain.gd")
const LostAct = preload("res://scripts/ui/activities/lost.gd")
const HomeCall = preload("res://scripts/rules/home_call.gd")
const Clutter = preload("res://scripts/world/clutter.gd")
const CrashWatch = preload("res://scripts/ui/crash_watch.gd")
const SignalLights = preload("res://scripts/world/signal_lights.gd")
const Progress = preload("res://scripts/rules/progress.gd")
const Friends = preload("res://scripts/rules/friends.gd")
const League = preload("res://scripts/rules/league.gd")
const Race = preload("res://scripts/rules/race.gd")
const Online = preload("res://scripts/rules/online.gd")
const Cloud = preload("res://scripts/ui/cloud.gd")
const Delivery = preload("res://scripts/rules/delivery.gd")
const Choose = preload("res://scripts/ui/activities/choose.gd")
const Neighbours = preload("res://scripts/rules/neighbours.gd")
const DayLines = preload("res://scripts/ui/day_lines.gd")
const DayEnd = preload("res://scripts/ui/day_end.gd")
const Graphics = preload("res://scripts/ui/graphics.gd")
const Reveal = preload("res://scripts/world/reveal.gd")
const Weather = preload("res://scripts/world/weather.gd")
const Driving = preload("res://scripts/ui/driving.gd")
const ReadAloud = preload("res://scripts/ui/read_aloud.gd")

const SWIPE_PX := 36.0
## The camera rides just behind and above the rickshaw, at street level.
const CAMERA_BACK := 6.2
const CAMERA_UP := 3.9
## Bangladesh drives on the left.
const KEEP_LEFT := 1.0

var strings := Strings.new()
var neighbours := Neighbours.new()
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
var _rider_paint: ShaderMaterial
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
## When each finger went down on the pedal: a quick tap starts (or stops)
## the cruise, a hold pedals only while held.
var _pedal_down_at := {}
## The way on (shift.next_turn), worked out again only when the rickshaw
## moves to another tile or the destination changes.
## A call from home today: when (on the day's clock; -1 when none, or
## once it has rung), and how it went, for the day's end.
var _call_at := -1.0
var _call_rng := RandomNumberGenerator.new()
## Energy from friends today: cups of tea they sent, the relay day.
var _friend_energy := 0.0
var _relay_energy := 0.0
var _call_result := {}
var _story_effect := {}
var _boost := {}
var _way := {"turn": -1, "tiles": -1}
var _way_key := []
var _said_way := []
var _key_brake := false
var _frames_logged := 0
## The traffic policeman who stops a wrong-way rickshaw, and his whistle.
var _police: Node3D
var _police_left := 0.0
var _whistle: AudioStreamPlayer
## Coins for a fare paid.
var _coin: AudioStreamPlayer
## The hand activity open, if any (haggling, the pump, pushing).
var _activity: Activity
var _league_decked := false
## Today's race (race.gd): on, the ride's points so far, the ghost to
## race and its points, the race's own clock.
var _race := false
## Whose day this is: Rahim Chacha's rickshaw, or Ratul's deliveries on
## his bicycle (scenes/delivery.tscn) through the same streets.
@export var mode := "rickshaw"
var _delivery = null
var _path := PackedVector2Array()
var _path_left := 0.0
var _ghost := {}
var _ghost_points := PackedVector2Array()
var _ghost_node: Node3D
var _race_clock := 0.0
## A live race (online.gd): the room ({} when not), the cloud, the
## others' rickshaws {uid: {node, points, name, done, time}}.
var _live := {}
var _live_cloud: Cloud
var _live_ghosts := {}
var _live_poll := 0.0
var _live_busy := false
## Activities that came while another was open, opened after it.
var _queued: Array[Callable] = []
## Passengers, the policeman and Rahim Chacha talking.
var _voice: Voice
var _chat_left := Chatter.gap()
var _first_told := false
## The passenger last told about (stop beside them), and the time to the
## next reminder to drink tea.
var _stop_hinted := {}
var _nag_left := 0.0
## Rain: how hard (0–1, eased), the drops, the sound, the water that
## spreads on the roads.
var _rain_k := 0.0
var _drops: CPUParticles3D
var _rain_sound: AudioStreamPlayer
var _rain_water: MeshInstance3D


func _ready() -> void:
	strings.lang = Strings.saved_lang()
	var b := Balance.new()
	# What carries over from earlier days: a faster rickshaw, for one, and
	# where he rides (Mirpur, or Old Dhaka once the mohalla is level 5).
	progress = Progress.new(b)
	# A live race in a room: the host's area and the room's route.
	if mode == "rickshaw" and Online.active() and str(Online.room.kind) == "race":
		_live = Online.room.duplicate(true)
		Online.room = {}
		Race.next = true
	var area := progress.rickshaw_area() if _live.is_empty() else str(_live.area)
	var map: RoadMap = RoadMap.load_area("mirpur" if mode == "delivery" else area)
	# The date brings the month's weather and any festival.
	# Shorter rides in the first days, the full length later.
	shift = Day.new(map, b, -1, progress.date(), Day.trip_for_level(progress.level()))
	shift.interactive = Activity.wanted()
	shift.follow_route = Driving.easy()
	shift.easy = Driving.easy()
	shift.level = progress.level()
	# Today's race instead of a working day, when chosen at home.
	_race = Race.next and mode == "rickshaw"
	Race.next = false
	var route_key := progress.date() if _live.is_empty() else str(_live.seed)
	var route := Race.route(map, route_key, int(b.n("race.low_tiles")), int(b.n("race.high_tiles"))) if _race else {}
	_race = not route.is_empty()
	if _race:
		# No passengers, no calls, no boosts used up: just the ride.
		shift.start_race(route)
		shift.base_speed *= progress.speed_factor()
	elif mode == "delivery":
		_setup_delivery(b)
	else:
		# A chapter's mark on the next days: a rented old rickshaw, shorter
		# days with Rokeya ill, more to earn for the flooded village.
		_story_effect = progress.story_effect("rickshaw")
		shift.day_seconds *= float(_story_effect.get("day_share", 1.0))
		# The night shift: ten to two, fewer about, higher fares.
		if mode == "night":
			shift.start_night()
			shift.lamp = progress.has_upgrade("battery_rickshaw")
		_call_rng.randomize()
		var call_share := HomeCall.plan(_call_rng, progress.level())
		if call_share >= 0.0:
			_call_at = call_share * shift.day_seconds
		_target_money = progress.rickshaw_target() + int(_story_effect.get("target", 0))
		shift.base_speed *= progress.speed_factor() * float(_story_effect.get("speed", 1.0))
		shift.energy_factor = progress.energy_factor()
		# Resting better at home (a bed, a fan): more energy to start with.
		shift.energy_max += progress.home_energy()
		# Cups of tea friends sent, and a friend's good morning at the stall
		# (the relay day): more energy too.
		_friend_energy = Friends.drink_tea(progress.data, b)
		_relay_energy = Friends.relay_energy(progress.data, b, progress.date())
		shift.energy_max += _friend_energy + _relay_energy
		# A good meal bought with stars.
		_boost = progress.take_boost("rickshaw")
		shift.energy_max += float(_boost.get("energy", 0))
		shift.energy = shift.energy_max
		# A few of the named neighbours may need a ride today.
		var ids := neighbours.ids()
		ids.shuffle()
		shift.npc_pool = ids.slice(0, 6)
		shift.relations = progress.data.npcs
	# Built a step per frame behind a loading screen, so a slow phone keeps
	# responding, and the log shows which step a crash happened in.
	set_process(false)
	var loading := _loading_screen()
	await _step("environment")
	_environment()
	await _step("town")
	# Friends' tea stalls in town: passengers may ask for them.
	shift.friend_places = Friends.shop_places(progress.data, map, strings.both("friendStall"))
	# Last week's league won here: the streets decked out, as for a festival.
	var decor: Dictionary = shift.festival
	_league_decked = decor.is_empty() and League.decked(progress.data, map.id, progress.date())
	if _league_decked:
		decor = {"name": strings.both("leagueBanner"), "colours": ["C2185B", "F6B800", "2E9E6B", "2D8BD6"]}
	var town := City.build(map, strings.lang, Vector2i(-1, -1), decor)
	add_child(town)
	for pl in shift.friend_places:
		add_child(_friend_stall(map, pl))
	if _delivery != null:
		add_child(_kitchen_signs())
	for g in shift.guards:
		add_child(_night_guard(map, g))
	await _step("clutter")
	for hex in Traffic.PALETTE:
		_palette.append(Color(hex))
	var clutter := Clutter.build(map, _palette)
	add_child(clutter)
	signals = SignalLights.new()
	add_child(signals)
	signals.setup(map)
	await _step("traffic")
	traffic = Traffic.new()
	add_child(traffic)
	var counts := Traffic.counts_for(map.id)
	# Easy driving: fewer vehicles on the roads, so fewer jams.
	if shift.easy:
		for k in counts:
			counts[k] = int(counts[k] * b.n("rickshaw.easy_traffic"))
	traffic.setup(map, map.home, counts)
	traffic.focus = shift.driver
	traffic.signal_cycle = shift.signal_cycle
	_person_mesh = Models.person()
	await _step("sounds")
	_sounds()
	await _step("rickshaw and hud")
	# Rahim Chacha's own rickshaw: yellow hood, magenta body.
	# The street's colours too, for the decorations (hood 0, body 1).
	# The festive hood (seven days running) is the studded one.
	# Bought looks: another paint, or hood art.
	var hood_style := 1 if (progress.data.cosmetics as Array).has("festive_hood") else 0
	var hood_colour := Look.YELLOW
	var body_colour := Look.MAGENTA
	var paint := progress.worn("rickshaw", "paint")
	if not paint.is_empty():
		hood_colour = Color(str(paint.hood))
		body_colour = Color(str(paint.body))
	var art := progress.worn("rickshaw", "art")
	if not art.is_empty():
		hood_style = int(art.style)
	if mode == "delivery":
		# Ratul's bicycle: the food box (hood's colour) and the frame.
		hood_colour = Color("F26B1D")
		body_colour = Color("1E6FB0")
		var cycle := progress.worn("delivery", "cycle")
		if not cycle.is_empty():
			hood_colour = Color(str(cycle.box))
			body_colour = Color(str(cycle.frame))
		rickshaw = Models.player_bicycle(hood_colour, body_colour)
	else:
		rickshaw = Models.player_rickshaw(hood_colour, body_colour, hood_style)
	var own := _palette.duplicate()
	own[0] = hood_colour
	own[1] = body_colour
	_paint = Models.traffic_material(own, false)
	(rickshaw.get_meta("body") as MeshInstance3D).material_override = _paint
	if rickshaw.has_meta("rider"):
		# Rahim Chacha's clothes: an orange shirt and a blue lungi, or a
		# bought outfit.
		var outfit := progress.worn("rickshaw", "outfit")
		_rider_paint = Models.traffic_material(PackedColorArray([Color(str(outfit.get("shirt", "E8892B"))), Color(str(outfit.get("lower", "2D5D8A")))]), false)
		(rickshaw.get_meta("rider") as MeshInstance3D).material_override = _rider_paint
	var plain := Models.material()
	for w in rickshaw.get_meta("wheels"):
		(w as MeshInstance3D).material_override = plain
	if mode != "delivery":
		_back_art(rickshaw)
	# A passenger on the seat, shown during a trip.
	_rider_seat = MeshInstance3D.new()
	_rider_seat.mesh = Models.seated_passenger()
	var seat_paint := Models.traffic_material(PackedColorArray([Color("1C4E9B"), Color("37474F")]), false)
	seat_paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	_rider_seat.material_override = seat_paint
	_rider_seat.visible = false
	rickshaw.add_child(_rider_seat)
	add_child(rickshaw)
	if shift.night:
		# The rickshaw's lamp lights the road ahead.
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(0, 1.0, -1.3)
		lamp.rotation_degrees = Vector3(-12, 0, 0)
		lamp.light_energy = 3.0 if shift.lamp else 1.8
		lamp.spot_range = 16.0
		lamp.spot_angle = 32.0
		lamp.light_color = Color("FFF1C9")
		rickshaw.add_child(lamp)
	if _race and not _live.is_empty():
		_setup_live()
	elif _race:
		_setup_ghost()
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
	hud.pump_pressed.connect(_on_pump)
	hud.hood_down_pressed.connect(_on_hood_down)
	hud.switch_pressed.connect(_on_switch)
	add_child(hud)
	# Photo mode: the street as it is, in a frame, to share.
	var cam := Photo.button(self, hud, strings, progress.data.get("frames", []))
	cam.position = Vector2(10, 84)
	hud.add_child(cam)
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
	# The town a part at a time, so a crash while drawing names the part.
	var blocks := town.get_node("Blocks")
	var poles := town.get_node("Poles")
	var first := [town.get_child(0), town.get_child(1)]
	var people := []
	for n in _waiting_nodes.values():
		people += Reveal.geometry(n, false) + Reveal.geometry(n, true)
	await Reveal.run(self, "rickshaw", [
		["sky", []],
		["roads", first],
		["buildings", Reveal.geometry(blocks, false)],
		["poles and wires", Reveal.geometry(poles, false)],
		["town bits", Reveal.geometry(town, false, first + [blocks, poles])],
		["shop signs", Reveal.geometry(town, true)],
		["roadside", Reveal.geometry(clutter, false)],
		["billboards", Reveal.geometry(clutter, true)],
		["signals", Reveal.geometry(signals, false) + Reveal.geometry(signals, true)],
		["traffic", Reveal.geometry(traffic, false)],
		["rickshaw", Reveal.geometry(rickshaw, false) + Reveal.geometry(marker, false) + Reveal.geometry(marker, true)],
		["passengers", people],
	])
	CrashWatch.start("rickshaw: graphics " + Graphics.level())
	Graphics.apply(get_viewport(), _env, _sun)
	await get_tree().process_frame
	await get_tree().process_frame
	await _step("done")
	loading.queue_free()
	set_process(true)
	if _delivery != null:
		_say(strings.t("deliveryStart"), Look.VERMILION, 5.0)
	elif shift.night:
		_say(strings.t("nightStart"), Look.SKY, 6.0)
	elif _race:
		var line := strings.t("raceStart", {"place": RoadMap.place_name(shift.race_to, strings.lang)})
		if not _ghost.is_empty():
			line += "\n" + (strings.t("ghostFriend", {"name": str(_ghost.name), "s": "%.1f" % float(_ghost.time)}) if _ghost.friend else strings.t("ghostMine", {"s": "%.1f" % float(_ghost.time)}))
		_say(line, Look.MAGENTA, 6.0)
	elif not _story_effect.is_empty():
		_say(strings.t("after_" + str(_story_effect.note), {"n": int(_story_effect.left)}), Look.MAGENTA, 6.0)
	elif not _boost.is_empty():
		_say(strings.t("boostUsed", {"name": strings.t("boost_" + str(_boost.id))}), Look.SKY, 4.0)
	elif not shift.festival.is_empty():
		_say(str(shift.festival.greeting.get(strings.lang, shift.festival.greeting.en)), Look.MAGENTA, 6.0)
	elif _league_decked:
		_say(strings.t("leagueDecked", {"area": strings.t("area_" + str(progress.rickshaw_area()))}), Look.MAGENTA, 5.0)
	elif not shift.friend_places.is_empty():
		_say(strings.t("friendStallsHere", {"n": shift.friend_places.size()}), Look.SKY, 4.0)
	elif shift.foggy:
		_say(strings.t("fogMorning"), Look.SKY, 4.0)
	elif shift.ramadan:
		_say(strings.t("ramadanDay"), Look.SKY, 5.0)
	elif progress.level() <= 3:
		_say(strings.t("cruiseTip"), Look.SKY, 6.0)


## The bell, horn players for passing traffic, the road's hum: WAV files
## made by tool/make_sounds.py and imported like any recording. The hum is
## replayed when it ends rather than looped.
func _sounds() -> void:
	print("[sounds] bell")
	_bell = AudioStreamPlayer.new()
	_bell.stream = Sfx.stream("bell")
	add_child(_bell)
	print("[sounds] hum")
	var hum := AudioStreamPlayer.new()
	hum.stream = Sfx.stream("hum")
	hum.volume_db = -10.0
	add_child(hum)
	hum.finished.connect(_hum_again.bind(hum))
	hum.play()
	print("[sounds] horns")
	var bell: AudioStream = _bell.stream
	_horn_sounds = {
		"cng": Sfx.stream("horn_cng"),
		"bus": Sfx.stream("horn_bus"),
		"rickshaw": bell,
		"rickshaw_full": bell,
	}
	for i in 3:
		var h := AudioStreamPlayer.new()
		add_child(h)
		_horns.append(h)
	_whistle = AudioStreamPlayer.new()
	_whistle.stream = Sfx.stream("whistle")
	add_child(_whistle)
	_rain_sound = AudioStreamPlayer.new()
	_rain_sound.stream = Sfx.stream("rain")
	_rain_sound.volume_db = -60.0
	add_child(_rain_sound)
	_rain_sound.finished.connect(_rain_again)
	_coin = AudioStreamPlayer.new()
	_coin.stream = Sfx.stream("coin")
	_coin.volume_db = -4.0
	add_child(_coin)
	_voice = Voice.new()
	add_child(_voice)
	# Music softly under the street: the rickshaw's tune, or a festival's.
	var tune := Music.new()
	tune.track = "tune_rickshaw" if shift.festival.is_empty() else "tune_festival"
	tune.volume_db = -18.0
	add_child(tune)


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
	layer.add_child(Tips.card(strings))
	add_child(layer)
	return layer


## Lets a frame pass and notes the next step in the log.
func _step(what: String) -> void:
	CrashWatch.start("rickshaw: " + what)
	print("[rickshaw] ", what, " ", Time.get_ticks_msec(), " ms, ", int(OS.get_static_memory_usage() / 1048576), " MB")
	await get_tree().process_frame


func _go_home() -> void:
	CrashWatch.stop()
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")


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
	env.fog_density = 0.008
	# A little more colour and contrast than the camera sees, and a soft
	# glow round the brightest things (signals, the sky, lamps at night).
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.1
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
	Graphics.plain(get_viewport(), env, sun)


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
	# The first frames, in the log: a crash while drawing shows here.
	if _frames_logged < 5:
		_frames_logged += 1
		print("[frame] ", _frames_logged, " ", Time.get_ticks_msec(), " ms")
	# A line in the log every 10 s, with the frame rate, for crash reports.
	_alive_left -= dt
	if _alive_left <= 0.0:
		_alive_left = 10.0
		print("[alive] %d ms, %d fps, mem %.0f MB, video %.0f MB, nodes %d, objects %d" % [Time.get_ticks_msec(), Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT)])
	var gap := traffic.gap_ahead(shift.driver)
	shift.room = clampf((gap - 0.12) / 0.5, 0.0, 1.0)
	# Someone crossing the junction ahead: wait for them (a little while).
	if shift.driver.progress > 0.45 and traffic.crossing_blocked(shift.driver):
		_crossing_wait += dt
		if _crossing_wait < Traffic.CROSSING_PATIENCE:
			shift.room = 0.0
	else:
		_crossing_wait = 0.0
	# A hand activity open: the street goes slower meanwhile.
	var pace := 0.35 if _activity != null and _activity.slow else 1.0
	var events := shift.update(dt * pace)
	traffic.clock = shift.clock
	signals.update_lights(shift.clock, shift.signal_cycle)
	_day_light()
	_handle(events)
	if not is_processing():
		return
	if _race:
		_race_tick(dt * pace)
	if not _live.is_empty():
		_live_tick(dt)
	hud.show_hood_down(shift.interactive and shift.hood_up and not shift.raining)
	# A call from home comes when he is standing still (a signal, a jam),
	# or after half a minute's wait for that.
	if _call_at >= 0.0 and shift.clock >= _call_at and _activity == null \
			and (shift.speed_now < 0.05 or shift.clock >= _call_at + 30.0):
		_call_at = -1.0
		_ring_home()
	if events.has(Driver.Event.WRONG_WAY) and not events.has(Day.POLICE):
		_say(strings.t("rickshawWrongWay"), Look.VERMILION)
	if events.has(Driver.Event.WAITING):
		_say(strings.t("rickshawWhichWay"), Look.SKY, INF)
	if _notice != "":
		_notice_left -= dt
		if _notice_left <= 0.0 or (_notice_left > 1e6 and shift.driver.moving):
			_notice = ""
	_chat_tick(dt)
	_stop_hint()
	_tired_nag(dt)
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
	if text != _notice:
		ReadAloud.say(text, strings.lang)
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
	var pedalling := (shift.pedal or shift.cruise) and d.moving
	_paint.set_shader_parameter("custom_data", Vector4(0.0, 1.0 if pedalling else 0.0, 0.0, 1.0))
	if _rider_paint != null:
		_rider_paint.set_shader_parameter("custom_data", Vector4(0.0, 1.0 if pedalling else 0.0, 0.0, 1.0))
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
	_update_way()
	# The arrow shows the way on: the next turn when it is close, else
	# straight ahead (clockwise, as grid y grows down the screen). With no
	# legal way, it points at the destination as the crow flies.
	var angle := 0.0
	if _way.tiles < 0:
		var to := Vector2(shift.destination) - me
		var ahead := Vector2(RoadMap.DX[d.heading], RoadMap.DY[d.heading])
		angle = ahead.angle_to(to) if to.length() > 0.01 else 0.0
	elif _way.turn >= 0 and _way.tiles <= 3:
		angle = [0.0, PI / 2, PI, -PI / 2][_way.turn]
	var target := strings.t("rickshawNoRoute")
	if shift.remaining >= 0:
		if not shift.riding.is_empty():
			target = strings.t("rickshawToPlace", {"place": RoadMap.place_name(shift.riding.place, strings.lang), "tiles": shift.remaining})
		else:
			target = strings.t("toPassenger", {"tiles": shift.remaining})
		var hint := _way_text()
		if hint != "":
			target += "\n" + hint
	hud.show_controls(shift.pedal or shift.cruise, shift.brake, shift.speed_now * City.T * 3.6)
	hud.show_energy(shift.energy)
	var status := "%s\n%s" % [_clock_text(), strings.t("taka", {"n": shift.money})]
	if _race:
		target = strings.t("raceTo", {"place": RoadMap.place_name(shift.race_to, strings.lang), "tiles": shift.remaining})
		var hint := _way_text()
		if hint != "":
			target += "\n" + hint
		status = strings.t("raceClock", {"s": "%.1f" % _race_clock})
		for uid in _live_ghosts:
			var g: Dictionary = _live_ghosts[uid]
			status += "\n" + (strings.t("liveDone", {"name": g.name, "s": "%.1f" % float(g.time)}) if g.done else strings.t("liveRiding", {"name": g.name}))
		if not _ghost.is_empty():
			status += "\n" + strings.t("raceGhostTime", {"s": "%.1f" % float(_ghost.time)})
	if _delivery != null:
		target = _stop_text()
		var hint := _way_text()
		if hint != "" and not _delivery.current().is_empty():
			target += "\n" + hint
		status = "%s\n%s" % [_clock_text(), strings.t("taka", {"n": _delivery.money + shift.money})]
		var n: int = _delivery.stops().size()
		hud.show_switch(n > 1 and _activity == null, strings.t("switchStop", {"n": n}))
	hud.refresh(target, status, angle, _notice, _notice_colour, me, shift.destination)


## Works out the way on again when the rickshaw has moved on a tile (or
## turned, stopped, or got a new destination); a passenger aboard calls
## out the turn two tiles before it, and the drop-off when it is close.
func _update_way() -> void:
	var d := shift.driver
	var key := [d.cell, d.heading, d.moving, d.progress > 0.0, shift.destination]
	if key == _way_key:
		return
	_way_key = key
	_way = shift.next_turn()
	if shift.riding.is_empty():
		return
	var said := [shift.destination, _way.turn, _way.tiles]
	if said == _said_way:
		return
	if _way.turn >= 0 and _way.tiles == 2:
		_said_way = said
		_voice.say(["", "dir_right", "dir_back", "dir_left"][_way.turn])
	elif _way.turn < 0 and _way.tiles == 2:
		_said_way = said
		_voice.say("dir_here")


## "২ ব্লক পরে বামে", "এখনই ডানে", "সোজা"; "" with no legal way.
func _way_text() -> String:
	if _way.tiles < 0:
		return ""
	if _way.turn < 0:
		return strings.t("wayStraight")
	var way := strings.t(["", "turnRight", "turnBack", "turnLeft"][_way.turn])
	if _way.tiles == 0 or _way.turn == Driver.BACK:
		return strings.t("wayNow", {"way": way})
	return strings.t("wayIn", {"tiles": _way.tiles, "way": way})


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


## About how long the ride takes, in the day's minutes (to the nearest 5).
func _ride_minutes(w: Dictionary) -> int:
	var seconds := shift.fares.eta(int(w.tiles), shift.base_speed)
	var hours := shift.balance.n("rickshaw.end_hour") - shift.balance.n("rickshaw.start_hour")
	var minutes := seconds / shift.day_seconds * hours * 60.0
	return maxi(5, roundi(minutes / 5.0) * 5)


## Who is offering: a named neighbour by name and job, else the kind.
func _who(w: Dictionary) -> String:
	var npc: String = w.get("npc", "")
	if npc == "":
		return strings.t("type_" + w.type)
	return "%s · %s" % [neighbours.name_of(npc, strings.lang), neighbours.role_of(npc, strings.lang)]


## What the day's events mean on screen.
func _handle(events: Array) -> void:
	if events.has(Day.OFFER):
		var w: Dictionary = shift.offer_for
		hud.show_offer(
			strings.t("offerTitle", {"place": RoadMap.place_name(w.place, strings.lang), "fare": w.offer}),
			"%s · %s" % [_who(w), strings.t("rideLength", {"m": _ride_minutes(w)})],
			strings.t("haggleButton") if shift.interactive else strings.t("counter", {"fare": shift.fares.counter(w.fair)}))
		# The passenger calls out, in the way of their kind.
		_voice.say("hail_" + str(w.get("type", "normal")), true)
	if events.has(Day.OFFER_GONE):
		hud.hide_offer()
	if events.has(Day.DELIVERED):
		_coin.play()
		var t: Dictionary = shift.last_trip
		var tt: Dictionary = t.get("time", {})
		print("[trip] %d tiles: finding %.1f s, riding %.1f s; junction %.1f, traffic %.1f, held %.1f, standing %.1f; detours %d" % [
			int(tt.get("tiles", 0)), tt.get("finding", 0.0), tt.get("riding", 0.0), tt.get("junction", 0.0),
			tt.get("traffic", 0.0), tt.get("held", 0.0), tt.get("standing", 0.0), int(tt.get("detours", 0))])
		if float(t.stars) >= 5.0:
			Juice.celebrate(hud, "sparkle")
		if float(t.stars) >= 4.0:
			_voice.say("thanks", true)
		elif float(t.stars) < 3.0:
			_voice.say("grumble", true)
		var tip_text := strings.t("tipText", {"tip": t.tip}) if t.tip > 0 else ""
		var said := strings.t("delivered", {"fare": t.fare, "tip": tip_text, "stars": _stars(t.stars)})
		if t.get("thanks", false):
			said += "\n" + strings.t("npcThanks", {"name": neighbours.name_of(t.npc, strings.lang)})
		if str(t.get("friend", "")) != "":
			said += "\n" + strings.t("friendStallDelivered", {"name": str(t.friend)})
		_say(said, Look.PARROT, 3.5)
		_rider_seat.visible = false
		_bell.play()
		_place_marker()
		_sync_waiting()
	if events.has(Day.FINED):
		_say(strings.t("redLight", {"fine": int(shift.balance.n("rickshaw.red_light_fine"))}), Look.VERMILION, 3.0)
	if events.has(Day.POLICE):
		_say(strings.t("police", {"fine": int(shift.balance.n("rickshaw.wrong_way_fine"))}), Look.VERMILION, shift.held)
		_voice.say("police", true)
		_stop_by_police()
	if events.has(Day.TEA_NEAR):
		hud.show_tea(true, int(shift.balance.n("rickshaw.tea_cost")))
	if events.has(Day.TEA_GONE):
		hud.show_tea(false)
	if events.has(Day.ENERGY_LOW) and not events.has(Day.TIRED):
		_say(strings.t("energyLow"), Look.YELLOW.darkened(0.2), 4.0)
	if events.has(Day.TIRED):
		_say(strings.t("tired"), Look.YELLOW.darkened(0.2), 4.0)
	if events.has(Day.FLAT):
		_say(strings.t("flatTyre"), Look.YELLOW.darkened(0.3), 3.5)
		hud.show_pump(true)
	if events.has(Day.STUCK):
		_say(strings.t("stuckWater"), Look.SKY, 2.5)
		_push_out()
	if events.has(Day.RAIN_START):
		_say(strings.t("rainStart") + ("\n" + strings.t("rainFares") if mode != "delivery" else ""), Look.SKY, 4.0)
		_rain_sound.play()
		if not shift.riding.is_empty():
			_voice.say("rain")
	if events.has(Day.HOOD):
		_raise_hood()
	if events.has(Day.PHONE_PAY):
		_funny("pay_bkash")
		_check_sms()
	if events.has(Day.CHAIN):
		_say(strings.t("chainOff"), Look.VERMILION, 3.0)
		_voice.say("grumble", true)
		_fix_chain()
	if events.has(Day.LOST_ITEM):
		_say(strings.t("lostFound", {"item": strings.t("lostItem_" + str(shift.lost.item))}), Look.MAGENTA, 3.0)
		if _activity != null:
			_queued.append(_ask_lost)
		else:
			_ask_lost()
	if events.has(Day.RAIN_END):
		_say(strings.t("rainEnd"), Look.SKY, 2.5)
	if events.has(Day.RACE_DONE):
		if _live.is_empty():
			_end_race()
		else:
			_end_live_race()
	if events.has(Day.POTHOLE):
		_say(strings.t("pothole"), Look.YELLOW.darkened(0.3), 3.0)
		Activity.buzz(120)
	if events.has(Day.GUARD):
		_ask_night_guard()
	if _delivery != null:
		_delivery_events(events)
	if events.has(Day.DAY_OVER):
		if _delivery != null:
			_end_delivery()
		else:
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
	return Weather.rain_drops()


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
	if _delivery != null:
		_take_order(true)
		return
	shift.accept()
	_voice.say("board")
	_boarded()


func _on_counter() -> void:
	if shift.interactive:
		_haggle()
		return
	_voice.say("rahim_counter", true)
	if shift.counter():
		_voice.say("counter_yes")
		_boarded()
	else:
		_voice.say("counter_no")
		hud.hide_offer()
		_say(strings.t("counterNo"), Look.VERMILION, 2.5)
		_place_marker()
		_sync_waiting()


## Haggling face to face (the hand activity).
func _haggle() -> void:
	var w: Dictionary = shift.offer_for
	if w.is_empty() or _activity != null:
		return
	var act := Haggle.new()
	act.mood_of = shift.mood
	act.start(int(w.offer), maxi(int(w.offer) + 50, shift.fares.round_fare(int(w.fair) * 1.8)))
	_open(act, "act_haggle", _haggled.bind(act))


func _haggled(_score: float, act: Haggle) -> void:
	if shift.offer_for.is_empty():
		return
	if act.quick or act.asked <= int(shift.offer_for.offer):
		_on_accept()
		return
	_voice.say("rahim_counter", true)
	if shift.haggle(act.asked):
		_voice.say("counter_yes")
		_boarded()
	else:
		_voice.say("counter_no")
		hud.hide_offer()
		_say(strings.t("counterNo"), Look.VERMILION, 2.5)
		_place_marker()
		_sync_waiting()


func _open(act: Activity, key: String, then: Callable) -> void:
	print("[rickshaw] hands: ", key)
	act.setup(strings, key, key + "_hint")
	act.done.connect(then)
	act.tree_exited.connect(_closed)
	_activity = act
	# Hands off the pedal while the fingers are busy.
	shift.cruise = false
	_pedal_down_at.clear()
	_pedal_fingers.clear()
	_brake_fingers.clear()
	_swipes.clear()
	_apply_controls()
	hud.add_child(act)


func _closed() -> void:
	_activity = null
	if not _queued.is_empty() and not shift.over:
		_queued.pop_front().call_deferred()


## The chain off the gear: lift it back on, turn the pedal.
func _fix_chain() -> void:
	if _activity != null:
		# Busy with something else: he puts it back on, slowly.
		shift.fix_chain(shift.balance.n("rickshaw.chain_quick_s"))
		return
	var act := ChainAct.new()
	_open(act, "act_chain", _chain_fixed.bind(act))


func _chain_fixed(score: float, act) -> void:
	if act.quick or score <= 0.0:
		shift.fix_chain(shift.balance.n("rickshaw.chain_quick_s"))
		_say(strings.t("chainSlow"), Look.YELLOW.darkened(0.3), 2.5)
	else:
		shift.fix_chain()
		_say(strings.t("chainOn"), Look.PARROT, 2.0)


## Something left on the seat: where did its owner get off?
func _ask_lost() -> void:
	var lost: Dictionary = shift.lost
	if lost.is_empty():
		return
	var act := LostAct.new()
	act.item = str(lost.item)
	var who := strings.t("lostWho_" + str(lost.type)) if str(lost.npc) == "" else neighbours.name_of(str(lost.npc), strings.lang)
	act.question = strings.t("lostQuestion_rickshaw", {"who": who, "item": strings.t("lostItem_" + act.item)})
	act.choices = (lost.choices as Array).map(func(p): return RoadMap.place_name(p, strings.lang))
	act.hand_in_key = "lost_police"
	_open(act, "act_lost", _lost_answered.bind(act))


func _lost_answered(_score: float, act) -> void:
	var result := shift.return_lost(act.choice)
	print("[rickshaw] lost item: ", result)
	match result:
		"right":
			_say(strings.t("lost_right", {"n": int(shift.balance.n("rickshaw.lost_reward"))}), Look.PARROT, 3.5)
			_coin.play()
		"wrong":
			_say(strings.t("lost_wrong"), Look.VERMILION, 3.0)
		"police":
			_say(strings.t("lost_police_said"), Look.SKY, 2.5)


# --- The night shift (night.gd) -----------------------------------------------------------


## A night guard by the road: khaki, a whistle, a torch.
func _night_guard(map: RoadMap, at: Vector2i) -> Node3D:
	var node := Node3D.new()
	node.name = "NightGuard"
	node.position = City._side(map, at) + Vector3(0, 0.15, 0)
	var face := City.centre(at) - node.position
	node.rotation.y = atan2(-face.x, -face.z)
	var body := MeshInstance3D.new()
	body.mesh = _person_mesh if _person_mesh != null else Models.person()
	var paint := Models.traffic_material(PackedColorArray([Color("8C7A4B"), Color("3E3A2E")]), false)
	paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	body.material_override = paint
	node.add_child(body)
	var torch := OmniLight3D.new()
	torch.position = Vector3(0.3, 1.2, -0.3)
	torch.light_color = Color("FFE7A0")
	torch.light_energy = 1.2
	torch.omni_range = 4.0
	node.add_child(torch)
	node.add_child(City._sign(strings.t("nightGuardName"), Vector3(0, 2.3, 0), 36, Look.SKY))
	return node


## A night guard's question; without the hands he just waves him on.
func _ask_night_guard() -> void:
	var q: Dictionary = shift.guard_ask.get("question", {})
	if not shift.interactive or q.is_empty() or _activity != null:
		shift.settle_guard(true)
		_say(strings.t("guardWave"), Look.SKY, 2.5)
		return
	var act := Choose.new()
	act.rounds = [q]
	_open(act, "act_guard", _guard_answered)


func _guard_answered(score: float) -> void:
	var ok := score >= 0.5
	shift.settle_guard(ok)
	_say(strings.t("guardOk" if ok else "guardHeld"), Look.PARROT if ok else Look.VERMILION, 3.0)


# --- Ratul's deliveries (delivery.gd) --------------------------------------------------


## Whose phone calls and family: Rahim Chacha's, or Ratul's.
func _whose() -> String:
	return "delivery" if mode == "delivery" else "rickshaw"


## Ratul's evening: his hours, his bicycle, orders instead of passengers.
func _setup_delivery(b: Balance) -> void:
	_delivery = Delivery.new(b, shift.map, -1, progress.data.delivery.upgrades)
	shift.start_delivery(_delivery)
	shift.hours_key = "delivery"
	shift.day_seconds = b.n("delivery.day_seconds")
	var speed := b.n("delivery.speed")
	if progress.has_upgrade("gear_cycle", "delivery"):
		speed *= b.n("delivery.upgrades.gear_cycle.speed")
	shift.base_speed *= speed
	shift.energy_factor = b.n("delivery.energy")
	_target_money = int(b.n("delivery.daily_target"))
	_call_rng.randomize()
	var call_share := HomeCall.plan(_call_rng, progress.level())
	if call_share >= 0.0:
		_call_at = call_share * shift.day_seconds
	# A boost bought with stars: more orders on the app.
	_boost = progress.take_boost("delivery")
	_delivery.offer_factor = float(_boost.get("arrivals", 1.0))


## The kitchens' names over them, so they can be found.
func _kitchen_signs() -> Node3D:
	var node := Node3D.new()
	node.name = "Kitchens"
	for k in _delivery.kitchens:
		var board := City._sign(str(k.name.get(strings.lang, k.name.en)), City._side(shift.map, k.at) + Vector3(0, 3.4, 0), 44, Look.VERMILION)
		node.add_child(board)
	return node


## The stop the arrow points at, in words.
func _stop_text() -> String:
	var stop: Dictionary = _delivery.current()
	if stop.is_empty():
		return strings.t("waitingOrders")
	var o: Dictionary = _delivery.order(int(stop.order))
	var kitchen := str(o.kitchen.name.get(strings.lang, o.kitchen.name.en))
	if stop.kind == "pick":
		return strings.t("stopPick", {"kitchen": kitchen, "tiles": shift.remaining})
	return strings.t("stopDrop", {"flat": str(o.flat), "tiles": shift.remaining, "heat": int(round(float(o.heat) * 100.0))})


func _delivery_events(events: Array) -> void:
	if events.has(Delivery.OFFER):
		var o: Dictionary = _delivery.offer
		# With nothing to carry, the order is his at once, as a passenger
		# gets in: only a second or third one at a time is a choice.
		if _delivery.active.is_empty():
			_bell.play()
			Activity.buzz(40)
			_say(strings.t("orderAuto", {"food": str(o.kitchen.food.get(strings.lang, o.kitchen.food.en)),
				"kitchen": str(o.kitchen.name.get(strings.lang, o.kitchen.name.en)), "pay": int(o.pay)}), Look.PARROT, 4.0)
			_take_order(true)
			return
		hud.show_offer(strings.t("orderTitle", {"food": str(o.kitchen.food.get(strings.lang, o.kitchen.food.en)), "pay": int(o.pay)}),
			strings.t("orderSub", {"kitchen": str(o.kitchen.name.get(strings.lang, o.kitchen.name.en)), "flat": str(o.flat), "tiles": int(o.tiles)}), "")
		Activity.buzz(40)
		_bell.play()
	if events.has(Delivery.OFFER_GONE):
		hud.hide_offer()
		_say(strings.t("orderGone"), Look.MUTED, 2.0)
	if events.has(Delivery.COOKING):
		_say(strings.t("foodCooking"), Look.YELLOW.darkened(0.3), 3.0)
	if events.has(Delivery.PICKED):
		var p: Dictionary = _delivery.last_picked
		_say(strings.t("foodPicked", {"food": str(p.kitchen.food.get(strings.lang, p.kitchen.food.en)), "flat": str(p.flat)}), Look.PARROT, 3.0)
		_place_marker()
	if events.has(Delivery.COLD):
		_say(strings.t("foodCold"), Look.VERMILION, 3.0)
	if events.has(Delivery.GATE):
		_ask_guard()
	if events.has(Delivery.DELIVERED):
		_delivered()


func _delivered() -> void:
	_coin.play()
	var d: Dictionary = _delivery.last_done
	var tip_text := strings.t("tipText", {"tip": d.tip}) if int(d.tip) > 0 else ""
	_say(strings.t("foodDelivered", {"pay": int(d.pay), "tip": tip_text, "stars": _stars(float(d.stars))}), Look.PARROT, 3.5)
	shift._aim()
	_place_marker()


func _take_order(yes: bool) -> void:
	hud.hide_offer()
	if yes and _delivery.accept():
		_say(strings.t("orderTaken"), Look.PARROT, 2.0)
	elif not yes:
		_delivery.decline()
	shift._aim()
	_place_marker()


func _on_switch() -> void:
	if _delivery == null:
		return
	_delivery.switch_target()
	shift._aim()
	_place_marker()
	Activity.buzz(12)


## A guard at the gate wants a word: a good answer, and in.
func _ask_guard() -> void:
	var q: Dictionary = _delivery.gate.question
	if _activity != null:
		_delivered_after_gate(0.5, null)
		return
	var act := Choose.new()
	act.rounds = [q]
	_open(act, "act_gate", _delivered_after_gate.bind(act))


func _delivered_after_gate(score: float, act) -> void:
	var ok := score >= 0.5
	var got: Array = _delivery.settle_gate(ok)
	if not ok:
		_say(strings.t("gateBad"), Look.VERMILION, 2.5)
	if got.has(Delivery.DELIVERED):
		_delivered()


## The end of Ratul's evening: what came in, the rating, into the save.
func _end_delivery() -> void:
	set_process(false)
	hud.hide_offer()
	hud.show_tea(false)
	hud.show_switch(false)
	shift.pedal = false
	shift.cruise = false
	_rain_sound.stop()
	_drops.emitting = false
	var d = _delivery
	var earned: int = d.money + shift.money
	var lines := [strings.t("ordersDone", {"n": d.delivered})]
	if d.hot > 0:
		lines.append(strings.t("ordersHot", {"n": d.hot}))
	if d.cold_ones > 0:
		lines.append(strings.t("ordersCold", {"n": d.cold_ones}))
	if d.tips > 0:
		lines.append(strings.t("teaTips", {"n": d.tips}))
	if shift.fines > 0:
		lines.append(strings.t("finesPaid", {"fines": shift.fines}))
	if shift.teas > 0:
		lines.append(strings.t("teaLine", {"n": shift.teas, "money": shift.tea_spent}))
	if not _call_result.is_empty():
		lines.append(strings.t("familyLine", {"n": _call_result.family}))
	var stats := {"orders": d.delivered, "hot": d.hot, "earned": earned}
	var got := progress.apply_delivery_day({"earned": earned, "orders": d.delivered, "stars": d.average_stars(), "stats": stats})
	progress.save()
	load("res://scripts/ui/cloud.gd").backup(self, progress.data)
	CrashWatch.stop()
	if int(got.get("samity_payout", 0)) > 0:
		lines.append(strings.t("samityPayoutLine", {"n": int(got.samity_payout)}))
	elif int(got.get("samity_paid", 0)) > 0:
		lines.append(strings.t("samityDayLine", {"n": int(got.samity_paid)}))
	var met := earned >= _target_money
	print("[day] delivery: %d orders, %.1f stars, %d taka" % [d.delivered, d.average_stars(), earned])
	var end := DayEnd.new()
	end.setup(strings, progress.b, progress, got, {
		"title": strings.t("dayOver"),
		"stars": d.average_stars(),
		"sub": strings.t("appRating", {"stars": _stars(snappedf(d.average_stars(), 0.1))}),
		"money": earned,
		"lines": lines,
		"share": strings.t("share_delivery", {"n": d.delivered, "money": earned}) if d.delivered > 0 else "",
		"kept_label": strings.t("gainKeptLabel"),
		"extras": [strings.t("targetMet" if met else "targetMissed", {"target": _target_money})],
		"good": met,
	})
	end.home_pressed.connect(_go_home)
	end.again_pressed.connect(_play_again)
	hud.add_child(end)


# --- Today's race with a ghost (race.gd) ---------------------------------------------


## The ghost: a friend's best ride today (or my own), a pale rickshaw
## with their name over it.
func _setup_ghost() -> void:
	_ghost = Race.ghost(progress.data, progress.date())
	_ghost_points = Race.decode(str(_ghost.get("path", "")))
	if _ghost_points.size() < 2:
		_ghost = {}
		return
	_ghost_node = Models.player_rickshaw(Color(0.9, 0.95, 1.0), Color(0.7, 0.8, 1.0))
	var pale := StandardMaterial3D.new()
	pale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pale.albedo_color = Color(0.6, 0.78, 1.0, 0.55)
	pale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for m in _ghost_node.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = pale
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var label := City._sign(str(_ghost.name) if _ghost.friend else strings.t("ghostYou"), Vector3(0, 2.6, 0), 40, Look.SKY)
	_ghost_node.add_child(label)
	add_child(_ghost_node)
	_place_ghost()


func _place_ghost() -> void:
	if _ghost_node == null:
		return
	var p := Race.at_time(_ghost_points, _race_clock)
	var ahead := Race.at_time(_ghost_points, _race_clock + Race.STEP) - p
	_ghost_node.position = Vector3(p.x, 0, p.y)
	if ahead.length() > 0.01:
		_ghost_node.rotation.y = lerp_angle(_ghost_node.rotation.y, atan2(-ahead.x, -ahead.y), 0.3)


## The race's clock, the ride written down, the ghost moved on.
func _race_tick(dt: float) -> void:
	# The clock starts with the first push of the pedals.
	if _race_clock <= 0.0 and shift.speed_now < 0.02:
		return
	_race_clock += dt
	_path_left -= dt
	if _path_left <= 0.0 and _path.size() < Race.MAX_POINTS:
		_path_left += Race.STEP
		_path.append(Vector2(rickshaw.position.x, rickshaw.position.z))
	_place_ghost()


## At the finish: the time, against the ghost; today's best kept and sent
## to the card; stars; again, or home.
func _end_race() -> void:
	set_process(false)
	shift.pedal = false
	shift.cruise = false
	_rain_sound.stop()
	_drops.emitting = false
	_path.append(Vector2(rickshaw.position.x, rickshaw.position.z))
	var got := Race.finish(progress.data, progress.b, progress.date(), _race_clock, Race.encode(_path), _ghost)
	progress.save()
	load("res://scripts/ui/cloud.gd").backup(self, progress.data)
	CrashWatch.stop()
	print("[race] %.1f s, ghost %s, %s" % [_race_clock, str(_ghost.get("time", "-")), str(got)])
	var lines := [strings.t("raceTime", {"s": "%.1f" % _race_clock})]
	if not _ghost.is_empty():
		var key := "raceBeat" if _race_clock < float(_ghost.time) else "raceLost"
		if not _ghost.friend:
			key = "raceBeatSelf" if _race_clock < float(_ghost.time) else "raceLostSelf"
		lines.append(strings.t(key, {"name": str(_ghost.name), "s": "%.1f" % float(_ghost.time)}))
	if got.best:
		lines.append(strings.t("raceBest"))
	if int(got.stars) > 0:
		lines.append(strings.t("raceStars", {"n": int(got.stars)}))
	lines.append(strings.t("raceShare"))
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(Look.CREAM, 18, 3))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(Look.title(strings.t("raceOver"), 32))
	for l in lines:
		var label := Look.label(str(l), 17, true)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var again := Look.chunky(strings.t("raceAgain"), Look.YELLOW, Look.OUTLINE, 18)
	again.pressed.connect(func():
		Race.next = true
		_play_again())
	var home := Look.chunky(strings.t("back"), Color.WHITE, Look.OUTLINE, 18)
	home.pressed.connect(_go_home)
	for button in [again, home]:
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 58)
		row.add_child(button)
	col.add_child(row)
	ReadAloud.say("\n".join(lines), strings.lang)


# --- A live race with friends (online.gd) -------------------------------------------


## The others in the room: a pale rickshaw each, with their name, riding
## where they were at the same moment of their race (a second or two late).
func _setup_live() -> void:
	_live_cloud = Cloud.new()
	add_child(_live_cloud)
	var tints := [Color(1.0, 0.75, 0.6, 0.6), Color(0.7, 1.0, 0.75, 0.6)]
	for uid in _live.players:
		if str(uid) == str(_live.me):
			continue
		var node := Models.player_rickshaw(Color(0.9, 0.95, 1.0), Color(0.7, 0.8, 1.0))
		var pale := StandardMaterial3D.new()
		pale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pale.albedo_color = tints[_live_ghosts.size() % tints.size()]
		pale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for m in node.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_override = pale
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var name := str(_live.names.get(uid, ""))
		node.add_child(City._sign(name, Vector3(0, 2.6, 0), 40, Look.VERMILION))
		node.visible = false
		add_child(node)
		_live_ghosts[str(uid)] = {"node": node, "points": PackedVector2Array(), "name": name, "done": false, "time": 0.0}


## Every second or two: my ride so far out, the others' in.
func _live_tick(dt: float) -> void:
	for uid in _live_ghosts:
		var g: Dictionary = _live_ghosts[uid]
		var pts: PackedVector2Array = g.points
		if pts.size() >= 2:
			var t := float(g.time) if g.done else _race_clock
			var p := Race.at_time(pts, t)
			var ahead := Race.at_time(pts, t + Race.STEP) - p
			var node: Node3D = g.node
			node.visible = true
			node.position = Vector3(p.x, 0, p.y)
			if ahead.length() > 0.01:
				node.rotation.y = lerp_angle(node.rotation.y, atan2(-ahead.x, -ahead.y), 0.3)
	_live_poll -= dt
	if _live_poll > 0.0 or _live_busy:
		return
	_live_poll = float(progress.b.n("online.poll_s"))
	_live_sync({"t": _race_clock})


func _live_sync(extra: Dictionary) -> void:
	_live_busy = true
	var mine := {"name": str(_live.names.get(_live.me, "")), "path": Race.encode(_path)}
	mine.merge(extra, true)
	await _live_cloud.move_put(str(_live.code), mine)
	var m := await _live_cloud.moves(str(_live.code))
	_live_busy = false
	if m.has("_error"):
		return
	for uid in _live_ghosts:
		var d = m.get(uid, null)
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var g: Dictionary = _live_ghosts[uid]
		g.points = Race.decode(str(d.get("path", "")))
		g.done = bool(d.get("done", false))
		g.time = float(d.get("time", 0.0))


## At the finish: my time out, then the places as the others come in
## (a minute and a half at most), stars, and the room tidied away.
func _end_live_race() -> void:
	set_process(false)
	shift.pedal = false
	shift.cruise = false
	_rain_sound.stop()
	_drops.emitting = false
	_path.append(Vector2(rickshaw.position.x, rickshaw.position.z))
	CrashWatch.stop()
	print("[live race] %.1f s" % _race_clock)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(Look.CREAM, 18, 3))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(Look.title(strings.t("raceOver"), 32))
	col.add_child(Look.label(strings.t("raceTime", {"s": "%.1f" % _race_clock}), 17, true))
	var table := Look.label(strings.t("liveWaiting"), 17, true)
	table.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(table)
	while _live_busy:
		await get_tree().create_timer(0.3).timeout
	var code := str(_live.code)
	var rows := []
	var waited := 0.0
	# A racer whose clock has stopped (closed the game, or put it away) is
	# not waited for.
	var seen := {}
	var gone := {}
	while true:
		await _live_cloud.move_put(code, {"name": str(_live.names.get(_live.me, "")), "path": Race.encode(_path), "done": true, "time": snappedf(_race_clock, 0.1)})
		var m := await _live_cloud.moves(code)
		if not m.has("_error"):
			rows = Online.standings(_live.players, m)
			for r in rows:
				if not r.done and r.uid != str(_live.me) and Online.gone(seen, m, r.uid, float(progress.b.n("online.poll_s")), float(progress.b.n("online.gone_s")), "t"):
					gone[r.uid] = true
			var text := PackedStringArray()
			for i in rows.size():
				var r: Dictionary = rows[i]
				var who: String = r.name + (" " + strings.t("onYou") if r.uid == str(_live.me) else "")
				if r.done:
					text.append(strings.t("livePlace", {"n": i + 1, "name": who, "s": "%.1f" % float(r.time)}))
				else:
					text.append(strings.t("liveGone" if gone.has(r.uid) else "liveStill", {"name": who}))
			table.text = "\n".join(text)
			if rows.all(func(r): return r.done or gone.has(r.uid)):
				break
		waited += float(progress.b.n("online.poll_s"))
		if waited >= float(progress.b.n("online.wait_s")):
			break
		await get_tree().create_timer(float(progress.b.n("online.poll_s"))).timeout
	var place := 1
	for i in rows.size():
		if rows[i].uid == str(_live.me):
			place = i + 1
	var stars := Online.race_prize(progress.data, progress.b, progress.date(), place, rows.size())
	progress.save()
	load("res://scripts/ui/cloud.gd").backup(self, progress.data)
	print("[live race] place %d of %d, %d stars" % [place, rows.size(), stars])
	col.add_child(Look.label(strings.t("liveWon") if place == 1 and rows.size() > 1 else strings.t("livePlaceMine", {"n": place}), 19, true, Look.MAGENTA))
	if stars > 0:
		col.add_child(Look.label(strings.t("raceStars", {"n": stars}), 17, true, Look.PARROT_DARK))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var again := Look.chunky(strings.t("onAgain"), Look.YELLOW, Look.OUTLINE, 18)
	again.pressed.connect(func(): get_tree().change_scene_to_file.call_deferred("res://scenes/online.tscn"))
	var home := Look.chunky(strings.t("back"), Color.WHITE, Look.OUTLINE, 18)
	home.pressed.connect(_go_home)
	for button in [again, home]:
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 58)
		row.add_child(button)
	col.add_child(row)
	ReadAloud.say(table.text, strings.lang)
	# Tidy up: my part away; the host closes the room once everyone is in.
	await _live_cloud.move_delete(code)
	if str(_live.host) == str(_live.me):
		await get_tree().create_timer(10.0).timeout
		if is_inside_tree():
			await _live_cloud.room_delete(code)


## A friend's tea stall by the road, with their name over it.
func _friend_stall(map: RoadMap, place: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "FriendStall"
	var at: Vector2i = place.at
	var inward := City._inward(map, at)
	node.position = City._side(map, at) + Vector3(0, 0.15, 0)
	# The counter faces the road.
	node.rotation.y = atan2(inward.x, inward.z)
	var stall := MeshInstance3D.new()
	stall.mesh = Models.tea_stall()
	stall.material_override = Models.material()
	stall.scale = Vector3.ONE * 0.8
	node.add_child(stall)
	var board := City._sign(RoadMap.place_name(place, strings.lang), Vector3(0, 3.0, 0), 44, Look.MAGENTA)
	node.add_child(board)
	return node


## The bell: once, or twice quickly to clear the way for longer.
func _ring() -> void:
	var kind := shift.ring()
	_bell.play()
	Activity.buzz(25 if kind == "double" else 12)


## The soft tyre: stop, then pump it.
func _on_pump() -> void:
	if _activity != null:
		return
	if shift.speed_now > 0.3:
		_say(strings.t("stopToPump"), Look.YELLOW.darkened(0.3), 2.0)
		return
	var act := Pump.new()
	_open(act, "act_pump", _pumped.bind(act))


func _pumped(_score: float, act: Pump) -> void:
	if act.quick:
		# Pumped without care: right enough, after a while.
		shift.flat = false
		shift.held = 3.0
		hud.show_pump(false)
		return
	var result := shift.pump(act.pressure)
	if result == "soft":
		_say(strings.t("pumpSoft"), Look.YELLOW.darkened(0.3), 2.5)
		return
	hud.show_pump(false)
	if result == "burst":
		_say(strings.t("pumpBurst", {"n": int(shift.balance.n("rickshaw.tube_cost"))}), Look.VERMILION, 3.0)
	else:
		_say(strings.t("pumpOk"), Look.PARROT, 2.0)


## The phone rings: someone from home. The answer moves the family's
## feeling, may send money home, may end the day (going home).
func _ring_home() -> void:
	var call := HomeCall.new().pick(_whose(), _call_rng, progress.family(_whose()))
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
	# With his own phone, a talk with home is a video call: gladder still.
	if option == "talk" and progress.has_phone():
		e.family += 1
	var now := progress.add_family(_whose(), e.family)
	shift.money -= e.cost
	_call_result = {"family": now, "delta": e.family}
	print("[home] call ", act.call.get("id", ""), ": ", option, ", family ", now)
	if e.family > 0:
		_say(strings.t("familyUp", {"n": now}), Look.PARROT, 3.0)
	elif e.family < 0:
		_say(strings.t("familyDown", {"n": now}), Look.VERMILION, 3.0)
	if e.end_day:
		shift.clock = shift.day_seconds

## Paid by phone: check the SMS before they walk off.
func _check_sms() -> void:
	if _activity != null:
		_sms_checked(1.0, null)
		return
	var act := Sms.new()
	act.sms = shift.phone_pay.sms
	act.fare = int(shift.phone_pay.fare)
	act.has_phone = progress.has_phone()
	_open(act, "act_sms", _sms_checked.bind(act))


func _sms_checked(_score: float, act) -> void:
	var fare := int(shift.phone_pay.get("fare", 0))
	var result := shift.settle_phone(act != null and act.said_fake)
	print("[rickshaw] phone pay: ", result)
	var colour: Color = {"fine": Look.PARROT, "caught": Look.PARROT, "fooled": Look.VERMILION, "wrong": Look.VERMILION}.get(result, Look.SKY)
	_say(strings.t("phone_" + result, {"fare": fare}), colour, 3.0)


func _on_hood_down() -> void:
	shift.lower_hood()
	hud.show_hood_down(false)
	_say(strings.t("hoodDown"), Look.PARROT, 2.0)


## Rain on the passenger: up with the hood, and the plastic over them.
func _raise_hood() -> void:
	if _activity != null:
		# Busy with something else: the hood goes up anyway, slowly.
		shift.raise_hood(0.5)
		return
	var act := Hood.new()
	_open(act, "act_hood", _hood_raised)


func _hood_raised(score: float) -> void:
	shift.raise_hood(score)
	if score >= 0.7:
		_say(strings.t("hoodDry", {"tip": int(shift.balance.n("rickshaw.hood_tip"))}), Look.PARROT, 2.5)
	elif score < 0.4:
		_say(strings.t("hoodWet"), Look.SKY, 2.5)


## Stuck in deep water: get down and push.
func _push_out() -> void:
	if _activity != null:
		return
	var act := Push.new()
	act.on_push = shift.push
	_open(act, "act_push", _pushed_out.bind(act))


func _pushed_out(_score: float, act: Push) -> void:
	if shift.stuck:
		# Skipped: he wades it out slowly.
		shift.stuck = false
		shift.held = 4.0
	if not act.quick:
		_say(strings.t("freed"), Look.PARROT, 2.0)


func _on_refuse() -> void:
	if _delivery != null:
		_take_order(false)
		return
	shift.refuse()
	hud.hide_offer()


func _boarded() -> void:
	hud.hide_offer()
	# The very first passenger of the very first day: a newcomer to Dhaka.
	if mode == "rickshaw" and int(progress.data.rickshaw.get("days", 0)) == 0 and shift.trips == 0 and not _first_told:
		_first_told = true
		_funny.call_deferred("first_ride")
	_rider_seat.mesh = Models.seated_passenger(randi() % Models.PEOPLE)
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
		if w.get("npc", "") != "":
			label.text = neighbours.name_of(w.npc, strings.lang) + "\n" + label.text
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
	_env.fog_density = lerpf(0.008, 0.026, _rain_k)
	# A winter morning's fog: white, thick at dawn, gone by mid-morning.
	var fog := shift.fog()
	if fog > 0.0:
		_env.fog_density = maxf(_env.fog_density, lerpf(0.008, 0.05, fog))
		_env.fog_light_color = _env.fog_light_color.lerp(Color("E8E8E4"), fog)
		_sky.sky_horizon_color = _sky.sky_horizon_color.lerp(Color("EDEDEA"), fog)
		_sun.light_energy *= lerpf(1.0, 0.6, fog)


func _end_day() -> void:
	set_process(false)
	hud.hide_offer()
	hud.show_tea(false)
	shift.pedal = false
	shift.cruise = false
	_rain_sound.stop()
	_drops.emitting = false
	var lines := []
	if shift.worn_out:
		lines.append(strings.t("wornOut"))
	lines.append(strings.t("tripsDone", {"trips": shift.trips}))
	if shift.fines > 0:
		lines.append(strings.t("finesPaid", {"fines": shift.fines}))
	if shift.teas > 0:
		lines.append(strings.t("teaLine", {"n": shift.teas, "money": shift.tea_spent}))
	if shift.night:
		if shift.potholes > 0:
			lines.append(strings.t("potholeLine", {"n": shift.potholes}))
		# Rokeya sat up waiting.
		var fam := progress.add_family("rickshaw", -int(progress.b.n("night.family_worry")))
		lines.append(strings.t("nightFamilyLine", {"n": fam}))
	if shift.returned > 0:
		lines.append(strings.t("lostLine", {"n": shift.returned, "money": shift.lost_rewards}))
	var to_friends := 0
	for uid in shift.friend_visits:
		to_friends += int(shift.friend_visits[uid])
	if to_friends > 0:
		lines.append(strings.t("friendStallLine", {"n": to_friends}))
	if not _call_result.is_empty():
		lines.append(strings.t("familyLine", {"n": _call_result.family}))
	var met := shift.money >= _target_money
	print("[day] rickshaw: %d trips, %.1f s a trip on average" % [shift.trips, shift.average_trip_seconds()])
	# Into the save: savings, school fee, fund, XP, the record.
	var stats := {"good_trips": shift.good_trips, "clean": 1 if shift.fines == 0 and shift.trips >= 3 else 0, "earned": shift.money}
	var got := progress.apply_day({"earned": shift.money, "trips": shift.trips, "stars": shift.average_stars(), "fines": shift.fines, "teas": shift.teas, "stats": stats, "npcs": shift.npc_log, "visits": shift.friend_visits})
	progress.save()
	# And a copy online, if this build has it (not waited for).
	load("res://scripts/ui/cloud.gd").backup(self, progress.data)
	CrashWatch.stop()
	if int(got.get("samity_payout", 0)) > 0:
		lines.append(strings.t("samityPayoutLine", {"n": int(got.samity_payout)}))
	elif int(got.get("samity_paid", 0)) > 0:
		lines.append(strings.t("samityDayLine", {"n": int(got.samity_paid)}))
	if _friend_energy > 0.0:
		lines.append(strings.t("friendTeaLine", {"n": int(_friend_energy)}))
	if _relay_energy > 0.0:
		lines.append(strings.t("relayEnergyLine", {"n": int(_relay_energy)}))
	if int(got.get("relay_bonus", 0)) > 0:
		lines.append(strings.t("relayBonusLine", {"n": int(got.relay_bonus)}))
	if bool(got.get("relay_done", false)):
		lines.append(strings.t("relayDoneLine", {"n": int(progress.b.n("friends.relay_tara"))}))
	var end := DayEnd.new()
	end.setup(strings, progress.b, progress, got, {
		"title": strings.t("dayOver"),
		"stars": shift.average_stars(),
		"sub": strings.t("avgRating", {"stars": _stars(snappedf(shift.average_stars(), 0.1))}),
		"money": shift.money,
		"lines": lines,
		"share": strings.t("share_night" if shift.night else ("share_rickshaw_rain" if shift.rain_at >= 0.0 else "share_rickshaw"), {"n": shift.trips, "money": shift.money}) if shift.trips > 0 else "",
		"kept_label": strings.t("gainKeptLabel"),
		"extras": [strings.t("targetMet" if met else "targetMissed", {"target": _target_money})],
		"good": met,
	})
	end.home_pressed.connect(_go_home)
	end.again_pressed.connect(_play_again)
	hud.add_child(end)


func _play_again() -> void:
	CrashWatch.start("rickshaw")
	get_tree().reload_current_scene.call_deferred()


## Touches are read finger by finger: a finger on the pedal or brake holds
## it; any other finger can swipe a turn at the same time.
func _input(event: InputEvent) -> void:
	if not is_processing() or _activity != null:
		return
	if event is InputEventScreenTouch:
		var finger: int = event.index
		if event.pressed:
			if hud.offer_rect().has_point(event.position) or hud.tea_rect().has_point(event.position) \
					or hud.pump_rect().has_point(event.position) or hud.hood_rect().has_point(event.position) \
					or hud.switch_rect().has_point(event.position):
				pass
			elif hud.bell_rect().has_point(event.position):
				_ring()
			elif hud.pedal_rect().has_point(event.position):
				_pedal_fingers[finger] = true
				_pedal_down_at[finger] = Time.get_ticks_msec()
			elif hud.brake_rect().has_point(event.position):
				_brake_fingers[finger] = true
			else:
				_swipes[finger] = {"start": event.position, "used": false}
		else:
			if _pedal_down_at.has(finger) and Time.get_ticks_msec() - int(_pedal_down_at[finger]) < 250:
				shift.cruise = not shift.cruise
			_pedal_down_at.erase(finger)
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
		if event.keycode == KEY_C and event.pressed:
			shift.cruise = not shift.cruise
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


## A passenger's passing talk now and then on a ride, when nothing else is
## on the notice line.
func _chat_tick(dt: float) -> void:
	_chat_left -= dt
	if _chat_left > 0.0:
		return
	_chat_left = Chatter.gap()
	if _notice != "" or shift.riding.is_empty() or _activity != null or mode == "delivery":
		return
	var line := Chatter.pick("ride_chat", strings.lang)
	if line.is_empty():
		return
	_voice.play(str(line.id))
	_say(str(line.text), Look.SKY_DARK, 4.0)


## Bought decorations on the back of Rahim Chacha's rickshaw, where the
## camera sees them all day: a painting, and a line written under it
## (always in Bangla, as rickshaw painters write it).
func _back_art(on: Node3D) -> void:
	var plate := progress.worn("rickshaw", "plate")
	if not plate.is_empty():
		var tex := load("res://textures/ui/%s.png" % str(plate.get("picture", ""))) as Texture2D
		if tex != null:
			var quad := QuadMesh.new()
			quad.size = Vector2(0.98, 0.4)
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.roughness = 0.55
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			var art := MeshInstance3D.new()
			art.name = "BackPlate"
			art.mesh = quad
			art.material_override = mat
			art.position = Vector3(0, 0.74, 0.96)
			on.add_child(art)
	var slogan := progress.worn("rickshaw", "slogan")
	if not slogan.is_empty():
		var board := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.92, 0.12, 0.025)
		board.mesh = box
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color("1C3E7B")
		board.material_override = paint
		board.position = Vector3(0, 0.47, 0.95)
		on.add_child(board)
		var words := Label3D.new()
		words.name = "BackSlogan"
		words.text = str(strings.both("look_" + str(slogan.id)).get("bn", ""))
		words.font = Look.font(Look.BOLD)
		words.font_size = 64
		words.pixel_size = 0.0016
		words.outline_size = 12
		words.modulate = Look.YELLOW
		words.outline_modulate = Color("7B1FA2")
		words.position = Vector3(0, 0.47, 0.965)
		on.add_child(words)


## In the first days: driving past a waiting passenger, a word to stop
## beside them (easy driving stops by itself).
func _stop_hint() -> void:
	if mode != "rickshaw" or shift.easy or not shift.riding.is_empty() or not shift.offer_for.is_empty() \
			or shift.speed_now <= 0.6 or int(progress.data.rickshaw.get("days", 0)) >= 5:
		return
	for w in shift.waiting:
		if not w.refused and shift._near(w.at) <= 2 and not _stop_hinted.has(w.at):
			_stop_hinted[w.at] = true
			_say(strings.t("stopForPassenger"), Look.MAGENTA, 3.0)
			return


## Tired: a reminder now and then to stop for tea, until he does.
func _tired_nag(dt: float) -> void:
	if shift.energy >= float(shift.balance.n("rickshaw.tired_below")) or shift.worn_out:
		_nag_left = float(shift.balance.n("rickshaw.tired_nag_s"))
		return
	_nag_left -= dt
	if _nag_left <= 0.0 and _notice == "":
		_nag_left = float(shift.balance.n("rickshaw.tired_nag_s"))
		_say(strings.t("tiredAgain", {"n": int(shift.energy)}), Look.VERMILION, 4.0)


## A funny moment: a line from a group, shown and (when made) spoken.
func _funny(group: String) -> void:
	var line := Chatter.pick(group, strings.lang)
	if line.is_empty():
		return
	_voice.play(str(line.id), true)
	_say(str(line.text), Look.MAGENTA, 4.5)
