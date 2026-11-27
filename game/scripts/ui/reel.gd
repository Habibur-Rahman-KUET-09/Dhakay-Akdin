## The day's reel: a 12-second video for reels and statuses, drawn here
## frame by frame (the character, the day's money counting up, the best
## moments, the game's name) and made into an MP4 with the theme song by
## the phone's own encoder (the Android plugin's makeVideo).
extends Node

const Look = preload("res://scripts/ui/look.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Share = preload("res://scripts/ui/share.gd")

signal status(text: String)
signal finished(path: String)

const SIZE := Vector2i(540, 960)
const FPS := 12
const SECONDS := 12.0
const DIR := "user://reel"
const OUT := "user://share/reel.mp4"
const RATE := 22050

## {face, colour (Color), name, money, stars, lines: [], url}
var info := {}
var s: Strings
var _vp: SubViewport
var _pages: Array[Control] = []
var _face: TextureRect
var _money: Label
var _stars: Array[TextureRect] = []
var _lines: Array[Label] = []


func make() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_vp.add_child(_build())
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var count := int(FPS * SECONDS)
	for i in count:
		_animate(float(i) / FPS)
		await RenderingServer.frame_post_draw
		if not is_inside_tree():
			return
		_vp.get_texture().get_image().save_png(DIR.path_join("f%03d.png" % i))
		if i % FPS == 0:
			status.emit(s.t("reelMaking", {"n": int(100.0 * i / count)}))
	var music := FileAccess.open(DIR.path_join("music.pcm"), FileAccess.WRITE)
	if music != null:
		music.store_buffer(FileAccess.get_file_as_bytes("res://sounds/reel_music.pcm"))
		music.close()
	status.emit(s.t("reelEncoding"))
	var p := Share.plugin()
	if p == null or not p.has_method("makeVideo"):
		finished.emit.call_deferred("")
		return
	p.connect("video_ready", _ready_video, CONNECT_ONE_SHOT)
	p.connect("video_failed", _failed_video, CONNECT_ONE_SHOT)
	p.makeVideo(ProjectSettings.globalize_path(DIR), count, FPS, ProjectSettings.globalize_path(DIR.path_join("music.pcm")),
		RATE, ProjectSettings.globalize_path(OUT))


func _ready_video(_path: String) -> void:
	_disconnect()
	finished.emit.call_deferred(OUT)


func _failed_video(why: String) -> void:
	print("[reel] failed: ", why)
	_disconnect()
	finished.emit.call_deferred("")


func _disconnect() -> void:
	var p := Share.plugin()
	for sig in ["video_ready", "video_failed"]:
		for c in p.get_signal_connection_list(sig):
			if c.callable.get_object() == self:
				p.disconnect(sig, c.callable)


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Look.label(text, size, true, colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(SIZE.x - 60, 0)
	return l


func _page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.position = Vector2(30, 150)
	page.size = Vector2(SIZE.x - 60, SIZE.y - 260)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 18)
	_pages.append(page)
	return page


func _build() -> Control:
	var root := Control.new()
	root.size = Vector2(SIZE)
	var bg := ColorRect.new()
	bg.color = Color("2B2238")
	bg.size = Vector2(SIZE)
	root.add_child(bg)
	var band := ColorRect.new()
	band.color = info.colour
	band.size = Vector2(SIZE.x, 18)
	band.position = Vector2(0, SIZE.y - 18)
	root.add_child(band)
	var flags := TextureRect.new()
	flags.texture = Look.icon_texture("bunting", 540)
	flags.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flags.stretch_mode = TextureRect.STRETCH_SCALE
	flags.size = Vector2(SIZE.x, 80)
	root.add_child(flags)
	# 1: who, and the game.
	var one := _page()
	_face = TextureRect.new()
	_face.texture = Look.icon_texture(str(info.face), 256)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.custom_minimum_size = Vector2(0, 280)
	_face.pivot_offset = Vector2((SIZE.x - 60) / 2.0, 140)
	one.add_child(_face)
	one.add_child(_label(s.t("reelDayOf", {"name": str(info.name)}), 34, Look.YELLOW))
	one.add_child(_label(s.t("appTitle"), 28, Color.WHITE))
	# 2: the money, counting up, and the stars.
	var two := _page()
	two.add_child(_label(s.t("reelEarned"), 30, Color.WHITE))
	_money = _label("", 64, Look.YELLOW)
	two.add_child(_money)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for i in 5:
		var star := TextureRect.new()
		star.texture = Look.icon_texture("star_off", 64)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.custom_minimum_size = Vector2(64, 64)
		_stars.append(star)
		row.add_child(star)
	two.add_child(row)
	# 3: the best moments.
	var three := _page()
	three.add_child(_label(s.t("reelMoments"), 30, Look.YELLOW))
	for line in (info.lines as Array).slice(0, 3):
		var l := _label(str(line), 24, Color.WHITE)
		_lines.append(l)
		three.add_child(l)
	# 4: play too.
	var four := _page()
	four.add_child(_label(s.t("reelPlay"), 40, Look.YELLOW))
	four.add_child(_label(s.t("appTitle"), 52, Color.WHITE))
	four.add_child(_label(str(info.url), 22, Color("C9B8EE")))
	for p in _pages:
		root.add_child(p)
	return root


## The picture at second t: which page shows, fading in and out, and what
## moves on it.
func _animate(t: float) -> void:
	var starts := [0.0, 3.0, 6.0, 9.5, SECONDS]
	for i in _pages.size():
		var a: float = starts[i]
		var z: float = starts[i + 1]
		var alpha := clampf((t - a) / 0.35, 0.0, 1.0) * clampf((z - t) / 0.35, 0.0, 1.0) if i < _pages.size() - 1 else clampf((t - a) / 0.35, 0.0, 1.0)
		_pages[i].modulate.a = alpha
		_pages[i].visible = alpha > 0.0
	var pop := clampf(t / 0.6, 0.0, 1.0)
	_face.scale = Vector2.ONE * lerpf(0.6, 1.0, ease(pop, 0.4)) * (1.0 + 0.03 * sin(t * 6.0))
	var k := clampf((t - 3.2) / 1.6, 0.0, 1.0)
	_money.text = s.t("taka", {"n": int(round(float(info.money) * k))})
	var stars := int(round(float(info.stars)))
	var shown := clampi(int((t - 4.6) / 0.25) + 1, 0, stars)
	for i in 5:
		_stars[i].texture = Look.icon_texture("star" if i < shown else "star_off", 64)
	for i in _lines.size():
		_lines[i].modulate.a = clampf((t - 6.3 - i * 0.9) / 0.4, 0.0, 1.0)
