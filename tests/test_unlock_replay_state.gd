extends SceneTree
## 触发彩蛋、收起页面、再次 present 之后，四个解锁页都必须回到初始状态。
##
## 盯的是一类具体的坑：RevealMotion 是拿立绘"当前位置"当归位点的，
## 彩蛋把鸟挪走之后如果不还原位姿，下一次进这一页鸟就把那儿当家了。

const ATTACKER := preload("res://scripts/ui/attacker_unlock.gd")
const HERON := preload("res://scripts/ui/night_heron_unlock.gd")
const REDSTART := preload("res://scripts/ui/redstart_unlock.gd")
const KESTREL := preload("res://scripts/ui/kestrel_unlock.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var title := game.get("_start_screen") as Control
	if title != null:
		game.set("_start_screen", null)
		title.get_parent().queue_free()
	game.call("_start_game")
	await create_timer(0.4).timeout

	assert(await _replay(game.get("_night_heron_unlock"), "final_bird", HERON.RAGE_HOVERS))
	assert(await _replay(game.get("_redstart_unlock"), "final_bird", REDSTART.RAGE_HOVERS))
	assert(await _replay(game.get("_attacker_unlock"), "bird", ATTACKER.RAGE_PECKS))
	assert(await _replay(game.get("_kestrel_unlock"), "bird", KESTREL.GLUTTON_PIGEONS + KESTREL.RAGE_HOVERS))
	print("Unlock replay: all four pages come back clean after their easter egg")
	await process_frame
	quit()


func _replay(page: Control, bird_name: String, hovers: int) -> bool:
	var bird := page.get(bird_name) as Control
	page.call("present")
	await create_timer(3.0).timeout
	# 真窗口下鼠标可能压在鸟上，关掉响应只走手动 emit。
	bird.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var home := bird.position
	var home_visible := bird.visible

	for hover in range(hovers):
		bird.mouse_entered.emit()
		await create_timer(0.02).timeout
	# 等整段演出播完，再像玩家那样点继续收起页面。
	await create_timer(3.2).timeout
	var continue_button := page.get_node("Finale/Continue") as Button
	continue_button.pressed.emit()
	await create_timer(1.0).timeout

	page.call("present")
	await create_timer(3.2).timeout
	var label := page.name
	assert(
		bird.position.distance_to(home) < 1.0,
		"%s: the portrait did not come back home (drift %.0fpx)" % [
			label, bird.position.distance_to(home)
		]
	)
	assert(bird.visible == home_visible, "%s: the portrait is still hidden" % label)
	assert(bird.scale.x < 1.2, "%s: the portrait kept its easter-egg scale" % label)
	assert(is_equal_approx(Engine.time_scale, 1.0), "%s: hitstop left the clock scaled" % label)
	continue_button.pressed.emit()
	await create_timer(0.8).timeout
	return true
