extends SceneTree
## 截制作人名单页面（星战滚动 + BGM 切换条）。
##   godot --fixed-fps 60 --script tools/capture_credits.gd

const OUTPUT_DIR := "res://artifacts/credits"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var screen := game.get("_start_screen") as StartScreen
	(screen.get_node("%CreditsButton") as Button).pressed.emit()
	var credits := game.get("_credits_screen") as CreditsScreen
	for shot in range(8):
		await create_timer(1.6).timeout
		await process_frame
		var image := root.get_texture().get_image()
		image.save_png("%s/credits_%02d.png" % [OUTPUT_DIR, shot])
	print("visible=", credits.visible, " playing=", credits.get_node("%CreditsBGM").playing)
	(credits.get_node("%HypeButton") as Button).pressed.emit()
	await create_timer(0.4).timeout
	await process_frame
	root.get_texture().get_image().save_png("%s/credits_hype_selected.png" % OUTPUT_DIR)
	(credits.get_node("%BackButton") as Button).pressed.emit()
	await create_timer(0.8).timeout
	await process_frame
	root.get_texture().get_image().save_png("%s/credits_back.png" % OUTPUT_DIR)
	print("after back visible=", credits.visible)
	quit()
