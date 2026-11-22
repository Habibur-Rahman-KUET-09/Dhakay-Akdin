## Hanging at the door: the bus sways; keep Babu upright (tilt the phone
## against the lean, or drag sideways), and while steady grab the one
## slipping out and pull him in (drag him inwards).
extends "res://scripts/ui/activity.gd"

var lean := 0.0
var caught := false
var _correct := 0.0
var _drag_x := INF
var _grab := false
var _grab_from := Vector2.ZERO
var _man := Vector2.ZERO


func _tick(dt: float) -> void:
	var sway := sin(t * 1.7) * 0.8 + sin(t * 3.3 + 1.0) * 0.4
	var tilt := clampf(-Input.get_accelerometer().x / 5.0, -1.0, 1.0) + _correct
	lean = clampf(lean + (sway - tilt * 1.5) * dt * 1.1, -1.0, 1.0)
	if not caught and t > 6.0:
		finish(0.0)


func _man_at() -> Vector2:
	return Vector2(canvas.size.x * 0.28, canvas.size.y * 0.55)


func _touch(e) -> void:
	if caught:
		return
	if e is InputEventMouseButton:
		if e.pressed:
			if e.position.distance_to(_man_at()) < 60.0:
				_grab = true
				_grab_from = e.position
			else:
				_drag_x = e.position.x
		else:
			_grab = false
			_drag_x = INF
			_correct = 0.0
	elif e is InputEventMouseMotion:
		if _grab:
			_man = e.position - _grab_from
			# Pulled inwards (right, into the bus) while steady: caught.
			if _man.x > 80.0 and Rules.steady(lean):
				caught = true
				buzz(60)
				finish(1.0)
			elif not Rules.steady(lean):
				_grab = false
				_man = Vector2.ZERO
				buzz(40)
		elif _drag_x != INF:
			_correct = clampf((float(e.position.x) - _drag_x) / 120.0, -1.0, 1.0)


func _paint(c: Control) -> void:
	var w := c.size.x
	var hgt := c.size.y
	var steady := Rules.steady(lean)
	text_at(c, Vector2(w * 0.5, 14), s.t("doorSteady" if steady else "doorHold"), 17, Look.PARROT if steady else Look.VERMILION)
	# The door frame, and the lean meter.
	c.draw_rect(Rect2(w * 0.12, 40, w * 0.36, hgt - 60), Color("2D6FB6"), false, 6.0)
	bar(c, Rect2(w * 0.55, 40, w * 0.4, 14), (lean + 1.0) / 2.0, Look.PARROT if steady else Look.VERMILION, [0.325, 0.675])
	# Babu hanging from the rail, leaning.
	var hand := Vector2(w * 0.7, 80)
	var body := hand + Vector2(0, 120).rotated(lean * 0.6)
	c.draw_line(hand, body, Look.SKY.darkened(0.2), 14.0)
	c.draw_circle(hand + Vector2(0, 18).rotated(lean * 0.6), 18.0, Color("D9A066"))
	c.draw_line(Vector2(w * 0.55, 70), Vector2(w * 0.85, 70), Look.OUTLINE, 5.0)
	# The one slipping out by the door.
	var man := _man_at() + _man
	c.draw_circle(man + Vector2(0, -50), 16.0, Color("C68B59"))
	c.draw_line(man + Vector2(0, -34), man + Vector2(0, 30), Color("8B4A2B"), 14.0)
