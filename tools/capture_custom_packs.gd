extends SceneTree
## 校验 custom_packs/ 下的关卡包，并给每个包渲染一张预览图（所有地图排成一行）。
## 跑法：godot --fixed-fps 60 --path . --script tools/capture_custom_packs.gd

const PACK_DIR := "res://custom_packs"
const OUT_DIR := "res://artifacts"

const COLOR_BG := Color("141a11")
const COLOR_PANEL := Color("1c281b")
const COLOR_EDGE := Color("3d4a33")
const COLOR_ON := Color("6f9a3c")
const COLOR_ON_EDGE := Color("a6d36b")
const COLOR_OFF := Color("222a1d")
const COLOR_TITLE := Color("ffd768")
const COLOR_INK := Color("e8efd8")
const COLOR_MUTED := Color("95a487")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var dir := DirAccess.open(PACK_DIR)
	if dir == null:
		push_error("找不到 " + PACK_DIR)
		quit(1)
		return
	var names: Array[String] = []
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			names.append(file_name)
	names.sort()

	var failed := 0
	for file_name in names:
		var path := PACK_DIR + "/" + file_name
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			print("FAIL 读不到 ", file_name)
			failed += 1
			continue
		var result := CustomLevel.from_json(file.get_as_text())
		file.close()
		if not bool(result["ok"]):
			print("FAIL ", file_name, " 校验不通过：", String(result["error"]))
			failed += 1
			continue
		var pack: Dictionary = result["level"]
		var item_bits := PackedStringArray()
		for key in CustomLevel.ITEM_KEYS:
			var count := CustomLevel.item_count(pack, key)
			if count > 0:
				item_bits.append("%s×%d" % [String(CustomLevel.ITEM_NAMES[key]), count])
		var notes := CustomLevel.warnings(pack)
		print(
			"OK   ", String(pack["name"]),
			" · ", CustomLevel.map_count(pack), " 张图",
			" · 共 ", CustomLevel.total_mines(pack), " 雷",
			" · 初始道具 ", "无" if item_bits.is_empty() else ", ".join(item_bits),
			" · 提示 ", "无" if notes.is_empty() else notes[0]
		)
		await _capture_pack(pack)

	if failed > 0:
		push_error("有 %d 个关卡包不合法" % failed)
		quit(1)
		return
	print("全部关卡包校验通过并已出图")
	quit()


func _capture_pack(pack: Dictionary) -> void:
	var view := PackPreview.new()
	view.pack = pack
	view.size = view.wanted_size()
	var window := Window.new()
	window.size = Vector2i(view.size)
	window.transparent = false
	root.add_child(window)
	window.add_child(view)
	await process_frame
	await process_frame
	var image := window.get_texture().get_image()
	var out := OUT_DIR + "/pack_" + String(pack["name"]) + ".png"
	image.save_png(ProjectSettings.globalize_path(out))
	print("     -> ", out)
	window.queue_free()
	await process_frame


## 把一个包里的所有地图横排画出来，每张标上序号、尺寸和雷数。
class PackPreview:
	extends Control

	const CELL := 26.0
	const PAD := 22.0
	const HEADER := 76.0
	const CAPTION := 44.0
	const GAP := 18.0

	var pack: Dictionary = {}


	func wanted_size() -> Vector2:
		var total_w := PAD
		var tallest := 0.0
		for index in CustomLevel.map_count(pack):
			var one := CustomLevel.map_at(pack, index)
			total_w += int(one.get("width", 0)) * CELL + GAP
			tallest = maxf(tallest, int(one.get("height", 0)) * CELL)
		return Vector2(total_w + PAD - GAP, HEADER + tallest + CAPTION + PAD)


	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)

		var item_bits := PackedStringArray()
		for key in CustomLevel.ITEM_KEYS:
			var count := CustomLevel.item_count(pack, key)
			if count > 0:
				item_bits.append("%s×%d" % [String(CustomLevel.ITEM_NAMES[key]), count])
		draw_string(
			font, Vector2(PAD, 38), String(pack.get("name", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, COLOR_TITLE
		)
		draw_string(
			font, Vector2(PAD, 62),
			"%d 张图 · 共 %d 雷 · 初始道具 %s" % [
				CustomLevel.map_count(pack),
				CustomLevel.total_mines(pack),
				"无" if item_bits.is_empty() else ", ".join(item_bits),
			],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, COLOR_MUTED
		)

		var x := PAD
		for index in CustomLevel.map_count(pack):
			var one := CustomLevel.map_at(pack, index)
			var w := int(one.get("width", 0))
			var h := int(one.get("height", 0))
			var mask: PackedByteArray = one.get("mask", PackedByteArray())
			var origin := Vector2(x, HEADER)
			draw_rect(
				Rect2(origin - Vector2(6, 6), Vector2(w, h) * CELL + Vector2(12, 12)),
				COLOR_PANEL
			)
			draw_rect(
				Rect2(origin - Vector2(6, 6), Vector2(w, h) * CELL + Vector2(12, 12)),
				COLOR_EDGE, false, 2.0
			)
			for y in h:
				for cx in w:
					var rect := Rect2(origin + Vector2(cx, y) * CELL, Vector2(CELL, CELL)).grow(-2.0)
					var on := mask[y * w + cx] == 1
					draw_rect(rect, COLOR_ON if on else COLOR_OFF)
					draw_rect(rect, COLOR_ON_EDGE if on else COLOR_EDGE, false, 1.0)
			draw_string(
				font, Vector2(x, HEADER + h * CELL + 26),
				"%d. %d×%d · %d 雷 · %d 格" % [
					index + 1, w, h, int(one.get("mines", 0)), CustomLevel.active_count(one)
				],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, COLOR_INK
			)
			x += w * CELL + GAP
