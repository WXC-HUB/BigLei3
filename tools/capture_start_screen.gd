extends SceneTree
## 截标题界面的「9」粒子，确认冒出位置和配色。
##   godot --fixed-fps 60 --script tools/capture_start_screen.gd

const OUTPUT_DIR := "res://artifacts/start_screen"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	# 短间隔连拍，方便看清过山车波形在字与字之间推进。
	await create_timer(1.2).timeout
	for shot in range(6):
		await create_timer(0.14).timeout
		await process_frame
		var image := root.get_texture().get_image()
		image.save_png("%s/title_%02d.png" % [OUTPUT_DIR, shot])
	print("Saved start screen frames")
	quit()
