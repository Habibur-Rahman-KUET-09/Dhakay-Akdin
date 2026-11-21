## The mohalla screen (§৩, §৫): where the days add up. The day number,
## mohalla level and XP, Rahim Chacha's savings and his daughter's school
## fee, the community fund and its project, the rickshaw upgrades on sale,
## the last few days, and the characters (Rahim Chacha can work). Stars
## and the run of days played, today's character and challenge, the story
## chapters waiting to be read, the neighbours' notebook (§৬, §৭).
extends Control

const Look = preload("res://scripts/ui/look.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Progress = preload("res://scripts/rules/progress.gd")
const CrashWatch = preload("res://scripts/ui/crash_watch.gd")
const Graphics = preload("res://scripts/ui/graphics.gd")
const Story = preload("res://scripts/rules/story.gd")
const Neighbours = preload("res://scripts/rules/neighbours.gd")
const StoryPlayer = preload("res://scripts/ui/story_player.gd")

var s := Strings.new()
var b := Balance.new()
var progress: Progress
var _crash := ""
var _lowered := false
var story := Story.new()
var neighbours := Neighbours.new()
## Where to go once an opening chapter has been read.
var _then_scene := ""


func _ready() -> void:
	s.lang = Strings.saved_lang()
	_crash = CrashWatch.last_crash()
	# A crash in a 3D scene: next time, go easy on the graphics chip.
	if _crash != "" and Graphics.level() == "high":
		Graphics.save_level("low")
		_lowered = true
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
	col.add_child(_today_card())
	var waiting := story.waiting(progress.data)
	if not waiting.is_empty():
		col.add_child(_chapter_card(waiting[0]))
	col.add_child(_rickshaw_card())
	col.add_child(_fund_card())
	if progress.unlocked("tea_stall"):
		col.add_child(_tea_card())
	else:
		col.add_child(_other("teaName", "teaRole", Look.PARROT, "tea_stall"))
	if progress.unlocked("bus"):
		col.add_child(_bus_card())
	else:
		col.add_child(_other("busName", "busRole", Look.SKY, "bus"))
	if not progress.data.history.is_empty():
		col.add_child(_history_card())
	col.add_child(_book_row())
	col.add_child(_graphics_row())
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
	box.add_child(Look.label(s.t("starsAndStreak", {"stars": int(progress.data.tara), "n": int(progress.data.streak.count)}), 15, true, Look.MAGENTA.darkened(0.1)))
	return panel


## Today: whose day pays double, and the challenge.
func _today_card() -> Control:
	var panel := _panel(Color("E8F1FB"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(Look.label(s.t("todayTitle"), 18, true))
	var who := progress.featured()
	var used: bool = progress.daily().featured
	box.add_child(Look.label(s.t("featuredUsed" if used else "featuredToday", {"name": s.t(_name_key(who))}), 15))
	var c := progress.challenge()
	if not c.is_empty():
		var done: bool = progress.daily().challenge
		var text := s.t("challengeLine", {"name": s.t(_name_key(c.who)), "what": s.t("ch_" + c.id, {"goal": int(c.goal)})})
		box.add_child(Look.label(text + (" · " + s.t("challengeMet") if done else ""), 15, done, Look.PARROT.darkened(0.2) if done else Look.OUTLINE))
	return panel


func _name_key(who: String) -> String:
	return {"rickshaw": "rickshawName", "tea": "teaName", "bus": "busName"}[who]


## A new story chapter to read.
func _chapter_card(c: Dictionary) -> Control:
	var panel := _panel(Color("FDE7EF"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Look.label(s.t("newChapter"), 14, true, Look.MAGENTA))
	text.add_child(Look.label(s.t("storyChapter", {"n": int(c.n), "title": c.title[s.lang]}), 17, true))
	row.add_child(text)
	var read := Look.button(s.t("readChapter"), Look.MAGENTA, 16)
	read.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	read.pressed.connect(_play_chapter.bind(c.id, ""))
	row.add_child(read)
	return panel


## The story read so far, and the neighbours' notebook.
func _book_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var tales := Look.button(s.t("storyBook", {"n": story.read(progress.data).size(), "all": story.chapters.size()}), Look.MAGENTA, 15)
	tales.pressed.connect(_story_book)
	row.add_child(tales)
	var notes := Look.button(s.t("notebook"), Look.SKY, 15)
	notes.pressed.connect(_notebook)
	row.add_child(notes)
	return row


## Plays a chapter over the screen; `then` is a scene to go to afterwards
## (an opening chapter before a character's first day), or "".
func _play_chapter(id: String, then: String) -> void:
	_then_scene = then
	var player := StoryPlayer.new()
	player.setup(story, story.chapter(id), s)
	player.finished.connect(_chapter_done)
	add_child(player)


func _chapter_done(id: String, effects: Dictionary) -> void:
	progress.finish_chapter(id, effects)
	progress.save()
	if _then_scene != "":
		_go(_then_scene)
	else:
		_build()


## Before a character's first day, their opening chapter.
func _start(who: String, scene: String) -> void:
	var opening := story.opening(who, progress.data)
	if not opening.is_empty():
		_play_chapter(opening.id, scene)
	else:
		_go(scene)


func _go(scene: String) -> void:
	CrashWatch.start(scene.get_file().get_basename())
	get_tree().change_scene_to_file(scene)


## A list over the screen: a title, rows, and a close button.
func _overlay(title: String, rows: Array) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(Look.CREAM, 16, 3))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = 40
	panel.offset_bottom = -40
	shade.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var head := HBoxContainer.new()
	var t := Look.label(title, 20, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Look.button(s.t("close"), Look.OUTLINE, 14)
	close.pressed.connect(shade.queue_free)
	head.add_child(close)
	col.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for r in rows:
		list.add_child(r)


## Chapters read, to read again; the rest shown locked.
func _story_book() -> void:
	var rows := []
	for c in story.chapters:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var read: bool = progress.seen(c.id)
		var label := Look.label("%s · %s" % [s.t(_name_key(c.who)), s.t("storyChapter", {"n": int(c.n), "title": c.title[s.lang]}) if read else s.t("chapterLocked", {"n": int(c.n)})], 15, read)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if read:
			var again := Look.button(s.t("readAgain"), Look.MAGENTA, 13)
			again.pressed.connect(_reread.bind(c.id))
			row.add_child(again)
		rows.append(row)
	_overlay(s.t("storyTitle"), rows)


func _reread(id: String) -> void:
	_then_scene = ""
	var player := StoryPlayer.new()
	player.setup(story, story.chapter(id), s)
	add_child(player)


## The neighbours: how each feels about the mohalla, and what happened
## lately.
func _notebook() -> void:
	var rows := []
	rows.append(Look.label(s.t("notebookHelp"), 13))
	for p in neighbours.people:
		var rel := progress.relation(p.id)
		var met: bool = progress.data.npcs.has(p.id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var who := Look.label("%s · %s" % [p[s.lang], p.role[s.lang]], 14, met)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(who)
		var mood := Look.label(s.t("notMet") if not met else s.t("mood", {"n": ("+" if rel > 0 else "") + str(rel)}), 14, true,
			Look.PARROT.darkened(0.2) if rel > 0 else (Look.VERMILION if rel < 0 else Look.OUTLINE))
		mood.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(mood)
		rows.append(row)
	if not progress.data.log.is_empty():
		rows.append(Look.label(s.t("lately"), 16, true))
		var shown := 0
		for e in progress.data.log:
			if shown >= 8:
				break
			shown += 1
			var change := int(e.delta)
			rows.append(Look.label(s.t("logLine", {"name": neighbours.name_of(e.id, s.lang), "what": s.t("log_" + str(e.what)),
				"n": ("+" if change > 0 else "") + str(change)}), 13))
	_overlay(s.t("notebook"), rows)


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
	# What the stall can buy next, from the shared savings.
	var next := progress.next_upgrade("tea")
	if next != "":
		var cost := progress.price(next, "tea")
		var buy := Look.button(s.t("buy_" + next, {"n": cost}), Look.PARROT if int(progress.data.taka) >= cost else Color("9E9E9E"), 15)
		buy.disabled = int(progress.data.taka) < cost
		buy.pressed.connect(_buy_for_stall.bind(next))
		box.add_child(buy)
	for id in progress.data.tea.upgrades:
		box.add_child(Look.label(s.t("owned_" + id), 14, false, Look.PARROT.darkened(0.2)))
	return panel


## Babu's bus, once the mohalla is big enough: the way on, and the last
## day there.
func _bus_card() -> Control:
	var panel := _panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_dot(Look.SKY))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Look.label(s.t("busName"), 20, true))
	text.add_child(Look.label(s.t("busRole"), 14))
	row.add_child(text)
	var board := Look.button(s.t("openBus"), Look.SKY)
	board.name = "Board"
	board.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board.pressed.connect(_board_bus)
	row.add_child(board)
	box.add_child(row)
	for h in progress.data.history:
		if h.get("who", "") == "bus":
			box.add_child(Look.label(s.t("busLastDay", {"money": int(h.earned), "riders": int(h.get("riders", 0))}), 15))
			break
	var next := progress.next_upgrade("bus")
	if next != "":
		var cost := progress.price(next, "bus")
		var buy := Look.button(s.t("buy_" + next, {"n": cost}), Look.SKY if int(progress.data.taka) >= cost else Color("9E9E9E"), 15)
		buy.disabled = int(progress.data.taka) < cost
		buy.pressed.connect(_buy_for.bind(next, "bus"))
		box.add_child(buy)
	for id in progress.data.bus.upgrades:
		box.add_child(Look.label(s.t("owned_" + id), 14, false, Look.SKY.darkened(0.2)))
	return panel


func _buy_for(id: String, who: String) -> void:
	if progress.buy(id, who):
		progress.save()
		_build()


func _board_bus() -> void:
	_start("bus", "res://scenes/bus.tscn")


func _buy_for_stall(id: String) -> void:
	if progress.buy(id, "tea"):
		progress.save()
		_build()


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
	var cost := int(b.n("unlocks.early_unlock_tara"))
	if int(progress.data.tara) >= cost:
		var early := Look.button(s.t("unlockEarly", {"n": cost}), Look.MAGENTA, 13)
		early.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		early.pressed.connect(_unlock_early.bind(unlock))
		row.add_child(early)
	else:
		var soon := Look.label(s.t("comingSoon"), 13)
		soon.autowrap_mode = TextServer.AUTOWRAP_OFF
		soon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(soon)
	return panel


func _unlock_early(what: String) -> void:
	if progress.unlock_early(what):
		progress.save()
		_build()


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
		elif h.get("who", "") == "bus":
			line = s.t("busHistoryLine", {"day": int(h.day), "money": int(h.earned), "riders": int(h.get("riders", 0))})
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
	if _lowered:
		box.add_child(Look.label(s.t("graphicsLowered"), 14, true))
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
	_start("rickshaw", "res://scenes/rickshaw.tscn")


func _open_stall() -> void:
	_start("tea", "res://scenes/tea.tscn")


## Graphics: two buttons, the one in use filled in.
func _graphics_row() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var title := Look.label(s.t("graphics"), 15, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	for level in ["high", "low"]:
		var on: bool = Graphics.level() == level
		var pick := Look.button(s.t("graphics_" + level), Look.MAGENTA if on else Color("B9B2A6"), 15)
		pick.name = "Graphics_" + level
		pick.pressed.connect(_set_graphics.bind(level))
		row.add_child(pick)
	box.add_child(row)
	var help := Look.label(s.t("graphicsHelp"), 12)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)
	return box


func _set_graphics(level: String) -> void:
	Graphics.save_level(level)
	_build()


func _switch_language() -> void:
	s.lang = "en" if s.lang == "bn" else "bn"
	Strings.save_lang(s.lang)
	_build()
