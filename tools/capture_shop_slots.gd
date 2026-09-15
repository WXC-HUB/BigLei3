extends SceneTree
## 无尽关槽位制商店（鸟窝）的过目截图：常态一张、替换态一张、扩到 12 格一张。
## 跑法（**不能加 --headless**）：
##   godot --fixed-fps 60 --path . --script tools/capture_shop_slots.gd
## 输出 artifacts/shop_nest.png、shop_nest_replacing.png、shop_nest_full.png。

const ShopOverlayView := preload("res://scenes/shop_overlay.tscn")

## 与 main.gd 的 ShopOffer 同序号。
const MAX_HEALTH := 0
const KESTREL := 2
const ORBITAL := 4
const LANTERN := 6
const COMPASS := 8
const CROW := 10
const MAGPIE := 11
const TIT := 12
const EMPTY := -1


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var shop := ShopOverlayView.instantiate() as ShopOverlay
	root.add_child(shop)
	await process_frame

	# 起手窝的下一步：四只起手鸟 + 一只买来的乌鸦，还剩一格。
	shop.set_nest_shop(true)
	shop.set_slots([LANTERN, COMPASS, ORBITAL, KESTREL, KESTREL, EMPTY], 22, 2, 3)
	shop.present("", "", 42, 5)
	# 抽到的货固定下来，截图才稳定：两只占格子的鸟 + 一件强化。
	shop.set("_current_offers", [TIT, MAGPIE, MAX_HEALTH] as Array[int])
	shop.update_gold(42, 5)
	await _settle()
	_shot("res://artifacts/shop_nest.png")

	# 窝满了买长尾山雀：整排货锁住，等玩家点一格。
	shop.set_slots([LANTERN, LANTERN, COMPASS, ORBITAL, KESTREL, MAGPIE], 22, 2, 3)
	shop.begin_slot_replacement(TIT)
	await _settle()
	_shot("res://artifacts/shop_nest_replacing.png")

	# 扩到头：15 格、七种鸟全在，扩建按钮收起，鸟牌挤到最窄也要排得下。
	shop.end_slot_replacement()
	shop.set_slots(
		[
			LANTERN, LANTERN, LANTERN, COMPASS, COMPASS, ORBITAL, KESTREL, KESTREL,
			KESTREL, CROW, MAGPIE, MAGPIE, TIT, EMPTY, EMPTY,
		],
		0, 0, 3
	)
	await _settle()
	_shot("res://artifacts/shop_nest_full.png")
	quit()


func _settle() -> void:
	for _i in 40:
		await process_frame


func _shot(path: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("已保存 ", path)
