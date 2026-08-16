extends SceneTree
## 截夜鹭解锁页的翻脸演出。
##   godot --fixed-fps 60 --script tools/capture_heron_rage.gd

const OUTPUT_DIR := "res://artifacts/heron_rage"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var title := game.get("_start_screen") as Control
	if title != null:
		game.set("_start_screen", null)
		title.get_parent().queue_free()
	game.call("_start_game")
	await create_timer(0.6).timeout
	var unlock := game.get("_night_heron_unlock") as NightHeronUnlock
	unlock.present()
	await create_timer(3.2).timeout
	# 真窗口下鼠标停在鸟身上会真的触发 hover，这里只走手动 emit。
	unlock.final_bird.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.get_texture().get_image().save_png("%s/heron_00_page.png" % OUTPUT_DIR)
	for hover in range(NightHeronUnlock.RAGE_HOVERS - 1):
		unlock.final_bird.mouse_entered.emit()
		await create_timer(0.05).timeout
	root.get_texture().get_image().save_png("%s/heron_01_fish.png" % OUTPUT_DIR)
	unlock.final_bird.mouse_entered.emit()
	for shot in range(12):
		await create_timer(0.1).timeout
		await process_frame
		root.get_texture().get_image().save_png("%s/heron_1%d.png" % [OUTPUT_DIR, shot])
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png("%s/heron_20_settled.png" % OUTPUT_DIR)
	print("raging=", unlock.get("_raging"), " time_scale=", Engine.time_scale,
		" name=", unlock.name_label.text, " tilt=", unlock.name_label.rotation)
	quit()
