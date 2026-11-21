## The mohalla screen (§৩, §৫): where the days add up. The day number,
## mohalla level and XP, Rahim Chacha's savings and his daughter's school
## fee, the community fund and its project, the rickshaw upgrades on sale,
## the last few days, and the characters (Rahim Chacha can work).
extends Control

const Look = preload("res://scripts/ui/look.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Progress = preload("res://scripts/rules/progress.gd")
const CrashWatch = preload("res://scripts/ui/crash_watch.gd")

var s := Strings.new()
var b := Balance.new()
var progress: Progress
var _crash := ""


func _ready() -> void:
	s.lang = Strings.saved_lang()
	_crash = CrashWatch.last_crash()
	progress = Progress.new(b)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Look.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var top := HBoxContainer.new()
	var title := Look.label(s.t("appTitle"), 32, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var lang := Button.new()
	lang.name = "Language"
	lang.text = "English" if s.lang == "bn" else "বাংলা"
	lang.flat = true
	lang.add_theme_color_override("font_color", Look.MAGENTA)
	lang.pressed.connect(_switch_language)
	top.add_child(lang)
	col.add_child(top)

	if _crash != "":
		col.add_child(_crash_card())
	col.add_child(_mohalla_card())
	col.add_child(_rickshaw_card())
	col.add_child(_fund_card())
	if progress.unlocked("tea_stall"):
		col.add_child(_tea_card())
	else:
		col.add_child(_other("teaName", "teaRole", Look.PARROT, "tea_stall"))
	col.add_child(_other("busName", "busRole", Look.SKY, "bus"))
	if not progress.data.history.is_empty():
		col.add_child(_history_card())
	var version := Look.label("%s · %s" % [s.t("testBuild"), ProjectSettings.get_setting("application/config/version", "dev")], 13)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(version)


func _panel(fill := Color.WHITE) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(fill, 16, 3))
	return panel


## A labelled bar: how far along something is.
func _bar(value: int, goal: int, colour: Color) -> Control:
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, goal)
	bar.value = clampi(value, 0, maxi(1, goal))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("E8E0CF")
	bg.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## Day, level and XP, and the savings.
func _mohalla_card() -> Control:
	var panel := _panel(Color("FFF0C9"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var row := HBoxContainer.new()
	var day := Look.label(s.t("dayNumber", {"n": int(progress.data.day) + 1}), 22, true)
	day.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(day)
	var savings := Look.label(s.t("savings", {"n": int(progress.data.taka)}), 18, true, Look.PARROT.darkened(0.2))
	savings.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(savings)
	box.add_child(row)
	box.add_child(Look.label(s.t("mohallaLevel", {"level": progress.level(), "xp": progress.xp(), "need": progress.to_next(progress.level())}), 15))
	box.add_child(_bar(progress.xp(), progress.to_next(progress.level()), Look.MAGENTA))
	return panel


## Rahim Chacha: the last day, the best day, the school fee, the rickshaw
## upgrade on sale, and the way out to work.
func _rickshaw_card() -> Control:
	var panel := _panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_dot(Look.MAGENTA))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Look.label(s.t("rickshawName"), 20, true))
	text.add_child(Look.label(s.t("rickshawRole"), 14))
	row.add_child(text)
	var drive := Look.button(s.t("startDay", {"n": int(progress.data.day) + 1}))
	drive.name = "Drive"
	drive.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	drive.pressed.connect(_drive)
	row.add_child(drive)
	box.add_child(row)
	# His last day (the newest record that is a rickshaw day).
	for last in progress.data.history:
		if last.get("who", "rickshaw") == "rickshaw":
			box.add_child(Look.label(s.t("lastDay", {"money": int(last.earned), "trips": int(last.get("trips", 0)), "stars": last.stars}), 15))
			box.add_child(Look.label(s.t("bestDay", {"money": int(progress.data.rickshaw.bestDay)}), 14))
			break
	var school := int(progress.data.rickshaw.school)
	box.add_child(Look.label(s.t("schoolFee", {"n": school, "goal": progress.school_goal()}), 15, true))
	box.add_child(_bar(school, progress.school_goal(), Look.SKY))
	box.add_child(Look.label(s.t("schoolHelp"), 13))
	var next := progress.next_upgrade()
	if next != "":
		var cost := progress.price(next)
		var buy := Look.button(s.t("buy_" + next, {"n": cost}), Look.PARROT if progress.data.taka >= cost else Color("9E9E9E"), 15)
		buy.disabled = int(progress.data.taka) < cost
		buy.pressed.connect(_buy.bind(next))
		box.add_child(buy)
	for id in progress.data.rickshaw.upgrades:
		box.add_child(Look.label(s.t("owned_" + id), 14, false, Look.PARROT.darkened(0.2)))
	return panel


## Monir Mama's tea stall, once the mohalla is big enough: the way in,
## and how the last day there went.
func _tea_card() -> Control:
	var panel := _panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_dot(Look.PARROT))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Look.label(s.t("teaName"), 20, true))
	text.add_child(Look.label(s.t("teaRole"), 14))
	row.add_child(text)
	var open := Look.button(s.t("openStall"), Look.PARROT)
	open.name = "OpenStall"
	open.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open.pressed.connect(_open_stall)
	row.add_child(open)
	box.add_child(row)
	for h in progress.data.history:
		if h.get("who", "") == "tea":
			box.add_child(Look.label(s.t("teaLastDay", {"money": int(h.earned), "served": int(h.served)}), 15))
			break
	return panel


## The community fund and the project it is filling.
func _fund_card() -> Control:
	var panel := _panel(Color("E7F4EC"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(Look.label(s.t("fundTitle"), 18, true))
	var project: String = progress.data.fundProject
	if project != "":
		box.add_child(Look.label(s.t("fundProgress", {"project": s.t("project_" + project), "n": int(progress.data.fund), "goal": progress.fund_goal()}), 15))
		box.add_child(_bar(int(progress.data.fund), progress.fund_goal(), Look.PARROT))
	box.add_child(Look.label(s.t("fundHelp"), 13))
	for done in progress.data.mohalla.projectsDone:
		box.add_child(Look.label(s.t("projectDone", {"project": s.t("project_" + done)}), 14, true, Look.PARROT.darkened(0.2)))
	return panel


func _other(name_key: String, role_key: String, colour: Color, unlock: String) -> Control:
	var panel := _panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_dot(colour))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Look.label(s.t(name_key), 18, true))
	var level := int(b.n("unlocks." + unlock))
	var role := s.t(role_key)
	if not progress.unlocked(unlock):
		role += " · " + s.t("unlocksAt", {"level": level})
	text.add_child(Look.label(role, 14))
	row.add_child(text)
	var soon := Look.label(s.t("comingSoon"), 13)
	soon.autowrap_mode = TextServer.AUTOWRAP_OFF
	soon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(soon)
	return panel


## The last five days, newest first.
func _history_card() -> Control:
	var panel := _panel()
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(Look.label(s.t("recentDays"), 17, true))
	var shown := 0
	for h in progress.data.history:
		if shown >= 5:
			break
		shown += 1
		var line := s.t("historyLine", {"day": int(h.day), "money": int(h.earned), "trips": int(h.get("trips", 0)), "stars": h.stars})
		if h.get("who", "") == "tea":
			line = s.t("teaHistoryLine", {"day": int(h.day), "money": int(h.earned), "served": int(h.get("served", 0))})
		box.add_child(Look.label(line, 14, false, Look.PARROT.darkened(0.3) if h.met else Look.OUTLINE))
	return panel


func _dot(colour: Color) -> Control:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(48, 48)
	dot.add_theme_stylebox_override("panel", Look.card(colour, 24, 0))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return dot


## Shown after a run that ended suddenly: a note and a button that copies
## the log, so the player can send it.
func _crash_card() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(Color("FDECEA"), 14, 2))
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(Look.label(s.t("crashTitle"), 16, true, Look.VERMILION))
	box.add_child(Look.label(s.t("crashHelp"), 14))
	var copy := Look.button(s.t("copyLog"), Look.OUTLINE, 15)
	copy.pressed.connect(_copy_log.bind(copy))
	box.add_child(copy)
	return panel


func _copy_log(button: Button) -> void:
	DisplayServer.clipboard_set(_crash)
	button.text = s.t("copied")


func _buy(id: String) -> void:
	if progress.buy(id):
		progress.save()
		_build()


func _drive() -> void:
	CrashWatch.start("rickshaw")
	get_tree().change_scene_to_file("res://scenes/rickshaw.tscn")


func _open_stall() -> void:
	CrashWatch.start("tea")
	get_tree().change_scene_to_file("res://scenes/tea.tscn")


func _switch_language() -> void:
	s.lang = "en" if s.lang == "bn" else "bn"
	Strings.save_lang(s.lang)
	_build()
