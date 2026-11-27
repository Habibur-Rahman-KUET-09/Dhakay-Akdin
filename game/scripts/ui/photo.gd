## Photo mode: a picture of the scene as it is now (the buttons hidden),
## put in a frame with a line and the game's name, to share. Frames: the
## game's own, and those won in the season pass.
extends Control

const Look = preload("res://scripts/ui/look.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Render = preload("res://scripts/ui/render.gd")
const Share = preload("res://scripts/ui/share.gd")

## Frame id -> colour; their words are strings of the same name.
const FRAMES := {"frame_dhaka": "C2185B", "frame_raja": "F6B800", "frame_jam": "1E6FB0", "frame_eid": "2E9E6B"}

var s: Strings
var shot: Image
var frames: Array = ["frame_dhaka"]
var _at := 0
var _view: TextureRect
var _framed: Image


## A camera button for a scene's screen: takes the photo when pressed.
static func button(scene: Node, layer: CanvasLayer, strings: Strings, won: Array) -> Button:
	var b := Look.chunky(strings.t("photoButton"), Color.WHITE, Look.OUTLINE, 14, 3, 12)
	b.name = "PhotoMode"
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.pressed.connect(func(): take(scene, layer, strings, won))
	return b


static func take(scene: Node, layer: CanvasLayer, strings: Strings, won: Array) -> void:
	var hidden: Array = []
	for c in scene.find_children("*", "CanvasLayer", true, false):
		if c.visible:
			c.visible = false
			hidden.append(c)
	await scene.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = scene.get_viewport().get_texture().get_image()
	for c in hidden:
		c.visible = true
	var mode = load("res://scripts/ui/photo.gd").new()
	mode.s = strings
	mode.shot = img
	for f in won:
		if FRAMES.has(f) and not mode.frames.has(f):
			mode.frames.append(f)
	layer.add_child(mode)
	scene.get_tree().paused = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 20
	col.offset_right = -20
	col.offset_top = 30
	col.offset_bottom = -30
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	_view = TextureRect.new()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_view)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for spec in [["photoFrame", Color.WHITE, _next_frame], ["photoShare", Look.MAGENTA, _share], ["photoClose", Color.WHITE, _close]]:
		var b := Look.chunky(s.t(spec[0]), spec[1], Look.OUTLINE if spec[1] == Color.WHITE else Color.WHITE, 15, 3, 12)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(spec[2])
		row.add_child(b)
	_draw_framed()


func _frame_view() -> Control:
	var id: String = frames[_at]
	var w := 720
	var h := int(w * float(shot.get_height()) / shot.get_width())
	var root := Control.new()
	root.size = Vector2(w + 48, h + 190)
	var border := ColorRect.new()
	border.color = Color(FRAMES[id])
	border.size = root.size
	root.add_child(border)
	var photo := TextureRect.new()
	photo.texture = ImageTexture.create_from_image(shot)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.position = Vector2(24, 24)
	photo.size = Vector2(w, h)
	root.add_child(photo)
	var words := Look.label(s.t(id), 52, true, Color.WHITE)
	words.position = Vector2(24, h + 34)
	words.size = Vector2(w, 80)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_theme_color_override("font_outline_color", Look.OUTLINE)
	words.add_theme_constant_override("outline_size", 10)
	root.add_child(words)
	var game := Look.label(s.t("appTitle") + " · pranerdhaka.web.app", 26, true, Color(1, 1, 1, 0.9))
	game.position = Vector2(24, h + 118)
	game.size = Vector2(w, 50)
	game.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(game)
	return root


func _draw_framed() -> void:
	var view := _frame_view()
	_framed = await Render.picture(self, view, Vector2i(view.size), false)
	_view.texture = ImageTexture.create_from_image(_framed)


func _next_frame() -> void:
	_at = (_at + 1) % frames.size()
	_draw_framed()


func _share() -> void:
	if _framed != null:
		Share.image(_framed, "photo", s.t("photoShareLine"))


func _close() -> void:
	get_tree().paused = false
	queue_free()
