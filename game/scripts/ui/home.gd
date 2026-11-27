## The menus around the days (§৩, §৫), painted like a rickshaw. First a
## title page; then the mohalla: a bar with the level, savings, stars and
## the run of days; the street with the three characters to pick; today's
## challenge, the season and a chapter waiting; and the big button into
## the day. Picking a character opens a sheet to get ready (where to ride,
## today's Dhaka, the target, the school fee, a tip). Along the bottom:
## the shop, the mohalla fund, the story book and the neighbours. Friends
## (codes, the week's list, gifts, the relay day) open from a card.
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
const Driving = preload("res://scripts/ui/driving.gd")
const Goods = preload("res://scripts/rules/goods.gd")
const ReadAloud = preload("res://scripts/ui/read_aloud.gd")
const Friends = preload("res://scripts/rules/friends.gd")
const Leaderboard = preload("res://scripts/rules/leaderboard.gd")
const League = preload("res://scripts/rules/league.gd")
const Ranked = preload("res://scripts/rules/ranked.gd")
const Cards = preload("res://scripts/rules/cards.gd")
const Season = preload("res://scripts/rules/season.gd")
const Stickers = preload("res://scripts/ui/stickers.gd")
const Share = preload("res://scripts/ui/share.gd")
const Juice = preload("res://scripts/ui/juice.gd")
const Race = preload("res://scripts/rules/race.gd")
const Together = preload("res://scripts/rules/together.gd")

const WHO := ["rickshaw", "tea", "bus", "fuchka", "delivery", "hawker", "boat"]
const PAGES := ["hub", "shop", "fund", "story", "people"]
const PAGE_ICONS := {"hub": "home", "shop": "bag", "fund": "town", "story": "book", "people": "people"}
const UPGRADE_ICONS := {
	"new_rickshaw": "rickshaw", "battery_rickshaw": "bolt", "bench": "bench", "second_kettle": "kettle",
	"awning": "awning", "fridge": "fridge", "notebook": "ledger", "change_bag": "purse", "loud_voice": "voice",
	"stool": "bench", "umbrella": "rain", "doi": "kettle",
	"gear_cycle": "bolt", "hot_bag": "bag", "raincoat": "rain",
	"big_basket": "bag", "masala": "star", "cooler": "fridge",
	"new_oars": "bolt", "chhoi": "awning", "big_boat": "bench",
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
## Friends: what just happened (a prize, gifts), the note under the
## buttons on their page, and whether they are being brought up to date.
var _friends_news: Array = []
var _friends_note: Label
var _friends_busy := false
## Leaderboards: stars just won, the list showing (period, character),
## the rows fetched for it and my place.
var _board_news: Array = []
var _lb_period := "day"
var _lb_who := "all"
var _lb_rows: Array = []
var _lb_rank := 0
var _lb_state := ""
## This week's area league as fetched: {area: {count, sum}}; "" / loading / ok.
var _league_now := {}
var _league_state := ""
## Last week's tournament prize, paid when the home opened in a new week.
var _rank_paid := {}
## Eid salami given when the home opened on an Eid day.
var _salami := {}
## Reading aloud: on (kept from the setting), and a finger held down
## (where, since when) to read what is under it.
var _read_aloud := false
var _hold_at := -1.0
var _hold_pos := Vector2.ZERO


func _ready() -> void:
	s.lang = Strings.saved_lang()
	_crash = CrashWatch.last_crash()
	# A crash in a 3D scene: next time, go easy on the graphics chip.
	if _crash != "" and Graphics.level() == "high":
		Graphics.save_level("low")
		_lowered = true
	progress = Progress.new(b)
	_rank_paid = Ranked.claim(progress.data, b, progress.date())
	_salami = progress.claim_salami()
	if not _rank_paid.is_empty() or not _salami.is_empty():
		progress.save()
	_read_aloud = ReadAloud.wanted()
	cloud = Cloud.new()
	add_child(cloud)
	music = Music.new()
	# The theme song on the home screen: the tune people hum.
	music.track = "tune_theme"
	music.volume_db = -6.0
	add_child(music)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if not _title_done:
		_page = "title"
	_build()
	_backup()


## Copies the save online if it has changed since the last copy.
func _backup() -> void:
	if cloud.enabled() and int(progress.data.day) != cloud.last_day:
		if await cloud.upload(progress.data) == "":
			_build()
	# And friends: my card out, theirs and their gifts in.
	_refresh_friends()


func _build() -> void:
	# A story being read stays (a copy online finishing behind it used to
	# rebuild the page and take the story away mid-way).
	for c in get_children():
		if c != cloud and c != music and not (c is StoryPlayer and not c.is_queued_for_deletion()):
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
	for c in get_children():
		if c is StoryPlayer:
			move_child(c, -1)
	if _page == "hub" and _sheet == "" and not _settings_open:
		_family_scene.call_deferred()


## From the title page into the mohalla.
func enter() -> void:
	_title_done = true
	_page = "hub"
	_build()


func show_page(page: String) -> void:
	_title_done = true
	if _page == "friends" and page != "friends":
		_friends_news = []
	if _page == "board" and page != "board":
		_board_news = []
		_league_state = ""
	_page = page
	_sheet = ""
	_build()
	if page == "friends":
		_refresh_friends()
	if page == "board":
		_load_board()


func open_sheet(who: String) -> void:
	_tab = who
	_sheet = who
	_build()


func _close_sheet() -> void:
	_sheet = ""
	_build()


# --- The title page -------------------------------------------------------------


func _title_page() -> void:
	var room := Look.safe_insets(get_viewport())
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_top = room.x
	col.offset_bottom = -room.y
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
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
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
		"friends":
			_friends_page(page)
		"board":
			_board_page(page)
		"together":
			_together_page(page)
		"cards":
			_cards_page(page)
		"season":
			_season_page(page)
		"stickers":
			_stickers_page(page)
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
	style.content_margin_top = 4 + Look.safe_insets(get_viewport()).x
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
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(center)
	var number := Look.label(str(progress.level()), 24, true)
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
	style.content_margin_bottom = 4 + Look.safe_insets(get_viewport()).y
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
	if not _salami.is_empty():
		inner.add_child(_salami_card())
	inner.add_child(_pass_card())
	inner.add_child(_ranked_card())
	inner.add_child(_album_card())
	inner.add_child(_stickers_card())
	inner.add_child(_together_card())
	if cloud.enabled():
		inner.add_child(_online_card())
	var friends := _friends_card()
	if friends != null:
		inner.add_child(friends)
	var leaders := _leader_card()
	if leaders != null:
		inner.add_child(leaders)
	inner.add_child(_news_card())
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
	# Six or seven on the street: smaller, so all fit across a phone.
	var many := WHO.size() > 5
	var px := 104 if picked else 90
	if WHO.size() > 6:
		px = 66 if picked else 56
	elif many:
		px = 84 if picked else 72
	face_box.add_child(_face(who, px, picked, open))
	var plate_box := CenterContainer.new()
	plate_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(plate_box)
	var name_text := s.t(_name_key(who))
	if not open:
		name_text = s.t("lockedPlate", {"name": name_text, "level": int(b.n("unlocks." + _unlock_of(who)))})
	var plate := Look.pill("", name_text, Color.WHITE, Look.OUTLINE, (11 if WHO.size() > 6 else 13) if many else 15)
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
	face.texture = Look.icon_texture({"rickshaw": "rahim", "tea": "monir", "bus": "babu", "fuchka": "julekha", "delivery": "ratul", "hawker": "kashem", "boat": "haripada"}[who], px)
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
	style.content_margin_bottom = 4 + Look.safe_insets(get_viewport()).y
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_top = 80 + Look.safe_insets(get_viewport()).x
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
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
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
		var race := _race_card()
		if race != null:
			body.add_child(race)
		body.add_child(_night_card())
	body.add_child(_caption(s.t("todayDhaka")))
	body.add_child(_today_chips(who))
	body.add_child(_goals_card(who))
	body.add_child(_tip_card(who))
	_let_scroll(body)

	var start := Look.chunky(s.t("start_" + who), Look.YELLOW, Look.OUTLINE, 26, 8, 22)
	start.name = {"rickshaw": "Drive", "tea": "OpenStall", "bus": "Board", "fuchka": "OpenCart", "delivery": "StartDeliveries", "hawker": "StartSelling", "boat": "StartRowing"}[who]
	start.icon = Look.icon_texture("play", 24)
	start.add_theme_constant_override("icon_max_width", 24)
	start.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	start.custom_minimum_size = Vector2(0, 78)
	start.pressed.connect(_start.bind(who, {"rickshaw": "res://scenes/rickshaw.tscn", "tea": "res://scenes/tea.tscn", "bus": "res://scenes/bus.tscn", "fuchka": "res://scenes/fuchka.tscn", "delivery": "res://scenes/delivery.tscn", "hawker": "res://scenes/hawker.tscn", "boat": "res://scenes/boat.tscn"}[who]))
	col.add_child(start)
	var secs := {"rickshaw": int(b.n("rickshaw.day_seconds")), "tea": int(b.n("tea_stall.day_seconds")), "fuchka": int(b.n("fuchka.day_seconds")), "delivery": int(b.n("delivery.day_seconds")), "hawker": int(b.n("hawker.day_seconds")), "boat": int(b.n("boat.day_seconds"))}
	if secs.has(who) and secs[who] > 0:
		var length := Look.label(s.t("playLength", {"n": int(round(secs[who] / 60.0))}), 14, true, Look.MUTED)
		length.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(length)


## The night shift: ten to two, from mohalla level 5.
func _night_card() -> Control:
	var panel := _card(Color("1E2A44"), 18)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	col.add_child(Look.label(s.t("nightTitle"), 17, true, Look.YELLOW))
	var about := Look.label(s.t("nightAbout"), 14, false, Color("E8E0CF"))
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(about)
	var level := int(b.n("night.unlock_level"))
	if progress.level() >= level:
		var go := Look.chunky(s.t("nightGo"), Look.YELLOW, Look.OUTLINE, 17, 4, 14)
		go.name = "NightGo"
		go.pressed.connect(_go.bind("res://scenes/night.tscn"))
		col.add_child(go)
	else:
		col.add_child(Look.label(s.t("nightLocked", {"n": level}), 14, true, Look.YELLOW))
	return panel


## Today's race with a ghost: the same ride for everyone today.
func _race_card() -> Control:
	var map = load("res://scripts/rules/road_map.gd").load_area(progress.rickshaw_area())
	var route := Race.route(map, progress.date(), int(b.n("race.low_tiles")), int(b.n("race.high_tiles")))
	if route.is_empty():
		return null
	var panel := _card(Color("EEF3FF"), 18)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	col.add_child(Look.label(s.t("raceTitle"), 17, true, Look.SKY_DARK))
	var about := Look.label(s.t("raceAbout", {"place": map.place_name(route.place, s.lang)}), 14)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(about)
	var ghost := Race.ghost(progress.data, progress.date())
	var mine := Race.of(progress.data)
	if str(mine.date) == progress.date() and float(mine.best) > 0.0:
		col.add_child(Look.label(s.t("raceYourBest", {"s": "%.1f" % float(mine.best)}), 14, true, Look.PARROT_DARK))
	if bool(ghost.get("friend", false)):
		col.add_child(Look.label(s.t("raceFriendBest", {"name": str(ghost.name), "s": "%.1f" % float(ghost.time)}), 14, true, Look.MAGENTA))
	var go := Look.chunky(s.t("raceGo"), Look.SKY_DARK, Color.WHITE, 17, 4, 14)
	go.name = "RaceGo"
	go.pressed.connect(func():
		Race.next = true
		_go("res://scenes/rickshaw.tscn"))
	col.add_child(go)
	return panel


func _caption(text: String) -> Label:
	return Look.label(text, 15, true, Look.MUTED)


## Rafiq Chacha's morning paper, read out over his tea: a festival today
## or tomorrow, Ramadan, and what the month's weather means for the day.
func _news_card() -> Control:
	var panel := _card(Color("FFFDF6"), 20)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(Look.icon("book", 36, Look.OUTLINE))
	var title := Look.label(s.t("newsTitle"), 18, true)
	# Room to grow, or the label wraps a letter to a line.
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)
	col.add_child(top)
	for item in Calendar.new().news(progress.date(), b.n("rickshaw.rain_chance_per_day")):
		var values := {}
		for k in item.values:
			var v = item.values[k]
			values[k] = v.get(s.lang, v.get("en", "")) if typeof(v) == TYPE_DICTIONARY else v
		var line := Look.label("• " + s.t(item.key, values), 15, false, Color("4A423A"))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(line)
	return panel


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
	var after := progress.story_effect(who)
	if not after.is_empty():
		flow.add_child(_wrap_pill("book", s.t("after_" + str(after.note), {"n": int(after.left)}), Color("F3E5F5"), Look.MAGENTA))
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
	if who == "rickshaw" or who == "delivery" or who == "hawker" or who == "boat":
		col.add_child(_goal_row("coin", s.t("goalTarget"), s.t("takaN", {"n": progress.rickshaw_target() if who == "rickshaw" else int(b.n(who + ".daily_target"))}), Color.WHITE))
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
			return s.t("lastDay", {"money": int(h.earned), "trips": int(h.get("trips", 0)), "stars": h.get("stars", 0)})
		if who == "tea":
			return s.t("teaLastDay", {"money": int(h.earned), "served": int(h.get("served", 0))})
		if who == "fuchka":
			return s.t("fuchkaLastDay", {"money": int(h.earned), "served": int(h.get("served", 0))})
		if who == "delivery":
			return s.t("deliveryLastDay", {"money": int(h.earned), "orders": int(h.get("orders", 0))})
		if who == "hawker":
			return s.t("hawkerLastDay", {"money": int(h.earned), "sold": int(h.get("sold", 0))})
		if who == "boat":
			return s.t("boatLastDay", {"money": int(h.earned), "carried": int(h.get("carried", 0))})
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
		Look.true_colours(early)
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
			Look.true_colours(pick)
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
	for who in WHO + ["home"]:
		var on: bool = who == _shop_who
		var text := s.t("shopHome") if who == "home" else s.t(_name_key(who))
		if who != "home" and not open.has(who):
			text = s.t("lockedPlate", {"name": text, "level": int(b.n("unlocks." + _unlock_of(who)))})
		var tab := Look.chunky(text, _deep_of(who) if on else Color.WHITE, Color.WHITE if on else Look.OUTLINE, 15, 4 if on else 2, 14)
		tab.name = "ShopTab_" + who
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 54)
		tab.disabled = who != "home" and not open.has(who)
		tab.pressed.connect(_pick_shop.bind(who))
		tabs.add_child(tab)
	page.add_child(tabs)
	if _shop_who == "home":
		_home_shop(page)
		return
	var grid := _two_columns()
	page.add_child(grid)
	for id in Progress.UPGRADE_LISTS[_shop_who][1]:
		grid.add_child(_upgrade_card(id, _shop_who))
	# Looks: paint and decorations, bought once, worn or taken off.
	page.add_child(_caption(s.t("looksTitle")))
	var looks := _two_columns()
	page.add_child(looks)
	var slot := ""
	for l in Goods.looks(_shop_who):
		# Rahim Chacha's back painting and slogan: their own part, after a
		# heading that says what they are.
		if _shop_who == "rickshaw" and str(l.slot) in ["plate", "slogan"] and str(l.slot) != slot:
			if slot not in ["plate", "slogan"]:
				page.add_child(_caption(s.t("rickshawArtTitle")))
				page.add_child(Look.label(s.t("rickshawArtHelp"), 14, false, Look.MUTED))
			page.add_child(Look.label(s.t("lookSlot_" + str(l.slot)), 16, true, Look.OUTLINE))
			looks = _two_columns()
			page.add_child(looks)
		slot = str(l.slot)
		looks.add_child(_look_card(l, _shop_who))
	# Bought with stars (won in the leaderboards, challenges, the story).
	page.add_child(_caption(s.t("starShopTitle", {"n": int(progress.data.tara)})))
	var boosts := _two_columns()
	page.add_child(boosts)
	for x in Goods.boosts(_shop_who):
		boosts.add_child(_boost_card(x))


func _two_columns() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	return grid


## A card: a picture tile, a name, a line of help, then whatever goes at
## the bottom (a price button, a pill).
func _goods_card(icon: String, tile_fill: Color, title: String, help_text: String) -> Array:
	var panel := _card(Color.WHITE, 20)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", Look.card(tile_fill, 14, 0))
	tile.custom_minimum_size = Vector2(0, 86)
	var center := CenterContainer.new()
	center.add_child(Look.icon(icon, 54, Look.OUTLINE))
	tile.add_child(center)
	col.add_child(tile)
	col.add_child(Look.label(title, 18, true))
	var help := Look.label(help_text, 14, false, Color("4A423A"))
	help.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(help)
	return [panel, col]


## A price button (greyed with how much more is needed when short).
func _price_button(col: VBoxContainer, cost: int, then: Callable, button_name: String, stars := false) -> void:
	var short := cost - int(progress.data.tara if stars else progress.data.taka)
	var buy := Look.chunky(str(cost), Look.SKY if stars else Look.YELLOW, Color.WHITE if stars else Look.OUTLINE, 18, 5, 14)
	buy.name = button_name
	buy.icon = Look.icon_texture("star" if stars else "coin", 24)
	Look.true_colours(buy)
	buy.add_theme_constant_override("icon_max_width", 24)
	buy.custom_minimum_size = Vector2(0, 52)
	buy.disabled = short > 0
	buy.pressed.connect(then)
	col.add_child(buy)
	if short > 0:
		var more := Look.label(s.t("needMoreTara" if stars else "needMore", {"n": short}), 13, true, Look.MUTED)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(more)


## A boost for the next day, bought with stars (one waiting at a time).
func _boost_card(x: Dictionary) -> Control:
	var parts := _goods_card(str(x.get("icon", "star")), Color("E3EEF9"), s.t("boost_" + x.id), s.t("boostHelp_" + x.id))
	if progress.has_boost(str(x.who)):
		_owned_pill(parts[1], s.t("boostWaiting"))
	else:
		_price_button(parts[1], int(x.tara), _buy_boost.bind(str(x.id)), "Boost_" + str(x.id), true)
	return parts[0]


func _buy_boost(id: String) -> void:
	if progress.buy_boost(id):
		progress.save()
		_build()


func _owned_pill(col: VBoxContainer, text: String) -> void:
	var owned := Look.pill("check", text, Color("E6F4EC"), Look.OUTLINE, 16)
	var c := CenterContainer.new()
	c.add_child(owned)
	col.add_child(c)


## A look: its colour (or the slot's picture), and buy, wear or take off.
func _look_card(l: Dictionary, who: String) -> Control:
	var tile := _tint_of(who)
	for key in ["hood", "fill", "colour", "body", "box", "basket", "shirt"]:
		if l.has(key):
			tile = Color(str(l[key])).lerp(Color.WHITE, 0.35)
			break
	var parts := _goods_card(str(l.get("icon", "bag")), tile, s.t("look_" + l.id), s.t("lookHelp_" + l.slot))
	var col: VBoxContainer = parts[1]
	# A painting shows itself; a slogan as it is written on the rickshaw.
	if l.has("picture"):
		var pic := TextureRect.new()
		pic.texture = Look.icon_texture(str(l.picture), 200)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(0, 80)
		col.add_child(pic)
	elif str(l.slot) == "slogan":
		var words := Look.label(str(s.both("look_" + l.id).get("bn", "")), 20, true, Look.YELLOW)
		words.add_theme_color_override("font_outline_color", Color("7B1FA2"))
		words.add_theme_constant_override("outline_size", 8)
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(words)
	if not progress.owns_look(l.id) and bool(l.get("prize", false)):
		col.add_child(Look.label(s.t("lookPrize"), 13, true, Look.MAGENTA))
	elif not progress.owns_look(l.id):
		var stars := l.has("tara")
		_price_button(col, int(l.tara) if stars else int(l.price), _buy_look.bind(who, l.id), "Look_" + l.id, stars)
	else:
		var on: bool = progress.worn(who, l.slot).get("id", "") == l.id
		var wear := Look.chunky(s.t("lookTakeOff" if on else "lookWear"), Look.PARROT if not on else Color.WHITE, Color.WHITE if not on else Look.OUTLINE, 16, 4, 14)
		wear.name = "Wear_" + l.id
		wear.custom_minimum_size = Vector2(0, 50)
		wear.pressed.connect(_wear_look.bind(who, l.id))
		if on:
			_owned_pill(col, s.t("lookOn"))
		col.add_child(wear)
	return parts[0]


func _buy_look(who: String, id: String) -> void:
	if progress.buy_look(who, id):
		progress.save()
		_build()


func _wear_look(who: String, id: String) -> void:
	if progress.wear_look(who, id):
		progress.save()
		_build()


## Rahim Chacha's home: things for it, a phone of his own, the samity.
func _home_shop(page: VBoxContainer) -> void:
	page.add_child(Look.label(s.t("homeShopHelp", {"n": progress.family("rickshaw")}), 15, false, Look.MUTED))
	var grid := _two_columns()
	page.add_child(grid)
	for h in Goods.home_items():
		var parts := _goods_card(str(h.get("icon", "home")), Color("FFF1D6"), s.t("home_" + h.id), s.t("homeHelp_" + h.id))
		if progress.has_home(h.id):
			_owned_pill(parts[1], s.t("owned"))
			if not story.scene("home_" + h.id).is_empty():
				var again := Look.chunky(s.t("homeSceneAgain"), Color.WHITE, Look.OUTLINE, 14, 3, 14)
				again.name = "HomeScene_" + h.id
				again.pressed.connect(_play_home_scene.bind(h.id))
				parts[1].add_child(again)
		else:
			_price_button(parts[1], int(h.price), _buy_home.bind(h.id), "Home_" + h.id)
		grid.add_child(parts[0])
	var phone := Goods.phone()
	var pp := _goods_card(str(phone.get("icon", "voice")), Color("D6ECF7"), s.t("phoneName"), s.t("phoneHelp"))
	if progress.has_phone():
		_owned_pill(pp[1], s.t("owned"))
	else:
		_price_button(pp[1], int(phone.get("price", 0)), _buy_phone, "Phone")
	grid.add_child(pp[0])
	page.add_child(_samity_card())


func _buy_home(id: String) -> void:
	if progress.buy_home(id):
		progress.save()
		_build()
		_play_home_scene(id)


## A family's scene, once, when their feeling is high or low (and no
## story is open already).
func _family_scene() -> void:
	for c in get_children():
		if c is StoryPlayer and not c.is_queued_for_deletion():
			return
	var id := progress.family_scene_due()
	if id == "" or story.scene(id).is_empty():
		return
	progress.scene_shown(id)
	progress.save()
	var player := StoryPlayer.new()
	player.setup(story, story.scene(id), s)
	add_child(player)


## The family's little scene for a thing bought for the home.
func _play_home_scene(id: String) -> void:
	var c := story.scene("home_" + id)
	if c.is_empty():
		return
	var player := StoryPlayer.new()
	player.setup(story, c, s)
	player.finished.connect(func(_id, _effects): _build())
	add_child(player)


func _buy_phone() -> void:
	if progress.buy_phone():
		progress.save()
		_build()


## The samity: a little put in at the end of every day, paid back with a
## bonus after a round.
func _samity_card() -> Control:
	var rules := Goods.samity()
	var sm: Dictionary = progress.data.samity
	var daily := int(rules.get("daily", 30))
	var rounds := int(rules.get("rounds", 10))
	var panel := _card(Color.WHITE, 20)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(Look.icon(str(rules.get("icon", "ledger")), 40, Look.OUTLINE))
	top.add_child(Look.label(s.t("samityName"), 19, true))
	col.add_child(top)
	col.add_child(Look.label(s.t("samityHelp", {"daily": daily, "rounds": rounds, "bonus": int(rules.get("bonus", 0))}), 14, false, Color("4A423A")))
	var joined := bool(sm.get("in", false))
	if joined:
		col.add_child(Look.label(s.t("samityPaid", {"n": int(sm.get("paid", 0)), "all": daily * rounds}), 15, true))
		col.add_child(Look.bar(int(sm.get("paid", 0)), daily * rounds, Look.PARROT, 16))
	var act := Look.chunky(s.t("samityLeave" if joined else "samityJoin"), Color.WHITE if joined else Look.PARROT, Look.OUTLINE if joined else Color.WHITE, 16, 4, 14)
	act.name = "Samity"
	act.custom_minimum_size = Vector2(0, 50)
	act.pressed.connect(_set_samity.bind(not joined))
	col.add_child(act)
	return panel


func _set_samity(join: bool) -> void:
	progress.set_samity(join)
	progress.save()
	_build()


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
		Look.true_colours(buy)
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
		var line := s.t("historyLine", {"day": int(h.day), "money": int(h.earned), "trips": int(h.get("trips", 0)), "stars": h.get("stars", 0)})
		if h.get("who", "") == "tea":
			line = s.t("teaHistoryLine", {"day": int(h.day), "money": int(h.earned), "served": int(h.get("served", 0))})
		elif h.get("who", "") == "fuchka":
			line = s.t("fuchkaHistoryLine", {"day": int(h.day), "money": int(h.earned), "served": int(h.get("served", 0))})
		elif h.get("who", "") == "delivery":
			line = s.t("deliveryHistoryLine", {"day": int(h.day), "money": int(h.earned), "orders": int(h.get("orders", 0))})
		elif h.get("who", "") == "hawker":
			line = s.t("hawkerHistoryLine", {"day": int(h.day), "money": int(h.earned), "sold": int(h.get("sold", 0))})
		elif h.get("who", "") == "boat":
			line = s.t("boatHistoryLine", {"day": int(h.day), "money": int(h.earned), "carried": int(h.get("carried", 0))})
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
		# The whole card opens their page.
		var open := Button.new()
		open.name = "Neighbour_" + str(p.id)
		open.flat = true
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			open.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		open.pressed.connect(_neighbour_page.bind(str(p.id)))
		panel.add_child(open)
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


# --- Friends (friends.gd) ------------------------------------------------------------


## On the mohalla page: friends at a glance, and the way in.
func _friends_card() -> Control:
	if not cloud.enabled():
		return null
	var f := Friends.of(progress.data)
	var panel := _card(Color("FFF4D6"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_icon_tile("people", Look.MAGENTA, Color.WHITE))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(Look.label(s.t("friendsTitle"), 18, true))
	var line := s.t("friendsStart")
	if str(f.code) != "":
		var rows := Friends.board(progress.data, cloud.uid, progress.date())
		var rank := 1
		for i in rows.size():
			if rows[i].me:
				rank = i + 1
		line = s.t("friendsSummary", {"n": f.list.size(), "rank": rank})
	if not _friends_news.is_empty():
		line = _friends_news[0]
	text.add_child(Look.label(line, 14, false, Look.MUTED))
	var go := Look.chunky(s.t("friendsOpen"), Look.YELLOW, Look.OUTLINE, 16, 4, 14)
	go.name = "FriendsOpen"
	go.autowrap_mode = TextServer.AUTOWRAP_OFF
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(show_page.bind("friends"))
	row.add_child(go)
	return panel


func _friends_page(page: VBoxContainer) -> void:
	var f := Friends.of(progress.data)
	var back := Look.chunky(s.t("friendsBack"), Color.WHITE, Look.OUTLINE, 15, 3, 14)
	back.name = "FriendsBack"
	back.autowrap_mode = TextServer.AUTOWRAP_OFF
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(show_page.bind("hub"))
	page.add_child(back)
	page.add_child(_page_title(s.t("friendsTitle")))
	if not cloud.enabled():
		page.add_child(Look.label(s.t("friendsOff"), 15, false, Look.MUTED))
		return
	_friends_note = Look.label("", 14, true, Look.VERMILION)
	_friends_note.visible = false
	for news in _friends_news:
		var news_card := _card(Look.YELLOW, 16)
		news_card.add_child(Look.label(str(news), 15, true))
		page.add_child(news_card)
	if str(f.code) == "":
		page.add_child(_friends_start())
		page.add_child(_friends_note)
		return
	page.add_child(_my_code_card(f))
	page.add_child(_friends_note)
	page.add_child(_add_friend_card())
	if not (f.mail as Array).is_empty() or int(f.tea) > 0:
		page.add_child(_mail_card(f))
	page.add_child(_caption(s.t("friendsWeek")))
	page.add_child(_board_card())
	page.add_child(_caption(s.t("relayTitle")))
	page.add_child(_relay_card())
	page.add_child(_caption(s.t("jointTitle")))
	page.add_child(_joint_card())
	page.add_child(Look.label(s.t("friendsSafety"), 13, false, Look.MUTED))


## The first time: choose a name, get a code.
func _friends_start() -> Control:
	var panel := _card(Color.WHITE, 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(Look.label(s.t("friendsHelp"), 15))
	var name_edit := LineEdit.new()
	name_edit.name = "FriendName"
	name_edit.placeholder_text = s.t("friendsNameHint")
	name_edit.max_length = Friends.NAME_LENGTH
	name_edit.custom_minimum_size = Vector2(0, 48)
	box.add_child(name_edit)
	var go := Look.chunky(s.t("friendsMakeCode"), Look.MAGENTA, Color.WHITE, 17, 5, 14)
	go.name = "FriendMakeCode"
	go.custom_minimum_size = Vector2(0, 54)
	go.pressed.connect(_make_code.bind(name_edit, go))
	box.add_child(go)
	return panel


func _my_code_card(f: Dictionary) -> Control:
	var panel := _card(Look.MAGENTA, 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(Look.label(s.t("friendsYourCode", {"name": str(f.name)}), 15, true, Color.WHITE))
	var code := Look.title(str(f.code), 44, Look.YELLOW, true)
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(code)
	box.add_child(Look.label(s.t("friendsShareHelp"), 13, false, Color.WHITE))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	var copy := Look.chunky(s.t("friendsCopy"), Look.YELLOW, Look.OUTLINE, 15, 4, 14)
	copy.name = "FriendCopy"
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.pressed.connect(_copy_code.bind(str(f.code)))
	grid.add_child(copy)
	var rename := Look.chunky(s.t("friendsRename"), Color.WHITE, Look.OUTLINE, 15, 4, 14)
	rename.name = "FriendRename"
	rename.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename.pressed.connect(_rename_form)
	grid.add_child(rename)
	box.add_child(grid)
	return panel


func _add_friend_card() -> Control:
	var panel := _card(Color.WHITE, 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(Look.label(s.t("friendsAdd"), 16, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var edit := LineEdit.new()
	edit.name = "FriendCode"
	edit.placeholder_text = s.t("friendsCodeHint")
	edit.max_length = 8
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 48)
	row.add_child(edit)
	var go := Look.chunky(s.t("friendsAddGo"), Look.PARROT, Color.WHITE, 16, 4, 14)
	go.name = "FriendAdd"
	go.autowrap_mode = TextServer.AUTOWRAP_OFF
	go.pressed.connect(_add_friend.bind(edit, go))
	row.add_child(go)
	box.add_child(row)
	return panel


## What friends sent lately; tea waiting for Rahim Chacha's next day.
func _mail_card(f: Dictionary) -> Control:
	var panel := _card(Color.WHITE, 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(Look.label(s.t("friendsMail"), 16, true))
	if int(f.tea) > 0:
		var cups := mini(int(f.tea), int(b.n("friends.tea_cap")))
		box.add_child(Look.label(s.t("friendsTeaWaiting", {"n": int(f.tea), "energy": int(cups * b.n("friends.tea_energy"))}), 14, true, Look.PARROT_DARK))
	for m in f.mail:
		var what := s.t("gift_" + str(m.kind)) if m.kind != "sticker" else "\"%s\"" % s.t("sticker_" + str(m.sticker))
		box.add_child(Look.label(s.t("friendsMailLine", {"name": str(m.name), "what": what}), 14))
	return panel


## This week's list, with gifts, stickers and the rest for each friend.
func _board_card() -> Control:
	var panel := _card(Color.WHITE, 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var rows := Friends.board(progress.data, cloud.uid, progress.date())
	if rows.size() == 1:
		box.add_child(Look.label(s.t("friendsNone"), 14, false, Look.MUTED))
	box.add_child(Look.label(s.t("friendsLeft", {"gifts": Friends.left_today(progress.data, b, "gift", progress.date()),
		"stickers": Friends.left_today(progress.data, b, "sticker", progress.date())}), 13, false, Look.MUTED))
	for i in rows.size():
		var r: Dictionary = rows[i]
		if i > 0:
			box.add_child(_dash())
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		var rank := Look.title(str(i + 1), 28, Look.MAGENTA if i == 0 else Look.MUTED, false)
		rank.custom_minimum_size = Vector2(28, 0)
		rank.autowrap_mode = TextServer.AUTOWRAP_OFF
		top.add_child(rank)
		var who := Look.label(s.t("friendsYou") if r.me else str(r.name), 17, true, Look.MAGENTA if r.me else Look.OUTLINE)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(who)
		var money := Look.label(s.t("takaN", {"n": int(r.taka)}), 16, true)
		money.autowrap_mode = TextServer.AUTOWRAP_OFF
		top.add_child(money)
		box.add_child(top)
		if r.me:
			continue
		var acts := GridContainer.new()
		acts.columns = 4
		acts.add_theme_constant_override("h_separation", 6)
		for kind in ["tea", "paan", "sticker", "more"]:
			var label := s.t("gift_" + kind) if kind != "sticker" and kind != "more" else s.t("friends_" + kind)
			var btn := Look.chunky(label, Look.YELLOW if kind == "tea" else Color.WHITE, Look.OUTLINE, 13, 3, 12)
			btn.name = "Friend_%s_%d" % [kind, i]
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 44)
			match kind:
				"sticker":
					btn.pressed.connect(_sticker_form.bind(str(r.uid), str(r.name)))
				"more":
					btn.pressed.connect(_friend_more.bind(str(r.uid), str(r.name)))
				_:
					btn.pressed.connect(_send.bind(str(r.uid), kind, ""))
			acts.add_child(btn)
		box.add_child(acts)
	box.add_child(Look.label(s.t("friendsPrizeHelp"), 13, false, Look.MUTED))
	return panel


## Today's relay: who played the morning stall, the noon rickshaw and the
## evening bus, and what each good leg gives the next.
func _relay_card() -> Control:
	var panel := _card(Color.WHITE, 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(Look.label(s.t("relayHelp"), 14))
	var theirs := Friends.relay(progress.data, progress.date())
	var f := Friends.of(progress.data)
	var mine: Dictionary = f.legs if f.legs_date == progress.date() else {}
	for leg in Friends.LEGS:
		box.add_child(_dash())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_icon_tile({"tea": "monir", "rickshaw": "rahim", "bus": "babu"}[leg], _colour_of(leg), Color.WHITE, 40))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		text.add_child(Look.label(s.t("relayLeg_" + leg), 15, true))
		var names := []
		if mine.has(leg):
			names.append(s.t("friendsYou"))
		if theirs.has(leg):
			names.append(s.t("relayWho", {"name": str(theirs[leg].name), "stars": snappedf(float(theirs[leg].stars), 0.1)}))
		var played := ", ".join(PackedStringArray(names)) if not names.is_empty() else s.t("relayNobody")
		text.add_child(Look.label(played, 14, false, Look.PARROT_DARK if not names.is_empty() else Look.MUTED))
		box.add_child(row)
	box.add_child(Look.label(s.t("relayReward", {"n": int(b.n("friends.relay_tara"))}), 13, false, Look.MUTED))
	return panel


## Everyone's gifts to their mohalla funds, together, for big things.
func _joint_card() -> Control:
	var panel := _card(Color.WHITE, 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(Look.label(s.t("jointHelp"), 14))
	box.add_child(Look.label(s.t("jointTotal", {"n": Friends.joint_total(progress.data)}), 16, true))
	for p in Friends.joint(progress.data, b):
		box.add_child(_dash())
		var top := HBoxContainer.new()
		var name_label := Look.label(s.t("joint_" + str(p.id)), 16, true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_label)
		var st := Look.label(s.t("projectIsDone") if p.done else s.t("takaN", {"n": int(p.cost)}), 14, true, Look.PARROT_DARK if p.done else Look.MUTED)
		st.autowrap_mode = TextServer.AUTOWRAP_OFF
		top.add_child(st)
		box.add_child(top)
		if not p.done:
			box.add_child(Look.bar(int(p.got), int(p.cost), Look.YELLOW, 14))
	return panel


func _say_friends(text: String, bad := true) -> void:
	if is_instance_valid(_friends_note):
		_friends_note.add_theme_color_override("font_color", Look.VERMILION if bad else Look.PARROT_DARK)
		_friends_note.text = text
		_friends_note.visible = text != ""


func _friends_err(e: String) -> String:
	for k in ["friendsErr_" + e, "cloudErr_" + e]:
		if s.has(k):
			return s.t(k)
	return s.t("cloudErrOther", {"e": e})


func _make_code(name_edit: LineEdit, go: Button) -> void:
	var chosen := Friends.clean_name(name_edit.text)
	if chosen == "":
		_say_friends(s.t("friendsNeedName"))
		return
	go.disabled = true
	_say_friends(s.t("cloudWorking"), false)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var e := "ALREADY_EXISTS"
	var code := ""
	for i in 5:
		code = Friends.make_code(rng)
		e = await cloud.claim_code(code)
		if e != "ALREADY_EXISTS":
			break
	if not is_instance_valid(go):
		return
	go.disabled = false
	if e != "":
		_say_friends(_friends_err(e))
		return
	var f := Friends.of(progress.data)
	f.name = chosen
	f.code = code
	progress.save()
	await cloud.publish_card(Leaderboard.card(progress.data, progress.date()))
	_build()


func _rename_form() -> void:
	var rows := []
	var edit := LineEdit.new()
	edit.name = "FriendNewName"
	edit.text = str(Friends.of(progress.data).name)
	edit.max_length = Friends.NAME_LENGTH
	edit.custom_minimum_size = Vector2(0, 48)
	rows.append(edit)
	var go := Look.chunky(s.t("friendsRenameGo"), Look.MAGENTA, Color.WHITE, 16, 5, 14)
	go.pressed.connect(_rename_go.bind(edit))
	rows.append(go)
	_overlay(s.t("friendsRename"), rows)


func _rename_go(edit: LineEdit) -> void:
	var chosen := Friends.clean_name(edit.text)
	if chosen == "":
		return
	Friends.of(progress.data).name = chosen
	progress.save()
	cloud.publish_card(Leaderboard.card(progress.data, progress.date()))
	_build()


func _copy_code(code: String) -> void:
	DisplayServer.clipboard_set(code)
	_say_friends(s.t("friendsCopied"), false)


func _add_friend(edit: LineEdit, go: Button) -> void:
	var code := Friends.clean_code(edit.text)
	if not Friends.valid_code(code):
		_say_friends(s.t("friendsBadCode"))
		return
	go.disabled = true
	_say_friends(s.t("cloudWorking"), false)
	var uid := await cloud.find_code(code)
	if not is_instance_valid(go):
		return
	go.disabled = false
	if uid == "":
		_say_friends(s.t("friendsNoCode"))
		return
	var got := await cloud.cards([uid])
	var card: Dictionary = got.get(uid, {})
	var why := Friends.add(progress.data, b, uid, code, str(card.get("name", code)), cloud.uid)
	if why != "":
		_say_friends(s.t("friendsAdd_" + why))
		return
	Friends.take_cards(progress.data, got)
	progress.save()
	_friends_news = [s.t("friendsAdded", {"name": Friends.clean_name(str(card.get("name", code)))})]
	_build()


## Sends a gift or a sticker, within today's limits.
func _send(uid: String, kind: String, sticker: String) -> void:
	var item := Friends.send(progress.data, b, cloud.uid, kind, sticker, progress.date())
	if item.is_empty():
		_say_friends(s.t("friendsLimit"))
		return
	_say_friends(s.t("cloudWorking"), false)
	var e := await cloud.send_item(uid, item)
	if e != "":
		Friends.unsend(progress.data, kind, progress.date())
		_say_friends(_friends_err(e))
		return
	progress.save()
	_friends_news = [s.t("friendsSent", {"what": s.t("gift_" + kind) if kind != "sticker" else "\"%s\"" % s.t("sticker_" + sticker)})]
	_build()


func _sticker_form(uid: String, friend_name: String) -> void:
	var rows := []
	rows.append(Look.label(s.t("stickerHelp", {"name": friend_name}), 15))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var tones := [Look.MAGENTA, Look.PARROT, Look.SKY_DARK, Look.VERMILION, Look.YELLOW, Look.PARROT_DARK]
	for i in Friends.STICKERS.size():
		var id: String = Friends.STICKERS[i]
		var fill: Color = tones[i % tones.size()]
		var btn := Look.chunky(s.t("sticker_" + id), fill, Look.OUTLINE if fill == Look.YELLOW else Color.WHITE, 17, 5, 18)
		btn.name = "Sticker_" + id
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 70)
		btn.pressed.connect(_send.bind(uid, "sticker", id))
		grid.add_child(btn)
	rows.append(grid)
	_overlay(s.t("friends_sticker"), rows)


## Removing a friend, or blocking them.
func _friend_more(uid: String, friend_name: String) -> void:
	var rows := []
	rows.append(Look.label(s.t("friendsMoreHelp", {"name": friend_name}), 15))
	var remove := Look.chunky(s.t("friendsRemove"), Color.WHITE, Look.OUTLINE, 16, 4, 14)
	remove.name = "FriendRemove"
	remove.pressed.connect(_friend_drop.bind(uid, false))
	rows.append(remove)
	var block := Look.chunky(s.t("friendsBlock"), Look.VERMILION, Color.WHITE, 16, 4, 14)
	block.name = "FriendBlock"
	block.pressed.connect(_friend_drop.bind(uid, true))
	rows.append(block)
	rows.append(Look.label(s.t("friendsBlockHelp"), 13, false, Look.MUTED))
	_overlay(friend_name, rows)


func _friend_drop(uid: String, and_block: bool) -> void:
	if and_block:
		Friends.block(progress.data, uid)
	else:
		Friends.remove(progress.data, uid)
	progress.save()
	_build()


## Brings friends up to date: my card out; their cards, gifts and
## stickers in; the week's prize, joint projects. Rebuilds if anything
## changed, or the friends page is open.
func _refresh_friends() -> void:
	var f := Friends.of(progress.data)
	if _friends_busy or not cloud.enabled():
		return
	_friends_busy = true
	await cloud.publish_card(Leaderboard.card(progress.data, progress.date()))
	var news := []
	if str(f.code) != "":
		var uids := []
		for p in f.list:
			uids.append(p.uid)
		var got := await cloud.cards(uids)
		Friends.take_cards(progress.data, got)
		# Customers friends' rickshaws brought to my stall.
		for v in Friends.claim_visits(progress.data, b, cloud.uid):
			news.append(s.t("shopVisits", {"name": v.name, "n": v.n, "taka": v.taka}))
		var items := await cloud.take_inbox()
		if Friends.receive(progress.data, b, items) > 0:
			news.append(s.t("friendsGotMail", {"n": items.size()}))
		var won := Friends.claim_week(progress.data, b, progress.date())
		if won != "":
			news.append(s.t("friendsWon_" + won, {"n": int(b.n("friends.week_tara"))}))
		for id in Friends.claim_joint(progress.data, b):
			news.append(s.t("jointDone", {"name": s.t("joint_" + id), "n": int(b.n("friends.joint_tara"))}))
	# The leaderboards just over: stars for a place in the top three.
	var board_news := []
	for check in Leaderboard.to_check(progress.data, progress.date()):
		var top3 := await cloud.top(str(check.field), 3)
		if top3.is_empty():
			continue
		var rank := 0
		for i in top3.size():
			if top3[i].uid == cloud.uid:
				rank = i + 1
		var stars := Leaderboard.settle(progress.data, b, check, rank)
		if stars > 0:
			board_news.append(s.t("lbWon", {"rank": rank, "period": s.t("lbPast_" + str(check.period)), "who": s.t("lbWho_" + str(check.who)), "n": stars}))
	# Last week's area league: who won (once a week).
	var last := Friends.last_week(progress.date())
	if not (League.of(progress.data).claimed as Array).has(last):
		var sides := {}
		for a in League.AREAS:
			var st := await cloud.stats_of(League.field(a, last))
			if st.is_empty():
				sides = {}
				break
			sides[a] = st
		if not sides.is_empty():
			var won := League.winner(b, sides)
			var stars := League.settle(progress.data, b, progress.date(), won)
			if stars > 0:
				board_news.append(s.t("leagueWon", {"area": s.t("area_" + won), "n": stars}))
			elif won != "":
				board_news.append(s.t("leagueResult", {"area": s.t("area_" + won)}))
	progress.save()
	_friends_busy = false
	if not news.is_empty():
		_friends_news = news
	if not board_news.is_empty():
		_board_news = board_news
	if not news.is_empty() or not board_news.is_empty() or _page == "friends":
		_build()


# --- Leaderboards (leaderboard.gd) ---------------------------------------------------


# --- Playing together on one phone (together.gd) ----------------------------------------


## On the mohalla page: the stories to play together, and the way in.
func _together_card() -> Control:
	var panel := _card(Color("FDEFE3"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_icon_tile("book", Look.VERMILION, Color.WHITE))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(Look.label(s.t("tgTitle"), 18, true))
	var open := progress.open_characters().has("bus")
	var line := Look.label(s.t("tgCardLine") if open else s.t("tgLocked"), 14, false, Look.MUTED)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(line)
	var go := Look.chunky(s.t("friendsOpen"), Look.YELLOW, Look.OUTLINE, 16, 4, 14)
	go.name = "TogetherOpen"
	go.autowrap_mode = TextServer.AUTOWRAP_OFF
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(show_page.bind("together"))
	row.add_child(go)
	return panel


## On the mohalla page: playing at the same time on friends' phones.
func _online_card() -> Control:
	var panel := _card(Color("E6F0FA"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_icon_tile("people", Look.SKY_DARK, Color.WHITE))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(Look.label(s.t("onTitle"), 18, true))
	var line := Look.label(s.t("onCardLine"), 14, false, Look.MUTED)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(line)
	var go := Look.chunky(s.t("friendsOpen"), Look.YELLOW, Look.OUTLINE, 16, 4, 14)
	go.name = "OnlineOpen"
	go.autowrap_mode = TextServer.AUTOWRAP_OFF
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(_go.bind("res://scenes/online.tscn"))
	row.add_child(go)
	return panel


func _together_page(page: VBoxContainer) -> void:
	var back := Look.chunky(s.t("friendsBack"), Color.WHITE, Look.OUTLINE, 15, 3, 14)
	back.name = "TogetherBack"
	back.autowrap_mode = TextServer.AUTOWRAP_OFF
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(show_page.bind("hub"))
	page.add_child(back)
	page.add_child(_page_title(s.t("tgTitle")))
	var help := Look.label(s.t("tgHelp"), 14, false, Look.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(help)
	var t := Together.new()
	var chars := progress.open_characters()
	var best: Dictionary = Together.of(progress.data).best
	var tara: Array = b.at("together.tara")
	for st in t.stories:
		var panel := _card(Color.WHITE, 18)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		panel.add_child(col)
		col.add_child(Look.label(str(st.title.get(s.lang, st.title.en)), 19, true, Look.MAGENTA))
		var about := Look.label(str(st.about.get(s.lang, st.about.en)), 14)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(about)
		var open := t.is_open(progress.data, chars, str(st.id))
		if best.has(st.id):
			col.add_child(Look.label(s.t("tgBest", {"ending": s.t("tgEndName_%d" % int(best[st.id]))}), 14, true, Look.PARROT_DARK))
		else:
			col.add_child(Look.label(s.t("tgPrize", {"n": int(tara.back())}), 14, true, Look.PARROT_DARK))
		if open:
			var go := Look.chunky(s.t("tgPlay"), Look.YELLOW, Look.OUTLINE, 17, 4, 14)
			go.name = "TogetherPlay_" + str(st.id)
			go.pressed.connect(func():
				Together.next = str(st.id)
				_go("res://scenes/together.tscn"))
			col.add_child(go)
		else:
			var why := s.t("tgLocked") if not chars.has("bus") else s.t("tgAfter", {"name": str(t.story(str(st.after)).title.get(s.lang, ""))})
			col.add_child(Look.label(why, 14, true, Look.MUTED))
		page.add_child(panel)


## On the mohalla page: the leaderboards, and the way in.
## The weekly tournament: this week's rank and points, how far to the
## next rank, the days left and the prize; last week's prize when it was
## just paid; and the area league, a tap away.
func _ranked_card() -> Control:
	var panel := _card(Color("2B1B4D"), 20)
	panel.name = "RankedCard"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var points := Ranked.points(progress.data, progress.date())
	var i := Ranked.rank_of(b, points)
	var rank := s.t("rank_" + Ranked.rank_id(b, i))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_icon_tile("star", Look.YELLOW, Look.OUTLINE))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(Look.label(s.t("rankedTitle"), 18, true, Look.YELLOW))
	titles.add_child(Look.label(s.t("rankedNow", {"rank": rank, "n": points}), 15, true, Color.WHITE))
	top.add_child(titles)
	col.add_child(top)
	var left := Ranked.to_next(b, points)
	if left > 0:
		var next_at := points + left
		var from := int(Ranked.ranks(b)[i].points)
		col.add_child(Look.bar(points - from, next_at - from, Look.YELLOW, 14))
		col.add_child(Look.label(s.t("rankedNext", {"rank": s.t("rank_" + Ranked.rank_id(b, i + 1)), "n": left}), 14, false, Color("E9DDFB")))
	else:
		col.add_child(Look.label(s.t("rankedTop"), 14, true, Look.YELLOW))
	var prize := int(Ranked.ranks(b)[i].tara)
	var when := s.t("rankedDays", {"n": Ranked.days_left(progress.date())})
	if prize > 0:
		when += " · " + s.t("rankedPrize", {"n": prize})
	var when_label := Look.label(when, 13, false, Color("C9B8EE"))
	when_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(when_label)
	if not _rank_paid.is_empty():
		var paid := Look.label(s.t("rankedPaid", {"rank": s.t("rank_" + Ranked.rank_id(b, int(_rank_paid.rank))), "n": int(_rank_paid.tara)}), 15, true, Look.PARROT)
		paid.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(paid)
	var how := Look.label(s.t("rankedHow"), 12, false, Color("C9B8EE"))
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(how)
	if cloud.enabled():
		var league := Look.chunky(s.t("rankedLeague"), Look.MAGENTA, Color.WHITE, 15, 4, 14)
		league.name = "RankedLeague"
		league.pressed.connect(show_page.bind("board"))
		col.add_child(league)
	return panel


func _leader_card() -> Control:
	if not cloud.enabled():
		return null
	var panel := _card(Color("E8F1FB"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_icon_tile("star", Look.SKY_DARK, Color.WHITE))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(Look.label(s.t("lbTitle"), 18, true))
	var line: String = _board_news[0] if not _board_news.is_empty() else s.t("lbCardLine")
	text.add_child(Look.label(line, 14, not _board_news.is_empty(), Look.PARROT_DARK if not _board_news.is_empty() else Look.MUTED))
	var go := Look.chunky(s.t("friendsOpen"), Look.YELLOW, Look.OUTLINE, 16, 4, 14)
	go.name = "BoardOpen"
	go.autowrap_mode = TextServer.AUTOWRAP_OFF
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(show_page.bind("board"))
	row.add_child(go)
	return panel


func _board_page(page: VBoxContainer) -> void:
	var back := Look.chunky(s.t("friendsBack"), Color.WHITE, Look.OUTLINE, 15, 3, 14)
	back.name = "BoardBack"
	back.autowrap_mode = TextServer.AUTOWRAP_OFF
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(show_page.bind("hub"))
	page.add_child(back)
	page.add_child(_page_title(s.t("lbTitle")))
	if not cloud.enabled():
		page.add_child(Look.label(s.t("friendsOff"), 15, false, Look.MUTED))
		return
	for news in _board_news:
		var news_card := _card(Look.YELLOW, 16)
		news_card.add_child(Look.label(str(news), 15, true))
		page.add_child(news_card)
	page.add_child(_league_card())
	# The name shown in the lists.
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var my_name := str(Friends.of(progress.data).name)
	var who_am_i := Look.label(s.t("lbYourName", {"name": my_name}) if my_name != "" else s.t("lbNameHint"), 14, true, Look.OUTLINE if my_name != "" else Look.MAGENTA)
	who_am_i.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who_am_i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(who_am_i)
	var rename := Look.chunky(s.t("friendsRename") if my_name != "" else s.t("lbSetName"), Color.WHITE, Look.OUTLINE, 14, 3, 14)
	rename.name = "BoardName"
	rename.autowrap_mode = TextServer.AUTOWRAP_OFF
	rename.pressed.connect(_rename_form)
	name_row.add_child(rename)
	page.add_child(name_row)
	page.add_child(_board_chips(Leaderboard.PERIODS, _lb_period, "lbPeriod_", "BoardPeriod_", true))
	page.add_child(_board_chips(Leaderboard.WHO, _lb_who, "lbWho_", "BoardWho_", false))
	if _lb_period == "ever":
		page.add_child(Look.label(s.t("lbNoPrize"), 13, false, Look.MUTED))
	else:
		page.add_child(Look.label(s.t("lbPrizes", {"a": Leaderboard.prize(b, _lb_period, 1), "b": Leaderboard.prize(b, _lb_period, 2), "c": Leaderboard.prize(b, _lb_period, 3)}), 13, true, Look.PARROT_DARK))
	var panel := _card(Color.WHITE, 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	if _lb_state != "ok":
		box.add_child(Look.label(s.t("lbLoading") if _lb_state == "loading" else s.t("lbEmpty"), 15, false, Look.MUTED))
	for i in _lb_rows.size():
		var r: Dictionary = _lb_rows[i]
		var me: bool = r.uid == cloud.uid
		if i > 0:
			box.add_child(_dash())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var rank := Look.title(str(i + 1), 26, [Look.YELLOW, Look.MUTED, Look.VERMILION][i] if i < 3 else Look.OUTLINE, false)
		rank.custom_minimum_size = Vector2(36, 0)
		rank.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(rank)
		var who := Look.label((s.t("friendsYou") + " · " if me else "") + Leaderboard.shown_name(str(r.name), str(r.uid), s.t("lbAnon")), 16, true, Look.MAGENTA if me else Look.OUTLINE)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(who)
		var money := Look.label(s.t("takaN", {"n": int(r.value)}), 15, true)
		money.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(money)
		box.add_child(row)
	page.add_child(panel)
	var mine := Leaderboard.mine(progress.data, _lb_period, _lb_who, progress.date())
	var you := s.t("lbYouNone")
	if mine > 0:
		you = s.t("lbYou", {"rank": _lb_rank, "n": mine}) if _lb_rank > 0 else s.t("lbYouNoRank", {"n": mine})
	page.add_child(Look.label(you, 15, true, Look.MAGENTA))
	page.add_child(Look.label(s.t("lbHelp"), 13, false, Look.MUTED))


## The area league this week: each side's average, my trips, last
## week's winner.
func _league_card() -> Control:
	var panel := _card(Color("FFF1F6"), 18)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(Look.label(s.t("leagueTitle"), 17, true, Look.MAGENTA))
	if _league_state != "ok":
		box.add_child(Look.label(s.t("leagueLoading"), 14, false, Look.MUTED))
	else:
		for a in League.AREAS:
			var st: Dictionary = _league_now.get(a, {})
			var name := s.t("area_" + a)
			if int(st.get("count", 0)) > 0:
				box.add_child(Look.label(s.t("leagueSide", {"area": name, "avg": "%.1f" % League.average(st), "n": int(st.count)}), 15, true))
			else:
				box.add_child(Look.label(s.t("leagueSideNone", {"area": name}), 15, false, Look.MUTED))
	var area := progress.rickshaw_area()
	var mine := League.mine(progress.data, area, progress.date())
	box.add_child(Look.label(s.t("leagueMine", {"area": s.t("area_" + area), "n": mine}) if mine > 0 else s.t("leagueMineNone"), 14, true, Look.PARROT_DARK))
	var w: Dictionary = League.of(progress.data).winner
	if str(w.get("week", "")) == Friends.last_week(progress.date()):
		box.add_child(Look.label(s.t("leagueLast", {"area": s.t("area_" + str(w.area))}), 14, false, Look.OUTLINE))
	var help := Look.label(s.t("leagueHelp", {"n": int(b.n("league.win_tara"))}), 13, false, Look.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	return panel


## This week's league, fetched once per visit to the page.
func _load_league() -> void:
	if _league_state != "" or not cloud.enabled():
		return
	_league_state = "loading"
	var week := Friends.week_of(progress.date())
	var now := {}
	for a in League.AREAS:
		now[a] = await cloud.stats_of(League.field(a, week))
	_league_now = now
	_league_state = "ok"
	if _page == "board":
		_build()


## A row of choices for the lists (periods, or characters).
func _board_chips(ids: Array, picked: String, key: String, prefix: String, is_period: bool) -> Control:
	var grid := GridContainer.new()
	# Five characters do not fit in a row: three and two.
	grid.columns = ids.size() if ids.size() <= 4 else 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for id in ids:
		var on: bool = id == picked
		var chip := Look.chunky(s.t(key + str(id)), Look.SKY_DARK if on else Color.WHITE, Color.WHITE if on else Look.OUTLINE, 13, 3, 12)
		chip.name = prefix + str(id)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(0, 44)
		chip.pressed.connect(_pick_board.bind(str(id), is_period))
		grid.add_child(chip)
	return grid


func _pick_board(id: String, is_period: bool) -> void:
	if is_period:
		_lb_period = id
	else:
		_lb_who = id
	_load_board()


## Fetches the list showing (my card goes out first, so I am in it).
func _load_board() -> void:
	if not cloud.enabled():
		return
	var field := Leaderboard.field(_lb_period, _lb_who, progress.date())
	_lb_state = "loading"
	_lb_rows = []
	_lb_rank = 0
	_build()
	await cloud.publish_card(Leaderboard.card(progress.data, progress.date()))
	_load_league()
	var rows := await cloud.top(field, int(b.n("leaderboard.top")))
	var mine := Leaderboard.mine(progress.data, _lb_period, _lb_who, progress.date())
	var rank := await cloud.rank_of(field, mine)
	# Another list asked for meanwhile: this one is stale.
	if field != Leaderboard.field(_lb_period, _lb_who, progress.date()):
		return
	_lb_rows = rows
	_lb_rank = rank
	_lb_state = "ok" if not rows.is_empty() else "empty"
	if _page == "board":
		_build()


## A neighbour's page in the notebook: who they are, how they feel about
## you, how much of their story has opened, and what happened lately.
func _neighbour_page(id: String) -> void:
	var p: Dictionary = {}
	for x in neighbours.people:
		if x.id == id:
			p = x
	if p.is_empty():
		return
	var rows := []
	rows.append(Look.label(p.role[s.lang], 16, true, Look.MUTED))
	var met: bool = progress.data.npcs.has(id)
	var rel := progress.relation(id)
	var feel := s.t("notMet") if not met else s.t("neighbourFeel", {"n": ("+" if rel > 0 else "") + str(rel)})
	rows.append(Look.label(feel, 16, true, Look.PARROT_DARK if met and rel > 0 else (Color("B3261E") if met and rel < 0 else Look.OUTLINE)))
	rows.append(Look.label(s.t("neighbourHelp"), 14, false, Look.MUTED))
	# Their story: chapters they appear in.
	var theirs := []
	for c in story.chapters:
		var in_it := false
		for panel in c.panels:
			for line in panel.lines:
				if line.by == id:
					in_it = true
		if in_it:
			theirs.append(c)
	if not theirs.is_empty():
		var read := theirs.filter(func(c): return progress.seen(c.id))
		rows.append(_caption(s.t("neighbourStory", {"n": read.size(), "all": theirs.size()})))
		for c in theirs:
			var seen_it := progress.seen(c.id)
			var line_text: String = s.t(_name_key(c.who)) + " · " + (str(c.title[s.lang]) if seen_it else s.t("chapterLocked", {"n": int(c.n)}))
			rows.append(Look.label("• " + line_text, 15, seen_it, Look.OUTLINE if seen_it else Look.MUTED))
	var lately := (progress.data.log as Array).filter(func(e): return e.id == id)
	if not lately.is_empty():
		rows.append(_caption(s.t("lately")))
		for e in lately.slice(0, 5):
			var change := int(e.delta)
			rows.append(Look.label(s.t("logLine", {"name": p[s.lang], "what": s.t("log_" + str(e.what)), "n": ("+" if change > 0 else "") + str(change)}), 14))
	_overlay(p[s.lang], rows)


# --- Reading aloud what is held -------------------------------------------------


## With reading aloud on, a finger held still on a card or a button for a
## moment reads its words out (and the button is not pressed by it).
func _input(event: InputEvent) -> void:
	if not _read_aloud:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_hold_at = Time.get_ticks_msec() / 1000.0
			_hold_pos = event.position
		else:
			if _hold_at == -2.0:
				# This hold was read out: the lift does not press anything.
				get_viewport().set_input_as_handled()
			_hold_at = -1.0
	elif event is InputEventMouseMotion and _hold_at >= 0.0 and event.position.distance_to(_hold_pos) > 24.0:
		_hold_at = -1.0


func _process(_dt: float) -> void:
	if _hold_at >= 0.0 and Time.get_ticks_msec() / 1000.0 - _hold_at > 0.6:
		_hold_at = -2.0
		ReadAloud.say(_words_at(_hold_pos), s.lang)


## The words of the smallest card or button under a point.
func _words_at(pos: Vector2) -> String:
	var best: Control = null
	var best_area := INF
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var ctl := n as Control
		if not (ctl is PanelContainer or ctl is Button or ctl is Label) or not ctl.get_global_rect().has_point(pos):
			continue
		var area := ctl.size.x * ctl.size.y
		if area < best_area and _words_in(ctl) != "":
			best = ctl
			best_area = area
	return _words_in(best) if best != null else ""


func _words_in(ctl: Control) -> String:
	var words := []
	if ctl is Label:
		return (ctl as Label).text.strip_edges()
	if ctl is Button and (ctl as Button).text != "":
		words.append((ctl as Button).text)
	for l in ctl.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text.strip_edges() != "":
			words.append((l as Label).text)
	for btn in ctl.find_children("*", "Button", true, false):
		if (btn as Button).is_visible_in_tree() and (btn as Button).text != "":
			words.append((btn as Button).text)
	return "। ".join(PackedStringArray(words))


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
	return {"rickshaw": "rickshawName", "tea": "teaName", "bus": "busName", "fuchka": "fuchkaName", "delivery": "deliveryName", "hawker": "hawkerName", "boat": "boatName"}[who]


func _role_key(who: String) -> String:
	return {"rickshaw": "rickshawRole", "tea": "teaRole", "bus": "busRole", "fuchka": "fuchkaRole", "delivery": "deliveryRole", "hawker": "hawkerRole", "boat": "boatRole"}[who]


## Each character's colour.
func _colour_of(who: String) -> Color:
	return {"rickshaw": Look.MAGENTA, "tea": Look.PARROT, "bus": Look.SKY, "fuchka": Look.VERMILION, "delivery": Color("F26B1D"), "hawker": Color("A0722F"), "boat": Color("1F6E8C")}[who]


## Their colour dark enough for white words on it.
func _deep_of(who: String) -> Color:
	return {"rickshaw": Look.MAGENTA, "tea": Look.PARROT_DARK, "bus": Look.SKY_DARK, "fuchka": Color("B3261E"), "delivery": Color("B84A0E"), "hawker": Color("6E4A1E"), "boat": Color("134B60")}.get(who, Look.VERMILION)


## A pale wash of their colour, behind pictures.
func _tint_of(who: String) -> Color:
	return {"rickshaw": Color("FDE7F0"), "tea": Color("E6F4EC"), "bus": Color("D6ECF7"), "fuchka": Color("FDE2DC"), "delivery": Color("FEEBDD"), "hawker": Color("F4E8D4"), "boat": Color("DCEEF3")}.get(who, Color("FFF1D6"))


## What opens a character ("tea_stall" for the tea stall).
func _unlock_of(who: String) -> String:
	return {"rickshaw": "", "tea": "tea_stall", "bus": "bus", "fuchka": "fuchka", "delivery": "delivery", "hawker": "hawker", "boat": "boat"}[who]


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
	rows.append(_choice_row(s.t("easyDriving"), [s.t("musicOn"), s.t("musicOff")], 0 if Driving.easy() else 1, func(i): _set_easy(i == 0), "Easy_", ["on", "off"]))
	rows.append(Look.label(s.t("easyDrivingHelp"), 13, false, Look.MUTED))
	rows.append(_choice_row(s.t("readAloud"), [s.t("musicOn"), s.t("musicOff")], 0 if ReadAloud.wanted() else 1, func(i): _set_read_aloud(i == 0), "ReadAloud_", ["on", "off"]))
	rows.append(Look.label(s.t("readAloudHelp"), 13, false, Look.MUTED))
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


func _set_read_aloud(value: bool) -> void:
	ReadAloud.save_wanted(value)
	_read_aloud = value
	if value:
		ReadAloud.say(s.t("readAloudOn"), s.lang)
	_build()


func _set_easy(value: bool) -> void:
	Driving.save_easy(value)
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
		cloud.web_google_preload()
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
	var room := Look.safe_insets(get_viewport())
	panel.offset_top = 18 + room.x
	panel.offset_bottom = -(18 + room.y)
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
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
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
	# What the chapter changes in the next days (a choice's own first).
	var c := story.chapter(id)
	if not effects.has("after") and c.has("after"):
		effects["after"] = (c.after as Dictionary).duplicate()
	if effects.has("after"):
		effects.after["who"] = str(c.get("who", ""))
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
	get_tree().change_scene_to_file.call_deferred(scene)


# --- The Dhaka card album ------------------------------------------------------


## On the mohalla page: how much of the album is filled, and a way in.
func _album_card() -> Control:
	var panel := _card(Color("FFF6E0"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_icon_tile("book", Look.YELLOW, Look.OUTLINE))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(Look.label(s.t("cardsTitle"), 18, true))
	text.add_child(Look.label(s.t("cardsCount", {"n": (Cards.of(progress.data).owned as Array).size(), "all": Cards.count()}), 14, false, Look.MUTED))
	var go := Look.chunky(s.t("friendsOpen"), Look.YELLOW, Look.OUTLINE, 16, 4, 14)
	go.name = "CardsOpen"
	go.autowrap_mode = TextServer.AUTOWRAP_OFF
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(show_page.bind("cards"))
	row.add_child(go)
	return panel


## The album: each set with its cards, held ones in colour with their fact,
## the rest as a "?".
func _cards_page(page: VBoxContainer) -> void:
	var back := Look.chunky(s.t("friendsBack"), Color.WHITE, Look.OUTLINE, 15, 3, 14)
	back.name = "CardsBack"
	back.autowrap_mode = TextServer.AUTOWRAP_OFF
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(show_page.bind("hub"))
	page.add_child(back)
	page.add_child(_caption(s.t("cardsTitle")))
	var how := Look.label(s.t("cardsHow", {"n": int(b.n("cards.set_tara"))}), 14, false, Look.MUTED)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(how)
	for set_info in Cards.sets():
		var held := Cards.held_in(progress.data, str(set_info.id))
		var all := (set_info.cards as Array).size()
		page.add_child(Look.label("%s · %s" % [str(set_info.name.get(s.lang, set_info.name.en)), s.num("%d/%d" % [held, all])], 17, true, Color(str(set_info.colour))))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		page.add_child(grid)
		for c in set_info.cards:
			grid.add_child(_album_tile(c, set_info))


func _album_tile(c: Dictionary, set_info: Dictionary) -> Control:
	var have := Cards.owned(progress.data, str(c.id))
	var colour := Color(str(set_info.colour))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(colour if have else Color("E9E3D8"), 14, 3))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 150)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	var icon := Look.icon(str(set_info.icon) if have else "lock", 34, Color.WHITE if have else Look.MUTED)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var name := Look.label(str(c.name.get(s.lang, c.name.en)) if have else "?", 14, true, Color.WHITE if have else Look.MUTED)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name)
	if have:
		var fact := Look.label(str(c.fact.get(s.lang, c.fact.en)), 11, false, Color(1, 1, 1, 0.92))
		fact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(fact)
	return panel


## Eid: the family's salami, shown once on the mohalla page.
func _salami_card() -> Control:
	var panel := _card(Color("E8F7EE"), 20)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_icon_tile("coin", Look.PARROT, Color.WHITE))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(Look.label(s.t("salamiTitle"), 18, true, Look.PARROT_DARK))
	var line := Look.label(s.t("salamiLine", {"taka": int(_salami.taka), "tara": int(_salami.tara)}), 14, false)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(line)
	panel.ready.connect(func(): Juice.celebrate(self, "sparkle"))
	return panel


# --- The free season pass --------------------------------------------------------


## On the mohalla page: this month's pass, the tier reached, prizes waiting.
func _pass_card() -> Control:
	var panel := _card(Color("1C3E7B"), 20)
	panel.name = "SeasonCard"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var date := progress.date()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_icon_tile("star", Look.YELLOW, Look.OUTLINE))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(Look.label(s.t("seasonTitle"), 18, true, Look.YELLOW))
	titles.add_child(Look.label(s.t("seasonTier", {"n": Season.open_tiers(progress.data, date), "all": Season.tiers().size()}), 15, true, Color.WHITE))
	top.add_child(titles)
	var go := Look.chunky(s.t("friendsOpen"), Look.YELLOW, Look.OUTLINE, 16, 4, 14)
	go.name = "SeasonOpen"
	go.autowrap_mode = TextServer.AUTOWRAP_OFF
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(show_page.bind("season"))
	top.add_child(go)
	col.add_child(top)
	var into := Season.points(progress.data, date) % Season.per_tier()
	if Season.open_tiers(progress.data, date) < Season.tiers().size():
		col.add_child(Look.bar(into, Season.per_tier(), Look.YELLOW, 14))
	var waiting := Season.waiting(progress.data, date)
	if waiting > 0:
		col.add_child(Look.label(s.t("seasonWaiting", {"n": waiting}), 14, true, Look.PARROT))
	return panel


## The pass: every tier's prize, claimed, to claim, or still locked.
func _season_page(page: VBoxContainer) -> void:
	var back := Look.chunky(s.t("friendsBack"), Color.WHITE, Look.OUTLINE, 15, 3, 14)
	back.name = "SeasonBack"
	back.autowrap_mode = TextServer.AUTOWRAP_OFF
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(show_page.bind("hub"))
	page.add_child(back)
	page.add_child(_caption(s.t("seasonTitle")))
	var how := Look.label(s.t("seasonHow", {"n": Season.per_tier()}), 14, false, Look.MUTED)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(how)
	var date := progress.date()
	var open := Season.open_tiers(progress.data, date)
	for t in range(1, Season.tiers().size() + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var panel := _card(Color.WHITE if t <= open else Color("ECE6DA"), 14)
		panel.add_child(row)
		var num := Look.label(s.num(str(t)), 20, true, Look.SKY_DARK if t <= open else Look.MUTED)
		num.custom_minimum_size = Vector2(36, 0)
		row.add_child(num)
		var what := Look.label(_prize_text(Season.tiers()[t - 1]), 15, true, Look.OUTLINE if t <= open else Look.MUTED)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(what)
		if Season.claimed(progress.data, date, t):
			row.add_child(Look.icon("check", 28, Look.PARROT))
		elif t <= open:
			var take := Look.chunky(s.t("seasonClaim"), Look.PARROT, Color.WHITE, 15, 3, 12)
			take.name = "SeasonClaim_%d" % t
			take.autowrap_mode = TextServer.AUTOWRAP_OFF
			take.pressed.connect(_claim_tier.bind(t))
			row.add_child(take)
		else:
			row.add_child(Look.icon("lock", 24, Look.MUTED))
		page.add_child(panel)


func _prize_text(prize: Dictionary) -> String:
	var parts := PackedStringArray()
	if prize.has("look"):
		parts.append(s.t("look_" + str(prize.look[1])))
	if prize.has("frame"):
		parts.append(s.t("seasonFrame", {"name": s.t(str(prize.frame))}))
	if prize.has("card"):
		parts.append(s.t("seasonCard"))
	if prize.has("tara"):
		parts.append(s.t("seasonStars", {"n": int(prize.tara)}))
	return " + ".join(parts)


func _claim_tier(t: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var got := Season.claim(progress.data, b, progress.date(), t, rng)
	if got.is_empty():
		return
	progress.save()
	Juice.celebrate(self, "sparkle")
	_build()


# --- Stickers ----------------------------------------------------------------------


func _stickers_card() -> Control:
	var panel := _card(Color("F0F7FF"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_icon_tile("smile", Look.SKY_DARK, Color.WHITE))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(Look.label(s.t("stickersTitle"), 18, true))
	text.add_child(Look.label(s.t("stickersLine"), 14, false, Look.MUTED))
	var go := Look.chunky(s.t("friendsOpen"), Look.YELLOW, Look.OUTLINE, 16, 4, 14)
	go.name = "StickersOpen"
	go.autowrap_mode = TextServer.AUTOWRAP_OFF
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(show_page.bind("stickers"))
	row.add_child(go)
	return panel


## The stickers: tap one to send it (Messenger, WhatsApp, or save it).
func _stickers_page(page: VBoxContainer) -> void:
	var back := Look.chunky(s.t("friendsBack"), Color.WHITE, Look.OUTLINE, 15, 3, 14)
	back.name = "StickersBack"
	back.autowrap_mode = TextServer.AUTOWRAP_OFF
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(show_page.bind("hub"))
	page.add_child(back)
	page.add_child(_caption(s.t("stickersTitle")))
	var how := Look.label(s.t("stickersHow"), 14, false, Look.MUTED)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(how)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	page.add_child(grid)
	for st in Stickers.LIST:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var view := Stickers.view(str(st[0]), s.t(str(st[1])), Color(str(st[2])), 200.0)
		var holder := CenterContainer.new()
		holder.add_child(view)
		cell.add_child(holder)
		var send := Look.chunky(s.t("stickerSend"), Look.PARROT, Color.WHITE, 15, 3, 12)
		send.name = "Sticker_" + str(st[1])
		send.pressed.connect(_send_sticker.bind(st))
		cell.add_child(send)
		grid.add_child(cell)


func _send_sticker(st: Array) -> void:
	var img: Image = await Stickers.picture(self, str(st[0]), s.t(str(st[1])), Color(str(st[2])))
	if not Share.image(img, "sticker", s.t("stickerShareLine")):
		_open_whatsapp_text(s.t("stickerShareLine"))


func _open_whatsapp_text(text: String) -> void:
	OS.shell_open("https://wa.me/?text=" + text.uri_encode())
