class_name StageCabinet
extends Node3D
## 陈列柜选关：各关展品（第 1～6 关加第 7 关无尽）沿画面横向排成一列摆在同一张波点桌布上，一次只看一件——
## 屏幕两侧的 ‹ › 箭头（或键盘 ←/→）把相机滑到相邻那件：切走的展品按原路收回台面，
## 滑进来的展品重新「搭」一遍（StageDiorama 的入场动画）。点展品本体或关卡卡上的
## 「进入关卡」进关。
##
## 对主场景的接口与老的 WorldMap 完全一致：同一组信号、present()/dismiss()、续局单槽与放弃确认、
## 右键看榜、顶栏（返回标题 / 地形区读数 / 全部排行榜 / 局外成长占位）。悬浮牌沿用 StageBadge。
## 还没做出真展品的关卡用灰泥胚占位（StageDiorama.paths_for），未解锁的关卡整件退成泥胚色。
##
## 和老地图一样用 `_input` 而不是 `_unhandled_input`：主场景里有全屏 Control 会把点击吃掉。

signal stage_selected(stage_id: String)
signal title_requested
signal resume_requested
signal abandon_requested
signal leaderboard_requested(stage_id: String)
signal all_leaderboards_requested
signal easter_egg_triggered(achievement_id: String)

const Catalog := preload("res://scripts/game/achievement_catalog.gd")

## 彩蛋各归各关：蚊子只在第 1 关的展品上飞，游荡动物只在第 2 关的地面上晃。
const MOSQUITO_STAGE := "grass_1"
const WANDER_STAGE := "grass_2"

const UI_LAYER := 60
const BADGE_LIFT := 1.6
## 相邻两件展品的间距（沿画面横向，世界单位）：比一屏宽，停下时邻件完全在画外。
const SLOT_STEP := 60.0
const TABLE_Y := -2.1
const TABLE_SIZE := 460.0
const CAMERA_PITCH_DEG := -37.0
const CAMERA_YAW_DEG := 31.0
## 滑到相邻展品的时长；滑到一半多一点时新展品开始搭。
const SLIDE_DURATION := 0.72
## 刚通关的关复原（荒废 → 生机）播完后，停一下再自动滑到下一关。
const ADVANCE_DELAY := 1.7
## 复原仪式的文字反馈：标题卡 + 三行分阶段的短句（地面回绿 → 屋舍器物 → 鸟兽归来），按关卡定制。
const RESTORE_LINES := {
	"grass_1": ["草坡返青", "果树重新挂果", "鸽群归来"],
	"grass_2": ["麦浪再起", "风车重新转动", "谷仓门修好了"],
	"grass_3": ["古树重新抽叶", "井水复清", "红绸再挂上枝头"],
	"river_1": ["清流回潭", "水车再转", "锦鲤回来了"],
	"river_2": ["瀑布复流", "松林返青", "潭水又深了"],
	"coast_1": ["灯塔重亮", "船队归港", "海鸟归来"],
}
const RESTORE_LINES_DEFAULT := ["草木返青", "屋舍修好", "鸟群归来"]
## 三行短句出现的时刻（从复原开始算）：地形升起后、屋舍树木弹出时、鸟落下来时。
const RESTORE_LINE_TIMES := [1.05, 1.85, 2.65]
## 最后一句冒出来之后，标题卡再留这么久才淡出；这段时间里柜子仍然不接受操作。
const RESTORE_TAIL := 1.15
const SLIDE_ENTRANCE_AT := 0.55
const EXIT_DURATION := 0.45

const PAPER := StageBadge.PAPER
const PAPER_EDGE := StageBadge.PAPER_EDGE
const INK := StageBadge.INK
const INK_SOFT := StageBadge.INK_SOFT
const INK_FAINT := Color(0.62, 0.58, 0.51)
const CARD_SHADOW := StageBadge.CARD_SHADOW
const ACCENT := Color(0.87, 0.60, 0.18)

## 测试与截图可关掉蚊子和自动入场。
var mosquito_events := true
var entrance_events := true

var _cleared: Array = []
var _resume_stage_id := ""
var _resume_round := 0
var _high_scores: Dictionary = {}
## 无尽关最远盘数（stage_id → 盘数），只有无尽关会有条目。
var _best_rounds: Dictionary = {}
var _current_region_id := ""

var _slots: Array[StageDiorama] = []
var _slot_by_id: Dictionary = {}
var _badges: Dictionary = {}
var _camera: Camera3D
var _current := 0
var _camera_tween: Tween
var _entrance_timer: SceneTreeTimer
var _cam_target := Vector3.ZERO
var _cam_size := 23.0
var _pending_stage_id := ""
var _presented := false
## 上一次停在哪件展品：放弃进度、倒下回柜子这类「原地刷新」都停回这里，
## 不再按进度跳到第一个可挑战的关（全通关后那是无尽关，等于每次都被弹到第 7 关）。
var _last_focus_id := ""
var _restoring_id := ""
## 排行榜还挡在前面时，刚通关的关先停在它身上保持荒废版，榜一关就播复原。
var _pending_restore_id := ""
var _restore_title: Panel
var _restore_title_label: Label
var _restore_sub_label: Label
var _restore_lines_host: Control
var _restore_tween: Tween
## 每次仪式一个号：短句按号认领，仪式结束后迟到的短句不会再弹出来。
var _ceremony_token := 0
## 共用的台面与背景：切到哪件展品就慢慢换成它的桌布配色。
var _env_holder: WorldEnvironment
var _table_mat: ShaderMaterial
var _table_tween: Tween
var _table_palette: Dictionary = {}

var _ui: CanvasLayer
var _badge_layer: Control
var _mosquito: MapMosquito
var _wanderer: MapWanderAnimal
var _region_name_label: Label
var _region_progress_label: Label
var _prev_button: Button
var _next_button: Button
var _stage_card: Panel
var _stage_card_title: Label
var _stage_card_detail: Label
var _stage_card_enter: Button
var _stage_card_abandon: Button
var _resume_banner: Control
var _resume_text: Label
var _confirm: Control
var _confirm_dim: ColorRect
var _confirm_card: Panel
var _confirm_text: Label


func _ready() -> void:
	_env_holder = StageDiorama.build_environment(0.22)
	add_child(_env_holder)
	for light in StageDiorama.build_lights(CAMERA_YAW_DEG, 0.25, 54.0, 232.0, 0.60, 12.0, 15.0, 0.82):
		add_child(light)
	var table := StageDiorama.build_table(TABLE_Y, TABLE_SIZE)
	_table_mat = table.material_override as ShaderMaterial
	add_child(table)
	_build_slots()
	_build_camera()
	_build_ui()
	set_process(true)


# --- 对外（与 WorldMap 相同） ---


func present(cleared: Array, resume_stage_id: String, resume_round: int, high_scores: Dictionary = {}, best_rounds: Dictionary = {}) -> void:
	var was_hidden := not visible
	# 这次回来新通关的关：荒废版收回、生机版重搭（复原），之后再自动滑到下一关。
	var newly: Array = []
	if _presented:
		for id in cleared:
			if not _cleared.has(id) and _slot_by_id.has(String(id)):
				newly.append(String(id))
	_cleared = cleared.duplicate()
	_resume_stage_id = resume_stage_id
	_resume_round = resume_round
	_high_scores = high_scores.duplicate()
	_best_rounds = best_rounds.duplicate()
	visible = true
	if _ui != null:
		_ui.visible = true
	if _camera != null:
		_camera.make_current()
	_close_confirm(true)
	_rebuild_badges()
	_apply_slot_looks()
	# 复原仪式：这次回来新通关的关（或上次还没来得及播的）先停在它身上、保持荒废版；
	# 排行榜等 modal 还挡在前面时不播，等它关掉再播（见 _process）。
	var restore_id := ""
	var held := _pending_restore_id if _pending_restore_id != "" else _restoring_id
	if held != "" and _cleared.has(held):
		restore_id = held
	elif not newly.is_empty() and entrance_events:
		restore_id = String(newly[0])
	for slot in _slots:
		if slot.stage_id != restore_id:
			slot.set_withered(not _cleared.has(slot.stage_id), false)
	if restore_id != "":
		if _restoring_id != restore_id:
			_pending_restore_id = restore_id
		_go_to(_index_of(restore_id), true)
		if _restoring_id == "":
			for slot in _slots:
				slot.skip_entrance()
	else:
		_go_to(_start_index(), true)
		if (was_hidden or not _presented) and entrance_events:
			for slot in _slots:
				slot.skip_entrance()
			_slots[_current].play_entrance()
	_presented = true
	_sync_easter_eggs()


func dismiss() -> void:
	_kill_camera_tween()
	_cancel_pending_entrance()
	_pending_restore_id = ""
	_restoring_id = ""
	_ceremony_token += 1
	_hide_restore_title(true)
	for slot in _slots:
		slot.skip_entrance()
	_close_confirm(true)
	if _mosquito != null:
		_mosquito.stop()
	if _wanderer != null:
		_wanderer.stop()
	visible = false
	if _ui != null:
		_ui.visible = false


## 测试与截图用的探针。
func slots() -> Array[StageDiorama]:
	return _slots


func slot_for(stage_id: String) -> StageDiorama:
	return _slot_by_id.get(stage_id)


func badge_for(stage_id: String) -> StageBadge:
	return _badges.get(stage_id)


func mosquito() -> MapMosquito:
	return _mosquito


func wander_animal() -> MapWanderAnimal:
	return _wanderer


func slot_count() -> int:
	return _slots.size()


## 正在复原的关（没有则空串）。
func restoring_stage() -> String:
	return _restoring_id


## 等着复原的关（排行榜还开着时；没有则空串）。
func pending_restore_stage() -> String:
	return _pending_restore_id


## 复原仪式进行中或等着开始：这段时间柜子不接受进关与切换。
func _ceremony_active() -> bool:
	return _restoring_id != "" or _pending_restore_id != ""


func camera() -> Camera3D:
	return _camera


func current_index() -> int:
	return _current


func current_stage() -> String:
	return _slots[_current].stage_id if _current >= 0 and _current < _slots.size() else ""


func is_transitioning() -> bool:
	return _camera_tween != null and _camera_tween.is_valid() and _camera_tween.is_running()


func stage_card() -> Control:
	return _stage_card


func prev_button() -> Button:
	return _prev_button


func next_button() -> Button:
	return _next_button


## 模拟按右箭头 / 左箭头。
func press_next() -> void:
	_step(1)


func press_prev() -> void:
	_step(-1)


## 模拟点当前这件展品的本体（= 进入）。
func press_slot(stage_id: String) -> void:
	_on_slot_pressed(stage_id)


## 模拟关卡卡上的主按钮（进入关卡 / 续上这一关 / 再打一遍）。
func press_enter() -> void:
	_on_enter_pressed()


# --- 柜子 ---


## 画面横向在世界里的方向（相机方位固定）。
static func _screen_right() -> Vector3:
	var yaw := deg_to_rad(CAMERA_YAW_DEG)
	return Vector3(cos(yaw), 0.0, -sin(yaw))


## 全部展品按关卡表顺序沿画面横向排成一列（第 7 关无尽在最右），每件自身不转，光影与单独展示时完全一样。
func _build_slots() -> void:
	var holder := Node3D.new()
	holder.name = "Slots"
	add_child(holder)
	var stages := StageTable.all_stages()
	for index in stages.size():
		var stage: Dictionary = stages[index]
		var stage_id := String(stage["id"])
		# 没通关的关先摆荒废版；present 再按通关记录换成生机版。
		var paths := StageDiorama.paths_for(stage_id, true)
		var slot := StageDiorama.new()
		slot.name = "Slot_%s" % stage_id
		slot.stage_id = stage_id
		slot.withered = true
		slot.model_path = String(paths["model"])
		slot.layout_path = String(paths["layout"])
		slot.standalone = false
		slot.entrance_on_ready = false
		slot.wind = _screen_right()
		slot.variant_changed.connect(_on_slot_variant_changed.bind(slot))
		slot.position = _screen_right() * (index - (stages.size() - 1) * 0.5) * SLOT_STEP
		holder.add_child(slot)
		_slots.append(slot)
		_slot_by_id[stage_id] = slot


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "CabinetCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 0.5
	_camera.far = 600.0
	add_child(_camera)
	if not _slots.is_empty():
		_cam_target = _slots[0].focus_target()
		_cam_size = _slots[0].camera_size
	_apply_camera()


func _apply_camera() -> void:
	if _camera == null:
		return
	var from := StageDiorama.direction(-CAMERA_PITCH_DEG, CAMERA_YAW_DEG)
	_camera.look_at_from_position(_cam_target + from * 200.0, _cam_target, Vector3.UP)
	_camera.size = _cam_size


func _fly_camera(target: Vector3, size: float, immediate: bool) -> void:
	_kill_camera_tween()
	if immediate:
		_cam_target = target
		_cam_size = size
		_apply_camera()
		return
	_camera_tween = create_tween().set_parallel(true)
	_camera_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_method(func(v: Vector3) -> void:
		_cam_target = v
		_apply_camera(), _cam_target, target, SLIDE_DURATION)
	_camera_tween.tween_method(func(v: float) -> void:
		_cam_size = v
		_apply_camera(), _cam_size, size, SLIDE_DURATION)


func _kill_camera_tween() -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null


func _cancel_pending_entrance() -> void:
	if _entrance_timer != null and _entrance_timer.time_left > 0.0:
		for connection in _entrance_timer.timeout.get_connections():
			_entrance_timer.timeout.disconnect(connection["callable"])
	_entrance_timer = null


# --- 切换 ---


func _index_of(stage_id: String) -> int:
	for index in _slots.size():
		if _slots[index].stage_id == stage_id:
			return index
	return 0


## 复原仪式：荒废版按原路收回，生机版带着粒子重搭（展品自己放粒子），标题卡与三行短句
## 分阶段弹出；播完停一下，再自动滑到下一关（如果有且已解锁）。
func _restore_stage(stage_id: String) -> void:
	var slot := slot_for(stage_id)
	if slot == null:
		return
	_restoring_id = stage_id
	_ceremony_token += 1
	var token := _ceremony_token
	_show_restore_title(stage_id)
	slot.set_withered(false, true)
	var lines: Array = RESTORE_LINES.get(stage_id, RESTORE_LINES_DEFAULT)
	var started := Time.get_ticks_msec()
	for i in lines.size():
		get_tree().create_timer(float(RESTORE_LINE_TIMES[i])).timeout.connect(_pop_restore_line.bind(String(lines[i]), i, token))
	while slot.is_restoring() or slot.is_entrance_playing():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	# 模型搭完了，但最后一句往往还没冒出来：把标题卡留到它说完，整段仪式读起来才是一拍。
	var tail := float(RESTORE_LINE_TIMES[lines.size() - 1]) + RESTORE_TAIL - (Time.get_ticks_msec() - started) / 1000.0
	if tail > 0.0:
		await get_tree().create_timer(tail).timeout
	if not is_inside_tree() or _ceremony_token != token:
		return
	_restoring_id = ""
	_hide_restore_title(false)
	if not visible or _slots[_current] != slot:
		return
	await get_tree().create_timer(ADVANCE_DELAY).timeout
	if not visible or _slots[_current] != slot or is_transitioning() or _is_modal_overlay_visible():
		return
	var next := _current + 1
	if next < _slots.size():
		var next_id := _slots[next].stage_id
		if StageTable.is_stage_unlocked(next_id, _cleared) and not _cleared.has(next_id):
			_go_to(next, false)


## 展品换了版（复原完成）：桌布配色与关卡卡跟着刷新。
func _on_slot_variant_changed(slot: StageDiorama) -> void:
	if not _slots.is_empty() and _slots[_current] == slot:
		_blend_table(slot.table_palette(), false)
		_update_stage_card()


## 一进来停在哪件：有续局停续局那关；否则停回上次看的那件（还开着的话），
## 让「放弃进度」「倒下回柜子」都留在原地；再没有才停第一个能打的关；都没有就停最后一关。
func _start_index() -> int:
	var target := _resume_stage_id
	if target == "":
		target = _last_focus_id if _is_focus_reusable(_last_focus_id) else StageTable.first_open_stage(_cleared)
	for index in _slots.size():
		if _slots[index].stage_id == target:
			return index
	return maxi(_slots.size() - 1, 0)


## 上次停的那件还能不能停：关卡还在、而且按现在的通关进度是解锁的。
func _is_focus_reusable(stage_id: String) -> bool:
	if stage_id == "" or not _slot_by_id.has(stage_id):
		return false
	return StageTable.is_stage_unlocked(stage_id, _cleared)


func _step(delta: int) -> void:
	if _is_modal_overlay_visible() or (_confirm != null and _confirm.visible):
		return
	var next := _current + delta
	if next < 0 or next >= _slots.size() or is_transitioning() or _ceremony_active():
		return
	_go_to(next, false)


## 切到第 index 件：相机沿画面横向滑过去，切走的展品收回台面，滑进来的展品在半路重新搭。
func _go_to(index: int, immediate: bool) -> void:
	index = clampi(index, 0, _slots.size() - 1)
	var leaving := _slots[_current] if _current != index else null
	_current = index
	var slot := _slots[index]
	_last_focus_id = slot.stage_id
	_cancel_pending_entrance()
	if immediate:
		_fly_camera(slot.focus_target(), slot.camera_size, true)
	else:
		if leaving != null and entrance_events:
			leaving.play_exit(EXIT_DURATION)
		if entrance_events:
			slot.build_progress = 0.0
			slot.set_water_level(0.0)
			slot.set_shadow_alpha(0.0)
		_fly_camera(slot.focus_target(), slot.camera_size, false)
		if entrance_events:
			_entrance_timer = get_tree().create_timer(SLIDE_DURATION * SLIDE_ENTRANCE_AT)
			_entrance_timer.timeout.connect(func() -> void:
				if visible and _slots[_current] == slot:
					slot.play_entrance())
	_blend_table(slot.table_palette(), immediate)
	_sync_easter_eggs()
	_update_stage_card()
	_refresh_arrows()
	_refresh_region_readout()


## 台面与背景色跟着当前展品走：切换时和相机同步渐变，present 时直接到位。
func _blend_table(target: Dictionary, immediate: bool) -> void:
	if _table_tween != null and _table_tween.is_valid():
		_table_tween.kill()
	_table_tween = null
	if _table_palette.is_empty() or immediate:
		_table_palette = target
		_apply_table_palette(target)
		return
	var from := _table_palette
	_table_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_table_tween.tween_method(func(t: float) -> void:
		_table_palette = StageDiorama.lerp_table_palette(from, target, t)
		_apply_table_palette(_table_palette), 0.0, 1.0, SLIDE_DURATION)


func _apply_table_palette(palette: Dictionary) -> void:
	StageDiorama.apply_table_palette(_table_mat, palette)
	if _env_holder != null and _env_holder.environment != null:
		_env_holder.environment.background_color = palette["far"]


## 测试用：当前台面配色。
func table_palette() -> Dictionary:
	return _table_palette


# --- 状态 ---


func _state_for(stage_id: String) -> int:
	if _cleared.has(stage_id):
		return StageBadge.State.CLEARED
	if not StageTable.is_stage_unlocked(stage_id, _cleared):
		return StageBadge.State.LOCKED
	if stage_id == _resume_stage_id:
		return StageBadge.State.IN_PROGRESS
	return StageBadge.State.AVAILABLE


func _apply_slot_looks() -> void:
	for slot in _slots:
		slot.set_locked_look(_state_for(slot.stage_id) == StageBadge.State.LOCKED)


func _rebuild_badges() -> void:
	for badge in _badges.values():
		badge.queue_free()
	_badges.clear()
	for slot in _slots:
		var stage := StageTable.stage(slot.stage_id)
		if stage.is_empty():
			continue
		var badge := StageBadge.new()
		_badge_layer.add_child(badge)
		badge.bind(stage)
		badge.set_high_score(int(_high_scores.get(slot.stage_id, 0)))
		badge.set_best_round(int(_best_rounds.get(slot.stage_id, 0)))
		badge.set_stage_state(_state_for(slot.stage_id))
		badge.pressed.connect(_on_slot_pressed.bind(slot.stage_id))
		badge.leaderboard_requested.connect(func(id: String) -> void: leaderboard_requested.emit(id))
		_badges[slot.stage_id] = badge


# --- 交互 ---


## 点当前这件展品（本体或牌子）= 进入；不是当前那件（滑动中露出的邻件）则切过去。
## 当前停在哪一关，就只开哪一关的彩蛋；`mosquito_events` 是这两个彩蛋共用的总开关
## （测试和截图靠它把画面清静下来）。
func _sync_easter_eggs() -> void:
	var stage := current_stage()
	var on := visible and mosquito_events
	if _mosquito != null:
		if on and stage == MOSQUITO_STAGE:
			_mosquito.start()
		else:
			_mosquito.stop()
	if _wanderer != null:
		if on and stage == WANDER_STAGE:
			# 舞台是展品本身：动物在岛的格子里走，每帧自己投影，相机滑动也跟得住。
			_wanderer.set_ground_source(_slots[_current] if _current < _slots.size() else null, _camera)
			_wanderer.start()
		else:
			_wanderer.stop()


## 薅到一撮毛：四种都薅过就给成就。
func _on_animal_plucked(_key: String, _where: Vector2) -> void:
	if _wanderer != null and _wanderer.is_complete():
		easter_egg_triggered.emit(Catalog.MAP_FUR_HARVEST)


## 拍满第三只：给成就；蚊子那边自己退场，这一轮关卡选择里不会再飞回来。
func _on_mosquito_swatted(_where: Vector2) -> void:
	if _mosquito != null and _mosquito.swat_count() == MapMosquito.SWAT_LIMIT:
		easter_egg_triggered.emit(Catalog.MAP_MOSQUITO_TRIO)


func _on_slot_pressed(stage_id: String) -> void:
	if _is_modal_overlay_visible() or is_transitioning() or _ceremony_active():
		return
	if stage_id != current_stage():
		var slot := slot_for(stage_id)
		if slot != null:
			_go_to(_slots.find(slot), false)
		return
	_on_enter_pressed()


func _on_enter_pressed() -> void:
	if is_transitioning() or _is_modal_overlay_visible() or _ceremony_active():
		return
	var stage_id := current_stage()
	if stage_id == "":
		return
	if stage_id == _resume_stage_id and _resume_stage_id != "":
		resume_requested.emit()
		return
	_request_enter(stage_id)


## 单槽续局：想进别的关，先确认放弃手上那一关。
func _request_enter(stage_id: String) -> void:
	if not StageTable.is_stage_unlocked(stage_id, _cleared):
		return
	if _resume_stage_id != "" and stage_id != _resume_stage_id:
		_open_confirm(stage_id)
		return
	stage_selected.emit(stage_id)


func _input(event: InputEvent) -> void:
	if not visible or _camera == null:
		return
	if _confirm != null and _confirm.visible:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_LEFT or key.keycode == KEY_A:
			_step(-1)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_RIGHT or key.keycode == KEY_D:
			_step(1)
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if not button.pressed:
		return
	if button.button_index != MOUSE_BUTTON_LEFT and button.button_index != MOUSE_BUTTON_RIGHT:
		return
	if _is_modal_overlay_visible() or is_transitioning() or _ceremony_active():
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if _find_stage_badge(hovered) != null or _is_cabinet_chrome(hovered) or _is_overlay_above(hovered):
		return
	var stage_id := _slot_at(button.position)
	if stage_id == "":
		return
	if button.button_index == MOUSE_BUTTON_RIGHT:
		leaderboard_requested.emit(stage_id)
	else:
		_on_slot_pressed(stage_id)
	get_viewport().set_input_as_handled()


## 鼠标射线打拾取体，回该件展品的 stage_id；打空返回空串。
func _slot_at(screen_pos: Vector2) -> String:
	if _camera == null or get_world_3d() == null:
		return ""
	var from := _camera.project_ray_origin(screen_pos)
	var to := from + _camera.project_ray_normal(screen_pos) * 600.0
	var query := PhysicsRayQueryParameters3D.create(from, to, StageDiorama.PICK_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return ""
	var collider: Object = hit.get("collider")
	if collider is Node and (collider as Node).has_meta("stage_id"):
		return String((collider as Node).get_meta("stage_id"))
	return ""


func _process(_delta: float) -> void:
	if not visible or _camera == null:
		return
	if _pending_restore_id != "" and not is_transitioning() and not _is_modal_overlay_visible():
		var id := _pending_restore_id
		_pending_restore_id = ""
		_restore_stage(id)
	_place_badges()


## 悬浮牌钉在每件展品锚点的上方；不在画面里的牌子自然收掉。
func _place_badges() -> void:
	var canvas_rect := Rect2(Vector2.ZERO, _badge_layer.size)
	for slot in _slots:
		var badge: StageBadge = _badges.get(slot.stage_id)
		if badge == null:
			continue
		var anchor := slot.marker().global_position + Vector3.UP * BADGE_LIFT
		if _camera.is_position_behind(anchor):
			badge.visible = false
			continue
		var where := _unproject_to_badge_layer(anchor)
		badge.position = where - Vector2(badge.size.x * 0.5, badge.size.y)
		badge.visible = canvas_rect.grow(48.0).intersects(Rect2(badge.position, badge.size))


func _unproject_to_badge_layer(world: Vector3) -> Vector2:
	var screen := _camera.unproject_position(world)
	var vp := get_viewport().get_visible_rect().size
	var layer := _badge_layer.size
	if vp.x < 1.0 or vp.y < 1.0 or layer.x < 1.0 or layer.y < 1.0:
		return screen
	return Vector2(screen.x * layer.x / vp.x, screen.y * layer.y / vp.y)


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


func _is_overlay_above(ctrl: Control) -> bool:
	var walk: Node = ctrl
	while walk != null:
		if walk is CanvasLayer:
			return (walk as CanvasLayer).layer > UI_LAYER
		walk = walk.get_parent()
	return false


## 顶栏、箭头、关卡卡、确认卡：它们自己处理点击，柜子不抢。
func _is_cabinet_chrome(ctrl: Control) -> bool:
	if ctrl == null or _ui == null:
		return false
	var walk: Node = ctrl
	while walk != null:
		if walk == _ui:
			return false
		var n := String(walk.name)
		if n == "TopBar" or n == "AbandonConfirm" or n == "StageCard" or n == "PrevButton" or n == "NextButton":
			return true
		walk = walk.get_parent()
	return false


# --- UI ---


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "CabinetUi"
	_ui.layer = UI_LAYER
	add_child(_ui)

	_badge_layer = Control.new()
	_badge_layer.name = "BadgeLayer"
	_badge_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_badge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_badge_layer)

	_mosquito = MapMosquito.new()
	_mosquito.name = "Mosquito"
	_mosquito.swatted.connect(_on_mosquito_swatted)
	_ui.add_child(_mosquito)

	_wanderer = MapWanderAnimal.new()
	_wanderer.name = "WanderAnimal"
	_wanderer.plucked.connect(_on_animal_plucked)
	_ui.add_child(_wanderer)

	_build_top_bar()
	_build_arrows()
	_build_stage_card()
	_build_confirm()
	_build_restore_text()


func _build_top_bar() -> void:
	var bar := Control.new()
	bar.name = "TopBar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 104.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(bar)

	var back := _make_button("BackToTitleButton", "‹  返回标题", Vector2(176.0, 52.0))
	back.position = Vector2(32.0, 26.0)
	back.pressed.connect(func() -> void: title_requested.emit())
	bar.add_child(back)

	var region_card := Panel.new()
	region_card.name = "RegionCard"
	region_card.position = Vector2(224.0, 18.0)
	region_card.size = Vector2(400.0, 68.0)
	region_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	region_card.add_theme_stylebox_override("panel", _card_style(14))
	bar.add_child(region_card)

	_region_name_label = Label.new()
	_region_name_label.name = "RegionNameLabel"
	_region_name_label.position = region_card.position + Vector2(22.0, 6.0)
	_region_name_label.size = Vector2(360.0, 32.0)
	_region_name_label.add_theme_font_size_override("font_size", 25)
	_region_name_label.add_theme_color_override("font_color", INK)
	bar.add_child(_region_name_label)

	_region_progress_label = Label.new()
	_region_progress_label.name = "RegionProgressLabel"
	_region_progress_label.position = region_card.position + Vector2(22.0, 38.0)
	_region_progress_label.size = Vector2(360.0, 24.0)
	_region_progress_label.add_theme_font_size_override("font_size", 16)
	_region_progress_label.add_theme_color_override("font_color", INK_SOFT)
	bar.add_child(_region_progress_label)

	var boards := _make_button("AllLeaderboardsButton", "全部排行榜", Vector2(168.0, 52.0))
	boards.anchor_left = 1.0
	boards.anchor_right = 1.0
	boards.offset_left = -520.0
	boards.offset_right = -352.0
	boards.offset_top = 26.0
	boards.offset_bottom = 78.0
	boards.pressed.connect(func() -> void: all_leaderboards_requested.emit())
	bar.add_child(boards)

	# 局外持久数值位：只占位不填数，空心细框就是"这里以后有东西"。
	var meta_box := Panel.new()
	meta_box.name = "MetaCurrencyBox"
	meta_box.anchor_left = 1.0
	meta_box.anchor_right = 1.0
	meta_box.offset_left = -332.0
	meta_box.offset_right = -32.0
	meta_box.offset_top = 26.0
	meta_box.offset_bottom = 78.0
	meta_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var meta_style := StyleBoxFlat.new()
	meta_style.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.55)
	meta_style.border_color = PAPER_EDGE
	meta_style.set_border_width_all(2)
	meta_style.set_corner_radius_all(14)
	meta_box.add_theme_stylebox_override("panel", meta_style)
	bar.add_child(meta_box)

	var meta_value := Label.new()
	meta_value.name = "MetaValueLabel"
	meta_value.text = "— —"
	meta_value.position = Vector2(20.0, 6.0)
	meta_value.size = Vector2(150.0, 40.0)
	meta_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta_value.add_theme_font_size_override("font_size", 22)
	meta_value.add_theme_color_override("font_color", INK_FAINT)
	meta_box.add_child(meta_value)

	var meta_hint := Label.new()
	meta_hint.name = "MetaHintLabel"
	meta_hint.text = "局外成长"
	meta_hint.position = Vector2(176.0, 10.0)
	meta_hint.size = Vector2(104.0, 32.0)
	meta_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta_hint.add_theme_font_size_override("font_size", 15)
	meta_hint.add_theme_color_override("font_color", INK_FAINT)
	meta_box.add_child(meta_hint)


## 屏幕两侧各一颗圆形箭头按钮，竖向居中。
func _build_arrows() -> void:
	_prev_button = _make_round_button("PrevButton", "‹")
	_prev_button.anchor_left = 0.0
	_prev_button.anchor_right = 0.0
	_prev_button.anchor_top = 0.5
	_prev_button.anchor_bottom = 0.5
	_prev_button.offset_left = 36.0
	_prev_button.offset_right = 36.0 + 84.0
	_prev_button.offset_top = -42.0
	_prev_button.offset_bottom = 42.0
	_prev_button.pressed.connect(func() -> void: _step(-1))
	_ui.add_child(_prev_button)

	_next_button = _make_round_button("NextButton", "›")
	_next_button.anchor_left = 1.0
	_next_button.anchor_right = 1.0
	_next_button.anchor_top = 0.5
	_next_button.anchor_bottom = 0.5
	_next_button.offset_left = -36.0 - 84.0
	_next_button.offset_right = -36.0
	_next_button.offset_top = -42.0
	_next_button.offset_bottom = 42.0
	_next_button.pressed.connect(func() -> void: _step(1))
	_ui.add_child(_next_button)


func _refresh_arrows() -> void:
	if _prev_button == null or _next_button == null:
		return
	_prev_button.disabled = _current <= 0
	_next_button.disabled = _current >= _slots.size() - 1


## 常驻的关卡卡：关名、盘数、最高分、状态，右侧是这一关该做的事（进入 / 续上 + 放弃 / 未解锁）。
func _build_stage_card() -> void:
	_stage_card = Panel.new()
	_stage_card.name = "StageCard"
	_stage_card.anchor_left = 0.5
	_stage_card.anchor_right = 0.5
	_stage_card.anchor_top = 1.0
	_stage_card.anchor_bottom = 1.0
	_stage_card.offset_left = -420.0
	_stage_card.offset_right = 420.0
	_stage_card.offset_top = -140.0
	_stage_card.offset_bottom = -36.0
	_stage_card.add_theme_stylebox_override("panel", _card_style(16))
	_ui.add_child(_stage_card)

	_stage_card_title = Label.new()
	_stage_card_title.name = "StageCardTitle"
	_stage_card_title.position = Vector2(32.0, 14.0)
	_stage_card_title.size = Vector2(470.0, 36.0)
	_stage_card_title.add_theme_font_size_override("font_size", 26)
	_stage_card_title.add_theme_color_override("font_color", INK)
	_stage_card.add_child(_stage_card_title)

	_stage_card_detail = Label.new()
	_stage_card_detail.name = "StageCardDetail"
	_stage_card_detail.position = Vector2(32.0, 52.0)
	_stage_card_detail.size = Vector2(470.0, 26.0)
	_stage_card_detail.add_theme_font_size_override("font_size", 17)
	_stage_card_detail.add_theme_color_override("font_color", INK_SOFT)
	_stage_card.add_child(_stage_card_detail)

	# 续局条：有进行中的关时亮起的一行琥珀提示（在本关：进度；在别关：提醒会放弃）。
	_resume_banner = Control.new()
	_resume_banner.name = "ResumeBanner"
	_resume_banner.position = Vector2(32.0, 78.0)
	_resume_banner.size = Vector2(470.0, 22.0)
	_resume_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resume_banner.visible = false
	_stage_card.add_child(_resume_banner)
	var accent := ColorRect.new()
	accent.name = "ResumeAccent"
	accent.color = ACCENT
	accent.position = Vector2(0.0, 4.0)
	accent.size = Vector2(4.0, 16.0)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resume_banner.add_child(accent)
	_resume_text = Label.new()
	_resume_text.name = "ResumeTextLabel"
	_resume_text.position = Vector2(12.0, 0.0)
	_resume_text.size = Vector2(458.0, 22.0)
	_resume_text.add_theme_font_size_override("font_size", 15)
	_resume_text.add_theme_color_override("font_color", ACCENT.darkened(0.25))
	_resume_banner.add_child(_resume_text)

	_stage_card_enter = _make_button("EnterStageButton", "进入关卡", Vector2(168.0, 52.0), true)
	_stage_card_enter.position = Vector2(500.0, 26.0)
	_stage_card_enter.pressed.connect(_on_enter_pressed)
	_stage_card.add_child(_stage_card_enter)

	_stage_card_abandon = _make_button("AbandonStageButton", "放弃", Vector2(140.0, 52.0))
	_stage_card_abandon.position = Vector2(676.0, 26.0)
	_stage_card_abandon.visible = false
	_stage_card_abandon.pressed.connect(func() -> void: _open_confirm(""))
	_stage_card.add_child(_stage_card_abandon)


func _update_stage_card() -> void:
	var stage_id := current_stage()
	var stage := StageTable.stage(stage_id)
	if stage.is_empty() or _stage_card == null:
		return
	var state := _state_for(stage_id)
	_stage_card_title.text = "第 %d 关 · %s" % [int(stage.get("order", 0)), String(stage.get("name", ""))]
	var best := int(_high_scores.get(stage_id, 0))
	var best_text := ("最高 %s" % _format_score(best)) if best > 0 else "最高 —"
	var status := String(StageBadge.STATE_WORDS[state])
	if bool(stage.get("endless", false)):
		# 无尽关没有目标盘数：卡上写记录「最远第 N 盘」。
		var farthest := int(_best_rounds.get(stage_id, 0))
		var farthest_text := ("最远第 %d 盘" % farthest) if farthest > 0 else "最远 —"
		_stage_card_detail.text = "无尽 · 越打越难 · %s · %s · %s" % [farthest_text, best_text, status]
	else:
		_stage_card_detail.text = "共 %d 盘 · %s · %s" % [int(stage.get("target_round", 0)), best_text, status]
	var resuming := _resume_stage_id != "" and stage_id == _resume_stage_id
	if _resume_stage_id != "":
		var resume_stage := StageTable.stage(_resume_stage_id)
		_resume_banner.visible = true
		if resuming and bool(resume_stage.get("endless", false)):
			_resume_text.text = "进行中 · 第 %d 盘 · 无尽" % maxi(_resume_round, 1)
		elif resuming:
			_resume_text.text = "进行中 · 第 %d / %d 盘" % [maxi(_resume_round, 1), int(resume_stage.get("target_round", 0))]
		else:
			_resume_text.text = "「%s」进行中 · 进这一关会放弃那份进度" % String(resume_stage.get("name", ""))
	else:
		_resume_banner.visible = false
	_stage_card_abandon.visible = resuming
	if resuming:
		_stage_card_enter.text = "续上这一关"
		_stage_card_enter.disabled = false
	elif state == StageBadge.State.LOCKED:
		_stage_card_enter.text = "未解锁"
		_stage_card_enter.disabled = true
	elif state == StageBadge.State.CLEARED:
		_stage_card_enter.text = "再打一遍"
		_stage_card_enter.disabled = false
	else:
		_stage_card_enter.text = "进入关卡"
		_stage_card_enter.disabled = false


static func _format_score(value: int) -> String:
	var raw := str(maxi(value, 0))
	var out := ""
	var count := 0
	for i in range(raw.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = raw[i] + out
		count += 1
	return out


func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.name = "AbandonConfirm"
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false
	_confirm.z_index = 10
	_ui.add_child(_confirm)

	_confirm_dim = ColorRect.new()
	_confirm_dim.name = "ConfirmDim"
	_confirm_dim.color = Color(0.16, 0.14, 0.11, 0.42)
	_confirm_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(_confirm_dim)

	_confirm_card = Panel.new()
	_confirm_card.name = "ConfirmPanel"
	_confirm_card.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_card.size = Vector2(640.0, 280.0)
	_confirm_card.offset_left = -320.0
	_confirm_card.offset_right = 320.0
	_confirm_card.offset_top = -140.0
	_confirm_card.offset_bottom = 140.0
	var card_box := _card_style(20)
	card_box.shadow_size = 28
	card_box.shadow_color = Color(0.10, 0.09, 0.07, 0.18)
	_confirm_card.add_theme_stylebox_override("panel", card_box)
	_confirm.add_child(_confirm_card)

	_confirm_text = Label.new()
	_confirm_text.name = "ConfirmTextLabel"
	_confirm_text.position = Vector2(40.0, 36.0)
	_confirm_text.size = Vector2(560.0, 130.0)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.add_theme_font_size_override("font_size", 22)
	_confirm_text.add_theme_color_override("font_color", INK)
	_confirm_card.add_child(_confirm_text)

	var no := _make_button("ConfirmNoButton", "继续那一关", Vector2(220.0, 56.0), true)
	no.position = Vector2(40.0, 188.0)
	no.pressed.connect(func() -> void: _close_confirm(false))
	_confirm_card.add_child(no)

	var yes := _make_button("ConfirmYesButton", "放弃并开新的", Vector2(250.0, 56.0))
	yes.position = Vector2(350.0, 188.0)
	yes.pressed.connect(_on_confirm_yes)
	_confirm_card.add_child(yes)


func _make_button(node_name: String, text: String, box_size: Vector2, primary := false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.size = box_size
	button.custom_minimum_size = box_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)
	var face := INK if primary else PAPER
	var ink := PAPER if primary else INK
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var box := _card_style(14)
		box.bg_color = face
		if primary:
			box.border_color = INK
		match state_name:
			"hover":
				box.bg_color = face.lightened(0.10) if primary else Color(0.985, 0.975, 0.955)
				box.border_color = INK.lightened(0.10) if primary else Color(0.70, 0.66, 0.59)
			"pressed":
				box.bg_color = face.darkened(0.12) if primary else Color(0.94, 0.925, 0.89)
				box.shadow_size = 0
			"disabled":
				box.bg_color = Color(0.94, 0.93, 0.90)
				box.border_color = PAPER_EDGE
		button.add_theme_stylebox_override(state_name, box)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_color_override("font_disabled_color", INK_FAINT)
	return button


## 圆形大按钮（左右箭头）：白卡皮、墨字，禁用时淡下去。
func _make_round_button(node_name: String, glyph: String) -> Button:
	var button := _make_button(node_name, glyph, Vector2(84.0, 84.0))
	button.add_theme_font_size_override("font_size", 44)
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var box := button.get_theme_stylebox(state_name) as StyleBoxFlat
		if box != null:
			box.set_corner_radius_all(42)
	return button


## 白卡底：所有浮在柜子上的面板共用这一份样式。
func _card_style(radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.border_color = PAPER_EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.shadow_color = CARD_SHADOW
	box.shadow_size = 10
	box.shadow_offset = Vector2(0.0, 4.0)
	return box


## `next_stage_id` 为空 = 从关卡卡的「放弃」进来的，放弃完停在柜子上；非空 = 要进别的关，
## 放弃完直接进那一关。
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


## 顶栏地形区读数：当前这一关所在的区。
func _refresh_region_readout() -> void:
	if _region_name_label == null or _slots.is_empty():
		return
	var stage := StageTable.stage(current_stage())
	if stage.is_empty():
		return
	var region_id := String(stage["region"])
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


# --- 复原仪式的文字反馈 ---


func _build_restore_text() -> void:
	_restore_title = Panel.new()
	_restore_title.name = "RestoreTitle"
	_restore_title.anchor_left = 0.5
	_restore_title.anchor_right = 0.5
	_restore_title.offset_left = -250.0
	_restore_title.offset_right = 250.0
	_restore_title.offset_top = 94.0
	_restore_title.offset_bottom = 180.0
	_restore_title.add_theme_stylebox_override("panel", _card_style(18))
	_restore_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restore_title.visible = false
	_ui.add_child(_restore_title)
	_restore_title_label = Label.new()
	_restore_title_label.name = "RestoreTitleLabel"
	_restore_title_label.position = Vector2(0.0, 10.0)
	_restore_title_label.size = Vector2(500.0, 46.0)
	_restore_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_restore_title_label.add_theme_font_size_override("font_size", 34)
	_restore_title_label.add_theme_color_override("font_color", INK)
	_restore_title.add_child(_restore_title_label)
	_restore_sub_label = Label.new()
	_restore_sub_label.name = "RestoreSubLabel"
	_restore_sub_label.position = Vector2(0.0, 54.0)
	_restore_sub_label.size = Vector2(500.0, 24.0)
	_restore_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_restore_sub_label.add_theme_font_size_override("font_size", 17)
	_restore_sub_label.add_theme_color_override("font_color", INK_SOFT)
	_restore_title.add_child(_restore_sub_label)
	_restore_lines_host = Control.new()
	_restore_lines_host.name = "RestoreLines"
	_restore_lines_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_restore_lines_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_restore_lines_host)


func _show_restore_title(stage_id: String) -> void:
	if _restore_title == null:
		return
	var stage := StageTable.stage(stage_id)
	_restore_title_label.text = "「%s」复苏" % String(stage.get("name", stage_id))
	_restore_sub_label.text = "荒芜褪去 · 生机回来了"
	if _restore_tween != null and _restore_tween.is_valid():
		_restore_tween.kill()
	_restore_title.visible = true
	_restore_title.pivot_offset = _restore_title.size * 0.5
	_restore_title.scale = Vector2(0.86, 0.86)
	_restore_title.modulate.a = 0.0
	_restore_tween = create_tween().set_parallel(true)
	_restore_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_restore_tween.tween_property(_restore_title, "scale", Vector2.ONE, 0.58)
	_restore_tween.tween_property(_restore_title, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD)


func _hide_restore_title(immediate: bool) -> void:
	if _restore_title == null:
		return
	if _restore_tween != null and _restore_tween.is_valid():
		_restore_tween.kill()
	if immediate and _restore_lines_host != null:
		for line in _restore_lines_host.get_children():
			line.queue_free()
	if immediate or not _restore_title.visible:
		_restore_title.visible = false
		return
	_restore_tween = create_tween()
	_restore_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_restore_tween.tween_property(_restore_title, "modulate:a", 0.0, 0.6)
	_restore_tween.tween_callback(func() -> void: _restore_title.visible = false)


## 一行短句：从标题卡下方冒出来，往上飘一点再淡掉。
func _pop_restore_line(text: String, index: int, token: int) -> void:
	if not visible or _restore_lines_host == null or _ceremony_token != token or _restoring_id == "":
		return
	var pill := Panel.new()
	pill.name = "RestoreLine%d" % index
	pill.add_theme_stylebox_override("panel", _card_style(14))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", INK)
	label.position = Vector2(26.0, 9.0)
	var text_w := label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22).x
	label.size = Vector2(text_w + 4.0, 30.0)
	var accent := ColorRect.new()
	accent.color = ACCENT
	accent.position = Vector2(12.0, 14.0)
	accent.size = Vector2(4.0, 20.0)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(accent)
	pill.add_child(label)
	pill.size = Vector2(text_w + 56.0, 48.0)
	pill.position = Vector2(150.0, 214.0 + 60.0 * index)
	pill.pivot_offset = pill.size * 0.5
	pill.scale = Vector2(0.8, 0.8)
	pill.modulate.a = 0.0
	_restore_lines_host.add_child(pill)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(pill, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pill, "modulate:a", 1.0, 0.28)
	tween.chain().tween_interval(1.45)
	tween.chain().set_parallel(true)
	tween.tween_property(pill, "position:y", pill.position.y - 34.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(pill, "modulate:a", 0.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(pill.queue_free)
