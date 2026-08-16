extends SceneTree
## 五个解锁页彩蛋各自对应一条成就：触发时点亮列表、弹一次提示，重复触发不再计入。

const Catalog := preload("res://scripts/game/achievement_catalog.gd")
const KESTREL := preload("res://scripts/ui/kestrel_unlock.gd")
const HERON := preload("res://scripts/ui/night_heron_unlock.gd")
const REDSTART := preload("res://scripts/ui/redstart_unlock.gd")
const ATTACKER := preload("res://scripts/ui/attacker_unlock.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(await _test_every_egg_awards_its_achievement())
	print("Easter egg achievements: five eggs, five unlocks, no duplicates passed")
	await process_frame
	quit()


func _test_every_egg_awards_its_achievement() -> bool:
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var title := game.get("_start_screen") as Control
	if title != null:
		game.set("_start_screen", null)
		title.get_parent().queue_free()
	game.call("_start_game")
	await create_timer(0.4).timeout

	var unlocked: Dictionary = game.get("_unlocked_achievements")
	var screen := game.get("_achievements_screen") as AchievementsScreen
	for egg_id in _egg_ids():
		assert(not unlocked.has(egg_id), "%s was unlocked before the egg fired" % egg_id)
		assert(not screen.is_unlocked(egg_id), "%s shows as earned too early" % egg_id)

	# 啄木鸟：撩到破屏
	var woodpecker := game.get("_attacker_unlock") as AttackerUnlock
	_hover(woodpecker.bird, ATTACKER.RAGE_PECKS)
	assert(
		unlocked.has(Catalog.WOODPECKER_SCREEN_BREAK),
		"Breaking the screen did not award its achievement"
	)

	# 夜鹭：撩到跳出画面
	var heron := game.get("_night_heron_unlock") as NightHeronUnlock
	_hover(heron.final_bird, HERON.RAGE_HOVERS)
	assert(unlocked.has(Catalog.HERON_YOROSHIKU), "The heron rage did not award its achievement")

	# 红尾水鸲：撩到水渠立起
	var redstart := game.get("_redstart_unlock") as RedstartUnlock
	_hover(redstart.final_bird, REDSTART.RAGE_HOVERS)
	assert(unlocked.has(Catalog.REDSTART_AQUEDUCT), "The aqueduct did not award its achievement")

	# 红隼：先鸽子雨，再吃撑
	var kestrel := game.get("_kestrel_unlock") as KestrelUnlock
	_hover(kestrel.bird, KESTREL.RAGE_HOVERS)
	assert(
		unlocked.has(Catalog.KESTREL_PIGEON_RAIN),
		"Switching to pigeon rain did not award its achievement"
	)
	assert(
		not unlocked.has(Catalog.KESTREL_STUFFED),
		"Getting stuffed should need thirty pigeons, not one"
	)
	while int(kestrel.get("_pigeon_count")) <= KESTREL.GLUTTON_PIGEONS:
		kestrel.bird.mouse_entered.emit()
	assert(unlocked.has(Catalog.KESTREL_STUFFED), "Eating thirty pigeons did not award its achievement")

	# 五条全部点亮，且提示条各排了一次队。
	var toast := game.get("_achievement_toast") as AchievementToast
	for egg_id in _egg_ids():
		assert(screen.is_unlocked(egg_id), "%s did not light up on the achievements page" % egg_id)
	var queued := toast._queue.size() + (1 if toast._showing else 0)
	assert(queued >= 1, "No achievement toast was raised for the eggs")

	# 再撩不会重复计入。
	var tally := unlocked.size()
	_hover(kestrel.bird, 3)
	_hover(heron.final_bird, 3)
	assert(unlocked.size() == tally, "An egg awarded its achievement twice")
	game.queue_free()
	await process_frame
	return true


func _egg_ids() -> PackedStringArray:
	return PackedStringArray([
		Catalog.WOODPECKER_SCREEN_BREAK,
		Catalog.HERON_YOROSHIKU,
		Catalog.REDSTART_AQUEDUCT,
		Catalog.KESTREL_PIGEON_RAIN,
		Catalog.KESTREL_STUFFED,
	])


## 成就是在触发那一帧就报上来的，不用等整段演出播完。
func _hover(target: Control, times: int) -> void:
	for index in range(times):
		target.mouse_entered.emit()
