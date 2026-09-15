extends SceneTree
## 选关图上的蚊子：飞进来、在飞行区里乱飞、慢挪鼠标只会把它吓跑、快挥过身子才拍死、
## 死后过一阵再飞进来一只、拍满三只就彻底退场；stop() 之后消失。
## 全部手动推帧（drive），不依赖真实鼠标。

const FRAME := 1.0 / 60.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Map mosquito test timed out")
		quit(2)
	)
	var bug := MapMosquito.new()
	bug.seed = 7
	root.add_child(bug)
	await process_frame
	assert(bug.mouse_filter == Control.MOUSE_FILTER_IGNORE, "蚊子层必须不吃鼠标事件")
	assert(bug.get_node_or_null("Body") is Sprite2D, "缺少 Body 精灵")
	var body := bug.get_node("Body") as Sprite2D
	assert(body.hframes == 4 and body.vframes == 2, "图集应为 4×2 帧")

	bug.start()
	bug.set_process(false)
	assert(not bug.is_flying(), "start() 之后应先等一会儿再飞进来")
	# 首次延时最长 3 秒。
	for _i in int(3.2 / FRAME):
		bug.drive(FRAME)
	assert(bug.is_flying(), "等过首次延时后蚊子没飞进来")
	assert(body.visible, "飞着的蚊子应可见")

	_check_flight_stays_in_bounds(bug)
	_check_slow_pointer_only_scares(bug)
	_check_big_jump_does_not_count(bug)
	_check_fast_swipe_kills(bug)
	_check_respawn(bug)
	_check_swat_limit_retires(bug)

	bug.stop()
	assert(not bug.is_flying() and not body.visible, "stop() 之后蚊子还在")
	bug.queue_free()
	await process_frame
	print("Map mosquito: 飞行、躲闪、拍死、重生与拍满退场全部通过")
	quit()


## 飞 4 秒：位置在变、翅膀帧在换、从不飞出飞行区。
func _check_flight_stays_in_bounds(bug: MapMosquito) -> void:
	var body := bug.get_node("Body") as Sprite2D
	# 远离指针，免得躲避干扰。
	bug.set_pointer_for_test(Vector2(-2000.0, -2000.0))
	var rect := bug.flight_rect().grow(MapMosquito.CELL_SIZE)
	var first := bug.body_center()
	var frames_seen := {}
	var farthest := 0.0
	for _i in int(4.0 / FRAME):
		bug.drive(FRAME)
		frames_seen[body.frame] = true
		farthest = maxf(farthest, bug.body_center().distance_to(first))
		assert(rect.has_point(body.position), "蚊子飞出了飞行区：%s" % str(body.position))
	assert(bug.is_flying(), "没人碰它却不飞了")
	assert(farthest > 150.0, "4 秒只挪了 %.0f 像素，几乎没动" % farthest)
	assert(frames_seen.size() >= 6, "翅膀帧只轮到了 %d 张" % frames_seen.size())


## 指针贴着身子慢慢挪（约 180 px/s）：不算拍，蚊子反应过来后会拉开距离。
func _check_slow_pointer_only_scares(bug: MapMosquito) -> void:
	var swats := bug.swat_count()
	var pointer := bug.body_center()
	bug.set_pointer_for_test(pointer)
	bug.drive(FRAME)
	var nearest := INF
	var final_gap := 0.0
	for _i in 60:
		pointer += Vector2(3.0, 0.0)
		bug.set_pointer_for_test(pointer)
		bug.drive(FRAME)
		nearest = minf(nearest, bug.body_center().distance_to(pointer))
		final_gap = bug.body_center().distance_to(pointer)
	assert(bug.is_flying(), "慢慢挪过去也把蚊子拍死了")
	assert(bug.swat_count() == swats, "慢挪不该计入拍死")
	assert(final_gap > MapMosquito.FLEE_RADIUS * 0.8, "蚊子没躲开慢慢逼近的指针（距离 %.0f）" % final_gap)


## 指针一帧内从很远跳到身子另一边：像窗口外跳回来的假动作，不算拍。
func _check_big_jump_does_not_count(bug: MapMosquito) -> void:
	var swats := bug.swat_count()
	var body := bug.body_center()
	bug.set_pointer_for_test(body + Vector2(-900.0, 0.0))
	bug.drive(FRAME)
	bug.set_pointer_for_test(body + Vector2(900.0, 0.0))
	bug.drive(FRAME)
	assert(bug.is_flying() and bug.swat_count() == swats, "指针大跳也被算成了拍")
	bug.set_pointer_for_test(Vector2(-2000.0, -2000.0))
	for _i in 30:
		bug.drive(FRAME)


## 一帧内从身子一侧划到另一侧（约 24000 px/s）：拍死，发信号，压扁后翻着掉下去。
func _check_fast_swipe_kills(bug: MapMosquito) -> void:
	var body := bug.get_node("Body") as Sprite2D
	var hits: Array = []
	bug.swatted.connect(func(where: Vector2) -> void: hits.append(where))
	var center := bug.body_center()
	bug.set_pointer_for_test(center + Vector2(-190.0, 6.0))
	bug.drive(FRAME)
	center = bug.body_center()
	bug.set_pointer_for_test(center + Vector2(190.0, -6.0))
	bug.drive(FRAME)
	assert(not bug.is_flying(), "快挥过身子没拍死蚊子")
	assert(hits.size() == 1, "swatted 信号应发一次，实际 %d" % hits.size())
	assert(bug.swat_count() == 1, "拍死计数不对：%d" % bug.swat_count())
	assert(body.scale.y < body.scale.x * 0.5, "拍上那一下应先压扁")
	var top := body.position.y
	for _i in 30:
		bug.drive(FRAME)
	assert(body.position.y > top + 20.0, "拍死后没往下掉")
	assert(body.modulate.a < 1.0 or body.rotation != 0.0, "拍死后既不翻转也不淡出")
	var fx := bug.get_node("Fx") as Control
	var has_pop := false
	for child in fx.get_children():
		if child is Label and (child as Label).text.begins_with("啪"):
			has_pop = true
	assert(has_pop, "命中点没弹出「啪！」")


## 拍满 SWAT_LIMIT 只之后彻底退场：不再排下一只，start() 也叫不回来
## （回选关、通关复原都会调 start()，所以这条要一并守住）。
func _check_swat_limit_retires(bug: MapMosquito) -> void:
	var body := bug.get_node("Body") as Sprite2D
	while bug.swat_count() < MapMosquito.SWAT_LIMIT:
		var before := bug.swat_count()
		_swat_once(bug)
		assert(bug.swat_count() == before + 1, "第 %d 只没拍死" % (before + 1))
		# 掉完这一只，再等足够长的重生窗口。
		for _i in int(1.2 / FRAME):
			bug.drive(FRAME)
		if bug.swat_count() < MapMosquito.SWAT_LIMIT:
			var came_back := false
			for _i in int(14.5 / FRAME):
				bug.drive(FRAME)
				if bug.is_flying():
					came_back = true
					break
			assert(came_back, "还没拍满就不来了（已拍 %d 只）" % bug.swat_count())
	assert(bug.is_retired(), "拍满 %d 只之后应当退场" % MapMosquito.SWAT_LIMIT)
	for _i in int(20.0 / FRAME):
		bug.drive(FRAME)
	assert(not bug.is_flying() and not body.visible, "退场之后又飞回来了")
	# 回选关会再调一次 start()，它也不该把蚊子叫回来。
	bug.start()
	for _i in int(6.0 / FRAME):
		bug.drive(FRAME)
	assert(not bug.is_flying() and not body.visible, "start() 把退场的蚊子叫回来了")
	assert(bug.swat_count() == MapMosquito.SWAT_LIMIT, "退场后计数不该再变")


## 一帧内从身子一侧快划到另一侧：拍死。
##
## 刚重生的那只是从屏外冲进来的，一帧能挪一百多像素；挥动跨度再加上它就越过了
## SWAT_MAX_JUMP，会被当成「指针大跳」忽略（那是设定，不是 bug）。所以先等它飞进
## 飞行区、速度稳下来，再用窄一点的跨度挥。
func _swat_once(bug: MapMosquito) -> void:
	_settle(bug)
	var center := bug.body_center()
	bug.set_pointer_for_test(center + Vector2(-130.0, 5.0))
	bug.drive(FRAME)
	center = bug.body_center()
	bug.set_pointer_for_test(center + Vector2(130.0, -5.0))
	bug.drive(FRAME)


## 推帧直到蚊子进了飞行区内圈：进场那一段冲得太快，拍不中。
func _settle(bug: MapMosquito) -> void:
	var inner := bug.flight_rect().grow(-30.0)
	for _i in int(3.0 / FRAME):
		if bug.is_flying() and inner.has_point(bug.body_center()):
			return
		bug.drive(FRAME)


## 掉完消失，最长 14 秒后又飞进来一只。
func _check_respawn(bug: MapMosquito) -> void:
	var body := bug.get_node("Body") as Sprite2D
	for _i in int(1.2 / FRAME):
		bug.drive(FRAME)
	assert(not body.visible and not bug.is_flying(), "掉完之后应该先消失")
	var came_back := false
	for _i in int(14.5 / FRAME):
		bug.drive(FRAME)
		if bug.is_flying():
			came_back = true
			break
	assert(came_back, "拍死后 14 秒内没有新蚊子飞进来")
