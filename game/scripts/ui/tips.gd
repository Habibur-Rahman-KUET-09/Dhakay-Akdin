## A tip on the loading screens: something useful (or just fun) to read
## while the town is set up. The tips are tip_0, tip_1, … in strings.json.
extends RefCounted

const Look = preload("res://scripts/ui/look.gd")
const Strings = preload("res://scripts/ui/strings.gd")


## How many tips there are.
static func count(s: Strings) -> int:
	var n := 0
	while s.has("tip_%d" % n):
		n += 1
	return n


## A card with a random tip, for the bottom of a loading screen.
static func card(s: Strings) -> Control:
	var n := count(s)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.card(Color.WHITE, 16, 3))
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_bottom = -60
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	col.add_child(Look.label(s.t("tipTitle"), 16, true, Look.MAGENTA))
	var line := Look.label(s.t("tip_%d" % (randi() % maxi(1, n))), 16, false, Look.OUTLINE)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	return panel
