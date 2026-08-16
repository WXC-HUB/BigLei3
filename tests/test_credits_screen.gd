extends SceneTree
## 制作人名单：入口、星战滚动的透视、BGM 切换、返回，以及名单内容的约定
## （主创两人具名，其余职位一律夜鹭，鸟类一律「夜鹭 饰」）。

const CREDITS := preload("res://scripts/ui/credits_screen.gd")
const LEAD_NAMES := ["Ago.Pang", "Claude.Wu"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(_test_crawl_contract())
	assert(await _test_open_switch_and_close())
	print("Credits screen: entry, crawl perspective, BGM switch and content passed")
	await process_frame
	quit()


## 名单内容不靠肉眼核对：主创之外的每个职位都必须是夜鹭，演员表每行都是「饰」。
func _test_crawl_contract() -> bool:
	var texts: Array[String] = []
	for entry in CREDITS.CRAWL_LINES:
		texts.append(entry["text"])
	for name in LEAD_NAMES:
		assert(texts.has(name), "Missing lead creator %s" % name)
	assert(not texts.has("pyq"), "The old single lead credit is still listed")

	var lead_index := texts.find("主创")
	assert(lead_index >= 0, "No 主创 heading")
	# 主创 标题后面紧跟的两行就是两位主创，再往后的每个职位都必须挂夜鹭。
	assert(texts[lead_index + 1] == LEAD_NAMES[0] and texts[lead_index + 2] == LEAD_NAMES[1])

	# 无厘头要职那一段挂两位主创，「剩下的活」那一段整块挂夜鹭，两段不能串味。
	var odd_index := texts.find("另 有 要 职")
	var rest_index := texts.find("剩 下 的 活")
	var cast_index := texts.find("演 员 表")
	assert(odd_index > lead_index, "No odd-jobs section after the leads")
	assert(rest_index > odd_index, "No 剩下的活 section after the odd jobs")
	assert(cast_index > rest_index, "No cast section")
	for wanted in ["点外卖", "吃火锅", "思考人生"]:
		var at := texts.find(wanted)
		assert(at > odd_index and at < rest_index, "Odd job %s is missing or out of section" % wanted)

	var odd_jobs := 0
	for index in range(odd_index + 1, rest_index):
		if CREDITS.CRAWL_LINES[index]["color"] != CREDITS.CREAM:
			continue
		var credited := false
		for name in LEAD_NAMES:
			credited = credited or texts[index].contains(name)
		assert(credited, "Odd job credit %s goes to neither lead" % texts[index])
		odd_jobs += 1
	assert(odd_jobs >= 8, "Expected the leads to hold at least eight odd jobs, found %d" % odd_jobs)

	var roles := 0
	for index in range(rest_index + 1, cast_index):
		if texts[index].is_empty():
			continue
		if CREDITS.CRAWL_LINES[index]["color"] == CREDITS.CREAM:
			assert(texts[index] == "夜鹭", "Job credit %s is not 夜鹭" % texts[index])
			roles += 1
	assert(roles >= 5, "Expected the rest of the jobs to be credited to 夜鹭")

	# 进了游戏的鸟由夜鹭饰，没进游戏的一律被鸽子放了鸽子——两种署名之外的都算写错。
	var in_game := 0
	var no_shows := 0
	for index in range(cast_index + 1, texts.size()):
		if not texts[index].contains("——"):
			continue
		if texts[index].ends_with("夜鹭 饰"):
			in_game += 1
		elif texts[index].ends_with("鸽子 饰"):
			no_shows += 1
		else:
			assert(false, "Cast line %s is credited to nobody we know" % texts[index])
	assert(in_game >= 5, "Expected every playable bird to be credited as 夜鹭 饰")
	assert(no_shows >= 5, "Expected the birds that never made it in to be credited as 鸽子 饰")
	assert(texts.has("疗愈鸟 —— 鸽子 饰"), "疗愈鸟 should be one of the no-shows")
	# 放鸽子的名单里不能混进真出场过的鸟，否则梗就塌了。
	for played in ["小蓝鸟", "夜鹭", "红尾水鸲", "啄木鸟", "红隼"]:
		assert(
			not texts.has("%s —— 鸽子 饰" % played),
			"%s actually shows up in game and cannot be a no-show" % played
		)

	# 鸣谢那一串工具是逐个点名的，少一个都算漏。
	var thanks_index := texts.find("特 别 鸣 谢")
	assert(thanks_index > cast_index, "No thanks section after the cast")
	for tool in ["Chat GPT", "Claude", "Gemini", "FLUX生图", "豆包", "DeepSeek"]:
		assert(texts.find(tool) > thanks_index, "Special thanks is missing %s" % tool)
	return true


func _test_open_switch_and_close() -> bool:
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var start_screen := game.get("_start_screen") as StartScreen
	var credits := game.get("_credits_screen") as CreditsScreen
	assert(credits != null and not credits.visible, "Credits should stay hidden until asked for")
	var main_bgm := game.get_node("BGM") as AudioStreamPlayer

	(start_screen.get_node("%CreditsButton") as Button).pressed.emit()
	await create_timer(0.4).timeout
	assert(credits.visible, "Credits button did not open the credits")
	assert(credits.bgm.playing, "Credits BGM did not start")
	assert(main_bgm.stream_paused, "Menu BGM kept playing under the credits")

	# 透视：同一行在两个时刻之间必须变小并向地平线靠拢。
	var line := await _first_visible_line(credits)
	assert(line != null, "The crawl never showed a line")
	var scale_before := line.scale.x
	var y_before := line.position.y
	await create_timer(0.5).timeout
	assert(line.scale.x < scale_before, "The crawl line did not recede")
	assert(line.position.y < y_before, "The crawl line did not rise toward the horizon")

	assert(credits.bgm.stream == CREDITS.HYPE_STREAM, "劲爆男声 should be the default track")
	credits.tender_button.pressed.emit()
	await process_frame
	var tender_stream := credits.bgm.stream
	assert(tender_stream == CREDITS.TENDER_STREAM, "极致柔情 button did not select its track")
	credits.hype_button.pressed.emit()
	await process_frame
	assert(credits.bgm.stream != tender_stream, "The BGM switch did not change tracks")
	assert(credits.bgm.playing, "The switched track is not playing")
	credits.tender_button.pressed.emit()
	await process_frame
	assert(credits.bgm.stream == tender_stream, "Switching back did not restore the other track")

	credits.back_button.pressed.emit()
	await create_timer(0.6).timeout
	assert(not credits.visible, "Back did not close the credits")
	assert(not credits.bgm.playing, "Credits BGM kept playing after leaving")
	assert(not main_bgm.stream_paused, "Menu BGM was not resumed")
	assert(game.get("_start_screen") != null, "Leaving the credits should land back on the title")
	game.queue_free()
	await process_frame
	return true


func _first_visible_line(credits: CreditsScreen) -> Label:
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		for child in credits.crawl_root.get_children():
			if child is Label and child.visible:
				return child
		await process_frame
	return null
