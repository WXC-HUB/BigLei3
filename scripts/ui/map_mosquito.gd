class_name MapMosquito
extends Control
## 选关图上放养的一只蚊子：在画面里晃来晃去地飞，鼠标慢慢挪过去它会躲开，
## 鼠标**快速划过**身子才算拍到——啪一声、压扁、翻着圈掉下去，隔一会儿再飞进来一只。
##
## 命中判定不靠 Control 的 mouse_entered，而是每帧把指针的上一位置与当前位置连成线段，
## 看线段有没有扫过身子：快速一挥两帧之间能跳几十像素，只看点在不在身上会漏。
## 整个节点 MOUSE_FILTER_IGNORE，绝不挡住悬浮牌和顶栏按钮。

signal swatted(where: Vector2)

const SHEET := preload("res://assets/sprites/generated/mosquito/mosquito_sheet.png")
const BUZZ := preload("res://assets/audio/mosquito_buzz.wav")
const SWAT_SFX := preload("res://assets/audio/mosquito_swat.wav")
const POP_FONT := preload("res://assets/fonts/eva_ming_sc.otf")

const SHEET_COLUMNS := 4
const SHEET_ROWS := 2
## 翅膀一个拍打周期的帧序（图集行优先、0 起）：举高 → 平 → 压低 → 平 → 举高。
const WING_CYCLE: Array[int] = [0, 1, 2, 3, 4, 6, 5, 7]
const WING_FPS := 22.0
## 显示尺寸（一格正方形的边长，逻辑像素）。图集里蚊子朝左。
const CELL_SIZE := 118.0
## 身体中心相对格中心的偏移（占格边长的比例）：翅膀高高举着，身子在格子偏下。
const BODY_OFFSET := Vector2(0.06, 0.17)
const HIT_RADIUS := 40.0
## 指针快过这个速度（像素/秒）才算「拍」，慢于它只是「摸」，蚊子会躲。
const SWAT_SPEED := 900.0
## 一帧内指针跳得比这还远，当作鼠标从窗口外跳回来，不算拍。
const SWAT_MAX_JUMP := 420.0
const FLEE_RADIUS := 150.0
const FLEE_SLOW_SPEED := 420.0
## 注意到慢慢逼近的指针要这么久才反应，一挥而过就来不及躲。
const FLEE_REACT := 0.18
const CRUISE_SPEED := Vector2(120.0, 240.0)
const DART_SPEED := 640.0
const STEER_GAIN := 3.2
const RETARGET_WAIT := Vector2(0.45, 1.3)
const FIRST_WAIT := Vector2(1.2, 3.0)
## 拍死之后多久再飞进来一只。
const RESPAWN_WAIT := Vector2(7.0, 14.0)
## 一次关卡选择里拍死这么多只就收手：成就到手，蚊子不再来烦人。
const SWAT_LIMIT := 3
## 飞行区留边；顶栏那一条不去。
const EDGE_MARGIN := 80.0
const TOP_MARGIN := 150.0
## 嗡嗡声：离指针远 → 近 的音量。
const BUZZ_DB := Vector2(-24.0, -10.0)
const BUZZ_NEAR := 720.0
const DEAD_SQUASH := 0.1
const DEAD_LIFE := 1.0
const SPECK_COUNT := 7

enum State { HIDDEN, FLYING, DEAD }

## 测试与截图可指定种子，轨迹就可复现；< 0 表示随机。
var seed := -1

var _sprite: Sprite2D
var _fx: Control
var _buzz: AudioStreamPlayer
var _slap: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _state := State.HIDDEN
var _base_scale := Vector2.ONE
var _vel := Vector2.ZERO
var _target := Vector2.ZERO
var _cruise := 180.0
var _retarget_in := 0.0
var _spawn_in := 0.0
var _dart_left := 0.0
var _flee_notice := 0.0
var _wing_clock := 0.0
var _flight_clock := 0.0
var _dead_clock := 0.0
var _dead_vel := Vector2.ZERO
var _dead_spin := 0.0
var _last_pointer := Vector2.ZERO
var _pointer_seeded := false
var _pointer_override := Vector2.ZERO
var _use_pointer_override := false
var _swat_count := 0
## 拍满 SWAT_LIMIT 之后为真：不再排下一只，start() 也叫不回来。
var _retired := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()

	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	_sprite.texture = SHEET
	_sprite.hframes = SHEET_COLUMNS
	_sprite.vframes = SHEET_ROWS
	_sprite.centered = true
	var cell_px := float(SHEET.get_width()) / float(SHEET_COLUMNS)
	_base_scale = Vector2.ONE * (CELL_SIZE / cell_px)
	_sprite.scale = _base_scale
	_sprite.visible = false
	add_child(_sprite)

	_fx = Control.new()
	_fx.name = "Fx"
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

	_buzz = AudioStreamPlayer.new()
	_buzz.name = "Buzz"
	_buzz.stream = _looping(BUZZ)
	_buzz.volume_db = BUZZ_DB.x
	add_child(_buzz)
	_slap = AudioStreamPlayer.new()
	_slap.name = "Slap"
	_slap.stream = SWAT_SFX
	_slap.volume_db = -4.0
	add_child(_slap)
	set_process(false)


## 导入的 WAV 默认不循环；复制一份把循环点设到整段。
static func _looping(stream: AudioStream) -> AudioStream:
	if not (stream is AudioStreamWAV):
		return stream
	var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return wav


# --- 对外 ---


## 地图亮出来时叫：过一小会儿飞进来第一只。
func start() -> void:
	# 已经拍满了就不再出场：这一轮关卡选择里它彻底退场，回选关也不会再飞回来。
	if _retired:
		return
	visible = true
	_state = State.HIDDEN
	_sprite.visible = false
	_spawn_in = _rng.randf_range(FIRST_WAIT.x, FIRST_WAIT.y)
	set_process(true)


## 地图收起时叫：蚊子和嗡嗡声一起停。
func stop() -> void:
	set_process(false)
	_state = State.HIDDEN
	_sprite.visible = false
	if _buzz != null:
		_buzz.stop()
	if _fx != null:
		for child in _fx.get_children():
			child.queue_free()


func is_flying() -> bool:
	return _state == State.FLYING


func swat_count() -> int:
	return _swat_count


## 拍满之后彻底退场了吗。
func is_retired() -> bool:
	return _retired


## 身体中心（本节点坐标）：命中与躲避都以它为准，不是格中心。
func body_center() -> Vector2:
	var offset := BODY_OFFSET * CELL_SIZE
	if _sprite.flip_h:
		offset.x = -offset.x
	return _sprite.position + offset.rotated(_sprite.rotation)


## 飞行区：整屏收边，顶栏那条留空。
func flight_rect() -> Rect2:
	var area := size
	if area.x < 200.0 or area.y < 200.0:
		area = get_viewport_rect().size
	return Rect2(
		Vector2(EDGE_MARGIN, TOP_MARGIN),
		Vector2(area.x - EDGE_MARGIN * 2.0, area.y - TOP_MARGIN - EDGE_MARGIN)
	)


## 不等首次延时，立刻从屏边飞进来（截图、测试用）。
func spawn_now() -> void:
	_spawn()


## 直接放到指定位置开始飞（截图用，构图可控）。
func spawn_at(where: Vector2) -> void:
	_spawn()
	_sprite.position = where


## 测试用：不读真实鼠标，用这个坐标当指针。
func set_pointer_for_test(pointer: Vector2) -> void:
	_pointer_override = pointer
	_use_pointer_override = true


## 测试用：手动推进一帧（自动 process 关掉之后用）。
func drive(delta: float) -> void:
	_tick(delta)


# --- 每帧 ---


func _process(delta: float) -> void:
	_tick(delta)


func _tick(delta: float) -> void:
	var pointer := _pointer_override if _use_pointer_override else get_local_mouse_position()
	if not _pointer_seeded:
		_last_pointer = pointer
		_pointer_seeded = true
	var moved := pointer - _last_pointer
	match _state:
		State.HIDDEN:
			# 退场之后不再排下一只：光靠 set_process(false) 不够，截图工具和测试会手动推帧。
			if _retired:
				return
			_spawn_in -= delta
			if _spawn_in <= 0.0:
				_spawn()
		State.FLYING:
			_check_pointer(delta, pointer, moved)
			if _state == State.FLYING:
				_fly(delta)
				_animate_wings(delta)
				_tune_buzz(pointer)
		State.DEAD:
			_tumble(delta)
	_last_pointer = pointer


func _spawn() -> void:
	var rect := flight_rect()
	var from_left := _rng.randf() < 0.5
	var start := Vector2(
		rect.position.x - CELL_SIZE if from_left else rect.end.x + CELL_SIZE,
		_rng.randf_range(rect.position.y + rect.size.y * 0.15, rect.end.y - rect.size.y * 0.15)
	)
	_sprite.position = start
	_sprite.rotation = 0.0
	_sprite.scale = _base_scale
	_sprite.modulate = Color.WHITE
	_sprite.flip_h = from_left
	_sprite.frame = WING_CYCLE[0]
	_sprite.visible = true
	_pick_target()
	_vel = (_target - start).normalized() * _cruise
	_dart_left = 0.0
	_flee_notice = 0.0
	_flight_clock = 0.0
	_state = State.FLYING
	if _buzz != null and not _buzz.playing:
		_buzz.play()


func _pick_target() -> void:
	var rect := flight_rect()
	_target = Vector2(
		_rng.randf_range(rect.position.x, rect.end.x),
		_rng.randf_range(rect.position.y, rect.end.y)
	)
	_cruise = _rng.randf_range(CRUISE_SPEED.x, CRUISE_SPEED.y)
	_retarget_in = _rng.randf_range(RETARGET_WAIT.x, RETARGET_WAIT.y)


func _fly(delta: float) -> void:
	_flight_clock += delta
	_retarget_in -= delta
	if _retarget_in <= 0.0:
		_pick_target()
	var speed := DART_SPEED if _dart_left > 0.0 else _cruise
	_dart_left = maxf(0.0, _dart_left - delta)
	var desired := (_target - _sprite.position).normalized() * speed
	_vel = _vel.lerp(desired, clampf(STEER_GAIN * delta, 0.0, 1.0))
	# 蚊子式抖动：垂直航向的高频小摆 + 上下慢晃，飞得不像直线。
	var side := _vel.orthogonal().normalized()
	var jitter := side * sin(_flight_clock * 19.0) * 26.0 + Vector2(0.0, sin(_flight_clock * 7.3) * 12.0)
	var pos := _sprite.position + (_vel + jitter) * delta

	var rect := flight_rect()
	if pos.x < rect.position.x:
		pos.x = rect.position.x
		_vel.x = absf(_vel.x)
		_pick_target()
	elif pos.x > rect.end.x:
		pos.x = rect.end.x
		_vel.x = -absf(_vel.x)
		_pick_target()
	if pos.y < rect.position.y:
		pos.y = rect.position.y
		_vel.y = absf(_vel.y)
		_pick_target()
	elif pos.y > rect.end.y:
		pos.y = rect.end.y
		_vel.y = -absf(_vel.y)
		_pick_target()
	_sprite.position = pos
	if pos.distance_to(_target) < 30.0:
		_pick_target()

	if absf(_vel.x) > 12.0:
		_sprite.flip_h = _vel.x > 0.0
	# 微微俯仰跟着航向；图集朝左，翻转后旋转方向也跟着反。
	var tilt := clampf(_vel.y / maxf(speed, 1.0), -1.0, 1.0) * 0.3
	_sprite.rotation = tilt if _sprite.flip_h else -tilt


func _animate_wings(delta: float) -> void:
	_wing_clock += delta * WING_FPS
	_sprite.frame = WING_CYCLE[int(_wing_clock) % WING_CYCLE.size()]


func _tune_buzz(pointer: Vector2) -> void:
	if _buzz == null:
		return
	var closeness := 1.0 - clampf(pointer.distance_to(body_center()) / BUZZ_NEAR, 0.0, 1.0)
	_buzz.volume_db = lerpf(BUZZ_DB.x, BUZZ_DB.y, pow(closeness, 1.5))
	var target_pitch := lerpf(0.94, 1.2, clampf(_vel.length() / DART_SPEED, 0.0, 1.0))
	_buzz.pitch_scale = lerpf(_buzz.pitch_scale, target_pitch, 0.08)


## 快挥过身子 → 拍死；慢慢逼近 → 反应一下之后往反方向窜。
func _check_pointer(delta: float, pointer: Vector2, moved: Vector2) -> void:
	var body := body_center()
	var speed := moved.length() / maxf(delta, 0.0001)
	if speed >= SWAT_SPEED and moved.length() <= SWAT_MAX_JUMP:
		var closest := Geometry2D.get_closest_point_to_segment(body, _last_pointer, pointer)
		if closest.distance_to(body) <= HIT_RADIUS:
			_die(moved.normalized(), closest)
			return
	if pointer.distance_to(body) <= FLEE_RADIUS and speed < FLEE_SLOW_SPEED:
		_flee_notice += delta
		if _flee_notice >= FLEE_REACT:
			_flee_from(pointer)
	else:
		_flee_notice = maxf(0.0, _flee_notice - delta)


func _flee_from(pointer: Vector2) -> void:
	var body := body_center()
	var away := body - pointer
	if away.length_squared() < 1.0:
		away = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
	away = away.normalized().rotated(_rng.randf_range(-0.5, 0.5))
	var rect := flight_rect()
	_target = (body + away * 340.0).clamp(rect.position, rect.end)
	_dart_left = 0.5
	_retarget_in = 0.6
	_flee_notice = 0.0


func _die(direction: Vector2, where: Vector2) -> void:
	_state = State.DEAD
	_swat_count += 1
	_dead_clock = 0.0
	_dead_vel = direction * 260.0 + Vector2(0.0, -120.0)
	_dead_spin = _rng.randf_range(7.0, 11.0) * (1.0 if direction.x >= 0.0 else -1.0)
	_sprite.frame = 3
	# 拍上的那一下当场压扁，不等下一帧。
	_sprite.scale = _base_scale * Vector2(1.3, 0.4)
	if _buzz != null:
		_buzz.stop()
	if _slap != null:
		_slap.pitch_scale = _rng.randf_range(0.92, 1.08)
		_slap.play()
	_pop_text(where)
	_burst_specks(body_center(), direction)
	swatted.emit(where)


## 先压扁一瞬（拍上的那一下），再翻着圈往下掉、淡掉；掉完排下一只。
func _tumble(delta: float) -> void:
	_dead_clock += delta
	if _dead_clock < DEAD_SQUASH:
		_sprite.scale = _base_scale * Vector2(1.3, 0.4)
		return
	var fall := _dead_clock - DEAD_SQUASH
	var unsquash := clampf(fall / 0.1, 0.0, 1.0)
	_sprite.scale = _base_scale * Vector2(1.3, 0.4).lerp(Vector2(1.0, 0.8), unsquash)
	_dead_vel.y += 1500.0 * delta
	_sprite.position += _dead_vel * delta
	_sprite.rotation += _dead_spin * delta
	var alpha := 1.0 - clampf((fall - 0.3) / 0.5, 0.0, 1.0)
	_sprite.modulate = Color(0.8, 0.8, 0.8, alpha)
	if _dead_clock >= DEAD_LIFE:
		_sprite.visible = false
		_state = State.HIDDEN
		if _swat_count >= SWAT_LIMIT:
			# 第三只掉完就收工：不排下一只，也不用再每帧空转。
			_retired = true
			set_process(false)
			return
		_spawn_in = _rng.randf_range(RESPAWN_WAIT.x, RESPAWN_WAIT.y)


## 「啪！」在命中点弹出来，抖一下、飘一点、淡掉。
func _pop_text(where: Vector2) -> void:
	if _fx == null:
		return
	var pop := Label.new()
	pop.text = "啪！"
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.add_theme_font_override("font", POP_FONT)
	pop.add_theme_font_size_override("font_size", 58)
	pop.add_theme_color_override("font_color", Color(0.85, 0.24, 0.18))
	pop.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.94, 0.95))
	pop.add_theme_constant_override("outline_size", 10)
	_fx.add_child(pop)
	pop.reset_size()
	pop.pivot_offset = pop.size * 0.5
	pop.position = where - pop.size * 0.5 + Vector2(0.0, -20.0)
	pop.rotation = _rng.randf_range(-0.22, 0.22)
	pop.scale = Vector2(0.3, 0.3)
	var tween := pop.create_tween()
	tween.tween_property(pop, "scale", Vector2(1.18, 1.18), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pop, "scale", Vector2.ONE, 0.08)
	tween.parallel().tween_property(pop, "position:y", pop.position.y - 42.0, 0.6)
	tween.tween_interval(0.25)
	tween.tween_property(pop, "modulate:a", 0.0, 0.22)
	tween.finished.connect(pop.queue_free)


## 几粒灰黑碎屑顺着挥的方向甩出去，落着淡掉。
func _burst_specks(origin: Vector2, direction: Vector2) -> void:
	if _fx == null:
		return
	for _index in SPECK_COUNT:
		var speck := ColorRect.new()
		speck.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var edge := _rng.randf_range(4.0, 8.0)
		speck.size = Vector2(edge, edge)
		speck.color = Color(0.16, 0.16, 0.19)
		_fx.add_child(speck)
		speck.pivot_offset = speck.size * 0.5
		var spread := direction.rotated(_rng.randf_range(-1.1, 1.1))
		var velocity := spread * _rng.randf_range(160.0, 420.0) + Vector2(0.0, -_rng.randf_range(40.0, 160.0))
		var life := _rng.randf_range(0.45, 0.8)
		var spin := _rng.randf_range(-9.0, 9.0)
		var tween := speck.create_tween()
		tween.tween_method(
			func(progress: float) -> void:
				if not is_instance_valid(speck):
					return
				var elapsed := progress * life
				speck.position = origin + velocity * elapsed + Vector2(0.0, 0.5 * 1400.0 * elapsed * elapsed) - speck.size * 0.5
				speck.rotation = spin * elapsed
				speck.modulate.a = 1.0 - clampf((progress - 0.55) / 0.45, 0.0, 1.0),
			0.0,
			1.0,
			life
		)
		tween.finished.connect(speck.queue_free)
