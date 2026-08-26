extends SceneTree
## FEAT-003 验收：对战分屏几何、迷雾罩存在性、单机布局零回归、协议未膨胀。
##
## 只断言水平方向的几何——headless 下视口高度会被报成 1920（见 test_roguelite_progression
## 那条既有失败），纵向断言在这个环境里不可靠。

const ProtocolScript := preload("res://scripts/net/duel_protocol.gd")

const TIMEOUT_MSEC := 20000

var _host_game: Node
var _guest_game: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_protocol_did_not_grow()

	var packed: PackedScene = load("res://scenes/main.tscn")
	_host_game = packed.instantiate()
	_guest_game = packed.instantiate()
	root.add_child(_host_game)
	root.add_child(_guest_game)
	await process_frame
	await process_frame

	_host_game.call("_on_duel_host_requested")
	_guest_game.call("_on_duel_join_requested")
	assert(await _wait(func() -> bool:
		return _host_game.get("_board") != null and _guest_game.get("_board") != null
	))

	_test_board_sits_in_left_half()
	_test_counters_stay_in_left_half()
	_test_opponent_slot_mirrors_the_board()
	_test_cell_size_only_shrinks_on_the_biggest_board()
	await _test_single_player_layout_untouched()

	print("DuelSplitLayout: all tests passed")
	quit()


## 验收：本 FEAT 不新增任何网络消息。这是共识 #3 的硬约束，也是「棋盘全遮」
## 换来的最大一笔节省——遮住了就没有状态要同步。
func _test_protocol_did_not_grow() -> void:
	assert(ProtocolScript.Kind.size() == 8)
	assert(ProtocolScript.Kind.keys()[0] == "HELLO")
	assert(ProtocolScript.Kind.keys()[7] == "DUEL_OVER")


## 验收：左屏棋盘整块落在左半屏内，不越过中线。
func _test_board_sits_in_left_half() -> void:
	var offset: Vector2 = _host_game.get("_board_center_offset")
	assert(is_equal_approx(offset.x, -480.0))
	var panel: Control = _host_game.get("_board_panel")
	var rect := panel.get_global_rect()
	var midline: float = root.get_visible_rect().size.x * 0.5
	assert(rect.end.x < midline)
	assert(rect.position.x > 0.0)


## 验收：剩余雷/剩余道具读数也留在左半屏，且不和自身 HUD 撞上。
func _test_counters_stay_in_left_half() -> void:
	var midline: float = root.get_visible_rect().size.x * 0.5
	var mine_rect: Rect2 = (_host_game.get("_mine_counter_panel") as Control).get_global_rect()
	var item_rect: Rect2 = (_host_game.get("_item_counter_panel") as Control).get_global_rect()
	assert(mine_rect.end.x <= midline)
	assert(item_rect.end.x <= midline)
	# 自身 HUD 被缩过一档，正是为了给读数行让出这段横向空间。
	var status: Control = _host_game.get("_player_status")
	assert(is_equal_approx(status.scale.x, 0.72))
	assert(status.get_global_rect().end.x < mine_rect.position.x)


## 验收：右屏那块位与左屏棋盘等尺寸，且真的盖着迷雾罩。
func _test_opponent_slot_mirrors_the_board() -> void:
	var hud = _host_game.get("_duel_hud")
	var slot: Control = hud.get("_opponent_slot")
	assert(slot != null)
	var panel: Control = _host_game.get("_board_panel")
	var slot_rect := slot.get_global_rect()
	var panel_rect := panel.get_global_rect()
	assert(is_equal_approx(slot_rect.size.x, panel_rect.size.x))
	assert(is_equal_approx(slot_rect.size.y, panel_rect.size.y))
	# 一块在中线左、一块在中线右。
	var midline: float = root.get_visible_rect().size.x * 0.5
	assert(slot_rect.position.x > midline)
	# 迷雾罩与格子轮廓底都在，且轮廓的行列数取自本地棋盘。
	var veil: ColorRect = slot.get_node("FogVeil")
	var backdrop: Control = slot.get_node("FogGridBackdrop")
	assert(veil != null and backdrop != null)
	assert(veil.color.a > 0.95)
	var board = _host_game.get("_board")
	assert(backdrop.get("columns") == board.width)
	assert(backdrop.get("rows") == board.height)


## 验收：只有最大的 10×10 需要缩，6×6 到 9×9 仍是原来的 88。
func _test_cell_size_only_shrinks_on_the_biggest_board() -> void:
	# 第一轮是 6×6，不该缩。
	assert(is_equal_approx(float(_host_game.get("_cell_size")), 88.0))
	for columns in [7, 8, 9]:
		_host_game.call("_apply_split_layout", columns, columns)
		assert(is_equal_approx(float(_host_game.get("_cell_size")), 88.0))
	_host_game.call("_apply_split_layout", 10, 10)
	var biggest := float(_host_game.get("_cell_size"))
	assert(biggest < 88.0 and biggest > 78.0)
	# 复原，免得污染后面的断言。
	var board = _host_game.get("_board")
	_host_game.call("_apply_split_layout", board.width, board.height)


## 验收：单机布局一个像素都没动。
func _test_single_player_layout_untouched() -> void:
	var solo: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(solo)
	await process_frame
	await process_frame
	assert(not bool(solo.call("_is_duel")))
	solo.call("_start_game")
	await process_frame
	assert(is_equal_approx(float(solo.get("_cell_size")), 88.0))
	assert((solo.get("_board_center_offset") as Vector2) == Vector2.ZERO)
	assert(is_equal_approx((solo.get("_player_status") as Control).scale.x, 1.0))
	# 最大盘在单机下也绝不缩。
	solo.call("_apply_split_layout", 10, 10)
	assert(is_equal_approx(float(solo.get("_cell_size")), 88.0))
	# 单机的对战 HUD 整棵树都不该露面。
	assert(not (solo.get("_duel_hud") as Control).visible)
	solo.queue_free()


func _wait(condition: Callable, timeout_msec: int = TIMEOUT_MSEC) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if condition.call():
			return true
	return false
