class_name MagpieUnlock
extends Control
## 灰喜鹊解锁页。彩蛋：每撩一次立绘，整页的图片和文字就更虚焦一点（继续按钮除外）；撩够
## 次数，一副比屏幕还大的黑框眼镜从右边甩进来，只有右镜片落在画面里、正压在它眼睛上——
## 镜片里看见的却不是鸟，是黑长直学姐。之后再撩只会让眼镜晃一晃、镜片眨一下。

## 页面里的彩蛋被触发，带上对应的成就 id。
signal easter_egg_triggered(achievement_id: String)

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const RevealMotion := preload("res://scripts/ui/unlock_reveal_motion.gd")
const Catalog := preload("res://scripts/game/achievement_catalog.gd")
## 撩到第几次眼镜滑进来。
const HOVERS_TO_GLASSES := 6
## 每撩一次多糊多少（屏幕纹理的 mip 级数），以及糊到头的上限。
const BLUR_PER_HOVER := 0.9
const BLUR_MAX := 4.6
const GLASSES_SLIDE_TIME := 0.55
## 眼镜的放大倍数：760 宽的眼镜图放到 3400 多像素，比屏幕宽得多，屏幕里只装得下右镜片。
const GLASSES_SCALE := 4.5
const LENS_FOCUS_TIME := 0.28
## 右镜片圆心在眼镜图里的位置（未放大的图内像素）：对准立绘的眼睛。
const RIGHT_LENS_CENTRE := Vector2(560.0, 150.0)
## 立绘里眼睛大致落在贴图的哪个比例位置。
const EYE_ANCHOR := Vector2(0.75, 0.43)

@onready var bird: TextureRect = $Finale/Bird
@onready var finale: Control = $Finale
@onready var name_label: Label = $Finale/Name
@onready var tagline_label: Label = $Finale/Tagline
@onready var effect_label: Label = $Finale/Effect
@onready var continue_button: Button = $Finale/Continue
@onready var bird_call: AudioStreamPlayer = $BirdCall
@onready var glasses_click: AudioStreamPlayer = $GlassesClick
@onready var veil: ColorRect = $DefocusVeil
@onready var rig: Control = $GlassesRig
@onready var lens_view: TextureRect = $GlassesRig/LensView
@onready var glasses: TextureRect = $GlassesRig/Glasses

var _hover_count := 0
var _glasses_on := false
var _sliding := false


func _ready() -> void:
	visible = false
	RevealMotion.prepare(finale, bird, [name_label, tagline_label, effect_label], continue_button)
	ButtonMotion.bind(continue_button, continue_button, 1.0)
	ButtonMotion.bind_hover(bird, bird, 1.6)
	continue_button.mouse_entered.connect(_play_bird_call)
	bird.mouse_entered.connect(_on_bird_hovered)
	rig.pivot_offset = rig.size * 0.5
	_reset_egg()


func _play_bird_call() -> void:
	bird_call.pitch_scale = randf_range(0.92, 1.1)
	bird_call.play()


func hover_count() -> int:
	return _hover_count


func blur_amount() -> float:
	return float((veil.material as ShaderMaterial).get_shader_parameter("blur_lod"))


func glasses_on() -> bool:
	return _glasses_on


## 从眼镜开始滑到镜片对上焦要多久，给等待方一个准数。
static func glasses_duration() -> float:
	return GLASSES_SLIDE_TIME + LENS_FOCUS_TIME


func _on_bird_hovered() -> void:
	_play_bird_call()
	if _glasses_on:
		_wiggle_glasses()
		return
	if _sliding:
		return
	_hover_count += 1
	_set_blur(minf(_hover_count * BLUR_PER_HOVER, BLUR_MAX))
	if _hover_count >= HOVERS_TO_GLASSES:
		_slide_glasses_in()


func _set_blur(lod: float) -> void:
	(veil.material as ShaderMaterial).set_shader_parameter("blur_lod", lod)
	veil.visible = lod > 0.01


## 眼镜停下来的位置：放大后右镜片的圆心压在立绘的眼睛上，左镜片和镜架大部分都在屏幕外。
## rig 围着自己的中心缩放，所以先算 rig 中心该在哪，再换成左上角。
func glasses_home() -> Vector2:
	var eye := bird.position + bird.size * EYE_ANCHOR
	var centre := eye - (RIGHT_LENS_CENTRE - rig.size * 0.5) * GLASSES_SCALE
	return centre - rig.size * 0.5


func _slide_glasses_in() -> void:
	_sliding = true
	easter_egg_triggered.emit(Catalog.MAGPIE_SENPAI)
	var home := glasses_home()
	rig.visible = true
	# 从右边屏幕外甩进来：起点让整副（放大后的）眼镜都在画面右侧之外。
	var start_scale := GLASSES_SCALE * 1.15
	rig.position = Vector2(size.x + rig.size.x * 0.5 * start_scale, home.y - 70.0) - Vector2(rig.size.x * 0.5, 0.0)
	rig.rotation = -0.22
	rig.scale = Vector2(start_scale, start_scale)
	lens_view.modulate.a = 0.0
	var slide := create_tween().set_parallel(true)
	slide.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slide.tween_property(rig, "position", home, GLASSES_SLIDE_TIME)
	slide.tween_property(rig, "rotation", 0.0, GLASSES_SLIDE_TIME)
	slide.tween_property(rig, "scale", Vector2(GLASSES_SCALE, GLASSES_SCALE), GLASSES_SLIDE_TIME)
	await slide.finished
	glasses_click.play()
	# 镜片一下子对上焦：看清了，是学姐。
	var focus := create_tween()
	focus.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	focus.tween_property(lens_view, "modulate:a", 1.0, LENS_FOCUS_TIME)
	await focus.finished
	_glasses_on = true
	_sliding = false


## 戴上之后再撩：眼镜晃一晃，镜片眨一下。
func _wiggle_glasses() -> void:
	var wobble := create_tween()
	wobble.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 眼镜很大、支点又在屏幕外，转一点点镜片就晃得够明显了。
	wobble.tween_property(rig, "rotation", 0.03, 0.07)
	wobble.tween_property(rig, "rotation", -0.02, 0.1)
	wobble.tween_property(rig, "rotation", 0.0, 0.14)
	lens_view.pivot_offset = lens_view.size * 0.5
	var blink := create_tween()
	blink.tween_property(lens_view, "scale:y", 0.12, 0.07)
	blink.tween_property(lens_view, "scale:y", 1.0, 0.12)


func _reset_egg() -> void:
	_hover_count = 0
	_glasses_on = false
	_sliding = false
	_set_blur(0.0)
	rig.visible = false
	rig.rotation = 0.0
	rig.scale = Vector2(GLASSES_SCALE, GLASSES_SCALE)
	lens_view.modulate.a = 1.0
	lens_view.scale = Vector2.ONE


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
