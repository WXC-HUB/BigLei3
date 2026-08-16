class_name StartScreen
extends Control

signal start_requested
signal achievements_requested
signal credits_requested

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const TextCoaster := preload("res://scripts/ui/text_coaster.gd")

## 三个按钮一直在原地弹跳、轻微晃动、并且颜色在暖色区间里来回漂。动的是槽位里的
## Swing 层，不是按钮本身：按钮的 rotation / scale 归 [ButtonMotion] 的悬停动效管，
## 两处写同一个属性会互相盖掉。Swing 是普通 Control 的子节点，position 不会被容器
## 重排掉，三个通道（位移、旋转、缩放）都能放心写。
##
## 成就按钮是这一屏最想被点到的东西，所以它那一档的跳幅、频率、倾角和变色范围都比
## 另外两个高一截——三行参数摆在一起，谁最闹一眼就能看出来。
##
## 倾角按牌子放大到 1.5 倍之后调小过：同样的角度，牌子越宽边角划过的距离越远，照
## 原来的度数会甩得过头。挤压幅度同理。
const BOUNCES := [
	{"node": "StartSlot", "hop": 7.0, "speed": 2.1, "tilt": 1.5, "hue": 0.030, "sat": 0.09, "glint": 0.04, "phase": 0.0},
	{"node": "AchievementsSlot", "hop": 17.0, "speed": 3.1, "tilt": 2.9, "hue": 0.070, "sat": 0.20, "glint": 0.13, "phase": 0.9},
	{"node": "CreditsSlot", "hop": 6.0, "speed": 1.9, "tilt": 1.4, "hue": 0.028, "sat": 0.08, "glint": 0.035, "phase": 1.9},
]
## 弹跳高度走 |sin|：落地那一下快、顶点飘一飘，才是球在跳而不是上下平移。
## 触地压扁、腾空拉长，这一对挤压回弹是「跳动感」真正的来源。
const SQUASH := 0.075
const STRETCH := 0.04
## 倾角比弹跳慢一截，两个频率错开才不像机械上下。
const TILT_SPEED := 0.62
## 变色的中心色相（金橙一带）和漂移速度。只在暖色窄区间里晃，不会窜到冷色去。
const BASE_HUE := 0.105
const HUE_SPEED := 0.8

## 成就横幅拴在成就按钮右边，箭头指着它。横幅按 BANNER_FOLLOW 的比例跟着按钮的
## 弹跳走——同步得太死会连挤压一起抄过来，完全不动又像两个没关系的东西。
const BANNER_FOLLOW := 0.55
const BANNER_TILT_DEG := 1.8
const BANNER_TILT_SPEED := 1.5
const BANNER_PULSE := 0.045
const BANNER_PULSE_SPEED := 2.4

@onready var start_button: Button = %StartButton
@onready var achievements_button: Button = %AchievementsButton
@onready var credits_button: Button = %CreditsButton
@onready var title: Label = $Menu/Title
@onready var bouncers: Array[Node] = [
	$Menu/StartSlot/Swing, $Menu/AchievementsSlot/Swing, $Menu/CreditsSlot/Swing
]
@onready var achievement_banner: TextureRect = %Banner
@onready var achievement_count: Label = %Count

var _closing := false
var _title_coaster: TextCoaster
var _bounce_time := 0.0
var _banner_home := 0.0


func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	achievements_button.pressed.connect(_on_achievements_button_pressed)
	credits_button.pressed.connect(_on_credits_button_pressed)
	ButtonMotion.bind(start_button, start_button, -1.0)
	ButtonMotion.bind(achievements_button, achievements_button, -1.0)
	ButtonMotion.bind(credits_button, credits_button, -1.0)
	# The coaster sits outside the menu container, which would otherwise try to
	# lay its glyph copies out as menu rows.
	_title_coaster = TextCoaster.new()
	_title_coaster.name = "TitleCoaster"
	add_child(_title_coaster)
	_title_coaster.bind(title)
	# 横幅的静止高度要在第一次动它之前记下来，否则每帧都会在上一帧的偏移上再加一次。
	_banner_home = achievement_banner.position.y
	modulate.a = 0.0
	var intro := create_tween()
	intro.tween_property(self, "modulate:a", 1.0, 0.35)


## 按下开始之后就停跳，让画面安静地淡出。
func _process(delta: float) -> void:
	if _closing:
		return
	_bounce_time += delta
	for index in bouncers.size():
		_animate_bounce(bouncers[index] as Control, BOUNCES[index])
	_animate_banner()


## 外面把已解锁数和总数丢进来，横幅只负责显示；标题页自己不记账。
func set_achievement_progress(unlocked: int, total: int) -> void:
	achievement_count.text = "成就解锁 %d/%d" % [unlocked, total]


func _animate_banner() -> void:
	var swing := bouncers[1] as Control
	achievement_banner.pivot_offset = achievement_banner.size * Vector2(0.15, 0.5)
	achievement_banner.position.y = _banner_home + swing.position.y * BANNER_FOLLOW
	achievement_banner.rotation = deg_to_rad(
		sin(_bounce_time * BANNER_TILT_SPEED) * BANNER_TILT_DEG
	)
	achievement_banner.scale = Vector2.ONE * (
		1.0 + BANNER_PULSE * sin(_bounce_time * BANNER_PULSE_SPEED)
	)


func _animate_bounce(swing: Control, config: Dictionary) -> void:
	var phase: float = _bounce_time * float(config["speed"]) + float(config["phase"])
	# |sin| 的谷底就是触地：lift 为 0 时压到最扁，为 1 时在顶点拉最长。
	var lift := absf(sin(phase))
	var contact := 1.0 - lift
	# 每帧重取支点：容器要到帧末才把宽度定下来，缓存住的第一帧是零宽。轴心压在底边
	# 中点，压扁和倾斜才像一个立着的东西在蹦，而不是绕自己中心打转。
	swing.pivot_offset = Vector2(swing.size.x * 0.5, swing.size.y)
	swing.position.y = -lift * float(config["hop"])
	swing.scale = Vector2(
		1.0 + SQUASH * contact - STRETCH * lift,
		1.0 - SQUASH * contact + STRETCH * lift
	)
	swing.rotation = deg_to_rad(
		sin(phase * TILT_SPEED + float(config["phase"])) * float(config["tilt"])
	)
	var hue := fposmod(
		BASE_HUE + sin(_bounce_time * HUE_SPEED + float(config["phase"])) * float(config["hue"]),
		1.0
	)
	# 亮度跟着跳：顶点最亮，落地收回来，颜色和动作是同一拍。
	swing.modulate = Color.from_hsv(
		hue, float(config["sat"]), 1.0 + float(config["glint"]) * lift
	)


func _on_credits_button_pressed() -> void:
	if _closing:
		return
	credits_requested.emit()


func _on_achievements_button_pressed() -> void:
	if _closing:
		return
	achievements_requested.emit()


func _on_start_button_pressed() -> void:
	if _closing:
		return
	_closing = true
	start_button.disabled = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 标题淡出的时候波形和粒子一起停下，免得最后一帧还在跳。
	_title_coaster.running = false
	var fade := create_tween()
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_property(self, "modulate:a", 0.0, 0.28)
	await fade.finished
	start_requested.emit()
