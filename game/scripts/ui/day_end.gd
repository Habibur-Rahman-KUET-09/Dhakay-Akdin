## The end of a day, for all three characters: a banner, the day's stars,
## the money (with how the day went), where the money went (savings, the
## school fee, the mohalla fund), the XP towards the next level and what a
## new level opens, the day's extras (challenge, run of days, a record),
## a card to share the day (a picture of it drawn for the phone's share
## sheet, or a line for WhatsApp or Facebook), and two ways on: back to the
## mohalla, or straight into the next day.
extends Control

const Look = preload("res://scripts/ui/look.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const Progress = preload("res://scripts/rules/progress.gd")
const DayLines = preload("res://scripts/ui/day_lines.gd")
const Share = preload("res://scripts/ui/share.gd")
const Reel = preload("res://scripts/ui/reel.gd")
const ReadAloud = preload("res://scripts/ui/read_aloud.gd")

signal home_pressed
signal again_pressed

const NIGHT := Color("2B2238")
## Each character's face and colour, for the day's picture.
const FACES := {"rickshaw": ["rahim", "C2185B"], "tea": ["monir", "2E9E6B"], "bus": ["babu", "2D8BD6"],
	"fuchka": ["julekha", "E2432A"], "delivery": ["ratul", "F26B1D"], "hawker": ["kashem", "A0722F"], "boat": ["haripada", "1F6E8C"]}
const NAMES := {"rickshaw": "rickshawName", "tea": "teaName", "bus": "busName", "fuchka": "fuchkaName",
	"delivery": "deliveryName", "hawker": "hawkerName", "boat": "boatName"}
## The day's picture: 1080 by 1350 (4:5, as phones show photos), saved
## here for the share sheet.
const PHOTO_SIZE := Vector2i(1080, 1350)
const PHOTO_PATH := "user://share/day.png"

var s: Strings
var b: Balance
var progress: Progress
var got: Dictionary
## title, stars (0-5), sub (a line under the stars), money, lines (how the
## day went), extras (lines of the character's own, as the target met),
## good (whether the day reached its target), kept_label, share (the
## day in a line, to share with friends; none, no card).
var info: Dictionary
var _photo: Image
var _photo_view: TextureRect
var _photo_button: Button
var _reel_button: Button
var _reel: Node


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
	if str(info.get("share", "")) != "":
		page.add_child(_share_card())
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


## Where the game is for anyone to play, in a browser.
const GAME_URL := "https://pranerdhaka.web.app"


## The day in a rickshaw-art frame: its picture (drawn once the page is
## up), a button to send the picture, and the line for WhatsApp or
## Facebook.
func _share_card() -> Control:
	var frame := PanelContainer.new()
	var outer := Look.card(Look.MAGENTA, 22, 4)
	outer.content_margin_left = 8
	outer.content_margin_right = 8
	outer.content_margin_top = 8
	outer.content_margin_bottom = 8
	frame.add_theme_stylebox_override("panel", outer)
	var inner := PanelContainer.new()
	var st := Look.card(Look.YELLOW, 16, 3)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	inner.add_theme_stylebox_override("panel", st)
	frame.add_child(inner)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	inner.add_child(col)
	var title := Look.title(s.t("sharePhotoTitle"), 26, Look.MAGENTA, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_photo_view = TextureRect.new()
	_photo_view.name = "SharePhoto"
	_photo_view.custom_minimum_size = Vector2(0, 330)
	_photo_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_photo_view.visible = false
	col.add_child(_photo_view)
	_photo_button = Look.chunky(s.t("sharePhoto"), Look.MAGENTA, Color.WHITE, 18, 4, 14)
	_photo_button.name = "Share_photo"
	_photo_button.custom_minimum_size = Vector2(0, 56)
	_photo_button.visible = false
	_photo_button.pressed.connect(_share_photo)
	col.add_child(_photo_button)
	# A 12-second reel (video) for statuses and reels: on the Android app.
	if Share.can_video():
		_reel_button = Look.chunky(s.t("reelMake"), Look.SKY_DARK, Color.WHITE, 18, 4, 14)
		_reel_button.name = "Share_reel"
		_reel_button.custom_minimum_size = Vector2(0, 56)
		_reel_button.pressed.connect(_make_reel)
		col.add_child(_reel_button)
	var line := Look.label(str(info.share), 16, true)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	for way in ["whatsapp", "facebook"]:
		var go := Look.chunky(s.t("share_" + way), Color("25D366") if way == "whatsapp" else Color("1877F2"), Color.WHITE, 16, 4, 14)
		go.name = "Share_" + way
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.custom_minimum_size = Vector2(0, 52)
		go.pressed.connect(_share.bind(way))
		grid.add_child(go)
	col.add_child(grid)
	_draw_photo.call_deferred()
	return frame


# --- The day's picture ---------------------------------------------------------


## Whose day it was: the latest day in the save.
func _who() -> String:
	var h: Array = progress.data.get("history", [])
	return str(h[0].get("who", "rickshaw")) if not h.is_empty() else "rickshaw"


## Draws the picture off screen (a viewport of its own), keeps it as a
## file for the share sheet, and shows it on the card.
func _draw_photo() -> void:
	var view := SubViewport.new()
	view.size = PHOTO_SIZE
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	view.add_child(_photo_layout())
	add_child(view)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := view.get_texture().get_image() if is_inside_tree() else null
	view.queue_free()
	if img == null or img.is_empty():
		return
	_photo = img
	DirAccess.make_dir_recursive_absolute(PHOTO_PATH.get_base_dir())
	img.save_png(PHOTO_PATH)
	_photo_view.texture = ImageTexture.create_from_image(img)
	_photo_view.visible = true
	_photo_button.visible = true
	print("[day end] picture drawn")


## The picture: the character's face in their colour in a rickshaw-art
## frame, the day's money and stars, the day in a line, and where to play.
func _photo_layout() -> Control:
	var who := _who()
	var face: Array = FACES.get(who, FACES.rickshaw)
	var colour := Color(str(face[1]))
	var root := Control.new()
	root.size = Vector2(PHOTO_SIZE)
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.size = Vector2(PHOTO_SIZE)
	root.add_child(bg)
	var bunting := TextureRect.new()
	bunting.texture = Look.icon_texture("bunting", 1080)
	bunting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bunting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	bunting.position = Vector2(0, 0)
	bunting.size = Vector2(1080, 150)
	root.add_child(bunting)
	var frame := PanelContainer.new()
	var outer := Look.card(Look.MAGENTA, 48, 10)
	for side in ["left", "right", "top", "bottom"]:
		outer.set("content_margin_" + side, 22)
	frame.add_theme_stylebox_override("panel", outer)
	frame.position = Vector2(60, 140)
	frame.size = Vector2(960, 1050)
	root.add_child(frame)
	var inner := PanelContainer.new()
	var st := Look.card(Look.CREAM, 36, 8)
	for side in ["left", "right", "top", "bottom"]:
		st.set("content_margin_" + side, 36)
	inner.add_theme_stylebox_override("panel", st)
	frame.add_child(inner)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	inner.add_child(col)
	var title := Look.title(s.t("appTitle"), 80, Look.MAGENTA)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var disc_box := CenterContainer.new()
	col.add_child(disc_box)
	var disc := Panel.new()
	disc.custom_minimum_size = Vector2(250, 250)
	var ring := StyleBoxFlat.new()
	ring.bg_color = colour
	ring.set_corner_radius_all(125)
	ring.border_color = Look.OUTLINE
	ring.set_border_width_all(8)
	disc.add_theme_stylebox_override("panel", ring)
	disc_box.add_child(disc)
	var pic := TextureRect.new()
	pic.texture = Look.icon_texture(str(face[0]), 256)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.position = Vector2(20, 20)
	pic.size = Vector2(210, 210)
	disc.add_child(pic)
	var name_label := Look.title(s.t(str(NAMES.get(who, "rickshawName"))), 64, colour.darkened(0.25), false)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)
	var money := Look.title(s.t("sharePhotoMoney", {"n": int(info.get("money", 0))}), 88, Look.PARROT_DARK)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(money)
	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 10)
	var n := int(round(float(info.get("stars", 0.0))))
	for i in 5:
		var star := TextureRect.new()
		star.texture = Look.icon_texture("star" if i < n else "star_off", 96)
		star.custom_minimum_size = Vector2(84, 84)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stars_row.add_child(star)
	col.add_child(stars_row)
	var line := Look.label(str(info.get("share", "")), 36, true)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(820, 0)
	col.add_child(line)
	var day := Look.label(s.t("sharePhotoDay", {"day": int(progress.data.get("day", 0)), "level": progress.level()}), 34, true, Look.MUTED)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(day)
	var foot := PanelContainer.new()
	var band := StyleBoxFlat.new()
	band.bg_color = Look.MAGENTA
	foot.add_theme_stylebox_override("panel", band)
	foot.position = Vector2(0, 1230)
	foot.size = Vector2(1080, 120)
	var url := Look.label(s.t("sharePhotoFoot", {"url": GAME_URL.replace("https://", "")}), 44, true, Color.WHITE)
	url.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	url.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(url)
	root.add_child(foot)
	return root


## The picture to the phone's share sheet (Android, through the game's
## plugin; in a browser, the browser's own sharing or a download); the
## line for WhatsApp where neither can.
func _share_photo() -> void:
	var text := "%s\n%s %s" % [str(info.share), s.t("sharePlay"), GAME_URL]
	if _photo == null:
		_share("whatsapp")
		return
	if Engine.has_singleton("GoogleSignIn"):
		Engine.get_singleton("GoogleSignIn").shareImage(ProjectSettings.globalize_path(PHOTO_PATH), text)
		return
	if OS.has_feature("web"):
		var b64 := Marshalls.raw_to_base64(_photo.save_png_to_buffer())
		var js := ("(function(){try{var b=atob(%s),a=new Uint8Array(b.length);for(var i=0;i<b.length;i++)a[i]=b.charCodeAt(i);"
			+ "var f=new File([a],'pranerdhaka.png',{type:'image/png'});"
			+ "if(navigator.canShare&&navigator.canShare({files:[f]})){navigator.share({files:[f],text:%s});return true}"
			+ "var u=URL.createObjectURL(f),l=document.createElement('a');l.href=u;l.download='pranerdhaka.png';"
			+ "document.body.appendChild(l);l.click();l.remove();return true}catch(e){return false}})()") % [JSON.stringify(b64), JSON.stringify(text)]
		if bool(JavaScriptBridge.eval(js, true)):
			return
	_share("whatsapp")


## Opens WhatsApp (or Facebook) with the day's line and the game's link;
## in a browser that can, the phone's own share sheet.
func _share(way: String) -> void:
	var text := "%s\n%s %s" % [str(info.share), s.t("sharePlay"), GAME_URL]
	if OS.has_feature("web") and way == "whatsapp":
		var js := "navigator.share ? (navigator.share({text: %s}), true) : false" % JSON.stringify(text)
		if bool(JavaScriptBridge.eval(js, true)):
			return
	if way == "facebook":
		OS.shell_open("https://www.facebook.com/sharer/sharer.php?u=%s&quote=%s" % [GAME_URL.uri_encode(), str(info.share).uri_encode()])
	else:
		OS.shell_open("https://wa.me/?text=" + text.uri_encode())


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


# --- The day's reel --------------------------------------------------------------


func _make_reel() -> void:
	if _reel != null:
		return
	var who := _who()
	var face: Array = FACES.get(who, FACES.rickshaw)
	var lines := DayLines.lines(got, s)
	lines.append_array(info.get("lines", []))
	_reel = Reel.new()
	_reel.s = s
	_reel.info = {"face": str(face[0]), "colour": Color(str(face[1])), "name": s.t(NAMES.get(who, "rickshawName")),
		"money": int(info.get("money", 0)), "stars": float(info.get("stars", 0.0)), "lines": lines, "url": GAME_URL.replace("https://", "")}
	_reel.status.connect(func(text: String): _reel_button.text = text)
	_reel.finished.connect(_reel_done)
	_reel_button.disabled = true
	add_child(_reel)
	_reel.make()


func _reel_done(path: String) -> void:
	_reel.queue_free()
	_reel = null
	_reel_button.disabled = false
	_reel_button.text = s.t("reelMake")
	if path == "" or not Share.video(path, "%s\n%s %s" % [str(info.share), s.t("sharePlay"), GAME_URL]):
		_reel_button.text = s.t("reelFailed")
