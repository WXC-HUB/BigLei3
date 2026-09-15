extends SceneTree
## 鸟类图鉴的两张校对图：新档（只有小蓝鸟，其余全是剪影）和全解锁。
##   godot --fixed-fps 60 --path . --script tools/capture_bird_codex.gd
##
## 直接实例化图鉴页，不经过 main.tscn：这一页本来就只吃「谁解锁了」这一个输入，
## 拖上整局游戏只会让截图等开场演出，也会被主场景当时的任何半成品状态挡住。

const Catalog := preload("res://scripts/game/bird_catalog.gd")
const CodexScreen := preload("res://scripts/ui/bird_codex_screen.gd")
const LOCKED_PATH := "res://artifacts/bird_codex_locked.png"
const UNLOCKED_PATH := "res://artifacts/bird_codex_unlocked.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var codex: BirdCodexScreen = CodexScreen.new()
	canvas.add_child(codex)
	await process_frame

	for bird_id in Catalog.ids():
		codex.set_unlocked(bird_id, bird_id == Catalog.BLUE)
	codex.present()
	await create_timer(0.6).timeout
	await _save(LOCKED_PATH)

	for bird_id in Catalog.ids():
		codex.set_unlocked(bird_id, true)
	await create_timer(0.4).timeout
	await _save(UNLOCKED_PATH)
	quit()


func _save(path: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		quit(1)
		return
	print("Saved ", ProjectSettings.globalize_path(path))
