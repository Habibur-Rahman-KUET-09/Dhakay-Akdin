## Stickers to send in Messenger and WhatsApp: the characters' faces with
## a line of theirs in a speech bubble, drawn as a 512x512 picture with a
## clear background and shared like any picture.
extends RefCounted

const Look = preload("res://scripts/ui/look.gd")
const Render = preload("res://scripts/ui/render.gd")

## [face, line's string key, bubble colour]
const LIST := [
	["rahim", "stk_jam", "C2185B"], ["monir", "stk_tea", "2E9E6B"], ["babu", "stk_ostad", "2D8BD6"],
	["julekha", "stk_tok", "E2432A"], ["ratul", "stk_order", "F26B1D"], ["kashem", "stk_badam", "A0722F"],
	["haripada", "stk_boat", "1F6E8C"], ["rahim", "stk_fare", "7B1FA2"],
]


## A sticker as Controls (for the page and for drawing).
static func view(face: String, line: String, colour: Color, size := 512.0) -> Control:
	var root := Control.new()
	root.size = Vector2(size, size)
	root.custom_minimum_size = Vector2(size, size)
	var k := size / 512.0
	var pic := TextureRect.new()
	pic.texture = Look.icon_texture(face, 256)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.position = Vector2(56, 150) * k
	pic.size = Vector2(400, 360) * k
	root.add_child(pic)
	var bubble := PanelContainer.new()
	var st := Look.card(colour, int(30 * k), int(6 * k))
	for side in ["left", "right", "top", "bottom"]:
		st.set("content_margin_" + side, 18 * k)
	st.border_color = Color.WHITE
	bubble.add_theme_stylebox_override("panel", st)
	bubble.position = Vector2(20, 14) * k
	bubble.size = Vector2(472, 0) * k
	var words := Look.label(line, int(44 * k), true, Color.WHITE)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size = Vector2(430, 0) * k
	bubble.add_child(words)
	root.add_child(bubble)
	return root


## The sticker as a picture.
static func picture(host: Node, face: String, line: String, colour: Color) -> Image:
	return await Render.picture(host, view(face, line, colour), Vector2i(512, 512), true)
