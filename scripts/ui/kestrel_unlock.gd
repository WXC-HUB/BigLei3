class_name KestrelUnlock
extends Control

## 页面里的彩蛋被触发，带上对应的成就 id。
signal easter_egg_triggered(achievement_id: String)

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const RevealMotion := preload("res://scripts/ui/unlock_reveal_motion.gd")
const FLY_TEXTURE := preload("res://my_asset/birds/eg_fly_big.png")
const Catalog := preload("res://scripts/game/achievement_catalog.gd")
## 撩到第几下红隼不再掠过，改成天上掉鸽子（和夜鹭页的掉鱼同一套做法）。
const RAGE_HOVERS := 21
## 掉够这么多只之后，红隼吃撑了：主文案换成打嗝，立绘横着撑开。
const GLUTTON_PIGEONS := 30
const GLUTTON_NAME_TEXT := "鸽 ？嗝~"
const GLUTTON_SCALE := Vector2(1.45, 1.02)
## 吃撑之后鼠标滑过只会冒这句，冒出来就一直留着，之后不再响应任何事件。
const FULL_BUBBLE_TEXT := "饱了……"
const PIGEON_TEXTURES: Array[Texture2D] = [
	preload("res://my_asset/birds/pigeons/pigeon_blue_gray.png"),
	preload("res://my_asset/birds/pigeons/pigeon_cream.png"),
	preload("res://my_asset/birds/pigeons/pigeon_dark_green.png"),
	preload("res://my_asset/birds/pigeons/pigeon_russet.png"),
	preload("res://my_asset/birds/pigeons/pigeon_violet_gray.png"),
]

@onready var bird: TextureRect = $Finale/Bird
@onready var finale: Control = $Finale
@onready var name_label: Label = $Finale/Name
@onready var tagline_label: Label = $Finale/Tagline
@onready var effect_label: Label = $Finale/Effect
@onready var continue_button: Button = $Finale/Continue
@onready var bird_call: AudioStreamPlayer = $BirdCall
@onready var flight_layer: Control = $FlightLayer

var _flyover_count := 0
var _pigeon_count := 0
var _glutton := false
var _full_bubble: Control
var _name_home_text := ""


func _ready() -> void:
	visible = false
	RevealMotion.prepare(finale, bird, [name_label, tagline_label, effect_label], continue_button)
	ButtonMotion.bind(continue_button, continue_button, 1.0)
	ButtonMotion.bind_hover(bird, bird, 1.6)
	continue_button.mouse_entered.connect(_play_bird_call)
	bird.mouse_entered.connect(_on_bird_hovered)
	_name_home_text = name_label.text


func _play_bird_call() -> void:
	bird_call.play()


func _on_bird_hovered() -> void:
	# 吃撑之后这只鸟就不干活了：只冒一次"饱了……"，此后什么都不响应。
	if _glutton:
		_show_full_bubble()
		return
	_play_bird_call()
	_flyover_count += 1
	# 撩过头之后掠过效果就不再出场，换成没完没了往下掉的鸽子。
	if _flyover_count >= RAGE_HOVERS:
		if _flyover_count == RAGE_HOVERS:
			easter_egg_triggered.emit(Catalog.KESTREL_PIGEON_RAIN)
		_drop_random_pigeon()
		return
	_play_level_flyover()


## 和夜鹭页的掉鱼同款：从画面上方随机位置落下，边转边掉，落地外自毁。
func _drop_random_pigeon() -> void:
	var pigeon := TextureRect.new()
	pigeon.texture = PIGEON_TEXTURES.pick_random()
	pigeon.size = Vector2(132.0, 132.0)
	pigeon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pigeon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pigeon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pigeon.pivot_offset = pigeon.size * 0.5
	_pigeon_count += 1
	if _pigeon_count > GLUTTON_PIGEONS and not _glutton:
		_become_glutton()
	var rain_width := maxf(flight_layer.size.x, 320.0)
	var rain_height := maxf(flight_layer.size.y, 1080.0)
	pigeon.position = Vector2(randf_range(72.0, rain_width - 168.0), -160.0)
	pigeon.rotation = randf_range(-0.35, 0.35)
	flight_layer.add_child(pigeon)
	var target := Vector2(
		pigeon.position.x + randf_range(-130.0, 130.0),
		rain_height + 170.0
	)
	var duration := randf_range(1.5, 2.1)
	var fall := create_tween().set_parallel(true)
	fall.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(pigeon, "position", target, duration)
	fall.tween_property(pigeon, "rotation", pigeon.rotation + randf_range(-2.5, 2.5), duration)
	await fall.finished
	if is_instance_valid(pigeon):
		pigeon.queue_free()


## 头顶的气泡只出现一次，出现之后不再消失、也不再重播。
func _show_full_bubble() -> void:
	if _full_bubble != null and is_instance_valid(_full_bubble):
		return
	bird_call.pitch_scale = 0.5
	bird_call.play()
	_full_bubble = SpeechBubble.new()
	_full_bubble.name = "FullBubble"
	(_full_bubble as SpeechBubble).text = FULL_BUBBLE_TEXT
	finale.add_child(_full_bubble)
	(_full_bubble as SpeechBubble).point_at(_head_anchor())
	_full_bubble.pivot_offset = Vector2(_full_bubble.size.x * 0.5, _full_bubble.size.y)
	_full_bubble.scale = Vector2(0.55, 0.55)
	_full_bubble.modulate.a = 0.0
	var pop := create_tween().set_parallel(true)
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_full_bubble, "scale", Vector2.ONE, 0.26)
	pop.tween_property(_full_bubble, "modulate:a", 1.0, 0.16)


## 头的位置：先取贴图里脑袋所在的比例，再按当前（撑胖后的）缩放换算回来。
func _head_anchor() -> Vector2:
	var center := bird.position + bird.size * 0.5
	var head := bird.position + bird.size * Vector2(0.135, 0.2)
	return center + (head - center) * bird.scale


## 鸽子吃太多了：主文案换成打嗝，立绘横向撑开一圈。
func _become_glutton() -> void:
	_glutton = true
	easter_egg_triggered.emit(Catalog.KESTREL_STUFFED)
	bird_call.pitch_scale = 0.55
	bird_call.play()

	name_label.text = GLUTTON_NAME_TEXT
	name_label.pivot_offset = name_label.size * 0.5
	var burp := create_tween()
	burp.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burp.tween_property(name_label, "scale", Vector2(1.14, 0.9), 0.1)
	burp.tween_property(name_label, "scale", Vector2.ONE, 0.22)

	# hover 动效是按这个 meta 里的基准缩放来算的，撑胖之后基准也得跟着换，
	# 否则鼠标一进一出就把肚子收回去了。
	bird.set_meta(&"ui_button_base_scale", GLUTTON_SCALE)
	var inflate := create_tween()
	inflate.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	inflate.tween_property(bird, "scale", GLUTTON_SCALE * Vector2(1.06, 0.95), 0.16)
	inflate.set_trans(Tween.TRANS_QUAD)
	inflate.tween_property(bird, "scale", GLUTTON_SCALE, 0.2)


func _play_level_flyover() -> void:
	var flyer := TextureRect.new()
	flyer.texture = FLY_TEXTURE
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.size = Vector2(720.0, 720.0)
	flyer.pivot_offset = flyer.size * 0.5
	flight_layer.add_child(flyer)

	var viewport_size := get_viewport_rect().size
	var start_center := Vector2(-360.0, viewport_size.y + 300.0)
	var finish_center := Vector2(viewport_size.x + 360.0, -300.0)
	var arc_control := (start_center + finish_center) * 0.5 + Vector2(-80.0, 90.0)
	flyer.global_position = start_center - flyer.size * 0.5
	flyer.modulate.a = 0.0
	_emit_gu_trail(flyer, 0.9)
	var flight := create_tween().set_parallel(true)
	flight.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flight.tween_method(func(progress: float) -> void:
		var point := _quadratic_bezier(start_center, arc_control, finish_center, progress)
		flyer.global_position = point - flyer.size * 0.5
	, 0.0, 1.0, 0.9)
	flight.tween_property(flyer, "modulate:a", 1.0, 0.12)
	flight.tween_property(flyer, "modulate:a", 0.0, 0.16).set_delay(0.74)
	flight.tween_property(flyer, "scale", Vector2(1.12, 1.12), 0.9)
	await flight.finished
	if is_instance_valid(flyer):
		flyer.queue_free()


func _emit_gu_trail(flyer: TextureRect, duration: float) -> void:
	var deadline := Time.get_ticks_msec() + roundi(duration * 1000.0)
	while is_instance_valid(flyer) and Time.get_ticks_msec() < deadline:
		_spawn_gu_particle(flyer)
		await get_tree().create_timer(0.032).timeout


func _spawn_gu_particle(flyer: TextureRect) -> void:
	var particle := Label.new()
	particle.text = "咕"
	particle.size = Vector2(110.0, 110.0)
	particle.pivot_offset = particle.size * 0.5
	particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	particle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	particle.add_theme_font_size_override("font_size", randi_range(46, 78))
	var start_color := Color(1.0, randf_range(0.68, 0.9), 0.35, 1.0)
	var finish_color := Color.from_hsv(randf(), randf_range(0.58, 0.88), 1.0, 1.0)
	particle.add_theme_color_override("font_color", start_color)
	particle.set_meta(&"gu_start_color", start_color)
	particle.add_theme_color_override("font_outline_color", Color(0.15, 0.035, 0.02, 0.92))
	particle.add_theme_constant_override("outline_size", 8)
	particle.z_index = -1
	flight_layer.add_child(particle)
	var flight_direction := Vector2(1.0, -0.72).normalized()
	var flyer_center := flyer.global_position + flyer.size * 0.5
	var trail_center := flyer_center - flight_direction * randf_range(150.0, 230.0)
	particle.global_position = trail_center - particle.size * 0.5 + Vector2(randf_range(-34.0, 34.0), randf_range(-34.0, 34.0))
	particle.rotation = randf_range(-0.24, 0.24)
	particle.scale = Vector2(0.72, 0.72)
	var drift := Vector2(randf_range(-90.0, -35.0), randf_range(25.0, 95.0))
	var puff := create_tween().set_parallel(true)
	puff.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	puff.tween_property(particle, "position", particle.position + drift, 0.56)
	puff.tween_property(particle, "scale", Vector2(1.35, 1.35), 0.56)
	puff.tween_method(func(progress: float) -> void:
		var color := start_color.lerp(finish_color, progress)
		color.a = 1.0 - clampf((progress - 0.25) / 0.75, 0.0, 1.0)
		particle.add_theme_color_override("font_color", color)
	, 0.0, 1.0, 0.56)
	await puff.finished
	if is_instance_valid(particle):
		particle.queue_free()


func _quadratic_bezier(start: Vector2, control: Vector2, finish: Vector2, progress: float) -> Vector2:
	var inverse := 1.0 - progress
	return inverse * inverse * start + 2.0 * inverse * progress * control + progress * progress * finish


func present() -> void:
	# 重开这一页要回到掠过模式，上一轮没落完的鸽子也一并清掉。
	_flyover_count = 0
	_pigeon_count = 0
	_glutton = false
	name_label.text = _name_home_text
	name_label.scale = Vector2.ONE
	if _full_bubble != null and is_instance_valid(_full_bubble):
		_full_bubble.queue_free()
	_full_bubble = null
	ButtonMotion.reset(bird)
	for leftover in flight_layer.get_children():
		leftover.queue_free()
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


func _animate_text(label: Label, target_position: Vector2, delay: float) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", target_position, 0.34).set_delay(delay)
	tween.tween_property(label, "modulate:a", 1.0, 0.2).set_delay(delay)


## 立绘头顶的对话气泡：圆角框 + 指向脑袋的小尾巴，都是画出来的。
class SpeechBubble extends Control:
	const PADDING := Vector2(34.0, 20.0)
	const TAIL_WIDTH := 30.0
	const TAIL_HEIGHT := 26.0
	const FONT_SIZE := 46

	var text := ""

	var _label: Label


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label = Label.new()
		_label.text = text
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.add_theme_font_size_override("font_size", FONT_SIZE)
		_label.add_theme_color_override("font_color", Color(0.16, 0.12, 0.08))
		add_child(_label)
		_label.reset_size()
		_label.position = PADDING
		size = _label.size + PADDING * 2.0
		queue_redraw()


	## 把气泡摆到目标点正上方，尾巴尖正好落在目标点上。
	func point_at(target: Vector2) -> void:
		position = Vector2(target.x - size.x * 0.5, target.y - size.y - TAIL_HEIGHT)


	func _draw() -> void:
		var body := Rect2(Vector2.ZERO, size)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.99, 0.97, 0.9, 0.97)
		style.border_color = Color(0.16, 0.12, 0.08)
		style.set_border_width_all(4)
		style.set_corner_radius_all(18)
		style.draw(get_canvas_item(), body)
		# 尾巴单独画：先描边再填色，接缝压在气泡底边下面看不出来。
		var tip := Vector2(size.x * 0.5, size.y + TAIL_HEIGHT)
		var left := Vector2(size.x * 0.5 - TAIL_WIDTH * 0.5, size.y - 3.0)
		var right := Vector2(size.x * 0.5 + TAIL_WIDTH * 0.5, size.y - 3.0)
		draw_colored_polygon(
			PackedVector2Array([left + Vector2(-4, 0), tip + Vector2(0, 5), right + Vector2(4, 0)]),
			Color(0.16, 0.12, 0.08)
		)
		draw_colored_polygon(
			PackedVector2Array([left, tip, right]), Color(0.99, 0.97, 0.9, 0.97)
		)
