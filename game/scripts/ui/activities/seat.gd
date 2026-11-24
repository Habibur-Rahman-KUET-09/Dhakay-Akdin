## Someone who needs a seat is standing: whom will Babu ask to stand? The
## seated passengers are shown by what they are doing; pick one.
extends "res://scripts/ui/activity.gd"

## [{id, trait}] from BusDay.seat_candidates, and who needs it ("mother"
## or "sick").
var candidates: Array = []
var need := "sick"
## The one picked (an id), read by the scene after `done`; -1 if skipped.
var picked := -1


func _build() -> void:
	set_hint(s.t("act_seat_hint", {"who": s.t("need_" + need)}))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12
	col.offset_right = -12
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	canvas.add_child(col)
	for r in candidates:
		var b := Look.button(s.t("trait_" + str(r.get("trait", "plain"))), Color.WHITE, 17)
		b.add_theme_color_override("font_color", Look.OUTLINE)
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(_pick.bind(int(r.id)))
		col.add_child(b)


func _pick(id: int) -> void:
	picked = id
	finish(1.0)
