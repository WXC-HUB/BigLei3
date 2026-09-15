extends SceneTree
## 九个解锁页彩蛋各自对应一条成就：触发时点亮列表、弹一次提示，重复触发不再计入。

const Catalog := preload("res://scripts/game/achievement_catalog.gd")
const KESTREL := preload("res://scripts/ui/kestrel_unlock.gd")
const HERON := preload("res://scripts/ui/night_heron_unlock.gd")
const REDSTART := preload("res://scripts/ui/redstart_unlock.gd")
const ATTACKER := preload("res://scripts/ui/attacker_unlock.gd")
const TIT := preload("res://scripts/ui/tit_unlock.gd")
const MAGPIE := preload("res://scripts/ui/magpie_unlock.gd")
const CROW := preload("res://scripts/ui/crow_unlock.gd")
const DOVE := preload("res://scripts/ui/dove_unlock.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(await _test_every_egg_awards_its_achievement())
	print("Easter egg achievements: nine eggs, nine unlocks, no duplicates passed")
	await process_frame
	quit()


func _test_every_egg_awards_its_achievement() -> bool:
	# 成就是写进存档的，这条测试每一步都在断言「现在还没解锁」，所以必须用自己的空存档槽跑。
	# 借用真实存档的话，之前任何一次游玩或测试留下的成就都会让第一条断言当场失败。
	GameSave.save_path = "user://test_easter_egg_achievements_save.json"
	GameSave.clear()
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

	# 长尾山雀：撩出一群团子，凑够就融成一碗汤圆
	var tit := game.get("_tit_unlock") as TitUnlock
	_hover(tit.bird, TIT.TANGYUAN_FLOCK - 1)
	assert(not unlocked.has(Catalog.TIT_TANGYUAN), "The tangyuan bowl came out one bird too early")
	_hover(tit.bird, 1)
	assert(unlocked.has(Catalog.TIT_TANGYUAN), "Merging the flock into tangyuan did not award its achievement")

	# 灰喜鹊：撩到虚焦，眼镜滑进来
	var magpie := game.get("_magpie_unlock") as MagpieUnlock
	_hover(magpie.bird, MAGPIE.HOVERS_TO_GLASSES - 1)
	assert(not unlocked.has(Catalog.MAGPIE_SENPAI), "The glasses came in one hover too early")
	_hover(magpie.bird, 1)
	assert(unlocked.has(Catalog.MAGPIE_SENPAI), "Putting the glasses on did not award its achievement")

	# 小嘴乌鸦：一只一只薅过去，薅到熊猫被追着跑
	var crow := game.get("_crow_unlock") as CrowUnlock
	var swap_cycle := CROW.PLUCK_LEAN_TIME + CROW.PLUCK_YANK_TIME + CROW.SWAP_OUT_TIME + CROW.SWAP_IN_TIME + 0.1
	for _pluck in range(CROW.VICTIMS.size() - 1):
		crow.bird.mouse_entered.emit()
		await create_timer(swap_cycle).timeout
	assert(not unlocked.has(Catalog.CROW_CHASED_BY_PANDA), "The panda gave chase one victim too early")
	crow.bird.mouse_entered.emit()
	await create_timer(CROW.PLUCK_LEAN_TIME + CROW.PLUCK_YANK_TIME + 0.08).timeout
	assert(unlocked.has(Catalog.CROW_CHASED_BY_PANDA), "Plucking the panda did not award its achievement")
	# 追逐还在跑，等它收场再拆场景，免得 tween 打在已经释放的节点上。
	await create_timer(CROW.chase_duration() + 0.3).timeout

	# 斑鸠：一根一根叼枝筑巢，堆满了被红隼叼走
	var dove := game.get("_dove_unlock") as DoveUnlock
	var twig_cycle := DOVE.twig_duration() + 0.14
	for _twig in range(DOVE.TWIGS_TO_NEST - 1):
		dove.bird.mouse_entered.emit()
		await create_timer(twig_cycle).timeout
	assert(not unlocked.has(Catalog.DOVE_SNATCHED), "The kestrel came one twig too early")
	dove.bird.mouse_entered.emit()
	await create_timer(DOVE.TWIG_LEAN_TIME + DOVE.TWIG_DROP_TIME + 0.08).timeout
	assert(unlocked.has(Catalog.DOVE_SNATCHED), "Being carried off did not award its achievement")
	# 红隼还在往外飞，等它飞完再拆场景。
	await create_timer(DOVE.snatch_duration() + 0.3).timeout

	# 九条全部点亮，且提示条各排了一次队。
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
	GameSave.clear()
	return true


func _egg_ids() -> PackedStringArray:
	return PackedStringArray([
		Catalog.WOODPECKER_SCREEN_BREAK,
		Catalog.HERON_YOROSHIKU,
		Catalog.REDSTART_AQUEDUCT,
		Catalog.KESTREL_PIGEON_RAIN,
		Catalog.KESTREL_STUFFED,
		Catalog.TIT_TANGYUAN,
		Catalog.MAGPIE_SENPAI,
		Catalog.CROW_CHASED_BY_PANDA,
		Catalog.DOVE_SNATCHED,
	])


## 成就是在触发那一帧就报上来的，不用等整段演出播完。
func _hover(target: Control, times: int) -> void:
	for index in range(times):
		target.mouse_entered.emit()
