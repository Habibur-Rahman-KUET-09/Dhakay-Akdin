## Paid by phone: the SMS on Rahim Chacha's phone. Is it real? The right
## amount, from the service (not an ordinary number), just now, the name
## spelt right. "Fine" or "Fake!". Skipping takes it as fine.
extends "res://scripts/ui/activity.gd"

## The message (Hands.phone_sms) and the fare it should be for.
var sms := {}
var fare := 0
## What the player said; read by the scene after `done`.
var said_fake := false
## With his own phone, the earlier SMS are there to compare with.
var has_phone := false


func _build() -> void:
	set_hint(s.t("act_sms_hint", {"fare": fare}))
	var phone := PanelContainer.new()
	phone.add_theme_stylebox_override("panel", Look.card(Color("1F2328"), 22, 3))
	phone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phone.offset_left = 24
	phone.offset_right = -24
	phone.offset_top = 6
	phone.offset_bottom = -6
	phone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(phone)
	var screen := PanelContainer.new()
	screen.add_theme_stylebox_override("panel", Look.card(Color("F4F1E8"), 12, 0))
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone.add_child(screen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	screen.add_child(col)
	var sender := s.t("sms_service" if sms.get("name_ok", true) else "sms_service_typo")
	if not sms.get("from_service", true):
		sender = s.t("sms_number")
	col.add_child(Look.label(sender, 18, true, Look.MAGENTA))
	var body := Look.label(s.t("sms_body", {
		"amount": int(sms.get("amount", 0)),
		"when": s.t("sms_now" if sms.get("today", true) else "sms_old"),
		"trx": str(sms.get("trx", "")),
	}), 17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	if has_phone:
		var tip := Look.label(s.t("smsPhoneTip"), 14, true, Look.PARROT_DARK)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(tip)
	add_button("sms_ok", Look.PARROT, _answer.bind(false))
	add_button("sms_fake", Look.VERMILION, _answer.bind(true))


func _tick(_dt: float) -> void:
	# Left too long, the passenger walks off as if it were fine.
	if t > 20.0:
		_answer(false)


func _answer(fake: bool) -> void:
	said_fake = fake
	finish(1.0)
