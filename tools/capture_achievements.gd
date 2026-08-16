extends SceneTree
## 截成就页：先全锁，再解开五个彩蛋成就。
##   godot --fixed-fps 60 --script tools/capture_achievements.gd

const OUTPUT_DIR := "res://artifacts/achievements"
const Catalog := preload("res://scripts/game/achievement_catalog.gd")


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var screen := game.get("_achievements_screen") as AchievementsScreen
	screen.present()
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png("%s/achievements_locked.png" % OUTPUT_DIR)
	for data in Catalog.ENTRIES:
		game.call("_unlock_achievement", data["id"])
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png("%s/achievements_unlocked.png" % OUTPUT_DIR)
	var scroll := screen.achievement_list.get_parent() as ScrollContainer
	for shot in range(3):
		scroll.scroll_vertical += 340
		await create_timer(0.25).timeout
		await process_frame
		root.get_texture().get_image().save_png("%s/achievements_scroll_%d.png" % [OUTPUT_DIR, shot])
	var toast := game.get("_achievement_toast") as AchievementToast
	print("rows=", screen.achievement_list.get_child_count(),
		" toast=", toast.toast_card.size)
	quit()
