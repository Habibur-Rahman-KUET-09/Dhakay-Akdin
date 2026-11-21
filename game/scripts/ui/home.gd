## The mohalla screen (§৩). For now: the three characters (Rahim Chacha can
## be driven) and a language switch.
extends Control

const Look = preload("res://scripts/ui/look.gd")
const Strings = preload("res://scripts/ui/strings.gd")
const Balance = preload("res://scripts/rules/balance.gd")
const CrashWatch = preload("res://scripts/ui/crash_watch.gd")

var s := Strings.new()
var _crash := ""


func _ready() -> void:
	s.lang = Strings.saved_lang()
	_crash = CrashWatch.last_crash()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Look.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var top := HBoxContainer.new()
	var title := Look.label(s.t("appTitle"), 34, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var lang := Button.new()
	lang.name = "Language"
	lang.text = "English" if s.lang == "bn" else "বাংলা"
	lang.flat = true
	lang.add_theme_color_override("font_color", Look.MAGENTA)
	lang.pressed.connect(_switch_language)
	top.add_child(lang)
	col.add_child(top)
	col.add_child(Look.label(s.t("tagline"), 18))

	var b := Balance.new()
	var people := [
		["rickshawName", "rickshawRole", Look.MAGENTA, 1],
		["teaName", "teaRole", Look.PARROT, int(b.n("unlocks.tea_stall"))],
		["busName", "busRole", Look.SKY, int(b.n("unlocks.bus"))],
	]
	for p in people:
		col.add_child(_card(p[0], p[1], p[2], p[3]))
	if _crash != "":
		col.add_child(_crash_card())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var version := Look.label("%s · %s" % [s.t("testBuild"), ProjectSettings.get_setting("application/config/version", "dev")], 13)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(version)


func _card(name_key: String, role_key: String, colour: Color, level: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(Color.WHITE, 18, 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(52, 52)
	var circle := Look.card(colour, 26, 0)
	dot.add_theme_stylebox_override("panel", circle)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(Look.label(s.t(name_key), 20, true))
	var role := s.t(role_key)
	if level > 1:
		role += " · " + s.t("unlocksAt", {"level": level})
	text.add_child(Look.label(role, 15))
	row.add_child(text)
	if level == 1:
		var drive := Look.button(s.t("rickshawDrive"))
		drive.name = "Drive"
		drive.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		drive.pressed.connect(_drive)
		row.add_child(drive)
	else:
		var soon := Look.label(s.t("comingSoon"), 13)
		soon.autowrap_mode = TextServer.AUTOWRAP_OFF
		soon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(soon)
	return panel


## Shown after a run that ended suddenly: a note and a button that copies
## the log, so the player can send it.
func _crash_card() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(Color("FDECEA"), 14, 2))
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(Look.label(s.t("crashTitle"), 16, true, Look.VERMILION))
	box.add_child(Look.label(s.t("crashHelp"), 14))
	var copy := Look.button(s.t("copyLog"), Look.OUTLINE, 15)
	copy.pressed.connect(_copy_log.bind(copy))
	box.add_child(copy)
	return panel


func _copy_log(button: Button) -> void:
	DisplayServer.clipboard_set(_crash)
	button.text = s.t("copied")


func _drive() -> void:
	CrashWatch.start("rickshaw")
	get_tree().change_scene_to_file("res://scenes/rickshaw.tscn")


func _switch_language() -> void:
	s.lang = "en" if s.lang == "bn" else "bn"
	Strings.save_lang(s.lang)
	_build()
