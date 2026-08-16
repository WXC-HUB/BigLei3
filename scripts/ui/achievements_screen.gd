class_name AchievementsScreen
extends Control
## 成就页只展示当前运行内由 Main 传入的状态，不读写任何存档数据。
##
## 列表按 AchievementCatalog 的总表在运行时铺出来：场景里只留一条隐藏的模板，
## 每个成就复制一份填字填图。加成就只改总表，这一页和提示条都会自动跟上。

signal back_requested

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const Catalog := preload("res://scripts/game/achievement_catalog.gd")

const UNLOCKED_COLOR := Color("6f8f3d")
const LOCKED_COLOR := Color("846e50")
const LOCKED_ICON_TINT := Color(0.24, 0.24, 0.2, 0.72)

@onready var back_button: Button = %BackButton
@onready var achievement_list: VBoxContainer = %AchievementList
@onready var entry_template: PanelContainer = %EntryTemplate

var _transitioning := false
## id -> {"row": PanelContainer, "icon": TextureRect, "status": Label}
var _entries: Dictionary = {}
var _unlocked: Dictionary = {}


func _ready() -> void:
	visible = false
	back_button.pressed.connect(_on_back_pressed)
	ButtonMotion.bind(back_button, back_button, -1.0)
	entry_template.visible = false
	for data in Catalog.ENTRIES:
		_build_entry(data)


func _build_entry(data: Dictionary) -> void:
	var row := entry_template.duplicate() as PanelContainer
	row.name = "Entry_%s" % data["id"]
	row.visible = true
	achievement_list.add_child(row)
	var icon := row.get_node("Row/Icon") as TextureRect
	var status := row.get_node("Row/Status") as Label
	icon.texture = data["icon"]
	(row.get_node("Row/Copy/Name") as Label).text = data["title"]
	(row.get_node("Row/Copy/Description") as Label).text = data["description"]
	_entries[data["id"]] = {"row": row, "icon": icon, "status": status}
	_refresh_entry(data["id"])


func set_unlocked(achievement_id: String, value: bool = true) -> void:
	if not _entries.has(achievement_id):
		push_warning("Unknown achievement id: %s" % achievement_id)
		return
	_unlocked[achievement_id] = value
	_refresh_entry(achievement_id)


func is_unlocked(achievement_id: String) -> bool:
	return bool(_unlocked.get(achievement_id, false))


## 给测试和调试用：拿到某条成就的状态标签。
func status_label(achievement_id: String) -> Label:
	if not _entries.has(achievement_id):
		return null
	return _entries[achievement_id]["status"]


func _refresh_entry(achievement_id: String) -> void:
	var parts: Dictionary = _entries[achievement_id]
	var unlocked := is_unlocked(achievement_id)
	var icon := parts["icon"] as TextureRect
	var status := parts["status"] as Label
	icon.self_modulate = Color.WHITE if unlocked else LOCKED_ICON_TINT
	status.text = "已获得" if unlocked else "未获得"
	status.add_theme_color_override("font_color", UNLOCKED_COLOR if unlocked else LOCKED_COLOR)


func present() -> void:
	if _transitioning:
		return
	visible = true
	modulate.a = 0.0
	var card := %Card as PanelContainer
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.96, 0.96)
	var intro := create_tween().set_parallel(true)
	intro.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.tween_property(self, "modulate:a", 1.0, 0.24)
	intro.tween_property(card, "scale", Vector2.ONE, 0.3)


func dismiss() -> void:
	if _transitioning or not visible:
		return
	_transitioning = true
	var card := %Card as PanelContainer
	var outro := create_tween().set_parallel(true)
	outro.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	outro.tween_property(self, "modulate:a", 0.0, 0.2)
	outro.tween_property(card, "scale", Vector2(0.97, 0.97), 0.2)
	await outro.finished
	visible = false
	_transitioning = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	if _transitioning:
		return
	back_requested.emit()
