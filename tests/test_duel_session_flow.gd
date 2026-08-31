extends SceneTree
## FEAT-001 对战局状态机的端到端验收：两个真实 WebSocket 端点跑完「握手 → 标雷互伤
## → 购买公开 → 清盘冻结 → 中场准备 → 下一轮 → 血量归零分胜负」整条链路。
##
## 两端都在场景树外，所以要自己 `poll(delta)`。

const SessionScript := preload("res://scripts/net/duel_session.gd")
const ConfigScript := preload("res://scripts/net/duel_config.gd")

const PORT := 8972
const TIMEOUT_MSEC := 6000

var _host
var _guest
var _host_damage := 0
var _guest_damage := 0
var _host_frozen: Array = []
var _guest_frozen: Array = []
var _host_finished: Array = []
var _guest_finished: Array = []


func _init() -> void:
	_host = SessionScript.new()
	_guest = SessionScript.new()
	_host.damage_taken.connect(func(amount: int) -> void: _host_damage += amount)
	_guest.damage_taken.connect(func(amount: int) -> void: _guest_damage += amount)
	_host.round_frozen.connect(func(self_cleared: bool) -> void: _host_frozen.append(self_cleared))
	_guest.round_frozen.connect(func(self_cleared: bool) -> void: _guest_frozen.append(self_cleared))
	_host.duel_finished.connect(func(self_won: bool) -> void: _host_finished.append(self_won))
	_guest.duel_finished.connect(func(self_won: bool) -> void: _guest_finished.append(self_won))

	_test_join_requires_room_code()
	_test_matching_room_code_starts_round()
	_test_wrong_room_code_is_rejected()
	_test_leave_cancels_while_linking()
	_test_handshake_agrees_on_seed()
	_test_marks_deal_damage_one_by_one()
	_test_purchases_are_public()
	_test_clearing_freezes_both_sides()
	_test_both_ready_starts_next_round()
	_test_countdown_starts_round_without_opponent()
	_test_defeat_decides_the_duel()

	_host.leave()
	_guest.leave()
	_host.free()
	_guest.free()
	print("DuelSessionFlow: all tests passed")
	quit()


func _test_join_requires_room_code() -> void:
	assert(_guest.join_duel("127.0.0.1") == ERR_INVALID_PARAMETER)
	assert(_guest.state == SessionScript.State.IDLE)


func _test_matching_room_code_starts_round() -> void:
	assert(_host.host_duel(8975, "7K2M") == OK)
	assert(_guest.join_duel("127.0.0.1", 8975, "7k2m") == OK)
	assert(_pump(func() -> bool: return _host.round_index == 1 and _guest.round_index == 1))
	assert(_host.room_code == "7K2M")
	assert(_guest.room_code == "7K2M")
	assert(_host.duel_seed != 0 and _host.duel_seed == _guest.duel_seed)
	_host.leave()
	_guest.leave()


func _test_wrong_room_code_is_rejected() -> void:
	var failed: Array = []
	var lost := 0
	_guest.link_failed.connect(func(reason: String) -> void: failed.append(reason), CONNECT_ONE_SHOT)
	_host.link_lost.connect(func() -> void: lost += 1)
	assert(_host.host_duel(8976, "7K2M") == OK)
	assert(_guest.join_duel("127.0.0.1", 8976, "WXYZ") == OK)
	assert(_pump(func() -> bool: return not failed.is_empty()))
	assert(_host.state == SessionScript.State.LINKING)
	assert(_host.round_index == 0)
	assert(lost == 0)
	_host.leave()
	_guest.leave()


func _test_leave_cancels_while_linking() -> void:
	var failed := 0
	var lost := 0
	_guest.link_failed.connect(func(_reason: String) -> void: failed += 1)
	_guest.link_lost.connect(func() -> void: lost += 1)
	assert(_guest.join_duel("127.0.0.1", 8999, "7K2M") == OK)
	assert(_guest.state == SessionScript.State.LINKING)
	_guest.leave()
	assert(_guest.state == SessionScript.State.IDLE)
	_guest.poll(0.05)
	assert(failed == 0)
	assert(lost == 0)


func _test_handshake_agrees_on_seed() -> void:
	assert(_host.host_duel(PORT) == OK)
	assert(_guest.join_duel("127.0.0.1", PORT) == OK)
	assert(_pump(func() -> bool: return _host.round_index == 1 and _guest.round_index == 1))
	# 种子必须一致且非零——BoardModel 把 0 当哨兵值，会退回去用系统时间。
	assert(_host.duel_seed != 0)
	assert(_host.duel_seed == _guest.duel_seed)
	assert(_host.level_seed_for(1) == _guest.level_seed_for(1))
	assert(_host.state == SessionScript.State.PLAYING)
	assert(_guest.state == SessionScript.State.PLAYING)
	assert(_host.is_host() and not _guest.is_host())


## Q10：一次标出 N 个雷就要发 N 条，对面掉 N 次血、飘 N 个字。
func _test_marks_deal_damage_one_by_one() -> void:
	for _step in range(3):
		_guest.report_mine_marked()
	assert(_pump(func() -> bool: return _host_damage >= 3))
	assert(_host_damage == 3 * ConfigScript.MARK_DAMAGE)
	assert(int(_host.opponent["marked_mines"]) == 3)
	# 单向：我没标雷，对面不该掉血。
	assert(_guest_damage == 0)


## Q7：对手买了什么必须立刻可见，血量金币同理。
func _test_purchases_are_public() -> void:
	_host.report_upgrade(6)
	_host.report_upgrade(6)
	_host.report_upgrade(0)
	_host.report_state(9, 11, 7)
	assert(_pump(func() -> bool:
		return int((_guest.opponent["upgrades"] as Dictionary).get(6, 0)) == 2 and int(_guest.opponent["hp"]) == 9
	))
	assert(int((_guest.opponent["upgrades"] as Dictionary).get(0, 0)) == 1)
	assert(int(_guest.opponent["max_hp"]) == 11)
	assert(int(_guest.opponent["gold"]) == 7)


## Q2：一方清盘，两端立即冻结；清盘方拿 true，落后方拿 false。
func _test_clearing_freezes_both_sides() -> void:
	_guest.report_round_cleared()
	assert(_guest_frozen == [true])
	assert(_pump(func() -> bool: return not _host_frozen.is_empty()))
	assert(_host_frozen == [false])
	assert(_host.state == SessionScript.State.INTERMISSION)
	assert(_guest.state == SessionScript.State.INTERMISSION)


## Q8 前半：双方都点准备，立刻开下一轮。
func _test_both_ready_starts_next_round() -> void:
	_host.enter_intermission()
	_guest.enter_intermission()
	_guest.mark_ready()
	assert(_pump(func() -> bool: return _host.opponent_ready))
	_host.mark_ready()
	assert(_pump(func() -> bool: return _host.round_index == 2 and _guest.round_index == 2))
	assert(_host.level_seed_for(2) == _guest.level_seed_for(2))
	# 每轮换盘：第 2 轮的种子不能和第 1 轮撞上。
	assert(_host.level_seed_for(1) != _host.level_seed_for(2))
	# 新一轮开始，对手的标雷进度要归零，否则 HUD 会一直显示上一轮的数。
	assert(int(_host.opponent["marked_mines"]) == 0)
	assert(_host.state == SessionScript.State.PLAYING)


## Q8 后半：只有一方点准备，倒计时归零也要自动开——防的是对手挂机把局卡死。
func _test_countdown_starts_round_without_opponent() -> void:
	_guest.report_round_cleared()
	assert(_pump(func() -> bool: return _host_frozen.size() == 2))
	_host.enter_intermission()
	_guest.enter_intermission()
	assert(_host.intermission_seconds_left() == ConfigScript.INTERMISSION_SECONDS)
	_guest.mark_ready()
	# 房主不点，纯靠倒计时。每次 poll 推进 1 秒，跑满 INTERMISSION_SECONDS 还多一点。
	assert(_pump(func() -> bool: return _host.round_index == 3 and _guest.round_index == 3, 1.0))
	assert(_host.intermission_seconds_left() == 0.0)


func _test_defeat_decides_the_duel() -> void:
	_guest.report_defeat()
	assert(_guest_finished == [false])
	assert(_pump(func() -> bool: return not _host_finished.is_empty()))
	assert(_host_finished == [true])
	assert(_host.state == SessionScript.State.FINISHED)


## 轮流驱动两端直到条件成立或超时。`delta` 是喂给中场休息倒计时的步进。
func _pump(condition: Callable, delta: float = 0.0) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		_host.poll(delta)
		_guest.poll(delta)
		if condition.call():
			return true
		OS.delay_msec(10)
	return false
