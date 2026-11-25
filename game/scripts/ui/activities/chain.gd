## The chain has come off the gear, in the middle of the road, and the
## cars behind are hooting. Take hold of the loose chain, lift it onto the
## teeth at the top of the big gear, then turn the pedal once round to
## seat it. Quick is best (activities.gd chain_score).
extends "res://scripts/ui/activity.gd"

## 0: hanging loose; 1: on the top teeth, turn the pedal; 2: done.
var stage := 0
var turns := 0.0
var _drag := false
## Where the finger holds the loose chain (stage 0).
var _hold := Vector2.INF
var _last_angle := INF
var _horn := 0.0
var _next_horn := 1.2


func _build() -> void:
	set_hint(s.t("act_chain_hint"))


func _gear() -> Vector2:
	return Vector2(canvas.size.x * 0.36, canvas.size.y * 0.5)


func _cog() -> Vector2:
	return Vector2(canvas.size.x * 0.8, canvas.size.y * 0.5)


const GEAR_R := 58.0
const COG_R := 22.0


## The lowest point of the hanging chain, where it is taken hold of.
func _sag() -> Vector2:
	return _gear() + Vector2(30, GEAR_R + 70)


func _top() -> Vector2:
	return _gear() + Vector2(0, -GEAR_R)


func _tick(dt: float) -> void:
	_horn = maxf(0.0, _horn - dt * 2.0)
	_next_horn -= dt
	if _next_horn <= 0.0 and stage < 2:
		_next_horn = randf_range(0.8, 1.8)
		_horn = 1.0
		buzz(20)
	if t > 15.0:
		finish(0.0)


func _touch(e) -> void:
	if e is InputEventMouseButton:
		if not e.pressed:
			if stage == 0 and _hold != Vector2.INF and _hold.distance_to(_top()) < 34.0:
				stage = 1
				buzz(40)
				set_hint(s.t("act_chain_turn"))
			_drag = false
			_hold = Vector2.INF
			_last_angle = INF
			return
		if stage == 0 and e.position.distance_to(_sag()) < 50.0:
			_drag = true
			_hold = e.position
		elif stage == 1 and e.position.distance_to(_gear()) < GEAR_R + 70.0:
			_drag = true
			_last_angle = INF
	elif e is InputEventMouseMotion and _drag:
		if stage == 0:
			_hold = e.position
			# Close enough to the top teeth: it catches by itself.
			if _hold.distance_to(_top()) < 18.0:
				stage = 1
				_drag = false
				_hold = Vector2.INF
				buzz(40)
				set_hint(s.t("act_chain_turn"))
		elif stage == 1:
			var a: float = (e.position - _gear()).angle()
			if _last_angle != INF:
				turns += absf(wrapf(a - _last_angle, -PI, PI)) / TAU
				if turns >= 1.0:
					stage = 2
					buzz(60)
					finish(Rules.chain_score(t))
			_last_angle = a


func _paint(c: Control) -> void:
	var w := c.size.x
	var g := _gear()
	var k := _cog()
	var spin := turns * TAU
	# The rear wheel's cog and the big gear, with teeth.
	for pair in [[g, GEAR_R, 18], [k, COG_R, 8]]:
		var at: Vector2 = pair[0]
		var r: float = pair[1]
		var n: int = pair[2]
		for i in n:
			var a := spin + i * TAU / n
			c.draw_line(at + Vector2.RIGHT.rotated(a) * (r - 4), at + Vector2.RIGHT.rotated(a) * (r + 7), Color("6F757A"), 6.0)
		c.draw_circle(at, r, Color("9AA3A8"))
		c.draw_arc(at, r, 0, TAU, 40, Look.OUTLINE, 3.0)
		c.draw_circle(at, r * 0.3, Color("4A5055"))
	# The chain: round both once seated, else over the cog and hanging loose.
	var chain := Color("3B3B3B")
	if stage >= 1:
		var top_from := g + Vector2(0, -GEAR_R)
		c.draw_line(top_from, k + Vector2(0, -COG_R), chain, 5.0)
		if stage == 2:
			c.draw_line(g + Vector2(0, GEAR_R), k + Vector2(0, COG_R), chain, 5.0)
		else:
			_draw_sag(c, k + Vector2(0, COG_R), g + Vector2(GEAR_R * 0.7, GEAR_R * 0.7), chain)
	else:
		var end := _hold if _hold != Vector2.INF else _sag()
		_draw_sag(c, k + Vector2(0, -COG_R), end, chain)
		_draw_sag(c, k + Vector2(0, COG_R), end, chain)
		# Where to take hold, and where it goes.
		var bob := sin(t * 6.0) * 4.0
		c.draw_arc(_sag(), 26.0 + bob, 0, TAU, 24, Look.MAGENTA, 3.0)
		c.draw_arc(_top(), 20.0, 0, TAU, 24, Color(Look.PARROT, 0.6 + 0.4 * sin(t * 5.0)), 3.0)
	# The crank and pedal on the big gear.
	# It starts pointing down and back, clear of the top teeth.
	var crank := g + Vector2.RIGHT.rotated(spin + PI * 0.75) * (GEAR_R + 40)
	c.draw_line(g, crank, Look.OUTLINE, 8.0)
	c.draw_rect(Rect2(crank - Vector2(18, 6), Vector2(36, 12)), Look.MAGENTA)
	if stage == 1:
		c.draw_arc(g, GEAR_R + 52, PI * 0.75, PI * 0.75 + TAU * turns, 40, Look.PARROT, 5.0)
	# The cars behind.
	if _horn > 0.0:
		text_at(c, Vector2(w * 0.82, 24 + 8 * (1.0 - _horn)), s.t("hornSound"), 18, Color(Look.VERMILION, _horn))


func _draw_sag(c: Control, a: Vector2, b: Vector2, colour: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var f := i / 12.0
		pts.append(a.lerp(b, f) + Vector2(0, sin(f * PI) * 26.0))
	c.draw_polyline(pts, colour, 5.0)
