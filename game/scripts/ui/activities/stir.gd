## Sugar and stirring: tap the jar for each spoon the customer asked for,
## then stir round the cup with a finger, three turns or so; "done".
extends "res://scripts/ui/activity.gd"

var spoons_wanted := 2
var spoons := 0
var turns := 0.0
var _last_angle := INF
var _drag := false
var _clink := 0.0


func _build() -> void:
	add_button("doneButton", Look.PARROT, _end)


func _tick(dt: float) -> void:
	_clink = maxf(0.0, _clink - dt * 3.0)
	if t > 12.0:
		_end()


func _jar() -> Rect2:
	return Rect2(18, canvas.size.y * 0.35, 90, 110)


func _centre() -> Vector2:
	return Vector2(canvas.size.x * 0.62, canvas.size.y * 0.55)


func _touch(e) -> void:
	if e is InputEventMouseButton:
		if e.pressed and _jar().has_point(e.position):
			spoons = mini(spoons + 1, 5)
			buzz(15)
			return
		_drag = e.pressed and e.position.distance_to(_centre()) < 140.0
		_last_angle = INF
	elif e is InputEventMouseMotion and _drag:
		var a: float = (e.position - _centre()).angle()
		if _last_angle != INF:
			var d := wrapf(a - _last_angle, -PI, PI)
			var before := floori(turns)
			turns += absf(d) / TAU
			if floori(turns) > before:
				buzz(10)
				_clink = 1.0
		_last_angle = a


func _end() -> void:
	finish(Rules.sugar_score(spoons, spoons_wanted, turns))


func _paint(c: Control) -> void:
	var w := c.size.x
	text_at(c, Vector2(w * 0.5, 16), s.t("sugarWish_%d" % clampi(spoons_wanted, 1, 3)), 18, Look.MAGENTA)
	text_at(c, Vector2(w * 0.5, 44), s.t("sugarCount", {"n": spoons, "turns": floori(turns)}), 15)
	var jar := _jar()
	c.draw_rect(jar, Color("F6F1E4"))
	c.draw_rect(Rect2(jar.position + Vector2(0, jar.size.y * 0.4), Vector2(jar.size.x, jar.size.y * 0.6)), Color.WHITE)
	c.draw_rect(jar, Look.OUTLINE, false, 2.5)
	text_at(c, jar.get_center() + Vector2(0, -jar.size.y * 0.25), s.t("sugarJar"), 15)
	var at := _centre()
	c.draw_circle(at, 70.0, Color("C98B4E"))
	c.draw_arc(at, 70.0, 0, TAU, 40, Look.OUTLINE, 3.0)
	# The swirl, turning as it is stirred.
	for k in 3:
		var a0 := turns * TAU + k * TAU / 3.0
		c.draw_arc(at, 24.0 + k * 14.0, a0, a0 + 2.0, 12, Color("F3E3C3"), 3.0)
	var spoon := at + Vector2.RIGHT.rotated(turns * TAU) * 40.0
	c.draw_line(spoon, spoon + Vector2(30, -70), Color("9A9A9A"), 6.0)
	if _clink > 0.0:
		c.draw_arc(at, 80.0 + 10.0 * (1.0 - _clink), 0, TAU, 40, Color(1, 1, 1, _clink), 2.0)
