class_name StartScreen
extends Control

signal start_requested
signal achievements_requested
signal credits_requested
signal clear_save_requested
signal abandon_run_requested
signal duel_host_requested
signal duel_join_requested

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
@onready var clear_save_button: Button = %ClearSaveButton
@onready var clear_confirmation: Control = %ClearConfirmation
@onready var clear_card: PanelContainer = %ClearCard
@onready var clear_dimmer: ColorRect = %ClearDimmer
@onready var clear_confirm_button: Button = %ClearConfirmButton
@onready var clear_cancel_button: Button = %ClearCancelButton
@onready var title: Label = $Menu/Title
@onready var bouncers: Array[Node] = [
	$Menu/StartSlot/Swing, $Menu/AchievementsSlot/Swing, $Menu/CreditsSlot/Swing
]
@onready var achievement_banner: TextureRect = %Banner
@onready var achievement_count: Label = %Count
@onready var confirm_eyebrow: Label = $ClearConfirmation/Center/ClearCard/Margin/Stack/Eyebrow
@onready var confirm_title: Label = $ClearConfirmation/Center/ClearCard/Margin/Stack/Title
@onready var confirm_message: Label = $ClearConfirmation/Center/ClearCard/Margin/Stack/Message

## 「放弃本轮」是运行时挂上去的，不在场景里：这一屏的 .tscn 常年开在编辑器里，
## 编辑器一保存就会把外部改过的节点抹掉。按钮的样式全部从「清除存档」身上抄，
## 所以改那颗按钮的皮，这颗跟着变。
var abandon_run_button: Button
var duel_host_button: Button
var duel_join_button: Button

## 有存档时开始按钮整颗换成绿色：金色=开新局，绿色=接着上次。两套只差底色和描边，
## 形状／圆角／投影都是从场景那套复制出来的。
const CONTINUE_BG := Color(0.482, 0.635, 0.247)
const CONTINUE_BG_HOVER := Color(0.573, 0.737, 0.318)
const CONTINUE_BG_PRESSED := Color(0.376, 0.514, 0.192)
const CONTINUE_BORDER := Color(0.224, 0.325, 0.137)

enum ConfirmKind {CLEAR_SAVE, ABANDON_RUN}

## 两个动作共用同一张确认卡，只换文案：一张卡的进出场动画不必写两遍。
const CONFIRM_COPY := {
	ConfirmKind.CLEAR_SAVE: {
		"eyebrow": "单槽存档管理",
		"title": "清除存档？",
		"message": "所有关卡进度、鸟类解锁、道具与成就都会被删除，且无法恢复。",
		"cancel": "保留存档",
		"confirm": "确认清除",
	},
	ConfirmKind.ABANDON_RUN: {
		"eyebrow": "本轮进度",
		"title": "放弃本轮？",
		"message": "本轮的关卡、金币、道具与鸟类解锁会全部清空，从第 1 关重新开始；成就保留。",
		"cancel": "继续本轮",
		"confirm": "确认放弃",
	},
}

var _closing := false
var _title_coaster: TextCoaster
var _bounce_time := 0.0
var _banner_home := 0.0
var _clear_confirmation_closing := false
var _confirm_kind := ConfirmKind.CLEAR_SAVE
var _run_in_progress := false
var _start_styles: Dictionary = {}
var _continue_styles: Dictionary = {}


func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	achievements_button.pressed.connect(_on_achievements_button_pressed)
	credits_button.pressed.connect(_on_credits_button_pressed)
	clear_save_button.pressed.connect(_open_clear_confirmation)
	clear_confirm_button.pressed.connect(_confirm_clear_save)
	clear_cancel_button.pressed.connect(_cancel_clear_save)
	abandon_run_button = _build_abandon_run_button()
	abandon_run_button.pressed.connect(_open_abandon_confirmation)
	_build_duel_slot()
	ButtonMotion.bind(start_button, start_button, -1.0)
	ButtonMotion.bind(achievements_button, achievements_button, -1.0)
	ButtonMotion.bind(credits_button, credits_button, -1.0)
	ButtonMotion.bind(clear_save_button, clear_save_button, 0.8)
	ButtonMotion.bind(abandon_run_button, abandon_run_button, 0.8)
	ButtonMotion.bind(duel_host_button, duel_host_button, -1.0)
	ButtonMotion.bind(duel_join_button, duel_join_button, 0.9)
	ButtonMotion.bind(clear_confirm_button, clear_confirm_button, 0.8)
	ButtonMotion.bind(clear_cancel_button, clear_cancel_button, -0.8)
	_build_start_button_palettes()
	# 过山车是 _ready 里挂上去的最后一个子节点，默认画在确认卡前面——标题的字和
	# 「9」会浮在卡片上。抬一层 z 让卡片始终盖住它。
	clear_confirmation.z_index = 10
	clear_confirmation.visible = false
	clear_save_button.visible = false
	set_run_in_progress(false)
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


## 贴在开始按钮右边的次要动作。锚在槽位的右边缘上，槽位怎么排它都跟着走；不进
## Swing 层，所以开始按钮蹦的时候它自己是稳的。
func _build_abandon_run_button() -> Button:
	var button := Button.new()
	button.name = "AbandonRunButton"
	button.text = "放弃本轮"
	button.visible = false
	button.disabled = true
	button.tooltip_text = "清空本轮进度，从第 1 关重新开始；成就保留"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(206, 58)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 0.5
	button.anchor_bottom = 0.5
	button.offset_left = 18.0
	button.offset_right = 224.0
	button.offset_top = -29.0
	button.offset_bottom = 29.0
	button.grow_horizontal = Control.GROW_DIRECTION_END
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, clear_save_button.get_theme_stylebox(state))
	for color_name in ["font_color", "font_hover_color", "font_outline_color"]:
		button.add_theme_color_override(color_name, clear_save_button.get_theme_color(color_name))
	button.add_theme_constant_override(
		"outline_size", clear_save_button.get_theme_constant("outline_size")
	)
	button.add_theme_font_size_override("font_size", 26)
	$Menu/StartSlot.add_child(button)
	return button


## 在菜单列末尾接一排对战入口。样式整套抄「制作人员」那颗按钮，免得手写一份主题
## 又和标题页跑偏。Menu 是 VBoxContainer，往里加一个槽位是安全操作。
func _build_duel_slot() -> void:
	var credits_slot := $Menu/CreditsSlot as Control
	var slot := Control.new()
	slot.name = "DuelSlot"
	slot.custom_minimum_size = credits_slot.custom_minimum_size
	$Menu.add_child(slot)

	var row := HBoxContainer.new()
	row.name = "DuelRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(row)

	duel_host_button = _build_duel_button("DuelHostButton", "创建对战", "在本机开一个对战房间，等对手连入")
	duel_join_button = _build_duel_button("DuelJoinButton", "加入对战", "连上本机已经开好的对战房间")
	row.add_child(duel_host_button)
	row.add_child(duel_join_button)
	duel_host_button.pressed.connect(func() -> void: duel_host_requested.emit())
	duel_join_button.pressed.connect(func() -> void: duel_join_requested.emit())


func _build_duel_button(node_name: String, text: String, tip: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.tooltip_text = tip
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(240, 62)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, credits_button.get_theme_stylebox(state))
	for color_name in ["font_color", "font_hover_color", "font_outline_color"]:
		button.add_theme_color_override(color_name, credits_button.get_theme_color(color_name))
	button.add_theme_constant_override("outline_size", credits_button.get_theme_constant("outline_size"))
	button.add_theme_font_size_override("font_size", 28)
	return button


func _build_start_button_palettes() -> void:
	for state in ["normal", "hover", "pressed"]:
		var base := start_button.get_theme_stylebox(state) as StyleBoxFlat
		_start_styles[state] = base
		var tinted := base.duplicate() as StyleBoxFlat
		match state:
			"hover":
				tinted.bg_color = CONTINUE_BG_HOVER
			"pressed":
				tinted.bg_color = CONTINUE_BG_PRESSED
			_:
				tinted.bg_color = CONTINUE_BG
		tinted.border_color = CONTINUE_BORDER
		_continue_styles[state] = tinted


func set_save_available(value: bool) -> void:
	clear_save_button.visible = value
	clear_save_button.disabled = not value
	if not value:
		clear_confirmation.visible = false
		_clear_confirmation_closing = false


## 「有存档」和「有一轮打到一半」是两件事：成就和进度存在同一个文件里，所以清完
## 本轮之后存档还在，只是这一组按钮要收回去。
func set_run_in_progress(value: bool) -> void:
	_run_in_progress = value
	start_button.text = "继续游戏" if value else "开始游戏"
	for state in _start_styles:
		var styles: Dictionary = _continue_styles if value else _start_styles
		start_button.add_theme_stylebox_override(state, styles[state])
	abandon_run_button.visible = value
	abandon_run_button.disabled = not value
	if not value and _confirm_kind == ConfirmKind.ABANDON_RUN:
		clear_confirmation.visible = false
		_clear_confirmation_closing = false


func _apply_confirmation_copy(kind: int) -> void:
	var copy: Dictionary = CONFIRM_COPY[kind]
	confirm_eyebrow.text = copy["eyebrow"]
	confirm_title.text = copy["title"]
	confirm_message.text = copy["message"]
	clear_cancel_button.text = copy["cancel"]
	clear_confirm_button.text = copy["confirm"]


func _open_clear_confirmation() -> void:
	await _open_confirmation(ConfirmKind.CLEAR_SAVE)


func _open_abandon_confirmation() -> void:
	await _open_confirmation(ConfirmKind.ABANDON_RUN)


func _open_confirmation(kind: int) -> void:
	var trigger := _confirmation_trigger(kind)
	if _closing or trigger.disabled or clear_confirmation.visible:
		return
	_confirm_kind = kind
	_apply_confirmation_copy(kind)
	trigger.disabled = true
	clear_confirmation.visible = true
	clear_dimmer.modulate.a = 0.0
	await get_tree().process_frame
	clear_card.pivot_offset = clear_card.size * 0.5
	clear_card.scale = Vector2(0.86, 0.86)
	clear_card.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(clear_dimmer, "modulate:a", 1.0, 0.18)
	tween.tween_property(clear_card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK)
	tween.tween_property(clear_card, "modulate:a", 1.0, 0.16)
	clear_cancel_button.grab_focus()


func _confirm_clear_save() -> void:
	await _close_clear_confirmation(true)


func _cancel_clear_save() -> void:
	await _close_clear_confirmation(false)


func _close_clear_confirmation(confirmed: bool) -> void:
	if not clear_confirmation.visible or _clear_confirmation_closing:
		return
	_clear_confirmation_closing = true
	clear_confirm_button.disabled = true
	clear_cancel_button.disabled = true
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(clear_dimmer, "modulate:a", 0.0, 0.16)
	tween.tween_property(clear_card, "scale", Vector2(0.92, 0.92), 0.16)
	tween.tween_property(clear_card, "modulate:a", 0.0, 0.13)
	await tween.finished
	clear_confirmation.visible = false
	clear_card.scale = Vector2.ONE
	clear_card.modulate = Color.WHITE
	clear_dimmer.modulate = Color.WHITE
	clear_confirm_button.disabled = false
	clear_cancel_button.disabled = false
	_clear_confirmation_closing = false
	var trigger := _confirmation_trigger(_confirm_kind)
	if not confirmed:
		trigger.disabled = false
		return
	# 按钮先收起来，外面处理完再通过 set_save_available / set_run_in_progress 决定
	# 它还该不该在。
	trigger.visible = false
	if _confirm_kind == ConfirmKind.CLEAR_SAVE:
		clear_save_requested.emit()
	else:
		abandon_run_requested.emit()


func _confirmation_trigger(kind: int) -> Button:
	return clear_save_button if kind == ConfirmKind.CLEAR_SAVE else abandon_run_button


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
