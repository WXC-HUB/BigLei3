extends SceneTree
## 拍一张关卡账单的正脸，顺带把血条的叠放摆出来：小票的撕边、点线和印章要在真实渲染
## 里看一眼才算数。

const OUTPUT_PATH := "res://artifacts/level_bill_receipt.png"
const HEARTS_OUTPUT_PATH := "res://artifacts/heart_stacks.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var bill := (load("res://scenes/ui/level_bill.tscn") as PackedScene).instantiate() as LevelBill
	root.add_child(bill)
	await process_frame
	bill.present(7, 12, 2, 5, 3, 40, 23, ScoreComboTracker.time_bonus_for(23.0))
	await create_timer(0.8).timeout
	await process_frame
	_save(root.get_texture().get_image(), OUTPUT_PATH)
	bill.queue_free()
	root.remove_child(bill)

	# 血条单独摆一张：上限 6（2+2+1+1）和上限 12（3+3+3+3）并排，看叠放有没有糊在一起。
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 80)
	row.position = Vector2(120, 300)
	root.add_child(row)
	for maximum in [3, 6, 9, 12]:
		var status := (
			(load("res://scenes/player_status.tscn") as PackedScene).instantiate() as PlayerStatus
		)
		row.add_child(status)
		await process_frame
		status.set_health(maxi(maximum - 1, 1), maximum)
	await create_timer(0.4).timeout
	await process_frame
	_save(root.get_texture().get_image(), HEARTS_OUTPUT_PATH)
	quit()


func _save(image: Image, path: String) -> void:
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save screenshot: %s" % error_string(error))
		quit(1)
		return
	print("Saved ", ProjectSettings.globalize_path(path))
