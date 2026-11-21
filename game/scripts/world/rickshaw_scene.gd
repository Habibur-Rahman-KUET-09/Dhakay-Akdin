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
const RickshawModel = preload("res://scripts/world/rickshaw_model.gd")
const Hud = preload("res://scripts/ui/hud.gd")

const SWIPE_PX := 36.0
const CAMERA_BACK := 8.5
const CAMERA_UP := 9.5

var strings := Strings.new()
var shift: Shift
var rickshaw: Node3D
var camera: Camera3D
var marker: Node3D
var hud: Hud
var _yaw := 0.0
var _notice := ""
var _notice_colour := Look.OUTLINE
var _notice_left := 0.0
var _touch_start := Vector2.ZERO
var _touch_used := true


func _ready() -> void:
	strings.lang = Strings.saved_lang()
	var map: RoadMap = RoadMap.load_area("mirpur")
	var b := Balance.new()
	shift = Shift.new(map, b.n("rickshaw.speed_tiles_per_s"), b.n("rickshaw.waterlog_speed"))
	_environment()
	add_child(City.build(map, strings.lang))
	rickshaw = RickshawModel.build()
	add_child(rickshaw)
	marker = _marker()
	add_child(marker)
	camera = Camera3D.new()
	camera.fov = 62
	camera.far = 160
	add_child(camera)
	camera.current = true
	hud = Hud.new()
	hud.setup(strings, map)
	hud.back_pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	add_child(hud)
	_yaw = _yaw_for(shift.driver.heading)
	_place_marker()
	_follow(0.0, true)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("C9DDEA")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("F3E9D8")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color("D9E1E4")
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("FFF1D6")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
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
	rickshaw.position = Vector3((pos.x + 0.5) * City.T, 0, (pos.y + 0.5) * City.T)
	var want := _yaw_for(d.heading)
	if snap:
		rickshaw.rotation.y = want
		_yaw = want
	else:
		rickshaw.rotation.y = lerp_angle(rickshaw.rotation.y, want, minf(1.0, dt * 10.0))
		_yaw = lerp_angle(_yaw, want, minf(1.0, dt * 3.5))
	if d.moving:
		for w in rickshaw.get_meta("wheels"):
			w.rotate_x(-dt * d.speed * 4.0)
	var forward := Vector3(-sin(_yaw), 0, -cos(_yaw))
	camera.position = rickshaw.position - forward * CAMERA_BACK + Vector3.UP * CAMERA_UP
	camera.look_at(rickshaw.position + forward * 5.0 + Vector3.UP * 0.5)


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
	hud.refresh(target, shift.delivered, angle, _notice, _notice_colour, me, shift.destination)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_touch_used = false
		return
	if event is InputEventScreenDrag and not _touch_used:
		var moved: Vector2 = event.position - _touch_start
		if moved.length() >= SWIPE_PX:
			_touch_used = true
			_turn(_swipe_turn(moved))
		return
	if event.is_action_pressed("ui_left"):
		_turn(Driver.LEFT)
	elif event.is_action_pressed("ui_right"):
		_turn(Driver.RIGHT)
	elif event.is_action_pressed("ui_down"):
		_turn(Driver.BACK)
	elif event.is_action_pressed("ui_up"):
		_turn(Driver.AHEAD)


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
