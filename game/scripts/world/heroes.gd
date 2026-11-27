## The seven people the player plays, as they stand on the home page:
## cute proportions (a big head, big shining eyes, a smile, a little blush),
## each with their own things to know them by from far off (Rahim's
## gamchha and checked lungi, Monir's cap and kettle, Babu's cap worn
## backwards and the notes between his fingers, Julekha's sari with its
## border, bangles and nose pin, Ratul's helmet and food bag, Kashem's
## peanut basket on his head, Haripada's gamchha turban and oar).
##
## Painted in flat bands of light (toon) with a dark outline, like the
## rickshaw art of the menus. A hero is a Node3D with the parts that move
## apart: "head" (with "lids" to blink), "arm_l" and "arm_r" (pivots at the
## shoulders), and "gesture" (what they do now and then).
## Faces -Z, standing on y = 0, about 1.5 m tall.
extends RefCounted

const Models = preload("res://scripts/world/models.gd")

const INK := Color("1D1A1A")
const WHITE := Color("FBF8F2")
const IRIS := Color("3B2314")
const MOUTH := Color("7A2A22")
const RUBBER := Color("26221F")
const GREY := Color("A9A49C")

## Each one: skin, hair, shirt, lower, what they do (gesture), and extras.
const LOOKS := {
	"rickshaw": {"skin": "9E6A48", "hair": "2A221E", "shirt": "E8892B", "lower": "2D5D8A", "gesture": "ring", "grey": true, "moustache": true},
	"tea": {"skin": "AC7752", "hair": "1F1916", "shirt": "F4F1E8", "lower": "2D5D8A", "gesture": "pour", "moustache": true},
	"bus": {"skin": "B47E56", "hair": "17120F", "shirt": "2D8BD6", "lower": "37474F", "gesture": "wave", "grin": true},
	"fuchka": {"skin": "BC8862", "hair": "17120F", "shirt": "1C7C54", "lower": "C2185B", "gesture": "wave"},
	"delivery": {"skin": "B07A52", "hair": "17120F", "shirt": "1E6FB0", "lower": "2B2B33", "gesture": "thumb", "grin": true},
	"hawker": {"skin": "9A6443", "hair": "201A16", "shirt": "A0722F", "lower": "5D4037", "gesture": "call", "moustache": true},
	"boat": {"skin": "93603F", "hair": "2A221E", "shirt": "F4F1E8", "lower": "1F6E8C", "gesture": "row", "grey": true, "moustache": true},
}

const HIP := 0.46
const SHOULDER_Y := 0.86
const NECK_Y := 0.92
const HEAD_R := 0.25

static var _toon: Shader
static var _outline: Shader


const TOON := """
shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform float lift = 0.0;
void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045))) + vec3(lift);
	ROUGHNESS = 1.0;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
"""

const OUTLINE := """
shader_type spatial;
render_mode unshaded, cull_front;
uniform float width = 0.012;
uniform vec4 ink : source_color = vec4(0.114, 0.102, 0.102, 1.0);
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = ink.rgb;
}
"""


## The outline pass alone: put on any material's next_pass.
static func outline(width := 0.012) -> ShaderMaterial:
	if _outline == null:
		_outline = Shader.new()
		_outline.code = OUTLINE
	var m := ShaderMaterial.new()
	m.shader = _outline
	m.set_shader_parameter("width", width)
	return m


## Flat bands of light from the vertex colours, outlined.
static func toon(width := 0.012) -> ShaderMaterial:
	if _toon == null:
		_toon = Shader.new()
		_toon.code = TOON
	var m := ShaderMaterial.new()
	m.shader = _toon
	m.next_pass = outline(width)
	return m


## `who` in their outfit (shirt and lower colours from a bought look, if
## any).
static func hero(who: String, outfit := {}) -> Node3D:
	var look: Dictionary = LOOKS.get(who, LOOKS.rickshaw)
	var skin := Color(str(look.skin))
	var hair := Color(str(look.hair))
	var shirt := Color(str(outfit.get("shirt", look.shirt)))
	var lower := Color(str(outfit.get("lower", look.lower)))
	var woman := who == "fuchka"
	var mat := toon()
	var root := Node3D.new()
	root.name = "Hero"
	# The body: legs, hips, clothes, chest, neck, things on the back.
	var b := Models.Builder.new()
	_legs(b, who, skin, shirt, lower)
	_chest(b, who, shirt, lower, skin, woman)
	root.add_child(_mesh("Body", b, mat))
	# The head on a pivot at the neck.
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, NECK_Y, 0)
	root.add_child(head)
	var hb := Models.Builder.new()
	_face(hb, who, look, skin, hair, shirt, lower)
	head.add_child(_mesh("HeadMesh", hb, mat))
	# Eyelids, shown for a blink.
	var lb := Models.Builder.new()
	for side in [-1, 1]:
		lb.ball(0.068, Vector3(side * 0.09, 0.215, -0.208), skin.darkened(0.08), Vector3(1.0, 1.25, 0.5), 1.0, Vector2.ZERO, 12)
	var lids := _mesh("Lids", lb, toon(0.006))
	lids.visible = false
	head.add_child(lids)
	# Arms on pivots at the shoulders; the right hand holds their thing.
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.name = "ArmR" if side > 0 else "ArmL"
		var sw := 0.2 if not woman else 0.18
		arm.position = Vector3(side * (sw + 0.03), SHOULDER_Y - 0.02, 0)
		root.add_child(arm)
		var ab := Models.Builder.new()
		_arm(ab, who, side, shirt, skin, woman)
		if side > 0:
			_held(ab, who)
		arm.add_child(_mesh("ArmMesh", ab, mat))
		root.set_meta("arm_r" if side > 0 else "arm_l", arm)
	root.set_meta("head", head)
	root.set_meta("lids", lids)
	root.set_meta("gesture", str(look.gesture))
	return root


static func _mesh(name: String, b, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = name
	m.mesh = b.commit()
	m.material_override = mat
	return m


static func _legs(b, who: String, skin: Color, shirt: Color, lower: Color) -> void:
	var wrap := who in ["rickshaw", "hawker", "boat", "fuchka"]
	for side in [-1, 1]:
		var x: float = side * 0.095
		if not wrap:
			b.cyl(0.085, 0.36, Vector3(x, 0.24, 0), lower, Vector3.ZERO, 12, 1.0, Vector2.ZERO, 0.08)
		else:
			b.cyl(0.06, 0.3, Vector3(x, 0.17, 0), skin, Vector3.ZERO, 10)
		# Sandals (chappal) for the lungi and the sari, shoes for the rest.
		var shoe := RUBBER if not wrap else Color("6B4A2E")
		b.ball(0.08, Vector3(x, 0.045, -0.04), shoe, Vector3(0.95, 0.5, 1.5), 1.0, Vector2.ZERO, 10)
	if who == "fuchka":
		# The sari falls to the ankles, with its border at the hem.
		b.cyl(0.25, 0.5, Vector3(0, 0.33, 0), shirt, Vector3.ZERO, 18, 1.0, Vector2.ZERO, 0.2)
		b.cyl(0.255, 0.06, Vector3(0, 0.1, 0), lower, Vector3.ZERO, 18, 1.0, Vector2.ZERO, 0.252)
	elif wrap:
		# A lungi: checks of two shades, a band at the waist.
		b.cyl(0.215, 0.4, Vector3(0, 0.33, 0), lower, Vector3.ZERO, 16, 1.0, Vector2.ZERO, 0.2)
		for k in 4:
			b.cyl(0.218, 0.025, Vector3(0, 0.18 + k * 0.08, 0), lower.lightened(0.35), Vector3.ZERO, 16, 1.0, Vector2.ZERO, 0.218)
		for k in 8:
			var a := k * TAU / 8.0
			b.box(Vector3(0.02, 0.38, 0.02), Vector3(sin(a) * 0.207, 0.33, cos(a) * 0.207), lower.darkened(0.25), Vector3(0, rad_to_deg(a), 0))
	b.ball(0.2, Vector3(0, HIP + 0.02, 0), lower if who != "fuchka" else shirt, Vector3(1.05, 0.55, 0.85), 1.0, Vector2.ZERO, 14)


static func _chest(b, who: String, shirt: Color, lower: Color, skin: Color, woman: bool) -> void:
	# A round chest and belly, shoulders.
	b.ball(0.23, Vector3(0, 0.66, 0), shirt, Vector3(1.0 if not woman else 0.92, 1.12, 0.82), 1.0, Vector2.ZERO, 16)
	var sw := 0.2 if not woman else 0.18
	for side in [-1, 1]:
		b.ball(0.085, Vector3(side * sw, SHOULDER_Y - 0.03, 0), shirt, Vector3.ONE, 1.0, Vector2.ZERO, 10)
	b.cyl(0.06, 0.08, Vector3(0, NECK_Y - 0.02, 0), skin, Vector3.ZERO, 10)
	match who:
		"rickshaw":
			# A red and white checked gamchha over the left shoulder.
			for k in 8:
				var c := Color("D32F2F") if k % 2 == 0 else WHITE
				b.box(Vector3(0.12, 0.07, 0.045), Vector3(-0.15 + k * 0.004, SHOULDER_Y - 0.02 - k * 0.065, -0.17 + k * 0.012), c, Vector3(-8, 0, 12))
		"tea":
			# A fatua's buttons and a short pocket.
			for k in 3:
				b.ball(0.014, Vector3(0, 0.78 - k * 0.08, -0.188), Color("C9A66B"), Vector3.ONE, 1.0, Vector2.ZERO, 6)
			b.box(Vector3(0.1, 0.08, 0.02), Vector3(0.1, 0.74, -0.18), shirt.darkened(0.08))
		"bus":
			# A shoulder bag strap for the day's money.
			b.box(Vector3(0.05, 0.62, 0.02), Vector3(0, 0.68, -0.19), Color("5D4037"), Vector3(0, 0, -38))
			b.box(Vector3(0.18, 0.14, 0.08), Vector3(0.18, 0.5, -0.1), Color("6D4C41"))
		"fuchka":
			# The sari's end (anchal) over the left shoulder, with its border.
			b.box(Vector3(0.14, 0.55, 0.03), Vector3(-0.05, 0.68, -0.19), shirt, Vector3(0, 0, 28))
			b.box(Vector3(0.035, 0.55, 0.035), Vector3(-0.1, 0.66, -0.2), lower, Vector3(0, 0, 28))
			b.box(Vector3(0.16, 0.6, 0.03), Vector3(-0.17, 0.62, 0.17), shirt, Vector3(0, 0, -6))
		"delivery":
			# The big insulated food bag on his back, with the white band.
			b.box(Vector3(0.38, 0.4, 0.26), Vector3(0, 0.72, 0.28), Color("F26B1D"))
			b.box(Vector3(0.39, 0.06, 0.27), Vector3(0, 0.74, 0.28), WHITE)
			for side in [-1, 1]:
				b.box(Vector3(0.04, 0.4, 0.03), Vector3(side * 0.13, 0.72, -0.19), INK, Vector3(-8, 0, 0))
		"hawker":
			# A gamchha round the neck.
			b.cyl(0.11, 0.05, Vector3(0, NECK_Y - 0.06, 0), Color("2E7D32"), Vector3.ZERO, 12, 1.0, Vector2.ZERO, 0.12)
		"boat":
			# A vest over the shirt.
			for side in [-1, 1]:
				b.box(Vector3(0.12, 0.34, 0.03), Vector3(side * 0.1, 0.68, -0.185), Color("6D4C41"), Vector3(0, 0, -side * 6))


static func _arm(b, who: String, side: int, shirt: Color, skin: Color, woman: bool) -> void:
	# From the pivot (the shoulder) down: a short sleeve, the arm, a hand.
	b.cyl(0.07, 0.16, Vector3(0, -0.07, 0), shirt, Vector3.ZERO, 10, 1.0, Vector2.ZERO, 0.075)
	b.cyl(0.05, 0.26, Vector3(0, -0.24, 0), skin, Vector3.ZERO, 10, 1.0, Vector2.ZERO, 0.055)
	b.ball(0.06, Vector3(0, -0.39, -0.005), skin, Vector3(0.9, 1.05, 0.8), 1.0, Vector2.ZERO, 10)
	if woman:
		# Glass bangles, red and gold.
		b.ring(0.045, 0.058, Vector3(0, -0.31, 0), Color("C62828"))
		b.ring(0.045, 0.058, Vector3(0, -0.33, 0), Color("F6B800"))


## What the right hand holds.
static func _held(b, who: String) -> void:
	var hand := Vector3(0, -0.42, -0.04)
	match who:
		"rickshaw":
			# The rickshaw bell, chrome.
			b.cyl(0.05, 0.03, hand + Vector3(0, 0.0, -0.05), Color("B8BCC2"), Vector3(90, 0, 0), 12)
			b.ball(0.035, hand + Vector3(0, 0.0, -0.07), Color("D8DCE2"), Vector3(1, 1, 0.6), 1.0, Vector2.ZERO, 10)
		"tea":
			# An aluminium kettle with its spout.
			b.cyl(0.1, 0.16, hand + Vector3(0, -0.1, -0.02), Color("C9CED6"), Vector3.ZERO, 14, 1.0, Vector2.ZERO, 0.075)
			b.ball(0.06, hand + Vector3(0, 0.0, -0.02), Color("C9CED6"), Vector3(1, 0.5, 1), 1.0, Vector2.ZERO, 10)
			b.cyl(0.018, 0.14, hand + Vector3(0, -0.07, -0.14), Color("C9CED6"), Vector3(-55, 0, 0), 8)
		"bus":
			# Folded notes between the fingers, green and red.
			for k in 3:
				b.box(Vector3(0.012, 0.12, 0.06), hand + Vector3(-0.02 + k * 0.02, -0.06, -0.03), [Color("2E7D32"), Color("C62828"), Color("6A1B9A")][k], Vector3(0, 0, -10 + k * 10))
		"fuchka":
			# A fuchka on a leaf plate.
			b.cyl(0.08, 0.015, hand + Vector3(0, -0.05, -0.06), Color("4E8B3A"), Vector3.ZERO, 12)
			b.ball(0.035, hand + Vector3(0, -0.02, -0.06), Color("E0A84E"), Vector3(1, 0.9, 1), 1.0, Vector2.ZERO, 8)
		"delivery":
			# A phone with the order on it.
			b.box(Vector3(0.07, 0.13, 0.015), hand + Vector3(0, 0.02, -0.06), INK, Vector3(-30, 0, 0))
			b.box(Vector3(0.055, 0.1, 0.004), hand + Vector3(0, 0.022, -0.07), Color("4FC3F7"), Vector3(-30, 0, 0))
		"hawker":
			# A paper cone of peanuts.
			b.cyl(0.05, 0.14, hand + Vector3(0, -0.04, -0.05), Color("E8D9B5"), Vector3(180, 0, 0), 10, 1.0, Vector2.ZERO, 0.0)
		"boat":
			# His oar: the shaft through the hand, the blade below.
			b.cyl(0.022, 1.5, hand + Vector3(0, -0.15, -0.05), Color("8D6E63"), Vector3.ZERO, 8)
			b.box(Vector3(0.14, 0.38, 0.025), hand + Vector3(0, -0.85, -0.05), Color("A1887F"))


static func _face(b, who: String, look: Dictionary, skin: Color, hair: Color, shirt: Color, lower: Color) -> void:
	var c := Vector3(0, 0.2, 0)
	# A big round head, cheeks a little full, ears.
	b.ball(HEAD_R, c, skin, Vector3(1.0, 0.96, 0.95), 1.0, Vector2.ZERO, 18)
	b.ball(0.17, c + Vector3(0, -0.08, -0.06), skin, Vector3(1.15, 0.7, 1.0), 1.0, Vector2.ZERO, 12)
	for side in [-1, 1]:
		b.ball(0.05, c + Vector3(side * 0.245, 0.0, 0.0), skin, Vector3(0.5, 0.9, 0.7), 1.0, Vector2.ZERO, 8)
		# Big eyes: white, a brown iris, the pupil, a shine of light.
		var eye := c + Vector3(side * 0.09, 0.015, -0.208)
		b.ball(0.062, eye, WHITE, Vector3(0.95, 1.2, 0.45), 1.0, Vector2.ZERO, 14)
		b.ball(0.042, eye + Vector3(0, -0.005, -0.016), IRIS, Vector3(1, 1.1, 0.4), 1.0, Vector2.ZERO, 12)
		b.ball(0.022, eye + Vector3(0, -0.005, -0.026), INK, Vector3(1, 1, 0.4), 1.0, Vector2.ZERO, 10)
		b.ball(0.012, eye + Vector3(-side * 0.012 - 0.006, 0.022, -0.034), Color.WHITE, Vector3(1, 1, 0.4), 1.0, Vector2.ZERO, 8)
		# Thick brows; a blush on the cheeks.
		var brow := hair if not look.get("grey", false) else GREY
		b.box(Vector3(0.085, 0.02, 0.02), c + Vector3(side * 0.095, 0.1, -0.215), brow, Vector3(0, 0, -side * 8))
		b.ball(0.04, c + Vector3(side * 0.15, -0.065, -0.185), skin.lerp(Color("E26D5A"), 0.35), Vector3(1.2, 0.6, 0.3), 1.0, Vector2.ZERO, 8)
	# A small nose; the smile (a grin with teeth for the young ones).
	b.ball(0.028, c + Vector3(0, -0.035, -0.238), skin.darkened(0.08), Vector3(1.1, 0.85, 0.8), 1.0, Vector2.ZERO, 8)
	if look.get("grin", false):
		b.ball(0.055, c + Vector3(0, -0.11, -0.205), MOUTH, Vector3(1.2, 0.55, 0.35), 1.0, Vector2.ZERO, 12)
		b.box(Vector3(0.09, 0.022, 0.01), c + Vector3(0, -0.092, -0.226), WHITE)
	else:
		for k in [-1, 0, 1]:
			b.box(Vector3(0.04, 0.016, 0.016), c + Vector3(k * 0.034, -0.105 + absf(k) * 0.012, -0.212), MOUTH, Vector3(0, 0, k * 22))
	if look.get("moustache", false):
		var m := hair if not look.get("grey", false) else GREY
		for side in [-1, 1]:
			b.ball(0.035, c + Vector3(side * 0.035, -0.07, -0.226), m, Vector3(1.3, 0.55, 0.5), 1.0, Vector2.ZERO, 8)
	# Hair and what is on the head.
	match who:
		"fuchka":
			# Hair parted and tied in a bun; a gold nose pin.
			b.ball(HEAD_R + 0.012, c + Vector3(0, 0.05, 0.02), hair, Vector3(1.0, 0.85, 1.0), 1.0, Vector2.ZERO, 16)
			b.ball(0.1, c + Vector3(0, -0.02, 0.24), hair, Vector3.ONE, 1.0, Vector2.ZERO, 12)
			b.ball(0.013, c + Vector3(0.028, -0.03, -0.248), Color("F6B800"), Vector3.ONE, 1.0, Vector2.ZERO, 6)
			# The sari's end over the back of the head.
			b.ball(HEAD_R + 0.03, c + Vector3(0, 0.03, 0.06), shirt, Vector3(1.02, 0.95, 0.9), 1.0, Vector2.ZERO, 16)
			b.box(Vector3(0.5, 0.04, 0.04), c + Vector3(0, 0.16, -0.12), lower, Vector3(-20, 0, 0))
		"tea":
			# A white crocheted cap.
			b.ball(HEAD_R + 0.012, c + Vector3(0, 0.04, 0.02), hair, Vector3(1.0, 0.8, 1.0), 1.0, Vector2.ZERO, 16)
			b.cyl(0.21, 0.11, c + Vector3(0, 0.2, 0.0), Color("F2F0EA"), Vector3.ZERO, 16, 1.0, Vector2.ZERO, 0.19)
		"bus":
			# A red cap worn backwards.
			b.ball(HEAD_R + 0.012, c + Vector3(0, 0.05, 0.02), hair, Vector3(1.0, 0.8, 1.0), 1.0, Vector2.ZERO, 16)
			b.ball(HEAD_R + 0.02, c + Vector3(0, 0.1, 0.0), Color("D32F2F"), Vector3(1.0, 0.6, 1.0), 1.0, Vector2.ZERO, 16)
			b.box(Vector3(0.22, 0.025, 0.16), c + Vector3(0, 0.1, 0.27), Color("B71C1C"), Vector3(-8, 0, 0))
		"delivery":
			# A helmet with a visor.
			b.ball(HEAD_R + 0.012, c + Vector3(0, 0.05, 0.02), hair, Vector3(1.0, 0.8, 1.0), 1.0, Vector2.ZERO, 16)
			b.ball(HEAD_R + 0.035, c + Vector3(0, 0.12, 0.03), Color("F26B1D"), Vector3(1.0, 0.7, 1.0), 1.0, Vector2.ZERO, 18)
			b.box(Vector3(0.32, 0.03, 0.09), c + Vector3(0, 0.17, -0.25), INK, Vector3(-18, 0, 0))
			b.box(Vector3(0.06, 0.06, 0.3), c + Vector3(0, 0.31, 0.03), WHITE)
		"hawker":
			# The round basket of peanuts on a coil of cloth.
			b.ball(HEAD_R + 0.012, c + Vector3(0, 0.05, 0.02), hair, Vector3(1.0, 0.78, 1.0), 1.0, Vector2.ZERO, 16)
			b.cyl(0.16, 0.05, c + Vector3(0, 0.24, 0), Color("C8B08A"), Vector3.ZERO, 14, 1.0, Vector2.ZERO, 0.17)
			b.cyl(0.3, 0.14, c + Vector3(0, 0.33, 0), Color("9C6B3C"), Vector3.ZERO, 18, 1.0, Vector2.ZERO, 0.24)
			for k in 14:
				var a := k * TAU / 14.0
				b.ball(0.035, c + Vector3(cos(a) * 0.17, 0.4, sin(a) * 0.17), Color("D9A35B"), Vector3(1, 0.7, 1.3), 1.0, Vector2.ZERO, 6)
			b.ball(0.035, c + Vector3(0, 0.41, 0), Color("D9A35B"), Vector3(1, 0.7, 1.3), 1.0, Vector2.ZERO, 6)
		"boat":
			# A gamchha tied round the head, red and white.
			b.ball(HEAD_R + 0.008, c + Vector3(0, 0.03, 0.02), GREY.darkened(0.3), Vector3(1.0, 0.8, 1.0), 1.0, Vector2.ZERO, 16)
			for k in 12:
				var a := k * TAU / 12.0
				b.ball(0.05, c + Vector3(cos(a) * 0.22, 0.17, sin(a) * 0.22), Color("D32F2F") if k % 2 == 0 else WHITE, Vector3(1.2, 0.75, 1.2), 1.0, Vector2.ZERO, 8)
			b.ball(0.06, c + Vector3(0.1, 0.22, 0.2), Color("D32F2F"), Vector3.ONE, 1.0, Vector2.ZERO, 8)
		_:
			# Rahim Chacha: short hair going grey at the sides.
			b.ball(HEAD_R + 0.012, c + Vector3(0, 0.06, 0.03), hair, Vector3(1.0, 0.75, 1.0), 1.0, Vector2.ZERO, 16)
			for side in [-1, 1]:
				b.ball(0.07, c + Vector3(side * 0.2, 0.03, 0.06), GREY, Vector3(0.5, 1.0, 1.0), 1.0, Vector2.ZERO, 8)
