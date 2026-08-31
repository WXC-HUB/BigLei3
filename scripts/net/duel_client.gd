class_name DuelClient
extends Node
## `WebSocketMultiplayerPeer` 的薄封装：连上、收发、断开三件事，不懂任何游戏规则。
##
## 为什么是 WebSocket 而不是 ENet：首发平台是 Web（见 export_presets.cfg），浏览器
## 开不了 UDP socket，ENet 直接出局。对战是回合制且带演出，TCP 的延迟完全在预算内。

signal linked
signal unlinked
signal message_received(kind: int, payload: Dictionary)

var _peer: WebSocketMultiplayerPeer
var _is_host := false
var _linked := false
## host 侧记住第一个连进来的对手。1v1 只收一个人，多出来的一律拒之门外。
var _remote_id := 0


func is_host() -> bool:
	return _is_host


func is_linked() -> bool:
	return _linked


func host(port: int = DuelConfig.DEFAULT_PORT) -> Error:
	_reset()
	_peer = WebSocketMultiplayerPeer.new()
	var error := _peer.create_server(port)
	if error != OK:
		push_warning("Could not host duel on port %d: %s" % [port, error_string(error)])
		_peer = null
		return error
	_is_host = true
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	return OK


func join(address: String = DuelConfig.DEFAULT_ADDRESS, port: int = DuelConfig.DEFAULT_PORT) -> Error:
	_reset()
	_peer = WebSocketMultiplayerPeer.new()
	var error := _peer.create_client("ws://%s:%d" % [address, port])
	if error != OK:
		push_warning("Could not join duel at %s:%d: %s" % [address, port, error_string(error)])
		_peer = null
		return error
	_is_host = false
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	return OK


func send(kind: int, payload: Dictionary = {}) -> void:
	if _peer == null or not _linked:
		return
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	_peer.put_packet(DuelProtocol.encode(kind, payload))


func close() -> void:
	if _peer != null:
		_peer.close()
	_reset()


## 房主踢掉当前对手，服务器继续听。用于房间码不对：别把整间房关了。
func kick_remote() -> void:
	if _peer == null or _remote_id == 0:
		return
	var id := _remote_id
	_remote_id = 0
	_linked = false
	_peer.disconnect_peer(id)


## 驱动一次收发。`_process` 会自动调它；headless 测试里没有稳定的帧节奏，测试代码
## 要自己循环调用这个方法，不能指望 SceneTree 替它 poll。
func poll() -> void:
	if _peer == null:
		return
	_peer.poll()
	# 客户端侧没有 peer_connected 可听（对端是服务器不是 peer），只能看连接状态跃迁。
	if not _is_host:
		var status := _peer.get_connection_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED and not _linked:
			_linked = true
			linked.emit()
		elif status == MultiplayerPeer.CONNECTION_DISCONNECTED and _linked:
			_linked = false
			unlinked.emit()
			return
	while _peer != null and _peer.get_available_packet_count() > 0:
		var message := DuelProtocol.decode(_peer.get_packet())
		if message.is_empty():
			continue
		message_received.emit(int(message["kind"]), message["payload"] as Dictionary)


func _process(_delta: float) -> void:
	poll()


func _on_peer_connected(id: int) -> void:
	if _remote_id != 0:
		# 已经有对手了。1v1 不接第三个人，直接踢掉，免得广播把状态发给旁观者。
		_peer.disconnect_peer(id)
		return
	_remote_id = id
	_linked = true
	linked.emit()


func _on_peer_disconnected(id: int) -> void:
	if _is_host and id != _remote_id:
		return
	_remote_id = 0
	if not _linked:
		return
	_linked = false
	unlinked.emit()


func _reset() -> void:
	if _peer != null:
		if _peer.peer_connected.is_connected(_on_peer_connected):
			_peer.peer_connected.disconnect(_on_peer_connected)
		if _peer.peer_disconnected.is_connected(_on_peer_disconnected):
			_peer.peer_disconnected.disconnect(_on_peer_disconnected)
	_peer = null
	_is_host = false
	_linked = false
	_remote_id = 0
