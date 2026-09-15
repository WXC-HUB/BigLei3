class_name BoardShape
extends RefCounted
## 盘面形状库。引擎只认包围盒 + active 掩码；kind 仅供编辑分类与校验。
##
## 掩码约定：1 = 可玩，0 = 空洞/缺口。ASCII 里 `#` = 可玩，`.` = 不可玩。

enum Kind { RECT, NOTCH, HOLE, MULTI_HOLE }

static var _shapes: Dictionary = {}


static func has_shape(shape_id: String) -> bool:
	_ensure()
	return _shapes.has(shape_id)


static func get_shape(shape_id: String) -> Dictionary:
	_ensure()
	if not _shapes.has(shape_id):
		return {}
	return (_shapes[shape_id] as Dictionary).duplicate(true)


static func all_ids() -> PackedStringArray:
	_ensure()
	var ids := PackedStringArray()
	for key in _shapes.keys():
		ids.append(String(key))
	ids.sort()
	return ids


static func active_count_of(shape_id: String) -> int:
	var shape := get_shape(shape_id)
	if shape.is_empty():
		return 0
	return int(shape["active_count"])


## 八邻域连通且恰好一块；供表体检与生成后自检。
## 不叫 is_connected：会与 Object.is_connected 撞名。
static func is_mask_connected(mask: PackedByteArray, width: int, height: int) -> bool:
	var start := -1
	var active := 0
	for index in mask.size():
		if mask[index] == 1:
			active += 1
			if start < 0:
				start = index
	if active == 0:
		return false
	var seen := PackedByteArray()
	seen.resize(mask.size())
	seen.fill(0)
	var stack: Array[int] = [start]
	seen[start] = 1
	var reached := 0
	while not stack.is_empty():
		var current: int = stack.pop_back()
		reached += 1
		var x := current % width
		var y: int = current / width
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if ox == 0 and oy == 0:
					continue
				var nx := x + ox
				var ny := y + oy
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
				var neighbor := ny * width + nx
				if mask[neighbor] == 0 or seen[neighbor] == 1:
					continue
				seen[neighbor] = 1
				stack.append(neighbor)
	return reached == active


static func mine_reserve_for(shape_id: String) -> int:
	## 为首点及其可玩邻格预留下限；小盘退化为 1（只保首点）。
	var active := active_count_of(shape_id)
	if active <= 4:
		return 1
	if active <= 16:
		return 2
	return 9


static func max_mines_for(shape_id: String) -> int:
	return maxi(active_count_of(shape_id) - mine_reserve_for(shape_id), 1)


static func from_ascii(rows: Array, kind: Kind = Kind.RECT) -> Dictionary:
	assert(not rows.is_empty(), "形状 ASCII 不能为空")
	var height := rows.size()
	var width: int = String(rows[0]).length()
	var mask := PackedByteArray()
	mask.resize(width * height)
	var active := 0
	for y in height:
		var line := String(rows[y])
		assert(line.length() == width, "形状 ASCII 行宽不一致")
		for x in width:
			var on := line[x] == "#"
			mask[y * width + x] = 1 if on else 0
			if on:
				active += 1
	assert(active > 0, "形状没有任何可玩格")
	assert(is_mask_connected(mask, width, height), "形状可玩格不是单一八邻域连通块")
	return {
		"width": width,
		"height": height,
		"mask": mask,
		"active_count": active,
		"kind": kind,
	}


static func _ensure() -> void:
	if not _shapes.is_empty():
		return
	_register_rect("rect_2x1", ["##"])
	# 新手强引导盘：5 宽 4 高，雷位由 GuidedTutorial 写死。
	_register_rect("rect_5x4", ["#####", "#####", "#####", "#####"])
	_register_rect("rect_4", _filled(4))
	_register_rect("rect_5", _filled(5))
	_register_rect("rect_6", _filled(6))
	_register_rect("rect_7", _filled(7))
	_register_rect("rect_8", _filled(8))
	_register_rect("rect_9", _filled(9))
	_register_rect("rect_10", _filled(10))

	_register("notch_corner_6", _notch_corner(6, 2), Kind.NOTCH)
	_register("notch_corner_7", _notch_corner(7, 2), Kind.NOTCH)
	_register("notch_corner_8", _notch_corner(8, 3), Kind.NOTCH)
	_register("notch_corner_9", _notch_corner(9, 3), Kind.NOTCH)

	_register("notch_l_6", _notch_l(6, 3, 3), Kind.NOTCH)
	_register("notch_l_7", _notch_l(7, 3, 3), Kind.NOTCH)
	_register("notch_l_8", _notch_l(8, 4, 4), Kind.NOTCH)
	_register("notch_l_9", _notch_l(9, 4, 4), Kind.NOTCH)
	_register("notch_l_10", _notch_l(10, 5, 5), Kind.NOTCH)

	_register("notch_bite_7", _notch_bite(7, 3, 2), Kind.NOTCH)
	_register("notch_bite_8", _notch_bite(8, 3, 2), Kind.NOTCH)
	_register("notch_bite_9", _notch_bite(9, 4, 2), Kind.NOTCH)

	_register("notch_c_7", _notch_c(7, 3, 2), Kind.NOTCH)
	_register("notch_c_8", _notch_c(8, 4, 2), Kind.NOTCH)
	_register("notch_c_9", _notch_c(9, 5, 3), Kind.NOTCH)
	_register("notch_c_10", _notch_c(10, 5, 3), Kind.NOTCH)

	_register("notch_u_7", _notch_u(7, 3, 2), Kind.NOTCH)
	_register("notch_u_8", _notch_u(8, 4, 2), Kind.NOTCH)
	_register("notch_u_9", _notch_u(9, 5, 3), Kind.NOTCH)
	_register("notch_u_10", _notch_u(10, 5, 3), Kind.NOTCH)

	_register("notch_channel_8", _notch_channel(8, 2, 3), Kind.NOTCH)
	_register("notch_channel_9", _notch_channel(9, 2, 4), Kind.NOTCH)
	_register("notch_channel_10", _notch_channel(10, 3, 4), Kind.NOTCH)

	_register("notch_furrow_7", _notch_furrow(7, 2, 2), Kind.NOTCH)
	_register("notch_furrow_8", _notch_furrow(8, 2, 2), Kind.NOTCH)
	_register("notch_ridge_7", _notch_ridge(7, 2, 2), Kind.NOTCH)
	_register("notch_ridge_8", _notch_ridge(8, 2, 2), Kind.NOTCH)

	_register("notch_bend_8", _notch_bend(8), Kind.NOTCH)
	_register("notch_bend_9", _notch_bend(9), Kind.NOTCH)
	_register("notch_bend_10", _notch_bend(10), Kind.NOTCH)

	_register("notch_bridge_8", _notch_bridge(8, 2, 2), Kind.NOTCH)
	_register("notch_bridge_9", _notch_bridge(9, 2, 3), Kind.NOTCH)
	_register("notch_bridge_10", _notch_bridge(10, 3, 3), Kind.NOTCH)

	_register("notch_gate_7", _notch_gate(7, 2), Kind.NOTCH)
	_register("notch_gate_8", _notch_gate(8, 2), Kind.NOTCH)
	_register("notch_gate_9", _notch_gate(9, 3), Kind.NOTCH)
	_register("notch_gate_10", _notch_gate(10, 3), Kind.NOTCH)

	_register("hole_center_7", _hole_center(7, 1), Kind.HOLE)
	_register("hole_center_8", _hole_center(8, 2), Kind.HOLE)
	_register("hole_center_9", _hole_center(9, 2), Kind.HOLE)
	_register("hole_center_10", _hole_center(10, 2), Kind.HOLE)

	_register("hole_lagoon_8", _hole_center(8, 3), Kind.HOLE)
	_register("hole_lagoon_9", _hole_center(9, 3), Kind.HOLE)
	_register("hole_lagoon_10", _hole_center(10, 4), Kind.HOLE)

	_register("holes_twin_8", _holes_twin(8, 1), Kind.MULTI_HOLE)
	_register("holes_twin_9", _holes_twin(9, 2), Kind.MULTI_HOLE)
	_register("holes_twin_10", _holes_twin(10, 2), Kind.MULTI_HOLE)

	_register("holes_scatter_9", _holes_scatter(9, 1), Kind.MULTI_HOLE)
	_register("holes_scatter_10", _holes_scatter(10, 2), Kind.MULTI_HOLE)

	_register("holes_reef_9", _holes_reef(9), Kind.MULTI_HOLE)
	_register("holes_reef_10", _holes_reef(10), Kind.MULTI_HOLE)


static func _register_rect(id: String, rows: Array) -> void:
	_register(id, from_ascii(rows, Kind.RECT), Kind.RECT)


static func _register(id: String, shape: Dictionary, kind: Kind) -> void:
	shape["id"] = id
	shape["kind"] = kind
	_shapes[id] = shape


static func _filled(n: int) -> Array:
	var rows: Array = []
	var line := "#".repeat(n)
	for _i in n:
		rows.append(line)
	return rows


static func _grid(n: int, fill: bool = true) -> Array:
	var cells: Array = []
	for _y in n:
		var row: Array = []
		for _x in n:
			row.append(fill)
		cells.append(row)
	return cells


static func _to_ascii(cells: Array) -> Array:
	var rows: Array = []
	for row in cells:
		var line := ""
		for on in row:
			line += "#" if bool(on) else "."
		rows.append(line)
	return rows


static func _notch_corner(n: int, cut: int) -> Dictionary:
	var cells := _grid(n, true)
	for y in range(n - cut, n):
		for x in range(n - cut, n):
			cells[y][x] = false
	return from_ascii(_to_ascii(cells), Kind.NOTCH)


static func _notch_l(n: int, cut_w: int, cut_h: int) -> Dictionary:
	var cells := _grid(n, true)
	for y in range(n - cut_h, n):
		for x in range(n - cut_w, n):
			cells[y][x] = false
	return from_ascii(_to_ascii(cells), Kind.NOTCH)


static func _notch_bite(n: int, width: int, depth: int) -> Dictionary:
	var cells := _grid(n, true)
	var start := int((n - width) / 2.0)
	for y in depth:
		for x in range(start, start + width):
			cells[y][x] = false
	return from_ascii(_to_ascii(cells), Kind.NOTCH)


static func _notch_c(n: int, opening: int, depth: int) -> Dictionary:
	var cells := _grid(n, true)
	var start := int((n - opening) / 2.0)
	for y in range(depth, n - depth):
		for x in range(start, start + opening):
			cells[y][x] = false
	## 左侧封口，形成 C。
	for y in range(depth, n - depth):
		for x in mini(depth, start):
			cells[y][x] = true
	return from_ascii(_to_ascii(cells), Kind.NOTCH)


static func _notch_u(n: int, opening: int, depth: int) -> Dictionary:
	var cells := _grid(n, true)
	var start := int((n - opening) / 2.0)
	for y in range(n - depth, n):
		for x in range(start, start + opening):
			cells[y][x] = false
	return from_ascii(_to_ascii(cells), Kind.NOTCH)


static func _notch_channel(n: int, thickness: int, inset: int) -> Dictionary:
	var cells := _grid(n, true)
	var y0 := int((n - thickness) / 2.0)
	for y in range(y0, y0 + thickness):
		for x in range(inset, n - inset):
			cells[y][x] = false
	return from_ascii(_to_ascii(cells), Kind.NOTCH)


## 从左侧犁进一条横沟，右侧留埂，田仍是一块。
static func _notch_furrow(n: int, thickness: int, margin: int) -> Dictionary:
	var cells := _grid(n, true)
	var y0 := int((n - thickness) / 2.0)
	for y in range(y0, y0 + thickness):
		for x in range(0, n - margin):
			cells[y][x] = false
	return from_ascii(_to_ascii(cells), Kind.NOTCH)


## 从上往下犁一条竖沟，底边留埂。
static func _notch_ridge(n: int, thickness: int, margin: int) -> Dictionary:
	var cells := _grid(n, true)
	var x0 := int((n - thickness) / 2.0)
	for y in range(0, n - margin):
		for x in range(x0, x0 + thickness):
			cells[y][x] = false
	return from_ascii(_to_ascii(cells), Kind.NOTCH)


static func _notch_bend(n: int) -> Dictionary:
	## 从完整矩形挖一条「┌」形浅槽，外圈仍连通，读起来像河曲。
	var cells := _grid(n, true)
	var inset := maxi(int(n / 4.0), 2)
	var thickness := 2 if n < 10 else 3
	for y in range(inset, inset + thickness):
		for x in range(inset, n - inset):
			cells[y][x] = false
	for y in range(inset, n - inset):
		for x in range(n - inset - thickness, n - inset):
			cells[y][x] = false
	return from_ascii(_to_ascii(cells), Kind.NOTCH)


static func _notch_bridge(n: int, side: int, gap: int) -> Dictionary:
	var cells := _grid(n, true)
	var y0 := int((n - gap) / 2.0)
	for y in range(y0, y0 + gap):
		for x in side:
			cells[y][x] = false
		for x in range(n - side, n):
			cells[y][x] = false
	return from_ascii(_to_ascii(cells), Kind.NOTCH)


static func _notch_gate(n: int, throat: int) -> Dictionary:
	var cells := _grid(n, true)
	var mid := int(n / 2.0)
	var half := maxi(int((n - throat) / 2.0), 1)
	for y in range(mid - 1, mid + 1):
		for x in half:
			cells[y][x] = false
		for x in range(n - half, n):
			cells[y][x] = false
	return from_ascii(_to_ascii(cells), Kind.NOTCH)


static func _hole_center(n: int, hole: int) -> Dictionary:
	var cells := _grid(n, true)
	var x0 := int((n - hole) / 2.0)
	var y0 := x0
	for y in range(y0, y0 + hole):
		for x in range(x0, x0 + hole):
			cells[y][x] = false
	return from_ascii(_to_ascii(cells), Kind.HOLE)


static func _holes_twin(n: int, hole: int) -> Dictionary:
	var cells := _grid(n, true)
	var left := maxi(int(n / 4.0) - int(hole / 2.0), 1)
	var right := n - left - hole
	var y0 := int((n - hole) / 2.0)
	for y in range(y0, y0 + hole):
		for x in range(left, left + hole):
			cells[y][x] = false
		for x in range(right, right + hole):
			cells[y][x] = false
	return from_ascii(_to_ascii(cells), Kind.MULTI_HOLE)


static func _holes_scatter(n: int, hole: int) -> Dictionary:
	var cells := _grid(n, true)
	var positions := [
		Vector2i(2, 2),
		Vector2i(n - 2 - hole, 2),
		Vector2i(int(n / 2.0) - int(hole / 2.0), n - 2 - hole),
	]
	for pos in positions:
		for y in range(pos.y, pos.y + hole):
			for x in range(pos.x, pos.x + hole):
				if x >= 0 and y >= 0 and x < n and y < n:
					cells[y][x] = false
	return from_ascii(_to_ascii(cells), Kind.MULTI_HOLE)


static func _holes_reef(n: int) -> Dictionary:
	var cells := _grid(n, true)
	var spots := [
		Vector2i(1, 1), Vector2i(3, 2), Vector2i(n - 3, 1),
		Vector2i(2, n - 3), Vector2i(n - 4, n - 3), Vector2i(int(n / 2.0), int(n / 2.0)),
	]
	for pos in spots:
		if pos.x >= 0 and pos.y >= 0 and pos.x < n and pos.y < n:
			cells[pos.y][pos.x] = false
		var nx: int = pos.x + 1
		var ny: int = pos.y
		if nx >= 0 and ny >= 0 and nx < n and ny < n and (pos.x + pos.y) % 2 == 0:
			cells[ny][nx] = false
	return from_ascii(_to_ascii(cells), Kind.MULTI_HOLE)
