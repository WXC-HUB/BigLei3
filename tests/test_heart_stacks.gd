extends SceneTree
## 单机血条：上限 4 颗以内一颗一格；超过 4 颗就把多出来的并进前面的格子里叠着放，最多
## 4 摞、每摞最多 3 颗，摞不下才继续加摞。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(10.0).timeout.connect(func() -> void:
		push_error("Heart stack test timed out")
		quit(2)
	)
	var status := (load("res://scenes/player_status.tscn") as PackedScene).instantiate() as PlayerStatus
	root.add_child(status)
	await process_frame
	var cases := {
		3: [1, 1, 1],
		4: [1, 1, 1, 1],
		5: [2, 1, 1, 1],
		6: [2, 2, 1, 1],
		9: [3, 2, 2, 2],
		12: [3, 3, 3, 3],
		13: [3, 3, 3, 2, 2],
	}
	for maximum in cases:
		status.set_health(maximum, maximum)
		await process_frame
		if not _require(
			_layout(status) == cases[maximum],
			"上限 %d 摆成了 %s，应该是 %s" % [maximum, _layout(status), cases[maximum]]
		): return
		if not _require(
			(status.get("_hearts") as Array).size() == maximum,
			"上限 %d 的心总数不对" % maximum
		): return

	# 一摞里从左下往右上填，掉血先灭右上那颗：上限 6 打剩 4 血时，亮着的必须是前四颗。
	status.set_health(4, 6)
	await process_frame
	var hearts: Array = status.get("_hearts")
	for index in range(hearts.size()):
		var lit: bool = (hearts[index] as TextureRect).modulate.a > 0.5
		if not _require(lit == (index < 4), "第 %d 颗心的明灭状态不对" % index): return

	# 一摞里的心要真的错开，不然看着还是并排的散心。
	status.set_health(6, 6)
	await process_frame
	var health_bar := status.get_node("%HealthHearts") as HBoxContainer
	var stack := health_bar.get_child(0) as Control
	var first := stack.get_child(0) as Control
	var second := stack.get_child(1) as Control
	if not _require(
		second.position.x > first.position.x and second.position.y < first.position.y,
		"同一摞里的心没有朝右上错开"
	): return
	if not _require(
		stack.custom_minimum_size.x < first.size.x * 2.0, "叠放没有省下横向空间"
	): return

	# 对战的紧凑血条不受影响：仍然是一颗心加「×N」。
	status.set_compact_hearts(true)
	status.set_health(6, 6)
	await process_frame
	if not _require((status.get("_hearts") as Array).size() == 1, "紧凑血条被叠放改坏了"): return
	print("Heart stacks: grouped hearts above four passed")
	quit()


func _layout(status: PlayerStatus) -> Array:
	var plan: Array = []
	for slot in (status.get_node("%HealthHearts") as HBoxContainer).get_children():
		plan.append(slot.get_child_count())
	return plan


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
