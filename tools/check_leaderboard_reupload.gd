extends SceneTree
## 端到端验证「浏览页二次上传」：在真实游戏里造一个本地最高分，打开榜，
## 走完弹窗 → 真发到线上 → 榜刷新 → 昵称落存档。顺带出两张截图。
## 跑法：godot --fixed-fps 60 --path . --script tools/check_leaderboard_reupload.gd

const STAGE := "grass_2"
const PROBE_NAME := "补传自检"
const PROBE_SCORE := 4321
const SHOT_BUTTON := "res://artifacts/reupload_button.png"
const SHOT_DIALOG := "res://artifacts/reupload_dialog.png"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("二次上传自检超时")
		quit(2)
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var original := GameSave.save_path
	GameSave.save_path = "user://check_reupload_save.json"
	GameSave.clear()

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.8).timeout

	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		var parent := screen.get_parent()
		if is_instance_valid(parent):
			parent.queue_free()

	# 造一个本地最高分，并记一个昵称，模拟"以前打过但没上榜"。
	var scores: Dictionary = game.get("_stage_high_scores")
	scores[STAGE] = PROBE_SCORE
	game.set("_stage_high_scores", scores)
	game.set("_leaderboard_name", PROBE_NAME)
	game.call("_save_progress")

	# 从选关图那条路开榜（会先灌本地记录）。
	game.call("_open_stage_leaderboard", STAGE, "")
	await create_timer(2.5).timeout

	var panel = game.get("_leaderboard_panel")
	if panel == null or not panel.visible:
		push_error("榜没打开")
		quit(1)
		return
	var button := panel.get("_upload_button") as Button
	print("按钮可见：", button.visible, "  文案：", button.text)
	print("面板拿到的本地最高分：", panel.call("local_best"))
	if not button.visible:
		push_error("有本地成绩却没显示上传按钮")
		quit(1)
		return
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(SHOT_BUTTON))
	print("saved ", SHOT_BUTTON)

	# 打开弹窗、截图、确认预填。
	button.pressed.emit()
	await create_timer(0.5).timeout
	var dialog := panel.get("_upload_dialog") as Control
	print("弹窗可见：", dialog.visible)
	print("预填昵称：", String((panel.get("_upload_input") as LineEdit).text))
	image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(SHOT_DIALOG))
	print("saved ", SHOT_DIALOG)

	# 真发一次。
	(panel.get("_upload_confirm") as Button).pressed.emit()
	var deadline := Time.get_ticks_msec() + 30000
	while bool(panel.get("_uploading")):
		if Time.get_ticks_msec() > deadline:
			push_error("上传没有回音")
			quit(1)
			return
		await create_timer(0.2).timeout
	await create_timer(1.5).timeout
	print("状态行：", String((panel.get("_status") as Label).text))
	print("弹窗已关：", not dialog.visible)

	# 昵称应当已经写进存档（main.gd 收到 name_remembered）。
	var saved := String(GameSave.load_data().get("leaderboard_name", ""))
	print("存档里的昵称：", saved)
	if saved != PROBE_NAME:
		push_error("上传后昵称没记进存档")
		quit(1)
		return

	print("二次上传链路自检通过")
	var bgm := game.get_node_or_null("BGM") as AudioStreamPlayer
	if bgm != null:
		bgm.stop()
	GameSave.clear()
	GameSave.save_path = original
	quit()
