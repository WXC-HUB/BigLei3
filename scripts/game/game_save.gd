class_name GameSave
extends RefCounted
## Minimal single-slot JSON save. The board itself is intentionally excluded;
## `current_level` always points to the level that should restart from its beginning.
##
## v2（FEAT-002）在原有字段之上加了四个：`cleared_stages`（已通关关卡集合，驱动悬浮
## 牌的 ✓ 与地形区解锁）、`resume_stage_id`（唯一续局槽属于哪一关，空串 = 无续局）、
## `stage_round`（续局槽在**本关内**打到第几盘，与全局盘序 `current_level` 分开记）、
## `music_break_played`（原本只在内存里，落盘后换歌插播在整个存档周期内只放一次）。
## v3：`stage_high_scores`（每关历史最高分，字典 stage_id → int）。
## v3 续：`leaderboard_name`（上榜昵称，本地记住，下次上榜预填）。
## 其余字段原样不动。

const VERSION := 3
static var save_path := "user://bird_minesweeper_save.json"


static func exists() -> bool:
	return FileAccess.file_exists(save_path)


static func load_data() -> Dictionary:
	if not exists():
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open save file: %s" % FileAccess.get_open_error())
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Save file is not valid JSON data")
		return {}
	var payload := parsed as Dictionary
	var version := int(payload.get("version", 0))
	if not payload.get("data", {}) is Dictionary:
		push_warning("Save file has no data section")
		return {}
	# 只往前迁移。比本版新的档一律拒绝——那是玩家降级了游戏版本，猜字段只会把存档改
	# 坏，宁可当没有存档。
	if version > VERSION or version < 1:
		push_warning("Save file version is unsupported")
		return {}
	var data := (payload["data"] as Dictionary).duplicate(true)
	if version < VERSION:
		data = _migrate(data, version)
	return data


## v1 → v2：老档没有关卡概念，所以已通关集合从空开始。老档若有一轮打到一半
## （`current_level > 1`），把这份进度整体归给第一关的续局槽——玩家回来时地图上会看到
## 第一关标着「进行中」，点续上就接着打，血量金币强化全在。
## v2 → v3：补每关最高分字典；没有玩过的关保持缺席（读侧当 0）。
static func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version <= 1:
		data["cleared_stages"] = []
		data["music_break_played"] = false
		var level := maxi(int(data.get("current_level", 1)), 1)
		if level > 1 and not StageTable.STAGES.is_empty():
			data["resume_stage_id"] = String(StageTable.STAGES[0]["id"])
			data["stage_round"] = level
		else:
			data["resume_stage_id"] = ""
			data["stage_round"] = 0
	if from_version <= 2:
		if not data.has("stage_high_scores") or not data["stage_high_scores"] is Dictionary:
			data["stage_high_scores"] = {}
		if not data.has("leaderboard_name"):
			data["leaderboard_name"] = ""
	return data


static func write(data: Dictionary) -> bool:
	var temporary_path := save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not create save file: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify({"version": VERSION, "data": data}, "\t"))
	file.flush()
	file.close()
	var absolute_save := ProjectSettings.globalize_path(save_path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_save)
	var error := DirAccess.rename_absolute(absolute_temporary, absolute_save)
	if error != OK:
		push_warning("Could not finalize save file: %s" % error_string(error))
		return false
	return true


static func clear() -> bool:
	var ok := true
	for path in [save_path, save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and ok
	return ok
