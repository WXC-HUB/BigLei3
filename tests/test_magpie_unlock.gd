extends SceneTree
## 灰喜鹊解锁页：文案齐全；每撩一次页面更虚焦；撩够次数眼镜滑进来、镜片里是学姐、报成就；
## 之后再撩只晃眼镜；重开页面全部还原。

const MAGPIE := preload("res://scripts/ui/magpie_unlock.gd")
const Catalog := preload("res://scripts/game/achievement_catalog.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("Magpie unlock test timed out")
		quit(2)
	)
	# 成就写在存档里：换到临时存档位，否则本机存档里已点亮的成就会让「太早」断言误报。
	GameSave.save_path = "user://test_magpie_unlock_save.json"
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

	var unlock := game.get("_magpie_unlock") as MagpieUnlock
	assert(unlock != null, "Main did not build the magpie unlock page")
	var name_label := unlock.get_node("Finale/Name") as Label
	var tagline := unlock.get_node("Finale/Tagline") as Label
	var effect := unlock.get_node("Finale/Effect") as Label
	var continue_button := unlock.get_node("Finale/Continue") as Button
	assert(name_label.text.replace(" ", "") == "灰喜鹊", "Magpie name line is incorrect")
	assert(not tagline.text.is_empty(), "Magpie tagline is missing")
	assert(effect.text.contains("一格一格"), "Magpie effect line does not describe the step-by-step walk")
	assert((unlock.get_node("BirdCall") as AudioStreamPlayer).stream != null, "Magpie hover call is missing")
	var pattern := (unlock.get_node("IconPattern") as ColorRect).material as ShaderMaterial
	assert(pattern != null and pattern.get_shader_parameter("icon_texture") != null, "Magpie unlock has no moving icon pattern")
	var veil := unlock.get_node("DefocusVeil") as ColorRect
	var rig := unlock.get_node("GlassesRig") as Control
	var lens := unlock.get_node("GlassesRig/LensView") as TextureRect
	assert(lens.texture != null and lens.material is ShaderMaterial, "Lens view has no senpai texture or mask shader")
	assert((unlock.get_node("GlassesRig/Glasses") as TextureRect).texture != null, "Glasses texture is missing")

	unlock.present()
	await create_timer(3.0).timeout
	assert(unlock.visible and not continue_button.disabled, "Unlock page reveal never finished")
	assert(not veil.visible and not rig.visible, "Page started already defocused or wearing glasses")
	var unlocked: Dictionary = game.get("_unlocked_achievements")

	# 每撩一次更糊一点，眼镜还没来。
	unlock.bird.mouse_entered.emit()
	assert(unlock.hover_count() == 1, "First hover was not counted")
	assert(veil.visible and unlock.blur_amount() > 0.0, "First hover did not defocus the page")
	var first_blur := unlock.blur_amount()
	for _hover in range(MAGPIE.HOVERS_TO_GLASSES - 2):
		unlock.bird.mouse_entered.emit()
	assert(unlock.blur_amount() > first_blur, "Repeated hovers did not deepen the defocus")
	assert(not rig.visible and not unlocked.has(Catalog.MAGPIE_SENPAI), "Glasses came in one hover too early")

	# 撩够：眼镜滑进来、报成就；滑到位后镜片对焦，学姐出现。
	unlock.bird.mouse_entered.emit()
	assert(unlocked.has(Catalog.MAGPIE_SENPAI), "Glasses did not award the senpai achievement")
	assert(rig.visible, "Glasses rig did not appear")
	assert(not unlock.glasses_on(), "Glasses counted as worn before they finished sliding in")
	await create_timer(MAGPIE.glasses_duration() + 0.3).timeout
	assert(unlock.glasses_on(), "Glasses never settled")
	assert(is_equal_approx(lens.modulate.a, 1.0), "Lens did not focus on the senpai")
	var bird := unlock.bird
	assert(rig.position.is_equal_approx(unlock.glasses_home()), "Glasses did not settle at their home: %s" % rig.position)
	assert(rig.scale.is_equal_approx(Vector2(MAGPIE.GLASSES_SCALE, MAGPIE.GLASSES_SCALE)), "Glasses did not end at their giant scale")
	var right_lens := rig.position + rig.size * 0.5 + (MAGPIE.RIGHT_LENS_CENTRE - rig.size * 0.5) * MAGPIE.GLASSES_SCALE
	var eye := bird.position + bird.size * MAGPIE.EYE_ANCHOR
	assert(right_lens.is_equal_approx(eye), "Right lens did not land on the bird's eye: %s vs %s" % [right_lens, eye])
	assert(rig.size.x * MAGPIE.GLASSES_SCALE > unlock.size.x * 1.5, "Glasses are not much wider than the screen")
	var left_lens := rig.position + rig.size * 0.5 + (Vector2(200.0, 150.0) - rig.size * 0.5) * MAGPIE.GLASSES_SCALE
	assert(left_lens.x < -100.0, "Left lens should be off screen; only one lens shows: %s" % left_lens)
	assert(veil.visible, "Defocus disappeared once the glasses were on; only the lens should be sharp")
	assert(continue_button.z_index > veil.z_index and continue_button.z_index > rig.z_index, "Continue button sits under the defocus veil or the giant glasses")

	# 戴上之后再撩：不再加糊，眼镜晃一晃。
	var blur_before := unlock.blur_amount()
	var count_before := unlock.hover_count()
	unlock.bird.mouse_entered.emit()
	await create_timer(0.05).timeout
	assert(unlock.hover_count() == count_before and is_equal_approx(unlock.blur_amount(), blur_before), "Hovering with glasses on kept defocusing")
	assert(not is_equal_approx(rig.rotation, 0.0), "Glasses did not wiggle on hover")
	await create_timer(0.5).timeout

	# 重开页面：一切还原。
	continue_button.pressed.emit()
	await create_timer(0.4).timeout
	unlock.present()
	await create_timer(0.2).timeout
	assert(unlock.hover_count() == 0 and not unlock.glasses_on(), "Reopening the page kept the egg state")
	assert(not veil.visible and not rig.visible, "Reopening the page kept the defocus or the glasses")
	assert(is_equal_approx(unlock.blur_amount(), 0.0), "Reopening the page kept the blur")
	GameSave.clear()
	print("Magpie unlock: texts, defocus, glasses, senpai lens, achievement, wiggle and reset passed")
	quit()
