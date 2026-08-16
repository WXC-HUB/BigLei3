extends SceneTree
## 截红隼解锁页撩过头之后的掉鸽子。
##   godot --fixed-fps 60 --script tools/capture_kestrel_pigeons.gd

const OUTPUT_DIR := "res://artifacts/kestrel_pigeons"


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
	# 序章会盖在解锁页上面，截图前先把它收掉。
	var story := game.get("_opening_story") as Control
	if story != null:
		story.visible = false
	await create_timer(0.6).timeout
	var unlock := game.get("_kestrel_unlock") as KestrelUnlock
	unlock.present()
	await create_timer(3.2).timeout
	# 真窗口下鼠标停在鸟身上会真的触发 hover，这里只走手动 emit。
	unlock.bird.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for hover in range(KestrelUnlock.RAGE_HOVERS - 1):
		unlock.bird.mouse_entered.emit()
		await create_timer(0.04).timeout
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png("%s/pigeons_00_before.png" % OUTPUT_DIR)
	for drop in range(KestrelUnlock.GLUTTON_PIGEONS + 2):
		unlock.bird.mouse_entered.emit()
		await create_timer(0.1).timeout
		if drop % 6 == 0 or drop >= KestrelUnlock.GLUTTON_PIGEONS - 1:
			await process_frame
			root.get_texture().get_image().save_png("%s/pigeons_%02d.png" % [OUTPUT_DIR, drop + 1])
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("%s/pigeons_99_glutton.png" % OUTPUT_DIR)
	# 吃撑之后再滑过：只冒一次气泡，不再掉鸽子。
	var before: int = unlock.get("_pigeon_count")
	unlock.bird.mouse_entered.emit()
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("%s/pigeons_98_bubble.png" % OUTPUT_DIR)
	unlock.bird.mouse_entered.emit()
	await create_timer(2.4).timeout
	root.get_texture().get_image().save_png("%s/pigeons_97_bubble_stays.png" % OUTPUT_DIR)
	print("pigeons before bubble=", before, " after=", unlock.get("_pigeon_count"))
	print("flyovers=", unlock.get("_flyover_count"), " pigeons=", unlock.get("_pigeon_count"),
		" glutton=", unlock.get("_glutton"), " name=", unlock.name_label.text, " bird_scale=", unlock.bird.scale)
	quit()
