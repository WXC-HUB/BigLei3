class_name WorldMap
extends Node3D
## 世界地图（World Map）——六边形 3D 选关屏。
##
## 场景 `scenes/world_map.tscn` 里只有 3D 布局（地格、装饰、关卡节点、相机、光），
## 那是可以在编辑器里自由手改的美术资产。所有 UI（悬浮牌、顶栏、续局条、确认卡）都
## 由本脚本在运行时搭起来，和项目里 `main.gd` 的 `_build_*` 一套做法一致——这样手改
## 场景不会一保存就把运行时挂上去的节点抹掉。
##
## 关卡数据一律去 [StageTable] 查；场景里的关卡节点只带一个 `stage_id` 元数据。

signal stage_selected(stage_id: String)
signal title_requested
signal resume_requested
signal abandon_requested
signal leaderboard_requested(stage_id: String)
signal all_leaderboards_requested
## 选关图随机事件达成成就时上报，和四个解锁页的彩蛋同一根线接到 Main。
signal easter_egg_triggered(achievement_id: String)

## 悬浮牌离地面的高度。建筑在关卡格上，牌子再抬一点免得扎进屋顶。
const BADGE_LIFT := 1.62
## 相机俯角。略侧俯，既能读出六边格顶面，也能看见格厚。
const CAMERA_PITCH_DEG := -52.0
## 正对地图，岛从左到右。
const CAMERA_YAW_DEG := 0.0
## 框定关卡时在算出的视距上再留边。
const FIT_PADDING := 1.12
## 关卡包围盒外扩，吃进岸边六边格，把云雾留给屏幕外圈。
const FIT_MARGIN := 2.4
## 关卡落点外描边：圆环，套在原木上。
const HEX_OUTLINE_RADIUS := 1.15
const HEX_OUTLINE_THICKNESS := 0.12
const HEX_OUTLINE_Y := 0.42
## 关卡行进路径：地面色带，把 1→6 的前后关系画出来。
const PATH_Y := 0.11
const PATH_WIDTH := 0.16
const PATH_OPEN := Color(0.78, 0.56, 0.28, 0.42)
const PATH_LOCKED := Color(0.52, 0.38, 0.22, 0.22)
## 悬停描边绕 Y 轴缓慢自转（弧度/秒）。
const HEX_OUTLINE_SPIN_SPEED := 0.7
## 把关卡节点对齐到地格时，平面距离小于此值即视为同一格。
const TILE_BIND_EPSILON := 0.35
## 悬停时地格（及同格装饰）向上抬起的高度。
const TILE_HOVER_LIFT := 0.30
const TILE_HOVER_DURATION := 0.14
const TILE_OUTLINE_DEFAULT := Color(1.0, 0.92, 0.55, 0.92)
## 地面拾取兜底：点到地格中心多远内算悬停在这一格（KayKit 六边中心到顶点 ≈ 1）。
const TILE_PICK_RADIUS := 1.05
## 地格碰撞层（bit1 = layer 2），专给地图悬停射线用，不跟别的物理搅在一起。
const TILE_PICK_COLLISION_LAYER := 2
## 鼠标面包屑：指针移动时才落屑；静止不刷，避免鸽子原地抽搐啄食。
const CRUMB_EMIT_INTERVAL := 0.055
const CRUMB_MOVE_THRESHOLD := 2.5
const CRUMB_LIFETIME := 1.85
const CRUMB_FADE := 0.3
const CRUMB_MAX := 56
const CRUMB_COLLISION_LAYER := 4
## 左右键落下的大面包：颜色不同，要啃很多口才没；彼此会撞、外形是整条面包。
const LOAF_SIZE := Vector3(0.78, 0.32, 0.42)
## 一口一跳落地；跳频 11 时约 0.29s/口，18 口 ≈ 一只鸟啄 5 秒。
const LOAF_BITES := 18
const LOAF_EAT_RADIUS := 1.25
const LOAF_MAX := 10
const LOAF_LIFETIME := 120.0
const LOAF_SETTLE_TIME := 0.55
const LOAF_LEFT_COLOR := Color(0.93, 0.74, 0.42)
const LOAF_RIGHT_COLOR := Color(0.62, 0.34, 0.28)
const LOAF_CRUST_DARK := 0.72
const LOAF_FOOD_MASK := CRUMB_COLLISION_LAYER | TILE_PICK_COLLISION_LAYER
## 跳跳鸽：用红隼页同一套鸽子面片，蹦着追面包屑；没屑时走走停停。
const HOP_PIGEON_COUNT := 9
const HOP_SPEED := 3.35
const HOP_LOAF_SPEED := 4.4
const HOP_WANDER_SPEED := 1.55
const HOP_HEIGHT := 0.48
const HOP_FREQ := 11.0
const HOP_WANDER_FREQ := 6.5
const HOP_ARRIVE_RADIUS := 0.12
const HOP_REST_MIN := 0.7
const HOP_REST_MAX := 2.1
const HOP_EAT_RADIUS := 0.42
## 落地附近即可啄；冷却约一跳一轮，避免靠边沿检测漏啄。
const HOP_PECK_INTERVAL := 0.28
const HOP_PECK_GROUND := 0.4
const HOP_PIXEL_SIZE := 0.00315
const HOP_PIGEON_TEXTURES: Array[Texture2D] = [
	preload("res://my_asset/birds/pigeons/pigeon_blue_gray.png"),
	preload("res://my_asset/birds/pigeons/pigeon_cream.png"),
	preload("res://my_asset/birds/pigeons/pigeon_dark_green.png"),
	preload("res://my_asset/birds/pigeons/pigeon_russet.png"),
	preload("res://my_asset/birds/pigeons/pigeon_violet_gray.png"),
]
## 植被/树木悬停：独立碰撞层，不挡关卡地格拾取。
const FLORA_PICK_COLLISION_LAYER := 8
const FLORA_KIND_SHAKE := 0
const FLORA_KIND_SONG := 1
const FLORA_KIND_BREAD := 2
## 悬停大多只抖一下；唱歌、掉面包是少见彩蛋。
const FLORA_SHAKE_CHANCE := 0.88
const FLORA_SONG_CHANCE := 0.07
const FLORA_BREAD_CHANCE := 0.05
const FLORA_NOTE_GLYPHS := ["♪", "♫", "♬", "♩"]
const FLORA_NOTE_FONT := preload("res://assets/fonts/eva_ming_sc.otf")
const FLORA_NOTES_PER_BURST := 14
const FLORA_NOTE_LIMIT := 72
## 名单页同一套鸟鸣：悬停植被时随机抽一只的叫声。
const FLORA_BIRD_CALLS: Array[AudioStream] = [
	preload("res://assets/audio/blue_bird_find.mp3"),
	preload("res://assets/audio/red_bird_compass.wav"),
	preload("res://assets/audio/black_bird_lantern.mp3"),
	preload("res://assets/audio/attacker_peck.wav"),
	preload("res://assets/audio/eg_super_luck_trigger.mp3"),
]
const FLORA_BIRD_TINTS: Array[Color] = [
	Color(0.42, 0.72, 1.0),
	Color(1.0, 0.46, 0.42),
	Color(0.72, 0.82, 0.95),
	Color(1.0, 0.78, 0.34),
	Color(0.98, 0.62, 0.28),
]
## 啄木鸟随机事件：飞来啄倒一棵树，过一会儿再长回来。
## 立绘是 220px 小鸟（和局内啄木鸟同一套），不能用大图那档 pixel_size。
const WOODPECKER_FLY := preload("res://my_asset/birds/attacker_fly_1.png")
const WOODPECKER_PECK := preload("res://my_asset/birds/attacker_zhuo.png")
const WOODPECKER_PECK_SFX := preload("res://assets/audio/attacker_peck.wav")
const WOODPECKER_TRIGGER_SFX := preload("res://assets/audio/attacker_trigger.mp3")
const WOODPECKER_PIXEL_SIZE := 0.0054
const WOODPECKER_CARD_SIZE := 1.22
const WOODPECKER_FIRST_WAIT := Vector2(2.4, 4.2)
const WOODPECKER_INTERVAL := Vector2(12.0, 18.0)
const WOODPECKER_HOVER_CHANCE := 0.28
const WOODPECKER_REGROW := Vector2(14.0, 24.0)
const WOODPECKER_PECKS := 5
const WOODPECKER_PECK_STEP := 0.24
const WOODPECKER_STRIKE_DIP := 0.14
const WOODPECKER_LAY_PITCH_DEG := -90.0
const WOODPECKER_CHIP_COUNT := 12
const WOODPECKER_TEXT_COUNT := 5
const WOODPECKER_TEXT_GLYPHS := ["笃", "笃笃", "！"]
## 面包落水：夜鹭飞来一口叼走，弹出一串「呱」。
const HERON_FLY: Array[Texture2D] = [
	preload("res://my_asset/birds/black_fly_1.png"),
	preload("res://my_asset/birds/black_fly_2.png"),
]
const HERON_CALL := preload("res://assets/audio/black_bird_lantern.mp3")
const HERON_PIXEL_SIZE := 0.0052
const HERON_POND_RADIUS := 1.2
const HERON_CROAK_COUNT := 8
const HERON_CROAK_GLYPHS := ["呱", "呱呱"]
## 红隼随机事件：飞来叼走一只跳跳鸽，沿路留下「咕」拖尾。
const KESTREL_FLY := preload("res://my_asset/birds/eg_fly_big.png")
const KESTREL_FLAP := preload("res://my_asset/birds/eg_idle_1.png")
const KESTREL_CALL := preload("res://assets/audio/eg_super_luck_trigger.mp3")
const KESTREL_PIXEL_SIZE := 0.006
const KESTREL_FIRST_WAIT := Vector2(6.0, 9.0)
const KESTREL_INTERVAL := Vector2(16.0, 24.0)
const KESTREL_RESPAWN := Vector2(10.0, 16.0)
const KESTREL_COO_COUNT := 8
const KESTREL_COO_GLYPHS := ["咕", "咕咕"]
## 红尾水鸲随机事件：飞来停一下，相框挪来、镜头一转再闪光，弹出一张主体被糊掉的实景照片。
const REDSTART_FLY: Array[Texture2D] = [
	preload("res://my_asset/birds/red_fly_1.png"),
	preload("res://my_asset/birds/red_fly_2.png"),
]
const REDSTART_IDLE: Array[Texture2D] = [
	preload("res://my_asset/birds/red_idle_1.png"),
	preload("res://my_asset/birds/red_idle_2.png"),
]
const REDSTART_CALL := preload("res://assets/audio/red_bird_compass.wav")
const REDSTART_PIXEL_SIZE := 0.0062
const REDSTART_FIRST_WAIT := Vector2(10.0, 16.0)
const REDSTART_INTERVAL := Vector2(28.0, 40.0)
## 从俯视全图绕到近处平视：偏航约 1/4 圈，俯角抬到接近人蹲着拍的高度。
const REDSTART_SHOT_YAW := 64.0
const REDSTART_SHOT_PITCH := 30.0
## 贴到鸟跟前拍场景，大约能看清身边的草和岸。
const REDSTART_SHOT_DIST := 3.05
const REDSTART_SHOT_DURATION := 0.68
const REDSTART_HOLD := 1.15
const REDSTART_PRINT_DELAY := 0.42
const REDSTART_FLY_IN := 0.38
const REDSTART_LAND := 0.10
const REDSTART_FRAME_IN := 0.34
const REDSTART_RETIRE := 0.50
const REDSTART_QTE_DURATION := 0.82
const REDSTART_QTE_SWEET := 0.72
## 金色甜区半宽（相对整条槽），点在带里算一次成功对焦。
const REDSTART_QTE_SWEET_RADIUS := 0.11
const MAP_HEALTH_CHECK_TREES := 3
const MAP_BUFFET_PIGEONS := 3
const MAP_HERON_BREAD_LOAVES := 5
const Catalog := preload("res://scripts/game/achievement_catalog.gd")
## 飘云：几颗圆球叠成的小卡通云，从岛外一侧进、另一侧出。
const DRIFT_CLOUD_COUNT := 9
const DRIFT_CLOUD_MAX_SHADOWS := 8
const CARTOON_CLOUD_SHADER := preload("res://shaders/cartoon_cloud.gdshader")

const UI_LAYER := 60
const PAPER := Color(0.973, 0.961, 0.925)
const PAPER_EDGE := Color(0.784, 0.722, 0.604)
const INK := Color(0.184, 0.165, 0.125)
const INK_SOFT := Color(0.478, 0.427, 0.349)

var _cleared: Array = []
var _resume_stage_id := ""
var _resume_round := 0
var _high_scores: Dictionary = {}

var _camera: Camera3D
var _markers: Array[Node3D] = []
var _badges: Dictionary = {}          # stage_id -> StageBadge
var _stage_tiles: Dictionary = {}     # stage_id -> Node3D（绑定的 hex 地格）
var _tiles: Array[Node3D] = []        # 全部 hex 地格
var _hovered_tile: Node3D = null      # 当前指针下的地格（每帧射线/平面拾取）
var _tile_lift_tweens: Dictionary = {} # instance_id -> Tween
var _pivot := Vector3.ZERO
var _distance := 16.0
## 地格在 XZ 平面上的包围盒（Rect2 的 y 存的是世界 z）。
var _map_bounds := Rect2(-8.0, -8.0, 16.0, 16.0)

var _ui: CanvasLayer
var _badge_layer: Control
var _region_name_label: Label
var _region_progress_label: Label
var _resume_banner: Control
var _resume_text: Label
var _confirm: Control
var _confirm_dim: ColorRect
var _confirm_card: Panel
var _confirm_text: Label
var _pending_stage_id := ""
var _current_region_id := ""
var _edge_mist: _EdgeMist
var _outline_mesh: ArrayMesh
var _stage_path_root: Node3D
var _crumb_root: Node3D
var _crumb_emit_accum := 0.0
var _crumb_box: BoxMesh
var _loaf_mesh: ArrayMesh
var _loaf_phys_mat: PhysicsMaterial
var _last_crumb_screen := Vector2(-99999.0, -99999.0)
var _pigeon_root: Node3D
var _floaters: Array[Node3D] = []
var _drift_clouds: Array[Node3D] = []
var _water_mats: Array[ShaderMaterial] = []
var _toon_mats: Array[ShaderMaterial] = []
var _cloud_rng := RandomNumberGenerator.new()
var _flora: Array[Node3D] = []
var _hovered_flora: Node3D = null
var _note_layer: Control
var _flora_voice: AudioStreamPlayer
var _flora_shake_tweens: Dictionary = {}
var _woodpecker: Node3D
var _woodpecker_card: MeshInstance3D
var _woodpecker_mat: StandardMaterial3D
var _woodpecker_fx: Node3D
var _woodpecker_peck_voice: AudioStreamPlayer
var _woodpecker_trigger_voice: AudioStreamPlayer
var _woodpecker_chip_mesh: BoxMesh
var _woodpecker_busy := false
var _woodpecker_loop_gen := 0
var _woodpecker_pose_tween: Tween
## 测试可关掉自动循环，只手动点名 `play_woodpecker_raid`。
var woodpecker_events := true
var _pond_centers: Array[Vector3] = []
var _heron: Node3D
var _heron_sprite: Sprite3D
var _heron_fx: Node3D
var _heron_voice: AudioStreamPlayer
var _heron_busy := false
var _heron_gen := 0
var _heron_queue: Array[Node3D] = []
var _heron_move_tween: Tween
## 测试可关掉落水自动来叼，只手动点名 `play_heron_snatch`。
var heron_events := true
var _kestrel: Node3D
var _kestrel_sprite: Sprite3D
var _kestrel_fx: Node3D
var _kestrel_voice: AudioStreamPlayer
var _kestrel_busy := false
var _kestrel_loop_gen := 0
var _kestrel_move_tween: Tween
## 测试可关掉自动循环，只手动点名 `play_kestrel_raid`。
var kestrel_events := true
var _redstart: Node3D
var _redstart_sprite: Sprite3D
var _redstart_voice: AudioStreamPlayer
var _redstart_busy := false
var _redstart_loop_gen := 0
var _redstart_move_tween: Tween
var _redstart_exit := Vector3.ZERO
var _shot_yaw_off := 0.0
var _shot_pitch_off := 0.0
## < 0 表示仍用整图框定距离；拍照时写成近距实值。
var _shot_dist := -1.0
var _shot_look_off := Vector3.ZERO
var _photo_layer: Control
var _viewfinder: Control
var _polaroid: PanelContainer
var _polaroid_image: TextureRect
var _empty_film_tex: Texture2D
var _photo_tween: Tween
var _focus_qte: _FocusQte
var _focus_qte_listening := false
var _focus_qte_locked := false
var _focus_qte_needle := 0.0
var _focus_grade: Label
var _map_trees_felled := 0
var _map_pigeons_eaten := 0
var _map_loaves_eaten := 0
## 测试可关掉自动循环，只手动点名 `play_redstart_photo`。
var redstart_events := true


const TOON_WATER_SHADER := preload("res://shaders/water_globe.gdshader")
const TOON_WATER_NOISE := preload("res://assets/builder/water/surface_noise.tres")
const TOON_WATER_DISTORT := preload("res://assets/builder/water/surface_distortion.tres")


func _ready() -> void:
	_camera = get_node_or_null("MapCamera") as Camera3D
	if _camera == null:
		push_warning("WorldMap: 缺少 MapCamera 节点，相机控制不可用")
	elif not _is_globe():
		_camera.fov = 46.0
	_collect_markers()
	_compute_map_bounds()
	_setup_tile_interactions()
	_setup_flora_interactions()
	if _is_globe():
		apply_toon_water_material(get_node_or_null("WaterSphere") as MeshInstance3D)
	else:
		_apply_toon_water_ponds()
		_apply_toon_materials()
		_lock_forest_materials()
		_apply_edge_atmosphere()
		_apply_scene_lighting()
		_setup_drift_clouds()
	_build_stage_path()
	if not _is_globe():
		_setup_breadcrumbs()
		_setup_hop_pigeons()
		_setup_woodpecker()
		_collect_ponds()
		_setup_heron()
		_setup_kestrel()
		_setup_redstart()
	_collect_floaters()
	_build_ui()
	set_process(true)


## Roystan Toon Water 的同一套参数。生成器和运行时共用，改一处即可。
## `for_pond` 把噪声与水深按小池塘尺度收一档，算法不变。
static func apply_toon_water_material(ball: MeshInstance3D, for_pond := false) -> void:
	if ball == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = TOON_WATER_SHADER
	mat.set_shader_parameter("depth_gradient_shallow", Color(0.325, 0.807, 0.971, 0.725))
	mat.set_shader_parameter("depth_gradient_deep", Color(0.086, 0.407, 1.0, 0.749))
	mat.set_shader_parameter("depth_max_distance", 0.55 if for_pond else 0.9)
	mat.set_shader_parameter("foam_color", Color(1.0, 1.0, 1.0, 1.0))
	mat.set_shader_parameter("surface_noise", TOON_WATER_NOISE)
	mat.set_shader_parameter("surface_noise_scroll", Vector2(0.03, 0.03))
	mat.set_shader_parameter("surface_noise_cutoff", 0.74)
	mat.set_shader_parameter("surface_noise_scale", 3.2 if for_pond else 10.0)
	mat.set_shader_parameter("surface_distortion", TOON_WATER_DISTORT)
	mat.set_shader_parameter("surface_distortion_amount", 0.27)
	mat.set_shader_parameter("surface_distortion_scale", 2.4 if for_pond else 6.0)
	mat.set_shader_parameter("foam_max_distance", 0.4 if for_pond else 0.65)
	mat.set_shader_parameter("foam_min_distance", 0.04 if for_pond else 0.06)
	mat.set_shader_parameter("cloud_shadow_count", 0)
	ball.set_surface_override_material(0, mat)


func _apply_toon_water_ponds() -> void:
	_water_mats.clear()
	var host := get_node_or_null("Ponds")
	if host == null:
		return
	for child in host.get_children():
		if child is MeshInstance3D:
			var pond := child as MeshInstance3D
			apply_toon_water_material(pond, true)
			var mat := pond.get_surface_override_material(0) as ShaderMaterial
			if mat != null:
				_water_mats.append(mat)


func _collect_floaters() -> void:
	_floaters.clear()
	var host := get_node_or_null("Floaters")
	if host == null:
		return
	for child in host.get_children():
		if not (child is Node3D):
			continue
		var node := child as Node3D
		node.set_meta("float_base_y", node.position.y)
		node.set_meta("float_phase", float(child.get_index()) * 0.73)
		_floaters.append(node)


func _bob_floaters(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for node in _floaters:
		if not is_instance_valid(node):
			continue
		var base_y := float(node.get_meta("float_base_y", node.position.y))
		var phase := float(node.get_meta("float_phase", 0.0))
		node.position.y = base_y + sin(t * 1.15 + phase) * 0.035
		node.rotation.y += delta * (0.12 + 0.04 * sin(phase))


func _setup_drift_clouds() -> void:
	if _is_globe():
		return
	var existing := get_node_or_null("DriftClouds")
	if existing != null:
		existing.free()
	_drift_clouds.clear()
	_cloud_rng.randomize()
	var host := Node3D.new()
	host.name = "DriftClouds"
	add_child(host)
	for i in DRIFT_CLOUD_COUNT:
		host.add_child(_make_drift_cloud(i))
	_sync_cloud_shadows_to_water()


func _make_drift_cloud(index: int) -> Node3D:
	var big := index % 3 != 2
	var root := Node3D.new()
	root.name = "DriftCloud_%d" % index
	var scale := _cloud_rng.randf_range(0.58, 0.76) if big else _cloud_rng.randf_range(0.40, 0.54)
	root.scale = Vector3.ONE * scale
	root.rotation.y = _cloud_rng.randf() * TAU
	_build_cartoon_puffs(root, big)
	var spawn := _map_bounds.grow(3.2)
	var center := spawn.get_center()
	var pos_xz := Vector2(
		_cloud_rng.randf_range(spawn.position.x, spawn.end.x),
		_cloud_rng.randf_range(spawn.position.y, spawn.end.y)
	)
	if index < 3:
		pos_xz = center + Vector2(
			_cloud_rng.randf_range(-4.2, 4.2),
			_cloud_rng.randf_range(-2.8, 2.8)
		)
	root.position = Vector3(pos_xz.x, _cloud_rng.randf_range(5.8, 8.0), pos_xz.y)
	var wind := Vector3(1.0, 0.0, 0.22).normalized()
	var heading := (wind + Vector3(_cloud_rng.randf_range(-0.18, 0.18), 0.0, _cloud_rng.randf_range(-0.22, 0.22))).normalized()
	var speed := _cloud_rng.randf_range(0.32, 0.72)
	var radius := (1.05 if big else 0.72) * scale
	root.set_meta("cloud_vel", heading * speed)
	root.set_meta("cloud_base_y", root.position.y)
	root.set_meta("cloud_bob_phase", _cloud_rng.randf() * TAU)
	root.set_meta("cloud_bob_amp", _cloud_rng.randf_range(0.08, 0.16))
	root.set_meta("cloud_spin", _cloud_rng.randf_range(-0.10, 0.10))
	root.set_meta("cloud_shadow_radius", radius)
	_attach_cloud_shadow_caster(root, radius / scale)
	_drift_clouds.append(root)
	return root


func _cartoon_cloud_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CARTOON_CLOUD_SHADER
	mat.set_shader_parameter("fill", Color(0.995, 0.995, 1.0, 1.0))
	mat.set_shader_parameter("belly", Color(0.80, 0.89, 0.98, 1.0))
	mat.set_shader_parameter("line", Color(0.52, 0.68, 0.86, 1.0))
	mat.set_shader_parameter("line_width", 0.30)
	return mat


func _build_cartoon_puffs(root: Node3D, big: bool) -> void:
	var mat := _cartoon_cloud_material()
	var specs: Array[Vector4] = []
	if big:
		specs = [
			Vector4(0.00, 0.04, 0.00, 0.40),
			Vector4(-0.36, -0.03, 0.05, 0.30),
			Vector4(0.38, -0.02, -0.04, 0.32),
			Vector4(0.06, 0.10, -0.20, 0.26),
		]
	else:
		specs = [
			Vector4(0.00, 0.02, 0.00, 0.32),
			Vector4(-0.26, -0.03, 0.04, 0.24),
			Vector4(0.24, -0.02, -0.03, 0.23),
		]
	var i := 0
	for spec in specs:
		var puff := MeshInstance3D.new()
		puff.name = "Puff_%d" % i
		var ball := SphereMesh.new()
		ball.radius = spec.w
		ball.height = spec.w * 1.72
		ball.radial_segments = 12
		ball.rings = 6
		puff.mesh = ball
		puff.position = Vector3(spec.x, spec.y, spec.z)
		puff.scale = Vector3(1.0, 0.72, 1.08)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.set_surface_override_material(0, mat)
		root.add_child(puff)
		i += 1


func _attach_cloud_shadow_caster(root: Node3D, local_radius: float) -> void:
	var caster := MeshInstance3D.new()
	caster.name = "CloudShadow"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	caster.mesh = sphere
	caster.scale = Vector3(local_radius, local_radius * 0.34, local_radius * 0.70)
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	caster.material_override = mat
	root.add_child(caster)


func _cloud_flight_rect() -> Rect2:
	return _map_bounds.grow(16.0)


func _tick_drift_clouds(delta: float) -> void:
	if _drift_clouds.is_empty():
		return
	var flight := _cloud_flight_rect()
	var t := Time.get_ticks_msec() * 0.001
	for cloud in _drift_clouds:
		if not is_instance_valid(cloud):
			continue
		var vel: Vector3 = cloud.get_meta("cloud_vel", Vector3(0.55, 0.0, 0.12))
		cloud.position.x += vel.x * delta
		cloud.position.z += vel.z * delta
		var phase := float(cloud.get_meta("cloud_bob_phase", 0.0))
		var amp := float(cloud.get_meta("cloud_bob_amp", 0.22))
		var base_y := float(cloud.get_meta("cloud_base_y", cloud.position.y))
		cloud.position.y = base_y + sin(t * 0.55 + phase) * amp
		cloud.rotation.y += float(cloud.get_meta("cloud_spin", 0.04)) * delta
		if cloud.position.x > flight.end.x:
			cloud.position.x = flight.position.x
			cloud.position.z = _cloud_rng.randf_range(flight.position.y, flight.end.y)
			cloud.set_meta("cloud_base_y", _cloud_rng.randf_range(5.8, 8.0))
		elif cloud.position.x < flight.position.x:
			cloud.position.x = flight.end.x
			cloud.position.z = _cloud_rng.randf_range(flight.position.y, flight.end.y)
	_sync_cloud_shadows_to_water()


func _project_cloud_shadow(cloud: Node3D) -> Vector3:
	var key := get_node_or_null("KeyLight") as DirectionalLight3D
	var dir := Vector3(-0.70, -0.56, -0.44)
	if key != null:
		dir = -key.global_transform.basis.z
	if absf(dir.y) < 0.08:
		dir.y = -0.08
	var origin := cloud.global_position
	return origin + dir * (-origin.y / dir.y)


func _sync_cloud_shadows_to_water() -> void:
	if _water_mats.is_empty():
		return
	var packed := PackedVector4Array()
	var count := 0
	for cloud in _drift_clouds:
		if count >= DRIFT_CLOUD_MAX_SHADOWS:
			break
		if not is_instance_valid(cloud):
			continue
		var hit := _project_cloud_shadow(cloud)
		var radius := float(cloud.get_meta("cloud_shadow_radius", 0.9))
		packed.append(Vector4(hit.x, hit.z, radius, 0.34))
		count += 1
	while packed.size() < DRIFT_CLOUD_MAX_SHADOWS:
		packed.append(Vector4.ZERO)
	var water_packed := PackedVector4Array()
	var ground_packed := PackedVector4Array()
	for blob in packed:
		water_packed.append(blob)
		ground_packed.append(Vector4(blob.x, blob.y, blob.z, blob.w * 0.55))
	for mat in _water_mats:
		if mat == null:
			continue
		mat.set_shader_parameter("cloud_shadow_count", count)
		mat.set_shader_parameter("cloud_shadows", water_packed)
	for mat in _toon_mats:
		if mat == null:
			continue
		mat.set_shader_parameter("cloud_shadow_count", count)
		mat.set_shader_parameter("cloud_shadows", ground_packed)


func _is_globe() -> bool:
	return float(get_meta("globe_radius", 0.0)) > 0.0 or get_node_or_null("WaterSphere") != null


func _globe_radius() -> float:
	var r := float(get_meta("globe_radius", 0.0))
	if r > 0.0:
		return r
	var ball := get_node_or_null("WaterSphere") as MeshInstance3D
	if ball != null and ball.mesh is SphereMesh:
		return (ball.mesh as SphereMesh).radius
	return 0.0


func _water_surface_radius() -> float:
	var ball := get_node_or_null("WaterSphere") as MeshInstance3D
	if ball != null and ball.mesh is SphereMesh:
		return (ball.mesh as SphereMesh).radius
	return _globe_radius()


## 平面池塘：全景天空盒，不打雾，让树环外露出蓝天。
func _apply_edge_atmosphere() -> void:
	var holder := get_node_or_null("MapEnv") as WorldEnvironment
	if holder == null or holder.environment == null:
		return
	var env := holder.environment
	env.volumetric_fog_enabled = false
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if _is_globe():
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(1.0, 1.0, 1.0)
		env.fog_enabled = false
		env.ambient_light_color = Color(0.90, 0.93, 0.96)
		env.ambient_light_energy = 0.48
		env.tonemap_exposure = 1.08
		if _camera != null:
			_camera.fov = 42.0
		return
	_apply_pond_skybox(env)
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.86, 0.94)
	env.fog_density = 0.0008
	env.ambient_light_color = Color(0.40, 0.50, 0.56)
	env.ambient_light_energy = 0.10
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.78
	env.glow_enabled = true
	env.glow_intensity = 0.08
	env.glow_bloom = 0.02
	if _camera != null:
		_camera.environment = env
		_camera.fov = 46.0


static func _apply_pond_skybox(env: Environment) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.46, 0.74, 0.98)
	sky_mat.sky_horizon_color = Color(0.82, 0.92, 0.99)
	sky_mat.ground_horizon_color = Color(0.70, 0.86, 0.96)
	sky_mat.ground_bottom_color = Color(0.42, 0.68, 0.38)
	sky_mat.sky_cover = load("res://my_asset/sky.png") as Texture2D
	sky_mat.energy_multiplier = 0.88
	sky_mat.sun_angle_max = 40.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.background_color = Color(0.55, 0.80, 0.94)


## 池塘用斜射主光拉开亮暗，补光和环境光只托暗部，避免三盏灯把阴影填平。
func _apply_scene_lighting() -> void:
	var studio := _is_globe()
	var key := get_node_or_null("KeyLight") as DirectionalLight3D
	if key != null:
		if not studio:
			key.rotation = Vector3(deg_to_rad(-34.0), deg_to_rad(58.0), 0.0)
		key.light_energy = 0.62 if studio else 0.78
		key.light_color = Color(1.0, 0.98, 0.94) if studio else Color(0.98, 0.94, 0.86)
		key.shadow_enabled = true
		key.shadow_blur = 1.1 if studio else 1.4
		key.shadow_bias = 0.03 if studio else 0.04
		key.shadow_normal_bias = 0.35 if studio else 0.5
		key.directional_shadow_max_distance = 48.0 if studio else 80.0
		key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		key.light_angular_distance = 0.0 if studio else 2.4
		key.shadow_opacity = 1.0 if studio else 0.82
		key.light_specular = 0.0
	var fill := get_node_or_null("FillLight") as DirectionalLight3D
	if fill != null:
		if not studio:
			fill.rotation = Vector3(deg_to_rad(-16.0), deg_to_rad(-118.0), 0.0)
		fill.light_energy = 0.38 if studio else 0.06
		fill.light_color = Color(0.78, 0.86, 0.96) if studio else Color(0.55, 0.68, 0.88)
		fill.shadow_enabled = false
		fill.light_specular = 0.0
	var bounce := get_node_or_null("BounceLight") as DirectionalLight3D
	if bounce != null:
		bounce.light_energy = 0.16 if studio else 0.03
		bounce.light_color = Color(0.98, 0.93, 0.86) if studio else Color(0.55, 0.72, 0.42)
		bounce.shadow_enabled = false
		bounce.light_specular = 0.0


## 每块 hex 地格挂碰撞体；悬停用每帧物理射线打到 TilePick（不用 mouse_entered）。
func _setup_tile_interactions() -> void:
	_stage_tiles.clear()
	_tiles.clear()
	_hovered_tile = null
	_tile_lift_tweens.clear()

	var terrain := get_node_or_null("HexTerrain") as Node3D
	if terrain != null:
		for region in terrain.get_children():
			for child in region.get_children():
				if not (child is Node3D):
					continue
				if not String(child.name).begins_with("pad_"):
					continue
				_tiles.append(child as Node3D)

	_outline_mesh = _build_hex_outline_mesh(HEX_OUTLINE_RADIUS, HEX_OUTLINE_THICKNESS)
	for tile in _tiles:
		_attach_tile_outline(tile)
		_attach_tile_pick(tile)
		if not tile.has_meta("hover_base_pos"):
			tile.set_meta("hover_base_pos", tile.position)
		if not tile.has_meta("hover_base_y"):
			tile.set_meta("hover_base_y", tile.position.y)

	for marker in _markers:
		var stage_id := String(marker.get_meta("stage_id", ""))
		if stage_id == "":
			continue
		var best: Node3D = null
		var best_d := INF
		var mp := marker.global_position
		for tile in _tiles:
			var tp := tile.global_position
			var d := tp.distance_squared_to(mp) if _is_globe() else Vector2(tp.x - mp.x, tp.z - mp.z).length_squared()
			if d < best_d:
				best_d = d
				best = tile
		var limit := TILE_BIND_EPSILON * TILE_BIND_EPSILON
		if _is_globe():
			limit = 2.2 * 2.2
		if best == null or best_d > limit:
			best = null
			for tile in _tiles:
				var parent := tile.get_parent()
				if parent != null and String(parent.name) == "Island_%s" % stage_id:
					best = tile
					break
		if best == null:
			push_warning("WorldMap: 关卡 %s 没有找到绑定地格" % stage_id)
			continue
		_stage_tiles[stage_id] = best
		best.set_meta("stage_id", stage_id)
		var island := best.get_parent()
		if island != null and String(island.name).begins_with("Island_"):
			for child in island.get_children():
				if child is Node3D and String(child.name).begins_with("hex_"):
					(child as Node3D).set_meta("stage_id", stage_id)
		marker.set_meta("tile_path", best.get_path())
		if not marker.has_meta("hover_base_pos"):
			marker.set_meta("hover_base_pos", marker.position)
		if not marker.has_meta("hover_base_y"):
			marker.set_meta("hover_base_y", marker.position.y)


func _attach_tile_outline(tile: Node3D) -> void:
	var existing := tile.get_node_or_null("TileOutline") as MeshInstance3D
	if existing != null:
		existing.queue_free()
	var outline := MeshInstance3D.new()
	outline.name = "TileOutline"
	outline.mesh = _outline_mesh
	outline.position = Vector3(0.0, HEX_OUTLINE_Y, 0.0)
	outline.visible = false
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = TILE_OUTLINE_DEFAULT
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1
	outline.set_surface_override_material(0, mat)
	tile.add_child(outline)


## 每块地格一个圆柱碰撞体，挂在地格根上；抬视觉时不抬它，射线才能稳定打中。
func _attach_tile_pick(tile: Node3D) -> void:
	var old := tile.get_node_or_null("TilePick")
	if old != null:
		old.queue_free()
	var body := StaticBody3D.new()
	body.name = "TilePick"
	body.collision_layer = TILE_PICK_COLLISION_LAYER
	body.collision_mask = 0
	body.input_ray_pickable = false
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.05 if _is_globe() else 1.15
	cyl.height = 1.1 if _is_globe() else 0.9
	shape.shape = cyl
	shape.position = Vector3(0.0, 0.35 if _is_globe() else 0.2, 0.0)
	body.add_child(shape)
	tile.add_child(body)


## 给林间/水面植被挂拾取体；悬停时随机抖动、唱歌或掉面包。
func _setup_flora_interactions() -> void:
	_flora.clear()
	_hovered_flora = null
	_collect_flora(get_node_or_null("HexTerrain/Grove"))
	_collect_flora(get_node_or_null("Floaters"))
	for node in _flora:
		_attach_flora_pick(node)
	if _flora_voice == null:
		_flora_voice = AudioStreamPlayer.new()
		_flora_voice.name = "FloraBirdCall"
		_flora_voice.volume_db = -4.0
		add_child(_flora_voice)


func _collect_flora(host: Node) -> void:
	if host == null:
		return
	for child in host.get_children():
		if not (child is Node3D):
			continue
		var node := child as Node3D
		if not _is_flora_prop(node):
			continue
		_flora.append(node)


func _is_flora_prop(node: Node3D) -> bool:
	if bool(node.get_meta("flora", false)):
		return true
	var n := String(node.name)
	if n.begins_with("Rock") or n.begins_with("Pebble"):
		return false
	if n.begins_with("building_") or n.begins_with("hex_") or n.begins_with("pad_"):
		return false
	return true


func _is_flora_tree(node: Node3D) -> bool:
	if node.has_meta("flora_tree"):
		return bool(node.get_meta("flora_tree"))
	var n := String(node.name)
	return (
		n.begins_with("Pine_") or n.begins_with("CommonTree")
		or n.begins_with("TwistedTree") or n.begins_with("DeadTree")
	)


func _attach_flora_pick(node: Node3D) -> void:
	var old := node.get_node_or_null("FloraPick")
	if old != null:
		old.queue_free()
	var body := StaticBody3D.new()
	body.name = "FloraPick"
	body.collision_layer = FLORA_PICK_COLLISION_LAYER
	body.collision_mask = 0
	body.input_ray_pickable = false
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	var tree := _is_flora_tree(node)
	cyl.radius = 0.42 if tree else 0.28
	cyl.height = 1.7 if tree else 0.55
	shape.shape = cyl
	shape.position = Vector3(0.0, cyl.height * 0.45, 0.0)
	body.add_child(shape)
	node.add_child(body)
	if not node.has_meta("flora_base_rot"):
		node.set_meta("flora_base_rot", node.rotation)


func _refresh_flora_hover_from_pointer() -> void:
	if not visible or _camera == null or _is_globe():
		_set_hovered_flora(null)
		return
	if _confirm != null and _confirm.visible:
		_set_hovered_flora(null)
		return
	var screen := get_viewport().get_mouse_position()
	if not get_viewport().get_visible_rect().has_point(screen):
		_set_hovered_flora(null)
		return
	_refresh_flora_at(screen)


func _refresh_flora_at(screen_pos: Vector2) -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	if _find_stage_badge(hovered) != null or _is_world_map_chrome(hovered):
		_set_hovered_flora(null)
		return
	_set_hovered_flora(_pick_flora_at_screen(screen_pos))


func _set_hovered_flora(node: Node3D) -> void:
	var next := node if node != null and is_instance_valid(node) else null
	if next == _hovered_flora:
		return
	_hovered_flora = next
	if _hovered_flora != null:
		_on_flora_entered(_hovered_flora)


func _pick_flora_at_screen(screen_pos: Vector2) -> Node3D:
	var hit := _raycast_flora(screen_pos)
	if hit != null:
		return hit
	return _pick_flora_on_ground(screen_pos)


func _raycast_flora(screen_pos: Vector2) -> Node3D:
	if _camera == null:
		return null
	var world := _camera.get_world_3d()
	if world == null or world.direct_space_state == null:
		return null
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 400.0)
	query.collision_mask = FLORA_PICK_COLLISION_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var walk := hit.get("collider") as Node
	while walk != null:
		if walk is Node3D and walk in _flora:
			return walk as Node3D
		walk = walk.get_parent()
	return null


func _pick_flora_on_ground(screen_pos: Vector2) -> Node3D:
	var ground := _ground_point_at_screen(screen_pos)
	var best: Node3D = null
	var best_d := 0.55 * 0.55
	for node in _flora:
		if not is_instance_valid(node):
			continue
		if bool(node.get_meta("felled", false)):
			continue
		var p := node.global_position
		var d := Vector2(p.x - ground.x, p.z - ground.z).length_squared()
		if d <= best_d:
			best_d = d
			best = node
	return best


func _on_flora_entered(node: Node3D) -> void:
	if (
		woodpecker_events
		and not _woodpecker_busy
		and _is_flora_tree(node)
		and randf() < WOODPECKER_HOVER_CHANCE
	):
		play_woodpecker_raid(node)
		return
	play_flora_react(node, _roll_flora_kind())


func _roll_flora_kind() -> int:
	var roll := randf()
	if roll < FLORA_SHAKE_CHANCE:
		return FLORA_KIND_SHAKE
	if roll < FLORA_SHAKE_CHANCE + FLORA_SONG_CHANCE:
		return FLORA_KIND_SONG
	return FLORA_KIND_BREAD


## 测试与运行时共用：0 抖动、1 音符+鸟鸣、2 掉面包。
func play_flora_react(node: Node3D, kind: int) -> void:
	if node == null or not is_instance_valid(node):
		return
	if bool(node.get_meta("felled", false)):
		return
	match kind:
		FLORA_KIND_SONG:
			_flora_sing(node)
		FLORA_KIND_BREAD:
			_flora_drop_bread(node)
		_:
			_flora_shake(node)


func _flora_shake(node: Node3D) -> void:
	var base: Vector3 = node.get_meta("flora_base_rot", node.rotation)
	node.set_meta("flora_base_rot", base)
	var key := node.get_instance_id()
	var previous: Tween = _flora_shake_tweens.get(key)
	if previous != null and previous.is_valid():
		previous.kill()
	var tween := node.create_tween()
	for _i in 2:
		var yaw := randf_range(-0.18, 0.18)
		var pitch := randf_range(-0.05, 0.05)
		tween.tween_property(node, "rotation", base + Vector3(pitch, yaw, 0.0), 0.05)
	tween.tween_property(node, "rotation", base, 0.08)
	_flora_shake_tweens[key] = tween


func _flora_sing(node: Node3D) -> void:
	if _flora_voice != null and not FLORA_BIRD_CALLS.is_empty():
		var index := randi() % FLORA_BIRD_CALLS.size()
		_flora_voice.stream = FLORA_BIRD_CALLS[index]
		_flora_voice.pitch_scale = randf_range(0.95, 1.08)
		_flora_voice.play()
		_burst_flora_notes(node, FLORA_BIRD_TINTS[index % FLORA_BIRD_TINTS.size()])
	else:
		_burst_flora_notes(node, Color(1.0, 0.94, 0.72))


func _flora_drop_bread(node: Node3D) -> void:
	var ground := node.global_position
	ground.y = 0.0
	_spawn_loaf_at(ground, randf() < 0.5)


func _burst_flora_notes(node: Node3D, tint: Color) -> void:
	if _note_layer == null:
		return
	var lift := 1.15 if _is_flora_tree(node) else 0.48
	var origin := _unproject_to_badge_layer(node.global_position + Vector3(0.0, lift, 0.0))
	var room := FLORA_NOTE_LIMIT - _note_layer.get_child_count()
	if room <= 0:
		return
	for _index in mini(FLORA_NOTES_PER_BURST, room):
		var note := Label.new()
		note.text = FLORA_NOTE_GLYPHS[randi() % FLORA_NOTE_GLYPHS.size()]
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note.add_theme_font_override("font", FLORA_NOTE_FONT)
		note.add_theme_font_size_override("font_size", randi_range(28, 64))
		note.add_theme_color_override("font_color", Color.WHITE)
		note.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.09, 0.85))
		note.add_theme_constant_override("outline_size", 8)
		_note_layer.add_child(note)
		note.reset_size()
		note.pivot_offset = note.size * 0.5
		var angle := randf_range(0.0, TAU)
		var velocity := Vector2.RIGHT.rotated(angle) * randf_range(180.0, 480.0)
		var life := randf_range(0.65, 1.15)
		var spin := randf_range(-3.2, 3.2)
		var color := tint.lerp(Color(1.0, 0.94, 0.72), randf_range(0.0, 0.55))
		var flight := create_tween().set_parallel(true)
		flight.tween_method(
			func(progress: float) -> void:
				_advance_flora_note(note, origin, velocity, progress, life, color),
			0.0,
			1.0,
			life
		)
		flight.tween_property(note, "rotation", spin, life)
		flight.finished.connect(note.queue_free)


func _advance_flora_note(
	note: Label,
	origin: Vector2,
	velocity: Vector2,
	progress: float,
	life: float,
	color: Color
) -> void:
	if not is_instance_valid(note):
		return
	var elapsed := progress * life
	var drag := 1.0 - pow(1.0 - progress, 2.4)
	var lift := 0.5 * (-480.0 + 240.0 * progress) * elapsed * elapsed
	note.position = origin + velocity * drag * life * 0.55 + Vector2(0.0, lift) - note.size * 0.5
	var fade_in := clampf(progress / 0.12, 0.0, 1.0)
	var fade_out := clampf((1.0 - progress) / 0.4, 0.0, 1.0)
	note.modulate = Color(color.r, color.g, color.b, minf(fade_in, fade_out))
	var pop := 0.55 + 0.6 * clampf(progress / 0.18, 0.0, 1.0)
	note.scale = Vector2(pop, pop)


func _clear_music_notes() -> void:
	if _note_layer == null:
		return
	for note in _note_layer.get_children():
		note.queue_free()


func _build_hex_outline_mesh(outer_r: float, thickness: float) -> ArrayMesh:
	var inner_r := maxf(outer_r - thickness, outer_r * 0.55)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var segs := 16
	for i in segs:
		var a0 := float(i) * TAU / float(segs)
		var a1 := float(i + 1) * TAU / float(segs)
		var o0 := Vector3(cos(a0) * outer_r, 0.0, sin(a0) * outer_r)
		var o1 := Vector3(cos(a1) * outer_r, 0.0, sin(a1) * outer_r)
		var i0 := Vector3(cos(a0) * inner_r, 0.0, sin(a0) * inner_r)
		var i1 := Vector3(cos(a1) * inner_r, 0.0, sin(a1) * inner_r)
		var base := verts.size()
		verts.append_array([o0, o1, i1, i0])
		for _j in 4:
			normals.append(Vector3.UP)
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 测试/内部：强制指定当前悬停地格（null = 清空）。
func _set_hovered_tile(tile: Node3D) -> void:
	if tile == _hovered_tile:
		return
	if _hovered_tile != null and is_instance_valid(_hovered_tile):
		_apply_tile_hover(_hovered_tile, false)
	_hovered_tile = tile if tile != null and is_instance_valid(tile) else null
	if _hovered_tile != null:
		_apply_tile_hover(_hovered_tile, true)


## 兼容旧测试名。
func _on_tile_hover(tile: Node3D, entered: bool) -> void:
	if entered:
		_set_hovered_tile(tile)
	elif tile == _hovered_tile:
		_set_hovered_tile(null)


func _on_stage_hover(stage_id: String, entered: bool) -> void:
	var tile: Node3D = _stage_tiles.get(stage_id)
	if tile == null:
		var badge: StageBadge = _badges.get(stage_id)
		if badge != null:
			badge.set_hover_visual(entered)
		return
	_on_tile_hover(tile, entered)


func _apply_tile_hover(tile: Node3D, active: bool) -> void:
	var outline := tile.get_node_or_null("TileOutline") as MeshInstance3D
	if outline != null:
		outline.visible = active
		if active:
			var accent := TILE_OUTLINE_DEFAULT
			var stage_id := String(tile.get_meta("stage_id", ""))
			var badge: StageBadge = _badges.get(stage_id) if stage_id != "" else null
			if badge != null and StageBadge.STATE_ACCENTS.has(badge.current_state()):
				var c: Color = StageBadge.STATE_ACCENTS[badge.current_state()]
				accent = Color(c.r, c.g, c.b, 0.94)
			var mat := outline.get_surface_override_material(0) as StandardMaterial3D
			if mat != null:
				mat.albedo_color = accent

	var stage_id := String(tile.get_meta("stage_id", ""))
	if stage_id != "":
		var badge: StageBadge = _badges.get(stage_id)
		if badge != null:
			badge.set_hover_visual(active)

	_tween_tile_lift(tile, active)


## 只抬视觉；TilePick 碰撞体留在原地。
func _hover_lift_targets(tile: Node3D) -> Array[Node3D]:
	var targets: Array[Node3D] = []
	for child in tile.get_children():
		if child.name == "TilePick":
			continue
		if child is Node3D:
			targets.append(child as Node3D)
	var parent := tile.get_parent()
	if parent == null:
		return targets
	var origin := tile.global_position
	for sibling in parent.get_children():
		if sibling == tile or not (sibling is Node3D):
			continue
		var name_str := String(sibling.name)
		if name_str.begins_with("hex_"):
			continue
		var other := sibling as Node3D
		var d := other.global_position.distance_to(origin) if _is_globe() else Vector2(
			other.global_position.x - origin.x, other.global_position.z - origin.z
		).length()
		if d <= TILE_BIND_EPSILON:
			targets.append(other)
	for marker in _markers:
		var d := marker.global_position.distance_to(origin) if _is_globe() else Vector2(
			marker.global_position.x - origin.x, marker.global_position.z - origin.z
		).length()
		if d <= TILE_BIND_EPSILON:
			targets.append(marker)
	return targets


func _lift_axis_in_parent(node: Node3D) -> Vector3:
	var parent := node.get_parent() as Node3D
	if parent == null:
		return Vector3.UP
	var world_up := node.global_transform.basis.y.normalized()
	if world_up.length_squared() < 0.01:
		world_up = Vector3.UP
	return parent.global_transform.basis.inverse() * world_up


func _tween_tile_lift(tile: Node3D, active: bool) -> void:
	for node in _hover_lift_targets(tile):
		if not node.has_meta("hover_base_pos"):
			node.set_meta("hover_base_pos", node.position)
		if not node.has_meta("hover_base_y"):
			node.set_meta("hover_base_y", node.position.y)
		var base: Vector3 = node.get_meta("hover_base_pos")
		var axis := _lift_axis_in_parent(node)
		var target := base + axis * (TILE_HOVER_LIFT if active else 0.0)
		var key := node.get_instance_id()
		var previous: Tween = _tile_lift_tweens.get(key)
		if previous != null and previous.is_valid():
			previous.kill()
		var tween := node.create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "position", target, TILE_HOVER_DURATION)
		_tile_lift_tweens[key] = tween


## 每帧射线拾取当前地格。
func _refresh_hover_from_pointer() -> void:
	if not visible or _camera == null:
		_set_hovered_tile(null)
		return
	if _confirm != null and _confirm.visible:
		_set_hovered_tile(null)
		return
	var screen := get_viewport().get_mouse_position()
	if not get_viewport().get_visible_rect().has_point(screen):
		_set_hovered_tile(null)
		return
	_refresh_hover_at(screen)


func _refresh_hover_at(screen_pos: Vector2) -> void:
	_set_hovered_tile(_resolve_tile_at_screen(screen_pos))


func _resolve_tile_at_screen(screen_pos: Vector2) -> Node3D:
	var hovered_ctrl := get_viewport().gui_get_hovered_control()
	var badge := _find_stage_badge(hovered_ctrl)
	if badge != null:
		if badge.disabled:
			return null
		return _stage_tiles.get(badge.stage_id) as Node3D
	# 只挡住世界地图自己的顶栏/确认卡；主场景里别的 Control 不能误杀拾取。
	if _is_world_map_chrome(hovered_ctrl):
		return null
	var hit := _raycast_tile(screen_pos)
	if hit != null:
		return hit
	return _pick_tile_on_ground(screen_pos)


func _find_stage_badge(ctrl: Control) -> StageBadge:
	var walk: Node = ctrl
	while walk != null:
		if walk is StageBadge:
			return walk as StageBadge
		walk = walk.get_parent()
	return null


func _is_modal_overlay_visible() -> bool:
	for node in get_tree().get_nodes_in_group("modal_overlay"):
		if node is CanvasLayer and (node as CanvasLayer).visible:
			return true
		if node is CanvasItem and (node as CanvasItem).is_visible_in_tree():
			return true
	return false


func _is_overlay_above_map(ctrl: Control) -> bool:
	var walk: Node = ctrl
	while walk != null:
		if walk is CanvasLayer:
			return (walk as CanvasLayer).layer > UI_LAYER
		walk = walk.get_parent()
	return false


func _is_world_map_chrome(ctrl: Control) -> bool:
	if ctrl == null or _ui == null:
		return false
	var walk: Node = ctrl
	var under_map_ui := false
	while walk != null:
		if walk == _ui:
			under_map_ui = true
			break
		var n := String(walk.name)
		if n == "TopBar" or n == "AbandonConfirm" or n == "ResumeBanner":
			return true
		walk = walk.get_parent()
	if not under_map_ui:
		return false
	# 在 WorldMapUi 下但不是牌子：顶栏等。
	walk = ctrl
	while walk != null and walk != _ui:
		var n2 := String(walk.name)
		if n2 == "TopBar" or n2 == "AbandonConfirm" or n2 == "ResumeBanner" or n2 == "ConfirmPanel":
			return true
		walk = walk.get_parent()
	return false


func _raycast_tile(screen_pos: Vector2) -> Node3D:
	if _camera == null:
		return null
	var world := _camera.get_world_3d()
	if world == null:
		return null
	var space := world.direct_space_state
	if space == null:
		return null
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 400.0)
	query.collision_mask = TILE_PICK_COLLISION_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	var node := hit.get("collider") as Node
	while node != null:
		if node is Node3D and _is_pick_tile(node):
			return node as Node3D
		if node.get_parent() != null and _is_pick_tile(node.get_parent()):
			return node.get_parent() as Node3D
		node = node.get_parent()
	return null


func _is_pick_tile(node: Node) -> bool:
	var n := String(node.name)
	return n.begins_with("hex_") or n.begins_with("pad_")


func _pick_tile_on_ground(screen_pos: Vector2) -> Node3D:
	if _camera == null or _tiles.is_empty():
		return null
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var hit := Vector3.ZERO
	if _is_globe():
		var sphere_hit := _intersect_globe(origin, dir)
		if sphere_hit == Vector3.INF:
			return null
		hit = sphere_hit
	else:
		if absf(dir.y) < 0.0001:
			return null
		var distance := -origin.y / dir.y
		if distance < 0.0:
			return null
		hit = origin + dir * distance
	var best: Node3D = null
	var best_d := TILE_PICK_RADIUS * TILE_PICK_RADIUS
	for tile in _tiles:
		var d := tile.global_position.distance_squared_to(hit)
		if d <= best_d:
			best_d = d
			best = tile
	return best


func _intersect_globe(origin: Vector3, dir: Vector3) -> Vector3:
	var radius := _globe_radius()
	if radius <= 0.0:
		return Vector3.INF
	var d := dir.normalized()
	var b := origin.dot(d)
	var c := origin.length_squared() - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return Vector3.INF
	var t := -b - sqrt(disc)
	if t < 0.0:
		t = -b + sqrt(disc)
	if t < 0.0:
		return Vector3.INF
	return origin + d * t


## 给场景里所有网格换上卡通渲染的材质。
##
## 在**运行时**扫一遍而不是烘进 .tscn，是为了让"手改场景"这条路保持通畅：以后在编辑器
## 里新拖一块地格进来，它自动就是卡通的，不用记得手动挂材质，也不用重跑生成工具。
##
## 只换 shader、不换贴图：每个表面的原始 `albedo_texture` 被读出来喂给 shader，素材本身
## 的色块图集原样保留，卡通化只作用在光照上。同一张贴图共用一份材质——整个包其实只有
## `hexagons_medieval.png` 一张图，所以最后基本只会建出一份。
func _apply_toon_materials() -> void:
	var shader := load("res://shaders/hex_toon.gdshader") as Shader
	if shader == null:
		push_warning("WorldMap: 找不到卡通渲染 shader，退回素材的默认材质")
		return
	var cache: Dictionary = {}
	for root_name in ["HexTerrain", "StageMarkers", "Floaters"]:
		var host := get_node_or_null(root_name)
		if host != null:
			_toon_ify(host, shader, cache)
	_toon_mats.clear()
	for mat in cache.values():
		if mat is ShaderMaterial:
			_toon_mats.append(mat as ShaderMaterial)


func _lock_forest_materials() -> void:
	var fill := get_node_or_null("HexTerrain/GroundFill") as MeshInstance3D
	if fill != null:
		var apron := StandardMaterial3D.new()
		apron.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		apron.albedo_color = Color(0.20, 0.42, 0.16)
		fill.set_surface_override_material(0, apron)
	var ribbon := get_node_or_null("HexTerrain/PathScene/DirtPath") as MeshInstance3D
	if ribbon != null:
		var dirt := StandardMaterial3D.new()
		dirt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dirt.cull_mode = BaseMaterial3D.CULL_DISABLED
		dirt.albedo_color = Color(0.78, 0.54, 0.30)
		ribbon.set_surface_override_material(0, dirt)


func _toon_ify(node: Node, shader: Shader, cache: Dictionary) -> void:
	var n := String(node.name)
	if n in ["Grove", "Ground", "GroundFill", "PathScene", "Hills", "Atmosphere", "Ponds", "PondBasins"]:
		return
	if n == "HexTerrain":
		for child in node.get_children():
			_toon_ify(child, shader, cache)
		return
	var mesh_node := node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		for surface in mesh_node.mesh.get_surface_count():
			var source := mesh_node.get_active_material(surface) as BaseMaterial3D
			if source == null:
				source = mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D
			var texture: Texture2D = source.albedo_texture if source != null else null
			var tint_col := source.albedo_color if source != null else Color.WHITE
			var key := texture.resource_path if texture != null else "__flat__:%0.3f,%0.3f,%0.3f" % [
				tint_col.r, tint_col.g, tint_col.b
			]
			if not cache.has(key):
				var material := ShaderMaterial.new()
				material.shader = shader
				material.set_shader_parameter("albedo_tex", texture)
				material.set_shader_parameter("has_albedo_tex", texture != null)
				material.set_shader_parameter("rim_strength", 0.08)
				material.set_shader_parameter("rim_width", 0.26)
				material.set_shader_parameter("band_softness", 0.10)
				# 没有贴图的表面（Builder Pack 纯色、或极少数装饰）走 tint。
				# 有贴图的地格也略压一档，KayKit 草面固有色偏亮，受光后容易发白。
				if texture == null:
					material.set_shader_parameter("tint", tint_col * Color(0.82, 0.84, 0.80, 1.0))
				else:
					material.set_shader_parameter("tint", Color(0.78, 0.82, 0.76, 1.0))
				material.set_shader_parameter("cloud_shadow_count", 0)
				cache[key] = material
			mesh_node.set_surface_override_material(surface, cache[key])
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_toon_ify(child, shader, cache)


## 场景里的关卡节点靠 `stage_id` 元数据认领。查不到的 id 只警告不崩——手改场景时
## 打错字或删了关卡表条目都属于这一类，不该让整张地图挂掉。
func _collect_markers() -> void:
	_markers.clear()
	var host := get_node_or_null("StageMarkers")
	if host == null:
		push_warning("WorldMap: 缺少 StageMarkers 节点，地图上不会有关卡")
		return
	for child in host.get_children():
		if not child is Node3D:
			continue
		var stage_id := String(child.get_meta("stage_id", ""))
		if stage_id == "":
			push_warning("WorldMap: 关卡节点 %s 没有 stage_id 元数据" % child.name)
			continue
		if not StageTable.has_stage(stage_id):
			push_warning("WorldMap: 关卡表里没有 %s" % stage_id)
			continue
		_markers.append(child as Node3D)


## 镜头框定以**关卡节点**为准。外圈六边格铺满第一屏，溶进边缘云雾，不拉远视距。
func _compute_map_bounds() -> void:
	if _is_globe():
		var r := _globe_radius() + FIT_MARGIN
		_map_bounds = Rect2(-r, -r, r * 2.0, r * 2.0)
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var found := false
	for marker in _markers:
		var p := marker.global_position
		lo.x = minf(lo.x, p.x)
		lo.y = minf(lo.y, p.z)
		hi.x = maxf(hi.x, p.x)
		hi.y = maxf(hi.y, p.z)
		found = true
	if not found:
		_map_bounds = Rect2(-8.0, -8.0, 16.0, 16.0)
		return
	lo -= Vector2(FIT_MARGIN, FIT_MARGIN)
	hi += Vector2(FIT_MARGIN, FIT_MARGIN)
	_map_bounds = Rect2(lo, hi - lo)


# --- 对外接口 ---


## 亮出地图。`cleared` 是已通关关卡 id 列表，`resume_stage_id` / `resume_round` 是
## 唯一那个续局槽（无续局传空串与 0）。`high_scores` 为 stage_id → 历史最高分。
func present(cleared: Array, resume_stage_id: String, resume_round: int, high_scores: Dictionary = {}) -> void:
	_cleared = cleared.duplicate()
	_resume_stage_id = resume_stage_id
	_resume_round = resume_round
	_high_scores = high_scores.duplicate()
	visible = true
	if _ui != null:
		_ui.visible = true
	if _camera != null:
		_camera.make_current()
	_scatter_hop_pigeons()
	_rebuild_badges()
	_refresh_stage_path()
	_refresh_resume_banner()
	_close_confirm(true)
	_frame_full_map()
	_refresh_region_readout()
	if woodpecker_events and not _is_globe():
		_kick_woodpecker_loop()
	if kestrel_events and not _is_globe():
		_kick_kestrel_loop()
	if redstart_events and not _is_globe():
		_kick_redstart_loop()


func dismiss() -> void:
	_set_hovered_tile(null)
	_set_hovered_flora(null)
	_clear_breadcrumbs()
	_clear_music_notes()
	_scatter_hop_pigeons()
	_stop_woodpecker_loop()
	_stop_heron()
	_stop_kestrel()
	_stop_redstart()
	visible = false
	if _ui != null:
		_ui.visible = false


## 镜头对准关卡分布中心，视距刚好把所有悬浮牌收进第一屏（含边缘云雾留白）。
func _frame_full_map() -> void:
	var center := _map_bounds.get_center()
	_pivot = Vector3(center.x, 0.0, center.y)
	_distance = _fit_distance_for_bounds(_map_bounds)
	_apply_camera()


## 按当前 FOV / 俯角，算出把 bounds 塞进视口所需的视距。
func _fit_distance_for_bounds(bounds: Rect2) -> float:
	if _camera == null:
		return 16.0
	if _is_globe():
		var visual_r := _globe_radius() + 2.2
		var fov_v := deg_to_rad(_camera.fov)
		# 水球约占竖向 FOV 的九成，岛和牌子仍留边。
		return visual_r / maxf(tan(fov_v * 0.54), 0.12)
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var fov_v := deg_to_rad(_camera.fov)
	var fov_h := 2.0 * atan(tan(fov_v * 0.5) * aspect)
	var yaw := deg_to_rad(CAMERA_YAW_DEG)
	var cy := cos(yaw)
	var sy := sin(yaw)
	var cx := bounds.get_center().x
	var cz := bounds.get_center().y
	var max_right := 0.0
	var max_depth := 0.0
	var corners: Array[Vector2] = [
		Vector2(bounds.position.x, bounds.position.y),
		Vector2(bounds.end.x, bounds.position.y),
		Vector2(bounds.end.x, bounds.end.y),
		Vector2(bounds.position.x, bounds.end.y),
	]
	for corner in corners:
		var dx := corner.x - cx
		var dz := corner.y - cz
		max_right = maxf(max_right, absf(dx * cy - dz * sy))
		max_depth = maxf(max_depth, absf(dx * sy + dz * cy))
	var d_w := max_right / maxf(tan(fov_h * 0.5), 0.05)
	var pitch_abs := absf(deg_to_rad(CAMERA_PITCH_DEG))
	var d_d := max_depth * maxf(sin(pitch_abs), 0.55) / maxf(tan(fov_v * 0.5), 0.05)
	var dist := maxf(d_w, d_d)
	return clampf(dist * FIT_PADDING, 12.0, 40.0)


## 按关卡序号连一条地面色带，读出 1→6 的前后；已开路段偏暖，未开偏灰。
func _build_stage_path() -> void:
	var old := get_node_or_null("StagePath")
	if old != null:
		old.queue_free()
	_stage_path_root = Node3D.new()
	_stage_path_root.name = "StagePath"
	add_child(_stage_path_root)
	var ordered := _ordered_markers()
	for i in range(ordered.size() - 1):
		var a := ordered[i].global_position
		var b := ordered[i + 1].global_position
		var from_id := String(ordered[i].get_meta("stage_id", ""))
		var to_id := String(ordered[i + 1].get_meta("stage_id", ""))
		_add_path_segment(a, b, from_id, to_id)
	_refresh_stage_path()


func _ordered_markers() -> Array[Node3D]:
	var ordered: Array[Node3D] = []
	for stage in StageTable.STAGES:
		var stage_id := String(stage["id"])
		for marker in _markers:
			if String(marker.get_meta("stage_id", "")) == stage_id:
				ordered.append(marker)
				break
	return ordered


func _add_path_segment(from_pos: Vector3, to_pos: Vector3, from_id: String, to_id: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Path_%s_%s" % [from_id, to_id]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("from_id", from_id)
	mi.set_meta("to_id", to_id)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = PATH_LOCKED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if _is_globe():
		mi.mesh = _build_globe_path_mesh(from_pos, to_pos)
	else:
		var a := Vector3(from_pos.x, PATH_Y, from_pos.z)
		var b := Vector3(to_pos.x, PATH_Y, to_pos.z)
		var length := a.distance_to(b)
		if length < 0.05:
			return
		var mesh := BoxMesh.new()
		mesh.size = Vector3(PATH_WIDTH, 0.035, length * 0.86)
		mi.mesh = mesh
		_stage_path_root.add_child(mi)
		mi.global_position = (a + b) * 0.5
		mi.set_surface_override_material(0, mat)
		mi.look_at(b, Vector3.UP)
		return
	if mi.mesh == null:
		return
	_stage_path_root.add_child(mi)
	mi.set_surface_override_material(0, mat)


func _build_globe_path_mesh(from_pos: Vector3, to_pos: Vector3) -> ArrayMesh:
	var a := from_pos.normalized()
	var b := to_pos.normalized()
	if a.dot(b) > 0.999:
		return null
	var radius := _water_surface_radius() + 0.05
	var segs := 12
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var half_w := PATH_WIDTH * 0.55
	for i in segs + 1:
		var t := float(i) / float(segs)
		var p := a.slerp(b, t).normalized()
		var tangent := (b - a).slide(p)
		if tangent.length_squared() < 0.0001:
			tangent = p.cross(Vector3.RIGHT)
		tangent = tangent.normalized()
		var side := p.cross(tangent).normalized()
		var center := p * radius
		verts.append(center - side * half_w)
		verts.append(center + side * half_w)
		normals.append(p)
		normals.append(p)
	for i in segs:
		var i0 := i * 2
		indices.append_array([i0, i0 + 2, i0 + 1, i0 + 1, i0 + 2, i0 + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _refresh_stage_path() -> void:
	if _stage_path_root == null:
		return
	for child in _stage_path_root.get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		var from_id := String(mi.get_meta("from_id", ""))
		var to_id := String(mi.get_meta("to_id", ""))
		# 起点已通关，或终点已解锁：这段路算"走过/可走"。
		var open := _cleared.has(from_id) or StageTable.is_stage_unlocked(to_id, _cleared)
		var mat := mi.get_surface_override_material(0) as StandardMaterial3D
		if mat != null:
			mat.albedo_color = PATH_OPEN if open else PATH_LOCKED


# --- 相机 ---


func _apply_camera() -> void:
	if _camera == null:
		return
	var pitch := deg_to_rad(CAMERA_PITCH_DEG + _shot_pitch_off)
	var yaw := deg_to_rad(CAMERA_YAW_DEG + _shot_yaw_off)
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var look := _pivot + _shot_look_off
	var dist := _shot_current_dist()
	_camera.position = look + basis.z * dist
	_camera.rotation = Vector3(pitch, yaw, 0.0)


func _shot_current_dist() -> float:
	return _distance if _shot_dist < 0.0 else _shot_dist


func _reset_shot_camera() -> void:
	_shot_yaw_off = 0.0
	_shot_pitch_off = 0.0
	_shot_dist = -1.0
	_shot_look_off = Vector3.ZERO
	_apply_camera()


# --- 悬浮牌 ---


func _rebuild_badges() -> void:
	_clear_all_tile_hovers()
	for badge in _badges.values():
		badge.queue_free()
	_badges.clear()
	for marker in _markers:
		var stage_id := String(marker.get_meta("stage_id", ""))
		var stage := StageTable.stage(stage_id)
		if stage.is_empty():
			continue
		var badge := StageBadge.new()
		_badge_layer.add_child(badge)
		badge.bind(stage)
		badge.set_high_score(int(_high_scores.get(stage_id, 0)))
		badge.set_stage_state(_state_for(stage_id))
		badge.pressed.connect(_on_badge_pressed.bind(stage_id))
		badge.leaderboard_requested.connect(func(id: String) -> void: leaderboard_requested.emit(id))
		_badges[stage_id] = badge


func _clear_all_tile_hovers() -> void:
	_hovered_tile = null
	for tween in _tile_lift_tweens.values():
		if tween != null and tween.is_valid():
			tween.kill()
	_tile_lift_tweens.clear()
	for tile in _tiles:
		var outline := tile.get_node_or_null("TileOutline") as MeshInstance3D
		if outline != null:
			outline.visible = false
		for node in _hover_lift_targets(tile):
			if node.has_meta("hover_base_pos"):
				node.position = node.get_meta("hover_base_pos")
			elif node.has_meta("hover_base_y"):
				node.position.y = float(node.get_meta("hover_base_y"))


func _state_for(stage_id: String) -> int:
	if _cleared.has(stage_id):
		return StageBadge.State.CLEARED
	if not StageTable.is_stage_unlocked(stage_id, _cleared):
		return StageBadge.State.LOCKED
	if stage_id == _resume_stage_id:
		return StageBadge.State.IN_PROGRESS
	return StageBadge.State.AVAILABLE


## 每帧把关卡节点的 3D 坐标投影成屏幕坐标去摆牌。相机背后的点 `unproject_position`
## 会给出镜像坐标，所以必须先用 `is_position_behind` 挡掉——否则拉近时远处的牌子会
## 诡异地闪到屏幕另一侧。
func _process(_delta: float) -> void:
	if not visible or _camera == null:
		return
	# `unproject_position` 给的是**视口真实像素**，而 Control 的坐标活在 canvas_items
	# 拉伸后的逻辑空间（本项目 1920×1080）。窗口不是 1920×1080 时两者差一个缩放系数，
	# 直接拿去赋值会让所有牌子整体偏移、脱离自己的地格。用 CanvasLayer 自己的变换换算，
	# 分辨率与拉伸模式怎么变都对。
	var canvas_rect := Rect2(Vector2.ZERO, _badge_layer.size)
	for marker in _markers:
		var stage_id := String(marker.get_meta("stage_id", ""))
		var badge: StageBadge = _badges.get(stage_id)
		if badge == null:
			continue
		var up := marker.global_transform.basis.y.normalized()
		if up.length_squared() < 0.2:
			up = Vector3.UP
		var anchor := marker.global_position + up * BADGE_LIFT
		if _camera.is_position_behind(anchor):
			badge.visible = false
			continue
		var where := _unproject_to_badge_layer(anchor)
		# 尖角锚在地格投影点；缩放/旋转绕尖角，悬停时牌子往上长大而不挪开地格。
		badge.position = where - Vector2(badge.size.x * 0.5, badge.size.y)
		badge.visible = canvas_rect.grow(48.0).intersects(Rect2(badge.position, badge.size))

	_refresh_hover_from_pointer()
	_refresh_flora_hover_from_pointer()
	_spin_hovered_outline(_delta)
	_update_breadcrumbs(_delta)
	_update_hop_pigeons(_delta)
	_bob_floaters(_delta)
	_tick_drift_clouds(_delta)


func _unproject_to_badge_layer(world: Vector3) -> Vector2:
	var screen := _camera.unproject_position(world)
	var vp := get_viewport().get_visible_rect().size
	var layer := _badge_layer.size
	if vp.x < 1.0 or vp.y < 1.0 or layer.x < 1.0 or layer.y < 1.0:
		return screen
	# 视口像素 → BadgeLayer 逻辑坐标；16:9 拉伸时就是等比缩放。
	return Vector2(screen.x * layer.x / vp.x, screen.y * layer.y / vp.y)


func _spin_hovered_outline(delta: float) -> void:
	if _hovered_tile == null or not is_instance_valid(_hovered_tile):
		return
	var outline := _hovered_tile.get_node_or_null("TileOutline") as MeshInstance3D
	if outline == null or not outline.visible:
		return
	outline.rotate_y(HEX_OUTLINE_SPIN_SPEED * delta)


## 地图页特效：指针移动洒小屑；左/右键落下不同颜色的大面包供鸽子久啃。
func _setup_breadcrumbs() -> void:
	_crumb_root = Node3D.new()
	_crumb_root.name = "Breadcrumbs"
	add_child(_crumb_root)
	_crumb_box = BoxMesh.new()
	_crumb_box.size = Vector3(0.09, 0.034, 0.07)
	_loaf_mesh = _build_loaf_mesh()
	_loaf_phys_mat = PhysicsMaterial.new()
	_loaf_phys_mat.friction = 0.98
	_loaf_phys_mat.bounce = 0.12


## 程序化整条面包：拉长球体 + 平底 + 顶面刀痕，顶点色做外皮深浅。
func _build_loaf_mesh() -> ArrayMesh:
	var rings := 14
	var segs := 20
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var hx := LOAF_SIZE.x * 0.5
	var hy := LOAF_SIZE.y * 0.5
	var hz := LOAF_SIZE.z * 0.5

	for ring in range(rings + 1):
		var v := float(ring) / float(rings)
		var pitch := lerpf(-PI * 0.5, PI * 0.5, v)
		var cy := sin(pitch)
		var cr := cos(pitch)
		for seg in range(segs):
			var u := float(seg) / float(segs)
			var yaw := u * TAU
			var nx := cos(yaw) * cr
			var ny := cy
			var nz := sin(yaw) * cr
			# 中段略鼓，两端收成面包头。
			var along := nx
			var belly := 1.0 + 0.12 * (1.0 - along * along)
			var px := nx * hx
			var py := ny * hy * belly
			var pz := nz * hz * belly
			# 底面压平，才像搁在桌上的整条面包。
			if py < 0.0:
				py *= 0.55
			# 顶面三道刀痕：往下挖一点浅槽。
			var score := 0.0
			if py > hy * 0.15 and absf(nx) < 0.82:
				for k in 3:
					var slot := lerpf(-0.45, 0.45, float(k) / 2.0)
					var d := absf(nz - slot)
					if d < 0.07:
						score = maxf(score, 1.0 - d / 0.07)
				py -= score * hy * 0.22
				pz += signf(pz) * score * 0.01
			verts.append(Vector3(px, py, pz))
			var n := Vector3(nx, ny * (0.55 if ny < 0.0 else 1.0), nz).normalized()
			normals.append(n)
			# 顶皮更深、刀痕更深，底面稍浅。
			var shade := lerpf(1.0, LOAF_CRUST_DARK, clampf(ny * 0.55 + 0.45, 0.0, 1.0))
			shade = lerpf(shade, shade * 0.78, score)
			colors.append(Color(shade, shade, shade, 1.0))

	for ring in range(rings):
		for seg in range(segs):
			var i0 := ring * segs + seg
			var i1 := ring * segs + ((seg + 1) % segs)
			var i2 := (ring + 1) * segs + seg
			var i3 := (ring + 1) * segs + ((seg + 1) % segs)
			indices.append_array([i0, i2, i1, i1, i2, i3])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _clear_breadcrumbs() -> void:
	_crumb_emit_accum = 0.0
	_last_crumb_screen = Vector2(-99999.0, -99999.0)
	if _crumb_root == null:
		return
	for child in _crumb_root.get_children():
		child.queue_free()


func _update_breadcrumbs(delta: float) -> void:
	if _crumb_root == null or _camera == null:
		return
	if _confirm != null and _confirm.visible:
		return
	var screen := get_viewport().get_mouse_position()
	if not get_viewport().get_visible_rect().has_point(screen):
		return
	if _is_world_map_chrome(get_viewport().gui_get_hovered_control()):
		return
	# 鼠标几乎没动就不落屑；否则鸽子会围着同一点狂啄，看着像抽搐。
	var moved := screen.distance_to(_last_crumb_screen)
	if moved < CRUMB_MOVE_THRESHOLD:
		_crumb_emit_accum = 0.0
		return
	_last_crumb_screen = screen
	_crumb_emit_accum += delta
	while _crumb_emit_accum >= CRUMB_EMIT_INTERVAL:
		_crumb_emit_accum -= CRUMB_EMIT_INTERVAL
		_spawn_breadcrumb(screen)
	_trim_crumb_overflow()


func _trim_crumb_overflow() -> void:
	var crumb_count := 0
	for child in _crumb_root.get_children():
		if String(child.get_meta("food_kind", "crumb")) == "crumb":
			crumb_count += 1
	while crumb_count > CRUMB_MAX:
		for child in _crumb_root.get_children():
			if String(child.get_meta("food_kind", "crumb")) != "crumb":
				continue
			_crumb_root.remove_child(child)
			child.queue_free()
			crumb_count -= 1
			break


func _loaf_count() -> int:
	var n := 0
	if _crumb_root == null:
		return 0
	for child in _crumb_root.get_children():
		if String(child.get_meta("food_kind", "")) == "loaf":
			n += 1
	return n


func _ground_point_at_screen(screen_pos: Vector2) -> Vector3:
	if _camera == null:
		return Vector3.ZERO
	var world := _camera.get_world_3d()
	if world != null and world.direct_space_state != null:
		var origin := _camera.project_ray_origin(screen_pos)
		var dir := _camera.project_ray_normal(screen_pos)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 400.0)
		query.collision_mask = TILE_PICK_COLLISION_LAYER
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return hit.position as Vector3
	var origin2 := _camera.project_ray_origin(screen_pos)
	var dir2 := _camera.project_ray_normal(screen_pos)
	if absf(dir2.y) < 0.0001:
		return Vector3(origin2.x, 0.0, origin2.z)
	var distance := -origin2.y / dir2.y
	if distance < 0.0:
		return Vector3(origin2.x, 0.0, origin2.z)
	return origin2 + dir2 * distance


func _spawn_breadcrumb(screen_pos: Vector2) -> void:
	var ground := _ground_point_at_screen(screen_pos)
	var body := RigidBody3D.new()
	body.name = "Breadcrumb"
	body.set_meta("food_kind", "crumb")
	body.set_meta("bites", 1)
	body.collision_layer = CRUMB_COLLISION_LAYER
	body.collision_mask = TILE_PICK_COLLISION_LAYER
	body.mass = 0.04
	body.continuous_cd = true
	body.gravity_scale = 1.35
	body.linear_damp = 0.15
	body.angular_damp = 0.4

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = _crumb_box
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tone := randf()
	mat.albedo_color = Color(
		lerpf(0.86, 0.96, tone),
		lerpf(0.68, 0.82, tone),
		lerpf(0.38, 0.52, tone)
	)
	mesh.set_surface_override_material(0, mat)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _crumb_box.size
	shape.shape = box

	body.add_child(mesh)
	body.add_child(shape)
	_crumb_root.add_child(body)
	body.global_position = ground + Vector3(
		randf_range(-0.1, 0.1),
		randf_range(0.4, 0.75),
		randf_range(-0.1, 0.1)
	)
	body.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	body.linear_velocity = Vector3(
		randf_range(-0.55, 0.55),
		randf_range(0.15, 0.9),
		randf_range(-0.55, 0.55)
	)
	body.angular_velocity = Vector3(
		randf_range(-8.0, 8.0),
		randf_range(-8.0, 8.0),
		randf_range(-8.0, 8.0)
	)
	_retire_food(body, mesh, CRUMB_LIFETIME)


## 左键金黄大面包 / 右键深褐大面包；体积大、口数多，彼此碰撞，鸽子能围着啃很久。
func _spawn_loaf(screen_pos: Vector2, left_click: bool) -> void:
	if _crumb_root == null or _camera == null or _loaf_mesh == null:
		return
	if _is_world_map_chrome(get_viewport().gui_get_hovered_control()):
		return
	_spawn_loaf_at(_ground_point_at_screen(screen_pos), left_click)


func _spawn_loaf_at(ground: Vector3, left_click: bool) -> void:
	if _crumb_root == null or _loaf_mesh == null:
		return
	while _loaf_count() >= LOAF_MAX:
		for child in _crumb_root.get_children():
			if String(child.get_meta("food_kind", "")) != "loaf":
				continue
			_crumb_root.remove_child(child)
			child.queue_free()
			break

	var body := RigidBody3D.new()
	body.name = "BreadLoaf"
	body.set_meta("food_kind", "loaf")
	body.set_meta("bites", LOAF_BITES)
	body.set_meta("bites_max", LOAF_BITES)
	# 层 4：和其他面包/屑互撞；mask 含地格 + 食物层。
	body.collision_layer = CRUMB_COLLISION_LAYER
	body.collision_mask = LOAF_FOOD_MASK
	body.mass = 0.85
	body.continuous_cd = true
	body.gravity_scale = 1.55
	body.linear_damp = 1.8
	body.angular_damp = 2.4
	body.physics_material_override = _loaf_phys_mat

	var visual := Node3D.new()
	visual.name = "Mesh"
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = _loaf_mesh
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = LOAF_LEFT_COLOR if left_click else LOAF_RIGHT_COLOR
	shell.set_surface_override_material(0, mat)
	visual.add_child(shell)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = minf(LOAF_SIZE.y, LOAF_SIZE.z) * 0.48
	capsule.height = maxf(LOAF_SIZE.x - capsule.radius * 2.0, capsule.radius * 2.05)
	shape.shape = capsule
	# 胶囊默认沿 Y；转到沿 X，贴合整条面包的长轴。
	shape.rotation_degrees = Vector3(0.0, 0.0, 90.0)

	body.add_child(visual)
	body.add_child(shape)
	_crumb_root.add_child(body)
	body.global_position = ground + Vector3(
		randf_range(-0.06, 0.06),
		randf_range(0.55, 0.85),
		randf_range(-0.06, 0.06)
	)
	body.rotation = Vector3(
		randf_range(-0.2, 0.2),
		randf() * TAU,
		randf_range(-0.15, 0.15)
	)
	body.linear_velocity = Vector3(
		randf_range(-0.2, 0.2),
		randf_range(0.2, 0.55),
		randf_range(-0.2, 0.2)
	)
	body.angular_velocity = Vector3(
		randf_range(-1.5, 1.5),
		randf_range(-2.0, 2.0),
		randf_range(-1.5, 1.5)
	)
	if is_in_water(ground):
		body.set_meta("in_water", true)
		body.set_meta("heron_claimed", true)
	_settle_loaf(body, ground.y)
	_retire_food(body, visual, LOAF_LIFETIME)


## 落地后很快冻住，免得一直滚、鸽子围着追却啄不着。
func _settle_loaf(body: RigidBody3D, ground_y: float) -> void:
	await get_tree().create_timer(LOAF_SETTLE_TIME).timeout
	if not is_instance_valid(body):
		return
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze = true
	var p := body.global_position
	var e := body.rotation
	e.x = 0.0
	e.z = 0.0
	body.rotation = e
	if bool(body.get_meta("in_water", false)) or is_in_water(p):
		body.set_meta("in_water", true)
		body.set_meta("heron_claimed", true)
		p.y = 0.07
		body.global_position = p
		_queue_heron_snatch(body)
		return
	p.y = ground_y + LOAF_SIZE.y * 0.28
	body.global_position = p


func _retire_food(body: RigidBody3D, visual: Node3D, lifetime: float) -> void:
	await get_tree().create_timer(lifetime).timeout
	if not is_instance_valid(body):
		return
	var tween := body.create_tween()
	tween.tween_property(visual, "scale", Vector3.ZERO, CRUMB_FADE)
	await tween.finished
	if is_instance_valid(body):
		body.queue_free()


func _peck_food(meal: Node3D, crumbs: Array[Node3D]) -> void:
	if meal == null or not is_instance_valid(meal):
		return
	var bites := int(meal.get_meta("bites", 1)) - 1
	meal.set_meta("bites", bites)
	var kind := String(meal.get_meta("food_kind", "crumb"))
	if kind == "loaf":
		var bites_max := maxi(int(meal.get_meta("bites_max", LOAF_BITES)), 1)
		var visual := meal.get_node_or_null("Mesh") as Node3D
		if visual != null:
			var t := clampf(float(bites) / float(bites_max), 0.22, 1.0)
			visual.scale = Vector3(t, lerpf(0.4, 1.0, t), t)
		if bites > 0:
			return
	crumbs.erase(meal)
	meal.queue_free()


## 一群用鸽子面片做成的跳跳鸽，专追面包屑；没屑时在地图上闲逛蹦跶。
func _setup_hop_pigeons() -> void:
	_pigeon_root = Node3D.new()
	_pigeon_root.name = "HopPigeons"
	add_child(_pigeon_root)
	for i in HOP_PIGEON_COUNT:
		var bird := Node3D.new()
		bird.name = "HopPigeon_%d" % i
		var sprite := Sprite3D.new()
		sprite.name = "Sprite"
		sprite.texture = HOP_PIGEON_TEXTURES[i % HOP_PIGEON_TEXTURES.size()]
		sprite.pixel_size = HOP_PIXEL_SIZE
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.transparent = true
		sprite.shaded = false
		sprite.double_sided = true
		sprite.centered = true
		sprite.position = Vector3(0.0, 0.28, 0.0)
		sprite.render_priority = 2
		bird.add_child(sprite)
		bird.set_meta("hop_t", randf() * TAU)
		bird.set_meta("ground_y", 0.0)
		bird.set_meta("wander", Vector3.ZERO)
		bird.set_meta("rest_t", randf_range(0.0, HOP_REST_MAX))
		bird.set_meta("face_left", false)
		bird.set_meta("peck_cd", 0.0)
		_pigeon_root.add_child(bird)
	_scatter_hop_pigeons()


func _scatter_hop_pigeons() -> void:
	if _pigeon_root == null:
		return
	if _kestrel != null:
		for child in _kestrel.get_children():
			if child is Node3D and child != _kestrel_sprite:
				_return_pigeon(child as Node3D, false)
	var center := _map_bounds.get_center()
	for bird in _pigeon_root.get_children():
		if not (bird is Node3D):
			continue
		var node := bird as Node3D
		var pos := Vector3(
			center.x + randf_range(-_map_bounds.size.x * 0.35, _map_bounds.size.x * 0.35),
			0.0,
			center.y + randf_range(-_map_bounds.size.y * 0.35, _map_bounds.size.y * 0.35)
		)
		node.global_position = pos
		node.set_meta("ground_y", 0.0)
		node.set_meta("hop_t", randf() * TAU)
		node.set_meta("wander", _random_wander_point())
		node.set_meta("rest_t", randf_range(0.2, HOP_REST_MAX))
		node.set_meta("peck_cd", 0.0)
		node.set_meta("snatched", false)
		node.set_meta("respawn_token", int(node.get_meta("respawn_token", 0)) + 1)
		node.visible = true
		node.scale = Vector3.ONE


func _random_wander_point() -> Vector3:
	var center := _map_bounds.get_center()
	return Vector3(
		center.x + randf_range(-_map_bounds.size.x * 0.4, _map_bounds.size.x * 0.4),
		0.0,
		center.y + randf_range(-_map_bounds.size.y * 0.4, _map_bounds.size.y * 0.4)
	)


func _live_crumbs() -> Array[Node3D]:
	var loaves: Array[Node3D] = []
	var crumbs: Array[Node3D] = []
	if _crumb_root == null:
		return crumbs
	for child in _crumb_root.get_children():
		if not (child is Node3D) or not is_instance_valid(child):
			continue
		var node := child as Node3D
		# 还在缩没动画里的不追。
		if int(node.get_meta("bites", 1)) <= 0:
			continue
		if bool(node.get_meta("in_water", false)) or bool(node.get_meta("heron_claimed", false)):
			continue
		if String(node.get_meta("food_kind", "crumb")) == "loaf":
			loaves.append(node)
		else:
			crumbs.append(node)
	# 场上有大面包时全体先啃面包，避免碎屑把鸽子引开、面包干搁着。
	if not loaves.is_empty():
		return loaves
	return crumbs


func _update_hop_pigeons(delta: float) -> void:
	if _pigeon_root == null:
		return
	var crumbs := _live_crumbs()
	var index := 0
	for child in _pigeon_root.get_children():
		if not (child is Node3D):
			continue
		var bird := child as Node3D
		if bool(bird.get_meta("snatched", false)) or not bird.visible:
			continue
		var sprite := bird.get_node_or_null("Sprite") as Sprite3D
		var ground_y := float(bird.get_meta("ground_y", 0.0))
		var resting := false
		var meal := _assigned_food(crumbs, index)
		index += 1
		var chasing := meal != null
		var after_loaf := chasing and String(meal.get_meta("food_kind", "")) == "loaf"
		var hop_speed := HOP_FREQ if chasing else HOP_WANDER_FREQ
		var move_speed := HOP_LOAF_SPEED if after_loaf else (HOP_SPEED if chasing else HOP_WANDER_SPEED)

		var peck_cd := maxf(0.0, float(bird.get_meta("peck_cd", 0.0)) - delta)
		bird.set_meta("peck_cd", peck_cd)

		if not chasing:
			var rest_t := float(bird.get_meta("rest_t", 0.0))
			if rest_t > 0.0:
				rest_t = maxf(0.0, rest_t - delta)
				bird.set_meta("rest_t", rest_t)
				resting = rest_t > 0.0
				if not resting:
					bird.set_meta("wander", _random_wander_point())

		var hop_t := float(bird.get_meta("hop_t", 0.0))
		if resting:
			hop_t = move_toward(hop_t, roundf(hop_t / PI) * PI, delta * 8.0)
		else:
			hop_t += delta * hop_speed
		bird.set_meta("hop_t", hop_t)

		var target := _hop_target_point(bird, meal)
		var pos := bird.global_position
		var flat := Vector3(target.x - pos.x, 0.0, target.z - pos.z)
		var dist := flat.length()
		var arrive := (LOAF_EAT_RADIUS * 0.35) if after_loaf else HOP_ARRIVE_RADIUS
		if not resting and dist > arrive:
			var step := minf(move_speed * delta, dist)
			pos += flat.normalized() * step
			if sprite != null and absf(flat.x) > 0.08:
				var face_left := bool(bird.get_meta("face_left", false))
				if flat.x < -0.08:
					face_left = true
				elif flat.x > 0.08:
					face_left = false
				bird.set_meta("face_left", face_left)
				sprite.flip_h = face_left
		elif not chasing and not resting and dist <= arrive:
			bird.set_meta("rest_t", randf_range(HOP_REST_MIN, HOP_REST_MAX))

		var bounce := 0.0 if resting else absf(sin(hop_t))
		var height := HOP_HEIGHT if chasing else HOP_HEIGHT * 0.55
		pos.y = ground_y + bounce * height
		bird.global_position = pos

		# 贴地半拍就能啄：用冷却控频率，不再靠跳跃边沿（边沿很容易漏）。
		if chasing and meal != null and is_instance_valid(meal) and peck_cd <= 0.0 and bounce <= HOP_PECK_GROUND:
			var eat_r := LOAF_EAT_RADIUS if after_loaf else HOP_EAT_RADIUS
			var meal_d := Vector2(meal.global_position.x - pos.x, meal.global_position.z - pos.z).length()
			if meal_d <= eat_r:
				_peck_food(meal, crumbs)
				bird.set_meta("peck_cd", HOP_PECK_INTERVAL)


func _assigned_food(crumbs: Array[Node3D], index: int) -> Node3D:
	if crumbs.is_empty():
		return null
	return crumbs[index % crumbs.size()]


func _hop_target_point(bird: Node3D, meal: Node3D) -> Vector3:
	if meal != null and is_instance_valid(meal):
		bird.set_meta("rest_t", 0.0)
		return meal.global_position
	var wander: Vector3 = bird.get_meta("wander", Vector3.ZERO)
	if wander == Vector3.ZERO:
		wander = _random_wander_point()
		bird.set_meta("wander", wander)
	return wander


func _nearest_crumb(from: Vector3, crumbs: Array[Node3D]) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for crumb in crumbs:
		if not is_instance_valid(crumb):
			continue
		var d := Vector2(crumb.global_position.x - from.x, crumb.global_position.z - from.z).length_squared()
		if d < best_d:
			best_d = d
			best = crumb
	return best


func _collect_ponds() -> void:
	_pond_centers.clear()
	var host := get_node_or_null("Ponds")
	if host == null:
		return
	for child in host.get_children():
		if child is Node3D:
			_pond_centers.append((child as Node3D).global_position)


func is_in_water(pos: Vector3, extra := 0.12) -> bool:
	var limit := HERON_POND_RADIUS + extra
	for center in _pond_centers:
		if Vector2(pos.x - center.x, pos.z - center.z).length() < limit:
			return true
	return false


func pond_point() -> Vector3:
	if _pond_centers.is_empty():
		return Vector3.ZERO
	return _pond_centers[0]


func _setup_heron() -> void:
	_heron = Node3D.new()
	_heron.name = "NightHeron"
	_heron.visible = false
	_heron_sprite = Sprite3D.new()
	_heron_sprite.name = "Sprite"
	_heron_sprite.texture = HERON_FLY[0]
	_heron_sprite.pixel_size = HERON_PIXEL_SIZE
	_heron_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_heron_sprite.transparent = true
	_heron_sprite.shaded = false
	_heron_sprite.double_sided = true
	_heron_sprite.centered = true
	_heron_sprite.no_depth_test = true
	_heron_sprite.render_priority = 7
	_heron.add_child(_heron_sprite)
	add_child(_heron)
	_heron_fx = Node3D.new()
	_heron_fx.name = "HeronFx"
	add_child(_heron_fx)
	_heron_voice = AudioStreamPlayer.new()
	_heron_voice.name = "HeronCall"
	_heron_voice.stream = HERON_CALL
	_heron_voice.volume_db = -5.0
	add_child(_heron_voice)


func _stop_heron() -> void:
	_heron_gen += 1
	_heron_busy = false
	_heron_queue.clear()
	if _heron_move_tween != null and _heron_move_tween.is_valid():
		_heron_move_tween.kill()
	_clear_heron_croaks()
	if _heron != null:
		_heron.visible = false


func _queue_heron_snatch(loaf: Node3D) -> void:
	if not heron_events or _is_globe() or loaf == null:
		return
	if _heron_busy:
		_heron_queue.append(loaf)
		return
	play_heron_snatch(loaf)


func play_heron_snatch(loaf: Node3D) -> void:
	if _heron_busy or _is_globe() or _heron == null:
		return
	if loaf == null or not is_instance_valid(loaf):
		return
	_heron_busy = true
	var gen := _heron_gen
	loaf.set_meta("heron_claimed", true)
	var target := loaf.global_position + Vector3(0.0, 0.22, 0.0)
	var from_left := randf() < 0.5
	var span := maxf(_map_bounds.size.x * 0.55, 6.5)
	var start := Vector3(
		_map_bounds.get_center().x + span * (-1.0 if from_left else 1.0),
		2.15,
		target.z + randf_range(-0.5, 0.5)
	)
	var hover := target + Vector3(0.0, 0.72, 0.08)
	var exit_p := Vector3(
		_map_bounds.get_center().x + span * (1.1 if from_left else -1.1),
		2.35,
		target.z + randf_range(-0.8, 0.8)
	)
	_heron.global_position = start
	_heron.visible = true
	_face_heron(not from_left)
	_flap_heron(0)
	await _move_heron(hover, 0.62)
	if gen != _heron_gen or not visible:
		_finish_heron_snatch()
		return
	_flap_heron(1)
	await _move_heron(target + Vector3(0.0, 0.18, 0.0), 0.16)
	if gen != _heron_gen:
		_finish_heron_snatch()
		return
	_snatch_loaf(loaf)
	_play_heron_croaks(gen)
	await _move_heron(hover + Vector3(0.0, 0.2, 0.0), 0.18)
	if gen != _heron_gen or not visible:
		_finish_heron_snatch()
		return
	_face_heron(exit_p.x >= _heron.global_position.x)
	_flap_heron(0)
	await _move_heron(exit_p, 0.52)
	_finish_heron_snatch()
	if heron_events and visible and not _heron_queue.is_empty():
		var next: Node3D = null
		while not _heron_queue.is_empty():
			next = _heron_queue.pop_front()
			if is_instance_valid(next):
				break
			next = null
		if next != null:
			play_heron_snatch(next)


func _finish_heron_snatch() -> void:
	if _heron != null:
		_heron.visible = false
	_heron_busy = false


func _clear_heron_croaks() -> void:
	if _heron_fx == null:
		return
	for child in _heron_fx.get_children():
		child.queue_free()


func _face_heron(facing_right: bool) -> void:
	if _heron_sprite != null:
		_heron_sprite.flip_h = facing_right


func _flap_heron(frame: int) -> void:
	if _heron_sprite == null or HERON_FLY.is_empty():
		return
	_heron_sprite.texture = HERON_FLY[frame % HERON_FLY.size()]


func _move_heron(target: Vector3, duration: float) -> void:
	if _heron == null:
		return
	if _heron_move_tween != null and _heron_move_tween.is_valid():
		_heron_move_tween.kill()
	_face_heron(target.x >= _heron.global_position.x)
	_heron_move_tween = _heron.create_tween()
	_heron_move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_heron_move_tween.tween_property(_heron, "global_position", target, duration)
	await _heron_move_tween.finished


func _snatch_loaf(loaf: Node3D) -> void:
	if loaf == null or not is_instance_valid(loaf):
		return
	if bool(loaf.get_meta("heron_eaten", false)):
		return
	loaf.set_meta("heron_eaten", true)
	loaf.set_meta("bites", 0)
	if loaf is RigidBody3D:
		(loaf as RigidBody3D).freeze = true
		(loaf as RigidBody3D).collision_layer = 0
	var grab := loaf.global_position
	var parent := loaf.get_parent()
	if parent != null:
		parent.remove_child(loaf)
	_heron.add_child(loaf)
	loaf.global_position = grab
	loaf.position = Vector3(0.12, -0.1, 0.04)
	loaf.scale = Vector3.ONE * 0.45
	var gulp := loaf.create_tween()
	gulp.tween_property(loaf, "scale", Vector3.ONE * 0.02, 0.16)
	gulp.tween_callback(loaf.queue_free)
	_register_loaf_eaten()


func _play_heron_croaks(generation: int) -> void:
	if _heron_voice != null:
		_heron_voice.pitch_scale = randf_range(0.94, 1.08)
		_heron_voice.play()
	_trail_heron_croaks(generation)


func _trail_heron_croaks(generation: int) -> void:
	# 世界坐标逐颗落下，不继承鸟的速度，留下一串呱的拖尾。
	for _i in HERON_CROAK_COUNT:
		if generation != _heron_gen or _heron == null or not _heron.visible:
			return
		_spawn_heron_croak(_heron.global_position)
		await get_tree().create_timer(0.075).timeout


func _burst_heron_croaks(origin: Vector3) -> void:
	if _heron_fx == null:
		return
	for _i in HERON_CROAK_COUNT:
		_spawn_heron_croak(origin)


func _spawn_heron_croak(origin: Vector3) -> void:
	if _heron_fx == null:
		return
	var glyph := Label3D.new()
	glyph.text = HERON_CROAK_GLYPHS[randi() % HERON_CROAK_GLYPHS.size()]
	glyph.font = FLORA_NOTE_FONT
	glyph.font_size = randi_range(52, 84)
	glyph.pixel_size = 0.0078
	glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glyph.no_depth_test = true
	glyph.render_priority = 10
	glyph.outline_size = 10
	glyph.outline_modulate = Color(0.08, 0.12, 0.18, 0.9)
	glyph.modulate = Color(0.78, 0.92, 1.0, 1.0)
	_heron_fx.add_child(glyph)
	glyph.global_position = origin + Vector3(
		randf_range(-0.08, 0.08),
		randf_range(0.12, 0.28),
		randf_range(-0.08, 0.08)
	)
	var dest := glyph.global_position + Vector3(
		randf_range(-0.12, 0.12),
		randf_range(0.35, 0.7),
		randf_range(-0.1, 0.1)
	)
	var life := randf_range(0.7, 1.05)
	var flight := glyph.create_tween()
	flight.set_parallel(true)
	flight.tween_property(glyph, "global_position", dest, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.tween_property(glyph, "modulate:a", 0.0, life).set_delay(life * 0.4)
	flight.tween_property(glyph, "scale", Vector3.ONE * randf_range(0.65, 0.95), life)
	flight.chain().tween_callback(glyph.queue_free)


func _setup_kestrel() -> void:
	_kestrel = Node3D.new()
	_kestrel.name = "Kestrel"
	_kestrel.visible = false
	_kestrel_sprite = Sprite3D.new()
	_kestrel_sprite.name = "Sprite"
	_kestrel_sprite.texture = KESTREL_FLY
	_kestrel_sprite.pixel_size = KESTREL_PIXEL_SIZE
	_kestrel_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_kestrel_sprite.transparent = true
	_kestrel_sprite.shaded = false
	_kestrel_sprite.double_sided = true
	_kestrel_sprite.centered = true
	_kestrel_sprite.no_depth_test = true
	_kestrel_sprite.render_priority = 7
	_kestrel.add_child(_kestrel_sprite)
	add_child(_kestrel)
	_kestrel_fx = Node3D.new()
	_kestrel_fx.name = "KestrelFx"
	add_child(_kestrel_fx)
	_kestrel_voice = AudioStreamPlayer.new()
	_kestrel_voice.name = "KestrelCall"
	_kestrel_voice.stream = KESTREL_CALL
	_kestrel_voice.volume_db = -5.0
	add_child(_kestrel_voice)


func _kick_kestrel_loop() -> void:
	_kestrel_loop_gen += 1
	_kestrel_loop(_kestrel_loop_gen)


func _stop_kestrel() -> void:
	_kestrel_loop_gen += 1
	_kestrel_busy = false
	if _kestrel_move_tween != null and _kestrel_move_tween.is_valid():
		_kestrel_move_tween.kill()
	if _kestrel != null:
		for child in _kestrel.get_children():
			if child == _kestrel_sprite:
				continue
			if child is Node3D:
				_return_pigeon(child as Node3D, false)
		_kestrel.visible = false
	_clear_kestrel_coos()


func _kestrel_loop(generation: int) -> void:
	var first := true
	while generation == _kestrel_loop_gen and is_inside_tree():
		var wait := KESTREL_FIRST_WAIT if first else KESTREL_INTERVAL
		first = false
		await get_tree().create_timer(randf_range(wait.x, wait.y)).timeout
		if generation != _kestrel_loop_gen or not visible:
			return
		await play_kestrel_raid()


func standing_pigeons() -> Array[Node3D]:
	var birds: Array[Node3D] = []
	if _pigeon_root == null:
		return birds
	for child in _pigeon_root.get_children():
		if not (child is Node3D) or not is_instance_valid(child):
			continue
		var bird := child as Node3D
		if bool(bird.get_meta("snatched", false)) or not bird.visible:
			continue
		birds.append(bird)
	return birds


## 飞来红隼，叼走一只跳跳鸽。`respawn_after < 0` 时用随机间隔再放回。
func play_kestrel_raid(pigeon: Node3D = null, respawn_after := -1.0) -> void:
	if _kestrel_busy or _is_globe() or _kestrel == null:
		return
	if pigeon == null or not is_instance_valid(pigeon) or bool(pigeon.get_meta("snatched", false)):
		var pool := standing_pigeons()
		if pool.is_empty():
			return
		pigeon = pool[randi() % pool.size()]
	_kestrel_busy = true
	var gen := _kestrel_loop_gen
	pigeon.set_meta("snatched", true)
	var prey := pigeon.global_position + Vector3(0.0, 0.35, 0.0)
	var from_left := randf() < 0.5
	var span := maxf(_map_bounds.size.x * 0.55, 6.5)
	var start := Vector3(
		_map_bounds.get_center().x + span * (-1.0 if from_left else 1.0),
		2.4,
		prey.z + randf_range(-0.6, 0.6)
	)
	var hover := prey + Vector3(0.0, 0.85, 0.06)
	var exit_p := Vector3(
		_map_bounds.get_center().x + span * (1.1 if from_left else -1.1),
		2.55,
		prey.z + randf_range(-0.8, 0.8)
	)
	_kestrel.global_position = start
	_kestrel.visible = true
	_face_kestrel(not from_left)
	_flap_kestrel(false)
	if _kestrel_voice != null:
		_kestrel_voice.pitch_scale = randf_range(0.96, 1.08)
		_kestrel_voice.play()
	await _move_kestrel(hover, 0.58)
	if gen != _kestrel_loop_gen or not visible:
		_finish_kestrel_raid()
		return
	_flap_kestrel(true)
	await _move_kestrel(prey, 0.16)
	if gen != _kestrel_loop_gen:
		_finish_kestrel_raid()
		return
	_grab_pigeon(pigeon)
	_trail_kestrel_coos(gen)
	await _move_kestrel(hover + Vector3(0.0, 0.18, 0.0), 0.16)
	if gen != _kestrel_loop_gen or not visible:
		_finish_kestrel_raid()
		return
	_face_kestrel(exit_p.x >= _kestrel.global_position.x)
	_flap_kestrel(false)
	await _move_kestrel(exit_p, 0.52)
	var delay := respawn_after
	if delay < 0.0:
		delay = randf_range(KESTREL_RESPAWN.x, KESTREL_RESPAWN.y)
	_schedule_pigeon_return(pigeon, delay)
	_finish_kestrel_raid()


func _finish_kestrel_raid() -> void:
	if _kestrel != null:
		_kestrel.visible = false
	_kestrel_busy = false


func _face_kestrel(facing_right: bool) -> void:
	if _kestrel_sprite != null:
		_kestrel_sprite.flip_h = facing_right


func _flap_kestrel(diving: bool) -> void:
	if _kestrel_sprite == null:
		return
	_kestrel_sprite.texture = KESTREL_FLAP if diving else KESTREL_FLY


func _move_kestrel(target: Vector3, duration: float) -> void:
	if _kestrel == null:
		return
	if _kestrel_move_tween != null and _kestrel_move_tween.is_valid():
		_kestrel_move_tween.kill()
	_face_kestrel(target.x >= _kestrel.global_position.x)
	_kestrel_move_tween = _kestrel.create_tween()
	_kestrel_move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_kestrel_move_tween.tween_property(_kestrel, "global_position", target, duration)
	await _kestrel_move_tween.finished


func _grab_pigeon(pigeon: Node3D) -> void:
	if pigeon == null or not is_instance_valid(pigeon):
		return
	pigeon.set_meta("snatched", true)
	var grab := pigeon.global_position
	var parent := pigeon.get_parent()
	if parent != _kestrel:
		if parent != null:
			parent.remove_child(pigeon)
		_kestrel.add_child(pigeon)
		pigeon.global_position = grab
	pigeon.position = Vector3(0.1, -0.12, 0.03)
	pigeon.scale = Vector3.ONE * 0.7
	var gulp := pigeon.create_tween()
	gulp.tween_property(pigeon, "scale", Vector3.ONE * 0.08, 0.2)
	gulp.tween_callback(func() -> void:
		if is_instance_valid(pigeon):
			pigeon.visible = false
			pigeon.scale = Vector3.ONE
	)
	_register_pigeon_eaten()


func _return_pigeon(pigeon: Node3D, place: bool) -> void:
	if pigeon == null or not is_instance_valid(pigeon):
		return
	if pigeon.get_parent() != _pigeon_root and _pigeon_root != null:
		var gp := pigeon.global_position
		pigeon.get_parent().remove_child(pigeon)
		_pigeon_root.add_child(pigeon)
		pigeon.global_position = gp
	pigeon.scale = Vector3.ONE
	pigeon.set_meta("snatched", false)
	if place:
		var spot := _random_wander_point()
		pigeon.global_position = spot
		pigeon.set_meta("ground_y", 0.0)
		pigeon.set_meta("wander", _random_wander_point())
		pigeon.set_meta("rest_t", randf_range(0.3, HOP_REST_MAX))
		pigeon.visible = true
	else:
		pigeon.visible = false


func _schedule_pigeon_return(pigeon: Node3D, delay: float) -> void:
	var token := int(pigeon.get_meta("respawn_token", 0)) + 1
	pigeon.set_meta("respawn_token", token)
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(pigeon):
		return
	if int(pigeon.get_meta("respawn_token", 0)) != token:
		return
	_return_pigeon(pigeon, true)


func _clear_kestrel_coos() -> void:
	if _kestrel_fx == null:
		return
	for child in _kestrel_fx.get_children():
		child.queue_free()


func _trail_kestrel_coos(generation: int) -> void:
	for _i in KESTREL_COO_COUNT:
		if generation != _kestrel_loop_gen or _kestrel == null or not _kestrel.visible:
			return
		_spawn_kestrel_coo(_kestrel.global_position)
		await get_tree().create_timer(0.075).timeout


func _burst_kestrel_coos(origin: Vector3) -> void:
	if _kestrel_fx == null:
		return
	for _i in KESTREL_COO_COUNT:
		_spawn_kestrel_coo(origin)


func _spawn_kestrel_coo(origin: Vector3) -> void:
	if _kestrel_fx == null:
		return
	var glyph := Label3D.new()
	glyph.text = KESTREL_COO_GLYPHS[randi() % KESTREL_COO_GLYPHS.size()]
	glyph.font = FLORA_NOTE_FONT
	glyph.font_size = randi_range(52, 84)
	glyph.pixel_size = 0.0078
	glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glyph.no_depth_test = true
	glyph.render_priority = 10
	glyph.outline_size = 10
	glyph.outline_modulate = Color(0.22, 0.12, 0.05, 0.9)
	glyph.modulate = Color(1.0, 0.84, 0.52, 1.0)
	_kestrel_fx.add_child(glyph)
	glyph.global_position = origin + Vector3(
		randf_range(-0.08, 0.08),
		randf_range(0.12, 0.28),
		randf_range(-0.08, 0.08)
	)
	var dest := glyph.global_position + Vector3(
		randf_range(-0.12, 0.12),
		randf_range(0.35, 0.7),
		randf_range(-0.1, 0.1)
	)
	var life := randf_range(0.7, 1.05)
	var flight := glyph.create_tween()
	flight.set_parallel(true)
	flight.tween_property(glyph, "global_position", dest, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.tween_property(glyph, "modulate:a", 0.0, life).set_delay(life * 0.4)
	flight.tween_property(glyph, "scale", Vector3.ONE * randf_range(0.65, 0.95), life)
	flight.chain().tween_callback(glyph.queue_free)


func _setup_woodpecker() -> void:
	_woodpecker_fx = Node3D.new()
	_woodpecker_fx.name = "WoodpeckerFx"
	add_child(_woodpecker_fx)
	_woodpecker = Node3D.new()
	_woodpecker.name = "Woodpecker"
	_woodpecker.visible = false
	var quad := QuadMesh.new()
	quad.size = Vector2(WOODPECKER_CARD_SIZE, WOODPECKER_CARD_SIZE)
	_woodpecker_mat = StandardMaterial3D.new()
	_woodpecker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_woodpecker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_woodpecker_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_woodpecker_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_woodpecker_mat.albedo_texture = WOODPECKER_FLY
	_woodpecker_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_woodpecker_mat.no_depth_test = true
	_woodpecker_card = MeshInstance3D.new()
	_woodpecker_card.name = "Card"
	_woodpecker_card.mesh = quad
	_woodpecker_card.material_override = _woodpecker_mat
	_woodpecker_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_woodpecker.add_child(_woodpecker_card)
	add_child(_woodpecker)
	_woodpecker_chip_mesh = BoxMesh.new()
	_woodpecker_chip_mesh.size = Vector3(0.055, 0.03, 0.04)
	_woodpecker_peck_voice = AudioStreamPlayer.new()
	_woodpecker_peck_voice.name = "WoodpeckerPeck"
	_woodpecker_peck_voice.stream = WOODPECKER_PECK_SFX
	_woodpecker_peck_voice.volume_db = -3.0
	add_child(_woodpecker_peck_voice)
	_woodpecker_trigger_voice = AudioStreamPlayer.new()
	_woodpecker_trigger_voice.name = "WoodpeckerTrigger"
	_woodpecker_trigger_voice.stream = WOODPECKER_TRIGGER_SFX
	_woodpecker_trigger_voice.volume_db = -6.0
	add_child(_woodpecker_trigger_voice)


func _kick_woodpecker_loop() -> void:
	_woodpecker_loop_gen += 1
	_woodpecker_loop(_woodpecker_loop_gen)


func _stop_woodpecker_loop() -> void:
	_woodpecker_loop_gen += 1
	if _woodpecker != null:
		_woodpecker.visible = false


func _woodpecker_loop(generation: int) -> void:
	var first := true
	while generation == _woodpecker_loop_gen and is_inside_tree():
		var wait := WOODPECKER_FIRST_WAIT if first else WOODPECKER_INTERVAL
		first = false
		await get_tree().create_timer(randf_range(wait.x, wait.y)).timeout
		if generation != _woodpecker_loop_gen or not visible:
			return
		await play_woodpecker_raid()


func standing_trees() -> Array[Node3D]:
	var trees: Array[Node3D] = []
	for node in _flora:
		if not is_instance_valid(node):
			continue
		if not _is_flora_tree(node):
			continue
		if bool(node.get_meta("felled", false)):
			continue
		trees.append(node)
	return trees


## 飞出啄木鸟，立体面片从上往下啄倒一棵树。`regrow_after < 0` 时用随机间隔再长回。
func play_woodpecker_raid(tree: Node3D = null, regrow_after := -1.0) -> void:
	if _woodpecker_busy or _is_globe() or _woodpecker == null:
		return
	if tree == null or not is_instance_valid(tree) or bool(tree.get_meta("felled", false)):
		var pool := standing_trees()
		if pool.is_empty():
			return
		tree = pool[randi() % pool.size()]
	_woodpecker_busy = true
	_remember_tree_rest(tree)
	var perch := tree.global_position + Vector3(
		randf_range(-0.08, 0.08),
		1.88,
		0.06
	)
	var from_left := randf() < 0.5
	var span := maxf(_map_bounds.size.x * 0.55, 6.5)
	var start := Vector3(
		_map_bounds.get_center().x + span * (-1.0 if from_left else 1.0),
		2.55,
		perch.z + randf_range(-0.6, 0.6)
	)
	var exit_p := Vector3(
		_map_bounds.get_center().x + span * (1.05 if from_left else -1.05),
		2.7,
		perch.z + randf_range(-0.8, 0.8)
	)
	_woodpecker.global_position = start
	_woodpecker.visible = true
	_set_woodpecker_texture(WOODPECKER_FLY)
	_face_woodpecker(not from_left)
	_woodpecker.rotation = _woodpecker_fly_rotation(not from_left)
	if _woodpecker_trigger_voice != null:
		_woodpecker_trigger_voice.pitch_scale = randf_range(0.96, 1.06)
		_woodpecker_trigger_voice.play()
	await _move_woodpecker(perch, 0.72, true)
	if not is_instance_valid(tree) or not visible:
		_finish_woodpecker_raid()
		return
	_set_woodpecker_texture(WOODPECKER_PECK)
	var rest := perch
	await _pose_woodpecker(rest, _woodpecker_peck_rotation(), 0.12)
	for _i in WOODPECKER_PECKS:
		if not is_instance_valid(tree):
			break
		rest = await _play_woodpecker_peck(tree, rest)
	if is_instance_valid(tree) and visible:
		await _fell_tree(tree)
		var delay := regrow_after
		if delay < 0.0:
			delay = randf_range(WOODPECKER_REGROW.x, WOODPECKER_REGROW.y)
		_schedule_tree_regrow(tree, delay)
	_set_woodpecker_texture(WOODPECKER_FLY)
	await _move_woodpecker(exit_p, 0.58, true)
	_finish_woodpecker_raid()


func _finish_woodpecker_raid() -> void:
	if _woodpecker != null:
		_woodpecker.visible = false
	_woodpecker_busy = false


func _set_woodpecker_texture(tex: Texture2D) -> void:
	if _woodpecker_mat != null:
		_woodpecker_mat.albedo_texture = tex


func _face_woodpecker(facing_right: bool) -> void:
	if _woodpecker_card == null:
		return
	_woodpecker_card.scale.x = -1.0 if facing_right else 1.0


func _woodpecker_fly_rotation(facing_right: bool) -> Vector3:
	# 立绘是俯视，面片平放 90°；飞的时候略抬，才看得出在往前冲。
	return Vector3(
		deg_to_rad(WOODPECKER_LAY_PITCH_DEG + 12.0),
		0.0,
		deg_to_rad(-8.0 if facing_right else 8.0)
	)


func _woodpecker_peck_rotation() -> Vector3:
	return Vector3(deg_to_rad(WOODPECKER_LAY_PITCH_DEG), 0.0, 0.0)


func _woodpecker_strike_rotation() -> Vector3:
	return Vector3(
		deg_to_rad(WOODPECKER_LAY_PITCH_DEG - 8.0),
		0.0,
		randf_range(-0.06, 0.06)
	)


func _move_woodpecker(target: Vector3, duration: float, flying: bool) -> void:
	if _woodpecker == null:
		return
	var facing_right := target.x >= _woodpecker.global_position.x
	_face_woodpecker(facing_right)
	var rot := _woodpecker_fly_rotation(facing_right) if flying else _woodpecker_peck_rotation()
	await _pose_woodpecker(target, rot, duration)


func _pose_woodpecker(target: Vector3, rot: Vector3, duration: float) -> void:
	if _woodpecker == null:
		return
	if _woodpecker_pose_tween != null and _woodpecker_pose_tween.is_valid():
		_woodpecker_pose_tween.kill()
	_woodpecker_pose_tween = _woodpecker.create_tween()
	_woodpecker_pose_tween.set_parallel(true)
	_woodpecker_pose_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_woodpecker_pose_tween.tween_property(_woodpecker, "global_position", target, duration)
	_woodpecker_pose_tween.tween_property(_woodpecker, "rotation", rot, duration)
	await _woodpecker_pose_tween.finished


func _play_woodpecker_peck(tree: Node3D, rest: Vector3) -> Vector3:
	if _woodpecker_peck_voice != null:
		_woodpecker_peck_voice.pitch_scale = randf_range(0.92, 1.12)
		_woodpecker_peck_voice.play()
	var floor_y := tree.global_position.y + 0.36
	var strike := rest + Vector3(0.0, -WOODPECKER_STRIKE_DIP, 0.03)
	strike.y = maxf(strike.y, floor_y)
	var next_rest := rest + Vector3(0.0, -WOODPECKER_PECK_STEP, 0.0)
	next_rest.y = maxf(next_rest.y, floor_y)
	await _pose_woodpecker(strike, _woodpecker_strike_rotation(), 0.09)
	var impact := Vector3(tree.global_position.x, strike.y - 0.04, tree.global_position.z)
	_jitter_tree(tree)
	_burst_wood_chips(impact)
	_burst_peck_text(impact)
	await _pose_woodpecker(next_rest, _woodpecker_peck_rotation(), 0.11)
	return next_rest


func _jitter_tree(tree: Node3D) -> void:
	var rest := _tree_rest_rotation(tree)
	var key := tree.get_instance_id()
	var previous: Tween = _flora_shake_tweens.get(key)
	if previous != null and previous.is_valid():
		previous.kill()
	var tween := tree.create_tween()
	tween.tween_property(tree, "rotation", rest + Vector3(0.06, 0.0, randf_range(-0.09, 0.09)), 0.05)
	tween.tween_property(tree, "rotation", rest, 0.08)
	_flora_shake_tweens[key] = tween


func _burst_peck_text(origin: Vector3) -> void:
	if _woodpecker_fx == null:
		return
	for _i in WOODPECKER_TEXT_COUNT:
		var glyph := Label3D.new()
		glyph.text = WOODPECKER_TEXT_GLYPHS[randi() % WOODPECKER_TEXT_GLYPHS.size()]
		glyph.font = FLORA_NOTE_FONT
		glyph.font_size = randi_range(48, 78)
		glyph.pixel_size = 0.0075
		glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glyph.no_depth_test = true
		glyph.render_priority = 10
		glyph.outline_size = 10
		glyph.outline_modulate = Color(0.16, 0.09, 0.03, 0.92)
		glyph.modulate = Color(1.0, 0.86, 0.38, 1.0)
		_woodpecker_fx.add_child(glyph)
		glyph.global_position = origin + Vector3(
			randf_range(-0.1, 0.1),
			randf_range(0.04, 0.16),
			randf_range(-0.1, 0.1)
		)
		var dest := glyph.global_position + Vector3(
			randf_range(-0.55, 0.55),
			randf_range(0.55, 1.15),
			randf_range(-0.35, 0.35)
		)
		var life := randf_range(0.55, 0.9)
		var spin := randf_range(-0.7, 0.7)
		var flight := glyph.create_tween()
		flight.set_parallel(true)
		flight.tween_property(glyph, "global_position", dest, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flight.tween_property(glyph, "rotation", Vector3(0.0, spin, spin * 0.4), life)
		flight.tween_property(glyph, "modulate:a", 0.0, life).set_delay(life * 0.35)
		flight.tween_property(glyph, "scale", Vector3.ONE * randf_range(0.55, 0.85), life)
		flight.chain().tween_callback(glyph.queue_free)


func _burst_wood_chips(origin: Vector3) -> void:
	if _woodpecker_fx == null or _woodpecker_chip_mesh == null:
		return
	for _i in WOODPECKER_CHIP_COUNT:
		var chip := MeshInstance3D.new()
		chip.mesh = _woodpecker_chip_mesh
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(
			randf_range(0.38, 0.66),
			randf_range(0.20, 0.42),
			randf_range(0.08, 0.22)
		)
		chip.set_surface_override_material(0, mat)
		_woodpecker_fx.add_child(chip)
		chip.global_position = origin + Vector3(
			randf_range(-0.06, 0.06),
			randf_range(0.0, 0.08),
			randf_range(-0.06, 0.06)
		)
		var dest := chip.global_position + Vector3(
			randf_range(-0.7, 0.7),
			randf_range(0.25, 0.85),
			randf_range(-0.7, 0.7)
		)
		var life := randf_range(0.38, 0.62)
		var flight := chip.create_tween()
		flight.set_parallel(true)
		flight.tween_property(chip, "global_position", dest + Vector3(0.0, -0.7, 0.0), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		flight.tween_property(chip, "rotation", Vector3(randf() * TAU, randf() * TAU, randf() * TAU), life)
		flight.tween_property(chip, "scale", Vector3.ZERO, life)
		flight.chain().tween_callback(chip.queue_free)


func _remember_tree_rest(tree: Node3D) -> void:
	if not tree.has_meta("tree_rest_scale"):
		tree.set_meta("tree_rest_scale", tree.scale)
	if not tree.has_meta("tree_rest_rot"):
		tree.set_meta("tree_rest_rot", tree.get_meta("flora_base_rot", tree.rotation))
	if not tree.has_meta("tree_rest_pos"):
		tree.set_meta("tree_rest_pos", tree.position)


func _tree_rest_rotation(tree: Node3D) -> Vector3:
	return tree.get_meta("tree_rest_rot", tree.get_meta("flora_base_rot", tree.rotation))


func _set_tree_pickable(tree: Node3D, on: bool) -> void:
	var pick := tree.get_node_or_null("FloraPick") as StaticBody3D
	if pick != null:
		pick.collision_layer = FLORA_PICK_COLLISION_LAYER if on else 0


func _fell_tree(tree: Node3D) -> void:
	if tree == null or not is_instance_valid(tree):
		return
	if bool(tree.get_meta("felled", false)):
		return
	_remember_tree_rest(tree)
	var key := tree.get_instance_id()
	var previous: Tween = _flora_shake_tweens.get(key)
	if previous != null and previous.is_valid():
		previous.kill()
	tree.set_meta("felled", true)
	_register_tree_felled()
	_set_tree_pickable(tree, false)
	if _hovered_flora == tree:
		_set_hovered_flora(null)
	_burst_wood_chips(tree.global_position + Vector3(0.0, 0.55, 0.0))
	_burst_peck_text(tree.global_position + Vector3(0.0, 0.85, 0.0))
	var rest_rot := _tree_rest_rotation(tree)
	var side := 1.0 if randf() < 0.5 else -1.0
	var fallen := rest_rot + Vector3(deg_to_rad(78.0 * side), 0.0, deg_to_rad(randf_range(-16.0, 16.0)))
	var rest_pos: Vector3 = tree.get_meta("tree_rest_pos", tree.position)
	var drop := rest_pos + Vector3(0.0, -0.12, 0.0)
	var fall := tree.create_tween()
	fall.set_parallel(true)
	fall.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	fall.tween_property(tree, "rotation", fallen, 0.62)
	fall.tween_property(tree, "position", drop, 0.62)
	await fall.finished
	if not is_instance_valid(tree):
		return
	var sink := tree.create_tween()
	sink.set_parallel(true)
	sink.tween_property(tree, "scale", Vector3.ONE * 0.02, 0.28)
	sink.tween_property(tree, "position", drop + Vector3(0.0, -0.18, 0.0), 0.28)
	await sink.finished
	if is_instance_valid(tree):
		tree.visible = false


func _schedule_tree_regrow(tree: Node3D, delay: float) -> void:
	var token := int(tree.get_meta("regrow_token", 0)) + 1
	tree.set_meta("regrow_token", token)
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(tree):
		return
	if int(tree.get_meta("regrow_token", 0)) != token:
		return
	await regrow_tree(tree)


func regrow_tree(tree: Node3D) -> void:
	if tree == null or not is_instance_valid(tree):
		return
	tree.set_meta("regrow_token", int(tree.get_meta("regrow_token", 0)) + 1)
	_remember_tree_rest(tree)
	var rest_scale: Vector3 = tree.get_meta("tree_rest_scale", Vector3.ONE * 0.5)
	var rest_rot: Vector3 = tree.get_meta("tree_rest_rot", Vector3.ZERO)
	var rest_pos: Vector3 = tree.get_meta("tree_rest_pos", tree.position)
	tree.visible = true
	tree.rotation = rest_rot
	tree.position = rest_pos
	tree.scale = rest_scale * 0.08
	tree.set_meta("felled", false)
	var grow := tree.create_tween()
	grow.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property(tree, "scale", rest_scale, 0.55)
	await grow.finished
	if is_instance_valid(tree):
		tree.scale = rest_scale
		_set_tree_pickable(tree, true)


func _on_badge_pressed(stage_id: String) -> void:
	if _is_modal_overlay_visible():
		return
	if not StageTable.is_stage_unlocked(stage_id, _cleared):
		return
	# 单槽续局：想进别的关，先确认放弃手上那一关（共识 6）。
	if _resume_stage_id != "" and stage_id != _resume_stage_id:
		_open_confirm(stage_id)
		return
	stage_selected.emit(stage_id)


## 点关卡地格仍进关；空地左键落金黄大面包，右键落深褐大面包。
## 用 `_input` 而不是 `_unhandled_input`：主场景里还有全屏 Control，会把点击吃掉，
## 未处理输入永远轮不到地图。
func _input(event: InputEvent) -> void:
	if not visible or _camera == null:
		return
	if _confirm != null and _confirm.visible:
		return
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if not button.pressed:
		return
	if button.button_index != MOUSE_BUTTON_LEFT and button.button_index != MOUSE_BUTTON_RIGHT:
		return
	if _focus_qte_listening:
		if button.button_index == MOUSE_BUTTON_LEFT:
			_lock_focus_qte()
		get_viewport().set_input_as_handled()
		return
	# 排行榜等模态开着时，地图自己不点地格/落面包。
	# 不能 set_input_as_handled：`_input` 早于 GUI，标了已处理上榜/跳过就点不到。
	if _is_modal_overlay_visible():
		return
	# 悬浮牌 / 顶栏 / 确认卡 / 更高层弹窗自己点；别在这里抢。
	var hovered := get_viewport().gui_get_hovered_control()
	if _find_stage_badge(hovered) != null or _is_world_map_chrome(hovered):
		return
	if _is_overlay_above_map(hovered):
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		if _try_select_tile_at(button.position):
			get_viewport().set_input_as_handled()
			return
		if not _is_globe():
			_spawn_loaf(button.position, true)
		get_viewport().set_input_as_handled()
		return
	if button.button_index == MOUSE_BUTTON_RIGHT:
		if _try_open_tile_leaderboard(button.position):
			get_viewport().set_input_as_handled()
			return
	if not _is_globe():
		_spawn_loaf(button.position, false)
	get_viewport().set_input_as_handled()


## 右键关卡地格：打开该关排行榜。
func _try_open_tile_leaderboard(screen_pos: Vector2) -> bool:
	_refresh_hover_at(screen_pos)
	if _hovered_tile == null or not is_instance_valid(_hovered_tile):
		return false
	var stage_id := String(_hovered_tile.get_meta("stage_id", ""))
	if stage_id == "":
		return false
	leaderboard_requested.emit(stage_id)
	return true


## 若指针下是已绑定关卡的地格，触发与牌子相同的选择。返回是否处理了点击。
func _try_select_tile_at(screen_pos: Vector2) -> bool:
	_refresh_hover_at(screen_pos)
	if _hovered_tile == null or not is_instance_valid(_hovered_tile):
		return false
	var stage_id := String(_hovered_tile.get_meta("stage_id", ""))
	if stage_id == "":
		return false
	_on_badge_pressed(stage_id)
	# 只要点到了关卡格就算处理（锁定格也会吞掉点击，避免穿透）。
	return true


func _setup_redstart() -> void:
	_redstart = Node3D.new()
	_redstart.name = "Redstart"
	_redstart.visible = false
	_redstart_sprite = Sprite3D.new()
	_redstart_sprite.name = "Sprite"
	_redstart_sprite.texture = REDSTART_FLY[0]
	_redstart_sprite.pixel_size = REDSTART_PIXEL_SIZE
	_redstart_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_redstart_sprite.transparent = true
	_redstart_sprite.shaded = false
	_redstart_sprite.double_sided = true
	_redstart_sprite.centered = true
	_redstart_sprite.no_depth_test = true
	_redstart_sprite.render_priority = 7
	_redstart.add_child(_redstart_sprite)
	add_child(_redstart)
	_redstart_voice = AudioStreamPlayer.new()
	_redstart_voice.name = "RedstartCall"
	_redstart_voice.stream = REDSTART_CALL
	_redstart_voice.volume_db = -3.0
	add_child(_redstart_voice)


func _kick_redstart_loop() -> void:
	_redstart_loop_gen += 1
	_redstart_loop(_redstart_loop_gen)


func _stop_redstart() -> void:
	_redstart_loop_gen += 1
	_redstart_busy = false
	if _redstart_move_tween != null and _redstart_move_tween.is_valid():
		_redstart_move_tween.kill()
	_kill_photo_tween()
	if _redstart != null:
		_redstart.visible = false
	if _viewfinder != null:
		_viewfinder.visible = false
	if _polaroid != null:
		_polaroid.visible = false
	if _focus_qte != null:
		_focus_qte.visible = false
	_hide_focus_grade()
	_focus_qte_listening = false
	_focus_qte_locked = false
	_reset_shot_camera()


func _redstart_loop(generation: int) -> void:
	var first := true
	while generation == _redstart_loop_gen and is_inside_tree():
		var wait := REDSTART_FIRST_WAIT if first else REDSTART_INTERVAL
		first = false
		await get_tree().create_timer(randf_range(wait.x, wait.y)).timeout
		if generation != _redstart_loop_gen or not visible:
			return
		await play_redstart_photo()


func _redstart_extents() -> Vector2:
	var tex := REDSTART_IDLE[0]
	return Vector2(
		float(tex.get_width()) * REDSTART_PIXEL_SIZE,
		float(tex.get_height()) * REDSTART_PIXEL_SIZE
	)


## 飞来一只红尾水鸲，镜头对准后滑一次对焦槽；条走完才结算，中途点了锁档，不点就是最低档。
func play_redstart_photo(hold := -1.0, focus_override := -1.0) -> void:
	if _redstart_busy or _is_globe() or _redstart == null:
		return
	_redstart_busy = true
	var gen := _redstart_loop_gen
	if hold < 0.0:
		hold = REDSTART_HOLD
	var perch := _redstart_perch()
	var from_left := randf() < 0.5
	var span := maxf(_map_bounds.size.x * 0.55, 6.5)
	var start := Vector3(
		_map_bounds.get_center().x + span * (-1.0 if from_left else 1.0),
		2.2,
		perch.z + randf_range(-0.5, 0.5)
	)
	_redstart_exit = Vector3(
		_map_bounds.get_center().x + span * (1.1 if from_left else -1.1),
		2.4,
		perch.z + randf_range(-0.8, 0.8)
	)
	_redstart.global_position = start
	_redstart.visible = true
	if _redstart_sprite != null:
		_redstart_sprite.modulate = Color.WHITE
	_face_redstart(not from_left)
	_pose_redstart(true)
	if _redstart_voice != null:
		_redstart_voice.pitch_scale = randf_range(0.94, 1.06)
		_redstart_voice.play()
	await _move_redstart(perch + Vector3(0.0, 0.55, 0.0), REDSTART_FLY_IN)
	if gen != _redstart_loop_gen or not visible:
		_finish_redstart_photo()
		return
	await _move_redstart(perch, REDSTART_LAND)
	if gen != _redstart_loop_gen or not visible:
		_finish_redstart_photo()
		return
	_pose_redstart(false)
	await _slide_viewfinder_in()
	if gen != _redstart_loop_gen or not visible:
		_finish_redstart_photo()
		return
	var yaw_sign := 1.0 if randf() < 0.5 else -1.0
	var look_off := Vector3.ZERO
	if _redstart != null:
		look_off = _redstart.global_position - _pivot
	await _tween_shot_to(
		REDSTART_SHOT_YAW * yaw_sign,
		REDSTART_SHOT_PITCH,
		REDSTART_SHOT_DIST,
		look_off,
		REDSTART_SHOT_DURATION
	)
	if gen != _redstart_loop_gen or not visible:
		_finish_redstart_photo()
		return
	var focus_quality := 0.0
	if focus_override >= 0.0:
		focus_quality = clampf(focus_override, 0.0, 1.0)
	else:
		focus_quality = await _run_focus_qte()
	_register_focus_result(focus_quality)
	if gen != _redstart_loop_gen or not visible:
		_finish_redstart_photo()
		return
	if _viewfinder != null:
		_viewfinder.visible = false
	var snapshot := await _capture_map_photo(focus_quality)
	if gen != _redstart_loop_gen or not visible:
		_finish_redstart_photo()
		return
	_flash_photo()
	await get_tree().create_timer(REDSTART_PRINT_DELAY).timeout
	if gen != _redstart_loop_gen or not visible:
		_finish_redstart_photo()
		return
	_show_polaroid_photo(snapshot, focus_quality)
	if _redstart_voice != null:
		_redstart_voice.pitch_scale = randf_range(1.04, 1.16)
		_redstart_voice.play()
	await get_tree().create_timer(hold).timeout
	if gen != _redstart_loop_gen:
		_finish_redstart_photo()
		return
	await _retire_redstart_photo()
	_finish_redstart_photo()


func _redstart_perch() -> Vector3:
	var pond := pond_point()
	if pond == Vector3.ZERO:
		var c := _map_bounds.get_center()
		return Vector3(c.x, 0.55, c.y + 1.6)
	var shore := pond + Vector3(randf_range(-0.4, 0.4), 0.0, 1.35)
	if is_in_water(shore, 0.2):
		shore.z += 0.8
	shore.y = 0.55
	return shore


func _move_redstart(target: Vector3, duration: float) -> void:
	if _redstart == null:
		return
	if _redstart_move_tween != null and _redstart_move_tween.is_valid():
		_redstart_move_tween.kill()
	_face_redstart(target.x >= _redstart.global_position.x)
	_redstart_move_tween = _redstart.create_tween()
	_redstart_move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_redstart_move_tween.tween_property(_redstart, "global_position", target, duration)
	await _redstart_move_tween.finished


func _face_redstart(facing_right: bool) -> void:
	if _redstart_sprite != null:
		_redstart_sprite.flip_h = facing_right


func _pose_redstart(flying: bool) -> void:
	if _redstart_sprite == null:
		return
	if flying:
		_redstart_sprite.texture = REDSTART_FLY[1] if _redstart_sprite.texture == REDSTART_FLY[0] else REDSTART_FLY[0]
	else:
		_redstart_sprite.texture = REDSTART_IDLE[randi() % REDSTART_IDLE.size()]


func _slide_viewfinder_in() -> void:
	if _viewfinder == null:
		return
	var size := _viewfinder_size()
	_viewfinder.size = size
	_viewfinder.pivot_offset = size * 0.5
	_viewfinder.position = _viewfinder_offscreen_pos()
	_viewfinder.rotation = 0.0
	_viewfinder.scale = Vector2.ONE * 0.58
	_viewfinder.modulate.a = 1.0
	_viewfinder.visible = true
	_viewfinder.queue_redraw()
	_kill_photo_tween()
	_photo_tween = create_tween()
	_photo_tween.set_parallel(true)
	_photo_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_photo_tween.tween_property(_viewfinder, "position", _viewfinder_home_pos(), REDSTART_FRAME_IN)
	_photo_tween.tween_property(_viewfinder, "scale", Vector2.ONE, REDSTART_FRAME_IN)
	await _photo_tween.finished


func _run_focus_qte() -> float:
	_place_focus_qte()
	_focus_qte_locked = false
	_focus_qte_needle = 0.0
	if _focus_qte != null:
		_focus_qte.needle = 0.0
		_focus_qte.locked = false
		_focus_qte.visible = true
		_focus_qte.queue_redraw()
	_focus_qte_listening = true
	_kill_photo_tween()
	var tw := create_tween()
	_photo_tween = tw
	tw.tween_method(_advance_focus_qte, 0.0, 1.0, REDSTART_QTE_DURATION)
	var finished := false
	tw.finished.connect(func() -> void: finished = true)
	while not finished:
		if not is_inside_tree() or _photo_tween != tw or not tw.is_valid():
			break
		await get_tree().process_frame
	_focus_qte_listening = false
	var quality := 0.0
	if _focus_qte_locked:
		quality = _focus_quality_from_slider(_focus_qte_needle)
	if _focus_qte != null:
		_focus_qte.visible = false
	return quality


func _advance_focus_qte(t: float) -> void:
	if _focus_qte_locked:
		return
	_focus_qte_needle = t
	if _focus_qte != null:
		_focus_qte.needle = t
		_focus_qte.queue_redraw()


func _lock_focus_qte() -> void:
	if not _focus_qte_listening or _focus_qte_locked:
		return
	_focus_qte_locked = true
	if _focus_qte != null:
		_focus_qte.locked = true
		_focus_qte.queue_redraw()


func _focus_quality_from_slider(t: float) -> float:
	var dist := absf(t - REDSTART_QTE_SWEET)
	var max_d := maxf(REDSTART_QTE_SWEET, 1.0 - REDSTART_QTE_SWEET)
	return clampf(1.0 - dist / max_d, 0.0, 1.0)


func is_successful_focus(quality: float) -> bool:
	return quality + 0.0001 >= _focus_quality_from_slider(REDSTART_QTE_SWEET - REDSTART_QTE_SWEET_RADIUS)


func focus_grade_text(quality: float) -> String:
	if is_successful_focus(quality):
		return "Get Daze！"
	if quality >= 0.62:
		return "合焦"
	if quality >= 0.36:
		return "轻虚"
	if quality >= 0.14:
		return "虚焦"
	return "失焦"


func _focus_grade_color(quality: float) -> Color:
	if is_successful_focus(quality):
		return Color(1.0, 0.86, 0.32)
	if quality >= 0.62:
		return Color(0.98, 0.94, 0.82)
	if quality >= 0.36:
		return Color(0.92, 0.78, 0.52)
	if quality >= 0.14:
		return Color(0.82, 0.62, 0.48)
	return Color(0.72, 0.42, 0.38)


func _register_tree_felled() -> void:
	_map_trees_felled += 1
	if _map_trees_felled == MAP_HEALTH_CHECK_TREES:
		easter_egg_triggered.emit(Catalog.MAP_HEALTH_CHECK)


func _register_pigeon_eaten() -> void:
	_map_pigeons_eaten += 1
	if _map_pigeons_eaten == MAP_BUFFET_PIGEONS:
		easter_egg_triggered.emit(Catalog.MAP_PIGEON_BUFFET)


func _register_loaf_eaten() -> void:
	_map_loaves_eaten += 1
	if _map_loaves_eaten == MAP_HERON_BREAD_LOAVES:
		easter_egg_triggered.emit(Catalog.MAP_HERON_BREAD)


func _register_focus_result(quality: float) -> void:
	if is_successful_focus(quality):
		easter_egg_triggered.emit(Catalog.MAP_GET_DAZE)


func _place_focus_qte() -> void:
	if _focus_qte == null:
		return
	var layer := _photo_canvas_size()
	_focus_qte.size = Vector2(720.0, 70.0)
	_focus_qte.position = Vector2((layer.x - 720.0) * 0.5, layer.y * 0.78)


func _tween_shot_to(yaw: float, pitch: float, dist: float, look_off: Vector3, duration: float) -> void:
	var y0 := _shot_yaw_off
	var p0 := _shot_pitch_off
	var d0 := _shot_current_dist()
	var l0 := _shot_look_off
	_kill_photo_tween()
	_photo_tween = create_tween()
	_photo_tween.tween_method(
		_advance_shot_pose.bind(y0, yaw, p0, pitch, d0, dist, l0, look_off),
		0.0,
		1.0,
		duration
	)
	await _photo_tween.finished


func _advance_shot_pose(
	t: float,
	y0: float,
	y1: float,
	p0: float,
	p1: float,
	d0: float,
	d1: float,
	l0: Vector3,
	l1: Vector3
) -> void:
	var s := t * t * (3.0 - 2.0 * t)
	_shot_yaw_off = lerpf(y0, y1, s)
	_shot_pitch_off = lerpf(p0, p1, s)
	_shot_dist = lerpf(d0, d1, s)
	_shot_look_off = l0.lerp(l1, s)
	_apply_camera()


func _capture_map_photo(focus_quality := 0.0) -> Texture2D:
	var viewport := get_viewport()
	if viewport == null or DisplayServer.get_name() == "headless":
		return null
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return null
	_blur_redstart_in_image(image, focus_quality)
	return ImageTexture.create_from_image(image)


func _blur_redstart_in_image(image: Image, focus_quality := 0.0) -> void:
	if _camera == null or _redstart == null:
		return
	var strength := 1.0 - clampf(focus_quality, 0.0, 1.0)
	if strength <= 0.05:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 1.0 or vp.y < 1.0:
		return
	var img_s := Vector2(float(image.get_width()), float(image.get_height()))
	var to_img := img_s / vp
	var origin := _redstart.global_position
	var bx := _camera.global_transform.basis.x
	var by := _camera.global_transform.basis.y
	var extents := _redstart_extents()
	var hw := extents.x * 0.8
	var hh := extents.y * 0.8
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	var corners: Array[Vector3] = [
		origin + bx * -hw + by * -hh,
		origin + bx * hw + by * -hh,
		origin + bx * -hw + by * hh,
		origin + bx * hw + by * hh,
	]
	for i in corners.size():
		var world: Vector3 = corners[i]
		if _camera.is_position_behind(world):
			continue
		var s := _camera.unproject_position(world) * to_img
		min_p.x = minf(min_p.x, s.x)
		min_p.y = minf(min_p.y, s.y)
		max_p.x = maxf(max_p.x, s.x)
		max_p.y = maxf(max_p.y, s.y)
	if not min_p.is_finite() or not max_p.is_finite():
		var mid := _camera.unproject_position(origin) * to_img
		min_p = mid - Vector2(48.0, 48.0)
		max_p = mid + Vector2(48.0, 48.0)
	var center := (min_p + max_p) * 0.5
	var radius := maxf(max_p.x - min_p.x, max_p.y - min_p.y) * lerpf(0.55, 1.85, strength)
	radius = maxf(radius, minf(img_s.x, img_s.y) * lerpf(0.06, 0.18, strength))
	var shrink := int(round(lerpf(5.0, 20.0, strength)))
	_blur_image_disc(image, center, radius, shrink)
	if strength > 0.42:
		_blur_image_disc(image, center, radius * 0.92, maxi(shrink - 6, 4))


func _blur_image_disc(image: Image, center: Vector2, radius: float, shrink := 16) -> void:
	if radius < 8.0:
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var r := int(ceil(radius))
	var rect := Rect2i(int(center.x) - r, int(center.y) - r, r * 2, r * 2)
	rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if rect.size.x < 4 or rect.size.y < 4:
		return
	var patch := image.get_region(rect)
	var small := Vector2i(maxi(rect.size.x / shrink, 2), maxi(rect.size.y / shrink, 2))
	patch.resize(small.x, small.y, Image.INTERPOLATE_BILINEAR)
	patch.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_BILINEAR)
	var cx := center.x - float(rect.position.x)
	var cy := center.y - float(rect.position.y)
	for y in rect.size.y:
		for x in rect.size.x:
			var d := Vector2(float(x) - cx, float(y) - cy).length() / radius
			var w := 1.0 if d < 0.72 else clampf(1.0 - (d - 0.72) / 0.28, 0.0, 1.0)
			if w <= 0.02:
				continue
			var src := patch.get_pixel(x, y)
			var dst := image.get_pixel(rect.position.x + x, rect.position.y + y)
			image.set_pixel(rect.position.x + x, rect.position.y + y, dst.lerp(src, w))


func _flash_photo() -> void:
	if _photo_layer == null:
		return
	var flash := ColorRect.new()
	flash.name = "Flash"
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.97, 0.9, 0.0)
	flash.z_index = 20
	_photo_layer.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.92, 0.04)
	tw.tween_property(flash, "color:a", 0.0, 0.28)
	tw.finished.connect(flash.queue_free)


func _show_polaroid_photo(snapshot: Texture2D, focus_quality := 0.0) -> void:
	if _polaroid == null:
		return
	_polaroid_image.texture = snapshot if snapshot != null else _placeholder_photo_tex()
	_polaroid.position = _polaroid_print_pos()
	_polaroid.pivot_offset = _polaroid.size * 0.5
	_polaroid.rotation = 0.16
	_polaroid.scale = Vector2.ONE * 0.42
	_polaroid.modulate.a = 1.0
	_polaroid.visible = true
	var pop := _polaroid.create_tween()
	pop.set_parallel(true)
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_polaroid, "scale", Vector2.ONE * 1.06, 0.26)
	pop.tween_property(_polaroid, "rotation", -0.08, 0.26)
	pop.chain().tween_property(_polaroid, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pop_focus_grade(focus_quality)


func _pop_focus_grade(quality: float) -> void:
	if _focus_grade == null:
		return
	_place_focus_grade()
	_focus_grade.text = focus_grade_text(quality)
	_focus_grade.add_theme_color_override("font_color", _focus_grade_color(quality))
	_focus_grade.add_theme_font_size_override("font_size", 118 if is_successful_focus(quality) else 96)
	_focus_grade.visible = true
	_focus_grade.modulate.a = 1.0
	_focus_grade.scale = Vector2.ONE * 2.8
	_focus_grade.rotation = -0.22
	var punch := _focus_grade.create_tween()
	punch.set_parallel(true)
	punch.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(_focus_grade, "scale", Vector2.ONE, 0.32)
	punch.tween_property(_focus_grade, "rotation", 0.05, 0.32)
	_punch_grade_flash(quality)


func _place_focus_grade() -> void:
	if _focus_grade == null:
		return
	var layer := _photo_canvas_size()
	_focus_grade.size = Vector2(layer.x, 200.0)
	_focus_grade.pivot_offset = _focus_grade.size * 0.5
	_focus_grade.position = Vector2(0.0, layer.y * 0.12)


func _punch_grade_flash(quality: float) -> void:
	if _photo_layer == null:
		return
	var flash := ColorRect.new()
	flash.name = "GradeFlash"
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tint := _focus_grade_color(quality)
	flash.color = Color(tint.r, tint.g, tint.b, 0.0)
	flash.z_index = 12
	_photo_layer.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.55 if is_successful_focus(quality) else 0.28, 0.05)
	tw.tween_property(flash, "color:a", 0.0, 0.22)
	tw.finished.connect(flash.queue_free)


func _hide_focus_grade() -> void:
	if _focus_grade == null:
		return
	_focus_grade.visible = false
	_focus_grade.modulate.a = 1.0
	_focus_grade.scale = Vector2.ONE
	_focus_grade.rotation = 0.0


func _retire_redstart_photo() -> void:
	_pose_redstart(true)
	if _redstart != null:
		_face_redstart(_redstart_exit.x >= _redstart.global_position.x)
	_kill_photo_tween()
	_photo_tween = create_tween()
	_photo_tween.set_parallel(true)
	_photo_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if _polaroid != null:
		_photo_tween.tween_property(_polaroid, "position", _polaroid_offscreen_pos(), REDSTART_RETIRE)
		_photo_tween.tween_property(_polaroid, "rotation", 0.22, REDSTART_RETIRE)
		_photo_tween.tween_property(_polaroid, "modulate:a", 0.0, REDSTART_RETIRE * 0.7).set_delay(REDSTART_RETIRE * 0.2)
	if _focus_grade != null and _focus_grade.visible:
		_photo_tween.tween_property(_focus_grade, "modulate:a", 0.0, REDSTART_RETIRE * 0.45)
		_photo_tween.tween_property(_focus_grade, "scale", Vector2.ONE * 1.35, REDSTART_RETIRE * 0.45)
	if _redstart != null:
		_photo_tween.tween_property(_redstart, "global_position", _redstart_exit, REDSTART_RETIRE)
	_photo_tween.tween_method(
		_advance_shot_pose.bind(
			_shot_yaw_off,
			0.0,
			_shot_pitch_off,
			0.0,
			_shot_current_dist(),
			_distance,
			_shot_look_off,
			Vector3.ZERO
		),
		0.0,
		1.0,
		REDSTART_RETIRE
	)
	await _photo_tween.finished


func _finish_redstart_photo() -> void:
	_kill_photo_tween()
	if _redstart_move_tween != null and _redstart_move_tween.is_valid():
		_redstart_move_tween.kill()
	if _redstart != null:
		_redstart.visible = false
	if _redstart_sprite != null:
		_redstart_sprite.modulate.a = 1.0
	if _viewfinder != null:
		_viewfinder.visible = false
		_viewfinder.modulate.a = 1.0
		_viewfinder.scale = Vector2.ONE
	if _polaroid != null:
		_polaroid.visible = false
		_polaroid.modulate.a = 1.0
		_polaroid.scale = Vector2.ONE
	if _focus_qte != null:
		_focus_qte.visible = false
	_hide_focus_grade()
	_focus_qte_listening = false
	_focus_qte_locked = false
	_reset_shot_camera()
	_redstart_busy = false


func _photo_canvas_size() -> Vector2:
	if _photo_layer != null and _photo_layer.size.x > 1.0:
		return _photo_layer.size
	var vp := get_viewport().get_visible_rect().size
	if vp.x > 1.0:
		return vp
	return Vector2(1920.0, 1080.0)


func _viewfinder_size() -> Vector2:
	return _photo_canvas_size()


func _viewfinder_home_pos() -> Vector2:
	return Vector2.ZERO


func _viewfinder_offscreen_pos() -> Vector2:
	return Vector2(-_photo_canvas_size().x * 0.78, 0.0)


func _polaroid_print_pos() -> Vector2:
	var layer := _photo_canvas_size()
	return Vector2(layer.x * 0.54, layer.y * 0.22)


func _polaroid_offscreen_pos() -> Vector2:
	var layer := _photo_canvas_size()
	return Vector2(layer.x + 90.0, layer.y * 0.30)


func _placeholder_photo_tex() -> Texture2D:
	var img := Image.create(64, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.82, 0.78, 0.72))
	return ImageTexture.create_from_image(img)


func _kill_photo_tween() -> void:
	if _photo_tween != null and _photo_tween.is_valid():
		_photo_tween.kill()
	_photo_tween = null


# --- UI ---


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "WorldMapUi"
	_ui.layer = UI_LAYER
	add_child(_ui)

	_badge_layer = Control.new()
	_badge_layer.name = "BadgeLayer"
	_badge_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# PASS 而不是 STOP：牌子照样收得到点击，但空白处的按下要能穿下去给相机拖拽。
	_badge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_badge_layer)

	_note_layer = Control.new()
	_note_layer.name = "MusicNotes"
	_note_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_note_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_note_layer)

	_build_edge_mist()
	_build_top_bar()
	_build_resume_banner()
	_build_confirm()
	_build_photo_ui()


## 屏幕四边的柔和云雾遮罩，压住地图硬边，让画面像嵌在云里。
func _build_edge_mist() -> void:
	_edge_mist = _EdgeMist.new()
	_edge_mist.name = "EdgeMist"
	_edge_mist.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 盖在悬浮牌之上、顶栏之下：边角牌子溶进云雾，按钮仍清晰可点。
	_ui.add_child(_edge_mist)


## 边缘云雾：胡闹厨房那种嵌在云里的画框——外圈实、里头透，云团沿边缓慢挪。
class _EdgeMist extends Control:
	var _t := 0.0

	func _ready() -> void:
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 1.0 or h <= 1.0:
			return
		var cloud := Color(0.97, 0.98, 1.0, 1.0)
		var pulse := 0.96 + 0.04 * sin(_t * 0.55)
		var band := mini(w, h) * 0.13
		_draw_soft_band(Rect2(0.0, 0.0, w, band * 0.78), cloud, true, pulse)
		_draw_soft_band(Rect2(0.0, h - band * 0.78, w, band * 0.78), cloud, false, pulse)
		_draw_soft_band_vertical(Rect2(0.0, 0.0, band * 0.62, h), cloud, true, pulse)
		_draw_soft_band_vertical(Rect2(w - band * 0.62, 0.0, band * 0.62, h), cloud, false, pulse)
		_draw_cloud_edge(w, h, band, cloud, pulse)


	func _draw_cloud_edge(w: float, h: float, band: float, color: Color, pulse: float) -> void:
		var lobes := [
			{"p": Vector2(w * 0.08, -band * 0.22), "r": band * 0.82},
			{"p": Vector2(w * 0.22, -band * 0.16), "r": band * 0.64},
			{"p": Vector2(w * 0.38, -band * 0.20), "r": band * 0.74},
			{"p": Vector2(w * 0.55, -band * 0.12), "r": band * 0.60},
			{"p": Vector2(w * 0.72, -band * 0.18), "r": band * 0.72},
			{"p": Vector2(w * 0.90, -band * 0.14), "r": band * 0.84},
			{"p": Vector2(w * 0.12, h + band * 0.18), "r": band * 0.76},
			{"p": Vector2(w * 0.32, h + band * 0.14), "r": band * 0.62},
			{"p": Vector2(w * 0.52, h + band * 0.20), "r": band * 0.80},
			{"p": Vector2(w * 0.74, h + band * 0.12), "r": band * 0.68},
			{"p": Vector2(w * 0.92, h + band * 0.16), "r": band * 0.78},
			{"p": Vector2(-band * 0.20, h * 0.18), "r": band * 0.72},
			{"p": Vector2(-band * 0.12, h * 0.38), "r": band * 0.54},
			{"p": Vector2(-band * 0.18, h * 0.62), "r": band * 0.68},
			{"p": Vector2(-band * 0.10, h * 0.82), "r": band * 0.58},
			{"p": Vector2(w + band * 0.20, h * 0.16), "r": band * 0.74},
			{"p": Vector2(w + band * 0.14, h * 0.42), "r": band * 0.56},
			{"p": Vector2(w + band * 0.18, h * 0.68), "r": band * 0.70},
			{"p": Vector2(w + band * 0.12, h * 0.88), "r": band * 0.62},
		]
		for i in lobes.size():
			var spec: Dictionary = lobes[i]
			var pos: Vector2 = spec["p"]
			pos += Vector2(_wobble(float(i) * 0.7, 12.0), _wobble(float(i) * 1.1 + 0.4, 8.0))
			var r: float = float(spec["r"]) * (0.94 + 0.08 * sin(_t * 0.42 + float(i)))
			var a := (0.42 + 0.10 * sin(_t * 0.38 + float(i) * 0.5)) * pulse
			_draw_puff(pos, r, color, a)


	func _draw_puff(pos: Vector2, r: float, color: Color, alpha: float) -> void:
		draw_circle(pos, r, Color(color.r, color.g, color.b, alpha))
		draw_circle(pos + Vector2(r * 0.42, -r * 0.18), r * 0.62, Color(color.r, color.g, color.b, alpha * 0.85))
		draw_circle(pos + Vector2(-r * 0.38, -r * 0.12), r * 0.55, Color(color.r, color.g, color.b, alpha * 0.78))
		draw_circle(pos + Vector2(r * 0.08, -r * 0.38), r * 0.48, Color(color.r, color.g, color.b, alpha * 0.7))


	func _wobble(phase: float, amp: float) -> float:
		return sin(_t * 0.33 + phase) * amp + cos(_t * 0.21 + phase * 1.7) * amp * 0.45


	func _draw_soft_band(rect: Rect2, color: Color, fade_down: bool, pulse: float) -> void:
		var steps := 16
		for i in steps:
			var t0 := float(i) / float(steps)
			var t1 := float(i + 1) / float(steps)
			var a0 := _edge_alpha(t0 if fade_down else 1.0 - t0) * pulse
			var a1 := _edge_alpha(t1 if fade_down else 1.0 - t1) * pulse
			var y0 := rect.position.y + rect.size.y * t0
			var y1 := rect.position.y + rect.size.y * t1
			var mid_a := (a0 + a1) * 0.5
			draw_rect(
				Rect2(rect.position.x, y0, rect.size.x, maxf(y1 - y0, 1.0)),
				Color(color.r, color.g, color.b, mid_a)
			)


	func _draw_soft_band_vertical(rect: Rect2, color: Color, fade_right: bool, pulse: float) -> void:
		var steps := 16
		for i in steps:
			var t0 := float(i) / float(steps)
			var t1 := float(i + 1) / float(steps)
			var a0 := _edge_alpha(t0 if fade_right else 1.0 - t0) * pulse
			var a1 := _edge_alpha(t1 if fade_right else 1.0 - t1) * pulse
			var x0 := rect.position.x + rect.size.x * t0
			var x1 := rect.position.x + rect.size.x * t1
			var mid_a := (a0 + a1) * 0.5
			draw_rect(
				Rect2(x0, rect.position.y, maxf(x1 - x0, 1.0), rect.size.y),
				Color(color.r, color.g, color.b, mid_a)
			)


	func _edge_alpha(t: float) -> float:
		# t=0 在屏幕外缘（最浓），t=1 贴近画面中心（透明）。
		return clampf(pow(1.0 - t, 2.35) * 0.50, 0.0, 0.50)


func _build_top_bar() -> void:
	var bar := Panel.new()
	bar.name = "TopBar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 96.0
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var bar_box := StyleBoxFlat.new()
	bar_box.bg_color = Color(0.067, 0.110, 0.180, 0.92)
	bar_box.border_color = Color(0.200, 0.255, 0.333)
	bar_box.border_width_bottom = 2
	bar.add_theme_stylebox_override("panel", bar_box)
	_ui.add_child(bar)

	var back := _make_button("BackToTitleButton", "‹ 返回标题", Vector2(188.0, 56.0))
	back.position = Vector2(32.0, 20.0)
	back.pressed.connect(func() -> void: title_requested.emit())
	bar.add_child(back)

	_region_name_label = Label.new()
	_region_name_label.name = "RegionNameLabel"
	_region_name_label.position = Vector2(256.0, 12.0)
	_region_name_label.size = Vector2(420.0, 36.0)
	_region_name_label.add_theme_font_size_override("font_size", 28)
	bar.add_child(_region_name_label)

	_region_progress_label = Label.new()
	_region_progress_label.name = "RegionProgressLabel"
	_region_progress_label.position = Vector2(256.0, 50.0)
	_region_progress_label.size = Vector2(760.0, 34.0)
	_region_progress_label.add_theme_font_size_override("font_size", 20)
	_region_progress_label.add_theme_color_override("font_color", Color(0.580, 0.639, 0.722))
	bar.add_child(_region_progress_label)

	var boards := _make_button("AllLeaderboardsButton", "全部排行榜", Vector2(188.0, 56.0))
	boards.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	boards.anchor_left = 1.0
	boards.anchor_right = 1.0
	boards.offset_left = -536.0
	boards.offset_right = -340.0
	boards.offset_top = 20.0
	boards.offset_bottom = 76.0
	boards.pressed.connect(func() -> void: all_leaderboards_requested.emit())
	bar.add_child(boards)

	# 局外持久数值位。本期只占位不填数（共识 5）——虚线框就是"这里以后有东西"的说明。
	var meta_box := Panel.new()
	meta_box.name = "MetaCurrencyBox"
	meta_box.anchor_left = 1.0
	meta_box.anchor_right = 1.0
	meta_box.offset_left = -324.0
	meta_box.offset_right = -32.0
	meta_box.offset_top = 18.0
	meta_box.offset_bottom = 78.0
	var meta_style := StyleBoxFlat.new()
	meta_style.bg_color = Color(0.110, 0.165, 0.267, 0.9)
	meta_style.border_color = Color(0.278, 0.333, 0.408)
	meta_style.set_border_width_all(2)
	meta_style.set_corner_radius_all(10)
	meta_box.add_theme_stylebox_override("panel", meta_style)
	bar.add_child(meta_box)

	var meta_value := Label.new()
	meta_value.name = "MetaValueLabel"
	meta_value.text = "— —"
	meta_value.position = Vector2(18.0, 10.0)
	meta_value.size = Vector2(150.0, 40.0)
	meta_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta_value.add_theme_font_size_override("font_size", 24)
	meta_value.add_theme_color_override("font_color", Color(0.580, 0.639, 0.722))
	meta_box.add_child(meta_value)

	var meta_hint := Label.new()
	meta_hint.name = "MetaHintLabel"
	meta_hint.text = "局外成长"
	meta_hint.position = Vector2(176.0, 14.0)
	meta_hint.size = Vector2(104.0, 32.0)
	meta_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta_hint.add_theme_font_size_override("font_size", 16)
	meta_hint.add_theme_color_override("font_color", Color(0.435, 0.478, 0.529))
	meta_box.add_child(meta_hint)


func _build_resume_banner() -> void:
	_resume_banner = Panel.new()
	_resume_banner.name = "ResumeBanner"
	# 贴底而不是贴顶：顶部正好是悬浮牌最密的地带，横幅放那儿会把上排关卡整排盖住。
	_resume_banner.anchor_left = 0.5
	_resume_banner.anchor_right = 0.5
	_resume_banner.anchor_top = 1.0
	_resume_banner.anchor_bottom = 1.0
	_resume_banner.offset_left = -424.0
	_resume_banner.offset_right = 424.0
	_resume_banner.offset_top = -152.0
	_resume_banner.offset_bottom = -40.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.231, 0.165, 0.071, 0.95)
	box.border_color = Color(0.906, 0.588, 0.078)
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	_resume_banner.add_theme_stylebox_override("panel", box)
	_resume_banner.visible = false
	_ui.add_child(_resume_banner)

	_resume_text = Label.new()
	_resume_text.name = "ResumeTextLabel"
	_resume_text.position = Vector2(24.0, 18.0)
	_resume_text.size = Vector2(470.0, 76.0)
	_resume_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resume_text.add_theme_font_size_override("font_size", 23)
	_resume_banner.add_child(_resume_text)

	var resume := _make_button("ResumeStageButton", "续上", Vector2(150.0, 60.0))
	resume.position = Vector2(520.0, 26.0)
	resume.pressed.connect(func() -> void: resume_requested.emit())
	_resume_banner.add_child(resume)

	var abandon := _make_button("AbandonStageButton", "放弃", Vector2(150.0, 60.0))
	abandon.position = Vector2(682.0, 26.0)
	abandon.pressed.connect(func() -> void: _open_confirm(""))
	_resume_banner.add_child(abandon)


## 放弃确认卡。开合动画照 `start_screen.gd` 的 clear_confirmation 那套来（遮罩淡入 +
## 卡片回弹），不另发明一套手感。
func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.name = "AbandonConfirm"
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false
	_confirm.z_index = 10
	_ui.add_child(_confirm)

	_confirm_dim = ColorRect.new()
	_confirm_dim.name = "ConfirmDim"
	_confirm_dim.color = Color(0.020, 0.031, 0.055, 0.66)
	_confirm_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(_confirm_dim)

	_confirm_card = Panel.new()
	_confirm_card.name = "ConfirmPanel"
	_confirm_card.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_card.size = Vector2(680.0, 300.0)
	_confirm_card.offset_left = -340.0
	_confirm_card.offset_right = 340.0
	_confirm_card.offset_top = -150.0
	_confirm_card.offset_bottom = 150.0
	var card_box := StyleBoxFlat.new()
	card_box.bg_color = PAPER
	card_box.border_color = PAPER_EDGE
	card_box.set_border_width_all(4)
	card_box.set_corner_radius_all(16)
	_confirm_card.add_theme_stylebox_override("panel", card_box)
	_confirm.add_child(_confirm_card)

	_confirm_text = Label.new()
	_confirm_text.name = "ConfirmTextLabel"
	_confirm_text.position = Vector2(36.0, 34.0)
	_confirm_text.size = Vector2(608.0, 150.0)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.add_theme_font_size_override("font_size", 24)
	_confirm_text.add_theme_color_override("font_color", INK)
	_confirm_card.add_child(_confirm_text)

	var no := _make_button("ConfirmNoButton", "继续那一关", Vector2(230.0, 62.0))
	no.position = Vector2(36.0, 206.0)
	no.pressed.connect(func() -> void: _close_confirm(false))
	_confirm_card.add_child(no)

	var yes := _make_button("ConfirmYesButton", "放弃并开新的", Vector2(266.0, 62.0))
	yes.position = Vector2(378.0, 206.0)
	yes.pressed.connect(_on_confirm_yes)
	_confirm_card.add_child(yes)


## 相机镜头取景：外圈镜筒、中间圆孔透视，从侧面挪过来对准主体。
class _CameraLens extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 1.0 or h <= 1.0:
			return
		var c := Vector2(w * 0.5, h * 0.5)
		var hole := minf(w, h) * 0.33
		var max_r := c.length() + 12.0
		var segs := 80
		var dark := Color(0.04, 0.04, 0.05, 0.9)
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var inner0 := c + Vector2(cos(a0), sin(a0)) * hole
			var inner1 := c + Vector2(cos(a1), sin(a1)) * hole
			var outer0 := c + Vector2(cos(a0), sin(a0)) * max_r
			var outer1 := c + Vector2(cos(a1), sin(a1)) * max_r
			draw_colored_polygon(PackedVector2Array([inner0, outer0, outer1]), dark)
			draw_colored_polygon(PackedVector2Array([inner0, outer1, inner1]), dark)
		var rings: Array = [
			{"r": hole + 6.0, "w": 11.0, "c": Color(0.16, 0.16, 0.18, 1.0)},
			{"r": hole + 18.0, "w": 6.0, "c": Color(0.48, 0.48, 0.50, 1.0)},
			{"r": hole + 28.0, "w": 8.0, "c": Color(0.10, 0.10, 0.11, 1.0)},
			{"r": hole + 40.0, "w": 5.0, "c": Color(0.32, 0.32, 0.34, 1.0)},
			{"r": hole + 50.0, "w": 4.0, "c": Color(0.62, 0.56, 0.46, 1.0)},
		]
		for spec in rings:
			draw_arc(c, float(spec["r"]), 0.0, TAU, 96, spec["c"], float(spec["w"]), true)
		draw_arc(c, hole - 1.5, 0.0, TAU, 96, Color(0.78, 0.78, 0.80, 0.95), 3.0, true)
		draw_arc(c, hole * 0.84, -2.45, -0.85, 28, Color(1.0, 1.0, 1.0, 0.28), 4.0, true)
		var mark := Color(0.93, 0.93, 0.90, 0.82)
		var arm := hole * 0.16
		var box := hole * 0.40
		_draw_bracket(c + Vector2(-box, -box), arm, 1.0, 1.0, mark)
		_draw_bracket(c + Vector2(box, -box), arm, -1.0, 1.0, mark)
		_draw_bracket(c + Vector2(-box, box), arm, 1.0, -1.0, mark)
		_draw_bracket(c + Vector2(box, box), arm, -1.0, -1.0, mark)
		draw_line(c + Vector2(-arm * 0.45, 0.0), c + Vector2(arm * 0.45, 0.0), mark, 1.6)
		draw_line(c + Vector2(0.0, -arm * 0.45), c + Vector2(0.0, arm * 0.45), mark, 1.6)


	func _draw_bracket(origin: Vector2, length: float, sx: float, sy: float, color: Color) -> void:
		draw_line(origin, origin + Vector2(length * sx, 0.0), color, 3.2)
		draw_line(origin, origin + Vector2(0.0, length * sy), color, 3.2)


## 一次性对焦滑动槽：指针从左扫到右，点下去锁档，不点就是最低档。
class _FocusQte extends Control:
	var needle := 0.0
	var locked := false
	var sweet := 0.72
	var sweet_radius := 0.11


	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 8.0 or h <= 8.0:
			return
		var track := Rect2(18.0, h * 0.42, w - 36.0, 18.0)
		draw_rect(track.grow(3.0), Color(0.08, 0.08, 0.09, 0.92), true)
		draw_rect(track, Color(0.22, 0.22, 0.24, 1.0), true)
		var sweet_x := track.position.x + track.size.x * sweet
		var zone := track.size.x * sweet_radius
		var sweet_rect := Rect2(sweet_x - zone, track.position.y, zone * 2.0, track.size.y)
		draw_rect(sweet_rect, Color(0.86, 0.72, 0.38, 0.95), true)
		draw_rect(Rect2(sweet_x - 2.0, track.position.y - 4.0, 4.0, track.size.y + 8.0), Color(0.98, 0.92, 0.62, 1.0), true)
		var nx := track.position.x + track.size.x * clampf(needle, 0.0, 1.0)
		var needle_col := Color(0.98, 0.96, 0.90) if not locked else Color(1.0, 0.84, 0.42)
		draw_rect(Rect2(nx - 3.0, track.position.y - 8.0, 6.0, track.size.y + 16.0), needle_col, true)
		var font := ThemeDB.fallback_font
		if font != null:
			var hint := "点击对焦" if not locked else "锁定"
			draw_string(
				font,
				Vector2(track.position.x, 22.0),
				hint,
				HORIZONTAL_ALIGNMENT_LEFT,
				track.size.x,
				18,
				Color(0.93, 0.93, 0.90, 0.9)
			)


func _build_photo_ui() -> void:
	_photo_layer = Control.new()
	_photo_layer.name = "PhotoLayer"
	_photo_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_photo_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_photo_layer)
	var film := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	film.fill(Color(0.12, 0.11, 0.10))
	_empty_film_tex = ImageTexture.create_from_image(film)
	_viewfinder = _CameraLens.new()
	_viewfinder.name = "Viewfinder"
	_viewfinder.visible = false
	_viewfinder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_layer.add_child(_viewfinder)
	_polaroid = PanelContainer.new()
	_polaroid.name = "Polaroid"
	_polaroid.visible = false
	_polaroid.mouse_filter = Control.MOUSE_FILTER_STOP
	_polaroid.custom_minimum_size = Vector2(520.0, 360.0)
	_polaroid.size = Vector2(520.0, 360.0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.99, 0.97, 0.90)
	box.border_color = Color(0.99, 0.97, 0.90)
	box.border_width_left = 14
	box.border_width_top = 14
	box.border_width_right = 14
	box.border_width_bottom = 36
	box.set_corner_radius_all(5)
	box.shadow_color = Color(0.015, 0.02, 0.05, 0.5)
	box.shadow_size = 18
	_polaroid.add_theme_stylebox_override("panel", box)
	_polaroid_image = TextureRect.new()
	_polaroid_image.name = "Image"
	_polaroid_image.custom_minimum_size = Vector2(492.0, 310.0)
	_polaroid_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_polaroid_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_polaroid_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_polaroid.add_child(_polaroid_image)
	_photo_layer.add_child(_polaroid)
	_focus_qte = _FocusQte.new()
	_focus_qte.name = "FocusQte"
	_focus_qte.visible = false
	_focus_qte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_qte.z_index = 2
	_focus_qte.sweet = REDSTART_QTE_SWEET
	_focus_qte.sweet_radius = REDSTART_QTE_SWEET_RADIUS
	_photo_layer.add_child(_focus_qte)
	_focus_grade = Label.new()
	_focus_grade.name = "FocusGrade"
	_focus_grade.visible = false
	_focus_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_grade.z_index = 8
	_focus_grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus_grade.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_focus_grade.add_theme_font_size_override("font_size", 96)
	_focus_grade.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))
	_focus_grade.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.92))
	_focus_grade.add_theme_constant_override("outline_size", 18)
	_photo_layer.add_child(_focus_grade)


func _make_button(node_name: String, text: String, box_size: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.size = box_size
	button.custom_minimum_size = box_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 24)
	return button


## `next_stage_id` 为空 = 从续局条的「放弃」进来的，放弃完就停在地图上；非空 = 点了
## 别的关卡，放弃完直接进那一关。
func _open_confirm(next_stage_id: String) -> void:
	if _resume_stage_id == "":
		return
	_pending_stage_id = next_stage_id
	var stage := StageTable.stage(_resume_stage_id)
	_confirm_text.text = "放弃「%s」的进度？\n已打到第 %d 盘的血量、金币与强化会全部清空。" % [
		String(stage.get("name", "")), maxi(_resume_round, 1)
	]
	_confirm.visible = true
	_confirm_dim.modulate.a = 0.0
	_confirm_card.pivot_offset = _confirm_card.size * 0.5
	_confirm_card.scale = Vector2(0.88, 0.88)
	_confirm_card.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_confirm_dim, "modulate:a", 1.0, 0.18)
	tween.tween_property(_confirm_card, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_confirm_card, "modulate:a", 1.0, 0.16)


func _close_confirm(immediate: bool) -> void:
	if _confirm == null:
		return
	_pending_stage_id = ""
	if immediate or not _confirm.visible:
		_confirm.visible = false
		_confirm_card.scale = Vector2.ONE
		_confirm_card.modulate.a = 1.0
		return
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_confirm_dim, "modulate:a", 0.0, 0.14)
	tween.tween_property(_confirm_card, "scale", Vector2(0.93, 0.93), 0.14)
	tween.tween_property(_confirm_card, "modulate:a", 0.0, 0.12)
	await tween.finished
	_confirm.visible = false
	_confirm_card.scale = Vector2.ONE
	_confirm_card.modulate.a = 1.0


func _on_confirm_yes() -> void:
	var next := _pending_stage_id
	_close_confirm(true)
	abandon_requested.emit()
	if next != "":
		stage_selected.emit(next)


func _refresh_resume_banner() -> void:
	if _resume_banner == null:
		return
	var stage := StageTable.stage(_resume_stage_id)
	if _resume_stage_id == "" or stage.is_empty():
		_resume_banner.visible = false
		return
	_resume_banner.visible = true
	_resume_text.text = "「%s」进行中 · 第 %d / %d 盘\n点其他关卡会放弃这份进度" % [
		String(stage["name"]), maxi(_resume_round, 1), int(stage["target_round"])
	]


## 当前地形区 = 离镜头中心最近的那个关卡所属的区（整图框定后即地图中心附近）。
func _refresh_region_readout() -> void:
	if _region_name_label == null:
		return
	var nearest := ""
	var best := INF
	for marker in _markers:
		var p := marker.global_position
		var d := Vector2(p.x - _pivot.x, p.z - _pivot.z).length_squared()
		if d < best:
			best = d
			nearest = String(marker.get_meta("stage_id", ""))
	var stage := StageTable.stage(nearest)
	if stage.is_empty():
		return
	var region_id := String(stage["region"])
	if region_id == _current_region_id:
		return
	_current_region_id = region_id
	var region := StageTable.region(region_id)
	var progress := StageTable.region_progress(region_id, _cleared)
	_region_name_label.text = String(region.get("name", ""))
	if not StageTable.is_region_unlocked(region_id, _cleared):
		_region_name_label.text += "（未解锁）"
	var text := "已通关 %d / %d" % [int(progress["cleared"]), int(progress["total"])]
	if String(progress["next_region"]) != "":
		var remaining := int(progress["remaining_for_next"])
		if remaining > 0:
			text += " · 再通 %d 关开启「%s」" % [remaining, String(progress["next_region_name"])]
		else:
			text += " · 「%s」已开启" % String(progress["next_region_name"])
	else:
		text += " · 最后一区"
	_region_progress_label.text = text


## 测试用：把某个关卡的悬浮牌取出来看状态。
func badge_for(stage_id: String) -> StageBadge:
	return _badges.get(stage_id)


func marker_count() -> int:
	return _markers.size()


func camera_distance() -> float:
	return _distance


func camera_pivot() -> Vector3:
	return _pivot


func bound_tile_for(stage_id: String) -> Node3D:
	return _stage_tiles.get(stage_id)


func outline_for(stage_id: String) -> MeshInstance3D:
	var tile: Node3D = _stage_tiles.get(stage_id)
	if tile == null:
		return null
	return tile.get_node_or_null("TileOutline") as MeshInstance3D


func tile_count() -> int:
	return _tiles.size()


func all_tiles() -> Array[Node3D]:
	return _tiles


func flora_props() -> Array[Node3D]:
	return _flora


func hovered_flora() -> Node3D:
	return _hovered_flora
