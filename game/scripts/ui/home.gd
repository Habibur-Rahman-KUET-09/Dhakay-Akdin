## The mohalla screen (§৩, §৫): where the days add up. At the top the
## day, savings, stars and the run of days, with the mohalla's level; then
## today (the challenge, a festival or the season) and a chapter waiting
## to be read; then the characters as tabs, one open at a time with its
## way into the day, its last day and what it can buy; the mohalla fund;
## and the story book, the neighbours' notebook and the recent days.
## Language, graphics, music and the online copy are under Settings.
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
const Cloud = preload("res://scripts/ui/cloud.gd")
const Calendar = preload("res://scripts/rules/calendar.gd")
const Music = preload("res://scripts/ui/music.gd")

var s := Strings.new()
var b := Balance.new()
var progress: Progress
var _crash := ""
var _lowered := false
var story := Story.new()
var neighbours := Neighbours.new()
## Where to go once an opening chapter has been read.
var _then_scene := ""
var cloud: Cloud
var music: Music
## The character whose panel is open ("" until the page first opens on
## today's character), and whether the settings are showing.
var _tab := ""
var _settings_open := false


func _ready() -> void:
	s.lang = Strings.saved_lang()
	_crash = CrashWatch.last_crash()
	# A crash in a 3D scene: next time, go easy on the graphics chip.
	if _crash != "" and Graphics.level() == "high":
		Graphics.save_level("low")
		_lowered = true
	progress = Progress.new(b)
	cloud = Cloud.new()
	add_child(cloud)
	music = Music.new()
	music.volume_db = -6.0
	add_child(music)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_backup()


## Copies the save online if it has changed since the last copy.
func _backup() -> void:
	if not cloud.enabled() or int(progress.data.day) == cloud.last_day:
		return
	if await cloud.upload(progress.data) == "":
		_build()


func _build() -> void:
	for c in get_children():
		if c != cloud and c != music:
			c.queue_free()
	if _tab == "":
		_tab = progress.featured()
	var bg := ColorRect.new()
	bg.color = Look.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# A finger has to move a little before it scrolls, so taps stay taps.
	scroll.scroll_deadzone = 12
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 20)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	col.add_child(_header())
	if _crash != "":
		col.add_child(_crash_card())
	col.add_child(_mohalla_card())
	var waiting := story.waiting(progress.data)
	if not waiting.is_empty():
		col.add_child(_chapter_card(waiting[0]))
	col.add_child(_today_card())
	col.add_child(_section(s.t("whoToday")))
	col.add_child(_tabs())
	col.add_child(_character_panel(_tab))
	col.add_child(_fund_card())
	col.add_child(_more_row())
	var version := Look.label("%s · %s" % [s.t("testBuild"), ProjectSettings.get_setting("application/config/version", "dev")], 12, false, Color("8A8178"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(version)
	_let_scroll(margin)
	if _settings_open:
		_settings()


## The name of the game and the way to the settings.
func _header() -> Control:
	var top := HBoxContainer.new()
	var title := Look.label(s.t("appTitle"), 30, true, Look.MAGENTA)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var gear := Look.button(s.t("settings"), Look.OUTLINE, 14)
	gear.name = "Settings"
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear.pressed.connect(_open_settings)
	top.add_child(gear)
	return top


## A small heading between the parts of the page.
func _section(text: String) -> Control:
	var l := Look.label(text, 15, true, Color("6B6259"))
	return l


## The mohalla at a glance: four numbers side by side, then the level.
func _mohalla_card() -> Control:
	var panel := _panel(Color("FFF0C9"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	chips.add_child(_chip(s.t("chipDay"), str(int(progress.data.day) + 1), Look.OUTLINE))
	chips.add_child(_chip(s.t("chipSaved"), s.t("takaN", {"n": int(progress.data.taka)}), Look.PARROT.darkened(0.2)))
	chips.add_child(_chip(s.t("chipStars"), str(int(progress.data.tara)), Look.MAGENTA))
	chips.add_child(_chip(s.t("chipStreak"), s.t("daysN", {"n": int(progress.data.streak.count)}), Look.SKY.darkened(0.2)))
	box.add_child(chips)
	var row := HBoxContainer.new()
	var lvl := Look.label(s.t("levelN", {"level": progress.level()}), 16, true)
	lvl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lvl)
	var xp := Look.label("%d / %d XP" % [progress.xp(), progress.to_next(progress.level())], 13)
	xp.autowrap_mode = TextServer.AUTOWRAP_OFF
	xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(xp)
	box.add_child(row)
	box.add_child(_bar(progress.xp(), progress.to_next(progress.level()), Look.MAGENTA))
	return panel


## One number with its name above it.
func _chip(caption: String, value: String, colour: Color) -> Control:
	var chip := PanelContainer.new()
	var style := Look.card(Color.WHITE, 12, 0)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", style)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	chip.add_child(box)
	var top := Look.label(caption, 12, false, Color("6B6259"))
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(top)
	var big := Look.label(value, 17, true, colour)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.autowrap_mode = TextServer.AUTOWRAP_OFF
	big.clip_text = true
	box.add_child(big)
	return chip


## Today: the challenge, and the festival or the season.
func _today_card() -> Control:
	var panel := _panel(Color("E8F1FB"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(Look.label(s.t("todayTitle"), 16, true))
	var c := progress.challenge()
	if not c.is_empty():
		var done: bool = progress.daily().challenge
		var text := s.t("challengeLine", {"name": s.t(_name_key(c.who)), "what": s.t("ch_" + c.id, {"goal": int(c.goal)})})
		box.add_child(Look.label(text + (" · " + s.t("challengeMet") if done else ""), 14, done, Look.PARROT.darkened(0.2) if done else Look.OUTLINE))
	var calendar := Calendar.new()
	var date := progress.date()
	var fest := calendar.festival(date)
	if not fest.is_empty():
		var line := str(fest.name.get(s.lang, fest.name.en))
		if int(fest.tip) > 0:
			line += " · " + s.t("festivalTip", {"n": int(fest.tip)})
		box.add_child(Look.label(line, 14, true, Look.MAGENTA))
	else:
		var season := ""
		var m := Calendar.month_of(date)
		if m >= 6 and m <= 9:
			season = "seasonMonsoon"
		elif m == 12 or m == 1:
			season = "seasonWinter"
		elif m == 4 or m == 5:
			season = "seasonHot"
		if season != "":
			box.add_child(Look.label(s.t(season), 13))
	return panel


func _name_key(who: String) -> String:
	return {"rickshaw": "rickshawName", "tea": "teaName", "bus": "busName"}[who]


## Each character's colour.
func _colour_of(who: String) -> Color:
	return {"rickshaw": Look.MAGENTA, "tea": Look.PARROT, "bus": Look.SKY}[who]


## What opens a character ("tea_stall" for the tea stall).
func _unlock_of(who: String) -> String:
	return {"rickshaw": "", "tea": "tea_stall", "bus": "bus"}[who]


## The three characters as tabs: the one picked filled in its colour,
## today's double-money one marked, the shut ones with their level.
func _tabs() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var open := progress.open_characters()
	var featured := progress.featured()
	var used: bool = progress.daily().featured
	for who in ["rickshaw", "tea", "bus"]:
		var second := s.t("tab_" + who)
		if not open.has(who):
			second = s.t("tabLocked", {"level": int(b.n("unlocks." + _unlock_of(who)))})
		elif who == featured and not used:
			second = s.t("tabDouble")
		var picked: bool = who == _tab
		var colour := _colour_of(who)
		var tab := Look.button(s.t(_name_key(who)) + "\n" + second, colour if picked else Color.WHITE, 14)
		tab.name = "Tab_" + who
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 58)
		if not picked:
			var ink: Color = colour.darkened(0.15) if open.has(who) else Color("9E958B")
			for state in ["font_color", "font_hover_color", "font_pressed_color"]:
				tab.add_theme_color_override(state, ink)
		tab.pressed.connect(_pick_tab.bind(who))
		row.add_child(tab)
	return row


func _pick_tab(who: String) -> void:
	_tab = who
	_build()


## The picked character: who they are, how their last day went, what
## they are saving for, the way to start the day, and what to buy next.
func _character_panel(who: String) -> Control:
	var panel := PanelContainer.new()
	var style := Look.card(Color.WHITE, 16, 3)
	style.border_color = _colour_of(who)
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_dot(_colour_of(who)))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Look.label(s.t(_name_key(who)), 20, true))
	text.add_child(Look.label(s.t({"rickshaw": "rickshawRole", "tea": "teaRole", "bus": "busRole"}[who]), 14))
	row.add_child(text)
	box.add_child(row)
	if not progress.open_characters().has(who):
		_locked_body(box, who)
		return panel
	if who == progress.featured() and not progress.daily().featured:
		box.add_child(Look.label(s.t("doubleToday"), 14, true, Look.MAGENTA))
	if who == "rickshaw":
		box.add_child(_area_row())
	# The last day as this character (the newest such record).
	for h in progress.data.history:
		if h.get("who", "rickshaw") != who:
			continue
		if who == "rickshaw":
			box.add_child(Look.label(s.t("lastDay", {"money": int(h.earned), "trips": int(h.get("trips", 0)), "stars": h.stars}), 14))
			box.add_child(Look.label(s.t("bestDay", {"money": int(progress.data.rickshaw.bestDay)}), 13))
		elif who == "tea":
			box.add_child(Look.label(s.t("teaLastDay", {"money": int(h.earned), "served": int(h.served)}), 14))
		else:
			box.add_child(Look.label(s.t("busLastDay", {"money": int(h.earned), "riders": int(h.get("riders", 0))}), 14))
		break
	if who == "rickshaw":
		var school := int(progress.data.rickshaw.school)
		box.add_child(Look.label(s.t("schoolFee", {"n": school, "goal": progress.school_goal()}), 14, true))
		box.add_child(_bar(school, progress.school_goal(), Look.SKY))
		box.add_child(Look.label(s.t("schoolHelp"), 12, false, Color("6B6259")))
	var start := Look.button(s.t("startDay", {"n": int(progress.data.day) + 1}), _colour_of(who), 20)
	start.name = {"rickshaw": "Drive", "tea": "OpenStall", "bus": "Board"}[who]
	start.custom_minimum_size = Vector2(0, 60)
	start.pressed.connect(_start.bind(who, {"rickshaw": "res://scenes/rickshaw.tscn", "tea": "res://scenes/tea.tscn", "bus": "res://scenes/bus.tscn"}[who]))
	box.add_child(start)
	# What to buy next, from the shared savings, and what is bought.
	var next := progress.next_upgrade(who)
	if next != "":
		var cost := progress.price(next, who)
		var afford := int(progress.data.taka) >= cost
		var buy := Look.button(s.t("buy_" + next, {"n": cost}), _colour_of(who) if afford else Color("B9B2A6"), 14)
		buy.disabled = not afford
		buy.pressed.connect(_buy_for.bind(next, who))
		box.add_child(buy)
	var owned: Array = progress.data[who].upgrades
	if not owned.is_empty():
		var names := PackedStringArray()
		for id in owned:
			var full := s.t("owned_" + id)
			names.append(full.get_slice(":", 1).strip_edges() if full.contains(":") else full)
		box.add_child(Look.label(s.t("ownedList", {"list": " · ".join(names)}), 13, false, _colour_of(who).darkened(0.25)))
	return panel


## A character not open yet: when they open, or the stars to open early.
func _locked_body(box: VBoxContainer, who: String) -> void:
	var unlock := _unlock_of(who)
	box.add_child(Look.label(s.t("unlocksAt", {"level": int(b.n("unlocks." + unlock))}), 15, true, Color("6B6259")))
	var cost := int(b.n("unlocks.early_unlock_tara"))
	if int(progress.data.tara) >= cost:
		var early := Look.button(s.t("unlockEarly", {"n": cost}), Look.MAGENTA, 16)
		early.pressed.connect(_unlock_early.bind(unlock))
		box.add_child(early)
	else:
		box.add_child(Look.label(s.t("earlyHelp", {"n": cost}), 13))


## The community fund and the project it is filling.
func _fund_card() -> Control:
	var panel := _panel(Color("E7F4EC"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(Look.label(s.t("fundTitle"), 16, true))
	var project: String = progress.data.fundProject
	if project != "":
		box.add_child(Look.label(s.t("fundProgress", {"project": s.t("project_" + project), "n": int(progress.data.fund), "goal": progress.fund_goal()}), 14))
		box.add_child(_bar(int(progress.data.fund), progress.fund_goal(), Look.PARROT))
	box.add_child(Look.label(s.t("fundHelp"), 12, false, Color("6B6259")))
	var done := PackedStringArray()
	for p in progress.data.mohalla.projectsDone:
		done.append(s.t("project_" + p))
	if not done.is_empty():
		box.add_child(Look.label(s.t("projectsDone", {"list": " · ".join(done)}), 13, true, Look.PARROT.darkened(0.2)))
	return panel


## The story read so far, the neighbours' notebook and the last few days.
func _more_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var buttons := [
		[s.t("storyBook", {"n": story.read(progress.data).size(), "all": story.chapters.size()}), Look.MAGENTA, _story_book],
		[s.t("notebook"), Look.SKY, _notebook],
		[s.t("recentDays"), Look.PARROT, _recent_days],
	]
	for spec in buttons:
		var button := Look.button(spec[0], spec[1], 14)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 50)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(spec[2])
		row.add_child(button)
	return row


## The last ten days, newest first.
func _recent_days() -> void:
	var rows := []
	if progress.data.history.is_empty():
		rows.append(Look.label(s.t("noDaysYet"), 14))
	for h in progress.data.history:
		var line := s.t("historyLine", {"day": int(h.day), "money": int(h.earned), "trips": int(h.get("trips", 0)), "stars": h.stars})
		if h.get("who", "") == "tea":
			line = s.t("teaHistoryLine", {"day": int(h.day), "money": int(h.earned), "served": int(h.get("served", 0))})
		elif h.get("who", "") == "bus":
			line = s.t("busHistoryLine", {"day": int(h.day), "money": int(h.earned), "riders": int(h.get("riders", 0))})
		rows.append(Look.label(line, 14, false, Look.PARROT.darkened(0.3) if h.met else Look.OUTLINE))
	_overlay(s.t("recentDays"), rows)


## Settings, over the page: language, graphics, music, the online copy.
func _open_settings() -> void:
	_settings_open = true
	_settings()


func _settings() -> void:
	var rows := []
	var lang_row := HBoxContainer.new()
	lang_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lang_row.add_theme_constant_override("separation", 8)
	var lang_title := Look.label(s.t("languageLabel"), 15, true)
	lang_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	lang_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lang_row.add_child(lang_title)
	for code in ["bn", "en"]:
		var pick := Look.button("বাংলা" if code == "bn" else "English", Look.MAGENTA if s.lang == code else Color("B9B2A6"), 15)
		pick.name = "Language_" + code
		pick.pressed.connect(_set_language.bind(code))
		lang_row.add_child(pick)
	rows.append(lang_row)
	rows.append(_graphics_row())
	rows.append(_music_row())
	rows.append(_cloud_card())
	_overlay(s.t("settings"), rows, _close_settings)


func _close_settings() -> void:
	_settings_open = false


## Cards, rows and labels stopped a finger dragging the page: the touch
## ended at the card. Let everything but buttons and text boxes pass
## touches on, so the page scrolls from anywhere.
static func _let_scroll(node: Node) -> void:
	for c in node.get_children():
		if c is Control and not (c is BaseButton or c is LineEdit or c is ScrollContainer):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		_let_scroll(c)


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


## The online copy: when it was last made, and the email to move phones.
func _cloud_card() -> Control:
	var panel := _panel(Color("EEF2F5"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(Look.label(s.t("cloudTitle"), 17, true))
	var status := s.t("cloudOff")
	if cloud.enabled():
		status = s.t("cloudNever") if cloud.last_time == "" else s.t("cloudLast", {"time": cloud.last_time.substr(0, 16), "n": cloud.last_day + 1})
	box.add_child(Look.label(status, 14))
	if not cloud.enabled():
		return panel
	if cloud.email != "":
		box.add_child(Look.label(s.t("cloudLinkedGoogle" if cloud.provider == "google" else "cloudLinked", {"email": cloud.email}), 14, true, Look.PARROT.darkened(0.2)))
	else:
		box.add_child(Look.label(s.t("cloudHelp"), 13))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var keep := Look.button(s.t("cloudKeep"), Look.SKY, 14)
		keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keep.pressed.connect(_email_form.bind(true))
		row.add_child(keep)
		var fetch := Look.button(s.t("cloudFetch"), Look.OUTLINE, 14)
		fetch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fetch.pressed.connect(_email_form.bind(false))
		row.add_child(fetch)
		box.add_child(row)
	return panel


## Asks for an email and password: to tie this phone's progress to them
## (keep), or to bring progress from another phone (fetch).
func _email_form(keep: bool) -> void:
	var rows := []
	rows.append(Look.label(s.t("cloudKeepHelp" if keep else "cloudFetchHelp"), 14))
	var note := Look.label("", 14, true, Look.VERMILION)
	# Google first, where the phone and the build can do it.
	if cloud.google_ready():
		var google := Look.button(s.t("cloudGoogleKeep" if keep else "cloudGoogleFetch"), Color("1A73E8"), 17)
		google.custom_minimum_size = Vector2(0, 56)
		google.pressed.connect(_google_go.bind(keep, note, google))
		rows.append(google)
		rows.append(Look.label(s.t("cloudOrEmail"), 14, true))
	var address := LineEdit.new()
	address.placeholder_text = s.t("cloudEmail")
	address.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	address.custom_minimum_size = Vector2(0, 48)
	rows.append(address)
	var password := LineEdit.new()
	password.placeholder_text = s.t("cloudPassword")
	password.secret = true
	password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	password.custom_minimum_size = Vector2(0, 48)
	rows.append(password)
	var go := Look.button(s.t("cloudEmailKeep" if keep else "cloudEmailFetch"), Look.SKY, 16)
	go.pressed.connect(_email_go.bind(keep, address, password, note, go))
	rows.append(go)
	rows.append(note)
	_overlay(s.t("cloudTitle"), rows)


func _email_go(keep: bool, address: LineEdit, password: LineEdit, note: Label, go: Button) -> void:
	go.disabled = true
	_working(note)
	var e := ""
	if keep:
		e = await cloud.link_email(address.text.strip_edges(), password.text)
	else:
		e = await cloud.sign_in(address.text.strip_edges(), password.text)
	go.disabled = false
	await _signed_in(keep, e, note, go)


func _google_go(keep: bool, note: Label, go: Button) -> void:
	go.disabled = true
	_working(note)
	var e := await cloud.google(keep)
	go.disabled = false
	if e == "CANCELLED":
		note.text = ""
		return
	await _signed_in(keep, e, note, go)


func _working(note: Label) -> void:
	note.add_theme_color_override("font_color", Look.OUTLINE)
	note.text = s.t("cloudWorking")


## After signing in either way: when keeping, copy this phone's progress
## up; when fetching, show what is kept online and offer to take it.
func _signed_in(keep: bool, e: String, note: Label, go: Button) -> void:
	if e == "" and keep:
		e = await cloud.upload(progress.data)
	if e != "":
		note.add_theme_color_override("font_color", Look.VERMILION)
		note.text = s.t("cloudErr_" + e) if s.has("cloudErr_" + e) else s.t("cloudErrOther", {"e": e})
		return
	if keep:
		_build()
		return
	var back := await cloud.download()
	if back.is_empty():
		note.text = s.t("cloudNothing")
		return
	note.text = s.t("cloudFound", {"n": int(back.day) + 1, "taka": int(back.save.get("taka", 0))})
	go.text = s.t("cloudUse")
	for c in go.pressed.get_connections():
		go.pressed.disconnect(c.callable)
	go.pressed.connect(_restore.bind(back.save))


## Takes the progress from online in place of this phone's.
func _restore(save: Dictionary) -> void:
	var base := Progress.fresh()
	for k in save:
		base[k] = save[k]
	progress.data = base
	progress.save()
	cloud.last_day = int(base.day)
	_build()


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
func _overlay(title: String, rows: Array, on_close := Callable()) -> void:
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
	if on_close.is_valid():
		close.pressed.connect(on_close)
	head.add_child(close)
	col.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.scroll_deadzone = 12
	scroll.add_child(list)
	for r in rows:
		list.add_child(r)
	_let_scroll(list)


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


## Where Rahim Chacha rides today: Mirpur, or Old Dhaka once it is open.
func _area_row() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title := Look.label(s.t("areaWhere"), 14, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var here := progress.rickshaw_area()
	for area in Progress.AREAS:
		var is_open: bool = area == "mirpur" or progress.unlocked(area)
		var colour: Color = Look.MAGENTA if area == here else Color("B9B2A6")
		var pick := Look.button(s.t("area_" + area), colour, 14)
		pick.name = "Area_" + area
		pick.disabled = not is_open
		pick.pressed.connect(_choose_area.bind(area))
		row.add_child(pick)
	box.add_child(row)
	if not progress.unlocked("old_dhaka"):
		box.add_child(Look.label(s.t("areaLocked", {"level": int(b.n("unlocks.old_dhaka"))}), 12))
	return box


func _choose_area(area: String) -> void:
	if progress.choose_area(area):
		progress.save()
		_build()


func _buy_for(id: String, who: String) -> void:
	if progress.buy(id, who):
		progress.save()
		_build()


func _unlock_early(what: String) -> void:
	if progress.unlock_early(what):
		progress.save()
		_build()


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


## The tune on or off.
func _music_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var title := Look.label(s.t("music"), 15, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	for value in [true, false]:
		var picked: bool = Music.wanted() == value
		var pick := Look.button(s.t("musicOn" if value else "musicOff"), Look.MAGENTA if picked else Color("B9B2A6"), 15)
		pick.name = "Music_" + ("on" if value else "off")
		pick.pressed.connect(_set_music.bind(value))
		row.add_child(pick)
	return row


func _set_music(value: bool) -> void:
	music.switch(value)
	_build()


func _set_graphics(level: String) -> void:
	Graphics.save_level(level)
	_build()


func _set_language(code: String) -> void:
	s.lang = code
	Strings.save_lang(s.lang)
	_build()
