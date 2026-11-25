## Something left behind on the seat: a phone, a file, an umbrella… Where
## did its owner get off? Three places to choose from (the scene gives
## their names), or hand it in (the police box, the bus counter). The
## owner gets it back only from the right place.
extends "res://scripts/ui/activity.gd"

## What was found (activities.gd LOST_ITEMS), the question, the places;
## the key of the "hand it in" button.
var item := "phone"
var question := ""
var choices: Array = []
var hand_in_key := "lost_police"
## Read by the scene after `done`: the place chosen, −1 handed in.
var choice := -1


func _build() -> void:
	set_hint(question)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12
	col.offset_right = -12
	col.offset_top = 96
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 8)
	canvas.add_child(col)
	for i in choices.size():
		var b := Look.button(str(choices[i]), Look.SKY.darkened(0.15), 17)
		b.custom_minimum_size = Vector2(0, 50)
		b.pressed.connect(_answer.bind(i))
		col.add_child(b)
	add_button(hand_in_key, Color("8A8178"), _answer.bind(-1))
	buzz(80)


func _tick(_dt: float) -> void:
	if t > 25.0:
		_answer(-1)


func _answer(i: int) -> void:
	choice = i
	finish(1.0 if i >= 0 else 0.5)


func _paint(c: Control) -> void:
	var at := Vector2(c.size.x * 0.5, 46)
	var bob := sin(t * 3.0) * 3.0
	at.y += bob
	# A glow behind it, then the thing itself.
	c.draw_circle(at, 42.0, Color(Look.YELLOW, 0.35))
	match item:
		"phone":
			c.draw_rect(Rect2(at + Vector2(-18, -32), Vector2(36, 64)), Look.OUTLINE)
			c.draw_rect(Rect2(at + Vector2(-14, -26), Vector2(28, 48)), Color("5C8FC2"))
		"umbrella":
			var pts := PackedVector2Array()
			for i in 13:
				pts.append(at + Vector2(-40 + i * 80.0 / 12.0, -6 - sin(i / 12.0 * PI) * 26.0))
			pts.append(at + Vector2(40, -6))
			c.draw_colored_polygon(pts, Look.MAGENTA)
			c.draw_line(at + Vector2(0, -6), at + Vector2(0, 30), Look.OUTLINE, 4.0)
			c.draw_arc(at + Vector2(-7, 30), 7.0, 0, PI, 8, Look.OUTLINE, 4.0)
		"file":
			c.draw_rect(Rect2(at + Vector2(-34, -26), Vector2(68, 52)), Color("E7C66B"))
			c.draw_rect(Rect2(at + Vector2(-34, -26), Vector2(68, 52)), Look.OUTLINE, false, 2.5)
			c.draw_rect(Rect2(at + Vector2(-34, -34), Vector2(28, 10)), Color("E7C66B"))
		"glasses":
			c.draw_arc(at + Vector2(-20, 0), 16.0, 0, TAU, 24, Look.OUTLINE, 4.0)
			c.draw_arc(at + Vector2(20, 0), 16.0, 0, TAU, 24, Look.OUTLINE, 4.0)
			c.draw_line(at + Vector2(-4, -2), at + Vector2(4, -2), Look.OUTLINE, 4.0)
		"book":
			c.draw_rect(Rect2(at + Vector2(-30, -28), Vector2(60, 56)), Look.PARROT)
			c.draw_rect(Rect2(at + Vector2(-30, -28), Vector2(60, 56)), Look.OUTLINE, false, 2.5)
			c.draw_line(at + Vector2(-20, -28), at + Vector2(-20, 28), Look.OUTLINE, 2.0)
		"purse":
			c.draw_rect(Rect2(at + Vector2(-30, -12), Vector2(60, 36)), Look.MAGENTA.darkened(0.2))
			c.draw_arc(at + Vector2(0, -12), 18.0, PI, TAU, 16, Look.OUTLINE, 4.0)
		_:
			c.draw_rect(Rect2(at + Vector2(-32, -18), Vector2(64, 46)), Color("8B5A2B"))
			c.draw_arc(at + Vector2(0, -18), 16.0, PI, TAU, 16, Look.OUTLINE, 4.0)
