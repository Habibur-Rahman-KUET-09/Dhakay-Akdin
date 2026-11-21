## Weather that the 3D scenes share: the rain.
extends RefCounted


## Rain drops to fall round the camera (emitting set by the scene).
static func rain_drops() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Rain"
	p.amount = 600
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(13, 0.5, 13)
	p.direction = Vector3(0.05, -1, 0)
	p.spread = 4.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 19.0
	p.gravity = Vector3(0, -9.8, 0)
	var streak := BoxMesh.new()
	streak.size = Vector3(0.012, 0.45, 0.012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.82, 0.86, 0.92, 0.4)
	streak.material = m
	p.mesh = streak
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	return p
