## What the player reads while driving: the way to the destination (an
## arrow turned to where it lies from the rickshaw's point of view), its
## name and distance, trips, a message, the whole map in small, and the
## OpenStreetMap credit.
extends CanvasLayer

const Look = preload("res://scripts/ui/look.gd")
const RoadMap = preload("res://scripts/rules/road_map.gd")
const Strings = preload("res://scripts/ui/strings.gd")

signal back_pressed
signal offer_accept
signal offer_counter
signal offer_refuse
signal again_pressed
signal tea_pressed
signal pump_pressed

var s: Strings
var map: RoadMap
var _target: Label
var _trips: Label
var _notice: Label
var _notice_box: PanelContainer
var _arrow: Control
var _mini: Control
var _mini_texture: ImageTexture
## Set each frame by refresh().
var _angle := 0.0
var _me := Vector2.ZERO
var _goal := Vector2i.ZERO

const MINI_PX := 3
const PEDAL_SIZE := Vector2(132, 132)
const BRAKE_SIZE := Vector2(104, 104)

## The pedal (right) and brake (left) buttons. They do not take touches
## themselves: the scene reads touches by finger, so one finger can pedal
## while another swipes.
var pedal_button: Panel
var bell_button: Panel
var brake_button: Panel
var _speed: Label
var _pedal_down := false
var _offer_box: PanelContainer
var _offer_title: Label
var _offer_sub: Label
var _counter_button: Button
var _end_layer: Control
var _brake_down := false
var _energy_bar: ProgressBar
var _energy_fill: StyleBoxFlat
var _energy_text: Label
var _energy_shown := -1
var _tea_button: Button
var _pump_button: Button


func setup(strings: Strings, road_map: RoadMap) -> void:
	s = strings
	map = road_map


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 8
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var back := Look.button(s.t("back"), Look.OUTLINE, 15)
	back.name = "Back"
	back.pressed.connect(func(): back_pressed.emit())
	top.add_child(back)
	var target_box := PanelContainer.new()
	target_box.add_theme_stylebox_override("panel", Look.card(Look.CREAM.lerp(Color.WHITE, 0.3)))
	target_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	target_box.add_child(row)
	_arrow = Control.new()
	_arrow.custom_minimum_size = Vector2(30, 30)
	_arrow.draw.connect(_draw_arrow)
	row.add_child(_arrow)
	_target = Look.label("", 16, true)
	_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_target)
	top.add_child(target_box)
	var trips_box := PanelContainer.new()
	trips_box.add_theme_stylebox_override("panel", Look.card())
	trips_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trips = Look.label("", 16, true)
	_trips.autowrap_mode = TextServer.AUTOWRAP_OFF
	trips_box.add_child(_trips)
	top.add_child(trips_box)

	# The whole map in small, under the top bar on the right.
	_mini_texture = ImageTexture.create_from_image(_mini_image())
	_mini = Control.new()
	_mini.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mini.offset_left = -map.width * MINI_PX - 10
	_mini.offset_right = -10
	_mini.offset_top = 72
	_mini.offset_bottom = 72 + map.height * MINI_PX
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini.draw.connect(_draw_mini)
	root.add_child(_mini)

	# Energy, under the map: a bar that turns from green to red.
	var energy := VBoxContainer.new()
	energy.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	energy.offset_left = -map.width * MINI_PX - 10
	energy.offset_right = -10
	energy.offset_top = 78 + map.height * MINI_PX
	energy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy.add_theme_constant_override("separation", 2)
	_energy_text = Look.label("", 14, true, Color.WHITE)
	_energy_text.add_theme_color_override("font_outline_color", Look.OUTLINE)
	_energy_text.add_theme_constant_override("outline_size", 5)
	energy.add_child(_energy_text)
	_energy_bar = ProgressBar.new()
	_energy_bar.max_value = 100
	_energy_bar.show_percentage = false
	_energy_bar.custom_minimum_size = Vector2(0, 12)
	_energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(1, 1, 1, 0.75)
	bar_bg.set_corner_radius_all(6)
	bar_bg.border_color = Look.OUTLINE
	bar_bg.set_border_width_all(2)
	_energy_fill = StyleBoxFlat.new()
	_energy_fill.bg_color = Look.PARROT
	_energy_fill.set_corner_radius_all(6)
	_energy_bar.add_theme_stylebox_override("background", bar_bg)
	_energy_bar.add_theme_stylebox_override("fill", _energy_fill)
	energy.add_child(_energy_bar)
	root.add_child(energy)

	# Tea, when stopped beside a stall.
	_tea_button = Look.button("", Color("8B5A2B"), 18)
	_tea_button.set_anchors_preset(Control.PRESET_CENTER)
	_tea_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tea_button.grow_vertical = Control.GROW_DIRECTION_BOTH
	_tea_button.offset_top = 120
	_tea_button.offset_bottom = 120
	_tea_button.pressed.connect(func(): tea_pressed.emit())
	_tea_button.visible = false
	root.add_child(_tea_button)
	# A soft tyre: the pump.
	_pump_button = Look.button(s.t("pumpButton"), Look.SKY.darkened(0.2), 18)
	_pump_button.set_anchors_preset(Control.PRESET_CENTER)
	_pump_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pump_button.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pump_button.offset_top = 180
	_pump_button.offset_bottom = 180
	_pump_button.pressed.connect(func(): pump_pressed.emit())
	_pump_button.visible = false
	root.add_child(_pump_button)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_bottom = -14
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	var controls := HBoxContainer.new()
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_vertical = Control.SIZE_SHRINK_END
	left.add_theme_constant_override("separation", 10)
	bell_button = _round_button(s.t("bell"), Vector2(78, 78), Look.YELLOW)
	bell_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(bell_button)
	brake_button = _round_button(s.t("brake"), BRAKE_SIZE, Look.VERMILION)
	left.add_child(brake_button)
	controls.add_child(left)
	_speed = Look.label("", 18, true)
	_speed.autowrap_mode = TextServer.AUTOWRAP_OFF
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed.size_flags_vertical = Control.SIZE_SHRINK_END
	_speed.add_theme_color_override("font_color", Color.WHITE)
	_speed.add_theme_color_override("font_outline_color", Look.OUTLINE)
	_speed.add_theme_constant_override("outline_size", 6)
	controls.add_child(_speed)
	pedal_button = _round_button(s.t("pedal"), PEDAL_SIZE, Look.PARROT)
	pedal_button.size_flags_vertical = Control.SIZE_SHRINK_END
	controls.add_child(pedal_button)
	bottom.add_child(controls)
	var credit := Look.label(map.credit, 11)
	credit.add_theme_color_override("font_color", Look.OUTLINE.lerp(Color.WHITE, 0.2))
	bottom.add_child(credit)
	_notice_box = PanelContainer.new()
	_notice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice = Look.label("", 16, true)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_box.add_child(_notice)
	bottom.add_child(_notice_box)
	_build_offer(root)


## The bargaining panel: where the passenger is going, their offer, and
## three buttons (agree, ask for more, no). Hidden until needed.
func _build_offer(root: Control) -> void:
	_offer_box = PanelContainer.new()
	_offer_box.add_theme_stylebox_override("panel", Look.card(Color.WHITE, 16, 3))
	_offer_box.set_anchors_preset(Control.PRESET_CENTER)
	_offer_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_offer_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_offer_box.custom_minimum_size = Vector2(380, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_offer_box.add_child(col)
	_offer_title = Look.label("", 20, true)
	_offer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_offer_title)
	_offer_sub = Look.label("", 15)
	_offer_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_offer_sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var agree := Look.button(s.t("agree"), Look.PARROT, 17)
	agree.pressed.connect(func(): offer_accept.emit())
	row.add_child(agree)
	_counter_button = Look.button("", Look.YELLOW.darkened(0.15), 17)
	_counter_button.pressed.connect(func(): offer_counter.emit())
	row.add_child(_counter_button)
	var no := Look.button(s.t("refuse"), Look.VERMILION, 17)
	no.pressed.connect(func(): offer_refuse.emit())
	row.add_child(no)
	col.add_child(row)
	_offer_box.visible = false
	root.add_child(_offer_box)


func show_offer(title: String, sub: String, counter_text: String) -> void:
	_offer_title.text = title
	_offer_sub.text = sub
	_counter_button.text = counter_text
	_offer_box.visible = true


func hide_offer() -> void:
	_offer_box.visible = false


## Where the offer buttons are, so touches there are not taken for swipes.
func offer_rect() -> Rect2:
	return _offer_box.get_global_rect() if _offer_box.visible else Rect2()


## The end of the day: the takings and two ways on.
func show_day_end(lines: Array, good: bool) -> void:
	_end_layer = ColorRect.new()
	(_end_layer as ColorRect).color = Color(0, 0, 0, 0.45)
	_end_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_end_layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(Look.CREAM, 18, 3))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(400, 0)
	_end_layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var title := Look.label(s.t("dayOver"), 28, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	for i in lines.size():
		var l := Look.label(lines[i], 18, i == lines.size() - 1, (Look.PARROT if good else Look.VERMILION) if i == lines.size() - 1 else Look.OUTLINE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var again := Look.button(s.t("nextDay"), Look.MAGENTA, 18)
	again.pressed.connect(func(): again_pressed.emit())
	row.add_child(again)
	var home := Look.button(s.t("toMohalla"), Look.PARROT, 18)
	home.pressed.connect(func(): back_pressed.emit())
	row.add_child(home)
	col.add_child(row)


func _round_button(text: String, size: Vector2, colour: Color) -> Panel:
	var b := Panel.new()
	b.custom_minimum_size = size
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("panel", Look.card(colour, int(size.x / 2), 4))
	var l := Look.label(text, 18, true, Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	b.set_meta("colour", colour)
	return b


## Shows a button pressed or not.
func _press(b: Panel, down: bool) -> void:
	var colour: Color = b.get_meta("colour")
	b.add_theme_stylebox_override("panel", Look.card(colour.darkened(0.3) if down else colour, int(b.custom_minimum_size.x / 2), 4))
	b.scale = Vector2.ONE * (0.94 if down else 1.0)
	b.pivot_offset = b.size / 2


## The tea button, with its price; hidden with show_tea(false).
func show_tea(shown: bool, price := 0) -> void:
	_tea_button.text = s.t("teaButton", {"n": price})
	_tea_button.visible = shown


func show_pump(shown: bool) -> void:
	_pump_button.visible = shown


func pump_rect() -> Rect2:
	return _pump_button.get_global_rect().grow(8) if _pump_button.visible else Rect2()


func tea_rect() -> Rect2:
	return _tea_button.get_global_rect().grow(8) if _tea_button.visible else Rect2()


## Energy 0–100: the bar, its colour and the number.
func show_energy(value: float) -> void:
	var n := clampi(ceili(value), 0, 100)
	if n == _energy_shown:
		return
	_energy_shown = n
	_energy_bar.value = n
	_energy_text.text = s.t("energy", {"n": n})
	_energy_fill.bg_color = Look.VERMILION if n < 20 else (Look.YELLOW if n < 50 else Look.PARROT)


## Where the buttons are, in the same coordinates as touch events.
func pedal_rect() -> Rect2:
	return pedal_button.get_global_rect().grow(16)


func brake_rect() -> Rect2:
	return brake_button.get_global_rect().grow(16)


func bell_rect() -> Rect2:
	return bell_button.get_global_rect().grow(10)


func show_controls(pedal: bool, brake: bool, kmh: float) -> void:
	if pedal != _pedal_down:
		_pedal_down = pedal
		_press(pedal_button, pedal)
	if brake != _brake_down:
		_brake_down = brake
		_press(brake_button, brake)
	var text := s.t("kmh", {"n": roundi(kmh)})
	if _speed.text != text:
		_speed.text = text


func _mini_image() -> Image:
	var img := Image.create(map.width * MINI_PX, map.height * MINI_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0.97, 0.9, 0.75))
	for p in map.roads():
		var c := Color("50555E") if map.kind_at(p) == RoadMap.Kind.MAIN_ROAD else Color("9AA0A6")
		if map.kind_at(p) == RoadMap.Kind.TEA:
			c = Color("8B5A2B")
		img.fill_rect(Rect2i(p * MINI_PX, Vector2i(MINI_PX, MINI_PX)), c)
	return img


func _draw_mini() -> void:
	_mini.draw_texture(_mini_texture, Vector2.ZERO)
	_mini.draw_rect(Rect2(Vector2.ZERO, _mini.size), Look.OUTLINE, false, 2.0)
	_mini.draw_circle((Vector2(_goal) + Vector2(0.5, 0.5)) * MINI_PX, 4.0, Look.VERMILION)
	_mini.draw_circle((_me + Vector2(0.5, 0.5)) * MINI_PX, 4.0, Look.MAGENTA)
	_mini.draw_arc((_me + Vector2(0.5, 0.5)) * MINI_PX, 4.0, 0, TAU, 12, Color.WHITE, 1.5)


func _draw_arrow() -> void:
	var c := _arrow.size / 2
	var pts := PackedVector2Array([Vector2(0, -13), Vector2(10, 11), Vector2(0, 5), Vector2(-10, 11)])
	for i in pts.size():
		pts[i] = c + pts[i].rotated(_angle)
	_arrow.draw_colored_polygon(pts, Look.VERMILION)
	_arrow.draw_polyline(pts + PackedVector2Array([pts[0]]), Look.OUTLINE, 2.0)


## target: the place name and tiles left (or a note when there is no legal
## way); angle: clockwise from straight ahead; notice: "" for the hint.
func refresh(target: String, status: String, angle: float, notice: String, notice_colour: Color, me: Vector2, goal: Vector2i) -> void:
	_target.text = target
	if _trips.text != status:
		_trips.text = status
	if absf(angle - _angle) > 0.01:
		_angle = angle
		_arrow.queue_redraw()
	if me != _me or goal != _goal:
		_me = me
		_goal = goal
		_mini.queue_redraw()
	var text: String = notice if notice != "" else s.t("rickshawHint")
	if _notice.text != text:
		_notice.text = text
		var fill := notice_colour if notice != "" else Look.CREAM
		_notice_box.add_theme_stylebox_override("panel", Look.card(fill))
		_notice.add_theme_color_override("font_color", Color.WHITE if notice != "" else Look.OUTLINE)
