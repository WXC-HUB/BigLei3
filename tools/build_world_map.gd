extends SceneTree
## 一次性布局生成工具 —— 产出 `scenes/world_map.tscn` 的第一版摆位。
##
## 跑法：`godot --headless --script tools/build_world_map.gd`
##
## 跑完之后这个 .tscn 就是一份**普通的可手改场景**：在编辑器里拖地格、换装饰、挪关卡
## 节点都随意，本工具不会再自动跑（除非你想重置整张图）。FEAT-002 共识 3 定的是"布局
## 手摆在场景里当美术资产"，本工具只负责把 150 个节点的初稿铺出来，免得从空场景开始
## 一个个拖。
##
## 三个地形区靠**不需要定向的地格**拉开差异 —— `hex_grass` 与 `hex_water` 都是六向对
## 称的，摆下去不用管旋转：
##   青草区：整片草地            → 内陆
##   河谷区：草地被一条水带切开  → 河谷
##   海岸区：中心草地 + 外圈环海  → 孤岛
## 素材包里的 `tiles/roads` `tiles/rivers` `tiles/coast` 需要按邻接方向定向才能接得上，
## 那是一套连通性求解，不在本期范围 —— 想要更精致的岸线和道路，在编辑器里手换。

const OUT_PATH := "res://scenes/world_map.tscn"
const HEX := "res://assets/hexmap/"

## 地格实测尺寸：X = 2.0、Z = 2.309(=4/√3)、顶面在 y = 0。由此得轴向坐标公式。
const HEX_STEP_X := 2.0
const HEX_STEP_Z := 1.7320508
## 水面压低一点，读起来才是"水在地下面"而不是"另一块地板"。
const WATER_Y := -0.18

const DIRS := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

## 每个区：中心轴向坐标 + 半径 + 主题。半径 3 是 37 格，再补一圈残缺的第 4 环到 ~50 格。
const REGION_LAYOUT := [
	{"id": "grass", "center": Vector2i(0, 0), "radius": 3},
	{"id": "river", "center": Vector2i(9, -2), "radius": 3},
	{"id": "coast", "center": Vector2i(18, -3), "radius": 3},
]

## 每区的地标建筑，按关卡序依次取用。绿色阵营那套，和鸟类主题的暖色调不打架。
const LANDMARKS := {
	"grass": [
		"buildings/green/building_home_A_green.gltf",
		"buildings/green/building_windmill_green.gltf",
		"buildings/green/building_well_green.gltf",
		"buildings/green/building_home_B_green.gltf",
		"buildings/green/building_church_green.gltf",
		"buildings/green/building_tower_A_green.gltf",
	],
	"river": [
		"buildings/green/building_watermill_green.gltf",
		"buildings/neutral/building_bridge_A.gltf",
		"buildings/green/building_lumbermill_green.gltf",
		"buildings/neutral/building_bridge_B.gltf",
		"buildings/green/building_market_green.gltf",
		"buildings/green/building_tavern_green.gltf",
	],
	"coast": [
		"buildings/green/building_tower_B_green.gltf",
		"buildings/green/building_barracks_green.gltf",
		"buildings/green/building_blacksmith_green.gltf",
		"buildings/green/building_mine_green.gltf",
		"buildings/green/building_tower_catapult_green.gltf",
		"buildings/green/building_castle_green.gltf",
	],
}

const LAND_DECOR := [
	"decoration/nature/trees_A_large.gltf",
	"decoration/nature/trees_A_medium.gltf",
	"decoration/nature/trees_A_small.gltf",
	"decoration/nature/trees_B_large.gltf",
	"decoration/nature/trees_B_medium.gltf",
	"decoration/nature/trees_B_small.gltf",
	"decoration/nature/tree_single_A.gltf",
	"decoration/nature/tree_single_B.gltf",
	"decoration/nature/rock_single_A.gltf",
	"decoration/nature/rock_single_C.gltf",
	"decoration/nature/hill_single_A.gltf",
	"decoration/nature/hills_A_trees.gltf",
]
const WATER_DECOR := [
	"decoration/nature/waterlily_A.gltf",
	"decoration/nature/waterlily_B.gltf",
	"decoration/nature/waterplant_A.gltf",
	"decoration/nature/waterplant_C.gltf",
]

var _rng := RandomNumberGenerator.new()
var _root: Node3D
var _terrain: Node3D
var _markers: Node3D
var _cache: Dictionary = {}
var _tile_count := 0
var _decor_count := 0


func _init() -> void:
	# 固定种子：同一份代码永远产出同一张图，便于对照与重跑。
	_rng.seed = 20260824

	_root = Node3D.new()
	_root.name = "WorldMap"
	_root.set_script(load("res://scripts/ui/world_map.gd"))

	_build_environment()
	_build_light()
	_build_camera()

	_terrain = Node3D.new()
	_terrain.name = "HexTerrain"
	_add(_root, _terrain)

	_markers = Node3D.new()
	_markers.name = "StageMarkers"
	_add(_root, _markers)

	for layout in REGION_LAYOUT:
		_build_region(layout)

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
	print("  地格 %d 块 / 装饰 %d 个 / 关卡节点 %d 个" % [
		_tile_count, _decor_count, _markers.get_child_count()
	])
	quit()


## pack() 只会收 owner 指向根的节点。gltf 实例本身要设 owner（于是被记成 instance=），
## 它内部的子节点不设（跟着实例走）。
func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = _root


## 背景走一层柔和的天空渐变，而不是一块死平的纯色——视角放平之后画面上半部分全是背景，
## 纯色会显得空。颜色压在低饱和的暖粉到浅青之间，把地块的绿衬出来又不抢戏。
func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.714, 0.780, 0.855)
	sky_material.sky_horizon_color = Color(0.925, 0.878, 0.855)
	sky_material.ground_horizon_color = Color(0.902, 0.851, 0.831)
	sky_material.ground_bottom_color = Color(0.847, 0.792, 0.788)
	sky_material.sun_angle_max = 1.0
	sky_material.energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# 背景用天空渐变，但**环境光走显式颜色**，不取天空。
	#
	# 踩过的坑：`AMBIENT_SOURCE_SKY` 的实际强度远不止 `ambient_light_energy` 这个数字——
	# 它是整个天空半球的辐照度乘以这个系数，还会连带开启天空反射。朝上的地格顶面把这份
	# 光吃满，而草地图集的原色本来就是黄绿（0.64, 0.66, 0.13，蓝通道极低），再乘上去绿
	# 通道先削顶、红通道跟上，整片地格就冲成了荧光黄。改成显式颜色后亮度完全可控，冷蓝
	# 的环境色照样能和暖色主光形成冷暖对比。
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.616, 0.678, 0.804)
	env.ambient_light_energy = 0.15
	env.ambient_light_sky_contribution = 0.0
	# 素材是无光照色块风格，镜面反射只会在平坦的六边形顶面上糊一层灰。
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var holder := WorldEnvironment.new()
	holder.name = "MapEnv"
	holder.environment = env
	_add(_root, holder)


## 三点布光。素材是无光照色块图集，真正塑形的是这三盏灯的方向差：
##   主光  暖白，左上前方斜射，唯一开阴影的一盏——地格之间、树与地面之间的接触阴影
##         是"这些东西真的立在那儿"的主要证据。
##   补光  冷蓝，右后方低角度，只有主光的三分之一，负责把背光面从死黑里捞回来并染上天光。
##   反弹  暖橙，从下方往上打，很弱，模拟地面把阳光弹回物体底部，去掉低模常见的"悬空感"。
func _build_light() -> void:
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation = Vector3(deg_to_rad(-46.0), deg_to_rad(-42.0), 0.0)
	key.light_energy = 0.38
	key.light_color = Color(1.0, 0.965, 0.906)
	key.shadow_enabled = true
	# 卡通风格要的是清晰但不锐利的阴影边——全糊掉就没有接触感，全硬又会有锯齿。
	key.shadow_blur = 1.6
	key.directional_shadow_max_distance = 70.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# 偏移是把双刃剑：给小了受光面撒摩尔纹，给大了阴影整个被推离物体、树底下干干净净。
	# 1.6 就属于后者，实测下来 0.5 左右两边都还行。
	key.shadow_normal_bias = 0.5
	key.shadow_bias = 0.02
	# 地图整体约 60 单位宽，把阴影范围收到刚好包住它，同样的阴影贴图分辨率就能换来更
	# 锐利的边——范围给到 120 时一棵树的投影只占几个像素，糊成一团看不出是什么。
	key.directional_shadow_split_1 = 0.12
	_add(_root, key)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(138.0), 0.0)
	fill.light_energy = 0.10
	fill.light_color = Color(0.729, 0.808, 0.925)
	fill.shadow_enabled = false
	_add(_root, fill)

	var bounce := DirectionalLight3D.new()
	bounce.name = "BounceLight"
	bounce.rotation = Vector3(deg_to_rad(62.0), deg_to_rad(28.0), 0.0)
	bounce.light_energy = 0.045
	bounce.light_color = Color(0.980, 0.898, 0.796)
	bounce.shadow_enabled = false
	_add(_root, bounce)


func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "MapCamera"
	camera.fov = 60.0
	camera.far = 400.0
	# 具体位置由 world_map.gd 每次 present() 时按 pivot 与视距算，这里只给个初值，
	# 让场景在编辑器里打开时就能看到东西。
	camera.position = Vector3(0.0, 12.0, 18.5)
	camera.rotation = Vector3(deg_to_rad(-33.0), 0.0, 0.0)
	_add(_root, camera)


func _build_region(layout: Dictionary) -> void:
	var region_id := String(layout["id"])
	var center: Vector2i = layout["center"]
	var radius := int(layout["radius"])

	var cells: Array[Vector2i] = _blob(center, radius)
	var marker_cells: Array[Vector2i] = _marker_cells(center)
	var stages := StageTable.stages_in_region(region_id)
	var landmarks: Array = LANDMARKS[region_id]

	var group := Node3D.new()
	group.name = "Region_" + region_id
	_add(_terrain, group)

	for cell: Vector2i in cells:
		var local: Vector2i = cell - center
		var water := _is_water(region_id, local, center, cell, radius)
		var is_marker := marker_cells.has(cell)
		if is_marker:
			water = false
		_place_tile(group, cell, water)
		if is_marker:
			continue
		_maybe_decorate(group, cell, water)

	# 关卡节点：只是一个带 stage_id 的空 Node3D，悬浮牌靠它的世界坐标定位。
	# 地标建筑单独摆在同一格上，属于地形组——手改时可以随便换掉而不影响关卡逻辑。
	for index in mini(stages.size(), marker_cells.size()):
		var marker_cell: Vector2i = marker_cells[index]
		var stage: Dictionary = stages[index]
		var marker := Node3D.new()
		marker.name = String(stage["id"])
		marker.position = _axial_to_world(marker_cell)
		marker.set_meta("stage_id", String(stage["id"]))
		_add(_markers, marker)
		if index < landmarks.size():
			_place_model(group, landmarks[index], marker_cell, 0.0, 1.0, _snap_yaw(index))


## 半径内的全部格子，外加一圈残缺的第 4 环——正六边形轮廓太规整，缺几块才像块陆地。
func _blob(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dq in range(-radius - 1, radius + 2):
		for dr in range(-radius - 1, radius + 2):
			var cell := center + Vector2i(dq, dr)
			var dist := _hex_distance(center, cell)
			if dist <= radius:
				out.append(cell)
			elif dist == radius + 1 and _rng.randf() < 0.42:
				out.append(cell)
	return out


## 6 个关卡落在第 2 环的六个"角"上，彼此隔得最开。
func _marker_cells(center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir in DIRS:
		out.append(center + dir * 2)
	return out


## 水的分布决定了三个区的轮廓：
##   grass 全陆；river 在 r_local == 1 切一条水带（正好绕开 6 个关卡格）；
##   coast 中心 2 环是陆、再往外全是海。
func _is_water(
	region_id: String, local: Vector2i, center: Vector2i, cell: Vector2i, radius: int
) -> bool:
	match region_id:
		"river":
			return local.y == 1
		"coast":
			return _hex_distance(center, cell) > radius - 1
		_:
			return false


func _maybe_decorate(group: Node3D, cell: Vector2i, water: bool) -> void:
	var pool: Array = WATER_DECOR if water else LAND_DECOR
	var chance := 0.55 if water else 0.62
	if _rng.randf() > chance:
		return
	var model: String = pool[_rng.randi_range(0, pool.size() - 1)]
	# 装饰在格子里随机偏一点，别每个都钉在正中心。
	var jitter := Vector3(_rng.randf_range(-0.35, 0.35), 0.0, _rng.randf_range(-0.35, 0.35))
	var y := WATER_Y if water else 0.0
	_place_model(
		group, model, cell, y, _rng.randf_range(0.85, 1.12),
		_rng.randf_range(0.0, TAU), jitter
	)
	_decor_count += 1


func _place_tile(group: Node3D, cell: Vector2i, water: bool) -> void:
	var model := "tiles/base/hex_water.gltf" if water else "tiles/base/hex_grass.gltf"
	# 六向对称，旋转只为打散贴图上的细微重复感，不影响接缝。
	_place_model(group, model, cell, WATER_Y if water else 0.0, 1.0, _snap_yaw(_rng.randi()))
	_tile_count += 1


func _place_model(
	group: Node3D,
	relative_path: String,
	cell: Vector2i,
	y: float,
	scale_factor: float,
	yaw: float,
	jitter := Vector3.ZERO
) -> void:
	var scene: PackedScene = _load_model(relative_path)
	if scene == null:
		return
	var node := scene.instantiate()
	node.name = "%s_%d_%d" % [relative_path.get_file().get_basename(), cell.x, cell.y]
	node.position = _axial_to_world(cell) + Vector3(0.0, y, 0.0) + jitter
	node.rotation = Vector3(0.0, yaw, 0.0)
	if not is_equal_approx(scale_factor, 1.0):
		node.scale = Vector3.ONE * scale_factor
	_add(group, node)


func _load_model(relative_path: String) -> PackedScene:
	if _cache.has(relative_path):
		return _cache[relative_path]
	var scene := load(HEX + relative_path) as PackedScene
	if scene == null:
		printerr("素材缺失: ", HEX + relative_path)
	_cache[relative_path] = scene
	return scene


## 六边形只在 60° 的整数倍上自洽，别的角度会露接缝。
func _snap_yaw(step: int) -> float:
	return float(step % 6) * TAU / 6.0


func _axial_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		HEX_STEP_X * (float(cell.x) + float(cell.y) * 0.5),
		0.0,
		HEX_STEP_Z * float(cell.y)
	)


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return int((absi(dq) + absi(dq + dr) + absi(dr)) / 2.0)
