extends SceneTree

const EXPECTED_TEXTURES := {
	MinesweeperBoard.ItemType.LANTERN: preload("res://assets/sprites/generated/bird_items/item_bird_lantern.png"),
	MinesweeperBoard.ItemType.COMPASS: preload("res://assets/sprites/generated/bird_items/item_bird_compass.png"),
	MinesweeperBoard.ItemType.ORBITAL_STRIKE: preload("res://assets/sprites/generated/bird_items/item_bird_orbital.png"),
	MinesweeperBoard.ItemType.SUPER_LUCK: preload("res://assets/sprites/generated/bird_items/item_bird_super_luck.png"),
}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	for item_type in EXPECTED_TEXTURES:
		assert(game.call("_item_texture", item_type) == EXPECTED_TEXTURES[item_type], "Board item did not use its bird icon")

	var shop := (load("res://scenes/shop_overlay.tscn") as PackedScene).instantiate() as ShopOverlay
	root.add_child(shop)
	await process_frame
	var shop_items: Array = shop.get("_item_nodes")
	var ordered_types := [
		MinesweeperBoard.ItemType.LANTERN,
		MinesweeperBoard.ItemType.COMPASS,
		MinesweeperBoard.ItemType.ORBITAL_STRIKE,
		MinesweeperBoard.ItemType.SUPER_LUCK,
	]
	for index in range(ordered_types.size()):
		var icon := (shop_items[index] as Node).get_node("Item_Icon") as Sprite2D
		assert(icon.texture == EXPECTED_TEXTURES[ordered_types[index]], "Shop item did not use its bird icon")
	print("Bird item icons: board and shop mappings passed")
	quit()
