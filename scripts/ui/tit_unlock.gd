class_name TitUnlock
extends Control
## 长尾山雀解锁页。彩蛋：每撩一次立绘，画面里就多蹦出来一只小长尾山雀；
## 凑够一群之后全部滚到一起，连立绘一并融成一碗汤圆。
##
## 融合分四段：①全员憋气蹲一下（预备）②沿弧线错峰飞向中心、边飞边缩、拖出「啾」字尾迹
## ③撞在一起：白光炸开、屏幕一震、咚一声、汤圆碎屑四散 ④碗从底下弹出来、压扁回弹，之后一直冒热气。

## 页面里的彩蛋被触发，带上对应的成就 id。
signal easter_egg_triggered(achievement_id: String)

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const RevealMotion := preload("res://scripts/ui/unlock_reveal_motion.gd")
const Catalog := preload("res://scripts/game/achievement_catalog.gd")
const FLOCK_TEXTURES: Array[Texture2D] = [
	preload("res://my_asset/birds/tit_idle_1.png"),
	preload("res://my_asset/birds/tit_idle_2.png"),
	preload("res://my_asset/birds/tit_idle_3.png"),
	preload("res://my_asset/birds/tit_idle_4.png"),
]
const BOWL_TEXTURE := preload("res://my_asset/tangyuan_bowl.png")
## 撩到第几只时鸟群融合成汤圆。
const TANGYUAN_FLOCK := 12
const TANGYUAN_NAME_TEXT := "汤    圆"
const TANGYUAN_TAGLINE_TEXT := "圆 圆 满 满"
const BOWL_SIZE := Vector2(760.0, 600.0)
const FLOCK_MIN_SIZE := 150.0
const FLOCK_MAX_SIZE := 210.0
## 融合各段的时长；测试和截图工具按这些值等。
const MERGE_BRACE_TIME := 0.26
const MERGE_STAGGER := 0.04
const MERGE_FLIGHT_TIME := 0.62
const MERGE_SERVE_TIME := 0.55
const TANGYUAN_COLOR := Color(0.99, 0.96, 0.93, 1.0)
const STEAM_GLYPHS := ["〜", "～", "≈"]

@onready var bird: TextureRect = $Finale/Bird
@onready var finale: Control = $Finale
@onready var name_label: Label = $Finale/Name
@onready var tagline_label: Label = $Finale/Tagline
@onready var effect_label: Label = $Finale/Effect
@onready var continue_button: Button = $Finale/Continue
@onready var bird_call: AudioStreamPlayer = $BirdCall
@onready var serve_thud: AudioStreamPlayer = $ServeThud
@onready var flight_layer: Control = $FlightLayer

var _flock: Array[TextureRect] = []
var _merging := false
var _merged := false
var _bowl: TextureRect
var _steam_generation := 0
var _name_home_text := ""
var _tagline_home_text := ""


func _ready() -> void:
	visible = false
	RevealMotion.prepare(finale, bird, [name_label, tagline_label, effect_label], continue_button)
	ButtonMotion.bind(continue_button, continue_button, 1.0)
	ButtonMotion.bind_hover(bird, bird, 1.6)
	continue_button.mouse_entered.connect(_play_bird_call)
	bird.mouse_entered.connect(_on_bird_hovered)
	_name_home_text = name_label.text
	_tagline_home_text = tagline_label.text


func _play_bird_call(pitch: float = -1.0) -> void:
	bird_call.pitch_scale = randf_range(0.94, 1.08) if pitch < 0.0 else pitch
	bird_call.play()


func flock_count() -> int:
	return _flock.size()


func is_merged() -> bool:
	return _merged


## 从撩出最后一只到碗站稳大约要多久，给等待方一个准数。
static func merge_duration() -> float:
	return MERGE_BRACE_TIME + MERGE_STAGGER * TANGYUAN_FLOCK + MERGE_FLIGHT_TIME + 0.12 + MERGE_SERVE_TIME


func _on_bird_hovered() -> void:
	if _merged:
		_wobble_bowl()
		return
	if _merging:
		return
	_play_bird_call()
	_spawn_flock_bird()
	if _flock.size() >= TANGYUAN_FLOCK:
		_merge_into_tangyuan()


## 一只小长尾山雀从画面里随机一处「啵」地蹦出来，落在地上蹲好。
func _spawn_flock_bird() -> void:
	var chick := TextureRect.new()
	chick.texture = FLOCK_TEXTURES.pick_random()
	var side := randf_range(FLOCK_MIN_SIZE, FLOCK_MAX_SIZE)
	chick.size = Vector2(side, side)
	chick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chick.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chick.flip_h = randf() < 0.5
	chick.pivot_offset = Vector2(side * 0.5, side)
	var stage_width := maxf(flight_layer.size.x, 1280.0)
	var stage_height := maxf(flight_layer.size.y, 720.0)
	# 落点铺在画面中下部两侧，别正好压住主立绘的脸。
	var x := randf_range(40.0, stage_width - side - 40.0)
	var y := randf_range(stage_height * 0.42, stage_height - side - 30.0)
	chick.position = Vector2(x, y)
	chick.scale = Vector2(0.2, 0.2)
	chick.modulate.a = 0.0
	flight_layer.add_child(chick)
	_flock.append(chick)
	var pop := chick.create_tween().set_parallel(true)
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(chick, "scale", Vector2.ONE, 0.32)
	pop.tween_property(chick, "modulate:a", 1.0, 0.12)
	# 一个小跳：落地那下压扁一点再回弹。
	pop.chain().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(chick, "scale", Vector2(1.08, 0.92), 0.08)
	pop.chain().tween_property(chick, "scale", Vector2.ONE, 0.14)


# ---------------------------------------------------------------------------
# 融合
# ---------------------------------------------------------------------------


func _merge_into_tangyuan() -> void:
	_merging = true
	easter_egg_triggered.emit(Catalog.TIT_TANGYUAN)
	bird.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var centre := finale.size * 0.5 + Vector2(0.0, 40.0)
	var everyone: Array[TextureRect] = []
	everyone.append_array(_flock)
	everyone.append(bird)

	# ① 预备：全员同步憋气——先压扁再拉长，像要一起蹦起来。
	# 并行 Tween 里 chain() 只对紧接着的那一个 tweener 生效，所以先把所有人的「压扁」
	# 排成一步，再 chain 一次把所有人的「拉长」排成第二步；否则会变成十几步的接力。
	var brace := create_tween().set_parallel(true)
	brace.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for actor in everyone:
		actor.pivot_offset = Vector2(actor.size.x * 0.5, actor.size.y)
		brace.tween_property(actor, "scale", actor.scale * Vector2(1.18, 0.78), MERGE_BRACE_TIME * 0.55)
	brace.chain().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for actor in everyone:
		brace.tween_property(actor, "scale", actor.scale * Vector2(0.9, 1.16), MERGE_BRACE_TIME * 0.45)
	_play_bird_call(0.8)
	await brace.finished

	# ② 聚拢：错峰起飞，沿弧线飞向中心，中途鼓一下再缩小，尾迹拖出「啾」。
	var order := everyone.duplicate()
	order.shuffle()
	var flights: Array[Tween] = []
	for index in range(order.size()):
		var actor := order[index] as TextureRect
		actor.pivot_offset = actor.size * 0.5
		var start := actor.position + actor.size * 0.5
		var midpoint := (start + centre) * 0.5
		var lateral := (centre - start).orthogonal().normalized() * randf_range(140.0, 300.0) * (1.0 if randf() < 0.5 else -1.0)
		var control := midpoint + lateral
		var spin := randf_range(-8.0, 8.0)
		var base_scale := actor.scale
		var delay := MERGE_STAGGER * index
		var flight := actor.create_tween()
		flight.tween_interval(delay)
		flight.tween_method(func(progress: float) -> void:
			var point := _quadratic_bezier(start, control, centre, progress)
			actor.position = point - actor.size * 0.5
			var swell := 1.0 + 0.28 * sin(progress * PI)
			actor.scale = base_scale * lerpf(1.0, 0.22, progress * progress) * swell
			actor.rotation = spin * progress
		, 0.0, 1.0, MERGE_FLIGHT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		flights.append(flight)
		_emit_jiu_trail(actor, delay, MERGE_FLIGHT_TIME)
		if index % 3 == 0:
			get_tree().create_timer(delay).timeout.connect(_play_bird_call.bind(0.95 + 0.06 * index))
	for flight in flights:
		if flight.is_valid():
			await flight.finished
	if not _merging:
		return

	# ③ 撞击：全部消失，白光炸开、屏幕一震、咚一声、汤圆碎屑四散。
	for chick in _flock:
		if is_instance_valid(chick):
			chick.queue_free()
	_flock.clear()
	bird.modulate.a = 0.0
	bird.scale = Vector2.ONE
	bird.rotation = 0.0
	serve_thud.play()
	_flash(centre)
	_burst_crumbs(centre)
	_shake(finale, 14.0, 7)
	_shake(flight_layer, 14.0, 7)
	await get_tree().create_timer(0.12).timeout

	# ④ 端上来：碗从底下弹出来，压扁一下再站稳；文案跟着换成汤圆。
	_bowl = TextureRect.new()
	_bowl.name = "TangyuanBowl"
	_bowl.texture = BOWL_TEXTURE
	_bowl.size = BOWL_SIZE
	_bowl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bowl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bowl.mouse_filter = Control.MOUSE_FILTER_STOP
	_bowl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bowl.pivot_offset = Vector2(BOWL_SIZE.x * 0.5, BOWL_SIZE.y * 0.9)
	_bowl.position = centre - BOWL_SIZE * 0.5 + Vector2(0.0, 90.0)
	_bowl.scale = Vector2(0.3, 0.05)
	_bowl.modulate.a = 0.0
	_bowl.mouse_entered.connect(_on_bird_hovered)
	flight_layer.add_child(_bowl)
	var serve := create_tween().set_parallel(true)
	serve.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	serve.tween_property(_bowl, "position:y", centre.y - BOWL_SIZE.y * 0.5, MERGE_SERVE_TIME * 0.6)
	serve.tween_property(_bowl, "modulate:a", 1.0, 0.08)
	serve.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	serve.tween_property(_bowl, "scale", Vector2(1.22, 0.82), MERGE_SERVE_TIME * 0.32)
	serve.chain().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	serve.tween_property(_bowl, "scale", Vector2(0.94, 1.08), MERGE_SERVE_TIME * 0.3)
	serve.chain().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	serve.tween_property(_bowl, "scale", Vector2.ONE, MERGE_SERVE_TIME * 0.38)

	name_label.text = TANGYUAN_NAME_TEXT
	name_label.pivot_offset = name_label.size * 0.5
	var punch := create_tween()
	punch.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(name_label, "scale", Vector2(1.16, 0.86), 0.1)
	punch.tween_property(name_label, "scale", Vector2.ONE, 0.3)
	tagline_label.modulate.a = 0.0
	tagline_label.text = TANGYUAN_TAGLINE_TEXT
	var tagline_in := create_tween()
	tagline_in.tween_property(tagline_label, "modulate:a", 1.0, 0.3).set_delay(0.15)
	await serve.finished
	_merged = true
	_merging = false
	_steam_generation += 1
	_steam_loop(_steam_generation)


## 端上来之后再摸就只会晃一晃碗。
func _wobble_bowl() -> void:
	if _bowl == null or not is_instance_valid(_bowl):
		return
	_play_bird_call(0.6)
	var wobble := create_tween()
	wobble.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	wobble.tween_property(_bowl, "scale", Vector2(1.06, 0.95), 0.09)
	wobble.tween_property(_bowl, "scale", Vector2(0.97, 1.04), 0.12)
	wobble.tween_property(_bowl, "scale", Vector2.ONE, 0.16)


func _quadratic_bezier(start: Vector2, control: Vector2, finish: Vector2, progress: float) -> Vector2:
	var inverse := 1.0 - progress
	return inverse * inverse * start + 2.0 * inverse * progress * control + progress * progress * finish


## 飞行途中每隔一小会在身后丢一个「啾」，颜色从奶白飘到粉。
func _emit_jiu_trail(actor: TextureRect, delay: float, duration: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var deadline := Time.get_ticks_msec() + roundi(duration * 1000.0)
	while is_instance_valid(actor) and Time.get_ticks_msec() < deadline and actor.modulate.a > 0.0:
		_spawn_jiu_particle(actor.position + actor.size * 0.5)
		await get_tree().create_timer(0.055).timeout


func _spawn_jiu_particle(origin: Vector2) -> void:
	var particle := Label.new()
	particle.text = "啾"
	particle.size = Vector2(80.0, 80.0)
	particle.pivot_offset = particle.size * 0.5
	particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	particle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	particle.add_theme_font_size_override("font_size", randi_range(30, 52))
	var start_color := TANGYUAN_COLOR
	var finish_color := Color(1.0, randf_range(0.55, 0.75), randf_range(0.7, 0.85), 1.0)
	particle.add_theme_color_override("font_color", start_color)
	particle.add_theme_color_override("font_outline_color", Color(0.14, 0.05, 0.08, 0.9))
	particle.add_theme_constant_override("outline_size", 6)
	particle.z_index = -1
	flight_layer.add_child(particle)
	particle.position = origin - particle.size * 0.5 + Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
	particle.rotation = randf_range(-0.3, 0.3)
	particle.scale = Vector2(0.6, 0.6)
	var drift := Vector2(randf_range(-40.0, 40.0), randf_range(30.0, 80.0))
	# 绑在粒子自己身上：页面重开把粒子一扫，tween 也跟着停，lambda 不会摸到已释放的对象。
	var puff := particle.create_tween().set_parallel(true)
	puff.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	puff.tween_property(particle, "position", particle.position + drift, 0.5)
	puff.tween_property(particle, "scale", Vector2(1.2, 1.2), 0.5)
	puff.tween_method(func(progress: float) -> void:
		var color := start_color.lerp(finish_color, progress)
		color.a = 1.0 - clampf((progress - 0.3) / 0.7, 0.0, 1.0)
		particle.add_theme_color_override("font_color", color)
	, 0.0, 1.0, 0.5)
	await puff.finished
	if is_instance_valid(particle):
		particle.queue_free()


## 撞击白光：一个圆从中心炸开、很快淡掉。
func _flash(centre: Vector2) -> void:
	var flash := Panel.new()
	flash.name = "MergeFlash"
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = TANGYUAN_COLOR
	style.set_corner_radius_all(400)
	flash.add_theme_stylebox_override("panel", style)
	flash.size = Vector2(120.0, 120.0)
	flash.pivot_offset = flash.size * 0.5
	flash.position = centre - flash.size * 0.5
	flash.scale = Vector2(0.2, 0.2)
	flash.z_index = 5
	flight_layer.add_child(flash)
	var boom := flash.create_tween().set_parallel(true)
	boom.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	boom.tween_property(flash, "scale", Vector2(9.0, 9.0), 0.42)
	boom.tween_property(flash, "modulate:a", 0.0, 0.42)
	await boom.finished
	if is_instance_valid(flash):
		flash.queue_free()


## 汤圆碎屑：一圈白团子向四周飞出去，被重力拽回来，边落边淡。
func _burst_crumbs(centre: Vector2) -> void:
	for index in range(14):
		var crumb := Panel.new()
		crumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = TANGYUAN_COLOR
		style.border_color = Color(0.18, 0.12, 0.12, 1.0)
		style.set_border_width_all(3)
		style.set_corner_radius_all(60)
		crumb.add_theme_stylebox_override("panel", style)
		var side := randf_range(22.0, 46.0)
		crumb.size = Vector2(side, side)
		crumb.pivot_offset = crumb.size * 0.5
		crumb.position = centre - crumb.size * 0.5
		crumb.z_index = 6
		flight_layer.add_child(crumb)
		var angle := TAU * index / 14.0 + randf_range(-0.2, 0.2)
		var speed := randf_range(520.0, 900.0)
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		var duration := randf_range(0.6, 0.85)
		var start := crumb.position
		var arc := crumb.create_tween().set_parallel(true)
		arc.tween_method(func(t: float) -> void:
			var seconds := t * duration
			crumb.position = start + velocity * seconds + Vector2(0.0, 1400.0) * seconds * seconds
			crumb.rotation = t * 4.0
		, 0.0, 1.0, duration)
		arc.tween_property(crumb, "modulate:a", 0.0, 0.25).set_delay(duration - 0.25)
		arc.finished.connect(crumb.queue_free)


## 屏幕一震：把一整层控件按递减的随机偏移抖几下再归位。
func _shake(target: Control, strength: float, steps: int) -> void:
	var home := target.position
	var shake := create_tween()
	for step in range(steps):
		var falloff := 1.0 - float(step) / float(steps)
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * falloff
		shake.tween_property(target, "position", home + offset, 0.028)
	shake.tween_property(target, "position", home, 0.04)


## 碗上不停冒热气：每隔一小会从碗口升起一个波浪字，飘高、变淡。
func _steam_loop(generation: int) -> void:
	while generation == _steam_generation and _merged and _bowl != null and is_instance_valid(_bowl) and visible:
		var steam := Label.new()
		steam.text = STEAM_GLYPHS.pick_random()
		steam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		steam.add_theme_font_size_override("font_size", randi_range(44, 72))
		steam.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.0))
		steam.size = Vector2(90.0, 90.0)
		steam.pivot_offset = steam.size * 0.5
		steam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		steam.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		steam.rotation = PI * 0.5
		steam.position = _bowl.position + Vector2(BOWL_SIZE.x * randf_range(0.34, 0.66), BOWL_SIZE.y * 0.08) - steam.size * 0.5
		flight_layer.add_child(steam)
		var rise := steam.create_tween().set_parallel(true)
		rise.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		rise.tween_property(steam, "position:y", steam.position.y - randf_range(120.0, 180.0), 1.5)
		rise.tween_property(steam, "position:x", steam.position.x + randf_range(-30.0, 30.0), 1.5)
		rise.tween_property(steam, "scale", Vector2(1.4, 1.4), 1.5)
		rise.tween_method(func(t: float) -> void:
			steam.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.75 * sin(t * PI)))
		, 0.0, 1.0, 1.5)
		rise.finished.connect(steam.queue_free)
		await get_tree().create_timer(0.45).timeout


func present() -> void:
	# 重开这一页鸟群清空、汤圆收走、文案和立绘全部还原。
	for chick in _flock:
		if is_instance_valid(chick):
			chick.queue_free()
	_flock.clear()
	if _bowl != null and is_instance_valid(_bowl):
		_bowl.queue_free()
	_bowl = null
	_merging = false
	_merged = false
	_steam_generation += 1
	for leftover in flight_layer.get_children():
		leftover.queue_free()
	finale.position = Vector2.ZERO
	flight_layer.position = Vector2.ZERO
	name_label.text = _name_home_text
	tagline_label.text = _tagline_home_text
	name_label.scale = Vector2.ONE
	bird.scale = Vector2.ONE
	bird.rotation = 0.0
	bird_call.pitch_scale = 1.0
	ButtonMotion.reset(bird)
	RevealMotion.prepare(finale, bird, [name_label, tagline_label, effect_label], continue_button)
	visible = true
	await RevealMotion.play(self, finale, bird, [name_label, tagline_label, effect_label], continue_button)
	continue_button.disabled = false
	await continue_button.pressed
	continue_button.disabled = true
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fade.finished
	visible = false
	modulate = Color.WHITE
