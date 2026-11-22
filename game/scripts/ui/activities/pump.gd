## Pumping a soft tyre: drag the pump handle down, up, down… Each full
## push puts air in; the needle must stop in the green. "Stop" when it is.
## Past the green, the tube bursts.
extends "res://scripts/ui/activity.gd"

const MAX := 1.3
var pressure := 0.25
var _handle := 0.0
var _was_up := true
var _drag := false
var _from_y := 0.0


func _build() -> void:
	add_button("stopPump", Look.PARROT, _stop)


func _tick(dt: float) -> void:
	# A slow hiss: it loses a little all the time.
	pressure = maxf(0.0, pressure - 0.025 * dt)
	if t > 14.0:
		_stop()


func _stop() -> void:
	finish(1.0 if Rules.pump_result(pressure) == "ok" else 0.0)


func _touch(e) -> void:
	if e is InputEventMouseButton:
		_drag = e.pressed
		_from_y = e.position.y
	elif e is InputEventMouseMotion and _drag:
		_handle = clampf(_handle + float(e.relative.y) / maxf(1.0, canvas.size.y * 0.5), 0.0, 1.0)
		if _handle < 0.15:
			_was_up = true
		elif _handle > 0.9 and _was_up:
			_was_up = false
			pressure += 0.09
			buzz(15)
			if Rules.pump_result(pressure) == "burst":
				buzz(150)
				finish(0.0)


func _paint(c: Control) -> void:
	var w := c.size.x
	var hgt := c.size.y
	var gauge := Rect2(16, 8, w - 32, 20)
	bar(c, gauge, pressure / MAX, Look.SKY if Rules.pump_result(pressure) != "burst" else Look.VERMILION,
		[Rules.PUMP_GREEN[0] / MAX, Rules.PUMP_GREEN[1] / MAX])
	c.draw_rect(Rect2(gauge.position.x + gauge.size.x * Rules.PUMP_GREEN[0] / MAX, gauge.end.y + 2,
		gauge.size.x * (Rules.PUMP_GREEN[1] - Rules.PUMP_GREEN[0]) / MAX, 6), Look.PARROT)
	text_at(c, Vector2(w * 0.5, 50), s.t("pumpState_" + Rules.pump_result(pressure)), 16)
	# The pump: a barrel, and the handle on its rod.
	var base := Vector2(w * 0.5, hgt - 20)
	c.draw_rect(Rect2(base + Vector2(-22, -170), Vector2(44, 170)), Color("2F5D8A"))
	c.draw_rect(Rect2(base + Vector2(-60, -6), Vector2(120, 10)), Color("2F5D8A"))
	var top_y := lerpf(-250.0, -180.0, _handle)
	c.draw_line(base + Vector2(0, -170), base + Vector2(0, top_y), Color("9AA3A8"), 8.0)
	c.draw_rect(Rect2(base + Vector2(-70, top_y - 12), Vector2(140, 22)), Look.OUTLINE)
	# The tyre beside it, fuller as the air goes in.
	var tyre := base + Vector2(-150, -60)
	var squash := clampf(pressure, 0.3, 1.0)
	c.draw_arc(tyre, 52.0, 0, TAU, 36, Look.OUTLINE, 10.0 * squash + 4.0)
