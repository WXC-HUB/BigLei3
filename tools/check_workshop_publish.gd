extends SceneTree
## 端到端验证「从编辑器里点发布」这条路：开编辑器 → 填发布对话框 → 真发到线上。
## 发上去的是一个一次性的验证包，末尾会打印它的 id，方便随后删掉。
## 跑法：godot --headless --path . --script tools/check_workshop_publish.gd

const PROBE_NAME := "发布自检请删除"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("发布自检超时")
		quit(2)
	)
	if not WorkshopApi.ENABLED:
		push_error("WorkshopApi.ENABLED 是 false，这条路走不通")
		quit(1)
		return

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.6).timeout

	var screen := game.get("_start_screen") as StartScreen
	var button := screen.get_node_or_null("Menu/DuelSlot/DuelRow/WorkshopButton") as Button
	if button == null:
		push_error("标题页没有创意工坊按钮")
		quit(1)
		return
	print("标题页入口：有")

	# 走「自定义」进编辑器。
	(screen.get_node("Menu/DuelSlot/DuelRow/CustomButton") as Button).pressed.emit()
	await process_frame
	await process_frame
	var editor = game.get("_custom_editor")
	if editor == null or not editor.is_open():
		push_error("编辑器没打开")
		quit(1)
		return

	var publish_button := editor.get("_publish_button") as Button
	print("编辑器发布按钮可见：", publish_button.visible)
	if not publish_button.visible:
		push_error("开关开了，发布按钮却没显示")
		quit(1)
		return

	# 装一个两图小包再发布。
	var pack := CustomLevel.make_default()
	pack["name"] = PROBE_NAME
	pack["maps"] = [CustomLevel.make_map(4, 3, 2), CustomLevel.make_map(3, 3, 1)]
	pack["items"] = CustomLevel.default_items()
	editor.load_level(pack)

	publish_button.pressed.emit()
	await process_frame
	var dialog := editor.get("_publish_dialog") as Control
	print("发布对话框弹出：", dialog.visible)
	if not dialog.visible:
		push_error("发布对话框没弹出来")
		quit(1)
		return
	(editor.get("_publish_author_input") as LineEdit).text = "自检"
	(editor.get("_publish_confirm") as Button).pressed.emit()

	# 等 main.gd 那边把结果回填到编辑器。
	var note := editor.get("_publish_note") as Label
	var deadline := Time.get_ticks_msec() + 30000
	while String(note.text).contains("正在发布"):
		if Time.get_ticks_msec() > deadline:
			push_error("发布没有回音")
			quit(1)
			return
		await create_timer(0.2).timeout
	var error_label := editor.get("_error_label") as Label
	print("发布结果：", String(error_label.text))
	if not String(error_label.text).contains("已发布"):
		push_error("发布失败")
		quit(1)
		return

	# 回头从线上确认它真的在列表里。
	var http := HTTPRequest.new()
	root.add_child(http)
	var listing := await WorkshopApi.fetch_list(http, WorkshopApi.SORT_NEW)
	var found := ""
	for item in (listing.get("items", []) as Array):
		if String((item as Dictionary).get("name", "")) == PROBE_NAME:
			found = String((item as Dictionary).get("id", ""))
			print("线上已收到：id=%s 作者=%s %d张图" % [
				found,
				String((item as Dictionary).get("author", "")),
				int((item as Dictionary).get("maps", 0)),
			])
			break
	if found.is_empty():
		push_error("线上列表里找不到刚发布的包")
		quit(1)
		return

	print("PROBE_ID=", found)
	print("发布链路自检通过")
	(game.get_node("BGM") as AudioStreamPlayer).stop()
	quit()
