extends SceneTree
## FEAT-001 的传输层验收：消息编解码往返，以及两个真实 WebSocket 端点在同一进程
## 里握手并双向收发。
##
## 注意：`DuelClient` 没有进场景树，`_process` 不会跑，所以这里必须自己循环 poll。
## headless 下没有稳定的帧节奏，指望 SceneTree 替它驱动会随机超时。

const ClientScript := preload("res://scripts/net/duel_client.gd")
const ProtocolScript := preload("res://scripts/net/duel_protocol.gd")

const PORT := 8971
const TIMEOUT_MSEC := 5000

var _host_inbox: Array = []
var _client_inbox: Array = []
var _host_linked := false
var _client_linked := false


func _init() -> void:
	_test_encode_decode_roundtrip()
	_test_decode_rejects_garbage()
	_test_live_handshake_and_two_way_traffic()
	print("DuelProtocol: all tests passed")
	quit()


func _test_encode_decode_roundtrip() -> void:
	var cases := [
		[ProtocolScript.Kind.HELLO, {"seed": -1234567}],
		[ProtocolScript.Kind.ROUND_START, {"round": 3}],
		[ProtocolScript.Kind.MINE_MARKED, {}],
		[ProtocolScript.Kind.STATE_SYNC, {"hp": 7, "max_hp": 10, "gold": 12}],
		[ProtocolScript.Kind.UPGRADE_BOUGHT, {"offer": 6}],
		[ProtocolScript.Kind.READY, {}],
		[ProtocolScript.Kind.ROUND_OVER, {}],
		[ProtocolScript.Kind.DUEL_OVER, {}],
	]
	for case in cases:
		var kind: int = case[0]
		var payload: Dictionary = case[1]
		var decoded := ProtocolScript.decode(ProtocolScript.encode(kind, payload))
		assert(not decoded.is_empty())
		assert(decoded["kind"] == kind)
		# JSON 把数字读回来都是 float，取值必须显式转 int —— 这里就是在钉住这条约定。
		for key in payload:
			assert(int((decoded["payload"] as Dictionary)[key]) == int(payload[key]))
	assert(ProtocolScript.kind_name(ProtocolScript.Kind.ROUND_OVER) == "ROUND_OVER")


func _test_decode_rejects_garbage() -> void:
	assert(ProtocolScript.decode("not json at all".to_utf8_buffer()).is_empty())
	assert(ProtocolScript.decode("[1,2,3]".to_utf8_buffer()).is_empty())
	# 缺 kind 字段的包直接丢，不要半解析出一个 kind=0 的假 HELLO。
	assert(ProtocolScript.decode('{"p":{}}'.to_utf8_buffer()).is_empty())


func _test_live_handshake_and_two_way_traffic() -> void:
	var host = ClientScript.new()
	var guest = ClientScript.new()
	host.linked.connect(func() -> void: _host_linked = true)
	guest.linked.connect(func() -> void: _client_linked = true)
	host.message_received.connect(func(kind: int, payload: Dictionary) -> void: _host_inbox.append([kind, payload]))
	guest.message_received.connect(func(kind: int, payload: Dictionary) -> void: _client_inbox.append([kind, payload]))

	assert(host.host(PORT) == OK)
	assert(guest.join("127.0.0.1", PORT) == OK)
	assert(_pump(host, guest, func() -> bool: return _host_linked and _client_linked))
	assert(host.is_host() and not guest.is_host())
	assert(host.is_linked() and guest.is_linked())

	# host → guest：下发种子。
	host.send(ProtocolScript.Kind.HELLO, {"seed": 5150})
	assert(_pump(host, guest, func() -> bool: return not _client_inbox.is_empty()))
	assert(_client_inbox[0][0] == ProtocolScript.Kind.HELLO)
	assert(int(_client_inbox[0][1]["seed"]) == 5150)

	# guest → host：标雷 + 状态快照，验证反向通道与多包顺序。
	guest.send(ProtocolScript.Kind.MINE_MARKED, {})
	guest.send(ProtocolScript.Kind.STATE_SYNC, {"hp": 8, "max_hp": 10, "gold": 3})
	assert(_pump(host, guest, func() -> bool: return _host_inbox.size() >= 2))
	assert(_host_inbox[0][0] == ProtocolScript.Kind.MINE_MARKED)
	assert(_host_inbox[1][0] == ProtocolScript.Kind.STATE_SYNC)
	assert(int(_host_inbox[1][1]["hp"]) == 8)

	host.close()
	guest.close()
	assert(not host.is_linked() and not guest.is_linked())
	host.free()
	guest.free()


## 轮流驱动两端直到条件成立或超时。返回条件是否成立，让调用方 assert。
func _pump(host, guest, condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		host.poll()
		guest.poll()
		if condition.call():
			return true
		OS.delay_msec(10)
	return false
