## The clay stove while the kettle fills: swipe to and fro to fan it and
## it fills sooner. (Blowing into the microphone was taken out: the
## microphone on Android was a suspect in a crash.)
extends "res://scripts/ui/activity.gd"

## Fans the fire: seconds sooner (TeaDay.fan); and how full the kettle is
## (0–1).
var on_fan: Callable
var filled: Callable
var fan_s := 0.35
var _last_x := INF
var _dir := 0
var _travel := 0.0
var _glow := 0.0


func _build() -> void:
	slow = false


func _tick(dt: float) -> void:
	_glow = maxf(0.0, _glow - dt * 1.5)
	if filled.is_valid() and float(filled.call()) >= 1.0:
		finish(1.0)
	elif t > 15.0:
		finish(0.5)


func _touch(e) -> void:
	if e is InputEventMouseButton:
		_last_x = e.position.x if e.pressed else INF
		_dir = 0
		_travel = 0.0
	elif e is InputEventMouseMotion and _last_x != INF:
		var dx: float = e.position.x - _last_x
		_last_x = e.position.x
		var d := signi(int(dx))
		if d != 0 and d != _dir:
			if _travel > 40.0:
				# A sweep one way, then back: one fan.
				on_fan.call(fan_s)
				_glow = 1.0
				buzz(10)
			_dir = d
			_travel = 0.0
		_travel += absf(dx)


func _paint(c: Control) -> void:
	var w := c.size.x
	var hgt := c.size.y
	var full := float(filled.call()) if filled.is_valid() else 0.0
	bar(c, Rect2(16, 8, w - 32, 16), full, Look.SKY)
	text_at(c, Vector2(w * 0.5, 44), s.t("kettleFilling"), 16)
	var base := Vector2(w * 0.5, hgt - 40)
	# The clay stove, its mouth glowing as it is fanned.
	c.draw_rect(Rect2(base + Vector2(-90, -90), Vector2(180, 90)), Color("A0522D"))
	c.draw_rect(Rect2(base + Vector2(-90, -90), Vector2(180, 90)), Look.OUTLINE, false, 2.5)
	var fire := Color("FF9A3C").lerp(Color("FFE066"), _glow)
	c.draw_circle(base + Vector2(0, -40), 26.0 + 10.0 * _glow, fire)
	for i in 3:
		var x := -30.0 + i * 30.0
		c.draw_colored_polygon(PackedVector2Array([base + Vector2(x - 10, -90), base + Vector2(x + 10, -90),
			base + Vector2(x, -120 - 30 * _glow - 8 * sin(t * 9.0 + i))]), fire)
	# The kettle on top.
	c.draw_circle(base + Vector2(0, -150), 44.0, Color("9AA3A8"))
	c.draw_arc(base + Vector2(0, -150), 44.0, 0, TAU, 32, Look.OUTLINE, 2.5)
	c.draw_line(base + Vector2(40, -160), base + Vector2(80, -180), Color("9AA3A8"), 8.0)
	# The hand fan, swinging.
	var fan_at := base + Vector2(130 * sin(t * 2.0 * (0.3 + _glow)), -70)
	c.draw_colored_polygon(PackedVector2Array([fan_at, fan_at + Vector2(-30, -50), fan_at + Vector2(30, -50)]), Color("E0C068"))
