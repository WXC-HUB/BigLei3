class_name CrowUnlock
extends Control
## 小嘴乌鸦解锁页。彩蛋顺着副标题往下演：页脚躺着一只睡熟的小猫，撩一次立绘，乌鸦就侧身
## 薅走一撮毛——被薅的那只哼一声溜走，换下一只躺过来，副标题跟着改口：
## 薅小猫毛 → 薅小狗毛 → 薅小羊毛 → 薅小马毛 → 薅小鹿毛 → 薅狐狸毛 → 薅熊猫毛。
## 薅到熊猫就踢到铁板了：熊猫瞪眼追上来，一鸟一熊绕着整个屏幕跑几圈，跑完乌鸦灰溜溜回原位，
## 熊猫往它旁边一坐不走了。之后再撩，只剩熊猫作势扑一下。

## 页面里的彩蛋被触发，带上对应的成就 id。
signal easter_egg_triggered(achievement_id: String)

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const RevealMotion := preload("res://scripts/ui/unlock_reveal_motion.gd")
const Catalog := preload("res://scripts/game/achievement_catalog.gd")
const TUFT_TEXTURE := preload("res://my_asset/crow_fur_tuft.png")
const PANDA_ANGRY_TEXTURE := preload("res://my_asset/crow_victim_panda_angry.png")
## 薅毛演出借用局内那套动作帧：探身、薅下、僵住、逃走。
const ACTION_FRAMES: Array[Texture2D] = [
	preload("res://my_asset/birds/crow_action_1.png"),
	preload("res://my_asset/birds/crow_action_2.png"),
	preload("res://my_asset/birds/crow_action_3.png"),
	preload("res://my_asset/birds/crow_action_4.png"),
]

## 一路薅下去的名单：贴图、副标题里的名字、毛的颜色（飞出来那撮按它染色）、惨叫的音高。
## 最后一位是熊猫——薅到它就没有下一只了，只有一场追逐。
const VICTIMS: Array[Dictionary] = [
	{"texture": preload("res://my_asset/crow_victim_cat.png"), "name": "小猫", "fur": Color(0.77, 0.75, 0.73), "pitch": 1.0},
	{"texture": preload("res://my_asset/crow_victim_dog.png"), "name": "小狗", "fur": Color(0.83, 0.67, 0.47), "pitch": 0.82},
	{"texture": preload("res://my_asset/crow_victim_sheep.png"), "name": "小羊", "fur": Color(0.96, 0.95, 0.93), "pitch": 1.16},
	{"texture": preload("res://my_asset/crow_victim_horse.png"), "name": "小马", "fur": Color(0.64, 0.45, 0.31), "pitch": 0.72},
	{"texture": preload("res://my_asset/crow_victim_deer.png"), "name": "小鹿", "fur": Color(0.78, 0.58, 0.39), "pitch": 0.96},
	{"texture": preload("res://my_asset/crow_victim_fox.png"), "name": "狐狸", "fur": Color(0.89, 0.5, 0.24), "pitch": 1.08},
	{"texture": preload("res://my_asset/crow_victim_panda.png"), "name": "熊猫", "fur": Color(0.97, 0.96, 0.95), "pitch": 0.62},
]

## 一次「探身—薅下—换下一只」各段的时长；测试和截图工具按这些值等。
const PLUCK_LEAN_TIME := 0.13
const PLUCK_YANK_TIME := 0.14
const SWAP_OUT_TIME := 0.24
const SWAP_IN_TIME := 0.3
## 追逐：僵住多久、每圈多久、跑几圈、收尾多久。
const CHASE_FREEZE_TIME := 0.38
const CHASE_LAP_TIME := 1.3
const CHASE_LAPS := 2
const CHASE_SETTLE_TIME := 0.5
const CHASED_TAGLINE_TEXT := "薅 错 了"
## 乌鸦探身薅毛时朝被薅的那只挪多少。
const LEAN_OFFSET := Vector2(-58.0, 28.0)

@onready var bird: TextureRect = $Finale/Bird
@onready var finale: Control = $Finale
@onready var name_label: Label = $Finale/Name
@onready var tagline_label: Label = $Finale/Tagline
@onready var effect_label: Label = $Finale/Effect
@onready var continue_button: Button = $Finale/Continue
@onready var bird_call: AudioStreamPlayer = $BirdCall
@onready var animal_yelp: AudioStreamPlayer = $AnimalYelp
@onready var stand: TextureRect = $AnimalStand
@onready var fur_layer: Control = $FurLayer

var _plucked := 0
var _busy := false
var _chased := false
var _bird_home := Vector2.ZERO
var _stand_home := Vector2.ZERO
var _idle_texture: Texture2D


func _ready() -> void:
	visible = false
	RevealMotion.prepare(finale, bird, [name_label, tagline_label, effect_label], continue_button)
	ButtonMotion.bind(continue_button, continue_button, 1.0)
	ButtonMotion.bind_hover(bird, bird, 1.6)
	continue_button.mouse_entered.connect(_play_call)
	bird.mouse_entered.connect(_on_bird_hovered)
	_bird_home = bird.position
	_stand_home = stand.position
	_idle_texture = bird.texture
	_reset_egg()


func _play_call(pitch: float = -1.0) -> void:
	bird_call.pitch_scale = randf_range(0.92, 1.1) if pitch < 0.0 else pitch
	bird_call.play()


## 已经薅了几只。
func plucked_count() -> int:
	return _plucked


## 现在躺在页脚的是第几只（薅完最后一只就停在熊猫上）。
func current_victim() -> Dictionary:
	return VICTIMS[mini(_plucked, VICTIMS.size() - 1)]


func is_chased() -> bool:
	return _chased


## 从薅完熊猫到两边都停下来大约要多久，给等待方一个准数。
static func chase_duration() -> float:
	return CHASE_FREEZE_TIME + CHASE_LAP_TIME * CHASE_LAPS + CHASE_SETTLE_TIME


## 一次薅毛要多久（不含换下一只）。
static func pluck_duration() -> float:
	return PLUCK_LEAN_TIME + PLUCK_YANK_TIME


func _on_bird_hovered() -> void:
	if _busy:
		return
	if _chased:
		_panda_lunges()
		return
	_pluck_one()


# ---------------------------------------------------------------------------
# 一只一只薅过去
# ---------------------------------------------------------------------------


func _pluck_one() -> void:
	_busy = true
	var victim: Dictionary = VICTIMS[_plucked]
	_plucked += 1
	_play_call()

	# 侧身探过去（帧 5）。
	bird.texture = ACTION_FRAMES[0]
	var lean := create_tween()
	lean.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lean.tween_property(bird, "position", _bird_home + LEAN_OFFSET, PLUCK_LEAN_TIME)
	await lean.finished

	# 薅下来（帧 6）：飞出一撮它自己颜色的毛，被薅的那只哼一声、抖一下。
	bird.texture = ACTION_FRAMES[1]
	_spawn_tuft(victim["fur"])
	animal_yelp.pitch_scale = float(victim["pitch"])
	animal_yelp.play()
	stand.pivot_offset = stand.size * Vector2(0.3, 0.9)
	var twitch := create_tween()
	twitch.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	twitch.tween_property(stand, "rotation", 0.035, PLUCK_YANK_TIME * 0.45)
	twitch.tween_property(stand, "rotation", 0.0, PLUCK_YANK_TIME * 0.55)
	await twitch.finished

	if _plucked >= VICTIMS.size():
		await _panda_gives_chase()
		return

	bird.texture = _idle_texture
	var back := create_tween()
	back.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	back.tween_property(bird, "position", _bird_home, SWAP_OUT_TIME)
	await _swap_in_next_victim()
	_busy = false


## 被薅的那只捂着毛往左边溜走，下一只从左边慢慢躺进来，副标题跟着改口。
func _swap_in_next_victim() -> void:
	var leaving := create_tween().set_parallel(true)
	leaving.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	leaving.tween_property(stand, "position:x", _stand_home.x - stand.size.x - 80.0, SWAP_OUT_TIME)
	leaving.tween_property(stand, "modulate:a", 0.0, SWAP_OUT_TIME)
	await leaving.finished

	var next: Dictionary = VICTIMS[_plucked]
	stand.texture = next["texture"]
	tagline_label.text = "薅 %s 毛" % String(next["name"])
	stand.position = Vector2(_stand_home.x - stand.size.x * 0.55, _stand_home.y)
	var arriving := create_tween().set_parallel(true)
	arriving.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	arriving.tween_property(stand, "position", _stand_home, SWAP_IN_TIME)
	arriving.tween_property(stand, "modulate:a", 1.0, SWAP_IN_TIME * 0.6)
	await arriving.finished


## 一撮毛从被薅的那只身上飞出来，按它的毛色染过，一边转一边飘走。
func _spawn_tuft(fur: Color) -> void:
	var tuft := TextureRect.new()
	tuft.texture = TUFT_TEXTURE
	tuft.modulate = fur
	tuft.size = Vector2(150.0, 150.0)
	tuft.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tuft.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tuft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tuft.pivot_offset = tuft.size * 0.5
	var back := stand.position + stand.size * Vector2(randf_range(0.4, 0.72), 0.3)
	tuft.position = back - tuft.size * 0.5
	tuft.scale = Vector2(0.4, 0.4)
	fur_layer.add_child(tuft)
	var drift := Vector2(randf_range(130.0, 270.0), randf_range(-310.0, -180.0))
	var fly := create_tween().set_parallel(true)
	fly.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fly.tween_property(tuft, "position", tuft.position + drift, 0.8)
	fly.tween_property(tuft, "scale", Vector2.ONE, 0.28)
	fly.tween_property(tuft, "rotation", randf_range(-2.4, 2.4), 0.8)
	fly.tween_property(tuft, "modulate:a", 0.0, 0.32).set_delay(0.48)
	await fly.finished
	if is_instance_valid(tuft):
		tuft.queue_free()


# ---------------------------------------------------------------------------
# 薅到熊猫：绕着屏幕跑
# ---------------------------------------------------------------------------


## 追逐路线：绕屏幕一圈的几个点，首尾相接。缩进量按两个跑动者里较大的那半个身位留，
## 不然跑到上边和左右边时熊猫和乌鸦会被切在画外。
func _chase_loop() -> PackedVector2Array:
	var margin := maxf(bird.size.x, stand.size.x) * 0.5 + 40.0
	var inset := Vector2(
		clampf(size.x * 0.22, margin, size.x * 0.45),
		clampf(size.y * 0.34, maxf(bird.size.y, stand.size.y) * 0.5 + 30.0, size.y * 0.45)
	)
	return PackedVector2Array([
		Vector2(size.x - inset.x, size.y - inset.y),
		Vector2(size.x - inset.x * 0.86, inset.y),
		Vector2(size.x * 0.5, inset.y * 0.92),
		Vector2(inset.x, inset.y),
		Vector2(inset.x * 0.9, size.y - inset.y),
		Vector2(size.x * 0.5, size.y - inset.y * 0.86),
	])


## 沿路线走：`t` 以圈为单位，0.5 就是跑了半圈。
func _loop_point(loop: PackedVector2Array, t: float) -> Vector2:
	var total := float(loop.size())
	var travelled := fposmod(t, 1.0) * total
	var index := int(travelled)
	var blend := travelled - float(index)
	return loop[index].lerp(loop[(index + 1) % loop.size()], blend)


func _panda_gives_chase() -> void:
	easter_egg_triggered.emit(Catalog.CROW_CHASED_BY_PANDA)
	# 熊猫瞪起眼睛弹起来。
	stand.texture = PANDA_ANGRY_TEXTURE
	animal_yelp.pitch_scale = 0.55
	animal_yelp.play()
	stand.pivot_offset = stand.size * Vector2(0.3, 0.9)
	var rear := create_tween()
	rear.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rear.tween_property(stand, "scale", Vector2(1.14, 1.16), 0.14)
	rear.tween_property(stand, "scale", Vector2.ONE, 0.22)

	# 追逐要跨过整个页面，熊猫得压在那几个大字上面，否则跑到中间就被标题吞了。
	stand.z_index = 6
	# 乌鸦当场僵住（帧 7）。
	bird.texture = ACTION_FRAMES[2]
	await get_tree().create_timer(CHASE_FREEZE_TIME).timeout

	# 满屏幕跑：乌鸦在前，熊猫咬在后面一点点。
	bird.texture = ACTION_FRAMES[3]
	_play_call(0.8)
	var loop := _chase_loop()
	var bird_centre := bird.size * 0.5
	var stand_centre := stand.size * 0.5
	var last_bird := _loop_point(loop, 0.0)
	var run := create_tween()
	run.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	run.tween_method(func(t: float) -> void:
		var here := _loop_point(loop, t)
		bird.position = here - bird_centre
		# 面朝跑的方向；素材本来朝左，往右跑就翻面。
		if absf(here.x - last_bird.x) > 0.5:
			bird.flip_h = here.x > last_bird.x
		bird.rotation = clampf((here.x - last_bird.x) * 0.012, -0.3, 0.3)
		last_bird = here
		var behind := _loop_point(loop, t - 0.13)
		stand.position = behind - stand_centre
		stand.flip_h = _loop_point(loop, t - 0.11).x > behind.x
	, 0.0, float(CHASE_LAPS), CHASE_LAP_TIME * CHASE_LAPS)
	await run.finished

	# 跑够了：乌鸦灰溜溜回原位，熊猫往它旁边一坐，盯着。
	bird.texture = _idle_texture
	bird.flip_h = false
	tagline_label.text = CHASED_TAGLINE_TEXT
	var settle := create_tween().set_parallel(true)
	settle.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle.tween_property(bird, "position", _bird_home, CHASE_SETTLE_TIME)
	settle.tween_property(bird, "rotation", 0.0, CHASE_SETTLE_TIME)
	settle.tween_property(stand, "position", _stand_home, CHASE_SETTLE_TIME)
	await settle.finished
	stand.flip_h = false
	stand.z_index = 0
	_chased = true
	_busy = false


## 收场之后再撩：熊猫作势扑一下，乌鸦缩一下脖子。
func _panda_lunges() -> void:
	_play_call(0.74)
	var lunge := create_tween()
	lunge.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lunge.tween_property(stand, "position", _stand_home + Vector2(46.0, -18.0), 0.1)
	lunge.tween_property(stand, "position", _stand_home, 0.2)
	var flinch := create_tween()
	flinch.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flinch.tween_property(bird, "position", _bird_home + Vector2(34.0, -20.0), 0.1)
	flinch.tween_property(bird, "position", _bird_home, 0.18)


func _reset_egg() -> void:
	_plucked = 0
	_busy = false
	_chased = false
	for leftover in fur_layer.get_children():
		leftover.queue_free()
	stand.texture = VICTIMS[0]["texture"]
	stand.position = _stand_home
	stand.rotation = 0.0
	stand.scale = Vector2.ONE
	stand.flip_h = false
	stand.z_index = 0
	stand.modulate = Color.WHITE
	tagline_label.text = "薅 %s 毛" % String(VICTIMS[0]["name"])
	bird.position = _bird_home
	bird.rotation = 0.0
	bird.flip_h = false
	bird.texture = _idle_texture


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
