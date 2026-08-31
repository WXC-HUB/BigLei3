class_name DuelProtocol
extends RefCounted
## 对战局的线上消息格式。载荷是 JSON，因为 FEAT-001 的量级下可读性比字节数重要得
## 多——抓包直接能看懂，出问题不用先写解码器。
##
## 注意：JSON 把所有数字读回来都是 float，所以取值一律显式 int()／float() 转换，
## 别直接把 payload 里的值当 int 用。

enum Kind {
	## host → client：下发对局种子。双方拿同一个种子各自建盘，棋盘因此逐格一致。
	HELLO,
	## host → client：开始新的一轮（载荷带轮次序号）。
	ROUND_START,
	## 双向：我标出了一个雷。一次标出多个就发多条——Q10 定的逐个结算。
	MINE_MARKED,
	## 双向：血量/金币快照。全公开信息的主通道。
	STATE_SYNC,
	## 双向：我买了某项强化（载荷带 ShopOffer 序号）。
	UPGRADE_BOUGHT,
	## 双向：我在中场休息里准备好了。
	READY,
	## 双向：我清完棋盘了 —— 收到即冻结本轮。
	ROUND_OVER,
	## 双向：我血量归零了 —— 收到即本方获胜。
	DUEL_OVER,
	## guest → host：报房间码。对不上就踢，对上了房主才开局。
	ROOM,
}


static func encode(kind: int, payload: Dictionary = {}) -> PackedByteArray:
	return JSON.stringify({"k": kind, "p": payload}).to_utf8_buffer()


## 解不出来就返回空字典，让调用方直接丢包。对战里一条坏包不值得把连接拆掉。
##
## 用 `JSON.new().parse()` 而不是静态的 `JSON.parse_string()`：后者遇到坏包会往
## 控制台推一条 ERROR，而丢弃坏包在这里是正常路径，不该看起来像故障。
static func decode(packet: PackedByteArray) -> Dictionary:
	var reader := JSON.new()
	if reader.parse(packet.get_string_from_utf8()) != OK:
		return {}
	var parsed = reader.data
	if not parsed is Dictionary:
		return {}
	var message := parsed as Dictionary
	if not message.has("k"):
		return {}
	var payload = message.get("p", {})
	if not payload is Dictionary:
		payload = {}
	return {"kind": int(message["k"]), "payload": payload as Dictionary}


static func kind_name(kind: int) -> String:
	var names := Kind.keys()
	if kind < 0 or kind >= names.size():
		return "UNKNOWN(%d)" % kind
	return str(names[kind])
