extends SceneTree
## 自定义关卡包编辑器的三栏布局截图：左边地图列表、中间画布、右边初始道具。
## 跑法：godot --fixed-fps 60 --path . --script tools/capture_custom_editor.gd

const OUTPUT_PATH := "res://artifacts/custom_editor_review.png"
const LevelEditorScript := preload("res://scripts/ui/custom_level_editor.gd")


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var editor = LevelEditorScript.new()
	root.add_child(editor)
	await process_frame

	# 三张形状各异的图，好让左栏的缩略图有东西可看。
	var pack := CustomLevel.make_default()
	pack["name"] = "峡谷三部曲"
	pack["maps"] = [
		{
			"width": 8, "height": 6, "mines": 9,
			"mask": PackedByteArray([
				0, 0, 1, 1, 1, 1, 0, 0,
				0, 1, 1, 1, 1, 1, 1, 0,
				1, 1, 1, 0, 0, 1, 1, 1,
				1, 1, 1, 0, 0, 1, 1, 1,
				0, 1, 1, 1, 1, 1, 1, 0,
				0, 0, 1, 1, 1, 1, 0, 0,
			]),
		},
		{
			"width": 10, "height": 4, "mines": 6,
			"mask": PackedByteArray([
				1, 1, 0, 0, 1, 1, 0, 0, 1, 1,
				1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
				1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
				1, 1, 0, 0, 1, 1, 0, 0, 1, 1,
			]),
		},
		{
			"width": 5, "height": 5, "mines": 4,
			"mask": PackedByteArray([
				1, 0, 0, 0, 1,
				0, 1, 0, 1, 0,
				0, 0, 1, 0, 0,
				0, 1, 0, 1, 0,
				1, 0, 0, 0, 1,
			]),
		},
	]
	pack["items"] = {
		"lantern": 2, "compass": 1, "orbital_strike": 1, "super_luck": 0,
		"medical_kit": 2, "xray": 1, "chain": 0, "enlarge": 1, "detect": 0,
	}
	editor.load_level(pack)
	editor.present()
	await create_timer(0.8).timeout

	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("saved ", OUTPUT_PATH)
	quit()
