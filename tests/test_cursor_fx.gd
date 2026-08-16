extends SceneTree
## 覆盖 scripts/ui/cursor_fx.gd：光标特效挂在最上层、涟漪有池上限并自己播完、
## 拖尾收拢后自动休眠，以及降级开关下依然能正常绘制。

const CursorFxView := preload("res://scripts/ui/cursor_fx.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Each check returns true only if it ran to the end; an assert that trips
	# aborts its function and leaves null here, so failures cannot slip past.
	assert(await _test_sits_above_every_overlay())
	assert(await _test_trail_follows_and_collapses())
	assert(await _test_ripple_pool_is_capped())
	assert(await _test_idle_cursor_stops_processing())
	assert(await _test_reduced_quality_still_draws())
	print("Cursor FX: layering, ripple pool and idle-sleep checks passed")
	await process_frame
	quit()


func _test_sits_above_every_overlay() -> bool:
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame

	var fx: CursorFx = game.get("_cursor_fx")
	assert(fx != null, "The main scene never built the cursor FX layer")
	var canvas := fx.get_parent() as CanvasLayer
	assert(canvas != null, "Cursor FX must live on its own CanvasLayer")

	var highest_other := 0
	for child in game.get_children():
		var other := child as CanvasLayer
		if other != null and other != canvas:
			highest_other = maxi(highest_other, other.layer)
	assert(
		canvas.layer > highest_other,
		"Some overlay would cover the cursor FX"
	)
	assert(fx.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Cursor FX must not eat clicks")

	game.queue_free()
	await process_frame
	return true


## 指针一路移动时拖尾要拉开，且长度被 TRAIL_MAX_SEGMENT 锁住；停下后自己收拢。
func _test_trail_follows_and_collapses() -> bool:
	var fx := _make_fx()
	var point := Vector2(200.0, 200.0)
	for _step in range(40):
		point += Vector2(26.0, 9.0)
		fx.drive_pointer(point)
		await process_frame
	assert(fx.trail_spread() > 60.0, "A moving pointer has to pull the trail open")
	var span := float(CursorFxView.TRAIL_POINTS) * CursorFxView.TRAIL_MAX_SEGMENT
	assert(fx.trail_spread() <= span, "The trail stretched past its segment budget")

	# 指针停住之后拖尾要自己收干净并休眠。
	for _step in range(180):
		if not fx.is_processing():
			break
		await process_frame
	assert(not fx.is_processing(), "A parked pointer should let the trail sleep")
	assert(fx.trail_spread() <= CursorFxView.TRAIL_SLEEP_SPREAD)
	fx.queue_free()
	await process_frame
	return true


func _test_ripple_pool_is_capped() -> bool:
	var fx := _make_fx()
	for index in range(MAX_CLICK_SPAM):
		fx.emit_click(Vector2(120.0 + index * 7.0, 240.0), MOUSE_BUTTON_LEFT)
	assert(
		fx.active_ripple_count() <= CursorFxView.MAX_RIPPLES,
		"Rapid clicking pushed the ripple pool past its cap"
	)
	assert(fx.active_ripple_count() > 0, "A click should leave a live ripple")
	assert(fx.is_processing(), "A click has to wake the effect back up")

	# 右键（插旗）用另一套配色，同样走池子。
	fx.emit_click(Vector2(400.0, 400.0), MOUSE_BUTTON_RIGHT)
	assert(fx.active_ripple_count() <= CursorFxView.MAX_RIPPLES)

	await create_timer(CursorFxView.RIPPLE_DURATION + 0.25).timeout
	assert(fx.active_ripple_count() == 0, "Ripples must finish on their own")
	fx.queue_free()
	await process_frame
	return true


## 鼠标不动、涟漪播完之后，特效必须彻底停下，闲置时不占帧预算。
func _test_idle_cursor_stops_processing() -> bool:
	var fx := _make_fx()
	assert(not fx.is_processing(), "A freshly built cursor FX should start asleep")
	fx.emit_click(Vector2(640.0, 360.0), MOUSE_BUTTON_LEFT)
	assert(fx.is_processing())

	await create_timer(CursorFxView.RIPPLE_DURATION + 0.35).timeout
	assert(not fx.is_processing(), "An idle cursor FX has to stop processing")
	assert(
		fx.trail_spread() <= CursorFxView.TRAIL_SLEEP_SPREAD,
		"The trail should have collapsed onto the cursor"
	)
	fx.queue_free()
	await process_frame
	return true


func _test_reduced_quality_still_draws() -> bool:
	var fx := _make_fx()
	CursorFxView.reduced_quality = true
	fx.emit_click(Vector2(300.0, 300.0), MOUSE_BUTTON_MIDDLE)
	await create_timer(0.2).timeout
	assert(fx.active_ripple_count() > 0, "The lite ripple still has to play")
	await create_timer(CursorFxView.RIPPLE_DURATION).timeout
	assert(fx.active_ripple_count() == 0)
	CursorFxView.reduced_quality = false
	fx.queue_free()
	await process_frame
	return true


const MAX_CLICK_SPAM := 12


func _make_fx() -> CursorFx:
	var fx: CursorFx = CursorFxView.new()
	root.add_child(fx)
	return fx
