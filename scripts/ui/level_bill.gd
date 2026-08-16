class_name LevelBill
extends Control

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")

@onready var panel: PanelContainer = $Center/Panel
@onready var level_label: Label = $Center/Panel/Margin/Stack/Level
@onready var mine_label: Label = $Center/Panel/Margin/Stack/Mines
@onready var fish_label: Label = $Center/Panel/Margin/Stack/NightMasterFish
@onready var total_label: Label = $Center/Panel/Margin/Stack/Total
@onready var continue_button: Button = $Center/Panel/Margin/Stack/Continue


func _ready() -> void:
	visible = false
	ButtonMotion.bind(continue_button, continue_button, -1.0)


func present(level: int, flagged_mines: int, night_master_fish: int, total_gold: int) -> void:
	level_label.text = "第 %d 关账单" % level
	mine_label.text = "正确标记雷 × %d    +%dG" % [flagged_mines, flagged_mines]
	fish_label.text = "夜师傅吃掉的鱼 × %d    +%dG" % [night_master_fish, night_master_fish]
	total_label.text = "当前金币：%dG" % total_gold
	continue_button.disabled = true
	visible = true
	await get_tree().process_frame
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.86, 0.86)
	panel.modulate.a = 0.0
	var enter := create_tween().set_parallel(true)
	enter.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter.tween_property(panel, "scale", Vector2.ONE, 0.3)
	enter.tween_property(panel, "modulate:a", 1.0, 0.18)
	await enter.finished
	continue_button.disabled = false
	await continue_button.pressed
	continue_button.disabled = true
	var exit := create_tween().set_parallel(true)
	exit.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_property(panel, "scale", Vector2(0.92, 0.92), 0.18)
	exit.tween_property(panel, "modulate:a", 0.0, 0.16)
	await exit.finished
	visible = false
	continue_button.disabled = false
	panel.scale = Vector2.ONE
	panel.modulate = Color.WHITE
