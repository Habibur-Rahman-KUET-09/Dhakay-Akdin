## Answering someone's questions with the right thing to say: a question,
## three answers, one that works. A few rounds; the score is the share
## answered well. (Rahim Chacha keeping Sumi's birthday a secret.)
extends "res://scripts/ui/activity.gd"

## [{q: {bn, en}, options: [{bn, en}…], right: index}].
var rounds: Array = []
## Who asks (a cast id), shown with the question.
var asker := ""
var right := 0
var _i := 0
var _col: VBoxContainer
var _said := ""
var _said_ok := false
var _wait := 0.0


func _build() -> void:
	_col = VBoxContainer.new()
	_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_col.offset_left = 12
	_col.offset_right = -12
	_col.offset_top = 64
	_col.add_theme_constant_override("separation", 8)
	canvas.add_child(_col)
	_show()


func _show() -> void:
	for k in _col.get_children():
		k.queue_free()
	if _i >= rounds.size():
		return
	var r: Dictionary = rounds[_i]
	set_hint(str(r.q.get(s.lang, r.q.get("en", ""))))
	for j in (r.options as Array).size():
		var o: Dictionary = r.options[j]
		var b := Look.button(str(o.get(s.lang, o.get("en", ""))), Look.SKY.darkened(0.15), 16)
		b.custom_minimum_size = Vector2(0, 52)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_answer.bind(j))
		_col.add_child(b)


func _answer(j: int) -> void:
	if _wait > 0.0 or _i >= rounds.size():
		return
	_said_ok = j == int(rounds[_i].right)
	if _said_ok:
		right += 1
	_said = s.t("chooseOk" if _said_ok else "chooseNo")
	buzz(20 if _said_ok else 80)
	_wait = 1.0
	for k in _col.get_children():
		(k as Button).disabled = true


func _tick(dt: float) -> void:
	if _wait > 0.0:
		_wait -= dt
		if _wait <= 0.0:
			_said = ""
			_i += 1
			if _i >= rounds.size():
				finish(float(right) / maxf(1.0, rounds.size()))
				return
			_show()
	if t > 45.0:
		finish(float(right) / maxf(1.0, rounds.size()))


func _paint(c: Control) -> void:
	var w := c.size.x
	text_at(c, Vector2(w * 0.5, 14), s.t("chooseRound", {"n": mini(_i + 1, rounds.size()), "of": rounds.size()}), 15, Look.MUTED)
	if _said != "":
		text_at(c, Vector2(w * 0.5, 42), _said, 18, Look.PARROT if _said_ok else Look.VERMILION)
