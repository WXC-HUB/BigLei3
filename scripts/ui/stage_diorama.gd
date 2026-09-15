class_name StageDiorama
extends Node3D
## 单关「展品」：一座手工构图的低模小岛，可以自己站在波点桌布的展柜台面上（standalone），
## 也可以作为陈列柜（StageCabinet）里的一件被摆到架上（hosted：台面、灯、相机由柜子提供）。
##
## 模型本体由 Blender 脚本生成（tools/build_diorama_*.py → assets/dioramas/<id>/<id>.glb），
## 这里负责「展柜」部分：台面（着色器画的渐变 + 屏幕空间波点）与岛底的柔和接触阴影、
## 主光/补光/环境光、溪水面、关卡锚点、拾取体与相机。布局数据（格子掩码、水位、锚点、
## 入场时序）读同目录的 <id>.json，和模型一个来源。还没做出展品的关卡用
## assets/dioramas/placeholder（灰泥胚）顶着，见 paths_for()。
##
## 入场：模型的顶点色里编着每件东西的基点与起跳时刻（Blender 端 finalize 写入），
## `diorama_build.gdshader` 按 `build` 进度让地形从台面弹起、各件道具围着自己的基点
## 果冻似地弹出；这里只推进 `build` 这一个数，再把溪水抬起来、把岛影淡进来。
##
## 模型加载：已导入就用导入后的 PackedScene；没导入（刚出图、测试环境）或环境变量
## DIORAMA_LIVE=1 时直接用 GLTFDocument 读 .glb，调美术时不用每次都跑一遍 --import。

signal entrance_finished
## 换了荒废 / 生机版模型（桌布配色、水面都可能变了）。
signal variant_changed

const BUILD_SHADER := preload("res://shaders/diorama_build.gdshader")
const TABLE_SHADER := preload("res://shaders/diorama_table.gdshader")

const PLACEHOLDER_MODEL := "res://assets/dioramas/placeholder/placeholder.glb"
const PLACEHOLDER_LAYOUT := "res://assets/dioramas/placeholder/placeholder.json"
## 拾取体所在的物理层：陈列柜用射线找鼠标下面是哪件展品。
const PICK_LAYER := 1 << 6

@export var stage_id := "grass_1"
@export var model_path := "res://assets/dioramas/grass_1/grass_1.glb"
@export var layout_path := "res://assets/dioramas/grass_1/grass_1.json"
## 进场景就播入场动画；截图/测试可关掉，直接是完全体。
@export var entrance_on_ready := false
## 自己带台面、灯光、环境与相机；被陈列柜托管时关掉，只留模型、水、锚点、岛影与拾取体。
@export var standalone := true
## 荒废态：这关还没通关时摆的是荒废版模型（<id>_withered.glb：枯树、封板窗、缺瓦、干井、
## 沉船、熄灯、鸟都走了），通关后换成生机版。没有荒废版文件时退回生机版。
@export var withered := false

@export_group("Clouds")
## 展品上空飘几朵云：云影落在岛上（主光真阴影）与水面上（水着色器自己画）。
@export var clouds_enabled := true
@export var cloud_count := 3

@export_group("Camera")
@export var camera_pitch_deg := -37.0
@export var camera_yaw_deg := 31.0
@export var camera_size := 23.0
## 画面中心相对小岛中心的偏移（世界单位，x / z）。
@export var camera_offset := Vector2(-0.24, -2.2)

@export_group("Lighting")
@export var key_energy := 0.25
@export var key_elevation_deg := 54.0
## 主光方位（相对相机方位的偏角）：+232° 落在画面左后上方，影子往右前落，同参考图。
@export var key_azimuth_offset_deg := 232.0
## 补光从相机略偏右的前方低角度打，托起朝观众的悬崖面与墙面。
@export var fill_energy := 0.60
@export var fill_elevation_deg := 12.0
@export var fill_azimuth_offset_deg := 15.0
@export var ambient_energy := 0.22
@export var shadow_opacity := 0.82

## 台面波点桌布：三种点色都取自展品配色，对比很低。
const TABLE_FAR := Color("f8f4ea")
const TABLE_NEAR := Color("ece3d2")
const DOT_SAND := Color("e6dbc6")
const DOT_SAGE := Color("cfd8bf")
const DOT_CLAY := Color("ecdacd")
const TABLE_SIZE := 110.0
## 小岛压在台面上的一圈柔和暗影（假环境光遮蔽，Compatibility 渲染器没有 SSAO）。
const TABLE_SHADOW_TINT := Color(0.42, 0.35, 0.25)
const TABLE_SHADOW_ALPHA := 0.30
const TABLE_SHADOW_MARGIN := 4.0
const TABLE_SHADOW_PX := 256
const WATER_SHALLOW := Color("a9d8d0", 0.82)
const WATER_DEEP := Color("78b3a8", 0.90)
## 入场默认时序（JSON 里有就以 JSON 为准）。
const DEFAULT_ENTRANCE := {"span": 1.35, "piece_time": 0.55, "rise_time": 0.7,
	"pivot_min": [-16.0, -3.0, -12.0], "pivot_size": [32.0, 10.0, 24.0]}
## 溪水在地形落定之后从河床升到水位。
const WATER_RISE_START := 0.42
const WATER_RISE_TIME := 0.5
## 未解锁展品的「泥胚」观感：抽掉大半颜色、压一点暖灰。
const LOCKED_DESATURATE := 0.85
const LOCKED_TINT := Color(0.90, 0.88, 0.84)
## 拾取体高度：从台面到最高的树梢再留一点。
const PICK_HEIGHT := 7.5
## 云：飞行高度、漂速、航线比占地外扩多少格、水面最多画几团云影。
const CLOUD_HEIGHT := Vector2(7.2, 9.0)
const CLOUD_SPEED := Vector2(0.35, 0.7)
const CLOUD_MARGIN := 9.0
const CLOUD_MAX_SHADOWS := 8
const CARTOON_CLOUD_SHADER := preload("res://shaders/cartoon_cloud.gdshader")
## 荒废态的常态微动收小：枯枝不该随风乱摆。
const WITHERED_MOTION := 0.45
## 复原（荒废 → 生机）：先按原路收回，再换模型重搭。
const RESTORE_EXIT := 0.72
## 复原时的粒子：叶与花瓣的颜色、光点的颜色、台面上扩开的一圈光。
const RESTORE_LEAF_COLORS: Array[Color] = [Color("a6c27b"), Color("8fae6a"), Color("f2c4bf"), Color("f5e1a0"), Color("ffffff"), Color("b4ca88")]
const RESTORE_MOTE_COLOR := Color(1.0, 0.92, 0.62, 1.0)
const RESTORE_RING_COLOR := Color(1.0, 0.94, 0.72, 0.85)
const RESTORE_FX_LIFETIME := 5.6

var _layout := {}
var _model: Node3D
var _camera: Camera3D
var _marker: Node3D
## 每一层水面一条：{"mesh": MeshInstance3D, "bed": float, "top": float}（溪流、深潭、台地上的小溪各自有水位）。
var _waters: Array[Dictionary] = []
var _table_shadow: MeshInstance3D
var _env_holder: WorldEnvironment
var _table_mat: ShaderMaterial
var _pick: StaticBody3D
var _material_cache: Dictionary = {}
var _build_materials: Array[ShaderMaterial] = []
var _entrance_tween: Tween
var _locked_look := false
var _clouds: Array[Node3D] = []
var _cloud_rng := RandomNumberGenerator.new()
var _restoring := false
## 云的漂移方向（本地坐标）；柜子把它设成画面横向，云就横穿画面。
var wind := Vector3(1.0, 0.0, 0.25)
## 入场进度 0（什么都没有）→ 1（完全体）。写它就同步到所有模型材质。
var build_progress := 1.0:
	set(value):
		build_progress = clampf(value, 0.0, 1.0)
		for mat in _build_materials:
			mat.set_shader_parameter("build", build_progress)


func _ready() -> void:
	if withered:
		var wp := paths_for(stage_id, true)
		if bool(wp["withered"]):
			model_path = String(wp["model"])
			layout_path = String(wp["layout"])
	_layout = _read_layout()
	if standalone:
		_env_holder = build_environment(ambient_energy)
		add_child(_env_holder)
		for light in build_lights(camera_yaw_deg, key_energy, key_elevation_deg, key_azimuth_offset_deg,
				fill_energy, fill_elevation_deg, fill_azimuth_offset_deg, shadow_opacity):
			add_child(light)
		var table := build_table(table_y(), TABLE_SIZE)
		_table_mat = table.material_override as ShaderMaterial
		add_child(table)
		# 每关自己的桌布配色：底色与三种点色都跟着展品走。
		apply_table_palette(_table_mat, table_palette())
		_env_holder.environment.background_color = table_palette()["far"]
	_build_island_shadow()
	_build_model()
	_build_water()
	_build_marker()
	_build_pick()
	_build_clouds()
	if standalone:
		_build_camera()
	if entrance_on_ready:
		play_entrance()
	set_process(true)


# --- 对外 ---


## 某关的展品资源：有真展品就用它，没有就用灰泥胚占位。
static func paths_for(id: String, want_withered := false) -> Dictionary:
	var model := "res://assets/dioramas/%s/%s.glb" % [id, id]
	var layout_file := "res://assets/dioramas/%s/%s.json" % [id, id]
	var real := _res_exists(model) and _res_exists(layout_file)
	if real and want_withered:
		var wm := "res://assets/dioramas/%s/%s_withered.glb" % [id, id]
		var wl := "res://assets/dioramas/%s/%s_withered.json" % [id, id]
		if _res_exists(wm) and _res_exists(wl):
			return {"model": wm, "layout": wl, "real": true, "withered": true}
	if real:
		return {"model": model, "layout": layout_file, "real": true, "withered": false}
	return {"model": PLACEHOLDER_MODEL, "layout": PLACEHOLDER_LAYOUT, "real": false, "withered": false}


static func _res_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


func showcase_camera() -> Camera3D:
	return _camera


func marker() -> Node3D:
	return _marker


func model() -> Node3D:
	return _model


## 第一层水面（测试与老调用方用）；没有水的展品返回 null。
func water() -> MeshInstance3D:
	return _waters[0]["mesh"] if not _waters.is_empty() else null


## 这件展品的桌布配色（JSON `table`），缺省回到青草坡的暖奶油。
func table_palette() -> Dictionary:
	var given: Variant = _layout.get("table", {})
	var far := TABLE_FAR
	var near := TABLE_NEAR
	var dots: Array[Color] = [DOT_SAND, DOT_SAGE, DOT_CLAY]
	if given is Dictionary:
		var g := given as Dictionary
		if g.has("far"):
			far = Color(String(g["far"]))
		if g.has("near"):
			near = Color(String(g["near"]))
		if g.has("dots") and g["dots"] is Array:
			var arr: Array = g["dots"]
			for i in mini(3, arr.size()):
				dots[i] = Color(String(arr[i]))
	return {"far": far, "near": near, "dots": dots}


## 把一套桌布配色写进台面着色器材质。
static func apply_table_palette(mat: ShaderMaterial, palette: Dictionary) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("base_far", palette["far"])
	mat.set_shader_parameter("base_near", palette["near"])
	var dots: Array = palette["dots"]
	mat.set_shader_parameter("dot_sand", dots[0])
	mat.set_shader_parameter("dot_sage", dots[1])
	mat.set_shader_parameter("dot_clay", dots[2])


## 两套桌布配色按 t 插值（切换展品时台面慢慢换色）。
static func lerp_table_palette(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var dots: Array[Color] = []
	for i in 3:
		dots.append((a["dots"][i] as Color).lerp(b["dots"][i], t))
	return {"far": (a["far"] as Color).lerp(b["far"], t), "near": (a["near"] as Color).lerp(b["near"], t), "dots": dots}


## 这件展品的水色（JSON `water`），缺省是青草坡的灰青。
func water_colors() -> Dictionary:
	var given: Variant = _layout.get("water", {})
	var shallow := WATER_SHALLOW
	var deep := WATER_DEEP
	if given is Dictionary:
		var g := given as Dictionary
		if g.has("shallow"):
			var c := Color(String(g["shallow"]))
			shallow = Color(c.r, c.g, c.b, WATER_SHALLOW.a)
		if g.has("deep"):
			var c2 := Color(String(g["deep"]))
			deep = Color(c2.r, c2.g, c2.b, WATER_DEEP.a)
	return {"shallow": shallow, "deep": deep}


func pick_body() -> StaticBody3D:
	return _pick


func layout() -> Dictionary:
	return _layout


func is_placeholder() -> bool:
	return model_path == PLACEHOLDER_MODEL


## 小岛底面所在高度（台面高度）。
func table_y() -> float:
	return float(_layout.get("bottom", -2.4))


## 小岛在 xz 上的占地（格数）。
func footprint() -> Vector2:
	return Vector2(float(_cols()), float(_rows()))


## 聚焦这件展品时相机该对准的点（世界坐标）：与单独展示时相同的构图偏移。
func focus_target() -> Vector3:
	return global_position + Vector3(camera_offset.x, 0.0, camera_offset.y)


## 整段入场动画的时长（秒）。
func entrance_duration() -> float:
	var e := _entrance()
	return float(e["span"]) + float(e["piece_time"])


func is_entrance_playing() -> bool:
	return _entrance_tween != null and _entrance_tween.is_valid() and _entrance_tween.is_running()


## 播「搭积木」入场：地形先从台面弹起，随后各件东西按编好的时刻依次弹出，
## 溪水在地形落定后升到水位，岛影跟着淡进来。播完发 entrance_finished。
func play_entrance() -> void:
	skip_entrance()
	build_progress = 0.0
	set_water_level(0.0)
	set_shadow_alpha(0.0)
	var total := entrance_duration()
	_entrance_tween = create_tween().set_parallel(true)
	_entrance_tween.tween_property(self, "build_progress", 1.0, total)
	_entrance_tween.tween_method(set_shadow_alpha, 0.0, 1.0, float(_entrance()["rise_time"]) * 0.8)
	_entrance_tween.tween_method(set_water_level, 0.0, 1.0, WATER_RISE_TIME) \
		.set_delay(WATER_RISE_START).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.chain().tween_callback(func() -> void: entrance_finished.emit())


## 收起（切走时用）：建好的东西按原路缩回台面，比直接消失更像收进柜子。
func play_exit(duration := 0.45) -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	_entrance_tween = create_tween().set_parallel(true)
	_entrance_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_entrance_tween.tween_property(self, "build_progress", 0.0, duration)
	_entrance_tween.tween_method(set_water_level, 1.0, 0.0, duration * 0.6)
	_entrance_tween.tween_method(set_shadow_alpha, 1.0, 0.0, duration)


## 直接跳到完全体（关掉正在播的入场）。
func skip_entrance() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	_entrance_tween = null
	build_progress = 1.0
	set_water_level(1.0)
	set_shadow_alpha(1.0)


## 未解锁的关卡：整件展品退成灰泥胚（抽色 + 暖灰），溪水也收掉。
func set_locked_look(locked: bool) -> void:
	_locked_look = locked
	for mat in _build_materials:
		mat.set_shader_parameter("desaturate", LOCKED_DESATURATE if locked else 0.0)
		mat.set_shader_parameter("tint", LOCKED_TINT if locked else Color.WHITE)
	for entry in _waters:
		(entry["mesh"] as MeshInstance3D).visible = not locked


func is_locked_look() -> bool:
	return _locked_look


## 这件展品此刻摆的是不是荒废版（看布局 JSON 的 withered 标记）。
func is_withered() -> bool:
	return bool(_layout.get("withered", false))


## 正在复原（荒废版收回、生机版重搭）。
func is_restoring() -> bool:
	return _restoring


## 切到荒废 / 生机版。animate=true 是通关后回柜子的「复原」：先按原路收回，再换模型重搭。
func set_withered(value: bool, animate := false) -> void:
	var paths := paths_for(stage_id, value)
	withered = value
	if String(paths["model"]) == model_path and String(paths["layout"]) == layout_path:
		return
	model_path = String(paths["model"])
	layout_path = String(paths["layout"])
	if not is_inside_tree() or _model == null:
		return
	if not animate:
		_swap_variant()
		return
	_restoring = true
	play_exit(RESTORE_EXIT)
	await get_tree().create_timer(RESTORE_EXIT + 0.05).timeout
	if not is_inside_tree():
		_restoring = false
		return
	_swap_variant()
	_spawn_restore_effects()
	play_entrance()
	_restoring = false


func _swap_variant() -> void:
	_layout = _read_layout()
	if _model != null:
		_model.free()
		_model = null
	for entry in _waters:
		(entry["mesh"] as MeshInstance3D).free()
	_waters.clear()
	_build_model()
	_build_water()
	set_locked_look(_locked_look)
	_apply_cloud_mood()
	variant_changed.emit()


# --- 展柜零件（陈列柜也用这几只静态方法，保证同一套光和台面） ---


static func build_environment(ambient: float) -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = TABLE_FAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.985, 0.965, 0.93)
	env.ambient_light_energy = ambient
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.fog_enabled = false
	var holder := WorldEnvironment.new()
	holder.name = "Env"
	holder.environment = env
	return holder


## 主光从画面左后上方来：顶面最亮、影子落向画面右前；补光从前方低角度托起立面。
static func build_lights(yaw_deg: float, key: float, key_elev: float, key_az_off: float,
		fill: float, fill_elev: float, fill_az_off: float, shadow_alpha: float) -> Array[DirectionalLight3D]:
	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	var from := direction(key_elev, yaw_deg + key_az_off)
	key_light.look_at_from_position(from * 40.0, Vector3.ZERO, Vector3.UP)
	key_light.light_energy = key
	key_light.light_color = Color(1.0, 0.98, 0.95)
	key_light.light_specular = 0.0
	key_light.shadow_enabled = true
	key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key_light.directional_shadow_max_distance = 160.0
	key_light.shadow_blur = 2.2
	key_light.light_angular_distance = 1.6
	key_light.shadow_bias = 0.03
	key_light.shadow_normal_bias = 0.7
	key_light.shadow_opacity = shadow_alpha
	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	var fill_from := direction(fill_elev, yaw_deg + fill_az_off)
	fill_light.look_at_from_position(fill_from * 40.0, Vector3.ZERO, Vector3.UP)
	fill_light.light_energy = fill
	fill_light.light_color = Color(0.96, 0.95, 0.97)
	fill_light.light_specular = 0.0
	fill_light.shadow_enabled = false
	return [key_light, fill_light]


## 波点桌布台面：屏幕空间正圆点子，仍是受光平面，岛影照落。
static func build_table(y: float, size: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var table := MeshInstance3D.new()
	table.name = "Table"
	table.mesh = plane
	table.position = Vector3(0.0, y, 0.0)
	table.material_override = table_material()
	table.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return table


static func table_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TABLE_SHADER
	mat.set_shader_parameter("base_far", TABLE_FAR)
	mat.set_shader_parameter("base_near", TABLE_NEAR)
	mat.set_shader_parameter("dot_sand", DOT_SAND)
	mat.set_shader_parameter("dot_sage", DOT_SAGE)
	mat.set_shader_parameter("dot_clay", DOT_CLAY)
	return mat


## 方位角 0 = +Z（相机默认所在的正前方），向 +X 转为正；仰角从水平面起算。
static func direction(elevation_deg: float, azimuth_deg: float) -> Vector3:
	var el := deg_to_rad(elevation_deg)
	var az := deg_to_rad(azimuth_deg)
	return Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el)).normalized()


# --- 布局数据 ---


func _read_layout() -> Dictionary:
	var text := ""
	if ResourceLoader.exists(layout_path):
		var res := load(layout_path)
		if res is JSON:
			var data: Variant = (res as JSON).data
			if data is Dictionary:
				return data
	if FileAccess.file_exists(layout_path):
		text = FileAccess.get_file_as_string(layout_path)
	if text == "":
		push_warning("StageDiorama: 读不到布局 %s" % layout_path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _entrance() -> Dictionary:
	var merged := DEFAULT_ENTRANCE.duplicate()
	var given: Variant = _layout.get("entrance", {})
	if given is Dictionary:
		for key in (given as Dictionary).keys():
			merged[key] = given[key]
	return merged


func _cols() -> int:
	return int(_layout.get("cols", 30))


func _rows() -> int:
	return int(_layout.get("rows", 22))


## 格子坐标 → 本地坐标（与 Blender 端 xy() 一致：x = c - cols/2，z = r - rows/2）。
func cell_to_local(c: float, r: float, y: float = 0.0) -> Vector3:
	return Vector3(c - _cols() * 0.5, y, r - _rows() * 0.5)


func _cell(c: int, r: int) -> String:
	var mask: Array = _layout.get("mask", [])
	if r < 0 or r >= mask.size():
		return "."
	var line := String(mask[r])
	if c < 0 or c >= line.length():
		return "."
	return line[c]


# --- 岛影 ---


func _build_island_shadow() -> void:
	_table_shadow = MeshInstance3D.new()
	_table_shadow.name = "TableShadow"
	var quad := PlaneMesh.new()
	quad.size = Vector2(_cols() + TABLE_SHADOW_MARGIN * 2.0, _rows() + TABLE_SHADOW_MARGIN * 2.0)
	_table_shadow.mesh = quad
	_table_shadow.position = Vector3(0.0, table_y() + 0.012, 0.0)
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.albedo_texture = _table_shadow_texture()
	shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_table_shadow.material_override = shadow_mat
	_table_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_table_shadow)


## 岛影浓淡（0 = 无）。
func set_shadow_alpha(alpha: float) -> void:
	if _table_shadow == null:
		return
	var mat := _table_shadow.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))


## 按格子掩码画一张软边暗影：岛底下全暗、往外约一格半淡出。
func _table_shadow_texture() -> ImageTexture:
	var n := TABLE_SHADOW_PX
	var span_x := _cols() + TABLE_SHADOW_MARGIN * 2.0
	var span_z := _rows() + TABLE_SHADOW_MARGIN * 2.0
	var field := PackedFloat32Array()
	field.resize(n * n)
	for py in n:
		var r := (float(py) + 0.5) / n * span_z - TABLE_SHADOW_MARGIN
		for px in n:
			var c := (float(px) + 0.5) / n * span_x - TABLE_SHADOW_MARGIN
			field[py * n + px] = 1.0 if _cell(int(floor(c)), int(floor(r))) != "." else 0.0
	var radius := int(1.35 / span_x * n)
	for _pass in 3:
		field = _box_blur(field, n, radius)
	var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for py in n:
		for px in n:
			var a := clampf(field[py * n + px], 0.0, 1.0)
			image.set_pixel(px, py, Color(TABLE_SHADOW_TINT.r, TABLE_SHADOW_TINT.g, TABLE_SHADOW_TINT.b, a * TABLE_SHADOW_ALPHA))
	return ImageTexture.create_from_image(image)


static func _box_blur(src: PackedFloat32Array, n: int, radius: int) -> PackedFloat32Array:
	if radius <= 0:
		return src
	var tmp := PackedFloat32Array()
	tmp.resize(n * n)
	var out := PackedFloat32Array()
	out.resize(n * n)
	var span := float(radius * 2 + 1)
	for y in n:
		var acc := 0.0
		for x in range(-radius, radius + 1):
			acc += src[y * n + clampi(x, 0, n - 1)]
		for x in n:
			tmp[y * n + x] = acc / span
			acc += src[y * n + clampi(x + radius + 1, 0, n - 1)] - src[y * n + clampi(x - radius, 0, n - 1)]
	for x in n:
		var acc := 0.0
		for y in range(-radius, radius + 1):
			acc += tmp[clampi(y, 0, n - 1) * n + x]
		for y in n:
			out[y * n + x] = acc / span
			acc += tmp[clampi(y + radius + 1, 0, n - 1) * n + x] - tmp[clampi(y - radius, 0, n - 1) * n + x]
	return out


# --- 模型 ---


func _build_model() -> void:
	_model = _load_model_scene()
	if _model == null:
		push_error("StageDiorama: 加载不到模型 %s" % model_path)
		_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_material_cache.clear()
	_build_materials.clear()
	_shader_pass(_model)
	build_progress = 1.0


func _load_model_scene() -> Node3D:
	var live := OS.get_environment("DIORAMA_LIVE") == "1"
	if not live and ResourceLoader.exists(model_path, "PackedScene"):
		var packed := load(model_path) as PackedScene
		if packed != null:
			return packed.instantiate() as Node3D
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(model_path), state)
	if err != OK:
		push_error("StageDiorama: GLTFDocument 读取失败 %s（%d）" % [model_path, err])
		return null
	return doc.generate_scene(state) as Node3D


## 把导入的标准材质换成入场着色器材质：颜色/贴图照搬，统一哑光；地形组走 mode 0（从台面弹起），
## 其它组走 mode 1（围基点弹出）。同一份源材质在同一 mode 下只建一份。
func _shader_pass(node: Node) -> void:
	var mesh_node := node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		var mode := 0 if String(mesh_node.name).to_lower().begins_with("terrain") else 1
		for surface in mesh_node.mesh.get_surface_count():
			var source := mesh_node.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var key := "%d:%d" % [source.get_instance_id(), mode]
			if not _material_cache.has(key):
				_material_cache[key] = _make_build_material(source, mode)
			mesh_node.set_surface_override_material(surface, _material_cache[key])
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_shader_pass(child)


func _make_build_material(source: BaseMaterial3D, mode: int) -> ShaderMaterial:
	var e := _entrance()
	var mat := ShaderMaterial.new()
	mat.shader = BUILD_SHADER
	mat.set_shader_parameter("albedo", source.albedo_color)
	if source.albedo_texture != null:
		mat.set_shader_parameter("albedo_tex", source.albedo_texture)
		mat.set_shader_parameter("use_albedo_tex", true)
	mat.set_shader_parameter("specular_amount", 0.1)
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("motion_amount", WITHERED_MOTION if is_withered() else 1.0)
	mat.set_shader_parameter("rise_from", table_y())
	mat.set_shader_parameter("build", 1.0)
	mat.set_shader_parameter("build_total", float(e["span"]) + float(e["piece_time"]))
	mat.set_shader_parameter("build_span", float(e["span"]))
	mat.set_shader_parameter("piece_time", float(e["piece_time"]))
	mat.set_shader_parameter("rise_time", float(e["rise_time"]))
	var pmin: Array = e["pivot_min"]
	var psize: Array = e["pivot_size"]
	mat.set_shader_parameter("pivot_min", Vector3(float(pmin[0]), float(pmin[1]), float(pmin[2])))
	mat.set_shader_parameter("pivot_size", Vector3(float(psize[0]), float(psize[1]), float(psize[2])))
	mat.set_shader_parameter("desaturate", LOCKED_DESATURATE if _locked_look else 0.0)
	mat.set_shader_parameter("tint", LOCKED_TINT if _locked_look else Color.WHITE)
	_build_materials.append(mat)
	return mat


# --- 水 ---


## 水面：掩码里每个水位字符（默认只有 W）各铺一层卡通水面——溪流、深潭、台地上的小溪
## 各自有自己的高度；着色器和选关图池塘同一套，配色按展品的 JSON `water` 走。
func _build_water() -> void:
	_waters.clear()
	var levels: Dictionary = {}
	var given: Variant = _layout.get("water_levels", {})
	if given is Dictionary and not (given as Dictionary).is_empty():
		for key in (given as Dictionary).keys():
			levels[String(key)] = float(given[key])
	elif _layout.has("water_y"):
		levels["W"] = float(_layout["water_y"])
	var heights: Dictionary = _layout.get("heights", {})
	var colors := water_colors()
	for char in levels.keys():
		var mesh := _water_mesh_for(char)
		if mesh == null:
			continue
		var node := MeshInstance3D.new()
		node.name = "Water" if _waters.is_empty() else "Water_%s" % char
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		WorldMap.apply_toon_water_material(node, true)
		var mat := node.get_surface_override_material(0) as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("depth_gradient_shallow", colors["shallow"])
			mat.set_shader_parameter("depth_gradient_deep", colors["deep"])
			mat.set_shader_parameter("depth_max_distance", 0.30)
			mat.set_shader_parameter("foam_max_distance", 0.22)
			mat.set_shader_parameter("foam_min_distance", 0.03)
			mat.set_shader_parameter("surface_noise_cutoff", 0.80)
			mat.set_shader_parameter("surface_noise_scale", 2.6)
			mat.set_shader_parameter("surface_noise_scroll", Vector2(0.02, 0.05))
			if is_withered():
				# 荒废态的水是一层浑浊的死水：不起浪花，也慢得几乎不动。
				mat.set_shader_parameter("surface_noise_cutoff", 1.0)
				mat.set_shader_parameter("foam_max_distance", 0.01)
				mat.set_shader_parameter("foam_min_distance", 0.0)
				mat.set_shader_parameter("surface_noise_scroll", Vector2(0.004, 0.008))
		var top := float(levels[char])
		var bed := float(heights.get(char, top - 0.25)) + 0.02
		_waters.append({"mesh": node, "bed": bed, "top": top})
	set_water_level(1.0)


func _water_mesh_for(char: String) -> ArrayMesh:
	var cells: Array[Vector2i] = []
	var mask: Array = _layout.get("mask", [])
	for r in mask.size():
		var line := String(mask[r])
		for c in line.length():
			if line[c] == char:
				cells.append(Vector2i(c, r))
	if cells.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grow := 0.03
	for cell in cells:
		var a := cell_to_local(cell.x - grow, cell.y - grow, 0.0)
		var b := cell_to_local(cell.x + 1.0 + grow, cell.y + 1.0 + grow, 0.0)
		var corners := [Vector3(a.x, 0.0, a.z), Vector3(b.x, 0.0, a.z), Vector3(b.x, 0.0, b.z), Vector3(a.x, 0.0, b.z)]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		# Godot 的三角形以顺时针为正面；从上往下看 a→b→c 是顺时针，水面才朝上。
		for index in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[index])
			st.add_vertex(corners[index])
	return st.commit()


## 0 = 贴着河床，1 = 正常水位（每一层水各按自己的床与水位）。
func set_water_level(fraction: float) -> void:
	for entry in _waters:
		(entry["mesh"] as MeshInstance3D).position.y = lerpf(float(entry["bed"]), float(entry["top"]), clampf(fraction, 0.0, 1.0))


# --- 锚点、拾取体与相机 ---


func _build_marker() -> void:
	_marker = Node3D.new()
	_marker.name = "StageMarker"
	_marker.set_meta("stage_id", stage_id)
	var anchor: Dictionary = _layout.get("marker", {"c": _cols() * 0.5, "r": _rows() * 0.5})
	_marker.position = cell_to_local(float(anchor.get("c", 0.0)), float(anchor.get("r", 0.0)), 0.0)
	add_child(_marker)


## 一个罩住整座小岛的盒子，只给鼠标射线用，不参与任何物理。
func _build_pick() -> void:
	_pick = StaticBody3D.new()
	_pick.name = "Pick"
	_pick.collision_layer = PICK_LAYER
	_pick.collision_mask = 0
	_pick.input_ray_pickable = false
	_pick.set_meta("stage_id", stage_id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(float(_cols()), PICK_HEIGHT, float(_rows()))
	shape.shape = box
	shape.position = Vector3(0.0, table_y() + PICK_HEIGHT * 0.5, 0.0)
	_pick.add_child(shape)
	add_child(_pick)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "ShowcaseCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = camera_size
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 0.5
	_camera.far = 400.0
	add_child(_camera)
	frame_camera()
	# 单独运行这个场景（F6）时没人来 make_current，自己顶上；接进主场景后由外面决定谁当相机。
	if get_viewport() != null and get_viewport().get_camera_3d() == null:
		_camera.make_current()


## 相机对准小岛中心（可偏移），沿设定的俯仰/方位退到远处正交拍。
func frame_camera() -> void:
	if _camera == null:
		return
	var target := Vector3(camera_offset.x, 0.0, camera_offset.y)
	var from := direction(-camera_pitch_deg, camera_yaw_deg)
	_camera.look_at_from_position(target + from * 120.0, target, Vector3.UP)
	_camera.size = camera_size


# --- 云 ---


## 几朵卡通云沿风向横穿展品上空：团子不吃光（自己的着色器），云影由只投影的椭球交给主光真阴影，
## 水面吃不到灯光阴影，就把每朵云落在地面的位置塞给水着色器自己画。
func _build_clouds() -> void:
	if not clouds_enabled or cloud_count <= 0:
		return
	_cloud_rng.seed = hash(stage_id)
	var host := Node3D.new()
	host.name = "Clouds"
	add_child(host)
	var fp := footprint()
	var w := wind.normalized()
	var perp := Vector3(-w.z, 0.0, w.x)
	for i in cloud_count:
		var cloud := Node3D.new()
		cloud.name = "Cloud_%d" % i
		var big := i % 3 != 2
		var scale := _cloud_rng.randf_range(2.0, 2.6) if big else _cloud_rng.randf_range(1.4, 1.8)
		cloud.scale = Vector3.ONE * scale
		cloud.rotation.y = _cloud_rng.randf() * TAU
		_build_cloud_puffs(cloud, big)
		var radius := (1.05 if big else 0.72) * scale
		_attach_cloud_shadow_caster(cloud, radius / scale)
		# 起点摊在整条航线上，别一开始全挤在一起。
		var along := _cloud_rng.randf_range(-1.0, 1.0) * (fp.x * 0.5 + CLOUD_MARGIN)
		var side := _cloud_rng.randf_range(-1.0, 1.0) * (fp.y * 0.5 + 2.0)
		var base_y := _cloud_rng.randf_range(CLOUD_HEIGHT.x, CLOUD_HEIGHT.y)
		cloud.position = w * along + perp * side + Vector3(0.0, base_y, 0.0)
		cloud.set_meta("speed", _cloud_rng.randf_range(CLOUD_SPEED.x, CLOUD_SPEED.y))
		cloud.set_meta("base_y", base_y)
		cloud.set_meta("bob_phase", _cloud_rng.randf() * TAU)
		cloud.set_meta("radius", radius)
		host.add_child(cloud)
		_clouds.append(cloud)
	_apply_cloud_mood()


func clouds() -> Array[Node3D]:
	return _clouds


func _cloud_material(gloomy: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CARTOON_CLOUD_SHADER
	if gloomy:
		mat.set_shader_parameter("fill", Color(0.74, 0.74, 0.73))
		mat.set_shader_parameter("belly", Color(0.56, 0.57, 0.58))
		mat.set_shader_parameter("line", Color(0.48, 0.49, 0.50))
	else:
		mat.set_shader_parameter("fill", Color(1.0, 0.998, 0.99))
		mat.set_shader_parameter("belly", Color(0.86, 0.89, 0.92))
		mat.set_shader_parameter("line", Color(0.80, 0.84, 0.88))
	mat.set_shader_parameter("line_width", 0.22)
	return mat


func _build_cloud_puffs(root: Node3D, big: bool) -> void:
	var specs: Array[Vector4] = []
	if big:
		specs = [Vector4(0.00, 0.04, 0.00, 0.40), Vector4(-0.36, -0.03, 0.05, 0.30), Vector4(0.38, -0.02, -0.04, 0.32),
			Vector4(0.06, 0.10, -0.20, 0.26)]
	else:
		specs = [Vector4(0.00, 0.02, 0.00, 0.32), Vector4(-0.26, -0.03, 0.04, 0.24), Vector4(0.24, -0.02, -0.03, 0.23)]
	var mat := _cloud_material(is_withered())
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
	# 比云团本身小一圈：影子只是一块柔和的暗斑，不要盖住半个岛。
	caster.scale = Vector3(local_radius * 0.78, local_radius * 0.28, local_radius * 0.55)
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	caster.material_override = mat
	root.add_child(caster)


## 荒废态的云偏灰暗，生机态的云雪白；换版时跟着换。
func _apply_cloud_mood() -> void:
	var mat := _cloud_material(is_withered())
	for cloud in _clouds:
		for puff in cloud.get_children():
			if puff is MeshInstance3D and String(puff.name).begins_with("Puff"):
				(puff as MeshInstance3D).set_surface_override_material(0, mat)


func _process(delta: float) -> void:
	_tick_clouds(delta)


func _tick_clouds(delta: float) -> void:
	if _clouds.is_empty():
		return
	var fp := footprint()
	var half := fp.x * 0.5 + CLOUD_MARGIN
	var w := wind.normalized()
	var perp := Vector3(-w.z, 0.0, w.x)
	var t := Time.get_ticks_msec() * 0.001
	for cloud in _clouds:
		cloud.position += w * float(cloud.get_meta("speed", 0.5)) * delta
		if cloud.position.dot(w) > half:
			# 飘出航线就从另一头回来，换个侧向位置与高度。
			var side := _cloud_rng.randf_range(-1.0, 1.0) * (fp.y * 0.5 + 2.0)
			var base_y := _cloud_rng.randf_range(CLOUD_HEIGHT.x, CLOUD_HEIGHT.y)
			cloud.set_meta("base_y", base_y)
			cloud.position = w * (-half) + perp * side + Vector3(0.0, base_y, 0.0)
		cloud.position.y = float(cloud.get_meta("base_y", cloud.position.y)) + sin(t * 0.55 + float(cloud.get_meta("bob_phase", 0.0))) * 0.12
	_sync_cloud_shadows()


## 一朵云沿主光方向投到地面（y = 0）的落点（本地坐标）。
func _project_cloud_shadow(cloud: Node3D) -> Vector3:
	var dir := -direction(key_elevation_deg, camera_yaw_deg + key_azimuth_offset_deg)
	if absf(dir.y) < 0.08:
		dir.y = -0.08
	var origin := cloud.position
	return origin + dir * (-origin.y / dir.y)


func _sync_cloud_shadows() -> void:
	if _waters.is_empty():
		return
	var packed := PackedVector4Array()
	var count := 0
	for cloud in _clouds:
		if count >= CLOUD_MAX_SHADOWS:
			break
		var hit := _project_cloud_shadow(cloud)
		packed.append(Vector4(hit.x + global_position.x, hit.z + global_position.z, float(cloud.get_meta("radius", 0.9)), 0.22))
		count += 1
	while packed.size() < CLOUD_MAX_SHADOWS:
		packed.append(Vector4.ZERO)
	for entry in _waters:
		var mat := (entry["mesh"] as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("cloud_shadow_count", count)
			mat.set_shader_parameter("cloud_shadows", packed)


# --- 复原粒子 ---


## 生机版重搭的那一刻：台面上一圈光扩开，叶片花瓣与光点从整座岛上升起，鸟落下时锚点处再迸一下星屑。
func _spawn_restore_effects() -> void:
	var host := Node3D.new()
	host.name = "RestoreFx"
	add_child(host)
	var fp := footprint()
	var ring := MeshInstance3D.new()
	ring.name = "RestoreRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position = Vector3(0.0, table_y() + 0.06, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_mat.albedo_color = RESTORE_RING_COLOR
	ring.material_override = ring_mat
	host.add_child(ring)
	var reach := maxf(fp.x, fp.y) * 0.95
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(reach, 1.0, reach), 1.85).from(Vector3(2.0, 1.0, 2.0)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 1.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	host.add_child(_make_restore_burst("RestoreLeaves", fp, 110, 3.9, 1.0, 2.1, Vector3(0.0, -0.55, 0.0), 0.15, 0.28, true))
	host.add_child(_make_restore_burst("RestoreMotes", fp, 64, 4.4, 0.32, 0.7, Vector3.ZERO, 0.5, 1.0, false))
	var marker_pos := _marker.position if _marker != null else Vector3.ZERO
	get_tree().create_timer(1.95).timeout.connect(func() -> void:
		if is_instance_valid(host):
			host.add_child(_make_restore_sparkle(marker_pos + Vector3(0.0, 1.3, 0.0))))
	get_tree().create_timer(RESTORE_FX_LIFETIME).timeout.connect(func() -> void:
		if is_instance_valid(host):
			host.queue_free())


## 一次性的 CPU 粒子：leaves=true 是随风飘的叶片花瓣（方片、带颜色、慢慢落），否则是往上浮的暖光点。
func _make_restore_burst(node_name: String, fp: Vector2, amount: int, lifetime: float, v_min: float, v_max: float,
		gravity: Vector3, scale_min: float, scale_max: float, leaves: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	p.one_shot = true
	p.explosiveness = 0.2 if leaves else 0.1
	p.amount = amount
	p.lifetime = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(fp.x * 0.44, 0.35, fp.y * 0.44)
	p.position = Vector3(0.0, 0.7, 0.0)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 38.0 if leaves else 16.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = gravity
	p.angular_velocity_min = -95.0 if leaves else 0.0
	p.angular_velocity_max = 95.0 if leaves else 0.0
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.12, Color(1.0, 1.0, 1.0, 1.0))
	fade.add_point(0.7, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	p.color_ramp = fade
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if leaves:
		var tints := Gradient.new()
		tints.set_color(0, RESTORE_LEAF_COLORS[0])
		for i in range(1, RESTORE_LEAF_COLORS.size()):
			tints.add_point(float(i) / float(RESTORE_LEAF_COLORS.size() - 1), RESTORE_LEAF_COLORS[i])
		tints.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		p.color_initial_ramp = tints
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 0.7)
		quad.material = mat
		p.mesh = quad
	else:
		p.color = RESTORE_MOTE_COLOR
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var ball := SphereMesh.new()
		ball.radius = 0.09
		ball.height = 0.18
		ball.radial_segments = 8
		ball.rings = 4
		ball.material = mat
		p.mesh = ball
	p.emitting = true
	return p


## 鸟落回锚点那一刻的一小团星屑。
func _make_restore_sparkle(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "RestoreSparkle"
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 30
	p.lifetime = 1.25
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 180.0
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 2.9
	p.gravity = Vector3(0.0, -1.7, 0.0)
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.22
	p.color = Color(1.0, 0.95, 0.75, 1.0)
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	p.color_ramp = fade
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = mat
	p.mesh = quad
	p.emitting = true
	return p
