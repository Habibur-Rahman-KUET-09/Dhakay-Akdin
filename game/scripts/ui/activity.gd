## A hand activity over the scene: a card in the lower half with a title,
## a hint, a drawing area the fingers work in, and a "quick" button that
## skips it (the plain button's result, as before). Emits `done` with a
## score from 0 to 1 (rules/activities.gd), once. Activities extend this,
## drawing in `_paint(c)` and taking touches in `_touch(event)`; the
## mouse stands in for a finger (Godot sends the first finger as one).
## Whether the player wants activities at all is a setting.
extends Control

const Look = preload("res://scripts/ui/look.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Rules = preload("res://scripts/rules/activities.gd")
const ReadAloud = preload("res://scripts/ui/read_aloud.gd")
const SETTINGS := "user://settings.cfg"

signal done(score: float)

var s: Strings
var title := ""
var hint := ""
## Whether the scene's clock slows while it is open (most do; the stove
## does not, since it is about time).
var slow := true
## Set when skipped with the quick button.
var quick := false
## The card's column, and a row of buttons under the drawing area.
var column: VBoxContainer
var buttons: HBoxContainer
## Where the fingers work; activities draw into it.
var canvas: Control
var _hint_label: Label
var _finished := false
## Seconds since it opened.
var t := 0.0


static func wanted() -> bool:
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		return bool(c.get_value("play", "hands", true))
	return true


static func save_wanted(value: bool) -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("play", "hands", value)
	c.save(SETTINGS)


## A short buzz of the phone (where it has one).
static func buzz(ms := 25) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func setup(strings: Strings, title_key: String, hint_key: String, values := {}) -> void:
	s = strings
	title = s.t(title_key, values)
	hint = s.t(hint_key, values)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if get_parent() is Window:
		size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(Look.CREAM, 18, 3))
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_top = 0.42
	panel.offset_left = 10
	panel.offset_right = -10
	panel.offset_top = 0
	panel.offset_bottom = -10
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	column = col
	var head := HBoxContainer.new()
	var name_label := Look.label(title, 19, true, Look.MAGENTA)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var quick := Look.button(s.t("quick"), Color("8A8178"), 14)
	quick.pressed.connect(_quick)
	head.add_child(quick)
	col.add_child(head)
	_hint_label = Look.label(hint, 14)
	col.add_child(_hint_label)
	canvas = Control.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_touch)
	col.add_child(canvas)
	buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	col.add_child(buttons)
	_build()
	ReadAloud.say("%s। %s" % [title, _hint_label.text], s.lang)


## Activities add their own buttons or labels here.
func _build() -> void:
	pass


func _process(dt: float) -> void:
	t += dt
	_tick(dt)
	if canvas != null:
		canvas.queue_redraw()


func _tick(_dt: float) -> void:
	pass


func _draw_canvas() -> void:
	_paint(canvas)


func _paint(_c: Control) -> void:
	pass


func _touch(_event) -> void:
	pass


func set_hint(text: String) -> void:
	if _hint_label != null:
		_hint_label.text = text


## A button under the drawing area.
func add_button(key: String, colour: Color, then: Callable) -> Button:
	var b := Look.button(s.t(key), colour, 16)
	b.custom_minimum_size = Vector2(0, 50)
	b.pressed.connect(then)
	buttons.add_child(b)
	return b


## Skipped: the result of the plain button, neither good nor bad.
func _quick() -> void:
	quick = true
	finish(0.5)


func finish(score: float) -> void:
	if _finished:
		return
	_finished = true
	done.emit(clampf(score, 0.0, 1.0))
	queue_free()


## Helpers for drawing.
static func text_at(c: Control, at: Vector2, text: String, px := 18, colour := Look.OUTLINE) -> void:
	var font := Look.font(Look.BOLD)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	c.draw_string(font, at - Vector2(w / 2.0, -px / 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, colour)


static func bar(c: Control, r: Rect2, value: float, colour: Color, marks: Array = []) -> void:
	c.draw_rect(r, Color("E8E0CF"))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(value, 0.0, 1.0), r.size.y)), colour)
	for m in marks:
		var x: float = r.position.x + r.size.x * float(m)
		c.draw_line(Vector2(x, r.position.y - 4), Vector2(x, r.end.y + 4), Look.OUTLINE, 2.0)
	c.draw_rect(r, Look.OUTLINE, false, 2.0)
