extends SceneTree
## 连击柱的环境火花有没有预算。玩家报「PERFECT 连击时卡住然后闪退」，这一层原先是
## 按真实帧时长补粒子、又没有存活上限：掉一次大帧（大连锁结算、窗口切走再切回来）
## delta 就是好几秒，一帧要补出几百个节点 + 补间，下一帧更慢、补得更多，越滚越死。
## 跑法：godot --headless --path . --script tests/test_combo_hud_particle_budget.gd

const HudScript := preload("res://scripts/ui/combo_score_hud.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var hud: Control = HudScript.new()
	root.add_child(hud)
	await process_frame
	hud.sync_state(9999, 40, false)
	await process_frame

	var spark_layer := hud.get("_spark_layer") as Control
	assert(spark_layer != null, "找不到火花层")
	var limit: int = HudScript.AMBIENT_LIVE_LIMIT
	var max_step: float = HudScript.AMBIENT_MAX_STEP

	# 一帧卡了 8 秒：不夹 delta 的话这一下就要补出四百多个粒子。
	var before := spark_layer.get_child_count()
	hud.call("_spawn_ambient_particles", 8.0)
	var burst := spark_layer.get_child_count() - before
	var ceiling := int(ceil(max_step * 60.0)) + 2
	assert(
		burst <= ceiling,
		"一帧掉了 8 秒就补出 %d 个粒子（按 %.2fs 的步长最多该补 %d 个）" % [burst, max_step, ceiling]
	)

	# 连着卡：存活数必须停在上限，不能一路涨上去。
	for _i in 200:
		hud.call("_spawn_ambient_particles", 4.0)
	assert(
		spark_layer.get_child_count() <= limit,
		"连着掉帧之后火花涨到 %d 个，上限是 %d" % [spark_layer.get_child_count(), limit]
	)

	hud.queue_free()
	await process_frame
	print("ComboScoreHud 粒子预算：大 delta 被夹住（一帧 %d 个），存活数封顶在 %d" % [burst, limit])
	quit()
