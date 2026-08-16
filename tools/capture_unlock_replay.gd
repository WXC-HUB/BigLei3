extends SceneTree
## 复现：触发彩蛋 → 收起页面 → 重新 present，看四个解锁页的初始状态。
##   godot --fixed-fps 60 --script tools/capture_unlock_replay.gd

const OUTPUT_DIR := "res://artifacts/unlock_replay"


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
	await create_timer(0.4).timeout

	await _replay(game, "heron", game.get("_night_heron_unlock"), "final_bird", 21)
	await _replay(game, "redstart", game.get("_redstart_unlock"), "final_bird", 21)
	await _replay(game, "woodpecker", game.get("_attacker_unlock"), "bird", 21)
	await _replay(game, "kestrel", game.get("_kestrel_unlock"), "bird", 21)
	quit()


func _replay(game: Node, tag: String, page: Control, bird_name: String, hovers: int) -> void:
	var bird := page.get(bird_name) as Control
	page.call("present")
	await create_timer(3.0).timeout
	bird.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var home := bird.position
	for hover in range(hovers):
		bird.mouse_entered.emit()
		await create_timer(0.03).timeout
	await create_timer(3.0).timeout
	root.get_texture().get_image().save_png("%s/%s_1_after_egg.png" % [OUTPUT_DIR, tag])
	# 收起页面，就像玩家点了继续。
	var continue_button := page.get_node("Finale/Continue") as Button
	continue_button.pressed.emit()
	await create_timer(1.0).timeout
	# 重开一轮，再次 present 同一页。
	page.call("present")
	await create_timer(3.2).timeout
	root.get_texture().get_image().save_png("%s/%s_2_replay.png" % [OUTPUT_DIR, tag])
	print(tag, ": home=", home, " replay=", bird.position, " scale=", bird.scale,
		" drift=", (bird.position - home).length())
	continue_button.pressed.emit()
	await create_timer(0.8).timeout
