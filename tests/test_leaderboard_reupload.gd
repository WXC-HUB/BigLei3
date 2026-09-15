extends SceneTree
## 排行榜浏览页的「上传我的最高分」（二次上传）：
##   - 有本地记录才显示按钮，没有就不显示
##   - 按钮文案带着分数，切关时跟着换
##   - 点开弹窗要预填记住的昵称、显示这一关的本地最高分
##   - 名字为空要拦住，不发请求
##   - 通关页（CLEAR 模式）不该出现这颗按钮，也不该有弹窗
##
## 不打真实网络：只验到"点上传之前"的所有状态，发请求那一步交给手测和服务端自检。

const PanelScript := preload("res://scripts/ui/leaderboard_panel.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("Leaderboard reupload test timed out")
		quit(2)
	)
	await _check_browse_button()
	await _check_dialog()
	await _check_clear_mode_hides_it()
	_check_error_text()
	print("Leaderboard reupload: 按钮显隐、文案、切关、弹窗预填、拒收文案与校验全部通过")
	quit()


## 教学关没有排行榜，`present()` 会直接 return——挑关一律走这里过滤。
func _ranked_stages() -> PackedStringArray:
	var ids := PackedStringArray()
	for entry in StageTable.STAGES:
		var id := String((entry as Dictionary)["id"])
		if StageTable.has_leaderboard(id):
			ids.append(id)
	return ids


func _make_panel() -> Node:
	var panel = PanelScript.new()
	root.add_child(panel)
	return panel


func _check_browse_button() -> void:
	var panel := _make_panel()
	await process_frame

	var ranked := _ranked_stages()
	assert(ranked.size() >= 3, "有排行榜的关卡不足 3 个，测试前提不成立：%s" % [ranked])
	var first_id := ranked[0]
	var second_id := ranked[1]

	# 没有本地记录：按钮不该出现。
	panel.call("set_local_context", {}, "")
	panel.call("present", first_id, "甲关")
	await process_frame
	var button := panel.get("_upload_button") as Button
	assert(button != null, "浏览页没有上传按钮节点")
	assert(not button.visible, "没有本地成绩时不该显示上传按钮")
	assert(int(panel.call("local_best")) == 0, "没有记录时 local_best 应为 0")

	# 有本地记录：按钮出现，文案带分数。
	panel.call("set_local_context", {first_id: 12345, second_id: 777}, "阿吴")
	await process_frame
	assert(button.visible, "有本地成绩却没显示上传按钮")
	assert(int(panel.call("local_best")) == 12345, "local_best 取错了：%d" % int(panel.call("local_best")))
	assert(String(button.text).contains("12,345"), "按钮没写出分数：%s" % String(button.text))

	# 切到另一关：按钮跟着换成那一关的记录。
	panel.call("_on_stage_tab_pressed", second_id)
	await process_frame
	assert(int(panel.call("local_best")) == 777, "切关后 local_best 没跟着换：%d" % int(panel.call("local_best")))
	assert(String(button.text).contains("777"), "切关后按钮文案没更新：%s" % String(button.text))

	# 切到一个没有记录的关：按钮收起来。
	panel.call("_on_stage_tab_pressed", ranked[2])
	await process_frame
	assert(not button.visible, "切到没记录的关还显示着上传按钮")

	panel.call("hide_immediately")
	panel.queue_free()
	await process_frame


func _check_dialog() -> void:
	var panel := _make_panel()
	await process_frame
	var stage_id := _ranked_stages()[0]
	panel.call("set_local_context", {stage_id: 8600}, "阿吴")
	panel.call("present", stage_id, "甲关")
	await process_frame

	var dialog := panel.get("_upload_dialog") as Control
	assert(not dialog.visible, "弹窗一开始就开着")

	panel.call("_on_upload_pressed")
	await process_frame
	assert(dialog.visible, "点上传没弹出确认框")
	var input := panel.get("_upload_input") as LineEdit
	assert(String(input.text) == "阿吴", "弹窗没预填记住的昵称：%s" % String(input.text))
	var body := panel.get("_upload_body") as Label
	assert(String(body.text).contains("8,600"), "弹窗没显示本地最高分：%s" % String(body.text))
	var title := panel.get("_upload_title") as Label
	assert(String(title.text).contains("甲关"), "弹窗没写清是哪一关：%s" % String(title.text))

	# 名字清空后点上传：要拦住并给提示，且不进入上传中状态。
	input.text = "   "
	panel.call("_on_upload_confirmed")
	await process_frame
	var note := panel.get("_upload_note") as Label
	assert(String(note.text).contains("名称"), "空名字没有给提示：%s" % String(note.text))
	assert(not bool(panel.get("_uploading")), "空名字不该进入上传中状态")
	assert(dialog.visible, "空名字不该把弹窗关掉")

	# 取消要关掉弹窗，且不影响榜本身。
	panel.call("_on_upload_cancelled")
	await process_frame
	assert(not dialog.visible, "取消没关掉弹窗")
	assert(panel.visible, "取消把整张榜也关了")

	panel.call("hide_immediately")
	panel.queue_free()
	await process_frame


func _check_clear_mode_hides_it() -> void:
	var panel := _make_panel()
	await process_frame
	var stage_id := _ranked_stages()[0]
	panel.call("set_local_context", {stage_id: 9999}, "阿吴")
	# 通关页是阻塞式的，这里不 await 它的返回，只看 UI 状态。
	panel.call("present_after_clear", stage_id, "甲关", 4321, "阿吴")
	await process_frame

	var button := panel.get("_upload_button") as Button
	var actions := panel.get("_browse_actions") as Control
	assert(not button.visible, "通关页不该出现二次上传按钮")
	assert(not actions.visible, "通关页不该出现浏览页那排按钮")
	assert(not (panel.get("_upload_dialog") as Control).visible, "通关页不该带着上传弹窗")
	assert((panel.get("_submit_button") as Button).visible, "通关页的上榜按钮不见了")

	panel.call("hide_immediately")
	panel.queue_free()
	await process_frame


## 服务端按分数上限/计分粒度退回时，文案要和「网络不通」分开——不然玩家会一直重试。
func _check_error_text() -> void:
	var panel = PanelScript.new()
	root.add_child(panel)

	var too_high: String = panel.call("_submit_error_text", {"error": "score_too_high", "max": 14000})
	assert(too_high.contains("超出本关上限"), "超上限的文案不对：%s" % too_high)
	assert(too_high.contains("14,000"), "超上限文案没写出上限数值：%s" % too_high)

	var misaligned: String = panel.call("_submit_error_text", {"error": "score_not_aligned"})
	assert(misaligned.contains("计分口径"), "口径不符的文案不对：%s" % misaligned)

	# 网络类失败没有 error 字段或是传输错误，应当返回空串、由调用方退回默认文案。
	assert(String(panel.call("_submit_error_text", {"error": "http_result"})) == "", "网络故障不该套用校验文案")
	assert(String(panel.call("_submit_error_text", {})) == "", "没有 error 字段时不该套用校验文案")

	panel.queue_free()
