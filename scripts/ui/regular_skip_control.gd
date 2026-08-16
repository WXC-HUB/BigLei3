class_name RegularSkipControl
extends Control

signal skip_requested
signal skip_confirmed
signal skip_cancelled
signal return_requested
signal return_confirmed
signal return_cancelled

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")

@onready var skip_button: Button = $SkipButton
@onready var return_button: Button = $ReturnButton
@onready var modal: Control = $Confirmation
@onready var dimmer: ColorRect = $Confirmation/Dimmer
@onready var card: PanelContainer = $Confirmation/Center/Card
@onready var eyebrow_label: Label = $Confirmation/Center/Card/Margin/Stack/Eyebrow
@onready var title_label: Label = $Confirmation/Center/Card/Margin/Stack/Title
@onready var message_label: Label = $Confirmation/Center/Card/Margin/Stack/Message
@onready var confirm_button: Button = $Confirmation/Center/Card/Margin/Stack/Actions/Confirm
@onready var cancel_button: Button = $Confirmation/Center/Card/Margin/Stack/Actions/Cancel

enum ConfirmationMode { NONE, SKIP, RETURN_TO_MENU }

var _available := false
var _closing := false
var _confirmation_mode := ConfirmationMode.NONE


func _ready() -> void:
	skip_button.pressed.connect(func() -> void: skip_requested.emit())
	return_button.pressed.connect(func() -> void: return_requested.emit())
	confirm_button.pressed.connect(_confirm_skip)
	cancel_button.pressed.connect(_cancel_skip)
	ButtonMotion.bind(skip_button, skip_button, 1.1)
	ButtonMotion.bind(return_button, return_button, -0.9)
	ButtonMotion.bind(confirm_button, confirm_button, 0.8)
	ButtonMotion.bind(cancel_button, cancel_button, -0.8)
	modal.visible = false
	set_available(false)


func set_available(value: bool) -> void:
	_available = value
	skip_button.visible = value
	skip_button.disabled = not value
	return_button.visible = value
	return_button.disabled = not value
	if not value:
		modal.visible = false
		_closing = false
		_confirmation_mode = ConfirmationMode.NONE


func open_confirmation() -> void:
	_open_confirmation(ConfirmationMode.SKIP)


func open_return_confirmation() -> void:
	_open_confirmation(ConfirmationMode.RETURN_TO_MENU)


func _open_confirmation(mode: ConfirmationMode) -> void:
	if not _available or modal.visible or _closing:
		return
	_confirmation_mode = mode
	_apply_confirmation_copy()
	skip_button.disabled = true
	return_button.disabled = true
	modal.visible = true
	dimmer.modulate.a = 0.0
	await get_tree().process_frame
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.86, 0.86)
	card.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(dimmer, "modulate:a", 1.0, 0.18)
	tween.tween_property(card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card, "modulate:a", 1.0, 0.16)
	confirm_button.grab_focus()


func is_confirmation_open() -> bool:
	return modal.visible


func _confirm_skip() -> void:
	await _close_confirmation(true)


func _cancel_skip() -> void:
	await _close_confirmation(false)


func _close_confirmation(confirmed: bool) -> void:
	if not modal.visible or _closing:
		return
	_closing = true
	confirm_button.disabled = true
	cancel_button.disabled = true
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(dimmer, "modulate:a", 0.0, 0.16)
	tween.tween_property(card, "scale", Vector2(0.92, 0.92), 0.16)
	tween.tween_property(card, "modulate:a", 0.0, 0.13)
	await tween.finished
	modal.visible = false
	card.scale = Vector2.ONE
	card.modulate = Color.WHITE
	dimmer.modulate = Color.WHITE
	confirm_button.disabled = false
	cancel_button.disabled = false
	_closing = false
	var completed_mode := _confirmation_mode
	_confirmation_mode = ConfirmationMode.NONE
	if confirmed:
		skip_button.visible = false
		return_button.visible = false
		if completed_mode == ConfirmationMode.RETURN_TO_MENU:
			return_confirmed.emit()
		else:
			skip_confirmed.emit()
	else:
		skip_button.disabled = not _available
		return_button.disabled = not _available
		if completed_mode == ConfirmationMode.RETURN_TO_MENU:
			return_cancelled.emit()
		else:
			skip_cancelled.emit()


func _apply_confirmation_copy() -> void:
	if _confirmation_mode == ConfirmationMode.RETURN_TO_MENU:
		eyebrow_label.text = "结束当前清扫"
		title_label.text = "返回主界面"
		message_label.text = "返回主界面，您的进度将会丢失，要返回么？"
		cancel_button.text = "继续游戏"
		confirm_button.text = "确认返回"
		return
	eyebrow_label.text = "跳过当前清扫"
	title_label.text = "蒜鸟，下一关"
	message_label.text = "这样做不会获得金钱哦，确认要跳过这一关么？"
	cancel_button.text = "继续清扫"
	confirm_button.text = "确认跳过"
