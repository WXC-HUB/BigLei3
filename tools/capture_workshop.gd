extends SceneTree
## 创意工坊开关打开后的两处入口截图：标题页那一排按钮、工坊浏览页。
## 跑法：godot --fixed-fps 60 --path . --script tools/capture_workshop.gd

const MENU_PATH := "res://artifacts/workshop_menu.png"
const PANEL_PATH := "res://artifacts/workshop_panel.png"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	if not WorkshopApi.ENABLED:
		push_error("WorkshopApi.ENABLED 是 false，没什么可截的")
		quit(1)
		return

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(1.2).timeout

	var screen := game.get("_start_screen") as StartScreen
	if screen == null:
		push_error("标题页没起来")
		quit(1)
		return
	var button := screen.get_node_or_null("Menu/DuelSlot/DuelRow/WorkshopButton") as Button
	print("标题页创意工坊按钮：", "有" if button != null else "没有")
	var row := screen.get_node_or_null("Menu/DuelSlot/DuelRow") as HBoxContainer
	if row != null:
		var names := PackedStringArray()
		for child in row.get_children():
			names.append(child.name)
		print("那一排按钮：", ", ".join(names))
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(MENU_PATH))
	print("saved ", MENU_PATH)

	# 打开工坊浏览页，等它把线上列表拉回来。
	game.call("_on_workshop_requested")
	await create_timer(3.0).timeout
	var panel = game.get("_workshop_panel")
	if panel == null:
		push_error("工坊面板没建起来")
		quit(1)
		return
	var status := panel.get("_status") as Label
	print("工坊状态行：", String(status.text))
	print("列出条目数：", (panel.get("_rows") as Array).size())
	image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(PANEL_PATH))
	print("saved ", PANEL_PATH)

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	quit()
