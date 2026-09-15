extends SceneTree
## 六关展品都要是真展品：模型有地形/建筑/树/道具几组、锚点在岛上、桌布配色各自不同且
## 相邻两关差得开、有水的关卡水面与水色齐全、入场着色器接上、手绘地面连 UV 进了引擎。
## 无头跑，模型可直读 .glb。

const STAGES := ["grass_1", "grass_2", "grass_3", "river_1", "river_2", "coast_1"]
## 有水的关卡与它们的水面层数。
const WATER_LAYERS := {"grass_1": 1, "river_1": 1, "river_2": 2, "coast_1": 1}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("Stage dioramas test timed out")
		quit(2)
	)
	var palettes: Array = []
	for id in STAGES:
		var paths := StageDiorama.paths_for(id)
		assert(bool(paths["real"]), "%s 还是泥胚占位，没有真展品" % id)
		var packed := load("res://scenes/dioramas/%s.tscn" % id) as PackedScene
		assert(packed != null, "缺少 scenes/dioramas/%s.tscn" % id)
		var diorama := packed.instantiate() as StageDiorama
		diorama.entrance_on_ready = false
		root.add_child(diorama)
		await process_frame
		assert(not diorama.is_placeholder(), "%s 场景指向了占位模型" % id)
		var names := {}
		var painted_ground := false
		for mesh_node in _collect_meshes(diorama.model()):
			names[String(mesh_node.name).to_lower().rstrip("0123456789")] = true
			for surface in mesh_node.mesh.get_surface_count():
				assert((mesh_node.get_active_material(surface) as ShaderMaterial) != null, "%s/%s 没换成入场材质" % [id, mesh_node.name])
				# 地形顶面的手绘地面（石板、沙滩、麦垄）要连着 UV 一起进引擎，否则只剩一片底色。
				var source := mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D
				if source != null and source.albedo_texture != null:
					var uvs: Variant = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV]
					assert(uvs != null and (uvs as PackedVector2Array).size() > 0, "%s/%s 带贴图的面没有 UV" % [id, mesh_node.name])
					painted_ground = true
		assert(painted_ground, "%s 没有一个面带手绘地面贴图" % id)
		for expected in ["terrain", "buildings", "trees", "props"]:
			var found := false
			for key in names.keys():
				if String(key).begins_with(expected):
					found = true
			assert(found, "%s 缺少 %s 组" % [id, expected])
		var marker := diorama.marker()
		assert(String(marker.get_meta("stage_id", "")) == id, "%s 的锚点 stage_id 不对" % id)
		var fp := diorama.footprint()
		assert(absf(marker.position.x) < fp.x * 0.5 and absf(marker.position.z) < fp.y * 0.5, "%s 的锚点在岛外" % id)
		var layers := int(WATER_LAYERS.get(id, 0))
		var found_layers := 0
		for child in diorama.get_children():
			if String(child.name).begins_with("Water"):
				found_layers += 1
		assert(found_layers == layers, "%s 水面层数应为 %d，实际 %d" % [id, layers, found_layers])
		if layers > 0:
			var mat := diorama.water().get_surface_override_material(0) as ShaderMaterial
			assert(mat != null, "%s 的水没套卡通水材质" % id)
			var colors := diorama.water_colors()
			var shallow: Color = mat.get_shader_parameter("depth_gradient_shallow")
			assert(shallow.is_equal_approx(colors["shallow"]), "%s 的水色没按 JSON 走" % id)
		var palette := diorama.table_palette()
		assert(diorama.layout().has("table"), "%s 的布局里没有桌布配色" % id)
		palettes.append(palette)
		# 常态微动：道具组的顶点带第二套 UV（运动种类 + 相位），着色器靠它让树摇、鸟动、船晃。
		var moving := false
		for mesh_node in _collect_meshes(diorama.model()):
			if String(mesh_node.name).to_lower().begins_with("terrain"):
				continue
			var uv2: Variant = mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
			if uv2 != null and (uv2 as PackedVector2Array).size() > 0:
				for v in (uv2 as PackedVector2Array):
					if v.x > 1.0 / 32.0:
						moving = true
						break
			if moving:
				break
		assert(moving, "%s 没有任何带运动编码的道具" % id)
		assert(not diorama.is_withered(), "%s 生机版不该带 withered 标记" % id)
		var clouds := diorama.get_node_or_null("Clouds")
		assert(clouds != null and clouds.get_child_count() == diorama.cloud_count, "%s 上空该有 %d 朵云" % [id, diorama.cloud_count])
		assert(clouds.get_child(0).get_node_or_null("CloudShadow") != null, "%s 的云没有投影体" % id)
		diorama.queue_free()
		await process_frame
		# 荒废态：同一布局的第二版模型，标记 withered，桌布更灰。
		var wp := StageDiorama.paths_for(id, true)
		assert(bool(wp["withered"]), "%s 缺少荒废版（_withered.glb/.json）" % id)
		var dead := packed.instantiate() as StageDiorama
		dead.entrance_on_ready = false
		dead.withered = true
		root.add_child(dead)
		await process_frame
		assert(dead.is_withered(), "%s 的荒废版布局没有 withered 标记" % id)
		assert(dead.model_path.ends_with("_withered.glb"), "%s 荒废版没读 _withered.glb" % id)
		assert(_palette_distance(palette, dead.table_palette()) > 0.02, "%s 荒废版的桌布应明显更灰" % id)
		dead.set_withered(false, false)
		assert(not dead.is_withered() and not dead.model_path.ends_with("_withered.glb"), "%s 换回生机版失败" % id)
		dead.queue_free()
		await process_frame
	# 配色差异化：相邻两关的桌布底色 + 点色合起来要差得开，六关两两也不能撞色。
	for i in range(palettes.size()):
		for j in range(i + 1, palettes.size()):
			var d := _palette_distance(palettes[i], palettes[j])
			assert(d > 0.05, "%s 与 %s 的桌布配色太像（%.3f）" % [STAGES[i], STAGES[j], d])
	for i in range(palettes.size() - 1):
		var d := _palette_distance(palettes[i], palettes[i + 1])
		assert(d > 0.07, "相邻的 %s 与 %s 配色差异不够（%.3f）" % [STAGES[i], STAGES[i + 1], d])
	print("Stage dioramas: 六关真展品、荒废版、微动编码、云、水面、锚点与差异化配色全部通过")
	quit()


func _palette_distance(a: Dictionary, b: Dictionary) -> float:
	var total := _color_distance(a["far"], b["far"]) + _color_distance(a["near"], b["near"])
	for i in 3:
		total += _color_distance(a["dots"][i], b["dots"][i])
	return total / 5.0


func _color_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		found.append(node as MeshInstance3D)
	for child in node.get_children():
		found.append_array(_collect_meshes(child))
	return found
