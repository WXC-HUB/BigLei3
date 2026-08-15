extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var trees := game.get_node("Scenery/Trees")
	var tree_list: Array = trees.get("_trees")
	if tree_list.is_empty():
		_fail("No trees were registered")
		return
	var tree := tree_list[0] as TextureRect
	var center := tree.global_position + tree.size * 0.5
	if not trees.call("_is_opaque_at", tree, center):
		_fail("The visible center of the first tree was not clickable")
		return

	var click := InputEventMouseButton.new()
	click.position = center
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	trees.call("_input", click)
	var material := tree.material as ShaderMaterial
	var initial_strength: float = material.get_shader_parameter("click_strength")
	if initial_strength <= 0.0:
		_fail("The click did not start a shader shake impulse")
		return
	await create_timer(0.35).timeout
	var final_strength: float = material.get_shader_parameter("click_strength")
	if not is_zero_approx(final_strength):
		_fail("The shader shake impulse did not settle")
		return

	print("Tree interaction: all tests passed")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
