extends SceneTree
## 第一关展品 grass_1：场景能实例化、模型有几组网格、材质统一成哑光、溪水与锚点齐全、
## 展柜相机是正交且对着小岛。无头跑，模型走 GLTFDocument 直读也要能过。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(40.0).timeout.connect(func() -> void:
		push_error("Stage diorama test timed out")
		quit(2)
	)
	var packed := load("res://scenes/dioramas/grass_1.tscn") as PackedScene
	assert(packed != null, "scenes/dioramas/grass_1.tscn 加载失败")
	var diorama := packed.instantiate() as StageDiorama
	assert(diorama != null, "根节点不是 StageDiorama")
	assert(diorama.entrance_on_ready, "场景文件应默认播入场（F6 预览）")
	diorama.entrance_on_ready = false
	root.add_child(diorama)
	await process_frame

	var layout := diorama.layout()
	assert(not layout.is_empty(), "布局 JSON 没读到")
	assert(int(layout["cols"]) >= 20 and int(layout["rows"]) >= 15, "布局尺寸不对")

	var model := diorama.model()
	assert(model != null and model.get_child_count() > 0, "模型是空的")
	var meshes := _collect_meshes(model)
	assert(meshes.size() >= 4, "模型里网格太少：%d（应有地形/建筑/树/道具几组）" % meshes.size())
	var names := {}
	for mesh_node in meshes:
		names[String(mesh_node.name).to_lower()] = true
		for surface in mesh_node.mesh.get_surface_count():
			var mat := mesh_node.get_active_material(surface) as ShaderMaterial
			assert(mat != null, "%s 第 %d 面没换成入场着色器材质" % [mesh_node.name, surface])
			assert(mat.shader == StageDiorama.BUILD_SHADER, "%s 材质用的不是 diorama_build 着色器" % mesh_node.name)
			assert(is_equal_approx(float(mat.get_shader_parameter("build")), 1.0), "%s 静态时 build 应为 1" % mesh_node.name)
			var expect_mode := 0 if String(mesh_node.name).to_lower().begins_with("terrain") else 1
			assert(int(mat.get_shader_parameter("mode")) == expect_mode, "%s 的入场 mode 不对" % mesh_node.name)
		assert(mesh_node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "%s 不投影" % mesh_node.name)
	_check_entrance_pivots(meshes)
	for expected in ["terrain", "buildings", "trees", "props"]:
		var found := false
		for key in names.keys():
			if String(key).begins_with(expected):
				found = true
		assert(found, "模型里缺少 %s 组" % expected)

	assert(diorama.water() != null and diorama.water().mesh != null, "没有溪水面")
	assert(diorama.water().get_surface_override_material(0) is ShaderMaterial, "溪水没套卡通水材质")

	var marker := diorama.marker()
	assert(marker != null and String(marker.get_meta("stage_id", "")) == "grass_1", "关卡锚点缺失或 stage_id 不对")
	assert(marker.position.length() < 12.0, "锚点离小岛中心太远：%s" % str(marker.position))

	var camera := diorama.showcase_camera()
	assert(camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "展柜相机应为正交")
	assert(camera.position.y > 10.0, "相机应从上方俯拍")
	var forward := -camera.global_transform.basis.z
	assert(forward.y < -0.3, "相机没有朝下看")
	assert(diorama.get_node_or_null("KeyLight") is DirectionalLight3D, "缺少主光")
	assert(diorama.get_node_or_null("Table") is MeshInstance3D, "缺少台面")
	assert(diorama.get_node_or_null("TableShadow") is MeshInstance3D, "缺少台面接触阴影")

	await _check_entrance(diorama)

	diorama.queue_free()
	await process_frame
	print("Stage diorama grass_1: 模型 %d 组网格、溪水、锚点、相机、布光与入场动画全部通过" % meshes.size())
	quit()


## 顶点色里编的是入场基点：解码出来应该离顶点本身不远（道具都不大），离得远说明
## 导出/导入路上被当成颜色做了伽马转换或量化坏了。
func _check_entrance_pivots(meshes: Array[MeshInstance3D]) -> void:
	var pmin := Vector3(-16.0, -3.0, -12.0)
	var psize := Vector3(32.0, 10.0, 24.0)
	var checked := 0
	for mesh_node in meshes:
		if String(mesh_node.name).to_lower().begins_with("terrain"):
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			assert(colors.size() == verts.size(), "%s 没有带入场数据的顶点色" % mesh_node.name)
			var worst := 0.0
			for i in range(0, verts.size(), 7):
				var col := colors[i]
				var pivot := pmin + Vector3(col.r, col.g, col.b) * psize
				worst = maxf(worst, pivot.distance_to(verts[i]))
				assert(col.a >= 0.0 and col.a <= 1.0, "入场起跳时刻越界")
				checked += 1
			assert(worst < 6.5, "%s 的入场基点离顶点太远（%.1f），顶点色数据不对" % [mesh_node.name, worst])
	assert(checked > 100, "抽查的顶点太少：%d" % checked)


## 入场：进度从 0 推到 1，中途溪水低于水位、材质 build < 1；播完 build 回到 1、发信号。
func _check_entrance(diorama: StageDiorama) -> void:
	var done := [false]
	diorama.entrance_finished.connect(func() -> void: done[0] = true)
	var top_y := diorama.water().position.y
	diorama.play_entrance()
	assert(diorama.is_entrance_playing(), "play_entrance 之后应在播")
	assert(diorama.build_progress < 0.01, "入场开始时 build 应为 0")
	assert(diorama.water().position.y < top_y - 0.1, "入场开始时溪水应贴着河床")
	for _i in 12:
		await process_frame
	assert(diorama.build_progress > 0.0 and diorama.build_progress < 1.0, "入场中途 build 应在 0 与 1 之间：%f" % diorama.build_progress)
	var mid_build := float((diorama.model().get_child(0) as MeshInstance3D).get_active_material(0).get_shader_parameter("build")) if diorama.model().get_child(0) is MeshInstance3D else diorama.build_progress
	assert(mid_build < 1.0, "材质上的 build 没跟着进度走")
	var waited := 0.0
	while not done[0] and waited < 6.0:
		await process_frame
		waited += 1.0 / 60.0
	assert(done[0], "入场没有在时限内播完")
	assert(is_equal_approx(diorama.build_progress, 1.0), "播完 build 应为 1")
	assert(is_equal_approx(diorama.water().position.y, top_y), "播完溪水应回到水位")
	diorama.skip_entrance()
	assert(not diorama.is_entrance_playing(), "skip 之后不该还在播")


func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		found.append(node as MeshInstance3D)
	for child in node.get_children():
		found.append_array(_collect_meshes(child))
	return found
