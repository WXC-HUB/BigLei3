class_name CustomLevel
extends RefCounted
## 自定义关卡包的数据与 JSON 进出。
##
## 一个关卡包（pack）是一个 Dictionary：
##   name   包名（导出时也是文件名）
##   items  { "lantern": n, ... } 九种**初始道具**的数量，整包共用
##   maps   Array[Dictionary]，按顺序连着打的多张地图
##
## 一张地图（map）是一个 Dictionary：
##   width / height   包围盒
##   mask   PackedByteArray，1 = 可玩，0 = 空洞，长度 width * height
##   mines  这张图的雷数
##
## 「初始道具」= 开局起每张图上都会埋这么多张对应的牌；地图之间的商店买到的加成会
## 叠在它上面（见 main.gd 的 `_prepare_custom_run`）。这一层只描述作者填的初值。
##
## JSON 里地图写成一行一个 `[1, 1, 0, 1]` 的 0/1 二维数组，肉眼能直接读出形状；
## 导入时也接受 `"##.#"` 这种 ASCII 行（`#`/`1` 为可玩）。
## v1（单图、字段摊在顶层）的老文件仍然读得进来，会被裹成只有一张图的包。

const VERSION := 2
const MIN_SIZE := 1
const MAX_WIDTH := 12
const MAX_HEIGHT := 10
const MAX_ITEM_COUNT := 30
const MAX_MAPS := 20
const DEFAULT_NAME := "我的关卡"

## 与 `MinesweeperBoard.ItemType` 一一对应；顺序即编辑器里的陈列顺序。
const ITEM_KEYS: Array[String] = [
	"lantern", "compass", "orbital_strike", "super_luck",
	"medical_kit", "xray", "chain", "enlarge", "detect",
]
const ITEM_TYPES := {
	"lantern": MinesweeperBoard.ItemType.LANTERN,
	"compass": MinesweeperBoard.ItemType.COMPASS,
	"orbital_strike": MinesweeperBoard.ItemType.ORBITAL_STRIKE,
	"super_luck": MinesweeperBoard.ItemType.SUPER_LUCK,
	"medical_kit": MinesweeperBoard.ItemType.MEDICAL_KIT,
	"xray": MinesweeperBoard.ItemType.XRAY,
	"chain": MinesweeperBoard.ItemType.CHAIN,
	"enlarge": MinesweeperBoard.ItemType.ENLARGE,
	"detect": MinesweeperBoard.ItemType.DETECT,
}
const ITEM_NAMES := {
	"lantern": "夜鹭（灯）",
	"compass": "红尾水鸲（罗盘）",
	"orbital_strike": "啄木鸟（轰击）",
	"super_luck": "红隼（无敌）",
	"medical_kit": "斑鸠（治愈）",
	"xray": "小嘴乌鸦（透视）",
	"chain": "连携雷（成组）",
	"enlarge": "长尾山雀（巨大）",
	"detect": "探测",
}


## ---- 构造 ----

static func make_map(width: int = 8, height: int = 6, mines: int = 8) -> Dictionary:
	var mask := PackedByteArray()
	mask.resize(width * height)
	mask.fill(1)
	return {"width": width, "height": height, "mask": mask, "mines": mines}


static func default_items() -> Dictionary:
	return {
		"lantern": 1, "compass": 1, "orbital_strike": 1, "super_luck": 1,
		"medical_kit": 1, "xray": 1, "chain": 0, "enlarge": 0, "detect": 0,
	}


static func make_default() -> Dictionary:
	return {
		"name": DEFAULT_NAME,
		"items": default_items(),
		"maps": [make_map()],
	}


## ---- 包级读取 ----

static func maps_of(pack: Dictionary) -> Array:
	var maps = pack.get("maps", [])
	return maps if maps is Array else []


static func map_count(pack: Dictionary) -> int:
	return maps_of(pack).size()


## 越界返回空字典，调用方按空处理即可，不抛。
static func map_at(pack: Dictionary, index: int) -> Dictionary:
	var maps := maps_of(pack)
	if index < 0 or index >= maps.size():
		return {}
	var one = maps[index]
	return one if one is Dictionary else {}


static func item_count(pack: Dictionary, key: String) -> int:
	var items: Dictionary = pack.get("items", {})
	return maxi(int(items.get(key, 0)), 0)


static func item_total(pack: Dictionary) -> int:
	var total := 0
	for key in ITEM_KEYS:
		total += item_count(pack, key)
	return total


static func total_mines(pack: Dictionary) -> int:
	var total := 0
	for one in maps_of(pack):
		if one is Dictionary:
			total += maxi(int((one as Dictionary).get("mines", 0)), 0)
	return total


## ---- 单图计算（入参是一张 map，不是整个包）----

static func active_count(map_data: Dictionary) -> int:
	var total := 0
	for bit in (map_data.get("mask", PackedByteArray()) as PackedByteArray):
		if bit == 1:
			total += 1
	return total


## 首点及其可玩邻格不布雷（`MinesweeperBoard._place_mines`）：可玩格多于 9 时让出
## 首点 + 它的可玩邻格，否则只保首点。这里按最坏的首点算——邻格最多的那一格。
static func mine_reserve(map_data: Dictionary) -> int:
	var active := active_count(map_data)
	if active <= 9:
		return 1
	var width := int(map_data.get("width", 0))
	var height := int(map_data.get("height", 0))
	var mask: PackedByteArray = map_data.get("mask", PackedByteArray())
	var worst := 1
	for y in height:
		for x in width:
			if mask[y * width + x] != 1:
				continue
			var reserved := 1
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if ox == 0 and oy == 0:
						continue
					var nx := x + ox
					var ny := y + oy
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					if mask[ny * width + nx] == 1:
						reserved += 1
			worst = maxi(worst, reserved)
	return worst


static func max_mines(map_data: Dictionary) -> int:
	return maxi(active_count(map_data) - mine_reserve(map_data), 1)


## ---- 校验 ----

## 单张图的错误；空列表即这张图没问题。
static func validate_map(map_data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var width := int(map_data.get("width", 0))
	var height := int(map_data.get("height", 0))
	if width < MIN_SIZE or width > MAX_WIDTH or height < MIN_SIZE or height > MAX_HEIGHT:
		errors.append("尺寸须在 %d×%d 到 %d×%d 之间" % [MIN_SIZE, MIN_SIZE, MAX_WIDTH, MAX_HEIGHT])
		return errors
	var mask: PackedByteArray = map_data.get("mask", PackedByteArray())
	if mask.size() != width * height:
		errors.append("地图数据与尺寸不匹配")
		return errors
	var active := active_count(map_data)
	if active < 2:
		errors.append("至少要画出 2 个可玩格")
		return errors
	if not BoardShape.is_mask_connected(mask, width, height):
		errors.append("可玩格必须连成一块（八邻域相连）")
	var mines := int(map_data.get("mines", 0))
	var ceiling := max_mines(map_data)
	if mines < 1:
		errors.append("至少放 1 枚雷")
	elif mines > ceiling:
		errors.append("雷太多了：%d 个可玩格最多放 %d 枚（首点周围要留空）" % [active, ceiling])
	return errors


## 整个包的错误列表；空列表即可开局。多图时错误前面缀上「第 N 张」。
static func validate(pack: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var maps := maps_of(pack)
	if maps.is_empty():
		errors.append("关卡包至少要有 1 张地图")
		return errors
	if maps.size() > MAX_MAPS:
		errors.append("地图最多 %d 张" % MAX_MAPS)
		return errors
	var multi := maps.size() > 1
	for index in maps.size():
		var one = maps[index]
		if not (one is Dictionary):
			errors.append("第 %d 张地图数据损坏" % (index + 1))
			continue
		for message in validate_map(one as Dictionary):
			errors.append(("第 %d 张：" % (index + 1)) + message if multi else message)
	var items: Dictionary = pack.get("items", {})
	for key in ITEM_KEYS:
		var count := int(items.get(key, 0))
		if count < 0 or count > MAX_ITEM_COUNT:
			errors.append("%s 数量须在 0 到 %d 之间" % [ITEM_NAMES[key], MAX_ITEM_COUNT])
	return errors


static func is_valid(pack: Dictionary) -> bool:
	return validate(pack).is_empty()


## 软提示：不拦开局，只提醒。初始道具每张图都会埋一遍，所以逐图检查空位；道具落在
## 「非雷、非首点及邻格」的空位上，放不下的会被 `MinesweeperBoard._place_items`
## 静默丢掉。只报第一张放不下的图，免得多图时刷屏。
static func warnings(pack: Dictionary) -> PackedStringArray:
	var notes := PackedStringArray()
	var total := item_total(pack)
	if total <= 0:
		return notes
	var maps := maps_of(pack)
	var multi := maps.size() > 1
	for index in maps.size():
		var one = maps[index]
		if not (one is Dictionary):
			continue
		var map_data := one as Dictionary
		var slots := active_count(map_data) - int(map_data.get("mines", 0)) - mine_reserve(map_data)
		if total > slots:
			var body := "道具共 %d 个，最坏只有 %d 个空位能放，多出的会放不下" % [total, maxi(slots, 0)]
			notes.append(("第 %d 张：" % (index + 1)) + body if multi else body)
			return notes
	return notes


## ---- 文件名 ----

## 去掉路径分隔符和不能进文件名的字符，空则退回默认名。
static func sanitize_name(name: String) -> String:
	var cleaned := name.strip_edges()
	for bad in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		cleaned = cleaned.replace(bad, "_")
	if cleaned.is_empty():
		cleaned = DEFAULT_NAME
	return cleaned


static func file_name_for(pack: Dictionary) -> String:
	return sanitize_name(String(pack.get("name", DEFAULT_NAME))) + ".json"


## ---- JSON ----

## 手工排版：地图一行一个数组，其余字段交给 JSON.stringify 转义。
static func to_json(pack: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("{")
	lines.append("  \"version\": %d," % VERSION)
	lines.append("  \"name\": %s," % JSON.stringify(String(pack.get("name", DEFAULT_NAME))))
	lines.append("  \"items\": {")
	for index in ITEM_KEYS.size():
		var key := ITEM_KEYS[index]
		var comma := "," if index < ITEM_KEYS.size() - 1 else ""
		lines.append("    \"%s\": %d%s" % [key, item_count(pack, key), comma])
	lines.append("  },")
	lines.append("  \"maps\": [")
	var maps := maps_of(pack)
	for map_index in maps.size():
		var map_data: Dictionary = maps[map_index]
		var width := int(map_data.get("width", 0))
		var height := int(map_data.get("height", 0))
		var mask: PackedByteArray = map_data.get("mask", PackedByteArray())
		lines.append("    {")
		lines.append("      \"width\": %d," % width)
		lines.append("      \"height\": %d," % height)
		lines.append("      \"mines\": %d," % int(map_data.get("mines", 1)))
		lines.append("      \"map\": [")
		for y in height:
			var cells := PackedStringArray()
			for x in width:
				cells.append(str(int(mask[y * width + x])))
			var row_comma := "," if y < height - 1 else ""
			lines.append("        [%s]%s" % [", ".join(cells), row_comma])
		lines.append("      ]")
		lines.append("    }%s" % ("," if map_index < maps.size() - 1 else ""))
	lines.append("  ]")
	lines.append("}")
	return "\n".join(lines) + "\n"


## 返回 { "ok": bool, "level": Dictionary, "error": String }。
## `level` 即使在失败时也尽量给出能读懂的部分，好让编辑器把玩家的图留住。
## 宽高可省略，由 map 推出；行既可以是 0/1 数组也可以是 `#.` / `10` 字符串。
static func from_json(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return _fail("不是合法的关卡 JSON")
	var data := parsed as Dictionary
	if int(data.get("version", VERSION)) > VERSION:
		return _fail("关卡文件版本太新，当前游戏不认识")

	var raw_maps: Array = []
	if data.get("maps", null) is Array:
		raw_maps = data["maps"] as Array
		if raw_maps.is_empty():
			return _fail("maps 是空的，至少要有 1 张地图")
	elif data.get("map", null) != null:
		# v1：单图，字段摊在顶层。裹成一张图。
		raw_maps = [data]
	else:
		return _fail("缺少 maps（或 v1 的 map）")
	if raw_maps.size() > MAX_MAPS:
		return _fail("地图最多 %d 张" % MAX_MAPS)

	var maps: Array = []
	for index in raw_maps.size():
		var entry = raw_maps[index]
		if not (entry is Dictionary):
			return _fail("第 %d 张地图不是对象" % (index + 1))
		var built := _map_from_dict(entry as Dictionary)
		if not bool(built["ok"]):
			var prefix := "第 %d 张：" % (index + 1) if raw_maps.size() > 1 else ""
			return _fail(prefix + String(built["error"]))
		maps.append(built["map"])

	var items := {}
	var raw_items: Dictionary = data.get("items", {}) if data.get("items", {}) is Dictionary else {}
	for key in ITEM_KEYS:
		items[key] = clampi(int(raw_items.get(key, 0)), 0, MAX_ITEM_COUNT)

	var pack := {
		"name": String(data.get("name", DEFAULT_NAME)),
		"items": items,
		"maps": maps,
	}
	var errors := validate(pack)
	if not errors.is_empty():
		return {"ok": false, "level": pack, "error": "\n".join(errors)}
	return {"ok": true, "level": pack, "error": ""}


static func _map_from_dict(data: Dictionary) -> Dictionary:
	var rows = data.get("map", null)
	if not rows is Array or (rows as Array).is_empty():
		return {"ok": false, "map": {}, "error": "缺少 map（0/1 二维数组）"}
	var height := (rows as Array).size()
	var width := -1
	var mask := PackedByteArray()
	for row in rows:
		var bits := _row_bits(row)
		if bits.is_empty():
			return {"ok": false, "map": {}, "error": "map 里有一行不是 0/1 数组或 #. 字符串"}
		if width < 0:
			width = bits.size()
		elif bits.size() != width:
			return {"ok": false, "map": {}, "error": "map 每一行的宽度必须一致"}
		mask.append_array(bits)
	if data.has("width") and int(data["width"]) != width:
		return {"ok": false, "map": {}, "error": "width 与 map 的行宽不一致"}
	if data.has("height") and int(data["height"]) != height:
		return {"ok": false, "map": {}, "error": "height 与 map 的行数不一致"}
	return {
		"ok": true,
		"error": "",
		"map": {"width": width, "height": height, "mask": mask, "mines": int(data.get("mines", 1))},
	}


static func _row_bits(row) -> PackedByteArray:
	var bits := PackedByteArray()
	if row is Array:
		for value in row:
			if value is bool:
				bits.append(1 if value else 0)
			elif value is float or value is int:
				bits.append(1 if int(value) != 0 else 0)
			elif value is String:
				bits.append(1 if (value == "1" or value == "#") else 0)
			else:
				return PackedByteArray()
		return bits
	if row is String:
		for character in (row as String):
			if character == " " or character == ",":
				continue
			bits.append(1 if (character == "1" or character == "#") else 0)
		return bits
	return PackedByteArray()


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "level": {}, "error": message}
