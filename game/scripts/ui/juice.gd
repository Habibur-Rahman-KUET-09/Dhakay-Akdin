## A little celebration for a good moment (a combo, a perfect stop call,
## a five-star ride, a just-right fuchka): a chime, a short buzz on the
## phone and a burst of coloured confetti on the screen. Kept small, so it
## feels good rather than noisy.
extends RefCounted

const COLOURS := [Color("F6B800"), Color("C2185B"), Color("2E9E6B"), Color("1E6FB0"), Color("E2432A")]


## A light buzz for a tap that is not on a button (a swipe, a face).
static func tap() -> void:
	if OS.has_feature("mobile") and load("res://scripts/ui/prefs.gd").taps():
		Input.vibrate_handheld(8)


## kind: "ting" (small) or "sparkle" (big). `parent` is where the confetti
## goes (a CanvasLayer or Control); `at` its middle on screen.
static func celebrate(parent: Node, kind := "ting", at := Vector2(-1, -1)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var big := kind == "sparkle"
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(35 if big else 18)
	var sound := AudioStreamPlayer.new()
	sound.stream = load("res://sounds/%s.wav" % kind)
	sound.volume_db = -4.0
	parent.add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)
	var burst := CPUParticles2D.new()
	var size := parent.get_viewport().get_visible_rect().size
	burst.position = at if at.x >= 0.0 else Vector2(size.x / 2.0, size.y * 0.3)
	burst.amount = 40 if big else 18
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.lifetime = 1.1
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.initial_velocity_min = 180.0 if big else 120.0
	burst.initial_velocity_max = 380.0 if big else 240.0
	burst.gravity = Vector2(0, 520)
	burst.scale_amount_min = 5.0
	burst.scale_amount_max = 9.0
	burst.angular_velocity_min = -200.0
	burst.angular_velocity_max = 200.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	ramp.colors = PackedColorArray(COLOURS)
	burst.color_initial_ramp = ramp
	parent.add_child(burst)
	burst.emitting = true
	parent.get_tree().create_timer(1.6).timeout.connect(burst.queue_free)
