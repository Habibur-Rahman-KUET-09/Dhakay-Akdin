## What the player reads while driving: the way to the destination (an
## arrow turned to where it lies from the rickshaw's point of view), its
## name and distance, trips, a message, the whole map in small, and the
## OpenStreetMap credit.
extends CanvasLayer

const Look = preload("res://scripts/ui/look.gd")
const RoadMap = preload("res://scripts/rules/road_map.gd")

signal back_pressed

var s
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


func setup(strings, road_map: RoadMap) -> void:
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

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_bottom = -14
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	var credit := Look.label(map.credit, 11)
	credit.add_theme_color_override("font_color", Look.OUTLINE.lerp(Color.WHITE, 0.2))
	bottom.add_child(credit)
	_notice_box = PanelContainer.new()
	_notice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice = Look.label("", 16, true)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_box.add_child(_notice)
	bottom.add_child(_notice_box)


func _mini_image() -> Image:
	var img := Image.create(map.width * MINI_PX, map.height * MINI_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0.97, 0.9, 0.75))
	for p in map.roads():
		var c := Color("50555E") if map.kind_at(p) == RoadMap.Kind.MAIN_ROAD else Color("9AA0A6")
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
func refresh(target: String, trips: int, angle: float, notice: String, notice_colour: Color, me: Vector2, goal: Vector2i) -> void:
	_target.text = target
	_trips.text = s.t("rickshawTrips", {"count": trips})
	if absf(angle - _angle) > 0.01:
		_angle = angle
		_arrow.queue_redraw()
	if me != _me or goal != _goal:
		_me = me
		_goal = goal
		_mini.queue_redraw()
	var text := notice if notice != "" else s.t("rickshawHint")
	if _notice.text != text:
		_notice.text = text
		var fill := notice_colour if notice != "" else Look.CREAM
		_notice_box.add_theme_stylebox_override("panel", Look.card(fill))
		_notice.add_theme_color_override("font_color", Color.WHITE if notice != "" else Look.OUTLINE)
