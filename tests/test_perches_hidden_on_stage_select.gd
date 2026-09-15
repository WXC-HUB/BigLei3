extends SceneTree
## 选关陈列柜上不该出现任何一只鸟的栖枝：它们属于关卡里的布景，由
## `_set_scenery_visible(false)` 统一收走。每加一只鸟都要把它的栖枝节点名补进
## `SCENERY_PLAY_NODES`——漏了就只有那一只鸟会挂在选关界面的角落里（灰喜鹊和
## 长尾山雀都这样漏过一次）。所以这里按 main.tscn 里实际存在的栖枝逐个查，
## 而不是照着一份写死的名单查。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("Perch visibility test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_perches_hidden_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		screen.get_parent().queue_free()
	await process_frame

	# 全解锁，否则没解锁的鸟本来就是隐藏的，测不出漏没漏。
	var perches: Array[String] = []
	for child in game.get_children():
		if child is BirdPerch:
			perches.append(String(child.name))
	assert(not perches.is_empty(), "main.tscn no longer carries any bird perches")
	for property in game.get_property_list():
		var name := String(property["name"])
		if name.ends_with("_unlocked") and typeof(game.get(name)) == TYPE_BOOL:
			game.set(name, true)
	for _level in range(int(game.get("TUTORIAL_LEVEL_COUNT")) + 1):
		game.call("_start_game")
	await create_timer(5.0).timeout

	var shown_in_level: Array[String] = []
	for perch_name in perches:
		if (game.get_node(perch_name) as CanvasItem).is_visible_in_tree():
			shown_in_level.append(perch_name)
	assert(
		not shown_in_level.is_empty(),
		"No perch was visible during a level, so this test could not tell hidden from broken"
	)

	game.call("_show_world_map")
	await create_timer(2.0).timeout
	var leaked: Array[String] = []
	for perch_name in perches:
		if (game.get_node(perch_name) as CanvasItem).is_visible_in_tree():
			leaked.append(perch_name)
	assert(
		leaked.is_empty(),
		"These perches leaked onto the stage select screen: %s — add them to SCENERY_PLAY_NODES" % str(leaked)
	)

	# 回到关卡里，栖枝要原样回来，别被这趟选关一起收走了。
	game.call("_hide_world_map")
	await process_frame
	var restored: Array[String] = []
	for perch_name in perches:
		if (game.get_node(perch_name) as CanvasItem).is_visible_in_tree():
			restored.append(perch_name)
	assert(
		restored == shown_in_level,
		"Perches did not come back after leaving the map: expected %s, got %s" % [
			str(shown_in_level), str(restored)
		]
	)
	GameSave.clear()
	print("Perch visibility: %d perches shown in level, none leaked onto stage select" % shown_in_level.size())
	quit()
