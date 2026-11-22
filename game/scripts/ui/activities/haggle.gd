## Haggling face to face: hold and drag up to ask more (5 taka a notch),
## watching the passenger's face: content, then frowning, then cross.
## Let go to ask. Past what they will pay, they walk off.
extends "res://scripts/ui/activity.gd"

var offer := 0
var most := 0
var asked := 0
## How the passenger takes an asking (Day.mood): 0 content … 1 at the edge.
var mood_of: Callable
var _drag := false
var _from_y := 0.0
var _from := 0
var _last := 0


func start(offered: int, highest: int) -> void:
	offer = offered
	most = highest
	asked = offered
	_last = offered


func _mood() -> float:
	return float(mood_of.call(asked)) if mood_of.is_valid() else 0.0


func _touch(e) -> void:
	if e is InputEventMouseButton:
		if e.pressed:
			_drag = true
			_from_y = e.position.y
			_from = asked
		elif _drag:
			_drag = false
			finish(0.5)
	elif e is InputEventMouseMotion and _drag:
		var notches := floori((_from_y - float(e.position.y)) / 24.0)
		asked = clampi(_from + notches * 5, offer, most)
		if asked != _last:
			_last = asked
			buzz(8 if _mood() < 0.8 else 30)


func _paint(c: Control) -> void:
	var w := c.size.x
	var m := clampf(_mood(), 0.0, 1.3)
	var at := Vector2(w * 0.5, c.size.y * 0.4)
	var skin := Color("D9A066").lerp(Color("E2553A"), clampf((m - 0.5) * 1.6, 0.0, 1.0))
	c.draw_circle(at, 78.0, skin)
	c.draw_arc(at, 78.0, 0, TAU, 40, Look.OUTLINE, 3.0)
	# Eyes, and brows that knit as the asking goes up.
	for side in [-1.0, 1.0]:
		var eye := at + Vector2(28 * side, -14)
		c.draw_circle(eye, 7.0, Look.OUTLINE)
		var inner := eye + Vector2(-14 * side, -18 + 10 * m)
		var outer := eye + Vector2(14 * side, -24 - 4 * m)
		c.draw_line(inner, outer, Look.OUTLINE, 4.0)
	# The mouth: a smile, flat, then down.
	var bend := lerpf(14.0, -16.0, clampf(m, 0.0, 1.0))
	var mouth := PackedVector2Array()
	for i in 9:
		var x := -28.0 + i * 7.0
		mouth.append(at + Vector2(x, 34 - bend * (1.0 - pow(x / 28.0, 2))))
	c.draw_polyline(mouth, Look.OUTLINE, 4.0)
	if m > 0.9:
		c.draw_circle(at + Vector2(70, -40), 8.0, Color("7FC8F8"))
	var colour := Look.PARROT if m < 0.5 else (Look.YELLOW.darkened(0.3) if m < 0.85 else Look.VERMILION)
	text_at(c, Vector2(w * 0.5, c.size.y * 0.4 + 120), s.t("takaN", {"n": asked}), 30, colour)
	text_at(c, Vector2(w * 0.5, c.size.y * 0.4 + 156), s.t("haggleFace_%d" % (0 if m < 0.5 else (1 if m < 0.85 else 2))), 15, colour)
	# The way up: an arrow by the finger.
	c.draw_line(Vector2(w - 40, c.size.y - 30), Vector2(w - 40, 40), Color(0, 0, 0, 0.2), 6.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(w - 52, 50), Vector2(w - 28, 50), Vector2(w - 40, 28)]), Color(0, 0, 0, 0.2))
