extends SceneTree
## 关卡账单要长得像一张小票：撕边的纸、品名／数量／金额三栏用点线连起来、小计与余额之
## 间压一道双线、右下角一枚「已结清」的章。这里盯的是结构和数字，不是像素。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(10.0).timeout.connect(func() -> void:
		push_error("Level bill test timed out")
		quit(2)
	)
	var bill := (load("res://scenes/ui/level_bill.tscn") as PackedScene).instantiate() as LevelBill
	root.add_child(bill)
	await process_frame
	var stack := bill.get_node("Center/Panel/Margin/Stack") as VBoxContainer
	for part in ["Shop", "Meta/Serial", "RuleTop", "Columns", "RuleSum", "RuleTotal", "Footer"]:
		if not _require(stack.has_node(part), "小票缺了 %s 这一块" % part): return
	if not _require(
		bill.has_node("Center/Panel/TornEdges/Stamp"), "小票右下角没有「已结清」的章"
	): return

	bill.present(7, 12, 2, 5, 3, 40, 23, ScoreComboTracker.time_bonus_for(23.0))
	await process_frame
	await process_frame
	var lines := stack.get_node("Lines") as VBoxContainer
	var printed := PackedStringArray()
	for row in lines.get_children():
		printed.append(row.name)
	if not _require(
		Array(printed) == ["Mines", "NightMasterFish", "ComboBonus", "ClearBonus"],
		"账目行不对：%s" % ", ".join(printed)
	): return
	if not _require(_amount(lines, "Mines") == "+12G", "标雷这一行金额不对"): return
	if not _require(_amount(lines, "ClearBonus") == "+3G", "通关奖励不是 3G"): return
	if not _require(
		_amount(stack.get_node("Subtotal"), "SubtotalLine") == "+22G", "小计没有把四行加起来"
	): return
	if not _require(
		_amount(stack.get_node("Total"), "TotalLine") == "40G", "余额没有显示当前金币"
	): return
	var serial := stack.get_node("Meta/Serial") as Label
	if not _require(serial.text.contains("No.0007"), "小票没有按关卡编单号：%s" % serial.text): return
	var dots := (lines.get_node("Mines") as HBoxContainer).get_node("Dots") as Label
	if not _require(dots.clip_text and dots.text.length() > 0, "品名和金额之间没有点线"): return

	# 用时奖励是这张小票上唯一记「分」的一行，压在余额下面、继续按钮上面。
	# 它不进金币小计——上面那条 +22G 的断言就是在钉这件事。
	if not _require(stack.has_node("ScoreLine"), "小票没有印用时奖励那一行"): return
	var score_row: HBoxContainer = stack.get_node("ScoreLine")
	if not _require(
		(score_row.get_node("Qty") as Label).text == "23 秒",
		"用时没印对：%s" % (score_row.get_node("Qty") as Label).text
	): return
	if not _require(
		(score_row.get_node("Amount") as Label).text
		== "+%d 分" % ScoreComboTracker.time_bonus_for(23.0),
		"用时奖励的分数没印对：%s" % (score_row.get_node("Amount") as Label).text
	): return
	if not _require(
		score_row.get_index() < (stack.get_node("Continue") as Control).get_index(),
		"用时奖励那行跑到「继续」下面去了"
	): return

	# 无尽关换一套口径：得分行改印排雷，别让玩家在一张只按排雷计分的小票上
	# 读到「用时奖励 +0 分」。
	bill.present(9, 6, 0, 0, 3, 20, 41, 0, 6, 6 * ScoreComboTracker.POINTS_PER_MINE, true)
	await process_frame
	await process_frame
	score_row = stack.get_node("ScoreLine") as HBoxContainer
	if not _require(
		(score_row.get_node("Name") as Label).text == "排雷得分",
		"无尽关的得分行品名没换：%s" % (score_row.get_node("Name") as Label).text
	): return
	if not _require(
		(score_row.get_node("Qty") as Label).text == "6 枚",
		"无尽关的得分行没印雷数：%s" % (score_row.get_node("Qty") as Label).text
	): return
	if not _require(
		(score_row.get_node("Amount") as Label).text
		== "+%d 分" % (6 * ScoreComboTracker.POINTS_PER_MINE),
		"无尽关的排雷得分没印对：%s" % (score_row.get_node("Amount") as Label).text
	): return
	# 再印一张普通关的票，确认品名会退回用时口径，不是一次性改坏。
	bill.present(3, 4, 0, 0, 3, 12, 23, ScoreComboTracker.time_bonus_for(23.0))
	await process_frame
	await process_frame
	score_row = stack.get_node("ScoreLine") as HBoxContainer
	if not _require(
		(score_row.get_node("Name") as Label).text == "用时奖励",
		"普通关的得分行品名没退回用时：%s" % (score_row.get_node("Name") as Label).text
	): return

	# 没拿到的收入不印空行：这一盘没有连击、没有鱼，小票上就只剩标雷和通关奖励。
	bill.present(3, 4, 0, 0, 3, 12)
	await process_frame
	await process_frame
	var trimmed := PackedStringArray()
	for row in lines.get_children():
		trimmed.append(row.name)
	if not _require(
		Array(trimmed) == ["Mines", "ClearBonus"], "小票印了金额为 0 的空行：%s" % ", ".join(trimmed)
	): return
	print("Level bill: receipt layout and totals passed")
	quit()


func _amount(parent: Node, row_name: String) -> String:
	var row := parent.get_node(row_name) as HBoxContainer
	return (row.get_node("Amount") as Label).text


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
