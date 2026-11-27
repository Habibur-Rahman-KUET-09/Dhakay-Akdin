## Kashem Bhai's day (phase 8): selling peanuts on the buses along Babu's
## route. At a stop he waits on the pavement and watches for a bus; on
## board, the camera stands at the front looking down the aisle at the
## riders' faces. Call out with the moving marker ("Badam! Badam!"), sell
## to each raised hand, and get off before the conductor puts him off.
## The bus scene's street, seats and riders are reused (bus_scene.gd);
## hawker_day.gd has the rules.
extends "res://scripts/world/bus_scene.gd"

const HawkerDay = preload("res://scripts/rules/hawker_day.gd")

## Buyers listed at once, nearest first.
const SHOWN_BUYERS := 4

var hk: HawkerDay
var _inside: MeshInstance3D
var _outside_bus: MeshInstance3D
var _hands := {}
var _hand_mesh: BoxMesh
var _hand_paint: StandardMaterial3D
var _basket: Node3D
var _marker_t := 0.0
var _buyer_col: VBoxContainer
var _off_button: Button
var _call_note: Label
var _sign_set := false
var _rain_said := false
var _ending := false
var _boost: Dictionary = {}


func _ready() -> void:
	strings.lang = Strings.saved_lang()
	b = Balance.new()
	progress = Progress.new(b)
	hk = HawkerDay.new(b, -1, progress.data.hawker.upgrades, progress.date())
	_boost = progress.take_boost("hawker")
	if not _boost.is_empty():
		hk.want_factor = float(_boost.get("arrivals", 1.0))
		_boost_name = strings.t("boost_" + str(_boost.id))
	_call_rng.randomize()
	var call_share := HomeCall.plan(_call_rng, progress.level())
	if call_share >= 0.0:
		_call_at = call_share * hk.day_seconds
	set_process(false)
	var loading := _loading_screen()
	await _step("environment")
	_environment()
	await _step("bus")
	for hex in Traffic.PALETTE:
		_palette.append(Color(hex))
	_inside = MeshInstance3D.new()
	_inside.mesh = Models.bus_interior()
	_inside.material_override = Models.material()
	add_child(_inside)
	_seats = Models.bus_seats()
	_standing = Models.bus_standing()
	_sitter_mesh = Models.bench_sitter()
	_stander_mesh = Models.person()
	for k in Models.PEOPLE:
		_sitter_meshes.append(Models.bench_sitter(k))
		_stander_meshes.append(Models.person(k))
	# The bus he waits for, seen from the pavement as it pulls in.
	_outside_bus = MeshInstance3D.new()
	_outside_bus.mesh = Models.bus()
	var paint := Models.traffic_material(PackedColorArray([Color("C62828"), Color("F6B800")]), false)
	paint.set_shader_parameter("custom_data", Vector4(0, 0, 0, 1))
	_outside_bus.material_override = paint
	_outside_bus.position = Vector3(-4.6, -0.9, 200)
	add_child(_outside_bus)
	# A raised hand, and a little packet count over it, for each buyer.
	_hand_mesh = BoxMesh.new()
	_hand_mesh.size = Vector3(0.09, 0.3, 0.06)
	_hand_paint = StandardMaterial3D.new()
	_hand_paint.albedo_color = Color("C68A5E")
	await _step("street")
	_build_street()
	camera = Camera3D.new()
	camera.fov = 70
	camera.near = 0.05
	camera.far = 200
	add_child(camera)
	_build_basket()
	await _step("sounds")
	_sounds()
	await _step("hud")
	_build_hud()
	_view()
	CrashWatch.start("hawker: graphics " + Graphics.level())
	Graphics.apply(get_viewport(), _env, _sun)
	await _step("done")
	loading.queue_free()
	set_process(true)
	var hello := strings.t("hawkerStart")
	if hk.hot:
		hello += "\n" + strings.t("hkHot")
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
	var text := Look.label(strings.t("hawkerLoading"), 22, true)
	text.set_anchors_preset(Control.PRESET_CENTER)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(text)
	layer.add_child(Tips.card(strings))
	add_child(layer)
	return layer


func _step(what: String) -> void:
	CrashWatch.start("hawker: " + what)
	print("[hawker] ", what, " ", Time.get_ticks_msec(), " ms")
	await get_tree().process_frame


## His basket, low in front of him: cane (or a bought colour) with a
## cloth over it and packets of peanuts on top.
func _build_basket() -> void:
	var look := progress.worn("hawker", "basket")
	var cane := Color(str(look.get("basket", "C8A165")))
	var cloth := Color(str(look.get("cloth", "B3261E")))
	_basket = Node3D.new()
	camera.add_child(_basket)
	_basket.position = Vector3(0.32, -0.42, -0.75)
	var body := MeshInstance3D.new()
	var tub := CylinderMesh.new()
	tub.top_radius = 0.2
	tub.bottom_radius = 0.15
	tub.height = 0.16
	body.mesh = tub
	var m := StandardMaterial3D.new()
	m.albedo_color = cane
	m.roughness = 0.9
	body.material_override = m
	_basket.add_child(body)
	var top := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.19
	disc.bottom_radius = 0.19
	disc.height = 0.02
	top.mesh = disc
	var cm := StandardMaterial3D.new()
	cm.albedo_color = cloth
	top.material_override = cm
	top.position.y = 0.08
	_basket.add_child(top)
	var packet := BoxMesh.new()
	packet.size = Vector3(0.05, 0.08, 0.03)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("E8C98A")
	for i in 5:
		var p := MeshInstance3D.new()
		p.mesh = packet
		p.material_override = pm
		p.position = Vector3(-0.1 + i * 0.05, 0.13, 0.02 * (i % 2))
		p.rotation.z = 0.2 * (i - 2)
		_basket.add_child(p)


func _stop_name(i: int) -> String:
	return strings.t("stop_" + hk.stop_id(i))


## On the bus: at the front, looking down the aisle at the riders. At a
## stop: on the pavement, looking back up the road for the next bus.
func _view() -> void:
	_inside.visible = hk.on_bus
	_outside_bus.visible = not hk.on_bus
	_basket.visible = hk.on_bus
	if hk.on_bus:
		camera.position = Vector3(0.0, 1.8, -4.2)
		camera.look_at(Vector3(0.0, 0.7, 4.5))
	else:
		camera.position = Vector3(-8.1, 0.95, -8.0)
		camera.look_at(Vector3(-4.0, 0.5, 12.0))
		_stop_label.text = _stop_name(hk.stop_i)
		_stop_sign.position.z = -2.5
		_sign_set = true
	_sync_people()


# --- People on the bus ---------------------------------------------------------


## The riders in their seats, facing him; a raised hand over each buyer.
func _sync_people() -> void:
	var here := {}
	if hk.on_bus:
		for r in hk.riders:
			here[r.id] = r
	for id in _people.keys():
		if not here.has(id):
			(_people[id] as Node3D).queue_free()
			_people.erase(id)
	for id in _hands.keys():
		if not here.has(id) or not _wants(here[id]):
			(_hands[id] as Node3D).queue_free()
			_hands.erase(id)
	for id in here:
		var r: Dictionary = here[id]
		var spot := int(r.seat)
		var seated := spot < _seats.size()
		var p: Vector2 = _seats[spot] if seated else _standing[mini(spot - _seats.size(), _standing.size() - 1)]
		if not _people.has(id):
			var person := MeshInstance3D.new()
			person.material_override = _paint_for(r)
			person.mesh = (_sitter_meshes if seated else _stander_meshes)[int(id) % Models.PEOPLE]
			add_child(person)
			_people[id] = person
			person.position = Vector3(p.x, 0.0 if seated else 0.02, p.y + (0.05 if seated else 0.0))
		if _wants(r) and not _hands.has(id):
			var hand := Node3D.new()
			hand.position = Vector3(p.x + 0.12, 1.35 if seated else 1.75, p.y)
			var arm := MeshInstance3D.new()
			arm.mesh = _hand_mesh
			arm.material_override = _hand_paint
			hand.add_child(arm)
			var n := Label3D.new()
			# The seat number, as on the buyer's button below.
			n.text = "%d · %s %d" % [int(r.seat) + 1, strings.t("item_" + str(r.item)), int(r.wants)]
			n.font = Look.font(Look.BOLD)
			n.font_size = 28
			n.outline_size = 8
			n.fixed_size = true
			n.modulate = Look.YELLOW if r.item == "badam" else Look.SKY
			n.outline_modulate = Look.OUTLINE
			n.pixel_size = 0.0012
			n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			n.no_depth_test = true
			n.position = Vector3(0, 0.22, 0)
			hand.add_child(n)
			add_child(hand)
			_hands[id] = hand


func _wants(r: Dictionary) -> bool:
	return bool(r.shown) and int(r.wants) > 0


func _paint_for(r: Dictionary) -> ShaderMaterial:
	var id := int(r.id)
	var paint := Models.traffic_material(PackedColorArray([_palette[id * 5 % 8], _palette[8 + id * 3 % 8]]), false)
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
	var stop_box := PanelContainer.new()
	stop_box.add_theme_stylebox_override("panel", Look.card(Look.CREAM.lerp(Color.WHITE, 0.3)))
	stop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_stop = Look.label("", 16, true)
	_next_stop.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stop_box.add_child(_next_stop)
	row.add_child(stop_box)
	var status_box := PanelContainer.new()
	status_box.add_theme_stylebox_override("panel", Look.card())
	_status = Look.label("", 15, true)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_box.add_child(_status)
	row.add_child(status_box)
	_route_bar = Control.new()
	_route_bar.custom_minimum_size = Vector2(0, 22)
	_route_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route_bar.draw.connect(_draw_route)
	top.add_child(_route_bar)
	# Calling out: a bar with a marker running to and fro.
	_call_box = PanelContainer.new()
	_call_box.add_theme_stylebox_override("panel", Look.card(Color.WHITE, 14, 3))
	var call_col := VBoxContainer.new()
	_call_box.add_child(call_col)
	_call_title = Look.label(strings.t("hkCallTitle"), 18, true, Look.MAGENTA)
	_call_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	call_col.add_child(_call_title)
	_call_bar = Control.new()
	_call_bar.custom_minimum_size = Vector2(0, 34)
	_call_bar.draw.connect(_draw_call)
	call_col.add_child(_call_bar)
	var call_button := Look.button(strings.t("hkCallButton"), Look.MAGENTA, 20)
	call_button.name = "CallOut"
	call_button.custom_minimum_size = Vector2(0, 56)
	call_button.pressed.connect(_on_call)
	call_col.add_child(call_button)
	_call_box.visible = false
	top.add_child(_call_box)
	_call_note = Look.label(strings.t("hkCalled"), 14, true, Color.WHITE)
	_call_note.add_theme_color_override("font_outline_color", Look.OUTLINE)
	_call_note.add_theme_constant_override("outline_size", 6)
	_call_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_call_note.visible = false
	top.add_child(_call_note)
	# Bottom: the notice, the buyers, getting off.
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
	_buyer_col = VBoxContainer.new()
	_buyer_col.add_theme_constant_override("separation", 6)
	bottom.add_child(_buyer_col)
	_off_button = Look.button(strings.t("hkGetOff"), Look.VERMILION, 20)
	_off_button.name = "GetOff"
	_off_button.custom_minimum_size = Vector2(0, 60)
	_off_button.pressed.connect(_on_get_off)
	bottom.add_child(_off_button)
	_refresh()


## Brings the screen up to date.
func _refresh() -> void:
	if hk.on_bus:
		var next_i := hk.stop_i if hk.at_stop else clampi(hk.stop_i + hk.dir, 0, hk.route.size() - 1)
		_next_stop.text = strings.t("atStopNow" if hk.at_stop else "nextStop", {"stop": _stop_name(next_i)})
	else:
		_next_stop.text = strings.t("hkWaiting", {"stop": _stop_name(hk.stop_i)})
	var h := int(hk.hour())
	var clock := strings.num("%d:%02d" % [((h - 1) % 12) + 1, int((hk.hour() - h) * 60.0)])
	var lines := PackedStringArray([clock, strings.t("taka", {"n": hk.earned()}), strings.t("hkBasket", {"n": hk.stock})])
	if hk.on_bus:
		lines.append(strings.t("hkStops", {"n": hk.ridden, "free": hk.free_stops}))
	_status.text = "\n".join(lines)
	_route_bar.queue_redraw()
	_call_box.visible = hk.on_bus and not hk.called and not hk.riders.is_empty()
	_call_note.visible = hk.on_bus and hk.called
	_off_button.visible = hk.on_bus and hk.at_stop
	_off_button.text = strings.t("hkGetOff")
	_fill_buyers()


## A button for each raised hand (a few at a time): tap to hand it over.
func _fill_buyers() -> void:
	var want := hk.buyers().slice(0, SHOWN_BUYERS) if hk.on_bus else []
	var ids := want.map(func(r): return int(r.id))
	var live := _buyer_col.get_children().filter(func(k): return not k.is_queued_for_deletion())
	var have := live.map(func(k): return int(k.get_meta("id", -1)))
	if ids == have:
		return
	# Hidden now and freed after this frame: the button being pressed may
	# still be handling its press.
	for k in live:
		k.visible = false
		k.queue_free()
	for r in want:
		var n := int(r.wants)
		if r.item == "badam":
			n = mini(n, hk.stock)
		var text := strings.t("hkBuyer", {"seat": int(r.seat) + 1, "item": strings.t("item_" + str(r.item)), "n": n, "taka": n * hk.price(str(r.item))})
		var button := Look.button(text, Look.PARROT if r.item == "badam" else Look.SKY.darkened(0.2), 15)
		button.set_meta("id", int(r.id))
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_on_sell.bind(int(r.id)))
		_buyer_col.add_child(button)


func _process(dt: float) -> void:
	_alive_left -= dt
	if _alive_left <= 0.0:
		_alive_left = 10.0
		print("[alive] %d ms, %d fps" % [Time.get_ticks_msec(), Engine.get_frames_per_second()])
	var pace := 0.35 if _activity != null and _activity.slow else 1.0
	var was_raining := hk.raining
	_handle(hk.update(dt * pace))
	if not is_processing():
		return
	if hk.raining and not was_raining and not _rain_said:
		_rain_said = true
		_say(strings.t("hkRain"), Look.SKY, 3.0)
	# A call from home: at a stop, or after half a minute's wait for one.
	if _call_at >= 0.0 and hk.clock >= _call_at and _activity == null \
			and (hk.at_stop or not hk.on_bus or hk.clock >= _call_at + 30.0):
		_call_at = -1.0
		_ring_home()
	# The street slides by while the bus goes; still while it stands.
	var want := 0.0
	if hk.on_bus and not hk.at_stop:
		want = SPEED * clampf(hk.travel_left / 2.5, 0.25, 1.0)
	_speed = move_toward(_speed, want, dt * 6.0)
	_distance += _speed * dt
	_scenery.position.z = fmod(_distance, PERIOD)
	_stop_sign.position.z += _speed * dt
	if hk.on_bus:
		# The next stop's sign comes into view up ahead.
		if not hk.at_stop and not _sign_set and hk.travel_left < 1.6:
			_sign_set = true
			_stop_label.text = _stop_name(clampi(hk.stop_i + hk.dir, 0, hk.route.size() - 1))
			_stop_sign.position.z = -14.0
		camera.position.y = 1.8 + sin(_distance * 0.9) * 0.015 * minf(1.0, _speed / SPEED)
	else:
		# The next bus pulls in from up the road.
		var left := hk.wait_left
		_outside_bus.visible = left < 4.0
		_outside_bus.position.z = minf(left, 4.0) * minf(left, 4.0) * 6.0
	if _notice_left > 0.0:
		_notice_left -= dt
		if _notice_left <= 0.0:
			_notice_box.visible = false
	_marker_t += dt
	if _call_box.visible:
		_call_bar.queue_redraw()
	_refresh()


## Where the marker is on the call bar, 0–1.
func _marker() -> float:
	return 0.5 + 0.5 * sin(_marker_t * 3.2)


func _draw_call() -> void:
	var w := _call_bar.size.x
	var h := _call_bar.size.y
	_call_bar.draw_rect(Rect2(0, 6, w, h - 12), Color("E8E0CF"))
	_call_bar.draw_rect(Rect2(w * 0.3, 6, w * 0.4, h - 12), Look.YELLOW)
	_call_bar.draw_rect(Rect2(w * 0.42, 6, w * 0.16, h - 12), Look.PARROT)
	var x := w * _marker()
	_call_bar.draw_rect(Rect2(x - 4, 0, 8, h), Look.OUTLINE)


func _draw_route() -> void:
	var w := _route_bar.size.x
	var y := _route_bar.size.y / 2.0
	var n := hk.route.size()
	_route_bar.draw_line(Vector2(10, y), Vector2(w - 10, y), Look.OUTLINE, 3.0)
	for i in n:
		var x := lerpf(10.0, w - 10.0, float(i) / (n - 1))
		_route_bar.draw_circle(Vector2(x, y), 6.0, Look.YELLOW if i == hk.stop_i else Color.WHITE)
		_route_bar.draw_arc(Vector2(x, y), 6.0, 0, TAU, 12, Look.OUTLINE, 2.0)
	var along := float(hk.stop_i)
	if hk.on_bus and not hk.at_stop:
		var between: Array = b.at("bus.seconds_between_stops")
		var whole := (float(between[0]) + float(between[1])) / 2.0
		along += hk.dir * clampf(1.0 - hk.travel_left / whole, 0.0, 0.95)
	var bx := lerpf(10.0, w - 10.0, along / (n - 1))
	_route_bar.draw_rect(Rect2(bx - 9, y - 7, 18, 14), Look.VERMILION if hk.on_bus else Look.MUTED)


func _handle(events: Array) -> void:
	if events.has(HawkerDay.Event.BUS_CAME):
		print("[hawker] bus %d at %s, %d riders%s" % [hk.buses, hk.stop_id(hk.stop_i), hk.riders.size(), " (Babu's)" if hk.babus else ""])
		_thump.play()
		_say(strings.t("hkBabuBus" if hk.babus else "hkBusCame"), Look.SKY, 3.0)
		_view()
	if events.has(HawkerDay.Event.ARRIVED):
		if absf(_stop_sign.position.z + 2.5) > 4.0:
			_stop_sign.position.z = -2.5
		_stop_label.text = _stop_name(hk.stop_i)
		if events.has(HawkerDay.Event.WARNED):
			_say(strings.t("hkWarned"), Look.VERMILION, 3.0)
		_sync_people()
	if events.has(HawkerDay.Event.DEPARTED):
		_sign_set = false
		_sync_people()
	if events.has(HawkerDay.Event.THROWN_OFF):
		print("[hawker] thrown off at ", hk.stop_id(hk.stop_i))
		_say(strings.t("hkThrown", {"n": int(b.n("hawker.dropped"))}), Look.VERMILION, 3.5)
		_view()
	if events.has(HawkerDay.Event.DAY_OVER):
		_end_day()


func _on_call() -> void:
	if not hk.on_bus or hk.called:
		return
	var quality := HawkerDay.call_quality(_marker())
	var n := hk.shout(quality)
	_thump.play()
	_say(strings.t("hkCall_" + quality, {"n": n}), Look.PARROT if quality != "miss" else Look.OUTLINE, 2.5)
	_sync_people()
	_refresh()


func _on_sell(id: int) -> void:
	var got := hk.sell(id)
	if not got.has(HawkerDay.Event.SOLD):
		return
	_coin.play()
	var s := hk.last_sale
	_say(strings.t("hkSold", {"item": strings.t("item_" + str(s.item)), "n": int(s.n), "taka": int(s.taka)}), Look.PARROT, 1.5)
	_sync_people()
	if got.has(HawkerDay.Event.SOLD_OUT):
		_say(strings.t("hkSoldOut"), Look.MAGENTA, 3.0)
		if hk.sold_out():
			set_process(false)
			get_tree().create_timer(2.0).timeout.connect(_end_day)
	_refresh()


func _on_get_off() -> void:
	if hk.get_off().has(HawkerDay.Event.GOT_OFF):
		_say(strings.t("hkGotOff"), Look.SKY, 2.0)
		_view()
	_refresh()


func _closed() -> void:
	_activity = null
	_refresh()


func _ring_home() -> void:
	var call := HomeCall.new().pick("hawker", _call_rng, progress.family("hawker"))
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
	var now := progress.add_family("hawker", e.family)
	hk.money -= e.cost
	_call_result = {"family": now, "delta": e.family}
	print("[home] call ", act.call.get("id", ""), ": ", option, ", family ", now)
	if e.family > 0:
		_say(strings.t("familyUp", {"n": now}), Look.PARROT, 3.0)
	elif e.family < 0:
		_say(strings.t("familyDown", {"n": now}), Look.VERMILION, 3.0)
	if e.end_day:
		hk.clock = hk.day_seconds


func _end_day() -> void:
	if _ending:
		return
	_ending = true
	print("[hawker] day over ", Time.get_ticks_msec(), " ms")
	set_process(false)
	hk.over = true
	_call_box.visible = false
	_off_button.visible = false
	for k in _buyer_col.get_children():
		k.queue_free()
	var earned := hk.earned()
	var stars := hk.stars()
	var stats := {"sold": hk.sold, "earned": earned, "clean": 1 if hk.thrown == 0 and hk.sold >= 30 else 0}
	var got := progress.apply_hawker_day({"earned": earned, "sold": hk.sold, "stars": stars, "stats": stats})
	progress.save()
	load("res://scripts/ui/cloud.gd").backup(self, progress.data)
	CrashWatch.stop()
	var lines := [strings.t("hkSoldLine", {"n": hk.sold})]
	if hk.water_sold > 0:
		lines.append(strings.t("hkWaterLine", {"n": hk.water_sold}))
	lines.append(strings.t("hkBusesLine", {"n": hk.buses}))
	if hk.thrown > 0:
		lines.append(strings.t("hkThrownLine", {"n": hk.thrown}))
	lines.append(strings.t("hkOwedLine", {"n": hk.cost()}))
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
	end.name = "DayEnd"
	end.setup(strings, b, progress, got, {
		"title": strings.t("hkDayOver"),
		"stars": stars,
		"sub": strings.t("hkRatingLine", {"stars": "%.1f" % stars}),
		"money": earned,
		"lines": lines,
		"share": strings.t("share_hawker", {"n": hk.sold, "money": earned}) if hk.sold > 0 else "",
	})
	end.home_pressed.connect(_go_home)
	end.again_pressed.connect(_again)
	_layer.add_child(end)


func _again() -> void:
	CrashWatch.start("hawker")
	get_tree().reload_current_scene.call_deferred()
