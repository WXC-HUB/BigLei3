class_name DuelConfig
extends RefCounted
## 对战局的全部可调数值。Spec 明确要求「数值全部集中成一组常量」——实测平衡时
## 只改这一个文件，别把数字散回 main.gd 里去。

## 本地双实例用的默认端口与地址。房间码决定实际监听端口，避免多人抢同一口。
const DEFAULT_PORT := 8910
const DEFAULT_ADDRESS := "127.0.0.1"
## 去掉 0/O/1/I，念给对面听时不容易混。
const ROOM_CHARS := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
const ROOM_CODE_LENGTH := 4
const ROOM_PORT_SPAN := 100
## 加入方连不上时的等待上限。房主等对手不走这个，只能自己取消。
const JOIN_TIMEOUT_SECONDS := 12.0


static func generate_room_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out := ""
	for _i in ROOM_CODE_LENGTH:
		out += ROOM_CHARS[rng.randi_range(0, ROOM_CHARS.length() - 1)]
	return out


static func normalize_room_code(value: String) -> String:
	var text := value.strip_edges().to_upper().replace(" ", "").replace("-", "")
	var out := ""
	for i in text.length():
		var ch := text[i]
		if ROOM_CHARS.find(ch) >= 0:
			out += ch
		elif ch == "0":
			out += "O"
		elif ch == "1":
			out += "I"
	if out.length() > ROOM_CODE_LENGTH:
		out = out.substr(0, ROOM_CODE_LENGTH)
	return out


static func port_for_room(room_code: String) -> int:
	var code := normalize_room_code(room_code)
	if code.is_empty():
		return DEFAULT_PORT
	var n := 0
	for i in code.length():
		n = int((n * 37 + code.unicode_at(i)) & 0x7fffffff)
	return DEFAULT_PORT + n % ROOM_PORT_SPAN

## 对战双方共用一条血：PVE 伤害（踩雷/错旗/大怪）照旧扣它，对手的标雷伤害也扣它。
## 单机的 3 点血在「每标一个雷掉 1 点」的经济里撑不住，所以对战单独给 10 点。
const START_HP := 10
const START_GOLD := 10

## 每标出一个雷：对对手造成 MARK_DAMAGE，自己获得 MARK_GOLD。按雷逐个结算。
const MARK_DAMAGE := 1
const MARK_GOLD := 1

## 中场休息的自动开始倒计时。双方都点「准备好了」可以提前，挂机则等它归零。
const INTERMISSION_SECONDS := 30.0
