## Reads a story chapter (§৬.২) as picture panels: the scene drawn above
## (a dawn yard, a street, the tea stall, the bus, a rainy night…, until
## real art arrives), the people in it standing along the bottom, and
## their lines one at a time below; tap for the next. A chapter may end in
## a choice. Emits `finished` with the chapter's id and the chosen
## effects.
extends Control

const Look = preload("res://scripts/ui/look.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Story = preload("res://scripts/rules/story.gd")

signal finished(chapter_id: String, effects: Dictionary)

## Women in the cast (drawn with long hair and a dress).
const WOMEN := ["rokeya", "sumi", "nasrin", "rumana", "joya", "sultana", "babu_ma"]

var story: Story
var chapter: Dictionary
var s: Strings
var _panels: Array = []
var _panel_i := 0
var _line_i := 0
var _effects := {}
var _choosing := false
var _picture: Control
var _title: Label
var _speaker: Label
var _speaker_box: PanelContainer
var _text: Label
var _hint: Label
var _choices: VBoxContainer
var _t := 0.0


func setup(the_story: Story, the_chapter: Dictionary, strings: Strings) -> void:
	story = the_story
	chapter = the_chapter
	s = strings
	_panels = chapter.panels.duplicate()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("1D1A1A")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 14
	col.offset_right = -14
	col.offset_top = 14
	col.offset_bottom = -14
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = Look.label("", 20, true, Look.YELLOW)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	var skip := Look.button(s.t("storySkip"), Color("4A4545"), 14)
	skip.pressed.connect(_skip)
	top.add_child(skip)
	col.add_child(top)
	_picture = Control.new()
	_picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.clip_contents = true
	_picture.draw.connect(_draw_picture)
	col.add_child(_picture)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.card(Look.CREAM, 16, 3))
	card.custom_minimum_size = Vector2(0, 190)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	_speaker_box = PanelContainer.new()
	_speaker_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_speaker_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker = Look.label("", 16, true, Color.WHITE)
	_speaker.autowrap_mode = TextServer.AUTOWRAP_OFF
	_speaker_box.add_child(_speaker)
	inner.add_child(_speaker_box)
	_text = Look.label("", 20)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	_choices.visible = false
	inner.add_child(_choices)
	_hint = Look.label(s.t("storyTap"), 13, false, Look.OUTLINE.lerp(Color.WHITE, 0.4))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inner.add_child(_hint)
	col.add_child(card)
	_show()


func _process(dt: float) -> void:
	# Rain falls, the lantern flickers.
	_t += dt
	_picture.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tap := (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tap and not _choosing:
		_next()
		accept_event()


func _lines() -> Array:
	return _panels[_panel_i].lines


func _show() -> void:
	_title.text = s.t("storyChapter", {"n": int(chapter.n), "title": chapter.title[s.lang]})
	var line: Dictionary = _lines()[_line_i]
	_speaker.text = story.speaker(line.by, s.lang)
	_speaker_box.add_theme_stylebox_override("panel", Look.card(story.colour(line.by), 10, 0))
	_text.text = line[s.lang]
	_picture.queue_redraw()


func _next() -> void:
	_line_i += 1
	if _line_i < _lines().size():
		_show()
		return
	_line_i = 0
	_panel_i += 1
	if _panel_i < _panels.size():
		_show()
		return
	_panel_i = _panels.size() - 1
	_line_i = _lines().size() - 1
	if chapter.has("choice") and not _effects.has("chosen"):
		_ask()
	else:
		_done()


## The chapter's choice: a question and a button for each answer; the
## answer's lines follow as one more panel.
func _ask() -> void:
	_choosing = true
	_hint.visible = false
	_speaker.text = s.t("storyChoice")
	_speaker_box.add_theme_stylebox_override("panel", Look.card(Look.MAGENTA, 10, 0))
	_text.text = chapter.choice.prompt[s.lang]
	for c in _choices.get_children():
		c.queue_free()
	for i in chapter.choice.options.size():
		var o: Dictionary = chapter.choice.options[i]
		var b := Look.button(o.label[s.lang], Look.PARROT if i == 0 else Look.VERMILION, 16)
		b.pressed.connect(_chose.bind(i))
		_choices.add_child(b)
	_choices.visible = true


func _chose(i: int) -> void:
	var o: Dictionary = chapter.choice.options[i]
	_effects = (o.effects as Dictionary).duplicate()
	_effects["chosen"] = i
	_choosing = false
	_choices.visible = false
	_hint.visible = true
	_panels.append({"scene": _panels.back().scene, "lines": o.lines})
	_panel_i = _panels.size() - 1
	_line_i = 0
	_show()


func _skip() -> void:
	if chapter.has("choice") and not _effects.has("chosen"):
		_panel_i = _panels.size() - 1
		_line_i = _lines().size() - 1
		_show()
		_ask()
	else:
		_done()


func _done() -> void:
	var effects := _effects.duplicate()
	effects.erase("chosen")
	finished.emit(chapter.id, effects)
	queue_free()


# --- The picture -------------------------------------------------------------


func _draw_picture() -> void:
	var area := _picture.size
	var scene: String = _panels[_panel_i].scene
	var night := scene.ends_with("night")
	var inside := scene == "bus_inside" or scene == "hospital"
	# Sky.
	var top: Color = {"home_dawn": Color("F2A65A"), "street_morning": Color("9DC3E6"), "tea_stall": Color("E9C27A"),
		"school": Color("A7D3F0"), "hospital": Color("DDEBE4"), "bus_inside": Color("EFE6D2")}.get(scene, Color("1E2A44"))
	var low: Color = {"home_dawn": Color("F8D9A0"), "street_morning": Color("E2EEF5"), "tea_stall": Color("F6E3B8"),
		"school": Color("E4F2FA"), "hospital": Color("F4F8F5"), "bus_inside": Color("D9CDB4")}.get(scene, Color("3A4566"))
	for i in 12:
		var y0 := area.y * i / 12.0
		_picture.draw_rect(Rect2(0, y0, area.x, area.y / 12.0 + 1), top.lerp(low, i / 11.0))
	var ground := area.y * 0.78
	if not inside:
		# The town behind: blocks of flats, windows lit at night.
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var x := 0.0
		while x < area.x:
			var w := rng.randf_range(50, 90)
			var h := rng.randf_range(area.y * 0.25, area.y * 0.5)
			var wall := Color("2A2F3A") if night else Color("C9BBA2").darkened(rng.randf_range(0.0, 0.25))
			_picture.draw_rect(Rect2(x, ground - h, w - 4, h), wall)
			for wy in range(int(ground - h + 10), int(ground - 14), 22):
				for wx in range(int(x + 8), int(x + w - 14), 16):
					var lit := night and rng.randf() < 0.45
					_picture.draw_rect(Rect2(wx, wy, 8, 10), Color("F6D365") if lit else Color("3B4250") if night else Color("6E7A86"))
			x += w
		_picture.draw_rect(Rect2(0, ground, area.x, area.y - ground), Color("4B4B4B") if scene != "home_dawn" and scene != "home_night" else Color("7A6A50"))
	match scene:
		"home_dawn", "home_night":
			_hut(Vector2(area.x * 0.68, ground), night)
		"street_morning":
			_rickshaw(Vector2(area.x * 0.72, ground + 4), 1.0)
		"rain_night":
			_rickshaw(Vector2(area.x * 0.7, ground + 4), 1.0)
			for i in 70:
				var rx := fmod(i * 37.0 + _t * 220.0, area.x + 40.0) - 20.0
				var ry := fmod(i * 53.0 + _t * 520.0, area.y)
				_picture.draw_line(Vector2(rx, ry), Vector2(rx - 6, ry + 18), Color(0.8, 0.85, 0.95, 0.5), 1.5)
		"tea_stall":
			_stall(Vector2(area.x * 0.7, ground))
		"school":
			_building(Vector2(area.x * 0.68, ground), Color("E8D9B0"), true)
		"hospital":
			_building(Vector2(area.x * 0.68, ground), Color("F4F4F0"), false)
		"bus_inside":
			for i in 5:
				_picture.draw_rect(Rect2(20 + i * area.x / 5.0, area.y * 0.15, area.x / 5.0 - 30, area.y * 0.3), Color("9DC3E6"))
			_picture.draw_line(Vector2(0, area.y * 0.1), Vector2(area.x, area.y * 0.1), Color("8C9196"), 4)
			_picture.draw_rect(Rect2(0, area.y * 0.55, area.x, area.y * 0.45), Color("C62828"))
			for i in 4:
				_picture.draw_rect(Rect2(10 + i * area.x / 4.0, area.y * 0.6, area.x / 4.0 - 20, area.y * 0.25), Color("1C4E9B"))
	# The people in this panel, along the bottom; the one speaking raised.
	var people := []
	for line in _lines():
		if not people.has(line.by):
			people.append(line.by)
	var speaking: String = _lines()[_line_i].by if not _choosing else ""
	for i in people.size():
		var px := area.x * (0.2 + 0.6 * (i + 0.5) / people.size()) - area.x * 0.12
		_person(Vector2(px, area.y * 0.97), people[i], people[i] == speaking)


func _person(at: Vector2, id: String, speaking: bool) -> void:
	var k := 1.0 if speaking else 0.86
	var lift := -8.0 if speaking else 0.0
	var c := story.colour(id)
	var base := at + Vector2(0, lift)
	var body := PackedVector2Array([base + Vector2(-26, 0) * k, base + Vector2(26, 0) * k,
		base + Vector2(17, -70) * k, base + Vector2(-17, -70) * k])
	if WOMEN.has(id):
		body = PackedVector2Array([base + Vector2(-32, 0) * k, base + Vector2(32, 0) * k,
			base + Vector2(15, -70) * k, base + Vector2(-15, -70) * k])
	_picture.draw_colored_polygon(body, c)
	var head := base + Vector2(0, -88) * k
	if WOMEN.has(id):
		_picture.draw_circle(head + Vector2(0, 6) * k, 21 * k, Color("1B1512"))
	_picture.draw_circle(head, 17 * k, Color("8A5A3C"))
	_picture.draw_circle(head + Vector2(0, -7) * k, 15 * k, Color("1B1512"), true)
	_picture.draw_circle(head + Vector2(0, 3) * k, 14 * k, Color("8A5A3C"))
	if speaking:
		_picture.draw_arc(head, 26, 0, TAU, 24, Look.YELLOW, 3.0)


func _hut(at: Vector2, night: bool) -> void:
	_picture.draw_rect(Rect2(at.x - 70, at.y - 90, 140, 90), Color("8B6A45"))
	_picture.draw_colored_polygon(PackedVector2Array([at + Vector2(-85, -88), at + Vector2(85, -88), at + Vector2(0, -140)]), Color("9AA3A8"))
	_picture.draw_rect(Rect2(at.x - 18, at.y - 55, 36, 55), Color("4A3420"))
	if night:
		var glow := 0.75 + 0.25 * sin(_t * 9.0)
		_picture.draw_circle(at + Vector2(45, -50), 18, Color(1.0, 0.8, 0.35, 0.35 * glow))
		_picture.draw_circle(at + Vector2(45, -50), 6, Color("FFD27A"))


func _rickshaw(at: Vector2, k: float) -> void:
	for wx in [-40.0, 30.0]:
		_picture.draw_arc(at + Vector2(wx, -22) * k, 22 * k, 0, TAU, 20, Color("1A1A1A"), 4.0)
	_picture.draw_rect(Rect2(at.x - 10 * k, at.y - 52 * k, 50 * k, 18 * k), Color("C2185B"))
	_picture.draw_arc(at + Vector2(15, -52) * k, 34 * k, PI, TAU, 16, Color("F6B800"), 12.0)
	_picture.draw_line(at + Vector2(-40, -22) * k, at + Vector2(-60, -60) * k, Color("3C3F44"), 3.0)
	_picture.draw_line(at + Vector2(-70, -60) * k, at + Vector2(-50, -60) * k, Color("B8BCC2"), 3.0)


func _stall(at: Vector2) -> void:
	_picture.draw_rect(Rect2(at.x - 80, at.y - 60, 160, 60), Color("2E7D4F"))
	_picture.draw_rect(Rect2(at.x - 80, at.y - 66, 160, 8), Color("8B5A2B"))
	_picture.draw_colored_polygon(PackedVector2Array([at + Vector2(-95, -128), at + Vector2(95, -128), at + Vector2(85, -112), at + Vector2(-85, -112)]), Color("C2185B"))
	for x in [-80.0, 80.0]:
		_picture.draw_line(at + Vector2(x, -66), at + Vector2(x, -114), Color("C8A96A"), 4.0)
	_picture.draw_circle(at + Vector2(40, -78), 12, Color("C9CDD2"))
	for i in 4:
		_picture.draw_rect(Rect2(at.x - 40 + i * 12, at.y - 76, 8, 10), Color("D9B36C"))


func _building(at: Vector2, wall: Color, flag: bool) -> void:
	_picture.draw_rect(Rect2(at.x - 100, at.y - 130, 200, 130), wall)
	for row in 2:
		for i in 5:
			_picture.draw_rect(Rect2(at.x - 88 + i * 38, at.y - 115 + row * 50, 24, 30), Color("6E8FA8"))
	if flag:
		_picture.draw_line(at + Vector2(-100, -130), at + Vector2(-100, -190), Color("8C9196"), 3.0)
		_picture.draw_rect(Rect2(at.x - 98, at.y - 190, 46, 28), Color("006A4E"))
		_picture.draw_circle(at + Vector2(-77, -176), 8, Color("F42A41"))
	else:
		_picture.draw_rect(Rect2(at.x - 12, at.y - 165, 24, 8), Color("E2432A"))
		_picture.draw_rect(Rect2(at.x - 4, at.y - 173, 8, 24), Color("E2432A"))
