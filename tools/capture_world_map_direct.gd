extends SceneTree
## 世界地图选关屏的过目截图——**直接实例化 world_map.tscn**，不经 main.tscn。
## 调画风时用这个：不依赖主场景里其它资源是否已导入，起得也快。
## 跑法（**不能加 --headless**，否则渲不出东西）：
##   godot --fixed-fps 60 --script tools/capture_world_map_direct.gd
## 可选环境变量 WORLD_MAP_SHOT 指定输出路径（默认 artifacts/world_map_review.png）。

const DEFAULT_OUTPUT := "res://artifacts/world_map_review.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	# 按项目设计分辩率出图，UI 尺寸才和真机一致。
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var map := (load("res://scenes/world_map.tscn") as PackedScene).instantiate() as WorldMap
	# 随机事件会把鸟飞进画面，过目图要的是静态构图。
	map.woodpecker_events = false
	map.kestrel_events = false
	map.redstart_events = false
	root.add_child(map)
	await process_frame
	await process_frame
	# 前两关通了、第 3 关打到一半：四种悬浮牌状态和续局提示条同时出现。
	map.present(["grass_1", "grass_2"], "grass_3", 2, {
		"grass_1": 2556, "grass_2": 15536, "grass_3": 1764, "grass_4": 2488, "grass_5": 3540,
	})
	# 蚊子本来要等一两秒才飞进来；截图直接放在右侧空地上，构图固定。
	map.mosquito().spawn_at(Vector2(1330.0, 420.0))
	for _i in 45:
		await process_frame
	var out := OS.get_environment("WORLD_MAP_SHOT")
	if out == "":
		out = DEFAULT_OUTPUT
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(out))
	print("已保存 ", out)
	quit()
