## Cracking the puris for a plate: tap each of the six to make a small
## hole for the filling. A quick tap cracks it; pressing too long breaks
## it. Done when all six are tapped; the score is the share left whole.
extends "res://scripts/ui/activity.gd"

const COUNT := 6
const HOLD_BREAKS := 0.35
## Each puri: 0 whole, 1 cracked right, 2 broken.
var puris: Array = [0, 0, 0, 0, 0, 0]
var _down_at := -1.0
var _down_on := -1


func _tick(_dt: float) -> void:
	if t > 9.0:
		_done()


func _spot(i: int) -> Vector2:
	var w := canvas.size.x
	var hgt := canvas.size.y
	var row := i / 3
	var col := i % 3
	return Vector2(w * (0.22 + col * 0.28), hgt * (0.35 + row * 0.38))


func _radius() -> float:
	return minf(canvas.size.x * 0.11, canvas.size.y * 0.16)


func _touch(e) -> void:
	if not (e is InputEventMouseButton):
		return
	if e.pressed:
		_down_on = -1
		for i in COUNT:
			if puris[i] == 0 and e.position.distance_to(_spot(i)) < _radius() * 1.2:
				_down_on = i
				_down_at = t
		return
	if _down_on < 0:
		return
	var held := t - _down_at
	puris[_down_on] = 2 if held > HOLD_BREAKS else 1
	buzz(60 if held > HOLD_BREAKS else 15)
	if held > HOLD_BREAKS:
		set_hint(s.t("act_crack_broke"))
	_down_on = -1
	if not puris.has(0):
		_done()


func _done() -> void:
	finish(float(puris.count(1)) / COUNT)


func _paint(c: Control) -> void:
	for i in COUNT:
		var at := _spot(i)
		var r := _radius()
		var gold := Color("E8C27A") if puris[i] != 2 else Color("C9A25C")
		c.draw_circle(at, r, gold)
		c.draw_arc(at, r, 0, TAU, 32, Look.OUTLINE, 3.0)
		match puris[i]:
			1:
				c.draw_circle(at + Vector2(0, -r * 0.2), r * 0.3, Color("7A4A2A"))
			2:
				c.draw_line(at + Vector2(-r * 0.7, -r * 0.3), at + Vector2(r * 0.1, r * 0.1), Look.OUTLINE, 3.0)
				c.draw_line(at + Vector2(r * 0.1, r * 0.1), at + Vector2(r * 0.6, -r * 0.5), Look.OUTLINE, 3.0)
				c.draw_line(at + Vector2(r * 0.1, r * 0.1), at + Vector2(0, r * 0.8), Look.OUTLINE, 3.0)
