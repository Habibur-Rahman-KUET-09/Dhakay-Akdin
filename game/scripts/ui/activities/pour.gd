## Monir Mama's long pour, cup to cup: drag the top cup up and down. Every
## stroke high enough froths the tea; four make it perfect. Too high and
## it spills.
extends "res://scripts/ui/activity.gd"

var height := 0.0
var strokes: Array = []
var spilled := false
var _peak := 0.0
var _drag := false


func _tick(_dt: float) -> void:
	if t > 8.0:
		_end()


func _touch(e) -> void:
	if e is InputEventMouseButton:
		_drag = e.pressed
		if e.pressed:
			_lift(e.position)
	elif e is InputEventMouseMotion and _drag:
		_lift(e.position)


func _lift(p: Vector2) -> void:
	var h := clampf(1.0 - p.y / maxf(1.0, canvas.size.y), 0.0, 1.0)
	height = h
	if h >= Rules.POUR_SPILL and not spilled:
		spilled = true
		buzz(90)
		set_hint(s.t("pourSpilled"))
	if h > 0.2:
		_peak = maxf(_peak, h)
	elif _peak > 0.2:
		# Back down: one stroke.
		strokes.append(_peak)
		if _peak >= Rules.POUR_HIGH:
			buzz(20)
		_peak = 0.0
		if _good() >= Rules.POUR_STROKES or strokes.size() >= 7:
			_end()


func _good() -> int:
	var n := 0
	for h in strokes:
		if float(h) >= Rules.POUR_HIGH:
			n += 1
	return n


func _end() -> void:
	finish(Rules.pour_score(strokes, spilled))


func _paint(c: Control) -> void:
	var w := c.size.x
	var hgt := c.size.y
	bar(c, Rect2(16, 8, w - 32, 16), Rules.pour_score(strokes, spilled), Look.PARROT)
	text_at(c, Vector2(w * 0.5, 44), s.t("pourCount", {"n": _good(), "all": Rules.POUR_STROKES}), 16)
	var low := Vector2(w * 0.42, hgt - 46)
	var top := Vector2(w * 0.58, lerpf(hgt - 120.0, 64.0, height))
	if height > 0.05:
		var lip := top + Vector2(-24, 14)
		c.draw_line(lip, low + Vector2(0, -26), Color("B8733A"), lerpf(7.0, 2.5, height))
		if spilled:
			for i in 6:
				c.draw_circle(low + Vector2(-40 + i * 16, 18), 5.0, Color("B8733A"))
	_glass(c, low, Color("B8733A"))
	_glass(c, top, Color("B8733A"), -0.5)
	# The froth on the lower cup.
	var froth := float(_good()) / Rules.POUR_STROKES
	if froth > 0.0:
		c.draw_rect(Rect2(low + Vector2(-22, -30), Vector2(44, 8 * froth)), Color("F3E3C3"))


## A small tea glass, tilted by `tilt` radians.
static func _glass(c: Control, at: Vector2, tea: Color, tilt := 0.0) -> void:
	var pts := PackedVector2Array([Vector2(-24, -32), Vector2(24, -32), Vector2(18, 30), Vector2(-18, 30)])
	var turned := PackedVector2Array()
	for p in pts:
		turned.append(at + p.rotated(tilt))
	var inside := PackedVector2Array()
	for p in [Vector2(-21, -20), Vector2(21, -20), Vector2(16, 27), Vector2(-16, 27)]:
		inside.append(at + p.rotated(tilt))
	c.draw_colored_polygon(turned, Color(1, 1, 1, 0.75))
	c.draw_colored_polygon(inside, tea)
	turned.append(turned[0])
	c.draw_polyline(turned, Look.OUTLINE, 2.5)
