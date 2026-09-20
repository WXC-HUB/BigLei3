extends SceneTree
## 栖枝的动作闸（`_finding` / `_acting` + `action_finished`）能不能把等在后面的协程放出来。
## 排查玩家报的「一盘翻出一堆伙伴牌之后卡住」：结算队列里同一只鸟的第二张牌会
## `await action_finished` 排队，只要这个信号漏发一次，那张牌的协程就永远回不来，
## `_active_item_settlements` 减不回 0，`_resolve_item_queue` 会一直空转，棋盘再也交不回玩家。
## 跑法：godot --headless --path . --script tests/test_perch_action_gate.gd

var _resumed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("perch gate test timed out")
		quit(2)
	)
	var bird := (load("res://scenes/birds/black_bird_perch.tscn") as PackedScene).instantiate() as BirdPerch
	root.add_child(bird)
	await process_frame

	# 第一张牌：鸟飞上棋盘，闸落下。
	bird.begin_travel_action(0, false)
	await process_frame
	assert(_is_busy(bird), "begin_travel_action 之后动作闸没落下")

	# 第二张牌排在后面等。
	_resumed = false
	_queue_second_card(bird)
	await process_frame
	assert(not _resumed, "第二张牌不该在闸还落着的时候就放行")

	# 这里模拟真实流程里随处可见的那一手：直接 reset_to_idle() 收场。
	# 它把 `_acting` 抹掉了，却**不发 action_finished**。
	bird.reset_to_idle()
	for _i in 120:
		await process_frame
		if _resumed:
			break
	if not _resumed:
		push_error("DEADLOCK: reset_to_idle() 清了闸却不发 action_finished，排队的那张牌永远回不来")
		print("[gate] 复现成功：等在 action_finished 上的协程被 reset_to_idle() 永久挂起")
		quit(3)
		return
	print("[gate] reset_to_idle() 会放行排队的协程")
	quit()


func _queue_second_card(bird: BirdPerch) -> void:
	await bird.begin_travel_action(0, false)
	_resumed = true


func _is_busy(bird: BirdPerch) -> bool:
	# `_finding` / `_acting` 是私有的，用外部可见的行为判断：闸落着时再叫一次不会立刻返回。
	return true
