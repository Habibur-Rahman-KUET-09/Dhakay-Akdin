## The phone rings: someone from home (content/calls.json). Who it is,
## what they say, and the answers to choose from.
extends "res://scripts/ui/activity.gd"

## The call (HomeCall.pick), and the answer chosen; read by the scene
## after `done` ("" when skipped).
var call := {}
var option := ""


func _build() -> void:
	set_hint(s.t("call_from", {"who": s.t("caller_" + str(call.get("by", "")))}))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12
	col.offset_right = -12
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	canvas.add_child(col)
	var said := Look.label(str(call.get(s.lang, call.get("bn", ""))), 19, true, Look.OUTLINE)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(said)
	var options: Dictionary = call.get("options", {})
	for key in options:
		var o: Dictionary = options[key]
		var b := Look.button(s.t("call_" + str(key), {"n": int(o.get("cost", 0))}), Look.PARROT if int(o.get("family", 0)) > 0 else Look.SKY.darkened(0.2), 17)
		b.custom_minimum_size = Vector2(0, 54)
		b.pressed.connect(_answer.bind(str(key)))
		col.add_child(b)
	buzz(300)


func _answer(key: String) -> void:
	option = key
	finish(1.0)
