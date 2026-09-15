class_name MapWanderAnimal
extends Control
## 第 2 关（麦垄）选关界面的彩蛋：地面上时不时晃出来一只动物（狗熊 / 猴子 / 企鹅 / 狐狸，
## 用户给的四张插画抠的图），在岛面上溜达、走走停停，过一阵自己踱下画面；**鼠标停到它身上**
## （不用点）乌鸦就从画外俯冲下来薅走一撮毛——「薅狗熊毛！」弹在头顶，动物惨叫一声撒腿
## 就跑，乌鸦叼着毛飞走。薅够 PLUCK_GOAL 种给成就。
##
## 和蚊子（[MapMosquito]）是一对：蚊子归第 1 关，这只归第 2 关，接口尽量一致——
## `start()`/`stop()`、`drive()` 手动推帧，方便无头测。
##
## **动物是在岛的格子坐标里走的，不是在屏幕上走的**：它的位置是展品的 (c, r) 格子，每帧按
## 当前相机投影成屏幕坐标再摆贴图。等距视角下岛面在屏幕上是个菱形，用屏幕矩形当活动区会
## 有大半落在岛外（第一版就是这么飘在半空的）。走的格子从布局掩码里挑，只挑陆地格，脚下
## 高度取那一格的地形高度，所以上了土丘也贴着地面。相机是正交的，远近不改变大小，缩放只
## 按「一格有多少像素」算一次。
##
## 动物贴图在右/下被原画切断，那条直边就当「站在草里」的吃水线：贴图底边贴着地面。

signal plucked(key: String, where: Vector2)

const CROW_FRAMES: Array[Texture2D] = [
	preload("res://my_asset/birds/crow_action_1.png"),   # 探身
	preload("res://my_asset/birds/crow_action_2.png"),   # 薅下
	preload("res://my_asset/birds/crow_action_3.png"),   # 僵住
	preload("res://my_asset/birds/crow_action_4.png"),   # 逃走
]
const TUFT := preload("res://my_asset/crow_fur_tuft.png")
const YELP := preload("res://assets/audio/crow_animal_yelp.wav")
const CAW := preload("res://assets/audio/crow_call.wav")
const POP_FONT := preload("res://assets/fonts/eva_ming_sc.otf")

## 四位主角：贴图、名字（进「薅XX毛」那句）、飞出来那撮毛的颜色、惨叫音高。
const ANIMALS: Array[Dictionary] = [
	{"key": "bear", "name": "狗熊", "texture": preload("res://assets/sprites/generated/wander/bear.png"),
		"fur": Color(0.64, 0.36, 0.20), "pitch": 0.74},
	{"key": "monkey", "name": "猴子", "texture": preload("res://assets/sprites/generated/wander/monkey.png"),
		"fur": Color(0.40, 0.28, 0.19), "pitch": 1.18},
	{"key": "penguin", "name": "企鹅", "texture": preload("res://assets/sprites/generated/wander/penguin.png"),
		"fur": Color(0.22, 0.23, 0.28), "pitch": 1.02},
	{"key": "fox", "name": "狐狸", "texture": preload("res://assets/sprites/generated/wander/fox.png"),
		"fur": Color(0.89, 0.42, 0.16), "pitch": 1.1},
]

## 动物有多高（按岛上的格子算）：一格是一个地形单元，屋子约 3 格宽。
const HEIGHT_IN_CELLS := 2.5
## 溜达与撒腿跑的速度（格/秒）。
const WALK_SPEED := Vector2(1.1, 1.9)
const FLEE_SPEED := 9.0
## 走一段停一会儿。
const PAUSE_WAIT := Vector2(0.7, 1.8)
## 在场上待够这么久就往岛边踱下去。
const STAY_TIME := Vector2(12.0, 20.0)
## 两只之间隔多久；开场第一只等多久。出现频率要高，别让人等。
const RESPAWN_WAIT := Vector2(2.2, 4.5)
const FIRST_WAIT := Vector2(0.6, 1.4)
## 薅够这么多种就给成就。
const PLUCK_GOAL := 3
## 走路时上下颠一点，看起来是在迈步。
const BOB_PIXELS := 4.0
const BOB_RATE := 6.2
## 只在岛的前半部分溜达：后半截被屋子和树挡着，看不见。
const FRONT_FROM := 0.42
## 命中判定往里收一点，避免蹭到边也算。
const HIT_INSET := 0.14
## 鼠标停在身上多久就开薅：给一点点缓冲，路过不算。
const HOVER_ARM := 0.08

## 薅毛四拍（和乌鸦解锁页同一套节奏）：俯冲、探身、薅下、僵住，然后各自跑路。
const DIVE_TIME := 0.42
const LEAN_TIME := 0.13
const YANK_TIME := 0.14
const FREEZE_TIME := 0.34
const ESCAPE_TIME := 0.85
## 乌鸦停在动物哪一侧、离多远（按动物贴图高度的比例）。
const CROW_OFFSET := Vector2(0.62, -0.46)
## 乌鸦比动物矮一头。
const CROW_HEIGHT_RATIO := 0.62

enum State { HIDDEN, WALKING, PLUCK, FLEE }

## 测试用固定随机种子；负数表示随机。
var seed := -1

var _sprite: Sprite2D
var _crow: Sprite2D
var _fx: Control
var _yelp: AudioStreamPlayer
var _caw: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _state := State.HIDDEN
## 走路的舞台：展品（要有 layout() 与 cell_to_local()）与柜子的相机。
var _slot: Node3D
var _camera: Camera3D
## 这件展品上所有能站人的格子（从掩码算一次，缓存起来）。
var _land: Array[Vector2i] = []
var _land_for := ""
var _heights := {}
var _index := 0
## 动物站在哪一格（浮点，(c, r)）。
var _cell := Vector2.ZERO
var _target := Vector2.ZERO
var _facing := -1.0
var _walk_speed := 1.4
var _pause_left := 0.0
var _stay_left := 0.0
var _spawn_in := 0.0
var _bob_clock := 0.0
var _leaving := false
var _pluck_clock := 0.0
var _pluck_phase := 0
var _crow_from := Vector2.ZERO
var _flee_dir := 1.0
var _plucked := {}
var _hover_clock := 0.0
var _pointer_override := Vector2.ZERO
var _use_pointer_override := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()

	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	_sprite.centered = false      # 以脚下那条边定位，贴着地面走
	_sprite.visible = false
	add_child(_sprite)

	_crow = Sprite2D.new()
	_crow.name = "Crow"
	_crow.texture = CROW_FRAMES[0]
	_crow.centered = true
	_crow.visible = false
	add_child(_crow)

	_fx = Control.new()
	_fx.name = "Fx"
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

	_yelp = AudioStreamPlayer.new()
	_yelp.name = "Yelp"
	_yelp.stream = YELP
	_yelp.volume_db = -6.0
	add_child(_yelp)
	_caw = AudioStreamPlayer.new()
	_caw.name = "Caw"
	_caw.stream = CAW
	_caw.volume_db = -9.0
	add_child(_caw)
	set_process(false)


# --- 对外 ---


## 走路的舞台：当前展品与柜子的相机。切关时换一次。
func set_ground_source(slot: Node3D, camera: Camera3D) -> void:
	if slot != _slot:
		_land.clear()
		_land_for = ""
	_slot = slot
	_camera = camera


## 切到第 2 关时叫：等一小会儿放第一只出来。
func start() -> void:
	visible = true
	_state = State.HIDDEN
	_sprite.visible = false
	_crow.visible = false
	_spawn_in = _rng.randf_range(FIRST_WAIT.x, FIRST_WAIT.y)
	set_process(true)


## 切走或地图收起时叫：动物、乌鸦、特效一起收干净。
func stop() -> void:
	set_process(false)
	_state = State.HIDDEN
	_sprite.visible = false
	_crow.visible = false
	if _yelp != null:
		_yelp.stop()
	if _caw != null:
		_caw.stop()
	if _fx != null:
		for child in _fx.get_children():
			child.queue_free()


func is_walking() -> bool:
	return _state == State.WALKING


func is_busy() -> bool:
	return _state == State.PLUCK or _state == State.FLEE


func current_key() -> String:
	return String(ANIMALS[_index]["key"]) if _state != State.HIDDEN else ""


func current_name() -> String:
	return String(ANIMALS[_index]["name"]) if _state != State.HIDDEN else ""


func plucked_keys() -> Array:
	return _plucked.keys()


func pluck_count() -> int:
	return _plucked.size()


## 薅够 PLUCK_GOAL 种了吗。
func is_complete() -> bool:
	return _plucked.size() >= PLUCK_GOAL


## 动物站的那一格（(c, r)）。
func cell() -> Vector2:
	return _cell


## 这一格在不在岛上（陆地）。
func is_on_land(c: float, r: float) -> bool:
	_ensure_land()
	return _land.has(Vector2i(int(floor(c)), int(floor(r))))


## 贴图在屏幕上的矩形（点击判定、测试都用它）。
func body_rect() -> Rect2:
	if _state == State.HIDDEN or _sprite.texture == null:
		return Rect2()
	var box := Vector2(_sprite.texture.get_width(), _sprite.texture.get_height()) * _sprite.scale.abs()
	var foot := _project(_cell)
	return Rect2(Vector2(foot.x - box.x * 0.5, foot.y - box.y), box)


## 不等延时，立刻放一只出来（截图、测试用）。
func spawn_now() -> void:
	_spawn()


## 指定放哪一只（测试用；key 不认识就随机）。
func spawn_key(key: String) -> void:
	for i in ANIMALS.size():
		if String(ANIMALS[i]["key"]) == key:
			_spawn(i)
			return
	_spawn()


## 测试用：不读真实鼠标，用这个坐标当指针。
func set_pointer_for_test(pointer: Vector2) -> void:
	_pointer_override = pointer
	_use_pointer_override = true


## 测试用：手动推进一帧（自动 process 关掉之后用）。
func drive(delta: float) -> void:
	_tick(delta)


## 对着当前这只薅一下（测试与截图用，等价于点在它身上）。
func pluck_now() -> bool:
	if _state != State.WALKING:
		return false
	_begin_pluck()
	return true


# --- 岛面 ---


## 把展品掩码里的陆地格收集起来：只要不是空格、地形高度 ≥ 0（水面不算）。
func _ensure_land() -> void:
	if _slot == null or not _slot.has_method("layout"):
		return
	var key := String(_slot.get("stage_id")) if _slot.get("stage_id") != null else str(_slot.get_instance_id())
	if _land_for == key and not _land.is_empty():
		return
	_land.clear()
	_land_for = key
	var layout: Dictionary = _slot.call("layout")
	_heights = layout.get("heights", {})
	var mask: Array = layout.get("mask", [])
	var rows := mask.size()
	for r in rows:
		var line := String(mask[r])
		# 只要岛的前半截：后半截被屋子和树挡着，动物走进去就看不见了。
		if float(r) < float(rows) * FRONT_FROM:
			continue
		for c in line.length():
			var ch := line[c]
			if ch == ".":
				continue
			if float(_heights.get(ch, -1.0)) < 0.0:
				continue     # 水面不站
			_land.append(Vector2i(c, r))


func _cell_height(c: float, r: float) -> float:
	if _slot == null or not _slot.has_method("layout"):
		return 0.0
	var layout: Dictionary = _slot.call("layout")
	var mask: Array = layout.get("mask", [])
	var ri := int(floor(r))
	var ci := int(floor(c))
	if ri < 0 or ri >= mask.size():
		return 0.0
	var line := String(mask[ri])
	if ci < 0 or ci >= line.length():
		return 0.0
	return float(_heights.get(line[ci], 0.0))


## 格子 → 屏幕坐标（脚下那一点）。
func _project(at: Vector2) -> Vector2:
	if _slot == null or _camera == null or not _slot.has_method("cell_to_local"):
		return Vector2.ZERO
	var local: Vector3 = _slot.call("cell_to_local", at.x, at.y, _cell_height(at.x, at.y))
	return _camera.unproject_position(_slot.global_position + local)


## 一格在屏幕上有多少像素（正交相机，和远近无关）。
func _pixels_per_cell() -> float:
	if _slot == null or _camera == null:
		return 40.0
	var a := _project(_cell)
	var b_local: Vector3 = _slot.call("cell_to_local", _cell.x + 1.0, _cell.y, _cell_height(_cell.x, _cell.y))
	var b := _camera.unproject_position(_slot.global_position + b_local)
	return maxf((b - a).length(), 4.0)


# --- 每帧 ---


func _process(delta: float) -> void:
	_tick(delta)


func _tick(delta: float) -> void:
	match _state:
		State.HIDDEN:
			_spawn_in -= delta
			if _spawn_in <= 0.0:
				_spawn()
		State.WALKING:
			_walk(delta)
			_check_hover(delta)
		State.PLUCK:
			_advance_pluck(delta)
		State.FLEE:
			_flee(delta)


## 挑一只（优先还没薅过的），从岛边的一格走进来。
func _spawn(forced := -1) -> void:
	_ensure_land()
	if _land.is_empty():
		# 舞台还没准备好（相机还在滑），等一下再试。
		_spawn_in = 0.4
		return
	var pool: Array[int] = []
	for i in ANIMALS.size():
		if not _plucked.has(String(ANIMALS[i]["key"])):
			pool.append(i)
	if pool.is_empty():
		for i in ANIMALS.size():
			pool.append(i)
	_index = forced if forced >= 0 else pool[_rng.randi_range(0, pool.size() - 1)]

	var edge := _edge_cell(_rng.randf() < 0.5)
	_cell = Vector2(edge)
	_facing = 1.0 if edge.x < _island_mid_c() else -1.0
	_walk_speed = _rng.randf_range(WALK_SPEED.x, WALK_SPEED.y)
	_pause_left = 0.0
	_stay_left = _rng.randf_range(STAY_TIME.x, STAY_TIME.y)
	_leaving = false
	_bob_clock = 0.0
	_pick_target()
	_sprite.texture = ANIMALS[_index]["texture"]
	_sprite.visible = true
	_sprite.modulate = Color.WHITE
	_sprite.rotation = 0.0
	_state = State.WALKING
	_apply_transform()


func _island_mid_c() -> float:
	var total := 0.0
	for cell_at in _land:
		total += float(cell_at.x)
	return total / maxf(float(_land.size()), 1.0)


## 岛最左 / 最右那一列里随便挑一格，动物从那儿走进来、也从那儿走出去。
func _edge_cell(left: bool) -> Vector2i:
	var best := _land[0]
	var pool: Array[Vector2i] = []
	for cell_at in _land:
		if (left and cell_at.x < best.x) or (not left and cell_at.x > best.x):
			best = cell_at
	for cell_at in _land:
		if absi(cell_at.x - best.x) <= 1:
			pool.append(cell_at)
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _pick_target() -> void:
	if _land.is_empty():
		return
	_target = Vector2(_land[_rng.randi_range(0, _land.size() - 1)])


func _apply_transform() -> void:
	if _sprite.texture == null:
		return
	var ppc := _pixels_per_cell()
	var scale := HEIGHT_IN_CELLS * ppc / float(_sprite.texture.get_height())
	# 贴图朝左画的；往右走时水平翻过来。
	_sprite.scale = Vector2(scale * (-1.0 if _facing > 0.0 else 1.0), scale)
	var width := _sprite.texture.get_width() * scale
	var height := _sprite.texture.get_height() * scale
	var foot := _project(_cell)
	var bob := sin(_bob_clock * BOB_RATE) * BOB_PIXELS * (1.0 if _state == State.WALKING and _pause_left <= 0.0 else 0.0)
	# scale.x 为负时精灵向左翻，起点要补一个宽度。
	var left := foot.x - width * 0.5
	_sprite.position = Vector2(left + (width if _sprite.scale.x < 0.0 else 0.0), foot.y - height + bob)


func _walk(delta: float) -> void:
	_stay_left -= delta
	if _pause_left > 0.0:
		_pause_left -= delta
		_apply_transform()
		return
	_bob_clock += delta
	var to_target := _target - _cell
	if to_target.length() < 0.25:
		if _leaving:
			# 走到岛边了：下画面，过一阵换下一只。
			_sprite.visible = false
			_state = State.HIDDEN
			_spawn_in = _rng.randf_range(RESPAWN_WAIT.x, RESPAWN_WAIT.y)
			return
		if _stay_left <= 0.0:
			_leaving = true
			_target = Vector2(_edge_cell(_cell.x < _island_mid_c()))
		else:
			_pause_left = _rng.randf_range(PAUSE_WAIT.x, PAUSE_WAIT.y)
			_pick_target()
		_apply_transform()
		return
	var step := to_target.normalized() * _walk_speed * delta
	_cell += step
	if absf(step.x) > 0.0001:
		_facing = signf(step.x)
	_apply_transform()


# --- 薅毛 ---


func _begin_pluck() -> void:
	_state = State.PLUCK
	_pluck_clock = 0.0
	_pluck_phase = 0
	_crow.texture = CROW_FRAMES[0]
	_crow.visible = true
	_crow.modulate.a = 1.0
	_crow_from = _crow_perch() + Vector2(240.0, -280.0)
	_crow.position = _crow_from
	_size_crow()
	if _caw != null:
		_caw.pitch_scale = _rng.randf_range(0.95, 1.08)
		_caw.play()


## 乌鸦停在动物背后那一侧。
func _crow_perch() -> Vector2:
	var rect := body_rect()
	var side := -signf(_facing) if _facing != 0.0 else 1.0
	return rect.position + rect.size * Vector2(0.5, 0.0) \
		+ Vector2(rect.size.y * CROW_OFFSET.x * side, rect.size.y * CROW_OFFSET.y)


func _size_crow() -> void:
	var rect := body_rect()
	var scale := rect.size.y * CROW_HEIGHT_RATIO / float(CROW_FRAMES[0].get_height())
	# 和动物朝同一边：动物朝左时乌鸦在右，看着它。
	_crow.scale = Vector2(scale * (1.0 if _facing > 0.0 else -1.0), scale)


func _advance_pluck(delta: float) -> void:
	_pluck_clock += delta
	_size_crow()
	match _pluck_phase:
		0:   # 俯冲到位
			var t := clampf(_pluck_clock / DIVE_TIME, 0.0, 1.0)
			_crow.position = _crow_from.lerp(_crow_perch(), t * t * (3.0 - 2.0 * t))
			if t >= 1.0:
				_pluck_phase = 1
				_pluck_clock = 0.0
		1:   # 探身
			var lean := clampf(_pluck_clock / LEAN_TIME, 0.0, 1.0)
			var rect := body_rect()
			_crow.position = _crow_perch().lerp(
				_crow_perch() + Vector2(signf(_facing) * rect.size.x * 0.22, rect.size.y * 0.12), lean)
			if _pluck_clock >= LEAN_TIME:
				_pluck_phase = 2
				_pluck_clock = 0.0
				_crow.texture = CROW_FRAMES[1]
				_do_yank()
		2:   # 薅下那一瞬，动物抖一下
			_sprite.rotation = sin(_pluck_clock * 46.0) * 0.05 * maxf(0.0, 1.0 - _pluck_clock / YANK_TIME)
			if _pluck_clock >= YANK_TIME:
				_pluck_phase = 3
				_pluck_clock = 0.0
				_crow.texture = CROW_FRAMES[2]
				_sprite.rotation = 0.0
		3:   # 僵住，然后各自跑路
			if _pluck_clock >= FREEZE_TIME:
				_crow.texture = CROW_FRAMES[3]
				_state = State.FLEE
				_pluck_clock = 0.0
				_flee_dir = -signf(_facing) if _facing != 0.0 else 1.0
				_facing = _flee_dir


## 薅下的那一下：毛飞出来、「薅XX毛！」弹出来、动物惨叫、记账。
func _do_yank() -> void:
	var spec := ANIMALS[_index]
	var rect := body_rect()
	var where := rect.position + rect.size * Vector2(0.62 if _facing < 0.0 else 0.38, 0.3)
	_plucked[String(spec["key"])] = true
	if _yelp != null:
		_yelp.pitch_scale = float(spec["pitch"])
		_yelp.play()
	_pop_text("薅%s毛！" % String(spec["name"]), rect.position + Vector2(rect.size.x * 0.5, -rect.size.y * 0.16))
	_burst_tuft(where, spec["fur"])
	plucked.emit(String(spec["key"]), where)


## 动物顺着岛面跑向岛边，乌鸦叼着毛往反方向飞走。
func _flee(delta: float) -> void:
	_pluck_clock += delta
	_bob_clock += delta * 2.6
	_cell.x += _flee_dir * FLEE_SPEED * delta
	_apply_transform()
	_crow.position += Vector2(-_flee_dir * 520.0, -300.0) * delta
	_crow.modulate.a = clampf(1.0 - _pluck_clock / ESCAPE_TIME, 0.0, 1.0)
	if _pluck_clock >= ESCAPE_TIME:
		_sprite.visible = false
		_crow.visible = false
		_crow.modulate.a = 1.0
		_sprite.rotation = 0.0
		_state = State.HIDDEN
		_spawn_in = _rng.randf_range(RESPAWN_WAIT.x, RESPAWN_WAIT.y)


# --- 表现 ---


## 「薅狗熊毛！」弹在动物头顶，抖一下、飘一点、淡掉（和蚊子的「啪！」同一套）。
func _pop_text(text: String, where: Vector2) -> void:
	if _fx == null:
		return
	var pop := Label.new()
	pop.text = text
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.add_theme_font_override("font", POP_FONT)
	pop.add_theme_font_size_override("font_size", 44)
	pop.add_theme_color_override("font_color", Color(0.29, 0.25, 0.20))
	pop.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.94, 0.95))
	pop.add_theme_constant_override("outline_size", 10)
	_fx.add_child(pop)
	pop.reset_size()
	pop.pivot_offset = pop.size * 0.5
	pop.position = where - pop.size * 0.5
	pop.rotation = _rng.randf_range(-0.14, 0.14)
	pop.scale = Vector2(0.35, 0.35)
	var tween := pop.create_tween()
	tween.tween_property(pop, "scale", Vector2(1.14, 1.14), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pop, "scale", Vector2.ONE, 0.08)
	tween.parallel().tween_property(pop, "position:y", pop.position.y - 44.0, 0.7)
	tween.tween_interval(0.3)
	tween.tween_property(pop, "modulate:a", 0.0, 0.25)
	tween.finished.connect(pop.queue_free)


## 一撮毛从薅到的地方飞出去，打着旋儿落下淡掉。
func _burst_tuft(origin: Vector2, fur: Color) -> void:
	if _fx == null:
		return
	var span := maxf(body_rect().size.y, 60.0)
	for i in 3:
		var tuft := TextureRect.new()
		tuft.texture = TUFT
		tuft.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tuft.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tuft.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var edge := span * _rng.randf_range(0.22, 0.34)
		tuft.size = Vector2(edge, edge)
		tuft.pivot_offset = tuft.size * 0.5
		tuft.position = origin - tuft.size * 0.5
		tuft.modulate = fur
		_fx.add_child(tuft)
		var away := Vector2(_rng.randf_range(-1.0, 1.0), -1.0).normalized() * span * _rng.randf_range(0.5, 0.95)
		var tween := tuft.create_tween().set_parallel(true)
		tween.tween_property(tuft, "position", tuft.position + away + Vector2(0.0, span * 0.5), 0.8) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(tuft, "rotation", _rng.randf_range(-2.4, 2.4), 0.8)
		tween.tween_property(tuft, "modulate:a", 0.0, 0.8).set_delay(0.25)
		tween.chain().tween_callback(tuft.queue_free)


# --- 输入 ---


## 鼠标停到动物身上就开薅，不用点。停够 HOVER_ARM 秒才算，免得指针路过就触发。
func _check_hover(delta: float) -> void:
	var pointer := _pointer_override if _use_pointer_override else get_local_mouse_position()
	if hit_test(pointer):
		_hover_clock += delta
		if _hover_clock >= HOVER_ARM:
			_hover_clock = 0.0
			_begin_pluck()
	else:
		_hover_clock = 0.0


## 这个点算不算落在动物身上。
func hit_test(pointer: Vector2) -> bool:
	if _state != State.WALKING:
		return false
	var rect := body_rect()
	if rect.size.x <= 0.0:
		return false
	return rect.grow_individual(-rect.size.x * HIT_INSET, -rect.size.y * HIT_INSET,
		-rect.size.x * HIT_INSET, 0.0).has_point(pointer)
