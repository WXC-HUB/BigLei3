extends SceneTree
## 截红尾水鸲解锁页的水渠出场。
##   godot --fixed-fps 60 --script tools/capture_redstart_rage.gd

const OUTPUT_DIR := "res://artifacts/redstart_rage"


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
	var unlock := game.get("_redstart_unlock") as RedstartUnlock
	unlock.present()
	await create_timer(3.2).timeout
	# 真窗口下鼠标停在鸟身上会真的触发 hover，这里只走手动 emit。
	unlock.final_bird.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.get_texture().get_image().save_png("%s/rise_00_page.png" % OUTPUT_DIR)
	for hover in range(RedstartUnlock.RAGE_HOVERS - 1):
		unlock.final_bird.mouse_entered.emit()
		await create_timer(0.04).timeout
	unlock.final_bird.mouse_entered.emit()
	for shot in range(14):
		await create_timer(0.24).timeout
		await process_frame
		root.get_texture().get_image().save_png("%s/rise_%02d.png" % [OUTPUT_DIR, shot + 1])
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png("%s/rise_99_settled.png" % OUTPUT_DIR)
	print("raging=", unlock.get("_raging"), " time_scale=", Engine.time_scale,
		" page_pos=", unlock.position, " aqueduct=", unlock.get("_aqueduct") != null)
	quit()
