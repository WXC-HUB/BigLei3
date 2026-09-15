class_name DoveUnlock
extends Control
## 斑鸠解锁页。斑鸠是出了名的窝搭得潦草——几根枝随手一架就算数，彩蛋就演这个：
## 每撩一次立绘，它就叼一根树枝丢到窝位上，角度全凭心情，越堆越像一摊柴火。
## 堆到最后一根，红隼从右边俯冲进来把它叼走，副标题当场改成「好吃」。

## 页面里的彩蛋被触发，带上对应的成就 id。
signal easter_egg_triggered(achievement_id: String)

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const RevealMotion := preload("res://scripts/ui/unlock_reveal_motion.gd")
const Catalog := preload("res://scripts/game/achievement_catalog.gd")
const TWIG_TEXTURE := preload("res://my_asset/dove_twig.png")
## 红隼用局内那张大图，和它自己的无敌演出是同一只。
const KESTREL_TEXTURE := preload("res://my_asset/birds/eg_fly_big.png")
## 筑巢演出借用局内那套动作帧：叼着枝站、叼着枝走、飞（两帧）。
const ACTION_FRAMES: Array[Texture2D] = [
	preload("res://my_asset/birds/dove_action_1.png"),
	preload("res://my_asset/birds/dove_action_2.png"),
	preload("res://my_asset/birds/dove_action_3.png"),
	preload("res://my_asset/birds/dove_action_4.png"),
]

## 丢几根枝之后红隼来收工。
const TWIGS_TO_NEST := 7
## 一次「叼过去—丢下—回原位」各段的时长；测试和截图工具按这些值等。
const TWIG_LEAN_TIME := 0.13
const TWIG_DROP_TIME := 0.17
const TWIG_RETURN_TIME := 0.15
## 红隼：俯冲多久、叼住停多久、带着飞出画面多久。
const SNATCH_DIVE_TIME := 0.42
const SNATCH_HOLD := 0.26
const SNATCH_EXIT_TIME := 0.5
const SNATCHED_TAGLINE_TEXT := "好 吃"
## 叼枝时斑鸠朝窝位挪多少。
const LEAN_OFFSET := Vector2(-64.0, 30.0)

@onready var bird: TextureRect = $Finale/Bird
@onready var finale: Control = $Finale
@onready var name_label: Label = $Finale/Name
@onready var tagline_label: Label = $Finale/Tagline
@onready var effect_label: Label = $Finale/Effect
@onready var continue_button: Button = $Finale/Continue
@onready var bird_call: AudioStreamPlayer = $BirdCall
@onready var kestrel_cry: AudioStreamPlayer = $KestrelCry
@onready var nest_layer: Control = $NestLayer
@onready var nest_spot: Control = $NestSpot

var _twigs := 0
var _busy := false
var _snatched := false
var _bird_home := Vector2.ZERO
var _idle_texture: Texture2D
var _tagline_home_text := ""


func _ready() -> void:
	visible = false
	RevealMotion.prepare(finale, bird, [name_label, tagline_label, effect_label], continue_button)
	ButtonMotion.bind(continue_button, continue_button, 1.0)
	ButtonMotion.bind_hover(bird, bird, 1.6)
	continue_button.mouse_entered.connect(_play_coo)
	bird.mouse_entered.connect(_on_bird_hovered)
	_bird_home = bird.position
	_idle_texture = bird.texture
	_tagline_home_text = tagline_label.text
	_reset_egg()


func _play_coo(pitch: float = -1.0) -> void:
	bird_call.pitch_scale = randf_range(0.94, 1.08) if pitch < 0.0 else pitch
	bird_call.play()


func twig_count() -> int:
	return _twigs


func is_snatched() -> bool:
	return _snatched


## 从最后一根枝落地到红隼把它叼出画面大约要多久，给等待方一个准数。
static func snatch_duration() -> float:
	return SNATCH_DIVE_TIME + SNATCH_HOLD + SNATCH_EXIT_TIME


## 一次叼枝要多久（不含红隼那一段）。
static func twig_duration() -> float:
	return TWIG_LEAN_TIME + TWIG_DROP_TIME + TWIG_RETURN_TIME


func _on_bird_hovered() -> void:
	if _busy or _snatched:
		return
	_fetch_one_twig()


# ---------------------------------------------------------------------------
# 一根一根往窝上丢
# ---------------------------------------------------------------------------


func _fetch_one_twig() -> void:
	_busy = true
	_twigs += 1
	_play_coo()

	# 叼着枝凑过去（帧 1 站姿叼枝 → 帧 2 走姿叼枝）。
	bird.texture = ACTION_FRAMES[0]
	var lean := create_tween()
	lean.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lean.tween_property(bird, "position", _bird_home + LEAN_OFFSET, TWIG_LEAN_TIME)
	await lean.finished

	bird.texture = ACTION_FRAMES[1]
	_drop_twig()
	await get_tree().create_timer(TWIG_DROP_TIME).timeout

	if _twigs >= TWIGS_TO_NEST:
		await _kestrel_snatch()
		return
	bird.texture = _idle_texture
	var back := create_tween()
	back.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	back.tween_property(bird, "position", _bird_home, TWIG_RETURN_TIME)
	await back.finished
	_busy = false


## 一根枝翻着落到窝位上，落点和角度都随便——斑鸠本来也不讲究。
func _drop_twig() -> void:
	var twig := TextureRect.new()
	twig.texture = TWIG_TEXTURE
	twig.size = Vector2(210.0, 140.0)
	twig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	twig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	twig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	twig.pivot_offset = twig.size * 0.5
	var landing := nest_spot.position + nest_spot.size * 0.5 + Vector2(
		randf_range(-nest_spot.size.x * 0.3, nest_spot.size.x * 0.3),
		randf_range(-nest_spot.size.y * 0.22, nest_spot.size.y * 0.22)
	) - twig.size * 0.5
	twig.position = bird.position + bird.size * Vector2(0.22, 0.5) - twig.size * 0.5
	twig.rotation = randf_range(-0.5, 0.5)
	nest_layer.add_child(twig)
	var drop := create_tween().set_parallel(true)
	drop.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(twig, "position", landing, TWIG_DROP_TIME)
	drop.tween_property(twig, "rotation", randf_range(-1.2, 1.2), TWIG_DROP_TIME)
	await drop.finished
	# 落地那下轻轻一弹，堆出「随手一丢」的感觉。
	var settle := create_tween()
	settle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settle.tween_property(twig, "position:y", landing.y - 10.0, 0.07)
	settle.tween_property(twig, "position:y", landing.y, 0.1)


# ---------------------------------------------------------------------------
# 红隼收工
# ---------------------------------------------------------------------------


func _kestrel_snatch() -> void:
	easter_egg_triggered.emit(Catalog.DOVE_SNATCHED)
	var kestrel := TextureRect.new()
	kestrel.name = "Kestrel"
	kestrel.texture = KESTREL_TEXTURE
	kestrel.size = Vector2(620.0, 620.0)
	kestrel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	kestrel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	kestrel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kestrel.pivot_offset = kestrel.size * 0.5
	kestrel.z_index = 8
	nest_layer.add_child(kestrel)

	var snatch_point := bird.position + bird.size * 0.5 - kestrel.size * 0.5
	kestrel.position = Vector2(size.x + kestrel.size.x * 0.4, snatch_point.y - 320.0)
	kestrel_cry.play()
	var dive := create_tween()
	dive.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dive.tween_property(kestrel, "position", snatch_point, SNATCH_DIVE_TIME)
	await dive.finished

	# 叼住了：斑鸠僵在半空，两边一起顿一下。
	bird.texture = ACTION_FRAMES[2]
	_play_coo(1.35)
	tagline_label.modulate.a = 0.0
	tagline_label.text = SNATCHED_TAGLINE_TEXT
	var retitle := create_tween()
	retitle.tween_property(tagline_label, "modulate:a", 1.0, 0.26)
	await get_tree().create_timer(SNATCH_HOLD).timeout

	# 一起往左上飞出画面，斑鸠跟着走。
	var exit_offset := Vector2(-size.x * 0.9, -size.y * 0.55)
	var carry := create_tween().set_parallel(true)
	carry.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	carry.tween_property(kestrel, "position", kestrel.position + exit_offset, SNATCH_EXIT_TIME)
	carry.tween_property(bird, "position", bird.position + exit_offset, SNATCH_EXIT_TIME)
	carry.tween_property(bird, "rotation", -0.5, SNATCH_EXIT_TIME)
	await carry.finished
	bird.visible = false
	_snatched = true
	_busy = false


func _reset_egg() -> void:
	_twigs = 0
	_busy = false
	_snatched = false
	for leftover in nest_layer.get_children():
		leftover.queue_free()
	bird.position = _bird_home
	bird.rotation = 0.0
	bird.visible = true
	bird.texture = _idle_texture
	tagline_label.text = _tagline_home_text
	tagline_label.modulate.a = 1.0


func present() -> void:
	_reset_egg()
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
