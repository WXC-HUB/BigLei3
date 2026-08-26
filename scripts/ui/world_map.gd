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

## 悬浮牌离地格顶面的高度（世界单位）。地格顶面在 y = 0，所以这就是牌子的挂高。
## 视角放平之后牌子会更贴近地格，所以比原来抬高一截。
const BADGE_LIFT := 2.1
## 相机俯角与视距区间。俯角固定，只有距离可调（滚轮）。
##
## 俯角越小越"平"：能看到地格的侧面厚度和建筑的正立面，立体书的感觉就出来了；
## 压到接近垂直则退化成一张平面图。参考图大约在 30° 上下。
const CAMERA_PITCH_DEG := -33.0
## 放平之后同样的视距能看到的地面变少（被透视压扁了），整体往回退一档。
const ZOOM_MIN := 13.0
const ZOOM_MAX := 52.0
const ZOOM_STEP := 3.5
## 按下到抬起的屏幕位移超过这个值就当拖拽，不算点关卡。
const DRAG_SLOP := 8.0
## 相机中心能漂出关卡分布范围多远。留一点余量，让边角的关卡也能被拖到屏幕中间。
const PAN_MARGIN := 10.0

const UI_LAYER := 60
const PAPER := Color(0.973, 0.961, 0.925)
const PAPER_EDGE := Color(0.784, 0.722, 0.604)
const INK := Color(0.184, 0.165, 0.125)
const INK_SOFT := Color(0.478, 0.427, 0.349)

var _cleared: Array = []
var _resume_stage_id := ""
var _resume_round := 0

var _camera: Camera3D
var _markers: Array[Node3D] = []
var _badges: Dictionary = {}          # stage_id -> StageBadge
var _pivot := Vector3.ZERO
var _distance := 24.0
var _pan_min := Vector2.ZERO
var _pan_max := Vector2.ZERO

var _dragging := false
var _drag_travel := 0.0
var _last_mouse := Vector2.ZERO

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


func _ready() -> void:
	_camera = get_node_or_null("MapCamera") as Camera3D
	if _camera == null:
		push_warning("WorldMap: 缺少 MapCamera 节点，相机控制不可用")
	_collect_markers()
	_compute_pan_bounds()
	_apply_toon_materials()
	_build_ui()
	set_process(true)


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
	for root_name in ["HexTerrain", "StageMarkers"]:
		var host := get_node_or_null(root_name)
		if host != null:
			_toon_ify(host, shader, cache)


func _toon_ify(node: Node, shader: Shader, cache: Dictionary) -> void:
	var mesh_node := node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		for surface in mesh_node.mesh.get_surface_count():
			var source := mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D
			var texture: Texture2D = source.albedo_texture if source != null else null
			var key := texture.resource_path if texture != null else "__flat__"
			if not cache.has(key):
				var material := ShaderMaterial.new()
				material.shader = shader
				material.set_shader_parameter("albedo_tex", texture)
				# 没有贴图的表面（极少数装饰）走纯色，别让 shader 采样到空纹理变全黑。
				if texture == null and source != null:
					material.set_shader_parameter("tint", source.albedo_color)
				cache[key] = material
			mesh_node.set_surface_override_material(surface, cache[key])
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


## 相机中心的可漂范围由关卡分布决定，而不是由地格分布——地格铺得比关卡宽，按地格算
## 会让玩家能把镜头拖到一片空草地上。
func _compute_pan_bounds() -> void:
	if _markers.is_empty():
		_pan_min = Vector2(-PAN_MARGIN, -PAN_MARGIN)
		_pan_max = Vector2(PAN_MARGIN, PAN_MARGIN)
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for marker in _markers:
		var p := marker.global_position
		lo.x = minf(lo.x, p.x)
		lo.y = minf(lo.y, p.z)
		hi.x = maxf(hi.x, p.x)
		hi.y = maxf(hi.y, p.z)
	_pan_min = lo - Vector2(PAN_MARGIN, PAN_MARGIN)
	_pan_max = hi + Vector2(PAN_MARGIN, PAN_MARGIN)


# --- 对外接口 ---


## 亮出地图。`cleared` 是已通关关卡 id 列表，`resume_stage_id` / `resume_round` 是
## 唯一那个续局槽（无续局传空串与 0）。
func present(cleared: Array, resume_stage_id: String, resume_round: int) -> void:
	_cleared = cleared.duplicate()
	_resume_stage_id = resume_stage_id
	_resume_round = resume_round
	visible = true
	if _ui != null:
		_ui.visible = true
	_rebuild_badges()
	_refresh_resume_banner()
	_close_confirm(true)
	_focus_on(_focus_stage_id())
	_refresh_region_readout()


func dismiss() -> void:
	visible = false
	if _ui != null:
		_ui.visible = false
	_dragging = false


## 初次显示时镜头对准的关卡：优先续局中的那一关，否则第一个还没通关的已解锁关卡。
func _focus_stage_id() -> String:
	if _resume_stage_id != "" and StageTable.has_stage(_resume_stage_id):
		return _resume_stage_id
	return StageTable.first_open_stage(_cleared)


func _focus_on(stage_id: String) -> void:
	for marker in _markers:
		if String(marker.get_meta("stage_id", "")) == stage_id:
			_pivot = Vector3(marker.global_position.x, 0.0, marker.global_position.z)
			break
	_clamp_pivot()
	_apply_camera()


# --- 相机 ---


func _apply_camera() -> void:
	if _camera == null:
		return
	var pitch := deg_to_rad(CAMERA_PITCH_DEG)
	# 相机沿 -Z 看向 pivot：抬到 pivot 上方 sin 分量、退到后方 cos 分量。
	_camera.position = _pivot + Vector3(0.0, -sin(pitch) * _distance, cos(pitch) * _distance)
	_camera.rotation = Vector3(pitch, 0.0, 0.0)


func _clamp_pivot() -> void:
	_pivot.x = clampf(_pivot.x, _pan_min.x, _pan_max.x)
	_pivot.z = clampf(_pivot.z, _pan_min.y, _pan_max.y)
	_pivot.y = 0.0


## 拖拽与滚轮都走 `_input`——它比 GUI 先拿到事件，所以即使起手按在某张悬浮牌上，
## 平移照样成立。这里**不**吞掉左键事件，否则悬浮牌就收不到点击了；"这一下到底是拖
## 还是点"由 `_drag_travel` 在牌子的 pressed 回调里裁决（见 `_on_badge_pressed`）。
func _input(event: InputEvent) -> void:
	if not visible or _camera == null:
		return
	if _confirm != null and _confirm.visible:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_dragging = true
				_drag_travel = 0.0
				_last_mouse = button.position
			else:
				_dragging = false
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(-ZOOM_STEP)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(ZOOM_STEP)
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_drag_travel += motion.relative.length()
		_pan_by(motion.relative)


func _zoom_by(delta: float) -> void:
	_distance = clampf(_distance + delta, ZOOM_MIN, ZOOM_MAX)
	_apply_camera()


## 屏幕位移换成地面位移。比例跟着视距走，否则拉远之后拖一下只挪一点点，手感发黏。
func _pan_by(screen_delta: Vector2) -> void:
	var viewport_height := float(get_viewport().get_visible_rect().size.y)
	if viewport_height <= 0.0:
		return
	var world_per_pixel := 2.0 * _distance * tan(deg_to_rad(_camera.fov) * 0.5) / viewport_height
	_pivot.x -= screen_delta.x * world_per_pixel
	# 屏幕往下拖 = 镜头往近处走。俯角固定，所以 Z 方向的换算要除掉俯角的余弦压缩。
	_pivot.z -= screen_delta.y * world_per_pixel / maxf(cos(deg_to_rad(CAMERA_PITCH_DEG)), 0.2)
	_clamp_pivot()
	_apply_camera()
	_refresh_region_readout()


# --- 悬浮牌 ---


func _rebuild_badges() -> void:
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
		badge.set_stage_state(_state_for(stage_id))
		badge.pressed.connect(_on_badge_pressed.bind(stage_id))
		_badges[stage_id] = badge


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
	var to_canvas := _badge_layer.get_canvas_transform().affine_inverse()
	var canvas_rect := Rect2(Vector2.ZERO, _badge_layer.size)
	for marker in _markers:
		var stage_id := String(marker.get_meta("stage_id", ""))
		var badge: StageBadge = _badges.get(stage_id)
		if badge == null:
			continue
		var anchor := marker.global_position + Vector3(0.0, BADGE_LIFT, 0.0)
		if _camera.is_position_behind(anchor):
			badge.visible = false
			continue
		var where := to_canvas * _camera.unproject_position(anchor)
		badge.position = where - Vector2(badge.size.x * 0.5, badge.size.y) \
			+ Vector2(0.0, badge.hover_lift())
		# 屏幕外的牌子藏起来：既省掉十几个 Control 的绘制，也让画面只剩镜头附近那一撮，
		# 不至于二十张牌子糊成一团。
		badge.visible = canvas_rect.intersects(Rect2(badge.position, badge.size))


func _on_badge_pressed(stage_id: String) -> void:
	# 从牌子上起手把地图拖走的那一下，不该顺带进关。
	if _drag_travel > DRAG_SLOP:
		return
	if not StageTable.is_stage_unlocked(stage_id, _cleared):
		return
	# 单槽续局：想进别的关，先确认放弃手上那一关（共识 6）。
	if _resume_stage_id != "" and stage_id != _resume_stage_id:
		_open_confirm(stage_id)
		return
	stage_selected.emit(stage_id)


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
	_badge_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui.add_child(_badge_layer)

	_build_top_bar()
	_build_resume_banner()
	_build_confirm()


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


## 当前地形区 = 离镜头中心最近的那个关卡所属的区。比"最后点过的区"稳：玩家拖到哪里，
## 顶栏就说哪里。
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
