class_name TutorialSkipButton
extends Control

signal skip_requested

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")

@onready var button: Button = $SkipButton


func _ready() -> void:
	button.pressed.connect(func() -> void: skip_requested.emit())
	ButtonMotion.bind(button, button, 1.2)


func set_available(value: bool) -> void:
	visible = value
	button.disabled = not value
