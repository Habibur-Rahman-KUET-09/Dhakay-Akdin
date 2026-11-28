## A real-looking person, made from three photos (tool/characters), on the
## home stage: they breathe, look about, sway their arms a little, and do
## their thing (the arms move by turning the rig's bones, see gesture()).
## Made by People.make(who); faces -Z like the cartoon heroes.
extends Node3D

## The rig's bones used here, by name (MPFB's "game_engine" rig).
const BONES := ["spine_01", "spine_02", "spine_03", "neck_01", "head", "clavicle_l", "clavicle_r",
		"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r",
		"thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r"]

## On the rickshaw (rickshaw-local, which faces -Z like him): where he sits,
## the pedals' crank (centre, radius, half the width between the pedals)
## and the handlebar's grips (x either side, height, z).
const SEAT := Vector3(0, 0.27, -0.42)
const CRANK := Vector3(0, 0.42, -0.52)
const CRANK_R := 0.15
const PEDAL_X := 0.12
const GRIP := Vector3(0.29, 1.15, -1.08)
## How far he leans over the handlebar (radians).
const LEAN := 0.42

## Turns, set by gesture tweens, as rotation vectors (axis times angle) in
## the rig's own space: +Z in front of him, +X his left, +Y up. They are
## measured from where the bone rests, as if its parent had not moved, so a
## forearm bend means the same thing whether the arm is down or raised.
var arm_l := Vector3.ZERO
var arm_r := Vector3.ZERO
var fore_l := Vector3.ZERO
var fore_r := Vector3.ZERO
var hand_r := Vector3.ZERO
var nod := 0.0
var gesture_kind := "wave"

var _skel: Skeleton3D
var _bone := {}
var _parent_rest := {}
var _rest := {}
var _t := 0.0
var _look := 0.0
var _look_to := 0.0
var _look_in := 2.0
## Riding: the crank's turn and whether he is pushing the pedals.
var riding := false
var crank := 0.0
var _cranks: Array[MeshInstance3D] = []


func setup(scene: PackedScene, p_gesture: String) -> Node3D:
	gesture_kind = p_gesture
	var model := scene.instantiate() as Node3D
	# glTF people face +Z; the game's face -Z.
	model.rotation.y = PI
	add_child(model)
	_skel = _find_skeleton(model)
	if _skel != null:
		for b in BONES:
			var i := _skel.find_bone(b)
			if i < 0:
				continue
			_bone[b] = i
			var p := _skel.get_bone_parent(i)
			_parent_rest[b] = _skel.get_bone_global_rest(p).basis.orthonormalized() if p >= 0 else Basis()
			_rest[b] = _skel.get_bone_rest(i).basis.get_rotation_quaternion()
	for m in find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return self


func has_rig() -> bool:
	return _bone.size() == BONES.size()


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null


## Called every frame by the stage.
func idle(dt: float) -> void:
	if _skel == null or not has_rig():
		return
	_t += dt
	# Now and then he looks somewhere else, slowly.
	_look_in -= dt
	if _look_in <= 0.0:
		_look_to = randf_range(-0.35, 0.35)
		_look_in = randf_range(2.5, 5.0)
	_look = lerpf(_look, _look_to, clampf(dt * 1.6, 0.0, 1.0))
	var breath := sin(_t * 2.1)
	_turn("spine_02", Vector3(-0.012 * breath, 0, 0))
	_turn("spine_03", Vector3(-0.016 * breath, sin(_t * 0.5) * 0.02, 0))
	_turn("neck_01", Vector3(0.01 * breath + nod * 0.5, _look * 0.4, 0))
	_turn("head", Vector3(nod * 0.5, _look * 0.6, sin(_t * 0.7) * 0.03))
	_turn("clavicle_l", Vector3(0, 0, 0.012 * breath))
	_turn("clavicle_r", Vector3(0, 0, -0.012 * breath))
	var sway := sin(_t * 1.05) * 0.025
	_turn("upperarm_l", arm_l + Vector3(sway, 0, 0))
	_turn("upperarm_r", arm_r + Vector3(-sway, 0, 0))
	_turn("lowerarm_l", fore_l + Vector3(-0.06, 0, 0))
	_turn("lowerarm_r", fore_r + Vector3(-0.06, 0, 0))
	_turn("hand_r", hand_r)


## A bought outfit: the shirt and the lungi take its colours, keeping the
## photo's folds, light and checks (outfit: {"shirt": hex, "lower": hex}).
func wear(outfit: Dictionary) -> void:
	if outfit.is_empty():
		return
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var key := "shirt" if mi.name == "shirt" else ("lower" if mi.name == "lungi" else "")
		if key == "" or not outfit.has(key) or mi.mesh == null:
			continue
		var old := mi.mesh.surface_get_material(0) as BaseMaterial3D
		if old == null or old.albedo_texture == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = _tint()
		mat.set_shader_parameter("photo", old.albedo_texture)
		mat.set_shader_parameter("tint", Color(str(outfit[key])))
		mi.material_override = mat


const _TINT_CODE := """
shader_type spatial;
uniform sampler2D photo : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color;
void fragment() {
	vec3 c = texture(photo, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = tint * (0.3 + 1.25 * l);
	ROUGHNESS = 0.85;
}
"""
static var _tint_shader: Shader


static func _tint() -> Shader:
	if _tint_shader == null:
		_tint_shader = Shader.new()
		_tint_shader.code = _TINT_CODE
	return _tint_shader


## Sits him on the rickshaw he is a child of, hands on the handlebar, feet
## on pedals (which this adds, turning with his feet).
func ride() -> void:
	riding = true
	position = SEAT
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("2B2B2B")
	steel.metallic = 0.6
	steel.roughness = 0.4
	for side in [-1, 1]:
		var arm := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.025, CRANK_R, 0.03)
		arm.mesh = box
		arm.material_override = steel
		var pedal := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.1, 0.025, 0.06)
		pedal.mesh = pb
		pedal.material_override = steel
		pedal.position = Vector3(side * 0.05, CRANK_R * 0.5, 0)
		arm.add_child(pedal)
		get_parent().add_child.call_deferred(arm)
		_cranks.append(arm)


## Each frame on the rickshaw: the crank turns while he pedals (speed in
## tiles a second; coasting, his feet stay where they are).
func pedal(dt: float, pushing: bool, speed: float) -> void:
	if _skel == null or not has_rig():
		return
	_t += dt
	if pushing:
		crank = fmod(crank + dt * (2.2 + speed * 1.6), TAU)
	var to_s := _skeleton_from_here()
	var breath := sin(_t * 2.6)
	# Leaning over the bars, pushing a little harder into each stroke.
	var push := (sin(crank * 2.0) * 0.03) if pushing else 0.0
	_turn("spine_01", Vector3(LEAN * 0.55 + push, 0, sin(crank) * (0.04 if pushing else 0.0)))
	_turn("spine_02", Vector3(LEAN * 0.25 - 0.01 * breath, 0, 0))
	_turn("spine_03", Vector3(LEAN * 0.2 - 0.012 * breath, 0, 0))
	# Head up to see the road.
	_turn("neck_01", Vector3(-LEAN * 0.55, 0, 0))
	_turn("head", Vector3(-LEAN * 0.35, sin(_t * 0.4) * 0.12, 0))
	for b in ["clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "hand_l", "hand_r"]:
		_skel.set_bone_pose_rotation(_bone[b], _rest[b])
	_skel.force_update_all_bone_transforms()
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		# The skeleton's +X (his left) is -X here: he is turned round in it.
		var a := crank + (0.0 if side == "l" else PI)
		var p := CRANK - SEAT + Vector3(-s * PEDAL_X, cos(a) * CRANK_R, -sin(a) * CRANK_R)
		var ankle := to_s * (p + Vector3(0, 0.1, 0.09))
		_limb("thigh_" + side, "calf_" + side, "foot_" + side, ankle, to_s.basis * Vector3(-s * 0.15, 0, -1))
		# The foot along the pedal, toes down more as it comes up behind.
		var toes := to_s.basis * Vector3(0, -0.35 - 0.25 * maxf(0.0, sin(a)), -1).normalized()
		_aim("foot_" + side, "ball_" + side, toes)
		var grip := to_s * (Vector3(-s * GRIP.x, GRIP.y, GRIP.z) - SEAT + Vector3(0, 0.02, 0.05))
		_limb("upperarm_" + side, "lowerarm_" + side, "hand_" + side, grip, to_s.basis * Vector3(-s, -0.6, 0.4))
	# The cranks with the pedals.
	for k in _cranks.size():
		# The first is on -X, with the left foot (crank + 0).
		var a := crank + (0.0 if k == 0 else PI)
		var arm := _cranks[k]
		arm.position = CRANK + Vector3((-1 if k == 0 else 1) * 0.07, cos(a) * CRANK_R * 0.5, -sin(a) * CRANK_R * 0.5)
		arm.rotation = Vector3(-a, 0, 0)
		(arm.get_child(0) as Node3D).rotation = Vector3(a, 0, 0)


## From this node's space to the skeleton's.
func _skeleton_from_here() -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = _skel
	while n != null and n != self:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf.affine_inverse()


## Two bones (upper, lower) reaching for target (skeleton space), the
## middle joint bending towards pole; the end bone keeps its rest.
func _limb(upper: String, lower: String, end: String, target: Vector3, pole: Vector3) -> void:
	var iu: int = _bone[upper]
	var il: int = _bone[lower]
	var ie: int = _bone[end]
	var a := _skel.get_bone_global_pose(iu).origin
	var l1 := _skel.get_bone_rest(il).origin.length()
	var l2 := _skel.get_bone_rest(ie).origin.length()
	var d := target - a
	var dist := clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.005)
	var dir := d.normalized()
	var x := (l1 * l1 + dist * dist - l2 * l2) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var side := (pole - dir * pole.dot(dir)).normalized()
	var mid := a + dir * x + side * h
	_aim(upper, lower, (mid - a).normalized())
	_aim(lower, end, (a + dir * dist - mid).normalized())


## Turns bone so the way to its child points along want (skeleton space),
## from its rest, under its parent as it is posed now.
func _aim(b: String, child: String, want: Vector3) -> void:
	var i: int = _bone[b]
	var c := _skel.find_bone(child)
	var p := _skel.get_bone_parent(i)
	var gp := _skel.get_bone_global_pose(p).basis.orthonormalized() if p >= 0 else Basis()
	var rest: Quaternion = _rest[b]
	var g0 := gp * Basis(rest)
	var now := (g0 * _skel.get_bone_rest(c).origin).normalized()
	var turn := Quaternion(now, want.normalized()) if now.dot(want.normalized()) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	_skel.set_bone_pose_rotation(i, (gp.inverse() * Basis(turn) * g0).get_rotation_quaternion())
	_skel.force_update_all_bone_transforms()


## Turns a bone by a rotation vector in the rig's space, from its rest.
func _turn(b: String, by: Vector3) -> void:
	var i: int = _bone[b]
	var q: Quaternion = _rest[b]
	if by.length_squared() > 1e-10:
		var p: Basis = _parent_rest[b]
		var world := Basis(by.normalized(), by.length())
		q = (p.inverse() * world * p).get_rotation_quaternion() * q
	_skel.set_bone_pose_rotation(i, q)


## Their thing, or "wave". Returns the tween so the stage knows when it ends.
func gesture(kind: String) -> Tween:
	var tw := create_tween()
	match kind:
		"ring":
			# The bell on the handlebar: the right hand out in front, shaken.
			tw.tween_property(self, "arm_r", Vector3(-1.05, 0, -0.15), 0.3).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(self, "fore_r", Vector3(-0.55, 0, 0), 0.3).set_trans(Tween.TRANS_SINE)
			for k in 4:
				tw.tween_property(self, "hand_r", Vector3(0, 0, 0.35), 0.08)
				tw.tween_property(self, "hand_r", Vector3(0, 0, -0.2), 0.08)
		"thumb":
			tw.tween_property(self, "arm_r", Vector3(-1.2, 0, 0), 0.3).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(self, "fore_r", Vector3(-0.3, 0, 0), 0.3)
			tw.tween_interval(0.8)
		"call":
			tw.tween_property(self, "arm_r", Vector3(-2.3, 0, -0.4), 0.35).set_trans(Tween.TRANS_SINE)
			for k in 2:
				tw.tween_property(self, "fore_r", Vector3(-0.5, 0, 0), 0.2)
				tw.tween_property(self, "fore_r", Vector3(0, 0, 0), 0.2)
		"row":
			for k in 2:
				tw.tween_property(self, "arm_r", Vector3(-0.8, 0, 0), 0.4).set_trans(Tween.TRANS_SINE)
				tw.parallel().tween_property(self, "arm_l", Vector3(-0.8, 0, 0), 0.4).set_trans(Tween.TRANS_SINE)
				tw.tween_property(self, "arm_r", Vector3(0.3, 0, 0), 0.4).set_trans(Tween.TRANS_SINE)
				tw.parallel().tween_property(self, "arm_l", Vector3(0.3, 0, 0), 0.4).set_trans(Tween.TRANS_SINE)
		"nod":
			for k in 2:
				tw.tween_property(self, "nod", 0.22, 0.18).set_trans(Tween.TRANS_SINE)
				tw.tween_property(self, "nod", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
		_:
			# A wave: the right arm up at the side, the forearm swinging.
			tw.tween_property(self, "arm_r", Vector3(-0.35, 0, -2.05), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(self, "fore_r", Vector3(0, 0, -0.25), 0.35)
			for k in 3:
				tw.tween_property(self, "fore_r", Vector3(0, 0, -0.75), 0.16).set_trans(Tween.TRANS_SINE)
				tw.tween_property(self, "fore_r", Vector3(0, 0, -0.1), 0.16).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "arm_r", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "arm_l", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "fore_r", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "fore_l", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "hand_r", Vector3.ZERO, 0.3)
	return tw
