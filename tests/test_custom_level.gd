extends SceneTree
## 自定义关卡包：JSON 往返与校验、编辑器矩形画格与地图列表、标题页 → 编辑器 → 开局
## → 结果 → 返回编辑 → 回标题的整条流转，多图包的「打完一张进商店再打下一张」，
## 以及自定义局绝不写存档。

const LevelEditorScript := preload("res://scripts/ui/custom_level_editor.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("Custom level test timed out")
		quit(2)
	)
	var original_path := GameSave.save_path
	GameSave.save_path = "user://test_custom_level_save.json"
	GameSave.clear()

	_check_json_roundtrip()
	_check_multi_map_json()
	_check_validation()
	_check_import_variants()
	await _check_editor_painting()
	await _check_map_list()
	await _check_game_flow()
	await _check_multi_map_flow()

	GameSave.clear()
	GameSave.save_path = original_path
	print("Custom level: JSON 往返、校验、矩形画格、地图列表、单图与多图流转全部通过")
	quit()


## 取包里第一张图，测试里到处要用。
func _first(pack: Dictionary) -> Dictionary:
	return CustomLevel.map_at(pack, 0)


func _check_json_roundtrip() -> void:
	var pack := CustomLevel.make_default()
	pack["name"] = "试作 \"一\" 号"
	pack["maps"] = [{
		"width": 4,
		"height": 3,
		"mask": PackedByteArray([1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1]),
		"mines": 2,
	}]
	pack["items"]["lantern"] = 3
	pack["items"]["detect"] = 2
	var text := CustomLevel.to_json(pack)
	# 地图必须一行一排、肉眼可读。
	assert(text.contains("[1, 1, 1, 0]"), "第一行地图没有按 0/1 数组写出：\n" + text)
	assert(text.contains("[1, 0, 1, 1]"), "第二行地图没有按 0/1 数组写出")
	assert(text.contains("\"lantern\": 3"), "初始道具数量没写进 JSON")
	assert(text.contains("\"version\": 2"), "没写出 v2 版本号")
	var result := CustomLevel.from_json(text)
	assert(bool(result["ok"]), "自己导出的 JSON 读不回来：" + String(result["error"]))
	var back: Dictionary = result["level"]
	assert(String(back["name"]) == "试作 \"一\" 号", "关卡包名往返丢失")
	assert(CustomLevel.map_count(back) == 1, "地图张数往返丢失")
	var one := _first(back)
	assert(int(one["width"]) == 4 and int(one["height"]) == 3, "尺寸往返丢失")
	assert((one["mask"] as PackedByteArray) == (_first(pack)["mask"] as PackedByteArray), "掩码往返丢失")
	assert(int(one["mines"]) == 2, "雷数往返丢失")
	assert(CustomLevel.item_count(back, "lantern") == 3 and CustomLevel.item_count(back, "detect") == 2, "初始道具往返丢失")
	assert(CustomLevel.file_name_for(back) == "试作 _一_ 号.json", "文件名没洗掉非法字符：" + CustomLevel.file_name_for(back))


func _check_multi_map_json() -> void:
	var pack := CustomLevel.make_default()
	pack["name"] = "三连"
	pack["maps"] = [
		CustomLevel.make_map(3, 3, 2),
		CustomLevel.make_map(4, 2, 1),
		CustomLevel.make_map(5, 4, 6),
	]
	assert(CustomLevel.map_count(pack) == 3, "包里应该有 3 张图")
	assert(CustomLevel.total_mines(pack) == 9, "总雷数应为 9，实际 %d" % CustomLevel.total_mines(pack))
	var result := CustomLevel.from_json(CustomLevel.to_json(pack))
	assert(bool(result["ok"]), "多图包读不回来：" + String(result["error"]))
	var back: Dictionary = result["level"]
	assert(CustomLevel.map_count(back) == 3, "多图往返丢了图")
	assert(int(CustomLevel.map_at(back, 1)["width"]) == 4, "第二张图尺寸往返丢失")
	assert(int(CustomLevel.map_at(back, 2)["mines"]) == 6, "第三张图雷数往返丢失")
	# 越界取图返回空字典，不该抛。
	assert(CustomLevel.map_at(back, 9).is_empty(), "越界取图应返回空字典")


func _check_validation() -> void:
	var pack := CustomLevel.make_default()
	assert(CustomLevel.is_valid(pack), "默认配置就该合法")

	# 断成两块
	pack["maps"] = [{"width": 5, "height": 1, "mask": PackedByteArray([1, 1, 0, 1, 1]), "mines": 1}]
	var errors := CustomLevel.validate(pack)
	assert(errors.size() >= 1 and errors[0].contains("连成一块"), "不连通的地图没被拦住：%s" % [errors])

	# 雷太多
	pack["maps"] = [{"width": 5, "height": 1, "mask": PackedByteArray([1, 1, 1, 1, 1]), "mines": 5}]
	errors = CustomLevel.validate(pack)
	assert(errors.size() >= 1 and errors[0].contains("雷太多"), "超上限的雷数没被拦住：%s" % [errors])
	assert(CustomLevel.max_mines(_first(pack)) == 4, "5 格小盘只保首点，雷上限应为 4")

	# 大盘让出首点 3x3
	assert(CustomLevel.max_mines(CustomLevel.make_map()) == 48 - 9, "48 格盘雷上限应为 39")

	# 细长盘按最坏首点算：2x6 每格最多 5 个邻格，让出 6 格。
	var strip := CustomLevel.make_map(6, 2, 1)
	assert(CustomLevel.mine_reserve(strip) == 6 and CustomLevel.max_mines(strip) == 6, "细长盘雷上限应为 6，实际 %d" % CustomLevel.max_mines(strip))

	# 多图时错误要指出是第几张。
	var multi := CustomLevel.make_default()
	multi["maps"] = [CustomLevel.make_map(3, 3, 1), {"width": 5, "height": 1, "mask": PackedByteArray([1, 1, 0, 1, 1]), "mines": 1}]
	errors = CustomLevel.validate(multi)
	assert(errors.size() >= 1 and errors[0].begins_with("第 2 张："), "多图错误没有标出图序：%s" % [errors])

	# 道具挤满只是软提示：不拦开局，多出的会放不下。
	pack["maps"] = [{"width": 5, "height": 1, "mask": PackedByteArray([1, 1, 1, 1, 1]), "mines": 1}]
	pack["items"] = CustomLevel.default_items()
	pack["items"]["lantern"] = 10
	assert(CustomLevel.is_valid(pack), "道具多不该拦开局")
	var notes := CustomLevel.warnings(pack)
	assert(notes.size() == 1 and notes[0].contains("放不下"), "道具挤满没有软提示：%s" % [notes])

	# 5 格 - 1 雷 - 首点 1 = 3 个空位，放 2 个道具刚好不提示。
	pack["items"] = {"lantern": 1, "xray": 1}
	assert(CustomLevel.warnings(pack).is_empty(), "道具放得下时不该提示：%s" % [CustomLevel.warnings(pack)])

	# 空包与超量图都要拦。
	var empty := {"name": "空", "items": {}, "maps": []}
	assert(not CustomLevel.is_valid(empty), "没有地图的包该被拦住")
	var too_many := {"name": "多", "items": {}, "maps": []}
	for i in CustomLevel.MAX_MAPS + 1:
		(too_many["maps"] as Array).append(CustomLevel.make_map(3, 3, 1))
	assert(not CustomLevel.is_valid(too_many), "超过上限的图数该被拦住")


func _check_import_variants() -> void:
	# v1 老文件：字段摊在顶层，要能被裹成只有一张图的包。
	var v1 := """{"name": "ASCII", "mines": 2, "map": ["###.", "#..#", "####"]}"""
	var result := CustomLevel.from_json(v1)
	assert(bool(result["ok"]), "v1 ASCII 行没读进来：" + String(result["error"]))
	var pack: Dictionary = result["level"]
	assert(CustomLevel.map_count(pack) == 1, "v1 应该裹成 1 张图")
	assert(int(_first(pack)["width"]) == 4 and int(_first(pack)["height"]) == 3, "v1 推出的尺寸不对")
	assert(CustomLevel.active_count(_first(pack)) == 9, "v1 可玩格数不对")

	# v2 多图，行可以是 0/1 数组也可以是 #. 字符串。
	var v2 := """{"version": 2, "name": "双", "items": {"lantern": 1}, "maps": [
		{"mines": 1, "map": [[1, 1], [1, 1]]},
		{"mines": 2, "map": ["###", "###"]}
	]}"""
	var multi := CustomLevel.from_json(v2)
	assert(bool(multi["ok"]), "v2 多图没读进来：" + String(multi["error"]))
	assert(CustomLevel.map_count(multi["level"]) == 2, "v2 应该读出 2 张图")
	assert(CustomLevel.item_count(multi["level"], "lantern") == 1, "v2 初始道具没读到")

	assert(not bool(CustomLevel.from_json("""{"map": [[1, 1], [1]], "mines": 1}""")["ok"]), "行宽不一致该被拒绝")
	assert(not bool(CustomLevel.from_json("not json")["ok"]), "非 JSON 该被拒绝")
	assert(not bool(CustomLevel.from_json("[1, 2, 3]")["ok"]), "非对象 JSON 该被拒绝")
	assert(not bool(CustomLevel.from_json("""{"width": 3, "map": [[1, 1]], "mines": 1}""")["ok"]), "width 与 map 不一致该被拒绝")
	assert(not bool(CustomLevel.from_json("""{"version": 99, "map": [[1, 1]], "mines": 1}""")["ok"]), "更新的版本该被拒绝")
	assert(not bool(CustomLevel.from_json("""{"version": 2, "maps": []}""")["ok"]), "空 maps 该被拒绝")
	# 多图里的坏图要指出是第几张。
	var bad_second := CustomLevel.from_json("""{"version": 2, "maps": [{"mines":1,"map":[[1,1]]}, {"mines":1,"map":[[1,1],[1]]}]}""")
	assert(not bool(bad_second["ok"]) and String(bad_second["error"]).begins_with("第 2 张："), "坏图没标出图序：%s" % String(bad_second["error"]))


func _check_editor_painting() -> void:
	var editor = LevelEditorScript.new()
	root.add_child(editor)
	await process_frame
	editor.present()
	var grid: Control = editor.get("_grid")
	grid.size = Vector2(760, 560)
	grid.set_dimensions(6, 4)
	grid.fill_all(0)
	assert(grid.bit_at(0, 0) == 0, "清空后格子还亮着")

	# 左键从 (1,1) 拖到 (4,2)：矩形内全亮，外面不动。
	_press(grid, grid.cell_center(Vector2i(1, 1)), MOUSE_BUTTON_LEFT)
	_move(grid, grid.cell_center(Vector2i(4, 2)))
	_release(grid, grid.cell_center(Vector2i(4, 2)), MOUSE_BUTTON_LEFT)
	for y in 4:
		for x in 6:
			var expected := 1 if (x >= 1 and x <= 4 and y >= 1 and y <= 2) else 0
			assert(grid.bit_at(x, y) == expected, "矩形填充结果不对 (%d,%d)=%d" % [x, y, grid.bit_at(x, y)])

	# 右键从 (4,2) 反向拖到 (3,1)：矩形内擦掉，拖动方向无关。
	_press(grid, grid.cell_center(Vector2i(4, 2)), MOUSE_BUTTON_RIGHT)
	_move(grid, grid.cell_center(Vector2i(3, 1)))
	_release(grid, grid.cell_center(Vector2i(3, 1)), MOUSE_BUTTON_RIGHT)
	assert(grid.bit_at(3, 1) == 0 and grid.bit_at(4, 2) == 0, "右键矩形没擦掉")
	assert(grid.bit_at(1, 1) == 1 and grid.bit_at(2, 2) == 1, "右键擦过界了")

	# 左键点在已亮的格子上 = 切换成暗。
	_press(grid, grid.cell_center(Vector2i(1, 1)), MOUSE_BUTTON_LEFT)
	_release(grid, grid.cell_center(Vector2i(1, 1)), MOUSE_BUTTON_LEFT)
	assert(grid.bit_at(1, 1) == 0, "左键单击已亮格没有切换成暗")

	# 掩码变化要同步进当前那张图；改尺寸保留左上角。
	var pack: Dictionary = editor.current_level()
	var one := CustomLevel.map_at(pack, 0)
	assert(int(one["width"]) == 6 and int(one["height"]) == 4, "编辑器没同步尺寸")
	assert((one["mask"] as PackedByteArray)[2 * 6 + 2] == 1, "编辑器没同步掩码")
	grid.set_dimensions(3, 3)
	assert(grid.bit_at(2, 2) == 1 and grid.bit_at(0, 0) == 0, "缩尺寸没保留左上角")
	assert(grid.bit_at(2, 0) == 0 and grid.width == 3, "缩尺寸结果不对")

	# 校验文案：断开的图不能开局，也不发 play_requested。
	var plays: Array = []
	editor.play_requested.connect(func(_l: Dictionary) -> void: plays.append(1))
	grid.fill_all(0)
	grid.apply_rect(Vector2i(0, 0), Vector2i(0, 0), 1)
	grid.apply_rect(Vector2i(2, 2), Vector2i(2, 2), 1)
	(editor.get("_play_button") as Button).pressed.emit()
	assert(plays.is_empty(), "不连通的图居然放行开局了")
	assert(String((editor.get("_error_label") as Label).text).contains("连成一块"), "没提示为什么不能开局")

	# 导出名字对话框：确认后把名字写回关卡包。
	grid.fill_all(1)
	editor.get("_mines_spin").value = 2
	(editor.get("_export_button") as Button).pressed.emit()
	assert((editor.get("_name_dialog") as Control).visible, "导出没有先问关卡包名")
	(editor.get("_name_dialog_input") as LineEdit).text = "小盘/test"
	(editor.get("_name_dialog_cancel") as Button).pressed.emit()
	assert(not (editor.get("_name_dialog") as Control).visible, "取消没关掉名字框")
	assert(String(editor.current_level()["name"]) != "小盘_test", "取消导出不该改名")

	# 创意工坊关着时，发布按钮不该出现。
	assert(not (editor.get("_publish_button") as Button).visible or WorkshopApi.ENABLED, "工坊没开时不该显示发布按钮")

	# 步进器：加减按钮各走一步，到边界就禁用，值同步进当前图。
	var mines_stepper = editor.get("_mines_spin")
	mines_stepper.value = 1
	assert(mines_stepper.minus_button.disabled, "到下限减号没禁用")
	mines_stepper.plus_button.pressed.emit()
	mines_stepper.plus_button.pressed.emit()
	assert(int(mines_stepper.value) == 3 and int(CustomLevel.map_at(editor.current_level(), 0)["mines"]) == 3, "加号没把雷数走到 3")
	mines_stepper.minus_button.pressed.emit()
	assert(int(mines_stepper.value) == 2 and not mines_stepper.minus_button.disabled, "减号没走回 2")
	var lantern_stepper = editor.get("_item_spins")["lantern"]
	lantern_stepper.value = CustomLevel.MAX_ITEM_COUNT
	assert(lantern_stepper.plus_button.disabled, "到上限加号没禁用")
	lantern_stepper.plus_button.pressed.emit()
	assert(int(lantern_stepper.value) == CustomLevel.MAX_ITEM_COUNT, "加号越过了上限")

	# 导入文本走同一条解析路，成功后编辑器拿到新图。
	assert(editor.import_text("""{"name": "导入", "mines": 1, "map": [[1, 1, 1], [1, 0, 1]]}"""), "合法文本导入失败")
	assert(String(editor.current_level()["name"]) == "导入", "导入后名字没变")
	var imported := CustomLevel.map_at(editor.current_level(), 0)
	assert(int(imported["width"]) == 3 and int(imported["height"]) == 2, "导入后尺寸没变")
	assert(grid.bit_at(1, 1) == 0 and grid.bit_at(0, 1) == 1, "导入后画布没刷新")
	assert(not editor.import_text("{bad"), "坏文本导入居然成功")
	assert(String((editor.get("_error_label") as Label).text).begins_with("导入失败"), "坏文本没有报错文案")
	assert(String(editor.current_level()["name"]) == "导入", "坏文本导入不该改掉当前关卡")

	editor.queue_free()
	await process_frame


## 地图列表：添加、切换、改一张不影响另一张、上下移、删除。
func _check_map_list() -> void:
	var editor = LevelEditorScript.new()
	root.add_child(editor)
	await process_frame
	editor.present()
	var grid: Control = editor.get("_grid")
	grid.size = Vector2(760, 560)

	assert(CustomLevel.map_count(editor.current_level()) == 1, "新编辑器应该只有 1 张图")
	assert(editor.current_map_index() == 0, "新编辑器应该停在第 1 张")
	assert((editor.get("_delete_map_button") as Button).disabled, "只有 1 张图时删除该禁用")

	# 第一张设成 4×3、2 雷。
	editor.get("_width_spin").value = 4
	editor.get("_height_spin").value = 3
	editor.get("_mines_spin").value = 2

	# 添加第二张：新图接在当前之后，并自动选中。
	(editor.get("_add_map_button") as Button).pressed.emit()
	assert(CustomLevel.map_count(editor.current_level()) == 2, "添加后应该有 2 张图")
	assert(editor.current_map_index() == 1, "添加后应该选中新图")
	assert(not (editor.get("_delete_map_button") as Button).disabled, "有 2 张图时删除该放开")

	# 改第二张，不能影响第一张。
	editor.get("_width_spin").value = 6
	editor.get("_height_spin").value = 2
	editor.get("_mines_spin").value = 5
	var pack: Dictionary = editor.current_level()
	assert(int(CustomLevel.map_at(pack, 0)["width"]) == 4, "改第二张把第一张也改了")
	assert(int(CustomLevel.map_at(pack, 0)["mines"]) == 2, "改第二张把第一张雷数也改了")
	assert(int(CustomLevel.map_at(pack, 1)["width"]) == 6 and int(CustomLevel.map_at(pack, 1)["mines"]) == 5, "第二张没存住")

	# 切回第一张：控件要还原成第一张的值。
	editor.call("_select_map", 0)
	assert(editor.current_map_index() == 0, "切换图序没生效")
	assert(int(editor.get("_width_spin").value) == 4 and int(editor.get("_mines_spin").value) == 2, "切回第一张控件没还原")
	assert(grid.width == 4 and grid.height == 3, "切回第一张画布没还原")

	# 上下移动：把第一张移到后面。
	assert((editor.get("_move_up_button") as Button).disabled, "第一张的上移该禁用")
	(editor.get("_move_down_button") as Button).pressed.emit()
	assert(editor.current_map_index() == 1, "下移后应该跟着选中")
	pack = editor.current_level()
	assert(int(CustomLevel.map_at(pack, 0)["width"]) == 6, "下移没换位置")
	assert(int(CustomLevel.map_at(pack, 1)["width"]) == 4, "下移没换位置")

	# 初始道具是整包共用的，切图不该改变它。
	editor.get("_item_spins")["lantern"].value = 4
	editor.call("_select_map", 0)
	assert(CustomLevel.item_count(editor.current_level(), "lantern") == 4, "切图把初始道具弄丢了")
	assert(int(editor.get("_item_spins")["lantern"].value) == 4, "切图后道具控件没保持")

	# 删除当前这张。
	(editor.get("_delete_map_button") as Button).pressed.emit()
	assert(CustomLevel.map_count(editor.current_level()) == 1, "删除后应该只剩 1 张")
	assert((editor.get("_delete_map_button") as Button).disabled, "剩 1 张时删除该禁用")

	editor.queue_free()
	await process_frame


func _check_game_flow() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.4).timeout

	var start_screen := game.get("_start_screen") as StartScreen
	assert(start_screen != null, "标题页没起来")
	var custom_button := start_screen.get_node("Menu/DuelSlot/DuelRow/CustomButton") as Button
	assert(custom_button != null, "标题页没有自定义按钮")
	# 工坊没开时标题页不该长出那颗按钮。
	assert(
		WorkshopApi.ENABLED or not start_screen.has_node("Menu/DuelSlot/DuelRow/WorkshopButton"),
		"工坊没开时不该出现创意工坊按钮"
	)
	custom_button.pressed.emit()
	await process_frame
	await process_frame
	assert(game.get("_start_screen") == null, "点自定义后标题页没拆")
	var editor = game.get("_custom_editor")
	assert(editor != null and editor.is_open(), "点自定义后编辑器没亮")
	assert(int(game.get("_run_number")) == 0, "编辑器阶段不该开盘")

	# 画一张 5x3 缺角图、配初始道具，开局。
	var pack := CustomLevel.make_default()
	pack["name"] = "流程测试"
	pack["maps"] = [{
		"width": 5,
		"height": 3,
		"mask": PackedByteArray([
			1, 1, 1, 1, 0,
			1, 1, 1, 1, 1,
			0, 1, 1, 1, 1,
		]),
		"mines": 3,
	}]
	pack["items"] = {
		"lantern": 2, "compass": 0, "orbital_strike": 1, "super_luck": 0,
		"medical_kit": 0, "xray": 1, "chain": 1, "enlarge": 0, "detect": 1,
	}
	editor.load_level(pack)
	(editor.get("_play_button") as Button).pressed.emit()
	await process_frame
	await create_timer(0.3).timeout
	assert(not editor.is_open(), "开局后编辑器没收起")
	assert(bool(game.call("_is_custom")), "开局后没进入自定义模式")
	var board := game.get("_board") as MinesweeperBoard
	assert(board != null, "自定义开局没建棋盘")
	assert(board.width == 5 and board.height == 3, "棋盘尺寸没照配置来：%dx%d" % [board.width, board.height])
	assert(not board.is_active(4) and not board.is_active(10) and board.is_active(0), "棋盘掩码没照配置来")
	assert(board.active_cell_count == 13, "可玩格数不对：%d" % board.active_cell_count)
	assert(board.mine_count == 3, "雷数没照配置来：%d" % board.mine_count)
	# 初始道具经由 `*_bonus` 铺到棋盘上，九种都要对得上。
	assert(board.lantern_count == 2 and board.compass_count == 0, "鸟类道具数量没照初始道具来")
	assert(board.orbital_strike_count == 1 and board.super_luck_count == 0, "鸟类道具数量没照初始道具来")
	assert(board.medical_kit_count == 0 and board.xray_count == 1, "地面道具数量没照初始道具来")
	assert(board.chain_count == 1 and board.enlarge_count == 0 and board.detect_count == 1, "地面道具数量没照初始道具来")
	assert(String((game.get("_stage_board_label") as Label).text).contains("流程测试"), "棋盘上方没显示自定义关卡名")
	var cells: Array = game.get("_cells")
	assert(cells.size() == 15, "格子数不对")
	assert(not (cells[4] as Control).visible, "空洞格没有隐藏")
	assert(not GameSave.exists(), "自定义开局不该写存档")

	# 先翻一格把雷布下去，再把血量打到 0 走一遍结算：结果卡要弹在编辑器这一层，
	# 而不是单机的 GameOverOverlay。
	var first_safe := -1
	for index in 15:
		if board.is_active(index):
			first_safe = index
			break
	game.call("_on_cell_revealed", first_safe)
	await create_timer(0.3).timeout
	assert(board.mines_placed, "首翻后没有布雷")
	game.set("_player_hp", 0)
	game.call("_finish_game")
	var deadline := Time.get_ticks_msec() + 8000
	while not (editor.get("_result_card") as Control).visible:
		assert(Time.get_ticks_msec() < deadline, "自定义局结束后结果卡没弹出来")
		await create_timer(0.1).timeout
	assert(not (game.get("_game_over_overlay") as Control).visible, "自定义局不该弹单机的结算界面")
	assert(String((editor.get("_result_title") as Label).text) == "踩雷了", "血量归零应判负")
	assert(not GameSave.exists(), "自定义局结束不该写存档")

	# 返回编辑：棋盘拆掉、编辑器回来、配置还在。
	(editor.get("_edit_button") as Button).pressed.emit()
	await process_frame
	await process_frame
	assert(editor.is_open() and (editor.get("_page") as Control).visible, "返回编辑后编辑页没亮")
	assert(not bool(game.call("_is_custom")), "返回编辑后还挂着自定义局")
	assert((game.get("_cells") as Array).is_empty(), "返回编辑后棋盘没拆")
	assert(int(CustomLevel.map_at(editor.current_level(), 0)["width"]) == 5, "返回编辑后配置丢了")

	# 再开一局 → 再来一局：同配置、从第一张图重来、跑合成态清干净。
	(editor.get("_play_button") as Button).pressed.emit()
	await create_timer(0.3).timeout
	game.set("_gold", 999)
	game.call("_on_custom_replay_requested")
	await create_timer(0.4).timeout
	assert(int(game.get("_custom_map_index")) == 0, "再来一局没回到第一张图")
	assert(int(game.get("_gold")) != 999, "再来一局没清掉上一轮的金币")
	assert((game.get("_board") as MinesweeperBoard).width == 5, "再来一局丢了配置")

	# 回标题：自定义状态清空、标题页重建。
	game.call("_return_to_main_menu")
	await process_frame
	await process_frame
	assert(not editor.is_open(), "回标题后编辑器还开着")
	assert(not bool(game.call("_is_custom")), "回标题后还挂着自定义局")
	assert(game.get("_start_screen") != null, "回标题后标题页没重建")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame


## 多图包：打完第一张要进商店，买完继续打第二张，最后一张打完才弹结果卡。
func _check_multi_map_flow() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.4).timeout

	var pack := CustomLevel.make_default()
	pack["name"] = "双城记"
	pack["maps"] = [
		{"width": 4, "height": 3, "mask": _solid(4, 3), "mines": 2},
		{"width": 3, "height": 3, "mask": _solid(3, 3), "mines": 1},
	]
	pack["items"] = {
		"lantern": 1, "compass": 0, "orbital_strike": 0, "super_luck": 0,
		"medical_kit": 0, "xray": 0, "chain": 0, "enlarge": 0, "detect": 0,
	}
	game.call("_on_custom_play_requested", pack)
	await create_timer(0.4).timeout

	var board := game.get("_board") as MinesweeperBoard
	assert(board.width == 4 and board.height == 3, "多图包第一张尺寸不对：%dx%d" % [board.width, board.height])
	assert(int(game.get("_custom_map_index")) == 0, "开局该停在第一张")
	assert(String((game.get("_stage_board_label") as Label).text).contains("1/2"), "多图包没显示图序进度")

	# 判定为通关，走结算：应当进商店而不是弹结果卡。
	var first_safe := -1
	for index in board.width * board.height:
		if board.is_active(index):
			first_safe = index
			break
	game.call("_on_cell_revealed", first_safe)
	await create_timer(0.3).timeout
	board.won = true
	game.call("_finish_game")

	# 账单会停在「继续」上等玩家点——多图包和单机一样，先看账单再进商店。
	await _click_bill(game)
	var shop: CanvasItem = game.get("_shop_layer")
	var deadline := Time.get_ticks_msec() + 20000
	while not shop.visible:
		assert(Time.get_ticks_msec() < deadline, "打完第一张没有进商店")
		await create_timer(0.1).timeout
	var editor = game.get("_custom_editor")
	assert(editor == null or not (editor.get("_result_card") as Control).visible, "还有下一张图时不该弹结果卡")
	assert(int(game.get("_custom_map_index")) == 1, "进商店后图序没推进")

	# 商店里买到的加成要带到下一张图上：直接加一发灯笼再继续。
	var lantern_before := int(game.get("_lantern_bonus"))
	game.set("_lantern_bonus", lantern_before + 3)
	game.call("_on_shop_continue")
	await create_timer(0.4).timeout
	board = game.get("_board") as MinesweeperBoard
	assert(board.width == 3 and board.height == 3, "商店之后没换到第二张图：%dx%d" % [board.width, board.height])
	assert(board.mine_count == 1, "第二张图雷数不对：%d" % board.mine_count)
	assert(board.lantern_count == lantern_before + 3, "商店买的加成没带到下一张图：%d" % board.lantern_count)
	assert(String((game.get("_stage_board_label") as Label).text).contains("2/2"), "第二张图没更新图序进度")

	# 最后一张打完才弹结果卡，标题是「通关！」。
	first_safe = -1
	for index in board.width * board.height:
		if board.is_active(index):
			first_safe = index
			break
	game.call("_on_cell_revealed", first_safe)
	await create_timer(0.3).timeout
	board.won = true
	game.call("_finish_game")
	editor = game.get("_custom_editor")
	assert(editor != null, "结算时编辑器该已经建好")
	deadline = Time.get_ticks_msec() + 20000
	while not (editor.get("_result_card") as Control).visible:
		assert(Time.get_ticks_msec() < deadline, "最后一张打完没弹结果卡")
		await create_timer(0.1).timeout
	assert(String((editor.get("_result_title") as Label).text) == "通关！", "多图包全打完该显示通关")
	assert(String((editor.get("_result_body") as Label).text).contains("2/2"), "结果卡没写清打到第几张")
	assert(not GameSave.exists(), "多图自定义局也不该写存档")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame


## 账单是交互式的：等它亮出来并放开「继续」，再替玩家点一下。
func _click_bill(game) -> void:
	var bill := game.get("_level_bill") as LevelBill
	var deadline := Time.get_ticks_msec() + 20000
	while bill == null or not bill.visible or bill.continue_button.disabled:
		assert(Time.get_ticks_msec() < deadline, "账单没出现或「继续」没放开")
		await create_timer(0.1).timeout
		bill = game.get("_level_bill") as LevelBill
	bill.continue_button.pressed.emit()
	await create_timer(0.35).timeout


func _solid(width: int, height: int) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(width * height)
	mask.fill(1)
	return mask


func _press(grid: Control, position: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = position
	grid._gui_input(event)


func _move(grid: Control, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	grid._gui_input(event)


func _release(grid: Control, position: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = false
	event.position = position
	grid._gui_input(event)
