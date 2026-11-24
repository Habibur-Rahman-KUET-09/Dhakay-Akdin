## The end of a day, for all three characters: a banner, the day's stars,
## the money (with how the day went), where the money went (savings, the
## school fee, the mohalla fund), the XP towards the next level and what a
## new level opens, the day's extras (challenge, run of days, a record),
## and two ways on: back to the mohalla, or straight into the next day.
extends Control

const Look = preload("res://scripts/ui/look.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Progress = preload("res://scripts/rules/progress.gd")
const DayLines = preload("res://scripts/ui/day_lines.gd")
const ReadAloud = preload("res://scripts/ui/read_aloud.gd")

signal home_pressed
signal again_pressed

const NIGHT := Color("2B2238")

var s: Strings
var b: Balance
var progress: Progress
var got: Dictionary
## title, stars (0-5), sub (a line under the stars), money, lines (how the
## day went), extras (lines of the character's own, as the target met),
## good (whether the day reached its target), kept_label.
var info: Dictionary


func setup(strings: Strings, balance: Balance, save: Progress, gained: Dictionary, day_info: Dictionary) -> void:
	s = strings
	b = balance
	progress = save
	got = gained
	info = day_info


func _ready() -> void:
	# Already in the tree here: anchors alone would keep today's (empty) size.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	print("[day end] shown")
	# Read out: the banner, the money, how the day went.
	var said := [str(info.get("title", "")), s.t("taka", {"n": int(info.get("money", 0))})]
	for line in info.get("lines", []):
		said.append(str(line))
	ReadAloud.say("। ".join(PackedStringArray(said)), s.lang)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = 12
	col.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var room := Look.safe_insets(get_viewport())
	margin.add_theme_constant_override("margin_top", 8 + room.x)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)
	page.add_child(_banner())
	page.add_child(_stars())
	var sub := Look.label(str(info.get("sub", "")), 17, true, Look.CREAM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(sub)
	page.add_child(_money_card())
	page.add_child(_progress_card())
	_let_scroll(margin)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 4 + room.y)
	pad.add_child(buttons)
	col.add_child(pad)
	var home := Look.chunky(s.t("toMohalla"), Look.YELLOW, Look.OUTLINE, 24, 7, 22)
	home.name = "Home"
	home.icon = Look.icon_texture("home", 26)
	home.add_theme_constant_override("icon_max_width", 26)
	home.custom_minimum_size = Vector2(0, 74)
	home.pressed.connect(func(): home_pressed.emit())
	buttons.add_child(home)
	var again := Button.new()
	again.name = "Again"
	again.text = s.t("nextDay")
	again.add_theme_font_override("font", Look.font(Look.BOLD))
	again.add_theme_font_size_override("font_size", 18)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		again.add_theme_color_override(state, Look.CREAM)
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0, 0, 0, 0)
	line.border_color = Look.CREAM
	line.set_border_width_all(3)
	line.set_corner_radius_all(18)
	line.content_margin_top = 8
	line.content_margin_bottom = 8
	for state in ["normal", "hover", "pressed", "focus"]:
		again.add_theme_stylebox_override(state, line)
	again.custom_minimum_size = Vector2(0, 56)
	again.pressed.connect(func(): again_pressed.emit())
	buttons.add_child(again)


func _banner() -> Control:
	var center := CenterContainer.new()
	var panel := PanelContainer.new()
	var st := Look.chunky_style(Look.MAGENTA, 14, 6, 4)
	st.content_margin_left = 30
	st.content_margin_right = 30
	st.content_margin_top = 4
	st.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)
	var t := Look.title(str(info.get("title", s.t("dayOver"))), 52, Look.CREAM, false)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(t)
	return center


## Five stars, the middle one biggest, filled to the day's rating.
func _stars() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	var stars := int(roundf(float(info.get("stars", 0.0))))
	var sizes := [50, 58, 68, 58, 50]
	for i in 5:
		var st := Look.icon("star" if i < stars else "star_dark", sizes[i])
		st.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(st)
	return row


## The money, how the day went, and where the money went.
func _money_card() -> Control:
	var panel := _card()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var head := HBoxContainer.new()
	var t := Look.label(s.t("earnedTitle"), 18, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(t)
	var money := Look.label(s.t("takaN", {"n": int(info.get("money", 0))}), 34, true)
	money.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(money)
	col.add_child(head)
	for line in info.get("lines", []):
		col.add_child(_line_row(str(line)))
	col.add_child(_dash())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.add_child(_gain(str(info.get("kept_label", s.t("toSavings"))), int(got.get("kept", 0)), Color("FFF0C9")))
	if int(got.get("school", 0)) > 0:
		grid.add_child(_gain(s.t("schoolTitle"), int(got.school), Color("FDE7F0")))
	grid.add_child(_gain(s.t("fundTitle"), int(got.get("fund", 0)), Color("E6F4EC")))
	col.add_child(grid)
	return panel


## XP towards the next level, what a new level opens, and the extras.
func _progress_card() -> Control:
	var panel := _card()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var head := HBoxContainer.new()
	var t := Look.label(s.t("xpTitle"), 17, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var gain := Look.label(s.t("gainXp", {"n": int(got.get("xp", 0))}), 17, true, Look.PARROT_DARK)
	gain.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(gain)
	col.add_child(head)
	col.add_child(Look.bar(progress.xp(), progress.to_next(progress.level()), Look.PARROT, 18))
	if got.get("level_up", false):
		col.add_child(_level_up())
	var extras := DayLines.lines(got, s)
	if got.get("best", false):
		extras.append(s.t("newBest"))
	if str(got.get("project", "")) != "":
		extras.append(s.t("projectFinished", {"project": s.t("project_" + str(got.project))}))
	extras.append_array(info.get("extras", []))
	for i in extras.size():
		var last: bool = i == extras.size() - 1 and not info.get("extras", []).is_empty()
		var icon_name := "check"
		if last and not info.get("good", true):
			icon_name = "flag"
		col.add_child(_extra_row(icon_name, str(extras[i])))
	return panel


## A new level: its number in a disc, and what it opens.
func _level_up() -> Control:
	var panel := PanelContainer.new()
	var st := Look.card(Look.OUTLINE, 16, 0)
	st.content_margin_left = 10
	st.content_margin_right = 12
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var disc := PanelContainer.new()
	disc.add_theme_stylebox_override("panel", Look.card(Look.YELLOW, 28, 3))
	disc.custom_minimum_size = Vector2(52, 52)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n := Look.label(str(progress.level()), 22, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	disc.add_child(n)
	row.add_child(disc)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(Look.label(s.t("levelUp", {"level": progress.level()}), 19, true, Look.YELLOW))
	for what in ["tea_stall", "bus", "old_dhaka"]:
		if int(b.n("unlocks." + what)) == progress.level():
			text.add_child(Look.label(s.t("nowOpen_" + what), 15, false, Look.CREAM))
	return panel


func _line_row(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dot := ColorRect.new()
	dot.color = Look.MAGENTA
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var l := Look.label(text, 16)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _extra_row(icon_name: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(Look.icon(icon_name, 22, Look.OUTLINE if icon_name != "check" else Color.WHITE))
	var l := Look.label(text, 16, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _gain(title: String, n: int, fill: Color) -> Control:
	var panel := PanelContainer.new()
	var st := Look.card(fill, 14, 3)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", st)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)
	col.add_child(Look.label(title, 14, true, Look.MUTED))
	var v := Look.label(("+" if n > 0 else "") + s.t("takaN", {"n": n}), 20, true)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(v)
	return panel


func _card() -> PanelContainer:
	var panel := PanelContainer.new()
	var st := Look.card(Look.CREAM, 22, 4)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", st)
	return panel


func _dash() -> Control:
	var line := ColorRect.new()
	line.color = Color("D9CBB0")
	line.custom_minimum_size = Vector2(0, 2)
	return line


static func _let_scroll(node: Node) -> void:
	for c in node.get_children():
		if c is Control and not (c is BaseButton or c is ScrollContainer):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		_let_scroll(c)
