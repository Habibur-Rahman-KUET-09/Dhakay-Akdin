## Rain on the passenger: pull the hood up (it sticks halfway, so let go
## and pull again), then draw the plastic sheet down over their legs. Done
## within about three seconds is best; slower, they get wet.
extends "res://scripts/ui/activity.gd"

## 0 down, 1 up; it stops at STICK until the finger lets go once.
var hood := 0.0
var sheet := 0.0
var _drag := false
var _stuck_once := false
var _released_after_stick := false
const STICK := 0.5


func _tick(_dt: float) -> void:
	if t > 10.0:
		finish(0.0)


func _touch(e) -> void:
	if e is InputEventMouseButton:
		_drag = e.pressed
		if not e.pressed and _stuck_once:
			_released_after_stick = true
	elif e is InputEventMouseMotion and _drag:
		var dy := float(e.relative.y) / maxf(1.0, canvas.size.y * 0.6)
		if hood < 1.0:
			# Up the screen raises the hood.
			var limit := 1.0 if _released_after_stick else STICK
			hood = clampf(hood - dy, 0.0, limit)
			if hood >= STICK and not _stuck_once:
				_stuck_once = true
				buzz(40)
				set_hint(s.t("act_hood_stuck"))
			if hood >= 1.0:
				buzz(20)
				set_hint(s.t("act_hood_sheet"))
		else:
			# Then down the screen draws the sheet over the legs.
			sheet = clampf(sheet + dy, 0.0, 1.0)
			if sheet >= 0.95:
				finish(Rules.hood_score(t))


func _paint(c: Control) -> void:
	var w := c.size.x
	var hgt := c.size.y
	# Rain.
	for i in 24:
		var x := fmod(i * 53.0 + t * 30.0, w)
		var y := fmod(i * 37.0 + t * 420.0, hgt)
		c.draw_line(Vector2(x, y), Vector2(x - 4, y + 14), Color(0.4, 0.6, 0.9, 0.6), 2.0)
	# The seat and the passenger's legs.
	var seat := Vector2(w * 0.5, hgt * 0.62)
	c.draw_rect(Rect2(seat + Vector2(-90, -10), Vector2(180, 24)), Look.MAGENTA)
	c.draw_rect(Rect2(seat + Vector2(-40, -70), Vector2(80, 62)), Color("6D6A64"))
	c.draw_circle(seat + Vector2(0, -92), 22.0, Color("C68A5E"))
	c.draw_rect(Rect2(seat + Vector2(-34, 14), Vector2(26, 70)), Color("37474F"))
	c.draw_rect(Rect2(seat + Vector2(8, 14), Vector2(26, 70)), Color("37474F"))
	# The hood: an arc over the seat, from folded back to right over.
	var hinge := seat + Vector2(60, -20)
	var reach := lerpf(0.15, 1.0, hood)
	var pts := PackedVector2Array()
	for i in 13:
		var a := lerpf(0.0, PI * 0.75 * reach, i / 12.0)
		pts.append(hinge + Vector2(-cos(a), -sin(a)) * 130.0)
	c.draw_polyline(pts, Look.YELLOW, 18.0)
	c.draw_polyline(pts, Look.OUTLINE, 3.0)
	# The plastic sheet, drawn down over the legs.
	if hood >= 1.0:
		var sh := Rect2(seat + Vector2(-60, 0), Vector2(120, 90 * sheet))
		c.draw_rect(sh, Color(0.85, 0.9, 1.0, 0.75))
		c.draw_rect(sh, Look.OUTLINE, false, 2.0)
	# Where to pull.
	var at := Vector2(w * 0.85, hgt * 0.5)
	var dir := -1.0 if hood < 1.0 else 1.0
	var bob := sin(t * 6.0) * 6.0 * dir
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, 30 * dir + bob), at + Vector2(-18, bob), at + Vector2(18, bob)]), Look.MAGENTA)
	c.draw_rect(Rect2(at + Vector2(-6, (0.0 if dir < 0.0 else -40.0) + bob), Vector2(12, 40)), Look.MAGENTA)
