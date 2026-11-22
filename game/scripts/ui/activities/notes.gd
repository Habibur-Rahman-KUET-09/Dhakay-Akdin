## Notes between the fingers, the conductor's way: smooth out the
## crumpled note (swipe across it), then drag it between the right
## fingers: 5 and 10, 20, 50, 100 and up. The wrong gap, and it falls
## back.
extends "res://scripts/ui/activity.gd"

const NOTE_COLOURS := {5: Color("B07A4A"), 10: Color("D46A8C"), 20: Color("3E8E5E"), 50: Color("8A6A3A"), 100: Color("3D6FB0"), 500: Color("7E4FA0")}

## The notes in his hand (values), and putting one away (BusDay.sort_note).
var notes: Array = []
var on_sort: Callable
var _i := 0
var _smooth := false
var _drag := false
var _swipe_from := INF
var _at := Vector2.ZERO
var _shake := 0.0


func _build() -> void:
	add_button("doneButton", Look.PARROT, func(): finish(1.0 if _i >= notes.size() else 0.5))


func _tick(dt: float) -> void:
	_shake = maxf(0.0, _shake - dt * 3.0)
	if _i >= notes.size():
		finish(1.0)


func _note_rect() -> Rect2:
	return Rect2(Vector2(canvas.size.x * 0.5 - 90, 40), Vector2(180, 90))


func _slot(k: int) -> Rect2:
	var w := canvas.size.x
	return Rect2(Vector2(20 + k * (w - 40) / 4.0 + 4, canvas.size.y - 110), Vector2((w - 40) / 4.0 - 8, 100))


func _touch(e) -> void:
	if _i >= notes.size():
		return
	if e is InputEventMouseButton:
		if e.pressed and _note_rect().grow(20).has_point(e.position):
			if _smooth:
				_drag = true
				_at = e.position
			else:
				_swipe_from = e.position.x
		elif not e.pressed:
			if _drag:
				_drag = false
				_drop(e.position)
			_swipe_from = INF
	elif e is InputEventMouseMotion:
		if _drag:
			_at = e.position
		elif _swipe_from != INF and absf(float(e.position.x) - _swipe_from) > 70.0:
			_smooth = true
			_swipe_from = INF
			buzz(12)


func _drop(at: Vector2) -> void:
	var note := int(notes[_i])
	for k in 4:
		if _slot(k).has_point(at):
			if k == Rules.finger_for(note) and on_sort.call(note):
				buzz(20)
				_i += 1
				_smooth = false
			else:
				buzz(70)
				_shake = 1.0
			return


func _paint(c: Control) -> void:
	var w := c.size.x
	text_at(c, Vector2(w * 0.5, 14), s.t("notesLeft", {"n": notes.size() - _i}), 16)
	for k in 4:
		var r := _slot(k)
		c.draw_rect(r, Color("E7C9A6"))
		c.draw_rect(r, Look.OUTLINE, false, 2.0)
		text_at(c, r.get_center() + Vector2(0, 30), s.t("finger_%d" % k), 15)
	if _i >= notes.size():
		return
	var note := int(notes[_i])
	var colour: Color = NOTE_COLOURS.get(note, Color("777777"))
	var r := _note_rect()
	if _drag:
		r.position = _at - r.size / 2.0
	r.position.x += sin(t * 40.0) * 8.0 * _shake
	if _smooth:
		c.draw_rect(r, colour)
		c.draw_rect(r.grow(-8), colour.lightened(0.25), false, 2.0)
	else:
		# Crumpled: a smaller, jagged thing.
		var pts := PackedVector2Array()
		var centre := r.get_center()
		for k in 10:
			var a := TAU * k / 10.0
			pts.append(centre + Vector2(cos(a) * (50 + 12 * (k % 2)), sin(a) * (32 + 8 * ((k + 1) % 2))))
		c.draw_colored_polygon(pts, colour.darkened(0.15))
	text_at(c, r.get_center(), str(note), 30, Color.WHITE)
