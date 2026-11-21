## What stands about a Dhaka street: rows of parked rickshaws, fruit
## sellers' vans, people waiting at shop fronts, billboards on the roofs
## along the main roads, and mosques with their domes and minarets.
## All copies of a kind are one multimesh.
extends RefCounted

const RoadMap = preload("res://scripts/rules/road_map.gd")
const Models = preload("res://scripts/world/models.gd")
const Look = preload("res://scripts/ui/look.gd")

const T := 6.0
const FLOOR := 3.0
const PAVEMENT := 0.9


## Same noise as the town, so clutter and buildings agree.
static func noise(p: Vector2i, salt := 0) -> float:
	var h := (p.x * 73856093) ^ (p.y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 10007) / 10007.0


static func centre(p: Vector2i, y := 0.0) -> Vector3:
	return Vector3((p.x + 0.5) * T, y, (p.y + 0.5) * T)


## Building tiles that hold a mosque instead of a block of flats: the one
## nearest Shah Ali Mazar and a few others beside roads.
static func mosque_tiles(map: RoadMap) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pl in map.places:
		if pl.id != "mazar":
			continue
		var best := Vector2i(-1, -1)
		var best_d := 1 << 30
		for d in 4:
			for k in range(1, 3):
				var q: Vector2i = pl.at + Vector2i(RoadMap.DX[d], RoadMap.DY[d]) * k
				if map.kind_at(q) == RoadMap.Kind.BLOCK and k < best_d:
					best = q
					best_d = k
		if best.x >= 0:
			out.append(best)
	for y in map.height:
		for x in map.width:
			var p := Vector2i(x, y)
			if map.kind_at(p) != RoadMap.Kind.BLOCK or noise(p, 300) > 0.006:
				continue
			for d in 4:
				if map.is_road(RoadMap.step(p, d)):
					out.append(p)
					break
	return out


## Facing a direction: Godot models look along -Z.
static func _facing(dir: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(-dir.x, -dir.z))


static func build(map: RoadMap, palette: PackedColorArray) -> Node3D:
	var node := Node3D.new()
	node.name = "Clutter"
	var paint := Models.traffic_material(palette)
	var parked: Array = []
	var carts: Array = []
	var people: Array = []
	var boards: Array = []
	var shop_list = JSON.parse_string(FileAccess.get_file_as_string("res://content/shops.json"))
	var ads: Array = shop_list.billboards
	for p in map.roads():
		var k := map.kind_at(p)
		for d in 4:
			var q := RoadMap.step(p, d)
			if map.kind_at(q) != RoadMap.Kind.BLOCK:
				continue
			var inward := Vector3(RoadMap.DX[d], 0, RoadMap.DY[d])
			var along := Vector3(-inward.z, 0, inward.x)
			var n := noise(p, 120 + d)
			var colours := Color(0, 0, floor(noise(p, 130 + d) * 8), 8 + floor(noise(p, 131 + d) * 8))
			if k == RoadMap.Kind.ROAD and n < 0.07:
				# One or two rickshaws parked end to end along the edge of the
				# lane, clear of the traffic.
				for i in 1 + int(noise(p, 145) * 2):
					var at := centre(p) + inward * (T / 2 - 0.72) + along * (i - 0.5) * 2.7
					parked.append([Transform3D(_facing(along), at), Color(0, 0, floor(noise(p, 150 + i) * 8), 8 + floor(noise(p, 151 + i) * 8))])
			elif k == RoadMap.Kind.ROAD and n < 0.1:
				carts.append([Transform3D(_facing(along), centre(p) + inward * (T / 2 - 0.75)), colours])
			elif n < 0.24:
				# Someone waiting at a shop front, facing the road.
				var spot := centre(p) + inward * (T / 2 + PAVEMENT * 0.5) + along * (noise(p, 160 + d) - 0.5) * 3.0
				people.append([Transform3D(_facing(-inward), spot + Vector3(0, 0.15, 0)), colours])
			# Billboards on the roofs along the main roads.
			if k == RoadMap.Kind.MAIN_ROAD and noise(p, 170 + d) < 0.05:
				var floors := 2 + int(noise(q, 1) * 5)
				var h := floors * FLOOR + 0.6
				var at := centre(q, h)
				boards.append([Transform3D(_facing(-inward), at), Color(0, 0, floor(noise(p, 171 + d) * 8), floor(noise(p, 172 + d) * 8))])
				var ad: Dictionary = ads[int(noise(p, 173 + d) * ads.size())]
				var label := Label3D.new()
				label.text = ad.bn
				label.font = Look.font(Look.BOLD)
				label.font_size = 96
				label.outline_size = 10
				label.modulate = Color.WHITE
				label.outline_modulate = Look.OUTLINE
				label.pixel_size = 0.012
				label.double_sided = false
				label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
				label.width = 5.6 / label.pixel_size
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.basis = _facing(-inward) * Basis(Vector3.UP, PI)
				label.position = at + Vector3(0, 4.55, 0) - inward * 0.16
				label.visibility_range_end = 120.0
				node.add_child(label)
	node.add_child(_multi(Models.rickshaw(false, false), parked, paint))
	node.add_child(_multi(Models.fruit_cart(), carts, paint))
	node.add_child(_multi(Models.person(), people, paint))
	node.add_child(_multi(Models.billboard_frame(), boards, paint))
	var mosque_at: Array = []
	for p in mosque_tiles(map):
		var face := Vector3.BACK
		for d in 4:
			if map.is_road(RoadMap.step(p, d)):
				face = Vector3(RoadMap.DX[d], 0, RoadMap.DY[d])
				break
		mosque_at.append([Transform3D(_facing(face), centre(p)), Color(0, 0, 0, 0)])
	var mosques := _multi(Models.mosque(), mosque_at, null)
	mosques.material_override = Models.material()
	node.add_child(mosques)
	return node


## items: [transform, custom data] each.
static func _multi(mesh: Mesh, items: Array, material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_custom_data(i, items[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if material:
		mi.material_override = material
	return mi
