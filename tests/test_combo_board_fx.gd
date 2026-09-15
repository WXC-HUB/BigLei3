extends SceneTree
## ComboBoardFx：烟花必须炸在棋盘之外、画在棋盘之后，跑完要交还 _process。
## 这层每帧现算几百条火星轨迹，冷下来不停机就是一笔白烧的固定开销。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var fx := ComboBoardFx.new()
	fx.size = Vector2(400, 400)
	root.add_child(fx)
	await process_frame

	assert(not fx.is_processing(), "刚建好还没有连击，不该占着 _process")
	assert(fx.mouse_filter == Control.MOUSE_FILTER_IGNORE, "这层盖在棋盘范围上，绝不能吃掉点击")
	assert(fx.z_index < 0, "特效必须画在棋盘背后，否则会压住格子上的数字")
	assert(not fx.clip_contents, "烟花要炸到自身矩形之外，裁剪一开就只剩半朵")

	# 起爆点必须落在棋盘矩形之外——炸在盘面里就会盖住格子。
	var board := Rect2(Vector2.ZERO, fx.size)
	for _try in range(200):
		var point := fx._perimeter_point(randf())
		assert(not board.has_point(point), "起爆点落进了棋盘内部：%s" % point)

	# 绕盘一圈的取点要真的绕满一圈，四条边都得有。
	var sides := {"top": 0, "right": 0, "bottom": 0, "left": 0}
	for step in range(64):
		var point := fx._perimeter_point(float(step) / 64.0)
		if point.y < 0.0:
			sides["top"] += 1
		elif point.y > fx.size.y:
			sides["bottom"] += 1
		elif point.x > fx.size.x:
			sides["right"] += 1
		else:
			sides["left"] += 1
	for side in sides:
		assert(sides[side] > 0, "绕盘一圈漏了一条边：%s" % side)

	# 同一颗火星每帧都得落在同一条轨迹上，否则烟花会整束抖动。
	assert(
		is_equal_approx(ComboBoardFx._hash01(7, 3), ComboBoardFx._hash01(7, 3)),
		"火星的伪随机必须可重复"
	)
	assert(ComboBoardFx._hash01(7, 3) != ComboBoardFx._hash01(7, 4), "同束内的火星不该重叠")
	for a in range(12):
		for b in range(12):
			var value := ComboBoardFx._hash01(a, b)
			assert(value >= 0.0 and value <= 1.0, "火星伪随机越界：%f" % value)

	# 连击越高炸得越多——「连击越多越强」这条就靠它。
	fx.set_state(2)
	fx.play_hit(2)
	var low := fx._bursts.size()
	fx.reset_visuals()
	fx.set_state(20)
	fx.play_hit(20)
	assert(fx._bursts.size() > low, "高连击应该一次炸更多束：%d vs %d" % [fx._bursts.size(), low])
	assert(fx._bursts[0].sparks > ComboBoardFx.SPARKS_MIN, "高连击的每束火星也该更多")

	# 齐射不得越过上限，否则一帧里会堆出上千条线。
	for _volley in range(6):
		fx.play_milestone(20)
	assert(fx._bursts.size() <= ComboBoardFx.BURST_LIMIT, "同时存活的烟花束超了上限")

	# 连击还活着时光晕要一直画；断连收场后必须自己停机。
	fx.set_state(6)
	var stayed_awake := not await _settles(fx, 1.2)
	assert(stayed_awake, "连击还在，盘后光晕必须继续画")
	fx.play_break(6)
	assert(await _settles(fx, 6.0), "断连收场后应停掉 _process")

	fx.set_state(9)
	assert(fx.is_processing(), "喂了连击状态就该在跑")
	fx.reset_visuals()
	assert(not fx.is_processing(), "换盘重置后应立即交还 _process")

	print("ComboBoardFx: off-board bursts, behind-board draw, scaling, and idle shutdown passed")
	quit()


## 等表现层自己冷下来，最多等 `seconds` 秒真实时间。
## 按墙钟而不是帧数计：headless 不限帧时每帧 delta 极小，数帧数会提前放弃。
func _settles(fx: ComboBoardFx, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not fx.is_processing():
			return true
	return false
