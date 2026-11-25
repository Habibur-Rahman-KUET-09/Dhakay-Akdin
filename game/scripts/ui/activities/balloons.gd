## Balloons on a packed bus: umbrella tips and elbows keep coming at
## them from both sides. Tap each one to push it back before it touches a
## balloon. The score is the share of balloons still whole after a while.
extends "res://scripts/ui/activity.gd"

const BALLOONS := 4
const SECONDS := 12.0
const COLOURS := [Color("E2432A"), Color("F6B800"), Color("2E9E6B"), Color("2D8BD6")]

## Whole or popped, by balloon; the sharp things coming: {pos, dir, kind}.
var whole: Array = []
var _threats: Array = []
var _next := 0.8
var _pops: Array = []


func _build() -> void:
	for i in BALLOONS:
		whole.append(true)


func _balloon(i: int) -> Vector2:
	var w := canvas.size.x
	return Vector2(w * (0.2 + 0.2 * i), canvas.size.y * (0.32 + 0.08 * (i % 2)) + sin(t * 2.0 + i) * 6.0)


func left() -> int:
	return whole.count(true)


func _tick(dt: float) -> void:
	_next -= dt
	if _next <= 0.0:
		_next = randf_range(0.6, 1.1)
		var from_left := randf() < 0.5
		var y := canvas.size.y * randf_range(0.2, 0.5)
		_threats.append({"pos": Vector2(-20.0 if from_left else canvas.size.x + 20.0, y),
			"dir": 1.0 if from_left else -1.0, "kind": randi() % 2, "speed": randf_range(80.0, 130.0)})
	for th in _threats.duplicate():
		th.pos = th.pos + Vector2(float(th.dir) * float(th.speed) * dt, 0.0)
		for i in BALLOONS:
			if whole[i] and th.pos.distance_to(_balloon(i)) < 34.0:
				whole[i] = false
				_pops.append({"at": _balloon(i), "k": 1.0})
				_threats.erase(th)
				buzz(80)
				break
		if th.pos.x < -60.0 or th.pos.x > canvas.size.x + 60.0:
			_threats.erase(th)
	for p in _pops:
		p.k = maxf(0.0, float(p.k) - dt * 2.0)
	if left() == 0 or t >= SECONDS:
		finish(float(left()) / BALLOONS)


func _touch(e) -> void:
	if e is InputEventMouseButton and e.pressed:
		for th in _threats:
			if th.pos.distance_to(e.position) < 44.0:
				_threats.erase(th)
				buzz(15)
				return


func _paint(c: Control) -> void:
	var w := c.size.x
	var hgt := c.size.y
	bar(c, Rect2(16, 6, w - 32, 12), 1.0 - t / SECONDS, Look.SKY)
	var hand := Vector2(w * 0.5, hgt - 16)
	for i in BALLOONS:
		var at := _balloon(i)
		if not whole[i]:
			continue
		c.draw_line(at + Vector2(0, 28), hand, Color("6D6A64"), 1.5)
		c.draw_circle(at, 26.0, COLOURS[i])
		c.draw_circle(at + Vector2(-8, -9), 6.0, Color(1, 1, 1, 0.5))
		c.draw_arc(at, 26.0, 0, TAU, 28, Look.OUTLINE, 2.0)
	for p in _pops:
		if float(p.k) > 0.0:
			text_at(c, p.at, s.t("balloonPop"), 18, Color(Look.VERMILION, float(p.k)))
	for th in _threats:
		var at: Vector2 = th.pos
		if int(th.kind) == 0:
			# An umbrella tip.
			var d := float(th.dir)
			c.draw_line(at - Vector2(70 * d, 0), at, Color("37474F"), 6.0)
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(10 * d, 0), at + Vector2(-6 * d, -7), at + Vector2(-6 * d, 7)]), Color("9AA3A8"))
		else:
			# An elbow.
			c.draw_circle(at, 16.0, Color("C68A5E"))
			c.draw_arc(at, 16.0, 0, TAU, 20, Look.OUTLINE, 2.0)
	c.draw_circle(hand, 12.0, Color("C68A5E"))
	text_at(c, Vector2(w * 0.5, hgt * 0.72), s.t("balloonCount", {"n": left(), "of": BALLOONS}), 16, Look.MAGENTA)
