class_name DuelSession
extends Node
## 对战局的状态机：谁是房主、种子是多少、现在第几轮、对手什么状态、什么时候开下
## 一轮。它不碰任何 UI，也不碰棋盘——GameFlow 订阅它的信号自己去改画面。
##
## 权威划分：房主端权威的只有「什么时候开下一轮」（中场休息倒计时）。其余一切都是
## 各自客户端权威——反作弊不在 FEAT-001 的目标里，各自算各自的盘最省事。

signal linked
signal link_lost
## 双方握手完成、对局种子已就位。载荷是种子，两端拿到的是同一个值。
signal duel_started(duel_seed: int)
signal round_started(round_index: int)
## 对手的血量/金币/标雷数/强化列表任一项变了，HUD 该刷新了。
signal opponent_changed
## 对手标出了一个雷，我该掉血了。按雷逐个发——一次标 3 个就触发 3 次。
signal damage_taken(amount: int)
## 本轮结束。`self_cleared` 为真表示是我先清完的盘。
signal round_frozen(self_cleared: bool)
signal duel_finished(self_won: bool)

enum State { IDLE, LINKING, PLAYING, INTERMISSION, FINISHED }

var duel_seed := 0
var round_index := 0
var state: State = State.IDLE
var self_ready := false
var opponent_ready := false

## 对手快照。Q7 选了全公开，所以这里存的东西 HUD 全都会显示出来。
var opponent := {
	"hp": DuelConfig.START_HP,
	"max_hp": DuelConfig.START_HP,
	"gold": DuelConfig.START_GOLD,
	"marked_mines": 0,
	"upgrades": {},
}

var _client: DuelClient
var _intermission_left := 0.0
## 倒计时是否已上膛。冻结的那一刻 state 就变成 INTERMISSION 了，但商店要过一段
## 收尾演出才弹出来；没有这个标志的话，房主会在演出还没放完时就看到「剩余 0 秒」
## 而直接开下一轮，中场休息整个被跳过。
var _intermission_armed := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_ensure_client()


## 传输层懒建。不放在 `_ready()` 里独占，是因为 headless 测试会在场景树外直接用
## 这个类——那时 `_ready()` 根本不会触发。
func _ensure_client() -> void:
	if _client != null:
		return
	_client = DuelClient.new()
	_client.name = "DuelClient"
	_client.linked.connect(_on_linked)
	_client.unlinked.connect(_on_unlinked)
	_client.message_received.connect(_on_message_received)
	add_child(_client)


## 手动驱动一次收发 + 一次计时。在场景树里这两件事分别由 DuelClient 和本类的
## `_process` 自动完成；场景树外（headless 测试、将来的无头服务端）要自己循环调。
func poll(delta: float = 0.0) -> void:
	if _client != null:
		_client.poll()
	tick(delta)


func is_active() -> bool:
	return state != State.IDLE


func is_host() -> bool:
	return _client != null and _client.is_host()


func host_duel(port: int = DuelConfig.DEFAULT_PORT) -> Error:
	_ensure_client()
	_reset_duel_state()
	var error := _client.host(port)
	state = State.LINKING if error == OK else State.IDLE
	return error


func join_duel(address: String = DuelConfig.DEFAULT_ADDRESS, port: int = DuelConfig.DEFAULT_PORT) -> Error:
	_ensure_client()
	_reset_duel_state()
	var error := _client.join(address, port)
	state = State.LINKING if error == OK else State.IDLE
	return error


func leave() -> void:
	if _client != null:
		_client.close()
	_reset_duel_state()
	state = State.IDLE


## 每一轮的棋盘种子。双方 duel_seed 相同、轮次相同，于是算出同一个 level_seed，
## 布局逐格一致。用显式整数混合而不是 hash()：种子必须在两端算出一模一样的值，
## 自己写的位运算比依赖引擎内部的字符串哈希更好保证这件事。
func level_seed_for(round_number: int) -> int:
	var mixed := duel_seed ^ (round_number * 0x9E3779B9)
	mixed = (mixed ^ (mixed >> 16)) * 0x45D9F3B
	mixed = (mixed ^ (mixed >> 16)) * 0x45D9F3B
	return mixed ^ (mixed >> 16)


# --- 出站：GameFlow 在对应时机调这些 ---


## 我标出了一个雷。逐个调用，不要合并成一条。
func report_mine_marked() -> void:
	_client.send(DuelProtocol.Kind.MINE_MARKED, {})


func report_state(hp: int, max_hp: int, gold: int) -> void:
	_client.send(DuelProtocol.Kind.STATE_SYNC, {"hp": hp, "max_hp": max_hp, "gold": gold})


func report_upgrade(offer_index: int) -> void:
	_client.send(DuelProtocol.Kind.UPGRADE_BOUGHT, {"offer": offer_index})


func report_round_cleared() -> void:
	if state != State.PLAYING:
		return
	state = State.INTERMISSION
	_client.send(DuelProtocol.Kind.ROUND_OVER, {})
	round_frozen.emit(true)


func report_defeat() -> void:
	if state == State.FINISHED:
		return
	state = State.FINISHED
	_client.send(DuelProtocol.Kind.DUEL_OVER, {})
	duel_finished.emit(false)


func mark_ready() -> void:
	if self_ready or state != State.INTERMISSION:
		return
	self_ready = true
	_client.send(DuelProtocol.Kind.READY, {})
	_try_advance_round()


## GameFlow 在弹出中场休息商店时调一次，倒计时从这里开始走。
func enter_intermission() -> void:
	self_ready = false
	opponent_ready = false
	_intermission_left = DuelConfig.INTERMISSION_SECONDS
	_intermission_armed = true
	# 上膛之前到的 READY 会被 `_try_advance_round()` 挡回去，这里补一次检查，
	# 免得双方其实都准备好了却还要干等满 30 秒。
	_try_advance_round()


func intermission_seconds_left() -> float:
	return maxf(_intermission_left, 0.0)


func _process(delta: float) -> void:
	tick(delta)


## 推进一次中场休息倒计时。
func tick(delta: float) -> void:
	if state != State.INTERMISSION or not _intermission_armed:
		return
	_intermission_left = maxf(_intermission_left - delta, 0.0)
	# 倒计时归零只有房主说了算，客户端那份纯粹是显示用的。
	if is_host() and _intermission_left <= 0.0:
		_advance_round()


# --- 入站 ---


func _on_linked() -> void:
	linked.emit()
	if not is_host():
		return
	# 房主负责造种子并下发，然后立刻开第一轮。
	_rng.randomize()
	duel_seed = _rng.randi()
	_client.send(DuelProtocol.Kind.HELLO, {"seed": duel_seed})
	duel_started.emit(duel_seed)
	_advance_round()


func _on_unlinked() -> void:
	state = State.IDLE
	link_lost.emit()


func _on_message_received(kind: int, payload: Dictionary) -> void:
	match kind:
		DuelProtocol.Kind.HELLO:
			duel_seed = int(payload.get("seed", 0))
			duel_started.emit(duel_seed)
		DuelProtocol.Kind.ROUND_START:
			round_index = int(payload.get("round", 1))
			_begin_round_locally()
		DuelProtocol.Kind.MINE_MARKED:
			opponent["marked_mines"] = int(opponent["marked_mines"]) + 1
			opponent_changed.emit()
			damage_taken.emit(DuelConfig.MARK_DAMAGE)
		DuelProtocol.Kind.STATE_SYNC:
			opponent["hp"] = int(payload.get("hp", opponent["hp"]))
			opponent["max_hp"] = int(payload.get("max_hp", opponent["max_hp"]))
			opponent["gold"] = int(payload.get("gold", opponent["gold"]))
			opponent_changed.emit()
		DuelProtocol.Kind.UPGRADE_BOUGHT:
			var offer := int(payload.get("offer", -1))
			if offer >= 0:
				var owned: Dictionary = opponent["upgrades"]
				owned[offer] = int(owned.get(offer, 0)) + 1
				opponent_changed.emit()
		DuelProtocol.Kind.READY:
			opponent_ready = true
			opponent_changed.emit()
			_try_advance_round()
		DuelProtocol.Kind.ROUND_OVER:
			if state != State.PLAYING:
				return
			state = State.INTERMISSION
			round_frozen.emit(false)
		DuelProtocol.Kind.DUEL_OVER:
			if state == State.FINISHED:
				return
			state = State.FINISHED
			duel_finished.emit(true)


func _try_advance_round() -> void:
	if not is_host() or state != State.INTERMISSION or not _intermission_armed:
		return
	if self_ready and opponent_ready:
		_advance_round()


func _advance_round() -> void:
	round_index += 1
	_client.send(DuelProtocol.Kind.ROUND_START, {"round": round_index})
	_begin_round_locally()


func _begin_round_locally() -> void:
	state = State.PLAYING
	self_ready = false
	opponent_ready = false
	_intermission_left = 0.0
	_intermission_armed = false
	opponent["marked_mines"] = 0
	opponent_changed.emit()
	round_started.emit(round_index)


func _reset_duel_state() -> void:
	duel_seed = 0
	round_index = 0
	self_ready = false
	opponent_ready = false
	_intermission_left = 0.0
	_intermission_armed = false
	opponent = {
		"hp": DuelConfig.START_HP,
		"max_hp": DuelConfig.START_HP,
		"gold": DuelConfig.START_GOLD,
		"marked_mines": 0,
		"upgrades": {},
	}
