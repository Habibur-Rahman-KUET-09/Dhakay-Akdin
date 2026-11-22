## Stuck in deep water: get down and push, left hand, right hand, left…
## (tap the two sides by turns). The same hand twice hardly moves it.
extends "res://scripts/ui/activity.gd"

## One push with a hand (0 left, 1 right): Day.push; [FREED] once out.
var on_push: Callable
var progress := 0.0
var _last := -1
var _flash := [0.0, 0.0]


func _tick(dt: float) -> void:
	for i in 2:
		_flash[i] = maxf(0.0, float(_flash[i]) - dt * 4.0)


func _touch(e) -> void:
	if e is InputEventMouseButton and e.pressed:
		var hand := 0 if float(e.position.x) < canvas.size.x / 2.0 else 1
		progress = minf(1.0, progress + Rules.push_amount(hand, _last))
		_last = hand
		_flash[hand] = 1.0
		buzz(15)
		var got: Array = on_push.call(hand) if on_push.is_valid() else []
		if not got.is_empty():
			finish(1.0)


func _paint(c: Control) -> void:
	var w := c.size.x
	var hgt := c.size.y
	bar(c, Rect2(16, 8, w - 32, 16), progress, Look.PARROT)
	# Brown water, the rickshaw in it, edging forward.
	var water_y := hgt * 0.55
	c.draw_rect(Rect2(0, water_y, w, hgt - water_y), Color("8D7A52"))
	for i in 6:
		var x := fmod(t * 40.0 + i * 90.0, w)
		c.draw_arc(Vector2(x, water_y + 12), 18.0, PI, TAU, 8, Color(1, 1, 1, 0.35), 2.0)
	var at := Vector2(lerpf(w * 0.25, w * 0.75, progress), water_y - 20)
	c.draw_rect(Rect2(at + Vector2(-50, -60), Vector2(100, 50)), Look.MAGENTA)
	c.draw_arc(at + Vector2(-34, 16), 26.0, 0, TAU, 20, Look.OUTLINE, 4.0)
	c.draw_arc(at + Vector2(34, 16), 26.0, 0, TAU, 20, Look.OUTLINE, 4.0)
	# The two hands to tap.
	for i in 2:
		var pad := Rect2(Vector2(16 + i * (w / 2.0), hgt - 90), Vector2(w / 2.0 - 32, 74))
		var lit: bool = i != _last
		c.draw_rect(pad, Color(1, 1, 1, 0.55 + 0.45 * float(_flash[i])) if lit else Color(1, 1, 1, 0.25))
		c.draw_rect(pad, Look.OUTLINE, false, 2.0)
		text_at(c, pad.get_center(), s.t("hand_left" if i == 0 else "hand_right"), 18)
