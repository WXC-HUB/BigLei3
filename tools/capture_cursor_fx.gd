extends SceneTree
## 把光标拖尾和点击涟漪逐帧截到 artifacts/ 下，方便肉眼确认长度、粗细和配色。
## 运行方式（需要渲染窗口，不能加 --headless）：
##   godot --fixed-fps 60 --script tools/capture_cursor_fx.gd
## --fixed-fps 必须带上：保存 PNG 会拖长真实帧间隔，不固定步长的话拖尾每帧
## 追赶的距离都不一样，截出来的长度没有参考价值。

const OUTPUT_DIR := "res://artifacts/cursor_fx"

var _game: Node
var _fx: CursorFx


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	await process_frame
	await process_frame
	# 直接掀掉标题页：走正常的开始流程会先排队播耳机提示和开场白，
	# 那两层会把整块画面盖成黑底，看不出特效压在棋盘上的实际效果。
	var start_screen: Node = _game.get("_start_screen")
	if start_screen != null:
		start_screen.get_parent().queue_free()
		_game.set("_start_screen", null)
	_game.call("_start_game")
	_game.call("_start_game")
	await create_timer(0.6).timeout
	_fx = _game.get("_cursor_fx")

	await _capture_trail()
	await _capture_slow_trail()
	await _capture_ripple("left", MOUSE_BUTTON_LEFT)
	await _capture_ripple("right", MOUSE_BUTTON_RIGHT)

	print("Saved cursor FX frames to ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


## 沿一条弧线扫过屏幕，中途取三张：起步、匀速、急转。
func _capture_trail() -> void:
	var start := Vector2(360.0, 760.0)
	var span := Vector2(1180.0, -430.0)
	var steps := 34
	for step in range(steps):
		var ratio := float(step) / float(steps - 1)
		var point := start + Vector2(span.x * ratio, span.y * sin(ratio * PI))
		_warp(point)
		await process_frame
		match step:
			5:
				_shoot("trail_00_start")
			16:
				_shoot("trail_01_sweep")
			30:
				_shoot("trail_02_turn")
	await create_timer(0.5).timeout
	_shoot("trail_03_settled")


## 日常速度（约 700 逻辑像素/秒）扫一段，确认慢速下拖尾不会糊成一坨。
func _capture_slow_trail() -> void:
	var start := Vector2(520.0, 300.0)
	var steps := 40
	for step in range(steps):
		_warp(start + Vector2(12.0 * step, 3.0 * step))
		await process_frame
		if step == 30:
			_shoot("trail_04_slow")


func _capture_ripple(tag: String, button_index: int) -> void:
	var center := Vector2(960.0, 540.0)
	_warp(center)
	await create_timer(0.4).timeout
	_fx.emit_click(center, button_index)
	await _shoot_after("ripple_%s_00_flash" % tag, 0.03)
	await _shoot_after("ripple_%s_01_spread" % tag, 0.08)
	await _shoot_after("ripple_%s_02_sparks" % tag, 0.1)
	await _shoot_after("ripple_%s_03_fade" % tag, 0.15)


## 直接喂坐标而不是 Input.warp_mouse：截图时窗口未必有焦点，靠真实鼠标
## 经常整段拖尾都推不起来，截出来是空的。
func _warp(logical_position: Vector2) -> void:
	_fx.drive_pointer(logical_position)


func _shoot_after(name: String, wait: float) -> void:
	await create_timer(wait).timeout
	await process_frame
	_shoot(name)


func _shoot(name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [OUTPUT_DIR, name])
