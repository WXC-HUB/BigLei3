extends SceneTree
## 六边岛选关图生成器 —— 产出 `scenes/world_map.tscn`。
##
## 跑法：`godot --headless --script tools/build_world_map.gd`
## 构图以 KayKit 六边格为主，岛浮在卡通水上；植被/水体/光线只用现有资源。

const OUT_PATH := "res://scenes/world_map.tscn"
const NATURE := "res://assets/nature/"
const HEXMAP := "res://assets/hexmap/"
const HEX_DECO := "res://assets/hexmap/decoration/"

## KayKit hex_grass：尖顶朝 Z，对边距 2，点距 2.309。
const HEX_W := 2.0
const HEX_H := 1.7320508
const PATH_HALF := 1.35
const TREE_MIN_GAP := 2.72

const STAGE_T := [0.00, 0.20, 0.40, 0.60, 0.80, 1.00]
const STAGE_IDS := ["grass_1", "grass_2", "grass_3", "river_1", "river_2", "coast_1"]
## 关卡格上的一点建筑：按关名挑小屋/风车/井/磨坊/市集，不盖城堡。
const STAGE_BUILDINGS := {
	"grass_1": {"rel": "buildings/green/building_home_A_green.gltf", "scale": 1.18, "yaw": 0.55},
	"grass_2": {"rel": "buildings/green/building_windmill_green.gltf", "scale": 0.88, "yaw": -0.35},
	"grass_3": {"rel": "buildings/green/building_well_green.gltf", "scale": 1.22, "yaw": 0.18},
	"river_1": {"rel": "buildings/green/building_home_B_green.gltf", "scale": 1.10, "yaw": 0.82},
	"river_2": {"rel": "buildings/green/building_watermill_green.gltf", "scale": 0.86, "yaw": 0.42},
	"coast_1": {"rel": "buildings/green/building_market_green.gltf", "scale": 0.76, "yaw": -0.48},
}

var _rng := RandomNumberGenerator.new()
var _root: Node3D
var _terrain: Node3D
var _markers: Node3D
var _grove: Node3D
var _path_scene: Node3D
var _hex_floor: Node3D
var _cache: Dictionary = {}
var _path_samples: PackedVector3Array = PackedVector3Array()
var _grass_cells: Array[Vector2i] = []
var _water_cells: Array[Vector2i] = []
var _tree_count := 0
var _prop_count := 0
var _ponds: Array[Dictionary] = []


func _init() -> void:
	_rng.seed = 20260830
	_setup_pond_specs()

	_root = Node3D.new()
	_root.name = "WorldMap"
	_root.set_script(load("res://scripts/ui/world_map.gd"))

	_build_environment()
	_build_sky_dome()
	_build_light()
	_build_camera()

	_terrain = Node3D.new()
	_terrain.name = "HexTerrain"
	_add(_root, _terrain)

	_markers = Node3D.new()
	_markers.name = "StageMarkers"
	_add(_root, _markers)

	var floaters := Node3D.new()
	floaters.name = "Floaters"
	_add(_root, floaters)

	_build_ground()
	_build_hex_floor()
	_build_dirt_path()
	_build_stage_pads()
	_build_ponds()
	_build_floaters()
	_build_atmosphere()

	_grove = Node3D.new()
	_grove.name = "Grove"
	_add(_terrain, _grove)
	_plant_forest()

	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err != OK:
		printerr("pack 失败: ", error_string(err))
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT_PATH)
	if err != OK:
		printerr("保存失败: ", error_string(err))
		quit(1)
		return
	print("已生成 %s" % OUT_PATH)
	print("  六边格 %d 块 / 树木 %d 棵 / 点缀 %d 件 / 关卡节点 %d 个" % [
		_hex_floor.get_child_count() if _hex_floor != null else 0,
		_tree_count, _prop_count, _markers.get_child_count()
	])
	quit()


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = _root


func _own_descendants(node: Node) -> void:
	for child in node.get_children():
		child.owner = _root
		_own_descendants(child)


func _path_at(t: float) -> Vector3:
	# 俯视时路从左到右蜿蜒，六关横向铺开。
	var x := -8.6 + 17.4 * t + 0.85 * sin(t * 2.5)
	var z := 0.15 + 2.25 * sin(t * 2.2)
	return Vector3(x, 0.0, z)


func _build_path_samples() -> void:
	_path_samples.clear()
	for i in 56:
		_path_samples.append(_path_at(float(i) / 55.0))


func _dist_to_path(pos: Vector3) -> float:
	var best := INF
	for p in _path_samples:
		best = minf(best, Vector2(pos.x - p.x, pos.z - p.z).length())
	return best


func _near_stage(pos: Vector3, radius: float) -> bool:
	if _markers != null:
		for child in _markers.get_children():
			if not (child is Node3D):
				continue
			var pad := (child as Node3D).position
			if Vector2(pos.x - pad.x, pos.z - pad.z).length() < radius:
				return true
		if _markers.get_child_count() > 0:
			return false
	for t in STAGE_T:
		var pad := _path_at(float(t))
		if Vector2(pos.x - pad.x, pos.z - pad.z).length() < radius:
			return true
	return false


func _setup_pond_specs() -> void:
	_ponds.clear()


func _in_pond(pos: Vector3, extra := 0.0) -> bool:
	var limit := HEX_W * 0.56 + extra
	for cell in _water_cells:
		var c := _hex_pos(cell.x, cell.y)
		if Vector2(pos.x - c.x, pos.z - c.z).length() < limit:
			return true
	return false


func _is_land(col: int, row: int) -> bool:
	# 铺满第一屏：椭圆盖住俯视镜头下的地面，外圈溶进云雾。
	var nx := float(col) / 10.5
	var nz := float(row) / 9.0
	var wobble := 0.08 * sin(float(col) * 0.7 + float(row) * 0.9)
	return nx * nx + nz * nz <= 1.08 + wobble


func _is_core_land(col: int, row: int) -> bool:
	# 关卡与乔木仍集中在岛心，避免外圈长成密林。
	var nx := float(col) / 6.0
	var nz := float(row) / 4.0
	var wobble := 0.13 * sin(float(col) * 1.05 + float(row) * 0.8)
	return nx * nx + nz * nz <= 0.90 + wobble


func _is_inland_water(col: int, row: int) -> bool:
	if not _is_land(col, row):
		return false
	# 岛中央一片湖，外围全是草地格。
	return float(col) * float(col) + float(row) * float(row) <= 4.2


func _path_side_dir(t: float) -> Vector3:
	var p := _path_at(t)
	var nxt := _path_at(minf(t + 0.03, 1.0))
	var dir := Vector3(nxt.x - p.x, 0.0, nxt.z - p.z)
	if dir.length_squared() < 0.0001:
		return Vector3.RIGHT
	dir = dir.normalized()
	return Vector3(-dir.z, 0.0, dir.x)


func _build_environment() -> void:
	var env := Environment.new()
	WorldMap._apply_pond_skybox(env)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.50, 0.56)
	env.ambient_light_energy = 0.10
	env.ambient_light_sky_contribution = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.78
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.86, 0.94)
	env.fog_density = 0.0008
	env.glow_enabled = true
	env.glow_intensity = 0.08
	env.glow_bloom = 0.02
	var holder := WorldEnvironment.new()
	holder.name = "MapEnv"
	holder.environment = env
	_add(_root, holder)


func _build_sky_dome() -> void:
	var sky_tex := load("res://my_asset/sky.png") as Texture2D
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = sky_tex
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	var bed := MeshInstance3D.new()
	bed.name = "SkyBed"
	bed.mesh = _flat_quad(96.0)
	bed.position = Vector3(0.5, 28.0, -40.0)
	bed.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	bed.set_surface_override_material(0, mat)
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bed.extra_cull_margin = 80.0
	_add(_root, bed)


func _build_light() -> void:
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation = Vector3(deg_to_rad(-34.0), deg_to_rad(58.0), 0.0)
	key.light_energy = 0.78
	key.light_color = Color(0.98, 0.94, 0.86)
	key.shadow_enabled = true
	key.shadow_blur = 1.4
	key.directional_shadow_max_distance = 80.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.shadow_normal_bias = 0.5
	key.shadow_bias = 0.04
	key.light_angular_distance = 2.4
	key.shadow_opacity = 0.82
	_add(_root, key)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation = Vector3(deg_to_rad(-16.0), deg_to_rad(-118.0), 0.0)
	fill.light_energy = 0.06
	fill.light_color = Color(0.55, 0.68, 0.88)
	_add(_root, fill)

	var bounce := DirectionalLight3D.new()
	bounce.name = "BounceLight"
	bounce.rotation = Vector3(deg_to_rad(58.0), deg_to_rad(20.0), 0.0)
	bounce.light_energy = 0.03
	bounce.light_color = Color(0.55, 0.72, 0.42)
	_add(_root, bounce)


func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "MapCamera"
	camera.fov = 46.0
	camera.far = 400.0
	camera.position = Vector3(0.4, 16.0, 13.0)
	camera.rotation = Vector3(deg_to_rad(-52.0), 0.0, 0.0)
	_add(_root, camera)


func _hex_pos(col: int, row: int) -> Vector3:
	var x := HEX_W * (float(col) + (0.5 if posmod(row, 2) == 1 else 0.0))
	var z := HEX_H * float(row)
	return Vector3(x, 0.0, z)


func _hex_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var col := cell.x
	var row := cell.y
	var odd := posmod(row, 2) == 1
	var dx := 1 if odd else 0
	return [
		Vector2i(col + 1, row),
		Vector2i(col - 1, row),
		Vector2i(col + dx, row + 1),
		Vector2i(col + dx - 1, row + 1),
		Vector2i(col + dx, row - 1),
		Vector2i(col + dx - 1, row - 1),
	]


func _build_ground() -> void:
	_build_path_samples()
	var fill := MeshInstance3D.new()
	fill.name = "GroundFill"
	var plane := PlaneMesh.new()
	plane.size = Vector2(90.0, 90.0)
	fill.mesh = plane
	fill.position = Vector3(0.5, -0.62, 0.0)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.20, 0.42, 0.16)
	fill.set_surface_override_material(0, fill_mat)
	_add(_terrain, fill)


func _build_hex_floor() -> void:
	_hex_floor = Node3D.new()
	_hex_floor.name = "HexFloor"
	_add(_terrain, _hex_floor)
	_grass_cells.clear()
	_water_cells.clear()
	var land: Dictionary = {}
	for row in range(-11, 12):
		for col in range(-12, 13):
			if _is_land(col, row) and not _is_inland_water(col, row):
				land[Vector2i(col, row)] = true
	for key in land.keys():
		var cell: Vector2i = key
		_grass_cells.append(cell)
		_spawn_hex("tiles/base/hex_grass.gltf", cell, _hex_pos(cell.x, cell.y))
	for row in range(-11, 12):
		for col in range(-12, 13):
			if not _is_inland_water(col, row):
				continue
			var cell := Vector2i(col, row)
			_water_cells.append(cell)
			_spawn_hex("tiles/base/hex_water.gltf", cell, _hex_pos(cell.x, cell.y) + Vector3(0.0, -0.40, 0.0))


func _spawn_hex(rel: String, cell: Vector2i, pos: Vector3) -> Node3D:
	var scene := _load_asset(rel, HEXMAP)
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	node.name = "hex_%d_%d" % [cell.x, cell.y]
	node.position = pos
	node.set_meta("hex_q", cell.x)
	node.set_meta("hex_r", cell.y)
	_add(_hex_floor, node)
	_own_descendants(node)
	return node


func _build_hills() -> void:
	var hills := Node3D.new()
	hills.name = "Hills"
	_add(_terrain, hills)
	var specs := [
		{"pos": Vector3(-14.0, -1.3, -8.0), "scale": Vector3(9.0, 3.0, 7.0)},
		{"pos": Vector3(3.0, -1.5, -12.0), "scale": Vector3(12.0, 4.0, 8.0)},
		{"pos": Vector3(14.0, -1.2, -6.0), "scale": Vector3(8.0, 2.8, 6.5)},
		{"pos": Vector3(-16.0, -1.4, 3.0), "scale": Vector3(8.0, 3.0, 6.0)},
	]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.40, 0.16)
	mat.roughness = 1.0
	mat.metallic = 0.0
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var ball := MeshInstance3D.new()
		ball.name = "Hill_%d" % i
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 12
		mesh.rings = 8
		ball.mesh = mesh
		ball.position = spec["pos"]
		ball.scale = spec["scale"]
		ball.set_surface_override_material(0, mat)
		_add(hills, ball)


func _build_dirt_path() -> void:
	_path_scene = Node3D.new()
	_path_scene.name = "PathScene"
	_add(_terrain, _path_scene)


func _build_stage_pads() -> void:
	var pool: Array[Vector2i] = []
	for cell in _grass_cells:
		if absf(_hex_pos(cell.x, cell.y).z) < 4.4:
			pool.append(cell)
	if pool.size() < 6:
		pool = _grass_cells.duplicate()
	var used: Array[Vector2i] = []
	for i in STAGE_IDS.size():
		var target_x := -8.2 + 16.4 * float(i) / 5.0
		var best := Vector2i(0, 0)
		var best_d := INF
		for cell in pool:
			if used.has(cell):
				continue
			var p := _hex_pos(cell.x, cell.y)
			var blocked := false
			for other in used:
				var q := _hex_pos(other.x, other.y)
				if Vector2(p.x - q.x, p.z - q.z).length() < 3.2:
					blocked = true
					break
			if blocked:
				continue
			var d := absf(p.x - target_x) + absf(p.z) * 0.4
			if d < best_d:
				best_d = d
				best = cell
		assert(best_d < 12.0, "关卡 %s 找不到可落的六边格" % String(STAGE_IDS[i]))
		used.append(best)
		var pos := _hex_pos(best.x, best.y)
		var tile := _hex_floor.get_node_or_null("hex_%d_%d" % [best.x, best.y]) as Node3D
		if tile != null:
			tile.name = "pad_%s" % String(STAGE_IDS[i])
			_place_stage_building(tile, String(STAGE_IDS[i]))
		var marker := Node3D.new()
		marker.name = String(STAGE_IDS[i])
		marker.position = pos
		marker.set_meta("stage_id", String(STAGE_IDS[i]))
		_add(_markers, marker)


func _place_stage_building(tile: Node3D, stage_id: String) -> void:
	if not STAGE_BUILDINGS.has(stage_id):
		return
	var spec: Dictionary = STAGE_BUILDINGS[stage_id]
	var scene := _load_asset(String(spec["rel"]), HEXMAP)
	if scene == null:
		return
	var node := scene.instantiate() as Node3D
	node.name = "building_%s" % stage_id
	# 略往后坐，牌子仍对准格心，建筑当背景。
	node.position = Vector3(0.06, 0.0, -0.34)
	node.rotation = Vector3(0.0, float(spec["yaw"]), 0.0)
	node.scale = Vector3.ONE * float(spec["scale"])
	node.set_meta("stage_building", true)
	_add(tile, node)
	_own_descendants(node)


func _build_ponds() -> void:
	var host := Node3D.new()
	host.name = "Ponds"
	_add(_root, host)
	var i := 0
	for cell in _water_cells:
		var water := MeshInstance3D.new()
		water.name = "Pond_%d" % i
		water.mesh = _hex_disc_mesh(0.96)
		water.position = _hex_pos(cell.x, cell.y) + Vector3(0.0, -0.02, 0.0)
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(host, water)
		i += 1


func _build_floaters() -> void:
	var host := _root.get_node("Floaters") as Node3D
	var lilies: Array[String] = [
		"nature/waterlily_A.gltf", "nature/waterlily_B.gltf",
		"nature/waterplant_A.gltf", "nature/waterplant_B.gltf",
	]
	var n := 0
	for cell in _water_cells:
		var c := _hex_pos(cell.x, cell.y)
		for j in 2:
			var a := _rng.randf() * TAU
			var k := _rng.randf_range(0.12, 0.38)
			var pos := c + Vector3(cos(a) * k, 0.05, sin(a) * k)
			_place_model(
				host, lilies[(n + j) % lilies.size()],
				pos, _rng.randf_range(0.48, 0.68), _rng.randf() * TAU, HEX_DECO
			)
			_prop_count += 1
		n += 1


func _ellipse_mesh(rx: float, rz: float, y: float, segs: int, noise: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	verts.append(Vector3(0.0, y, 0.0))
	normals.append(Vector3.UP)
	uvs.append(Vector2(0.5, 0.5))
	for i in segs:
		var a := TAU * float(i) / float(segs)
		var wobble := 1.0 + 0.10 * sin(a * 3.0 + noise) + 0.06 * sin(a * 5.0 - noise)
		var x := cos(a) * rx * wobble
		var z := sin(a) * rz * wobble
		verts.append(Vector3(x, y, z))
		normals.append(Vector3.UP)
		uvs.append(Vector2(x / (rx * 2.0) + 0.5, z / (rz * 2.0) + 0.5))
	for i in segs:
		var i1 := i + 1
		var i2 := 1 if i == segs - 1 else i + 2
		indices.append_array([0, i1, i2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _hex_disc_mesh(flat_r: float) -> ArrayMesh:
	var vert_r := flat_r / cos(PI / 6.0)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	verts.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	uvs.append(Vector2(0.5, 0.5))
	for i in 6:
		var a := -PI * 0.5 + float(i) * PI / 3.0
		var x := cos(a) * vert_r
		var z := sin(a) * vert_r
		verts.append(Vector3(x, 0.0, z))
		normals.append(Vector3.UP)
		uvs.append(Vector2(x / (vert_r * 2.0) + 0.5, z / (vert_r * 2.0) + 0.5))
	for i in 6:
		indices.append_array([0, i + 1, 1 if i == 5 else i + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _annulus_mesh(inner_r: float, outer_r: float, segs: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in segs:
		var a := TAU * float(i) / float(segs)
		var ca := cos(a)
		var sa := sin(a)
		verts.append(Vector3(ca * inner_r, 0.0, sa * inner_r * 0.78))
		verts.append(Vector3(ca * outer_r, 0.0, sa * outer_r * 0.78))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, float(i) / float(segs)))
		uvs.append(Vector2(1.0, float(i) / float(segs)))
	for i in segs:
		var i0 := i * 2
		var i1 := i0 + 1
		var i2 := 0 if i == segs - 1 else i0 + 2
		var i3 := 1 if i == segs - 1 else i0 + 3
		indices.append_array([i0, i1, i3, i0, i3, i2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_atmosphere() -> void:
	var fx := Node3D.new()
	fx.name = "Atmosphere"
	_add(_terrain, fx)
	var ray_mat := StandardMaterial3D.new()
	ray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ray_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ray_mat.albedo_color = Color(1.0, 0.93, 0.68, 0.10)
	ray_mat.disable_receive_shadows = true
	for i in 6:
		var p := _hex_pos(-3 + i, -1)
		var quad := QuadMesh.new()
		quad.size = Vector2(0.7 + float(i % 3) * 0.18, 11.0)
		var mi := MeshInstance3D.new()
		mi.name = "GodRay_%d" % i
		mi.mesh = quad
		mi.position = p + Vector3(0.4, 6.0, -0.8)
		mi.rotation = Vector3(deg_to_rad(22.0), deg_to_rad(48.0), deg_to_rad(10.0))
		mi.set_surface_override_material(0, ray_mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(fx, mi)
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.albedo_color = Color(0.96, 0.98, 1.0)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.albedo_color.a = 0.92
	for i in 10:
		var a := TAU * float(i) / 10.0 + 0.2
		var r := 20.4 + float(i % 3) * 0.8
		var pos := Vector3(cos(a) * r, 1.35 + float(i % 4) * 0.55, sin(a) * r * 0.72)
		var rel := "nature/cloud_big.gltf" if i % 2 == 0 else "nature/cloud_small.gltf"
		var scene := _load_asset(rel, HEX_DECO)
		if scene == null:
			continue
		var node := scene.instantiate() as Node3D
		node.name = "Cloud_%d" % i
		node.position = pos
		node.rotation.y = a + 0.4
		node.scale = Vector3.ONE * (2.4 if i % 2 == 0 else 1.8)
		_add(fx, node)
		_own_descendants(node)
		_paint_unshaded(node, cloud_mat)


func _paint_unshaded(node: Node, mat: Material) -> void:
	var mesh_node := node as MeshInstance3D
	if mesh_node != null:
		mesh_node.set_surface_override_material(0, mat)
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_paint_unshaded(child, mat)


func _plant_forest() -> void:
	var pines: Array[String] = ["Pine_1.gltf", "Pine_2.gltf", "Pine_3.gltf", "Pine_4.gltf", "Pine_5.gltf"]
	var commons: Array[String] = [
		"CommonTree_1.gltf", "CommonTree_2.gltf", "CommonTree_3.gltf",
		"CommonTree_4.gltf", "CommonTree_5.gltf",
	]
	var grasses: Array[String] = [
		"Grass_Common_Short.gltf", "Grass_Common_Tall.gltf",
		"Grass_Wispy_Short.gltf", "Grass_Wispy_Tall.gltf",
	]
	var cover: Array[String] = [
		"Fern_1.gltf", "Plant_1.gltf", "Plant_1_Big.gltf",
		"Flower_3_Group.gltf", "Flower_4_Group.gltf",
		"Clover_1.gltf", "Clover_2.gltf",
	]
	var bushes: Array[String] = ["Bush_Common.gltf", "Bush_Common_Flowers.gltf"]
	var rocks: Array[String] = ["Rock_Medium_1.gltf", "Rock_Medium_2.gltf", "Rock_Medium_3.gltf"]
	var occupied: Array[Dictionary] = []
	var tree_i := 0
	for cell in _grass_cells:
		if not _is_core_land(cell.x, cell.y):
			continue
		var pos := _hex_pos(cell.x, cell.y)
		if _near_stage(pos, 1.55) or pos.z > 3.4:
			continue
		var rim := _is_rim_cell(cell)
		var chance := 0.72 if rim else 0.18
		if _rng.randf() > chance:
			continue
		var use_pine := _rng.randf() < 0.7
		var path := pines[tree_i % pines.size()] if use_pine else commons[tree_i % commons.size()]
		_plant_tree(path, pos, _rng.randf_range(0.42, 0.56), _rng.randf() * TAU, 1.08, occupied)
		tree_i += 1
	if _tree_count < 10:
		for cell in _grass_cells:
			if _tree_count >= 12:
				break
			if not _is_core_land(cell.x, cell.y):
				continue
			var pos := _hex_pos(cell.x, cell.y)
			if _near_stage(pos, 1.55) or pos.z > 3.4:
				continue
			_plant_tree(pines[_tree_count % pines.size()], pos, 0.48, 0.2, 1.08, occupied, true)

	for cell in _grass_cells:
		var pos := _hex_pos(cell.x, cell.y)
		if _near_stage(pos, 1.35):
			continue
		var core := _is_core_land(cell.x, cell.y)
		if core and _rng.randf() < 0.16:
			_place_model(
				_grove, bushes[_rng.randi() % bushes.size()], pos,
				_rng.randf_range(0.40, 0.55), _rng.randf() * TAU
			)
			_prop_count += 1
		if core and _rng.randf() < 0.12:
			_place_model(
				_grove, rocks[_rng.randi() % rocks.size()], pos,
				_rng.randf_range(0.18, 0.32), _rng.randf() * TAU
			)
			_prop_count += 1
		_place_model(
			_grove, grasses[_rng.randi() % grasses.size()],
			pos + Vector3(_rng.randf_range(-0.28, 0.28), 0.0, _rng.randf_range(-0.28, 0.28)),
			_rng.randf_range(0.46, 0.66), _rng.randf() * TAU
		)
		_prop_count += 1
		if _rng.randf() < (0.28 if core else 0.16):
			_place_model(
				_grove, cover[_rng.randi() % cover.size()],
				pos + Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3)),
				_rng.randf_range(0.38, 0.56), _rng.randf() * TAU
			)
			_prop_count += 1
		if core and _rng.randf() < 0.08:
			_place_model(
				_grove, "Mushroom_Common.gltf" if _rng.randf() < 0.6 else "Mushroom_Laetiporus.gltf",
				pos, _rng.randf_range(0.22, 0.38), _rng.randf() * TAU
			)
			_prop_count += 1



func _plant_tree(
	path: String, pos: Vector3, scale_factor: float, yaw: float, radius: float,
	occupied: Array[Dictionary], force := false
) -> void:
	if not force and _blocks_stage_view(pos):
		return
	if not _gap_free(occupied, pos, radius):
		return
	_place_model(_grove, path, pos, scale_factor, yaw)
	occupied.append({"pos": pos, "radius": radius})
	_tree_count += 1


func _blocks_stage_view(pos: Vector3) -> bool:
	if _in_pond(pos, 0.2):
		return true
	if pos.z > 4.8 and absf(pos.x) < 8.0:
		return true
	return _near_stage(pos, 2.4)


func _is_rim_cell(cell: Vector2i) -> bool:
	for n in _hex_neighbors(cell):
		if _water_cells.has(n):
			return true
		if _is_core_land(cell.x, cell.y) and not _is_core_land(n.x, n.y):
			return true
	return false


func _occludes_pond(pos: Vector3) -> bool:
	for spec in _ponds:
		var c: Vector3 = spec["pos"]
		var rx: float = float(spec["rx"]) + 2.4
		var rz: float = float(spec["rz"]) + 3.2
		var dx := pos.x - c.x
		var dz := pos.z - c.z
		if absf(dx) < rx and dz > 0.0 and dz < rz:
			return true
	return false


func _path_z_at_x(x: float) -> float:
	var best_z := 0.8
	var best_dx := INF
	for p in _path_samples:
		var dx := absf(p.x - x)
		if dx < best_dx:
			best_dx = dx
			best_z = p.z
	return best_z


func _gap_free(occupied: Array[Dictionary], pos: Vector3, radius: float) -> bool:
	for item in occupied:
		var other: Vector3 = item["pos"]
		var need := maxf(radius + float(item["radius"]) + 0.18, TREE_MIN_GAP)
		if Vector2(pos.x - other.x, pos.z - other.z).length() < need:
			return false
	return true


func _ribbon_mesh(points: PackedVector3Array, width: float, y: float, _color: Color) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half := width * 0.5
	var u := 0.0
	for i in points.size():
		var p: Vector3 = points[i]
		var dir := Vector3(0.0, 0.0, -1.0)
		if i < points.size() - 1:
			dir = points[i + 1] - p
		elif i > 0:
			dir = p - points[i - 1]
		dir.y = 0.0
		if dir.length_squared() < 0.0001:
			dir = Vector3(0.0, 0.0, -1.0)
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0.0, dir.x) * half
		var left := Vector3(p.x, y, p.z) - side
		var right := Vector3(p.x, y, p.z) + side
		verts.append(left)
		verts.append(right)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, u))
		uvs.append(Vector2(1.0, u))
		if i > 0:
			u += 0.18
			var i0 := (i - 1) * 2
			indices.append_array([i0, i0 + 1, i0 + 3, i0, i0 + 3, i0 + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _flat_quad(size: float) -> ArrayMesh:
	var h := size * 0.5
	var verts := PackedVector3Array([
		Vector3(-h, 0.0, -h), Vector3(h, 0.0, -h), Vector3(h, 0.0, h), Vector3(-h, 0.0, h)
	])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _place_model(
	group: Node3D, relative_path: String, pos: Vector3, scale_factor: float, yaw: float,
	base := NATURE
) -> void:
	var scene: PackedScene = _load_asset(relative_path, base)
	if scene == null:
		return
	var node := scene.instantiate()
	node.name = "%s_%d" % [relative_path.get_file().get_basename(), group.get_child_count()]
	node.position = pos
	node.rotation = Vector3(0.0, yaw, 0.0)
	node.scale = Vector3.ONE * scale_factor
	var stem := relative_path.get_file().get_basename()
	var is_rock := stem.begins_with("Rock") or stem.begins_with("Pebble")
	if not is_rock:
		node.set_meta("flora", true)
		var is_tree := (
			stem.begins_with("Pine") or stem.begins_with("CommonTree")
			or stem.begins_with("TwistedTree") or stem.begins_with("DeadTree")
		)
		node.set_meta("flora_tree", is_tree)
	_add(group, node)
	_own_descendants(node)


func _load_asset(relative_path: String, base := NATURE) -> PackedScene:
	var key := base + relative_path
	if _cache.has(key):
		return _cache[key]
	var scene := load(key) as PackedScene
	if scene == null:
		printerr("素材缺失: ", key)
	_cache[key] = scene
	return scene
