## Colours and fonts: rickshaw art (docs/DETAILED_DESIGN.md §১০).
extends RefCounted

const MAGENTA := Color("C2185B")
const PARROT := Color("2E9E6B")
const YELLOW := Color("F6B800")
const SKY := Color("2D8BD6")
const VERMILION := Color("E2432A")
const OUTLINE := Color("1D1A1A")
const CREAM := Color("FFF6E5")

const REGULAR := "res://fonts/HindSiliguri-Regular.ttf"
const SEMIBOLD := "res://fonts/HindSiliguri-SemiBold.ttf"
const BOLD := "res://fonts/HindSiliguri-Bold.ttf"


static func font(path := REGULAR) -> Font:
	return load(path)


static func label(text: String, size := 18, bold := false, colour := OUTLINE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if bold:
		l.add_theme_font_override("font", font(BOLD))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A cream card with a dark outline, as on painted rickshaw panels.
static func card(fill := CREAM, radius := 14, border := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = OUTLINE
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func button(text: String, fill := MAGENTA, size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font(BOLD))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := card(fill.darkened(0.1) if state == "pressed" else fill, 12, 3)
		b.add_theme_stylebox_override(state, s)
	return b


# --- The painted look of the menus: chunky buttons, pills, icons ----------------

const INK := OUTLINE
## Darker shades of the paint, for white text on them (4.5:1 or more).
const PARROT_DARK := Color("1F7A50")
const SKY_DARK := Color("1E6FB0")
const MUTED := Color("5C534A")
const SAND := Color("EDE4D3")
const DISPLAY := "res://fonts/Galada-Regular.ttf"

static var _icons := {}


## An icon from textures/ui/ (SVG, drawn at the size asked for, twice over
## for sharp phone screens). Line icons are white: tint them with modulate.
static func icon_texture(name: String, px := 32) -> Texture2D:
	var key := "%s@%d" % [name, px]
	if _icons.has(key):
		return _icons[key]
	var img := Image.new()
	var bytes := FileAccess.get_file_as_bytes("res://textures/ui/%s.svg" % name)
	var natural := 64.0
	var head := bytes.get_string_from_utf8().substr(0, 160)
	var m := RegEx.create_from_string("width=\"(\\d+)\"").search(head)
	if m:
		natural = float(m.get_string(1))
	if bytes.is_empty() or img.load_svg_from_buffer(bytes, px * 2.0 / natural) != OK:
		push_error("icon %s missing" % name)
		img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


## An icon of `size` pixels, tinted (white line icons take the tint).
static func icon(name: String, size := 24, tint := Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon_texture(name, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.modulate = tint
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A big painted title (Galada), with a dark outline and a drop.
static func title(text: String, size := 40, colour := MAGENTA, outlined := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(DISPLAY))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if outlined:
		l.add_theme_color_override("font_outline_color", OUTLINE)
		l.add_theme_constant_override("outline_size", maxi(6, size / 6))
		l.add_theme_color_override("font_shadow_color", OUTLINE)
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 12))
		l.add_theme_constant_override("shadow_outline_size", maxi(6, size / 6))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A painted panel: fill, dark border, and a thicker dark edge below
## (`depth`) so it stands up from the page like a key.
static func chunky_style(fill: Color, radius := 18, depth := 6, border := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = OUTLINE
	s.set_border_width_all(border)
	s.border_width_bottom = border + depth
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.anti_aliasing = true
	return s


## A big game button. Pressed, it sinks onto its edge.
static func chunky(text: String, fill := YELLOW, ink := OUTLINE, size := 22, depth := 6, radius := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font(BOLD))
	b.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, ink)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_color_override("icon_normal_color", ink)
	b.add_theme_color_override("icon_pressed_color", ink)
	b.add_theme_color_override("icon_hover_color", ink)
	b.add_theme_color_override("icon_focus_color", ink)
	b.add_theme_color_override("icon_disabled_color", MUTED)
	b.add_theme_constant_override("h_separation", 10)
	var up := chunky_style(fill, radius, depth)
	var down := chunky_style(fill.darkened(0.08), radius, 1)
	down.content_margin_top = up.content_margin_top + depth - 1
	var off := chunky_style(SAND, radius, 1)
	off.border_color = Color("8A8178")
	for state in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, up)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("hover_pressed", down)
	b.add_theme_stylebox_override("disabled", off)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


## A rounded chip with an icon and a bold number or word.
static func pill(icon_name: String, text: String, fill := Color.WHITE, ink := OUTLINE, size := 17, tint := Color.WHITE) -> PanelContainer:
	var p := PanelContainer.new()
	var s := card(fill, 99, 3)
	s.content_margin_left = 6
	s.content_margin_right = 12
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	if icon_name != "":
		row.add_child(icon(icon_name, size + 6, tint))
	var l := label(text, size, true, ink)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	return p


## A bar with a dark outline: how far along something is.
static func bar(value: int, goal: int, colour: Color, height := 16) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = maxi(1, goal)
	b.value = clampi(value, 0, maxi(1, goal))
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("F0E4CC")
	bg.border_color = OUTLINE
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(height)
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(height)
	fill.border_color = OUTLINE
	fill.set_border_width_all(2)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	return b


## A painted strip of diamonds, as along a rickshaw's hood.
static func band(height := 22) -> TextureRect:
	var r := TextureRect.new()
	# The tile is 26 x 22 at 2x: drawn as is, so load it at the band's height.
	r.texture = icon_texture("band", int(round(height * 52.0 / 88.0)))
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.custom_minimum_size = Vector2(0, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Lets a coloured icon (a coin, a star, a tick) on a chunky button keep
## its own colours, instead of the button's ink.
static func true_colours(b: Button) -> void:
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(state, Color.WHITE)
