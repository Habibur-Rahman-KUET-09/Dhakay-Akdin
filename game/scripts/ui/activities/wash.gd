## Washing up at the stall: the dirty cups stand in the basin. Scrub each
## one round and round with a finger until it shines (activities.gd
## WASH_TURNS turns), and it goes back on the rack. "Done" when enough are
## clean; all of them and it closes by itself.
extends "res://scripts/ui/activity.gd"

## Dirty cups to wash here (the scene gives at most six at a time).
var dirty := 4
## Read by the scene after `done`.
var washed := 0
var _dirt: Array = []
var _scrubbing := -1
var _last_angle := INF
var _shine: Array = []


func _build() -> void:
	for i in dirty:
		_dirt.append(1.0)
		_shine.append(0.0)
	add_button("doneButton", Look.PARROT, _end)


func _tick(dt: float) -> void:
	for i in _shine.size():
		_shine[i] = maxf(0.0, float(_shine[i]) - dt * 1.5)
	if t > 16.0:
		_end()


func _cup_at(i: int) -> Vector2:
	var across := mini(dirty, 3)
	var row := floori(i / 3.0)
	var col := i % 3
	var w := canvas.size.x
	return Vector2(w * (col + 0.5) / across, canvas.size.y * (0.36 + 0.36 * row))


func _touch(e) -> void:
	if e is InputEventMouseButton:
		_scrubbing = -1
		_last_angle = INF
		if e.pressed:
			for i in dirty:
				if float(_dirt[i]) > 0.0 and e.position.distance_to(_cup_at(i)) < 56.0:
					_scrubbing = i
	elif e is InputEventMouseMotion and _scrubbing >= 0:
		var at := _cup_at(_scrubbing)
		var a: float = (e.position - at).angle()
		if _last_angle != INF:
			var turn := absf(wrapf(a - _last_angle, -PI, PI)) / TAU
			_dirt[_scrubbing] = maxf(0.0, float(_dirt[_scrubbing]) - turn / Rules.WASH_TURNS)
			if float(_dirt[_scrubbing]) <= 0.0:
				washed += 1
				_shine[_scrubbing] = 1.0
				buzz(30)
				_scrubbing = -1
				if washed >= dirty:
					_end()
					return
		_last_angle = a


func _end() -> void:
	finish(Rules.wash_score(washed, dirty))


func _paint(c: Control) -> void:
	var w := c.size.x
	text_at(c, Vector2(w * 0.5, 14), s.t("washCount", {"n": washed, "of": dirty}), 16, Look.MAGENTA)
	# The basin of water.
	c.draw_rect(Rect2(10, 32, w - 20, c.size.y - 40), Color(0.55, 0.75, 0.9, 0.35))
	c.draw_rect(Rect2(10, 32, w - 20, c.size.y - 40), Look.OUTLINE, false, 2.0)
	for i in dirty:
		var at := _cup_at(i)
		var dirt := float(_dirt[i])
		# A glass cup, its stain fading as it is scrubbed.
		var cup := Rect2(at + Vector2(-26, -30), Vector2(52, 60))
		c.draw_rect(cup, Color(1, 1, 1, 0.85))
		c.draw_rect(Rect2(cup.position + Vector2(0, cup.size.y * 0.35), Vector2(cup.size.x, cup.size.y * 0.65)), Color(0.55, 0.35, 0.15, 0.75 * dirt))
		c.draw_rect(cup, Look.OUTLINE, false, 2.5)
		if dirt > 0.0:
			c.draw_arc(at, 44.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - dirt), 24, Look.PARROT, 4.0)
		else:
			text_at(c, at + Vector2(0, 44), s.t("washClean"), 13, Look.PARROT_DARK)
		if float(_shine[i]) > 0.0:
			var k := float(_shine[i])
			for j in 4:
				var a := j * PI * 0.5 + t
				c.draw_line(at + Vector2.RIGHT.rotated(a) * 34.0, at + Vector2.RIGHT.rotated(a) * (34.0 + 16.0 * k), Color(1, 0.95, 0.5, k), 3.0)
		# Bubbles round the one being scrubbed.
		if i == _scrubbing:
			for j in 5:
				var a := t * 4.0 + j * TAU / 5.0
				c.draw_arc(at + Vector2.RIGHT.rotated(a) * 30.0, 6.0, 0, TAU, 10, Color(1, 1, 1, 0.9), 2.0)
