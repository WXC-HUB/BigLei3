extends SceneTree
## 红隼模式下其他鸟的去留：除了红隼自己和长尾山雀，其余七只都滑出屏幕，
## 把这一刻让给红隼；模式结束后全部回到枝头。
##
## 长尾山雀是有意留下的——红隼模式里那一次左键仍可能翻出巨大，它得在枝上等着摔。
## 这条测试存在的意义就是钉住这份名单：以后再加鸟，漏挂进去就会在这里报出来。

const TUTORIAL_LEVEL_COUNT := 8
## 收走的：蓝鸟、红尾水鸲、夜鹭、啄木鸟、灰喜鹊、小嘴乌鸦、斑鸠。
const STOWED := [
	"BlueBirdPerch", "RedBirdPerch", "BlackBirdPerch", "AttackerBirdPerch",
	"MagpieBirdPerch", "CrowBirdPerch", "DoveBirdPerch",
]
## 留在原地的：红隼本人，以及要等着摔的长尾山雀。
const STAYS := ["EgBirdPerch", "TitBirdPerch"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(40.0).timeout.connect(func() -> void:
		push_error("Super luck bird hiding test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_super_luck_bird_hiding_save.json"
	GameSave.clear()
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var title := game.get("_start_screen") as Control
	if title != null:
		game.set("_start_screen", null)
		title.get_parent().queue_free()
	for flag in [
		"_red_bird_unlocked", "_night_heron_unlocked", "_attacker_bird_unlocked",
		"_lucky_bird_unlocked", "_tit_bird_unlocked", "_magpie_bird_unlocked",
		"_crow_bird_unlocked", "_dove_bird_unlocked",
	]:
		game.set(flag, true)
	for _level in range(TUTORIAL_LEVEL_COUNT + 1):
		game.call("_start_game")
	await create_timer(0.6).timeout

	# 名单本身就是断言的一部分：九只鸟只能分成「收走」和「留下」两堆，不许有漏网的。
	var listed: Array[String] = []
	for bird in (game.call("_super_luck_other_birds") as Array):
		listed.append((bird as Node).name)
	assert(listed.size() == STOWED.size(), "Kestrel stow list has %d birds, expected %d: %s" % [
		listed.size(), STOWED.size(), str(listed),
	])
	for name in STOWED:
		assert(listed.has(name), "%s is missing from the kestrel stow list" % name)
	for name in STAYS:
		assert(not listed.has(name), "%s should never be stowed for the kestrel" % name)

	var homes := {}
	for name in STOWED + STAYS:
		var sprite := game.get_node(name).get_node("Sprite") as Control
		homes[name] = sprite.global_position

	game.call("_enter_super_luck_mode", 1)
	# 滑出去是 0.36s 的补间，滑完把整个栖位收成不可见、坐标还原，所以等它播完再看可见性。
	await create_timer(1.2).timeout
	for name in STOWED:
		assert(not (game.get_node(name) as Control).visible, "%s stayed on screen for the kestrel" % name)
	for name in STAYS:
		var perch := game.get_node(name) as Control
		var sprite := perch.get_node("Sprite") as Control
		assert(perch.visible and sprite.visible, "%s vanished during the kestrel's turn" % name)
		assert(
			sprite.global_position.is_equal_approx(homes[name]),
			"%s left its perch during the kestrel's turn" % name,
		)

	# 模式结束：七只都回来。
	game.call("_consume_super_luck_click")
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline and bool(game.get("_super_luck_settling")):
		await process_frame
	await create_timer(0.8).timeout
	for name in STOWED + STAYS:
		var perch := game.get_node(name) as Control
		var sprite := perch.get_node("Sprite") as Control
		assert(perch.visible and sprite.visible, "%s did not come back after the kestrel's turn" % name)
		assert(
			sprite.global_position.is_equal_approx(homes[name]),
			"%s came back to the wrong spot: %s vs %s" % [name, sprite.global_position, homes[name]],
		)
	GameSave.clear()
	print("Super luck bird hiding: seven stowed, kestrel and tit stay, everybody returns")
	quit()
