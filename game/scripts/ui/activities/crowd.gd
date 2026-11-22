## The crowd at the door: drag the people standing by it further in, one
## by one; each push lets one more waiting outside get on.
extends "res://scripts/ui/activity.gd"

## A push: BusDay.push_in ([] when nobody more can get on).
var on_push: Callable
var waiting := 0
var _people: Array = []
var _held := -1
var _from := Vector2.ZERO
var _in := 0


func _build() -> void:
	for i in 5:
		_people.append(Vector2(0.18 + 0.06 * (i % 2), 0.3 + 0.13 * i))


func _tick(_dt: float) -> void:
	if _in >= waiting:
		finish(1.0)
	elif t > 10.0:
		finish(float(_in) / maxf(1.0, waiting))


func _pos(i: int) -> Vector2:
	var p: Vector2 = _people[i]
	return Vector2(p.x * canvas.size.x, p.y * canvas.size.y)


func _touch(e) -> void:
	if e is InputEventMouseButton:
		if e.pressed:
			for i in _people.size():
				if e.position.distance_to(_pos(i)) < 40.0:
					_held = i
					_from = e.position
					return
		elif _held >= 0:
			var moved: float = float(e.position.x) - _from.x
			if moved > canvas.size.x * 0.25:
				var got: Array = on_push.call() if on_push.is_valid() else []
				if not got.is_empty():
					_in += 1
					buzz(25)
					var p: Vector2 = _people[_held]
					_people[_held] = Vector2(minf(0.85, p.x + 0.45), p.y)
				else:
					_in = waiting
			_held = -1
	elif e is InputEventMouseMotion and _held >= 0:
		var p: Vector2 = _people[_held]
		_people[_held] = Vector2(clampf(float(e.position.x) / canvas.size.x, 0.1, 0.9), p.y)


func _paint(c: Control) -> void:
	var w := c.size.x
	var hgt := c.size.y
	text_at(c, Vector2(w * 0.5, 14), s.t("crowdLeft", {"n": maxi(0, waiting - _in)}), 16)
	c.draw_rect(Rect2(0, 30, w * 0.12, hgt - 40), Color("2D6FB6"))
	text_at(c, Vector2(w * 0.06, hgt * 0.5), s.t("doorWord"), 14, Color.WHITE)
	for i in _people.size():
		var p := _pos(i)
		c.draw_circle(p + Vector2(0, -26), 13.0, Color("C68B59"))
		c.draw_line(p + Vector2(0, -12), p + Vector2(0, 26), Color("6A6A8A") if i != _held else Look.MAGENTA, 16.0)
