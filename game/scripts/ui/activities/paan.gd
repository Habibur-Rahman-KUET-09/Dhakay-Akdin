## Folding a paan: drag areca and lime (and zarda, if they want it) from
## the bowls onto the leaf, then swipe across the leaf to fold it shut.
extends "res://scripts/ui/activity.gd"

const THINGS := ["areca", "lime", "zarda"]
const COLOURS := {"areca": Color("8B5A2B"), "lime": Color("F4F4EE"), "zarda": Color("3B2A1E")}

var wants_zarda := false
var on_leaf: Array = []
var folded := false
var _carry := ""
var _carry_at := Vector2.ZERO
var _fold_from := INF
var _done_in := -1.0


func _tick(dt: float) -> void:
	if _done_in > 0.0:
		_done_in -= dt
		if _done_in <= 0.0:
			finish(Rules.paan_score(on_leaf, wants_zarda, folded))
	elif t > 14.0:
		finish(Rules.paan_score(on_leaf, wants_zarda, folded))


func _leaf() -> Vector2:
	return Vector2(canvas.size.x * 0.5, canvas.size.y * 0.42)


func _bowl(i: int) -> Vector2:
	return Vector2(canvas.size.x * (0.2 + 0.3 * i), canvas.size.y - 50)


func _touch(e) -> void:
	if folded:
		return
	if e is InputEventMouseButton:
		if e.pressed:
			for i in THINGS.size():
				if e.position.distance_to(_bowl(i)) < 44.0:
					_carry = THINGS[i]
					_carry_at = e.position
					return
			if e.position.distance_to(_leaf()) < 110.0:
				_fold_from = e.position.x
		else:
			if _carry != "" and e.position.distance_to(_leaf()) < 110.0 and not on_leaf.has(_carry):
				on_leaf.append(_carry)
				buzz(15)
			elif _fold_from != INF and absf(e.position.x - _fold_from) > 90.0 and not on_leaf.is_empty():
				folded = true
				buzz(40)
				_done_in = 0.5
			_carry = ""
			_fold_from = INF
	elif e is InputEventMouseMotion and _carry != "":
		_carry_at = e.position


func _paint(c: Control) -> void:
	var w := c.size.x
	text_at(c, Vector2(w * 0.5, 14), s.t("paanWithZarda" if wants_zarda else "paanNoZarda"), 18, Look.MAGENTA)
	var at := _leaf()
	var leaf := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var r := 1.0 - 0.25 * absf(sin(a / 2.0))
		leaf.append(at + Vector2(cos(a) * 110.0 * r, sin(a) * 80.0))
	if folded:
		c.draw_colored_polygon(PackedVector2Array([at + Vector2(-60, 40), at + Vector2(60, 40), at + Vector2(0, -50)]), Color("3E7D32"))
		text_at(c, at + Vector2(0, 70), s.t("paanFolded"), 16, Look.PARROT.darkened(0.2))
	else:
		c.draw_colored_polygon(leaf, Color("4E9A3A"))
		c.draw_line(at + Vector2(-100, 0), at + Vector2(100, 0), Color("2F6B24"), 2.0)
		for i in on_leaf.size():
			var thing: String = on_leaf[i]
			for k in 5:
				c.draw_circle(at + Vector2(-30 + i * 30 + (k % 2) * 8, -12 + k * 6), 6.0, COLOURS[thing])
	for i in THINGS.size():
		var b := _bowl(i)
		c.draw_circle(b, 38.0, Color("D7C3A0"))
		c.draw_circle(b, 26.0, COLOURS[THINGS[i]])
		c.draw_arc(b, 38.0, 0, TAU, 24, Look.OUTLINE, 2.0)
		text_at(c, b + Vector2(0, -50), s.t("paan_" + THINGS[i]), 14)
	if _carry != "":
		c.draw_circle(_carry_at, 14.0, COLOURS[_carry])
