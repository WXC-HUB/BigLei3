extends SceneTree
## 调试用：把某关 .glb 里地形贴图按 Godot 实际解出来的样子存成 PNG，核对 Blender 那边画的地面
## 有没有原样进到引擎。跑法：
##   godot --headless --script tools/dump_diorama_texture.gd -- coast_1
## 输出 artifacts/texdump_<id>.png，并打印贴图尺寸与几个采样点。

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id := String(args[0]) if args.size() > 0 else "coast_1"
	var path := ProjectSettings.globalize_path("res://assets/dioramas/%s/%s.glb" % [id, id])
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		push_error("read failed %d" % err)
		quit(1)
		return
	var scene := doc.generate_scene(state) as Node3D
	var meshes: Array[MeshInstance3D] = []
	_collect(scene, meshes)
	for mi in meshes:
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat != null and mat.albedo_texture != null:
				var img := mat.albedo_texture.get_image()
				print("%s surface %d: texture %dx%d format %d" % [mi.name, s, img.get_width(), img.get_height(), img.get_format()])
				var samples := {"beach": Vector2i(333, 870), "quay": Vector2i(1000, 400), "grass": Vector2i(1000, 150)}
				for key in samples.keys():
					print("  %s %s" % [key, img.get_pixelv(samples[key])])
				img.save_png(ProjectSettings.globalize_path("res://artifacts/texdump_%s.png" % id))
				print("saved artifacts/texdump_%s.png" % id)
	quit()


func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)
