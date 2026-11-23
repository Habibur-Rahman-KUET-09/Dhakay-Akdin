## The menus around the days (§৩, §৫), painted like a rickshaw. First a
## title page; then the mohalla: a bar with the level, savings, stars and
## the run of days; the street with the three characters to pick; today's
## challenge, the season and a chapter waiting; and the big button into
## the day. Picking a character opens a sheet to get ready (where to ride,
## today's Dhaka, the target, the school fee, a tip). Along the bottom:
## the shop, the mohalla fund, the story book and the neighbours.
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
const Voice = preload("res://scripts/ui/voice.gd")
const Sfx = preload("res://scripts/ui/sfx.gd")
const Activity = preload("res://scripts/ui/activity.gd")

const WHO := ["rickshaw", "tea", "bus"]
const PAGES := ["hub", "shop", "fund", "story", "people"]
const PAGE_ICONS := {"hub": "home", "shop": "bag", "fund": "town", "story": "book", "people": "people"}
const UPGRADE_ICONS := {
	"new_rickshaw": "rickshaw", "battery_rickshaw": "bolt", "bench": "bench", "second_kettle": "kettle",
	"awning": "awning", "fridge": "fridge", "notebook": "ledger", "change_bag": "purse", "loud_voice": "voice",
}
const PROJECT_ICONS := {"street_lights": "lamp", "drain_cleaning": "drain", "bus_shelter": "shelter"}

## The title page shows once each time the game opens.
static var _title_done := false

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
## The character picked on the street ("" until the page first opens on
## today's character), the page showing, the character whose sheet is
## open (""), the shop's character, and whether the settings show.
var _tab := ""
var _page := "hub"
var _sheet := ""
var _shop_who := ""
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
	if not _title_done:
		_page = "title"
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
	if _shop_who == "":
		_shop_who = _tab if progress.open_characters().has(_tab) else "rickshaw"
	var bg := ColorRect.new()
	bg.color = Look.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if _page == "title":
		_title_page()
	else:
		_app_page()
	if _sheet != "":
		_start_sheet(_sheet)
	if _settings_open:
		_settings()


## From the title page into the mohalla.
func enter() -> void:
	_title_done = true
	_page = "hub"
	_build()


func show_page(page: String) -> void:
	_title_done = true
	_page = page
	_sheet = ""
	_build()


func open_sheet(who: String) -> void:
	_tab = who
	_sheet = who
	_build()


func _close_sheet() -> void:
	_sheet = ""
	_build()


# --- The title page -------------------------------------------------------------


func _title_page() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(Look.band(24))
	var art_box := Control.new()
	art_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_box.clip_contents = true
	art_box.custom_minimum_size = Vector2(0, 260)
	col.add_child(art_box)
	var art := TextureRect.new()
	art.texture = Look.icon_texture("title_art", 540)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_box.add_child(art)
	var kicker_row := CenterContainer.new()
	kicker_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	kicker_row.offset_top = 22
	kicker_row.offset_bottom = 60
	art_box.add_child(kicker_row)
	kicker_row.add_child(Look.pill("", s.t("titleKicker"), Look.OUTLINE, Look.CREAM, 17))

	var low := MarginContainer.new()
	for side in ["left", "right"]:
		low.add_theme_constant_override("margin_" + side, 28)
	low.add_theme_constant_override("margin_top", 10)
	low.add_theme_constant_override("margin_bottom", 22)
	col.add_child(low)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	low.add_child(box)
	var name_label := Look.title(s.t("appTitle"), 80, Look.MAGENTA)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var tagline := Look.label(s.t("titleTagline"), 18, true)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tagline)
	var play := Look.chunky(s.t("playGame"), Look.YELLOW, Look.OUTLINE, 30, 8, 22)
	play.name = "Play"
	play.icon = Look.icon_texture("play", 26)
	play.add_theme_constant_override("icon_max_width", 26)
	play.custom_minimum_size = Vector2(0, 84)
	play.pressed.connect(enter)
	box.add_child(play)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var day := int(progress.data.day)
	var status := Look.label(s.t("titleNew") if day == 0 else s.t("titleStatus", {"n": day, "level": progress.level()}), 15, true, Look.MUTED)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status)
	var gear := Look.chunky(s.t("settings"), Color.WHITE, Look.OUTLINE, 15, 3, 14)
	gear.name = "Settings"
	gear.autowrap_mode = TextServer.AUTOWRAP_OFF
	gear.pressed.connect(_open_settings)
	row.add_child(gear)
	box.add_child(row)
	col.add_child(Look.band(24))


# --- The app pages: the bar on top, a page, the menu below ---------------------


func _app_page() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(_top_bar())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# A finger has to move a little before it scrolls, so taps stay taps.
	scroll.scroll_deadzone = 12
	col.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_top", 0 if _page == "hub" else 14)
	margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	match _page:
		"shop":
			_shop_page(page)
		"fund":
			_fund_page(page)
		"story":
			_story_page(page)
		"people":
			_people_page(page)
		_:
			_hub_page(page, margin)
	_let_scroll(margin)
	if _page == "hub":
		col.add_child(_play_button())
	col.add_child(_nav())


## Level (with a ring of XP), savings, stars, the run of days, settings.
func _top_bar() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Look.CREAM
	style.border_color = Look.OUTLINE
	style.border_width_bottom = 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	row.add_child(_level_badge())
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(stats)
	stats.add_child(_stat("coin", str(int(progress.data.taka))))
	stats.add_child(_stat("star", str(int(progress.data.tara))))
	stats.add_child(_stat("flame", str(int(progress.data.streak.count))))
	var gear := _square_button("gear", s.t("settings"))
	gear.name = "Settings"
	gear.pressed.connect(_open_settings)
	row.add_child(gear)
	return panel


func _stat(icon_name: String, text: String) -> Control:
	var p := Look.pill(icon_name, text, Color.WHITE, Look.OUTLINE, 17)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## The level in a white disc, its XP towards the next level as a ring.
func _level_badge() -> Control:
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(62, 62)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var share := float(progress.xp()) / maxf(1.0, float(progress.to_next(progress.level())))
	var paint := func():
		var c := badge.size / 2
		badge.draw_circle(c, 29, Look.OUTLINE)
		badge.draw_circle(c, 26, Color.WHITE)
		badge.draw_arc(c, 21, 0, TAU, 48, Color("E9DCC3"), 6, true)
		if share > 0.0:
			badge.draw_arc(c, 21, -PI / 2, -PI / 2 + TAU * clampf(share, 0.0, 1.0), 48, Look.PARROT, 6, true)
	badge.draw.connect(paint)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", -6)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(center)
	var word := Look.label(s.t("levelShort"), 11, true)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.autowrap_mode = TextServer.AUTOWRAP_OFF
	center.add_child(word)
	var number := Look.label(str(progress.level()), 22, true)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.autowrap_mode = TextServer.AUTOWRAP_OFF
	center.add_child(number)
	return badge


func _square_button(icon_name: String, tip: String) -> Button:
	var gear := Look.chunky("", Color.WHITE, Look.OUTLINE, 14, 3, 14)
	gear.icon = Look.icon_texture(icon_name, 26)
	gear.add_theme_constant_override("icon_max_width", 26)
	gear.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear.custom_minimum_size = Vector2(52, 52)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear.tooltip_text = tip
	return gear


## The five pages along the bottom, on a dark strip.
func _nav() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Look.OUTLINE
	style.content_margin_top = 8
	style.content_margin_bottom = 12
	style.content_margin_left = 4
	style.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	panel.add_child(row)
	for page in PAGES:
		var on: bool = page == _page
		var ink: Color = Look.YELLOW if on else Look.CREAM
		var button := Button.new()
		button.name = "Nav_" + page
		button.flat = true
		button.text = s.t("nav_" + page)
		button.icon = Look.icon_texture(PAGE_ICONS[page], 28)
		button.add_theme_constant_override("icon_max_width", 28)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 62)
		button.add_theme_font_override("font", Look.font(Look.BOLD if on else Look.SEMIBOLD))
		button.add_theme_font_size_override("font_size", 14)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color",
				"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
			button.add_theme_color_override(state, ink)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(show_page.bind(page))
		row.add_child(button)
	return panel


## A page's name, painted.
func _page_title(text: String, extra := "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var t := Look.title(text, 40, Look.OUTLINE, false)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	if extra != "":
		var e := Look.label(extra, 15, true, Look.MUTED)
		e.autowrap_mode = TextServer.AUTOWRAP_OFF
		e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(e)
	return row


# --- The mohalla --------------------------------------------------------------


func _hub_page(page: VBoxContainer, margin: MarginContainer) -> void:
	# The street runs edge to edge.
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	page.add_child(_street())
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	pad.add_child(inner)
	page.add_child(pad)
	if _crash != "":
		inner.add_child(_crash_card())
	var waiting := story.waiting(progress.data)
	if not waiting.is_empty():
		inner.add_child(_chapter_card(waiting[0]))
	var challenge := _challenge_card()
	if challenge != null:
		inner.add_child(challenge)
	inner.add_child(_season_card())
	var version := Look.label("%s · %s" % [s.t("testBuild"), ProjectSettings.get_setting("application/config/version", "dev")], 12, false, Color("8A8178"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(version)


## The street, drawn, with the three characters standing on it: tap one
## to get them ready for the day.
func _street() -> Control:
	var scene := Control.new()
	scene.custom_minimum_size = Vector2(0, 400)
	scene.clip_contents = true
	var art := TextureRect.new()
	art.texture = Look.icon_texture("mohalla", 540)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(art)
	var calendar := Calendar.new()
	var fest := calendar.festival(progress.date())
	if not fest.is_empty():
		var flags := TextureRect.new()
		flags.texture = Look.icon_texture("bunting", 540)
		flags.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flags.stretch_mode = TextureRect.STRETCH_SCALE
		flags.set_anchors_preset(Control.PRESET_TOP_WIDE)
		flags.offset_top = 0
		flags.offset_bottom = 56
		flags.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scene.add_child(flags)
	var over := MarginContainer.new()
	over.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		over.add_theme_constant_override("margin_" + side, 10)
	over.add_theme_constant_override("margin_top", 12)
	over.add_theme_constant_override("margin_bottom", 18)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(over)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(col)
	var where_row := HBoxContainer.new()
	where_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	where_row.add_child(Look.pill(_weather_icon(), _where_line(), Look.OUTLINE, Look.CREAM, 15, Look.CREAM))
	col.add_child(where_row)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	var people := HBoxContainer.new()
	people.add_theme_constant_override("separation", 4)
	people.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(people)
	for who in WHO:
		people.add_child(_character_spot(who))
	return scene


## "Mirpur · 22 July · Monsoon", or the festival's name.
func _where_line() -> String:
	var date := progress.date()
	var parts := PackedStringArray([s.t("area_" + progress.rickshaw_area())])
	var m := Calendar.month_of(date)
	if m >= 1 and m <= 12:
		parts.append("%d %s" % [int(date.substr(8, 2)), s.t("month_%d" % m)])
	var fest := Calendar.new().festival(date)
	if not fest.is_empty():
		parts.append(str(fest.name.get(s.lang, fest.name.en)))
	else:
		parts.append(s.t("season_" + _season()))
	return " · ".join(parts)


func _season() -> String:
	var m := Calendar.month_of(progress.date())
	if m >= 6 and m <= 9:
		return "monsoon"
	if m == 12 or m == 1:
		return "winter"
	if m == 4 or m == 5:
		return "hot"
	return "fair"


func _weather_icon() -> String:
	return {"monsoon": "rain", "winter": "fog", "hot": "sun", "fair": "sun"}[_season()]


## One character on the street: a ribbon if it is their double-money day,
## their face in their colour (ringed in yellow when picked, locked if not
## open yet) and their name.
func _character_spot(who: String) -> Control:
	var open := progress.open_characters().has(who)
	var picked: bool = who == _tab
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ribbon_box := CenterContainer.new()
	ribbon_box.custom_minimum_size = Vector2(0, 30)
	ribbon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(ribbon_box)
	if open and who == progress.featured() and not progress.daily().featured:
		var ribbon := Look.pill("", s.t("tabDouble"), Look.YELLOW, Look.OUTLINE, 14)
		ribbon.rotation_degrees = -4
		ribbon_box.add_child(ribbon)
	var face_box := CenterContainer.new()
	face_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(face_box)
	face_box.add_child(_face(who, 104 if picked else 90, picked, open))
	var plate_box := CenterContainer.new()
	plate_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(plate_box)
	var name_text := s.t(_name_key(who))
	if not open:
		name_text = s.t("lockedPlate", {"name": name_text, "level": int(b.n("unlocks." + _unlock_of(who)))})
	var plate := Look.pill("", name_text, Color.WHITE, Look.OUTLINE, 15)
	plate_box.add_child(plate)
	# The whole spot is one button, drawn over it.
	var wrap := MarginContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(col)
	var tap := Button.new()
	tap.name = "Pick_" + who
	tap.flat = true
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tap.pressed.connect(open_sheet.bind(who))
	wrap.add_child(tap)
	return wrap


## A character's face in a disc of their colour.
func _face(who: String, px: int, picked := false, open := true) -> Control:
	var disc := Panel.new()
	disc.custom_minimum_size = Vector2(px, px)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = _colour_of(who) if open else Color("B9B2A6")
	style.border_color = Look.YELLOW if picked else Look.OUTLINE
	style.set_border_width_all(6 if picked else 4)
	style.set_corner_radius_all(px)
	style.anti_aliasing = true
	if picked:
		style.shadow_color = Look.OUTLINE
		style.shadow_size = 3
	disc.add_theme_stylebox_override("panel", style)
	var face := TextureRect.new()
	face.texture = Look.icon_texture({"rickshaw": "rahim", "tea": "monir", "bus": "babu"}[who], px)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.offset_left = px * 0.1
	face.offset_right = -px * 0.1
	face.offset_top = px * 0.08
	face.offset_bottom = 0
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not open:
		face.modulate = Color(1, 1, 1, 0.45)
	disc.add_child(face)
	if not open:
		var lock := Look.icon("lock", int(px * 0.38), Look.OUTLINE)
		lock.set_anchors_preset(Control.PRESET_CENTER)
		lock.grow_horizontal = Control.GROW_DIRECTION_BOTH
		lock.grow_vertical = Control.GROW_DIRECTION_BOTH
		disc.add_child(lock)
	return disc


## Today's challenge, and whether it is done.
func _challenge_card() -> Control:
	var c := progress.challenge()
	if c.is_empty():
		return null
	var done: bool = progress.daily().challenge
	var panel := _card(Color.WHITE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_icon_tile("target", Look.YELLOW, Look.OUTLINE))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(Look.label(s.t("todayChallenge", {"name": s.t(_name_key(c.who))}), 14, true, Look.MUTED))
	text.add_child(Look.label(s.t("ch_" + c.id, {"goal": int(c.goal)}), 18, true))
	if done:
		row.add_child(Look.icon("check", 32))
	return panel


## The festival (and its tip), or what the season brings.
func _season_card() -> Control:
	var panel := _card(Color("E8F1FB"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var fest := Calendar.new().festival(progress.date())
	var text := ""
	if not fest.is_empty():
		row.add_child(_icon_tile("flag", Look.MAGENTA, Color.WHITE))
		text = str(fest.name.get(s.lang, fest.name.en))
		if int(fest.tip) > 0:
			text += " · " + s.t("festivalTip", {"n": int(fest.tip)})
	else:
		row.add_child(_icon_tile(_weather_icon(), Look.SKY_DARK, Color.WHITE))
		var season := _season()
		text = s.t({"monsoon": "seasonMonsoon", "winter": "seasonWinter", "hot": "seasonHot", "fair": "seasonFair"}[season])
	var l := Look.label(text, 16, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return panel


## A new story chapter to read.
func _chapter_card(c: Dictionary) -> Control:
	var panel := _card(Color("FDE7F0"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_icon_tile("book", Look.MAGENTA, Color.WHITE))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	text.add_child(Look.label(s.t("newChapter"), 14, true, Look.MAGENTA))
	text.add_child(Look.label(s.t("storyChapter", {"n": int(c.n), "title": c.title[s.lang]}), 18, true))
	row.add_child(text)
	var read := Look.chunky(s.t("readChapter"), Look.MAGENTA, Color.WHITE, 17, 4, 14)
	read.autowrap_mode = TextServer.AUTOWRAP_OFF
	read.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	read.pressed.connect(_play_chapter.bind(c.id, ""))
	row.add_child(read)
	return panel


## The big way into the day, for the character picked.
func _play_button() -> Control:
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 12)
	var who := _tab
	var open := progress.open_characters().has(who)
	var ink: Color = Color.WHITE
	var go := Look.chunky("", _deep_of(who) if open else Look.SAND, ink if open else Look.OUTLINE, 20, 7, 22)
	go.name = "PlayDay"
	go.custom_minimum_size = Vector2(0, 84)
	go.pressed.connect(open_sheet.bind(who))
	pad.add_child(go)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -14
	row.offset_bottom = -7
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	go.add_child(row)
	var disc := Panel.new()
	disc.custom_minimum_size = Vector2(56, 56)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ds := Look.card(Look.YELLOW, 28, 3)
	disc.add_theme_stylebox_override("panel", ds)
	var tri := Look.icon("play", 24)
	tri.set_anchors_preset(Control.PRESET_CENTER)
	tri.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tri.grow_vertical = Control.GROW_DIRECTION_BOTH
	tri.offset_left = -10
	tri.offset_right = 14
	tri.offset_top = -12
	tri.offset_bottom = 12
	disc.add_child(tri)
	row.add_child(disc)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", -2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var big := Look.label(s.t("playDay", {"n": int(progress.data.day) + 1}), 26, true, ink if open else Look.OUTLINE)
	big.autowrap_mode = TextServer.AUTOWRAP_OFF
	big.clip_text = true
	text.add_child(big)
	var small := "%s · %s" % [s.t(_name_key(who)), s.t(_role_key(who))]
	if open and who == progress.featured() and not progress.daily().featured:
		small += " · " + s.t("tabDouble")
	var sub := Look.label(small, 15, false, ink if open else Look.OUTLINE)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.clip_text = true
	text.add_child(sub)
	return pad


# --- Getting ready for the day ---------------------------------------------------


## A sheet over the mohalla: who, where, today's Dhaka, what to aim for,
## a tip, and the way into the day.
func _start_sheet(who: String) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.12, 0.15, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var outside := Button.new()
	outside.flat = true
	outside.set_anchors_preset(Control.PRESET_FULL_RECT)
	outside.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	outside.pressed.connect(_close_sheet)
	shade.add_child(outside)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Look.CREAM
	style.border_color = Look.OUTLINE
	style.border_width_top = 4
	style.corner_radius_top_left = 30
	style.corner_radius_top_right = 30
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_top = 90
	shade.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(_face(who, 100, false, progress.open_characters().has(who)))
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 0)
	var n := Look.title(s.t(_name_key(who)), 42, _deep_of(who), false)
	names.add_child(n)
	names.add_child(Look.label("%s · %s" % [s.t(_role_key(who)), s.t("dayN", {"n": int(progress.data.day) + 1})], 16, true))
	head.add_child(names)
	var close := _square_button("close", s.t("close"))
	close.name = "CloseSheet"
	close.pressed.connect(_close_sheet)
	head.add_child(close)
	col.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)

	if not progress.open_characters().has(who):
		_locked_body(body, who)
		_let_scroll(body)
		return
	if who == "rickshaw":
		body.add_child(_caption(s.t("whereTitle")))
		body.add_child(_area_row())
	body.add_child(_caption(s.t("todayDhaka")))
	body.add_child(_today_chips(who))
	body.add_child(_goals_card(who))
	body.add_child(_tip_card(who))
	_let_scroll(body)

	var start := Look.chunky(s.t("start_" + who), Look.YELLOW, Look.OUTLINE, 26, 8, 22)
	start.name = {"rickshaw": "Drive", "tea": "OpenStall", "bus": "Board"}[who]
	start.icon = Look.icon_texture("play", 24)
	start.add_theme_constant_override("icon_max_width", 24)
	start.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	start.custom_minimum_size = Vector2(0, 78)
	start.pressed.connect(_start.bind(who, {"rickshaw": "res://scenes/rickshaw.tscn", "tea": "res://scenes/tea.tscn", "bus": "res://scenes/bus.tscn"}[who]))
	col.add_child(start)
	var secs := {"rickshaw": int(b.n("rickshaw.day_seconds")), "tea": int(b.n("tea_stall.day_seconds"))}
	if secs.has(who) and secs[who] > 0:
		var length := Look.label(s.t("playLength", {"n": int(round(secs[who] / 60.0))}), 14, true, Look.MUTED)
		length.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(length)


func _caption(text: String) -> Label:
	return Look.label(text, 15, true, Look.MUTED)


## Today's Dhaka in chips: the season or a festival, and a double-money day.
func _today_chips(who: String) -> Control:
	var flow := VBoxContainer.new()
	flow.add_theme_constant_override("separation", 8)
	var fest := Calendar.new().festival(progress.date())
	if not fest.is_empty():
		var line := str(fest.name.get(s.lang, fest.name.en))
		if int(fest.tip) > 0:
			line += " · " + s.t("festivalTip", {"n": int(fest.tip)})
		flow.add_child(_wrap_pill("flag", line, Color("FDE7F0"), Look.MAGENTA))
	flow.add_child(_wrap_pill(_weather_icon(), s.t("chip_" + _season()), Color("D6ECF7"), Look.SKY_DARK))
	if who == progress.featured() and not progress.daily().featured:
		flow.add_child(_wrap_pill("coin", s.t("chipDouble", {"name": s.t(_name_key(who))}), Color("FFE9A8"), Color.WHITE))
	return flow


## A chip the width of the sheet, its words free to wrap.
func _wrap_pill(icon_name: String, text: String, fill: Color, tint: Color) -> Control:
	var p := PanelContainer.new()
	var st := Look.card(fill, 16, 3)
	st.content_margin_left = 8
	st.content_margin_right = 12
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	p.add_child(row)
	row.add_child(Look.icon(icon_name, 22, tint))
	var l := Look.label(text, 15, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return p


## What to aim for today: the target, the challenge if it is theirs, the
## school fee (Rahim Chacha), and how the last day went.
func _goals_card(who: String) -> Control:
	var panel := _card(Color.WHITE, 20)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var rows := 0
	if who == "rickshaw":
		col.add_child(_goal_row("coin", s.t("goalTarget"), s.t("takaN", {"n": int(b.n("rickshaw.daily_target"))}), Color.WHITE))
		rows += 1
	var c := progress.challenge()
	if not c.is_empty() and c.who == who:
		if rows > 0:
			col.add_child(_dash())
		var done: bool = progress.daily().challenge
		col.add_child(_goal_row("check" if done else "star", s.t("ch_" + c.id, {"goal": int(c.goal)}), s.t("challengeMet") if done else s.t("plusStars", {"n": int(b.n("tara.daily_challenge"))}), Color.WHITE))
		rows += 1
	if who == "rickshaw":
		if rows > 0:
			col.add_child(_dash())
		var school := int(progress.data.rickshaw.school)
		col.add_child(_goal_row("cap", s.t("schoolTitle"), "%d / %d" % [school, progress.school_goal()], Look.OUTLINE))
		col.add_child(Look.bar(school, progress.school_goal(), Look.MAGENTA, 16))
		col.add_child(Look.label(s.t("schoolHelp"), 13, false, Look.MUTED))
		rows += 1
	var last := _last_day_line(who)
	if last != "":
		if rows > 0:
			col.add_child(_dash())
		col.add_child(_goal_row("calendar", last, "", Look.OUTLINE))
	return panel


func _goal_row(icon_name: String, text: String, value: String, tint: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(Look.icon(icon_name, 28, tint))
	var l := Look.label(text, 16, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	if value != "":
		var v := Look.label(value, 17, true)
		v.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(v)
	return row


func _dash() -> Control:
	var line := ColorRect.new()
	line.color = Color("E3D7BF")
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## The last day as this character (the newest such record), or "".
func _last_day_line(who: String) -> String:
	for h in progress.data.history:
		if h.get("who", "rickshaw") != who:
			continue
		if who == "rickshaw":
			return s.t("lastDay", {"money": int(h.earned), "trips": int(h.get("trips", 0)), "stars": h.stars})
		if who == "tea":
			return s.t("teaLastDay", {"money": int(h.earned), "served": int(h.served)})
		return s.t("busLastDay", {"money": int(h.earned), "riders": int(h.get("riders", 0))})
	return ""


func _tip_card(who: String) -> Control:
	var panel := _card(Color("E6F4EC"), 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(Look.icon("bulb", 26, Look.PARROT_DARK))
	var l := Look.label(s.t("tip_" + who), 15)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return panel


## A character not open yet: when they open, or the stars to open early.
func _locked_body(box: VBoxContainer, who: String) -> void:
	var unlock := _unlock_of(who)
	var panel := _card(Look.SAND, 18)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(Look.icon("lock", 30, Look.OUTLINE))
	var l := Look.label(s.t("unlocksAt", {"level": int(b.n("unlocks." + unlock))}), 18, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	col.add_child(row)
	var cost := int(b.n("unlocks.early_unlock_tara"))
	if int(progress.data.tara) >= cost:
		var early := Look.chunky(s.t("unlockEarly", {"n": cost}), Look.MAGENTA, Color.WHITE, 18, 5, 16)
		early.icon = Look.icon_texture("star", 24)
		early.add_theme_constant_override("icon_max_width", 24)
		early.add_theme_color_override("icon_normal_color", Color.WHITE)
		early.pressed.connect(_unlock_early.bind(unlock))
		col.add_child(early)
	else:
		col.add_child(Look.label(s.t("earlyHelp", {"n": cost}), 15))
	box.add_child(panel)


## Where Rahim Chacha rides today: Mirpur, or Old Dhaka once it is open.
func _area_row() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var here := progress.rickshaw_area()
	for area in Progress.AREAS:
		var is_open: bool = area == "mirpur" or progress.unlocked(area)
		var text := s.t("area_" + area)
		if not is_open:
			text += "\n" + s.t("tabLocked", {"level": int(b.n("unlocks." + area))})
		var pick := Look.chunky(text, Color.WHITE, Look.OUTLINE, 17, 4 if area == here else 2, 16)
		pick.name = "Area_" + area
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.custom_minimum_size = Vector2(0, 64)
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if area == here:
			pick.icon = Look.icon_texture("check", 26)
			var st := pick.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			st.border_color = Look.MAGENTA
			pick.add_theme_stylebox_override("normal", st)
			pick.add_theme_stylebox_override("hover", st)
			pick.add_theme_color_override("icon_normal_color", Color.WHITE)
		elif not is_open:
			pick.icon = Look.icon_texture("lock", 24)
		pick.add_theme_constant_override("icon_max_width", 26)
		pick.disabled = not is_open
		pick.pressed.connect(_choose_area.bind(area))
		grid.add_child(pick)
	return grid


func _choose_area(area: String) -> void:
	if progress.choose_area(area):
		progress.save()
		_build()


# --- The shop ------------------------------------------------------------------


func _shop_page(page: VBoxContainer) -> void:
	page.add_child(_page_title(s.t("nav_shop")))
	page.add_child(Look.label(s.t("shopHelp"), 15, false, Look.MUTED))
	var tabs := GridContainer.new()
	tabs.columns = 3
	tabs.add_theme_constant_override("h_separation", 8)
	var open := progress.open_characters()
	for who in WHO:
		var on: bool = who == _shop_who
		var text := s.t(_name_key(who))
		if not open.has(who):
			text = s.t("lockedPlate", {"name": text, "level": int(b.n("unlocks." + _unlock_of(who)))})
		var tab := Look.chunky(text, _deep_of(who) if on else Color.WHITE, Color.WHITE if on else Look.OUTLINE, 15, 4 if on else 2, 14)
		tab.name = "ShopTab_" + who
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 54)
		tab.disabled = not open.has(who)
		tab.pressed.connect(_pick_shop.bind(who))
		tabs.add_child(tab)
	page.add_child(tabs)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	page.add_child(grid)
	for id in Progress.UPGRADE_LISTS[_shop_who][1]:
		grid.add_child(_upgrade_card(id, _shop_who))


func _pick_shop(who: String) -> void:
	_shop_who = who
	_build()


## One thing to buy: its picture, name, what it does, and its price (or
## that it is bought, or how much more is needed).
func _upgrade_card(id: String, who: String) -> Control:
	var panel := _card(Color.WHITE, 20)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", Look.card(_tint_of(who), 14, 0))
	tile.custom_minimum_size = Vector2(0, 86)
	var center := CenterContainer.new()
	center.add_child(Look.icon(UPGRADE_ICONS.get(id, "bag"), 54, Look.OUTLINE))
	tile.add_child(center)
	col.add_child(tile)
	col.add_child(Look.label(s.t("up_" + id), 18, true))
	var help := Look.label(s.t("upHelp_" + id), 14, false, Color("4A423A"))
	help.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(help)
	if progress.has_upgrade(id, who):
		var owned := Look.pill("check", s.t("owned"), Color("E6F4EC"), Look.OUTLINE, 16)
		var c := CenterContainer.new()
		c.add_child(owned)
		col.add_child(c)
	else:
		var cost := progress.price(id, who)
		var short := cost - int(progress.data.taka)
		var buy := Look.chunky(str(cost), Look.YELLOW, Look.OUTLINE, 18, 5, 14)
		buy.name = "Buy_" + id
		buy.icon = Look.icon_texture("coin", 24)
		buy.add_theme_constant_override("icon_max_width", 24)
		buy.custom_minimum_size = Vector2(0, 52)
		buy.disabled = short > 0
		buy.pressed.connect(_buy_for.bind(id, who))
		col.add_child(buy)
		if short > 0:
			var more := Look.label(s.t("needMore", {"n": short}), 13, true, Look.MUTED)
			more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(more)
	return panel


func _buy_for(id: String, who: String) -> void:
	if progress.buy(id, who):
		progress.save()
		_build()


# --- The mohalla fund ----------------------------------------------------------


func _fund_page(page: VBoxContainer) -> void:
	page.add_child(_page_title(s.t("fundPageTitle")))
	var panel := _card(Color.WHITE, 20)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(Look.label(s.t("fundHelp"), 15, false, Color("4A423A")))
	var now: String = progress.data.fundProject
	var done: Array = progress.data.mohalla.projectsDone
	for p in Progress.PROJECTS:
		col.add_child(_dash())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var is_done: bool = done.has(p)
		var is_now: bool = p == now and not is_done
		row.add_child(_icon_tile(PROJECT_ICONS.get(p, "town"), Look.PARROT_DARK if is_done else (Look.YELLOW if is_now else Look.SAND), Color.WHITE if is_done else Look.OUTLINE))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 4)
		row.add_child(text)
		var top := HBoxContainer.new()
		var name_label := Look.label(s.t("project_" + p), 18, true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_label)
		var state := s.t("projectIsDone") if is_done else (s.t("projectNow") if is_now else s.t("projectNext"))
		var st := Look.label(state, 14, true, Look.PARROT_DARK if is_done else Look.MUTED)
		st.autowrap_mode = TextServer.AUTOWRAP_OFF
		top.add_child(st)
		text.add_child(top)
		var goal := int(b.n("fund_projects.%s.cost" % p))
		if is_now:
			text.add_child(Look.label("%s / %s" % [s.t("takaN", {"n": int(progress.data.fund)}), s.t("takaN", {"n": progress.fund_goal()})], 15, true))
			text.add_child(Look.bar(int(progress.data.fund), progress.fund_goal(), Look.YELLOW, 16))
		elif not is_done:
			text.add_child(Look.label(s.t("takaN", {"n": goal}), 15, false, Look.MUTED))
		col.add_child(row)
	page.add_child(panel)
	page.add_child(_caption(s.t("recentDays")))
	var days := _card(Color.WHITE, 18)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	days.add_child(list)
	if progress.data.history.is_empty():
		list.add_child(Look.label(s.t("noDaysYet"), 15))
	for h in progress.data.history:
		var line := s.t("historyLine", {"day": int(h.day), "money": int(h.earned), "trips": int(h.get("trips", 0)), "stars": h.stars})
		if h.get("who", "") == "tea":
			line = s.t("teaHistoryLine", {"day": int(h.day), "money": int(h.earned), "served": int(h.get("served", 0))})
		elif h.get("who", "") == "bus":
			line = s.t("busHistoryLine", {"day": int(h.day), "money": int(h.earned), "riders": int(h.get("riders", 0))})
		list.add_child(Look.label(line, 15, h.met, Look.PARROT_DARK if h.met else Look.OUTLINE))
	page.add_child(days)


# --- The story book --------------------------------------------------------------


func _story_page(page: VBoxContainer) -> void:
	page.add_child(_page_title(s.t("storyTitle"), s.t("chaptersRead", {"n": story.read(progress.data).size(), "all": story.chapters.size()})))
	var waiting := story.waiting(progress.data)
	var next_id: String = waiting[0].id if not waiting.is_empty() else ""
	for c in story.chapters:
		var read: bool = progress.seen(c.id)
		var is_next: bool = c.id == next_id
		var panel := _card(Look.MAGENTA if is_next else (Color.WHITE if read else Look.SAND), 18)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var num := Look.title(str(int(c.n)), 34, Color.WHITE if is_next else (Look.MAGENTA if read else Look.MUTED), false)
		num.custom_minimum_size = Vector2(34, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(num)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		var ink: Color = Color.WHITE if is_next else Look.OUTLINE
		text.add_child(Look.label(s.t(_name_key(c.who)), 13, true, ink if is_next else Look.MUTED))
		var title: String = c.title[s.lang] if (read or is_next) else s.t("chapterLocked", {"n": int(c.n)})
		text.add_child(Look.label(title, 17, true, ink))
		if is_next:
			var go := Look.chunky(s.t("readChapter"), Look.YELLOW, Look.OUTLINE, 16, 4, 14)
			go.autowrap_mode = TextServer.AUTOWRAP_OFF
			go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			go.pressed.connect(_play_chapter.bind(c.id, ""))
			row.add_child(go)
		elif read:
			var again := Look.chunky(s.t("readAgain"), Color.WHITE, Look.OUTLINE, 14, 3, 14)
			again.autowrap_mode = TextServer.AUTOWRAP_OFF
			again.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			again.pressed.connect(_reread.bind(c.id))
			row.add_child(again)
		else:
			row.add_child(Look.icon("lock", 24, Look.MUTED))
		page.add_child(panel)


# --- The neighbours ------------------------------------------------------------


func _people_page(page: VBoxContainer) -> void:
	page.add_child(_page_title(s.t("notebook")))
	page.add_child(Look.label(s.t("notebookHelp"), 15, false, Look.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	page.add_child(grid)
	for p in neighbours.people:
		var rel := progress.relation(p.id)
		var met: bool = progress.data.npcs.has(p.id)
		var panel := _card(Color.WHITE if met else Look.SAND, 16)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)
		var face := "meh"
		var fill := Color("FFE9A8")
		var mood := s.t("mood_ok")
		if not met:
			fill = Look.SAND
			mood = s.t("notMet")
		elif rel > 0:
			face = "smile"
			fill = Color("E6F4EC")
			mood = s.t("mood_good")
		elif rel < 0:
			face = "frown"
			fill = Color("FDE2DC")
			mood = s.t("mood_bad")
		row.add_child(_icon_tile(face, fill, Look.OUTLINE, 44))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", -2)
		row.add_child(text)
		text.add_child(Look.label(p[s.lang], 16, true))
		text.add_child(Look.label(p.role[s.lang], 13, false, Look.MUTED))
		text.add_child(Look.label(mood, 13, true, Look.PARROT_DARK if met and rel > 0 else (Color("B3261E") if met and rel < 0 else Look.MUTED)))
		grid.add_child(panel)
	if not progress.data.log.is_empty():
		page.add_child(_caption(s.t("lately")))
		var card := _card(Color.WHITE, 18)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 6)
		card.add_child(list)
		var shown := 0
		for e in progress.data.log:
			if shown >= 8:
				break
			shown += 1
			var change := int(e.delta)
			list.add_child(Look.label(s.t("logLine", {"name": neighbours.name_of(e.id, s.lang), "what": s.t("log_" + str(e.what)),
				"n": ("+" if change > 0 else "") + str(change)}), 14))
		page.add_child(card)


# --- Small parts ----------------------------------------------------------------


func _card(fill := Color.WHITE, radius := 18) -> PanelContainer:
	var panel := PanelContainer.new()
	var st := Look.card(fill, radius, 3)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", st)
	return panel


## A square of colour with an icon in it.
func _icon_tile(icon_name: String, fill: Color, tint: Color, px := 48) -> Control:
	var tile := PanelContainer.new()
	var st := Look.card(fill, 14, 3)
	st.content_margin_left = 0
	st.content_margin_right = 0
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	tile.add_theme_stylebox_override("panel", st)
	tile.custom_minimum_size = Vector2(px, px)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(Look.icon(icon_name, int(px * 0.56), tint))
	tile.add_child(c)
	return tile


func _name_key(who: String) -> String:
	return {"rickshaw": "rickshawName", "tea": "teaName", "bus": "busName"}[who]


func _role_key(who: String) -> String:
	return {"rickshaw": "rickshawRole", "tea": "teaRole", "bus": "busRole"}[who]


## Each character's colour.
func _colour_of(who: String) -> Color:
	return {"rickshaw": Look.MAGENTA, "tea": Look.PARROT, "bus": Look.SKY}[who]


## Their colour dark enough for white words on it.
func _deep_of(who: String) -> Color:
	return {"rickshaw": Look.MAGENTA, "tea": Look.PARROT_DARK, "bus": Look.SKY_DARK}[who]


## A pale wash of their colour, behind pictures.
func _tint_of(who: String) -> Color:
	return {"rickshaw": Color("FDE7F0"), "tea": Color("E6F4EC"), "bus": Color("D6ECF7")}[who]


## What opens a character ("tea_stall" for the tea stall).
func _unlock_of(who: String) -> String:
	return {"rickshaw": "", "tea": "tea_stall", "bus": "bus"}[who]


func _unlock_early(what: String) -> void:
	if progress.unlock_early(what):
		progress.save()
		_build()


## Cards, rows and labels stopped a finger dragging the page: the touch
## ended at the card. Let everything but buttons and text boxes pass
## touches on, so the page scrolls from anywhere.
static func _let_scroll(node: Node) -> void:
	for c in node.get_children():
		if c is Control and not (c is BaseButton or c is LineEdit or c is ScrollContainer):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		_let_scroll(c)


## Shown after a run that ended suddenly: a note and a button that copies
## the log, so the player can send it.
func _crash_card() -> Control:
	var panel := _card(Color("FDECEA"), 16)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(Look.label(s.t("crashTitle"), 16, true, Look.VERMILION))
	box.add_child(Look.label(s.t("crashHelp"), 14))
	if _lowered:
		box.add_child(Look.label(s.t("graphicsLowered"), 14, true))
	var copy := Look.chunky(s.t("copyLog"), Look.OUTLINE, Color.WHITE, 15, 3, 12)
	copy.pressed.connect(_copy_log.bind(copy))
	box.add_child(copy)
	return panel


func _copy_log(button: Button) -> void:
	DisplayServer.clipboard_set(_crash)
	button.text = s.t("copied")


# --- Settings ------------------------------------------------------------------


## Settings, over the page: language, graphics, music, the online copy.
func _open_settings() -> void:
	_settings_open = true
	_settings()


func _settings() -> void:
	var rows := []
	var codes := ["bn", "en"]
	rows.append(_choice_row(s.t("languageLabel"), ["বাংলা", "English"], codes.find(s.lang), func(i): _set_language(codes[i]), "Language_", codes))
	var levels := ["high", "low"]
	rows.append(_choice_row(s.t("graphics"), [s.t("graphics_high"), s.t("graphics_low")], levels.find(Graphics.level()), func(i): _set_graphics(levels[i]), "Graphics_", levels))
	rows.append(Look.label(s.t("graphicsHelp"), 13, false, Look.MUTED))
	rows.append(_choice_row(s.t("music"), [s.t("musicOn"), s.t("musicOff")], 0 if Music.wanted() else 1, func(i): _set_music(i == 0), "Music_", ["on", "off"]))
	rows.append(_choice_row(s.t("voices"), [s.t("musicOn"), s.t("musicOff")], 0 if Voice.wanted() else 1, func(i): _set_voices(i == 0), "Voices_", ["on", "off"]))
	rows.append(_choice_row(s.t("hands"), [s.t("musicOn"), s.t("musicOff")], 0 if Activity.wanted() else 1, func(i): _set_hands(i == 0), "Hands_", ["on", "off"]))
	rows.append(_cloud_card())
	# Who recorded the street sounds (their licences ask to be named).
	var credits := Sfx.credits()
	if not credits.is_empty():
		rows.append(Look.label(s.t("soundCredits"), 14, true))
		for line in credits:
			rows.append(Look.label(line, 12, false, Look.MUTED))
	var version := Look.label("%s · %s" % [s.t("testBuild"), ProjectSettings.get_setting("application/config/version", "dev")], 12, false, Color("8A8178"))
	rows.append(version)
	_overlay(s.t("settings"), rows, _close_settings)


## A setting's name, then its choices side by side (the one in use filled).
func _choice_row(title: String, options: Array, picked: int, then: Callable, prefix: String, ids: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(Look.label(title.trim_suffix(":"), 16, true))
	var grid := GridContainer.new()
	grid.columns = options.size()
	grid.add_theme_constant_override("h_separation", 8)
	for i in options.size():
		var on := i == picked
		var pick := Look.chunky(options[i], Look.MAGENTA if on else Color.WHITE, Color.WHITE if on else Look.OUTLINE, 16, 4 if on else 2, 14)
		pick.name = prefix + str(ids[i])
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.custom_minimum_size = Vector2(0, 50)
		pick.pressed.connect(then.bind(i))
		grid.add_child(pick)
	box.add_child(grid)
	return box


func _close_settings() -> void:
	_settings_open = false


func _set_hands(value: bool) -> void:
	Activity.save_wanted(value)
	_build()


func _set_voices(value: bool) -> void:
	Voice.save_wanted(value)
	_build()


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


## The online copy: when it was last made, and the email to move phones.
func _cloud_card() -> Control:
	var panel := _card(Color("EEF2F5"), 16)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(Look.icon("cloud", 26, Look.SKY_DARK))
	var t := Look.label(s.t("cloudTitle"), 17, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	box.add_child(head)
	var status := s.t("cloudOff")
	if cloud.enabled():
		status = s.t("cloudNever") if cloud.last_time == "" else s.t("cloudLast", {"time": cloud.last_time.substr(0, 16), "n": cloud.last_day + 1})
	box.add_child(Look.label(status, 14))
	if not cloud.enabled():
		return panel
	if cloud.email != "":
		box.add_child(Look.label(s.t("cloudLinkedGoogle" if cloud.provider == "google" else "cloudLinked", {"email": cloud.email}), 14, true, Look.PARROT_DARK))
	else:
		box.add_child(Look.label(s.t("cloudHelp"), 13))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		var keep := Look.chunky(s.t("cloudKeep"), Look.SKY_DARK, Color.WHITE, 15, 4, 14)
		keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keep.pressed.connect(_email_form.bind(true))
		grid.add_child(keep)
		var fetch := Look.chunky(s.t("cloudFetch"), Color.WHITE, Look.OUTLINE, 15, 4, 14)
		fetch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fetch.pressed.connect(_email_form.bind(false))
		grid.add_child(fetch)
		box.add_child(grid)
	return panel


## Asks for an email and password: to tie this phone's progress to them
## (keep), or to bring progress from another phone (fetch).
func _email_form(keep: bool) -> void:
	var rows := []
	rows.append(Look.label(s.t("cloudKeepHelp" if keep else "cloudFetchHelp"), 14))
	var note := Look.label("", 14, true, Look.VERMILION)
	# Google first, where the phone and the build can do it.
	if cloud.google_ready():
		var google := Look.chunky(s.t("cloudGoogleKeep" if keep else "cloudGoogleFetch"), Color("1A73E8"), Color.WHITE, 17, 5, 14)
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
	var go := Look.chunky(s.t("cloudEmailKeep" if keep else "cloudEmailFetch"), Look.SKY_DARK, Color.WHITE, 16, 5, 14)
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


## A panel over the screen: a title, rows, and a close button.
func _overlay(title: String, rows: Array, on_close := Callable()) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.12, 0.15, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	var st := Look.chunky_style(Look.CREAM, 24, 6, 4)
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 16
	st.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", st)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 14
	panel.offset_right = -14
	panel.offset_top = 36
	panel.offset_bottom = -36
	shade.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var t := Look.title(title, 36, Look.OUTLINE, false)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := _square_button("close", s.t("close"))
	close.name = "Close"
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
	list.add_theme_constant_override("separation", 12)
	scroll.scroll_deadzone = 12
	scroll.add_child(list)
	for r in rows:
		list.add_child(r)
	_let_scroll(list)


# --- The story, and into the day ---------------------------------------------------


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


func _reread(id: String) -> void:
	_then_scene = ""
	var player := StoryPlayer.new()
	player.setup(story, story.chapter(id), s)
	add_child(player)


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
