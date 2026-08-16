extends SceneTree
## 截啄木鸟解锁页的破屏演出。
##   godot --fixed-fps 60 --script tools/capture_attacker_rage.gd

const OUTPUT_DIR := "res://artifacts/attacker_rage"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	# 直接掀掉标题并开局：标题之后的耳机提示和序章都跟这段演出无关，
	# 走完整流程只会让截图时序跟着它们漂。
	_dismiss_title(game)
	game.call("_start_game")
	await create_timer(0.6).timeout
	var unlock := game.get("_attacker_unlock") as AttackerUnlock
	unlock.present()
	await create_timer(3.2).timeout
	# 截图开的是真窗口：鼠标正好停在鸟身上就会真的触发 hover，把计数搅乱。
	# 这里关掉鸟的鼠标响应，只用手动 emit 走这段演出。
	unlock.bird.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.get_texture().get_image().save_png("%s/rage_00_page.png" % OUTPUT_DIR)
	# 连续触发拟声词，最后一次进入破屏。
	for peck in range(AttackerUnlock.RAGE_PECKS - 1):
		unlock.bird.mouse_entered.emit()
		await create_timer(0.09).timeout
	root.get_texture().get_image().save_png("%s/rage_01_stacked.png" % OUTPUT_DIR)
	var tag := unlock.tagline_label
	print("tagline size=", tag.size, " scale=", tag.scale, " pos=", tag.position,
		" font=", tag.get_theme_font_size("font_size"), " autowrap=", tag.autowrap_mode,
		" lines=", tag.get_line_count(), " visible_lines=", tag.get_visible_line_count(),
		" finale=", unlock.finale.size, " root=", unlock.size)
	unlock.bird.mouse_entered.emit()
	for shot in range(10):
		await create_timer(0.11).timeout
		await process_frame
		root.get_texture().get_image().save_png("%s/rage_1%d.png" % [OUTPUT_DIR, shot])
	print("raging=", unlock.get("_raging"), " time_scale=", Engine.time_scale)
	quit()


func _dismiss_title(game: Node) -> void:
	var screen := game.get("_start_screen") as Control
	if screen == null:
		return
	game.set("_start_screen", null)
	if screen.get_parent() != null:
		screen.get_parent().queue_free()
