## The player's "Dhakabashi card" to show off: name, level, days played,
## best run of days, cards held, the character played most (big), the
## school or university, painted like a rickshaw panel. A game card, not
## any real document.
extends RefCounted

const Look = preload("res://scripts/ui/look.gd")
const Cards = preload("res://scripts/rules/cards.gd")
const Friends = preload("res://scripts/rules/friends.gd")
const School = preload("res://scripts/rules/school.gd")
const Render = preload("res://scripts/ui/render.gd")

const SIZE := Vector2i(720, 1000)
const FACES := {"rickshaw": ["rahim", "C2185B"], "tea": ["monir", "2E9E6B"], "bus": ["babu", "2D8BD6"],
	"fuchka": ["julekha", "E2432A"], "delivery": ["ratul", "F26B1D"], "hawker": ["kashem", "A0722F"], "boat": ["haripada", "1F6E8C"]}
const NAMES := {"rickshaw": "rickshawName", "tea": "teaName", "bus": "busName", "fuchka": "fuchkaName",
	"delivery": "deliveryName", "hawker": "hawkerName", "boat": "boatName"}


## The character played most in the days kept (rickshaw if none yet).
static func favourite(data: Dictionary) -> String:
	var count := {}
	for h in data.get("history", []):
		var w := str(h.get("who", ""))
		if w != "":
			count[w] = int(count.get(w, 0)) + 1
	var best := "rickshaw"
	var most := 0
	for w in count:
		if int(count[w]) > most:
			most = int(count[w])
			best = w
	return best


## The card as a Control `k` times the preview size (360 by 500).
static func view(progress: Object, s: Object, k := 1.0) -> Control:
	var data: Dictionary = progress.data
	var who := favourite(data)
	var face: Array = FACES.get(who, FACES.rickshaw)
	var colour := Color(str(face[1]))
	var root := Panel.new()
	root.custom_minimum_size = Vector2(360, 500) * k
	root.size = root.custom_minimum_size
	var bg := StyleBoxFlat.new()
	bg.bg_color = colour.darkened(0.25)
	bg.border_color = Look.YELLOW
	bg.set_border_width_all(int(8 * k))
	bg.set_corner_radius_all(int(28 * k))
	root.add_theme_stylebox_override("panel", bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 22 * k
	col.offset_right = -22 * k
	col.offset_top = 16 * k
	col.offset_bottom = -14 * k
	col.add_theme_constant_override("separation", int(6 * k))
	root.add_child(col)
	var title := Look.title(s.t("idTitle"), int(34 * k), Look.YELLOW, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var face_box := CenterContainer.new()
	var disc := Panel.new()
	disc.custom_minimum_size = Vector2(130, 130) * k
	var ds := StyleBoxFlat.new()
	ds.bg_color = colour
	ds.border_color = Color.WHITE
	ds.set_border_width_all(int(6 * k))
	ds.set_corner_radius_all(int(65 * k))
	disc.add_theme_stylebox_override("panel", ds)
	var pic := TextureRect.new()
	pic.texture = Look.icon_texture(str(face[0]), int(130 * k))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 12 * k
	pic.offset_right = -12 * k
	pic.offset_top = 10 * k
	disc.add_child(pic)
	face_box.add_child(disc)
	col.add_child(face_box)
	var my_name := str(Friends.of(data).name)
	var name := Look.label(my_name if my_name != "" else s.t("idNoName"), int(28 * k), true, Color.WHITE)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name)
	var fav := Look.label(s.t("idFavourite", {"name": s.t(NAMES.get(who, "rickshawName"))}), int(15 * k), false, Look.CREAM)
	fav.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(fav)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(8 * k))
	grid.add_theme_constant_override("v_separation", int(8 * k))
	col.add_child(grid)
	var streak: Dictionary = data.get("streak", {})
	for pair in [["idLevel", progress.level()], ["idDays", int(data.get("day", 0))],
			["idStreak", int(streak.get("best", 0))], ["idCards", "%d/%d" % [Cards.of(data).size(), Cards.count()]]]:
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cs := Look.card(Look.CREAM, int(14 * k), int(3 * k))
		cs.content_margin_top = 4 * k
		cs.content_margin_bottom = 4 * k
		cell.add_theme_stylebox_override("panel", cs)
		var cc := VBoxContainer.new()
		cc.add_theme_constant_override("separation", 0)
		cell.add_child(cc)
		var v := Look.label(s.num(str(pair[1])), int(24 * k), true, colour.darkened(0.3))
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cc.add_child(v)
		var l := Look.label(s.t(str(pair[0])), int(12 * k), false, Look.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cc.add_child(l)
		grid.add_child(cell)
	var school := School.mine(data)
	if school != "":
		var sc := Look.label(School.name_of(school, s.lang), int(15 * k), true, Look.YELLOW)
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(sc)
	var foot := Look.label("pranerdhaka.web.app", int(12 * k), true, Look.CREAM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(foot)
	return root


## The card as a picture to share.
static func picture(host: Node, progress: Object, s: Object) -> Image:
	var c := view(progress, s, float(SIZE.x) / 360.0)
	return await Render.picture(host, c, SIZE, true)
