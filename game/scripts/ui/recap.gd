## The end of a day as a story, before the page with everything on it: tap
## through the money (counting up), the day's best moment, the day's card
## (tear open a paper cone, as jhalmuri comes in, and it pops out), the
## season pass filling up, and the end (share it). Skip goes straight on.
extends Control

const Look = preload("res://scripts/ui/look.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Cards = preload("res://scripts/rules/cards.gd")
const Season = preload("res://scripts/rules/season.gd")
const Juice = preload("res://scripts/ui/juice.gd")
const DayLines = preload("res://scripts/ui/day_lines.gd")

signal finished

const FILLS := {"money": Color("C2185B"), "moment": Color("1E6FB0"), "card": Color("2E7D4F"), "pass": Color("1C3E7B"), "end": Color("2B2238")}
const PAPER := Color("F1E6CC")

var s: Strings
var info: Dictionary
var got: Dictionary
var progress: Object
var face := "rahim"
var pages: Array = []
var at := 0
var _body: Control
var _bars: HBoxContainer
var _bg: ColorRect
var _torn := false
var _cone: Node2D


func setup(strings: Strings, day_info: Dictionary, gained: Dictionary, save: Object, face_icon: String) -> Control:
	s = strings
	info = day_info
	got = gained
	progress = save
	face = face_icon
	pages = ["money"]
	if _moment() != "":
		pages.append("moment")
	if not (got.get("card", {}) as Dictionary).is_empty():
		pages.append("card")
	if int((got.get("season", {}) as Dictionary).get("gained", 0)) > 0 and int(save.data.get("day", 0)) >= 2:
		pages.append("pass")
	pages.append("end")
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	var room := Look.safe_insets(get_viewport())
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = room.x
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	_bars = HBoxContainer.new()
	_bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bars.add_theme_constant_override("separation", 4)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_bars)
	var skip := Look.chunky(s.t("recapSkip"), Color.WHITE, Look.OUTLINE, 14, 3, 14)
	skip.name = "RecapSkip"
	skip.autowrap_mode = TextServer.AUTOWRAP_OFF
	skip.pressed.connect(_done)
	top.add_child(skip)
	_body = Control.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.offset_top = room.x + 60
	_body.offset_bottom = -room.y - 20
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_show()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		if pages[at] == "card" and not _torn:
			_tear()
			return
		next()


func next() -> void:
	if at >= pages.size() - 1:
		_done()
		return
	Juice.tap()
	at += 1
	_show()


func _done() -> void:
	finished.emit()
	queue_free()


func _show() -> void:
	for c in _body.get_children():
		c.queue_free()
	for c in _bars.get_children():
		c.queue_free()
	for k in pages.size():
		var bar := ColorRect.new()
		bar.color = Look.YELLOW if k <= at else Color(1, 1, 1, 0.3)
		bar.custom_minimum_size = Vector2(0, 5)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bars.add_child(bar)
	var page: String = pages[at]
	_bg.color = FILLS.get(page, FILLS.end)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 24
	col.offset_right = -24
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(col)
	match page:
		"money":
			_money(col)
		"moment":
			_moment_page(col)
		"card":
			_card_page(col)
		"pass":
			_pass_page(col)
		_:
			_end_page(col)
	if page != "end":
		var hint := _line(s.t("recapTap") if page != "card" or _torn else s.t("recapTear"), 15, false, Color(1, 1, 1, 0.75))
		hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		hint.offset_top = -30
		_body.add_child(hint)


func _line(text: String, size: int, bold := true, colour := Color.WHITE) -> Label:
	var l := Look.label(text, size, bold, colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _money(col: VBoxContainer) -> void:
	col.add_child(_line(s.t("recapMoney"), 26))
	var face_box := CenterContainer.new()
	face_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = Look.icon_texture(face, 150)
	pic.custom_minimum_size = Vector2(150, 150)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face_box.add_child(pic)
	col.add_child(face_box)
	var money := int(info.get("money", 0))
	var big := _line(s.t("taka", {"n": 0}), 64)
	big.add_theme_font_override("font", Look.font(Look.DISPLAY))
	col.add_child(big)
	var tw := create_tween()
	tw.tween_method(func(v: float): if is_instance_valid(big): big.text = s.t("taka", {"n": int(v)}), 0.0, float(money), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func(): if is_instance_valid(big): Juice.celebrate(self, "ting", Vector2(size.x / 2.0, size.y * 0.45)))
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 6)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := int(round(float(info.get("stars", 0.0))))
	for i in 5:
		var star := Look.icon("star" if i < n else "star_off", 44, Color.WHITE)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars.add_child(star)
	col.add_child(stars)
	var sub := str(info.get("sub", ""))
	if sub != "":
		var l := _line(sub, 18, false, Look.CREAM)
		col.add_child(l)


## The best line of the day: one of the character's own (the target met, a
## record), else the first of how it went.
func _moment() -> String:
	for line in info.get("extras", []):
		if str(line) != "":
			return str(line)
	for line in info.get("lines", []):
		if str(line) != "":
			return str(line)
	return ""


func _moment_page(col: VBoxContainer) -> void:
	col.add_child(_line(s.t("recapMoment"), 26))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.card(Look.CREAM, 24, 3))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Look.label("“%s”" % _moment(), 26, true, Look.OUTLINE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(l)
	col.add_child(card)
	card.pivot_offset = Vector2(220, 60)
	card.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- The card in a paper cone ---------------------------------------------------


func _card_page(col: VBoxContainer) -> void:
	_torn = false
	col.add_child(_line(s.t("recapCard"), 26))
	var spot := Control.new()
	spot.custom_minimum_size = Vector2(0, 420)
	spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spot)
	spot.resized.connect(func(): if _cone != null: _cone.position = Vector2(spot.size.x / 2.0, 30))
	_cone = Node2D.new()
	_cone.position = Vector2(246, 30)
	spot.add_child(_cone)
	# The cone: two halves of newspaper (they come apart when torn), printed
	# lines, a twist of paper at the top.
	for side in [-1, 1]:
		var half := Node2D.new()
		half.name = "Half%d" % side
		_cone.add_child(half)
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(0, 0), Vector2(side * 120, 0), Vector2(side * 4, 330), Vector2(0, 330)])
		poly.color = PAPER if side < 0 else PAPER.darkened(0.06)
		half.add_child(poly)
		for k in 9:
			var y := 30.0 + k * 30.0
			var w := 110.0 * (1.0 - y / 340.0)
			var print_line := Line2D.new()
			print_line.points = PackedVector2Array([Vector2(side * 8, y), Vector2(side * w, y)])
			print_line.width = 4
			print_line.default_color = Color(0.25, 0.22, 0.2, 0.35)
			half.add_child(print_line)
		var edge := Line2D.new()
		edge.points = PackedVector2Array([Vector2(0, 0), Vector2(side * 120, 0), Vector2(side * 4, 330)])
		edge.width = 4
		edge.default_color = Look.OUTLINE
		half.add_child(edge)
	var twist := Polygon2D.new()
	twist.polygon = PackedVector2Array([Vector2(-120, 0), Vector2(120, 0), Vector2(80, -26), Vector2(-80, -26)])
	twist.color = Look.VERMILION
	twist.name = "Twist"
	_cone.add_child(twist)
	var wobble := create_tween().set_loops()
	wobble.tween_property(_cone, "rotation", 0.06, 0.5).set_trans(Tween.TRANS_SINE)
	wobble.tween_property(_cone, "rotation", -0.06, 0.5).set_trans(Tween.TRANS_SINE)


func _tear() -> void:
	_torn = true
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(40)
	var sound := AudioStreamPlayer.new()
	sound.stream = load("res://sounds/tear.wav")
	add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)
	var spot := _cone.get_parent() as Control
	var tw := create_tween().set_parallel()
	for side in [-1, 1]:
		var half: Node2D = _cone.get_node("Half%d" % side)
		tw.tween_property(half, "position", Vector2(side * 260, 140), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(half, "rotation", side * 0.9, 0.55)
		tw.tween_property(half, "modulate:a", 0.0, 0.55)
	tw.tween_property(_cone.get_node("Twist"), "position", Vector2(0, -200), 0.45)
	tw.tween_property(_cone.get_node("Twist"), "modulate:a", 0.0, 0.45)
	var card := _the_card()
	spot.add_child(card)
	card.position = Vector2((spot.size.x - 300) / 2.0, 30)
	card.pivot_offset = Vector2(150, 180)
	card.scale = Vector2(0.1, 0.1)
	card.rotation = -0.5
	var pop := create_tween().set_parallel()
	pop.tween_property(card, "scale", Vector2.ONE, 0.5).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(card, "rotation", 0.0, 0.5).set_delay(0.2)
	pop.chain().tween_callback(func(): Juice.celebrate(self, "sparkle", Vector2(size.x / 2.0, size.y * 0.4)))
	# The hint under it now says tap to go on.
	for c in _body.get_children():
		if c is Label:
			c.text = s.t("recapTap")


func _the_card() -> Control:
	var got_card: Dictionary = got.card
	var c := Cards.card(str(got_card.id))
	var set_colour := Color("1E6FB0")
	var set_name := ""
	for st in Cards.sets():
		if st.id == c.get("set", ""):
			set_colour = Color(str(st.colour))
			set_name = str(st.name.get(s.lang, st.name.en))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 360)
	var style := Look.card(Look.CREAM, 22, 6)
	style.border_color = set_colour
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var tag := Look.pill("", s.t("recapNewCard") if got_card.new else s.t("recapAgainCard", {"n": int(got_card.tara)}), Look.YELLOW if got_card.new else Look.SAND, Look.OUTLINE, 15)
	var tag_row := CenterContainer.new()
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_row.add_child(tag)
	col.add_child(tag_row)
	var name := Look.label(str(c.get("name", {}).get(s.lang, "")), 30, true, set_colour.darkened(0.2))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name)
	var fact := Look.label(str(c.get("fact", {}).get(s.lang, "")), 16, false, Look.OUTLINE)
	fact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(fact)
	var from := Look.label(set_name, 14, true, Look.MUTED)
	from.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(from)
	if str(got_card.get("set_done", "")) != "":
		var done := Look.label(s.t("recapSetDone", {"n": int(got_card.tara)}), 17, true, Look.PARROT_DARK)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(done)
	# Not in a container: wrapped lines need a width to wrap to.
	for l in col.get_children():
		if l is Label:
			l.custom_minimum_size.x = 260
	return panel


# --- The season pass ------------------------------------------------------------


func _pass_page(col: VBoxContainer) -> void:
	col.add_child(_line(s.t("recapPass"), 26))
	var season: Dictionary = got.season
	var date: String = progress.date()
	var per := Season.per_tier()
	var points := Season.points(progress.data, date)
	var tier := Season.open_tiers(progress.data, date)
	var new_tier := int(season.get("new_tiers", 0)) > 0
	col.add_child(_line(s.t("recapTier", {"n": tier + (0 if tier >= Season.tiers().size() else 1)}), 20, true, Look.YELLOW))
	var bar := Look.bar(0, per, Look.YELLOW, 26)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	var start := 0 if new_tier else maxi(0, (points - int(season.gained)) % per)
	bar.value = start
	create_tween().tween_property(bar, "value", float(points % per), 0.9).set_delay(0.2)
	col.add_child(_line("+%s" % s.num(str(int(season.gained))), 30, true, Color.WHITE))
	if new_tier:
		col.add_child(_line(s.t("recapNewTier"), 24, true, Look.YELLOW))
		get_tree().create_timer(0.6).timeout.connect(func(): if is_inside_tree(): Juice.celebrate(self, "sparkle"))


func _end_page(col: VBoxContainer) -> void:
	var title := Look.title(s.t("recapEnd"), 46, Look.YELLOW, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)
	col.add_child(_line(s.t("recapEndLine"), 18, false, Look.CREAM))
	var see := Look.chunky(s.t("recapSee"), Look.YELLOW, Look.OUTLINE, 22, 6, 20)
	see.name = "RecapSee"
	see.custom_minimum_size = Vector2(0, 70)
	see.pressed.connect(_done)
	col.add_child(see)
