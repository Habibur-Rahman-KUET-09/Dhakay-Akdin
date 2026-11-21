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
