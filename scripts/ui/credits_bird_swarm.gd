class_name CreditsBirdSwarm
extends Control
## 名单页上放养的九只鸟：各自沿直线匀速飞，撞墙原样弹回，撞到同伴就交换法向速度
## （等质量弹性碰撞）。鼠标滑过谁，谁就叫一声，并从身上炸出一大把音符。
##
## 命中判定是每帧自己拿鼠标坐标算的，没有用 Control 的 mouse_entered：鸟是动的，
## 靠引擎的悬停通知会漏掉「鼠标不动、鸟飞过来」这种最常见的情况。也正因为不靠
## 引擎派发，九只鸟一律 MOUSE_FILTER_IGNORE，绝不会挡住上面那排按钮。

## 一鸟一叫：立绘和音效都取自它在局内用的那一套。
const BIRDS := [
	{
		"name": "BlueBird",
		"texture": preload("res://my_asset/birds/blue_idle_1.png"),
		"call": preload("res://assets/audio/blue_bird_find.mp3"),
		"tint": Color(0.42, 0.72, 1.0),
	},
	{
		"name": "Redstart",
		"texture": preload("res://my_asset/birds/red_idle_1.png"),
		"call": preload("res://assets/audio/red_bird_compass.wav"),
		"tint": Color(1.0, 0.46, 0.42),
	},
	{
		"name": "NightHeron",
		"texture": preload("res://my_asset/birds/black_idle_1.png"),
		"call": preload("res://assets/audio/black_bird_lantern.mp3"),
		"tint": Color(0.72, 0.82, 0.95),
	},
	{
		"name": "Woodpecker",
		"texture": preload("res://my_asset/birds/attacker_idle_1.png"),
		"call": preload("res://assets/audio/attacker_peck.wav"),
		"tint": Color(1.0, 0.78, 0.34),
	},
	{
		"name": "Kestrel",
		"texture": preload("res://my_asset/birds/eg_idle_1.png"),
		"call": preload("res://assets/audio/eg_super_luck_trigger.mp3"),
		"tint": Color(0.98, 0.62, 0.28),
	},
	{
		"name": "LongTailedTit",
		"texture": preload("res://my_asset/birds/tit_idle_1.png"),
		"call": preload("res://assets/audio/tit_chirp.wav"),
		"tint": Color(1.0, 0.8, 0.86),
	},
	{
		"name": "AzureMagpie",
		"texture": preload("res://my_asset/birds/magpie_idle_1.png"),
		"call": preload("res://assets/audio/magpie_call.wav"),
		"tint": Color(0.72, 0.84, 0.96),
	},
	{
		"name": "CarrionCrow",
		"texture": preload("res://my_asset/birds/crow_idle_1.png"),
		"call": preload("res://assets/audio/crow_call.wav"),
		"tint": Color(0.58, 0.56, 0.6),
	},
	{
		"name": "TurtleDove",
		"texture": preload("res://my_asset/birds/dove_idle_1.png"),
		"call": preload("res://assets/audio/dove_coo.wav"),
		"tint": Color(0.95, 0.93, 0.9),
	},
]

const NOTE_FONT := preload("res://assets/fonts/eva_ming_sc.otf")
const NOTE_GLYPHS := ["♪", "♫", "♬", "♩"]

const BIRD_SIZE := 168.0
const SPEED_RANGE := Vector2(110.0, 190.0)
## 命中判定用的半径比立绘小一圈：立绘四周有透明留白，按整格算会「隔空叫」。
const HIT_RADIUS := BIRD_SIZE * 0.36
## 碰撞用的半径比命中判定大，鸟与鸟之间才不会视觉上叠在一起。
const BUMP_RADIUS := BIRD_SIZE * 0.42
## 摆出初始位置和速度的固定种子：同一份名单每次跑都一样，截图和回归才对得上。
const LAYOUT_SEED := 20260817

## 一次爆发的音符数量，以及同屏上限——名单是常驻画面，粒子必须封顶。
const NOTES_PER_BURST := 18
const NOTE_LIMIT := 90
const NOTE_SIZE_RANGE := Vector2(38.0, 92.0)
const NOTE_SPEED_RANGE := Vector2(240.0, 620.0)
const NOTE_LIFE_RANGE := Vector2(0.7, 1.25)
## 音符往上飘的额外加速度，飞出去之后会慢慢扬起来。
const NOTE_LIFT := -520.0
const NOTE_GRAVITY := 260.0

var _birds: Array[TextureRect] = []
var _velocities: PackedVector2Array = PackedVector2Array()
var _hovered: Array[bool] = []
var _voices: Array[AudioStreamPlayer] = []
var _note_layer: Control
var _rng := RandomNumberGenerator.new()
var _placed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = LAYOUT_SEED
	# 音符层排在鸟后面加进来，爆发才盖在鸟身上而不是被鸟压住。
	for config in BIRDS:
		_spawn_bird(config)
	_note_layer = Control.new()
	_note_layer.name = "Notes"
	_note_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_note_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_note_layer)
	# 名单页没拉起来之前不空转；present() 撒完位置才开始飞。
	set_process(false)


func _spawn_bird(config: Dictionary) -> void:
	var bird := TextureRect.new()
	bird.name = String(config["name"])
	bird.texture = config["texture"]
	bird.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bird.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bird.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bird.size = Vector2(BIRD_SIZE, BIRD_SIZE)
	bird.pivot_offset = Vector2(BIRD_SIZE, BIRD_SIZE) * 0.5
	add_child(bird)
	_birds.append(bird)
	_hovered.append(false)

	var voice := AudioStreamPlayer.new()
	voice.name = "%sCall" % bird.name
	voice.stream = config["call"]
	voice.volume_db = -4.0
	add_child(voice)
	_voices.append(voice)


## 名单页每次拉起来都重新撒一次位置，鸟不会停在上一次退出时的角落里。
func scatter() -> void:
	_placed = size.x > BIRD_SIZE and size.y > BIRD_SIZE
	if not _placed:
		return
	_rng.seed = LAYOUT_SEED
	_velocities = PackedVector2Array()
	for index in _birds.size():
		var bird := _birds[index]
		# 沿画面均分开摆，避免一开局就叠在一起互相弹。
		var column := (float(index) + 0.5) / float(_birds.size())
		bird.position = Vector2(
			lerpf(0.0, size.x - BIRD_SIZE, column),
			_rng.randf_range(0.0, size.y - BIRD_SIZE)
		)
		var angle := _rng.randf_range(0.0, TAU)
		var speed := _rng.randf_range(SPEED_RANGE.x, SPEED_RANGE.y)
		_velocities.append(Vector2.RIGHT.rotated(angle) * speed)
		_hovered[index] = false
		bird.scale = Vector2.ONE
		bird.rotation = 0.0
	_face_travel()


func clear_notes() -> void:
	if _note_layer == null:
		return
	for note in _note_layer.get_children():
		note.queue_free()


func _process(delta: float) -> void:
	if not _placed:
		scatter()
		return
	_advance(delta)
	_bounce_walls()
	_bounce_birds()
	_face_travel()
	_check_hover()


func _advance(delta: float) -> void:
	for index in _birds.size():
		_birds[index].position += _velocities[index] * delta


func _bounce_walls() -> void:
	var limit := size - Vector2(BIRD_SIZE, BIRD_SIZE)
	for index in _birds.size():
		var bird := _birds[index]
		var velocity := _velocities[index]
		if bird.position.x <= 0.0 and velocity.x < 0.0:
			bird.position.x = 0.0
			velocity.x = -velocity.x
		elif bird.position.x >= limit.x and velocity.x > 0.0:
			bird.position.x = limit.x
			velocity.x = -velocity.x
		if bird.position.y <= 0.0 and velocity.y < 0.0:
			bird.position.y = 0.0
			velocity.y = -velocity.y
		elif bird.position.y >= limit.y and velocity.y > 0.0:
			bird.position.y = limit.y
			velocity.y = -velocity.y
		_velocities[index] = velocity


## 等质量弹性碰撞：只交换法向分量，切向分量原样保留，两只鸟才会像撞球一样擦着分开
## 而不是原路退回。
func _bounce_birds() -> void:
	for a in _birds.size():
		for b in range(a + 1, _birds.size()):
			var center_a := _birds[a].position + Vector2(BIRD_SIZE, BIRD_SIZE) * 0.5
			var center_b := _birds[b].position + Vector2(BIRD_SIZE, BIRD_SIZE) * 0.5
			var offset := center_b - center_a
			var distance := offset.length()
			var overlap := BUMP_RADIUS * 2.0 - distance
			if overlap <= 0.0:
				continue
			# 正好重合时法线没有意义，随便挑一个方向把它们推开。
			var normal := offset / distance if distance > 0.01 else Vector2.RIGHT
			var push := normal * (overlap * 0.5 + 0.5)
			_birds[a].position -= push
			_birds[b].position += push
			var along_a := _velocities[a].dot(normal)
			var along_b := _velocities[b].dot(normal)
			# 已经在分开的就别再换一次，否则会黏在一起来回抖。
			if along_a - along_b <= 0.0:
				continue
			_velocities[a] += normal * (along_b - along_a)
			_velocities[b] += normal * (along_a - along_b)


## 立绘本身都朝左，往右飞的时候翻个面，看着才是在往前飞。
func _face_travel() -> void:
	for index in _birds.size():
		_birds[index].flip_h = _velocities[index].x > 0.0


func _check_hover() -> void:
	var mouse := get_local_mouse_position()
	for index in _birds.size():
		var center := _birds[index].position + Vector2(BIRD_SIZE, BIRD_SIZE) * 0.5
		var inside := mouse.distance_to(center) <= HIT_RADIUS
		if inside and not _hovered[index]:
			_greet(index)
		_hovered[index] = inside


func _greet(index: int) -> void:
	var voice := _voices[index]
	if voice.stream != null:
		voice.pitch_scale = _rng.randf_range(0.95, 1.08)
		voice.play()
	var bird := _birds[index]
	var pop := create_tween()
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(bird, "scale", Vector2(1.26, 1.26), 0.09)
	pop.tween_property(bird, "scale", Vector2.ONE, 0.34)
	_burst_notes(
		bird.position + Vector2(BIRD_SIZE, BIRD_SIZE) * 0.5,
		BIRDS[index]["tint"]
	)


## 一次炸一大把音符：从鸟身上向外飞散，飞出去之后被向上的力扬起来，边转边淡出。
func _burst_notes(origin: Vector2, tint: Color) -> void:
	var room := NOTE_LIMIT - _note_layer.get_child_count()
	if room <= 0:
		return
	for _index in mini(NOTES_PER_BURST, room):
		var note := Label.new()
		note.text = NOTE_GLYPHS[_rng.randi() % NOTE_GLYPHS.size()]
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note.add_theme_font_override("font", NOTE_FONT)
		note.add_theme_font_size_override(
			"font_size", int(_rng.randf_range(NOTE_SIZE_RANGE.x, NOTE_SIZE_RANGE.y))
		)
		note.add_theme_color_override("font_color", Color.WHITE)
		note.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.09, 0.85))
		note.add_theme_constant_override("outline_size", 8)
		_note_layer.add_child(note)
		note.reset_size()
		note.pivot_offset = note.size * 0.5

		var angle := _rng.randf_range(0.0, TAU)
		var velocity := Vector2.RIGHT.rotated(angle) * _rng.randf_range(
			NOTE_SPEED_RANGE.x, NOTE_SPEED_RANGE.y
		)
		var life := _rng.randf_range(NOTE_LIFE_RANGE.x, NOTE_LIFE_RANGE.y)
		var spin := _rng.randf_range(-3.4, 3.4)
		# 在鸟的本色附近取色，五只鸟炸出来的音符各是各的颜色。
		var color := tint.lerp(Color(1.0, 0.94, 0.72), _rng.randf_range(0.0, 0.55))
		# 位置、颜色和透明度必须由同一个方法写：拆成两个补间就会互相覆盖 modulate。
		var flight := create_tween().set_parallel(true)
		flight.tween_method(
			func(progress: float) -> void:
				_advance_note(note, origin, velocity, progress, life, color),
			0.0,
			1.0,
			life
		)
		flight.tween_property(note, "rotation", spin, life)
		flight.finished.connect(note.queue_free)


func _advance_note(
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
	# 起手快、随即被空气拖住，再被向上的力接管——先炸开后飘起来。
	var drag := 1.0 - pow(1.0 - progress, 2.4)
	var lift := 0.5 * (NOTE_LIFT + NOTE_GRAVITY * progress) * elapsed * elapsed
	note.position = origin + velocity * drag * life * 0.55 + Vector2(0.0, lift) - note.size * 0.5
	var fade_in := clampf(progress / 0.12, 0.0, 1.0)
	var fade_out := clampf((1.0 - progress) / 0.4, 0.0, 1.0)
	note.modulate = Color(color.r, color.g, color.b, minf(fade_in, fade_out))
	var pop := 0.55 + 0.6 * clampf(progress / 0.18, 0.0, 1.0)
	note.scale = Vector2(pop, pop)
