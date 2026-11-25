## Pouring the tamarind water: hold the jug down and the sour rises in the
## plate, measure by measure (0–4); let go at the level wanted, "Done".
## Those waiting and how sour each wants it are shown as marks.
extends "res://scripts/ui/activity.gd"

const RATE := 1.1
const TOP := 4.0
var level := 0.0
## How sour those waiting want it (marks beside the gauge).
var wants: Array = []
var _pouring := false


func _build() -> void:
	add_button("act_tamarind_done", Look.PARROT, _stop)


func _tick(dt: float) -> void:
	if _pouring:
		var before := int(level)
		level = minf(TOP, level + RATE * dt)
		if int(level) != before:
			buzz(12)
	if t > 12.0:
		_stop()


func _stop() -> void:
	finish(clampf(level / TOP, 0.0, 1.0))


func _touch(e) -> void:
	if e is InputEventMouseButton:
		_pouring = e.pressed


func _paint(c: Control) -> void:
	var w := c.size.x
	var hgt := c.size.y
	var gauge := Rect2(w * 0.62, 16, 44, hgt - 40)
	c.draw_rect(gauge, Color("F4F1E8"))
	var fill := gauge.size.y * level / TOP
	c.draw_rect(Rect2(gauge.position.x, gauge.end.y - fill, gauge.size.x, fill), Color("7A4A2A"))
	c.draw_rect(gauge, Look.OUTLINE, false, 3.0)
	for n in range(0, int(TOP) + 1):
		var y := gauge.end.y - gauge.size.y * n / TOP
		c.draw_line(Vector2(gauge.position.x - 8, y), Vector2(gauge.position.x, y), Look.OUTLINE, 2.0)
		text_at(c, Vector2(gauge.position.x - 22, y + 6), str(n), 15)
	# Who wants how sour: a little flag at their level.
	for i in wants.size():
		var y := gauge.end.y - gauge.size.y * float(wants[i]) / TOP
		c.draw_rect(Rect2(gauge.end.x + 6 + i * 16, y - 6, 12, 12), Look.MAGENTA)
	text_at(c, Vector2(w * 0.3, 40), s.t("act_tamarind_level", {"n": int(level)}), 20)
	# The jug, tipped while pouring.
	var jug := Vector2(w * 0.28, hgt * 0.55)
	var tip := 0.6 if _pouring else 0.0
	var a := jug + Vector2(-30, -40).rotated(tip)
	var b2 := jug + Vector2(30, -40).rotated(tip)
	var c2 := jug + Vector2(36, 40).rotated(tip)
	var d := jug + Vector2(-36, 40).rotated(tip)
	c.draw_colored_polygon(PackedVector2Array([a, b2, c2, d]), Color("7A4A2A"))
	c.draw_polyline(PackedVector2Array([a, b2, c2, d, a]), Look.OUTLINE, 3.0)
	if _pouring:
		c.draw_line(b2, Vector2(gauge.position.x + 10, gauge.end.y - fill), Color("9C6B3C"), 5.0)
