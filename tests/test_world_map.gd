extends SceneTree
## 世界地图场景本体：池塘、原木落点、漂浮物、悬浮牌四态、整图框定、点击进关。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(55.0).timeout.connect(func() -> void:
		push_error("World map test timed out")
		quit(2)
	)
	var map := (load("res://scenes/world_map.tscn") as PackedScene).instantiate() as WorldMap
	assert(map != null, "world_map.tscn 的根节点不是 WorldMap")
	map.woodpecker_events = false
	map.heron_events = false
	map.kestrel_events = false
	map.redstart_events = false
	map.mosquito_events = false
	root.add_child(map)
	await process_frame

	_check_scene_wiring(map)
	await _check_drift_clouds(map)
	await _check_badge_states(map)
	await _check_camera(map)
	await _check_flora_hover(map)
	await _check_woodpecker_raid(map)
	await _check_heron_snatch(map)
	await _check_kestrel_raid(map)
	await _check_redstart_photo(map)
	await _check_click_without_drag(map)
	await _check_region_readout(map)
	await _check_mosquito(map)

	map.queue_free()
	await process_frame
	print("World map: %d 个关卡节点、四态悬浮牌、整图框定与点击进关全部通过" % map_marker_count)
	quit()


var map_marker_count := 0


## 场景与关卡表的挂接：每个 StageMarker 的 stage_id 都能查到、无重复，且表里每一关都在
## 场景里有节点。少一个关卡在地图上就是一个点不到的关。
func _check_scene_wiring(map: WorldMap) -> void:
	var markers := map.get_node("StageMarkers")
	assert(markers != null, "场景里没有 StageMarkers")
	assert(map.get_node_or_null("MapCamera") is Camera3D, "场景里没有 MapCamera")
	assert(map.get_node_or_null("HexTerrain") != null, "场景里没有 HexTerrain")
	assert(map.get_node_or_null("Ponds") != null, "俯视选关图应有卡通池塘 Ponds")
	assert((map.get_node("Ponds") as Node).get_child_count() >= 2, "池塘太少")
	assert(map.get_node_or_null("WaterSphere") == null, "不应再有 WaterSphere")

	var seen := {}
	for child in markers.get_children():
		var id := String(child.get_meta("stage_id", ""))
		assert(id != "", "关卡节点 %s 没有 stage_id 元数据" % child.name)
		assert(StageTable.has_stage(id), "场景里的 %s 在关卡表里查不到" % id)
		assert(not seen.has(id), "场景里有两个节点都挂着 %s" % id)
		seen[id] = true
	for stage in _map_stages():
		assert(seen.has(String(stage["id"])), "关卡表里的 %s 在地图上没有节点" % String(stage["id"]))
	map_marker_count = markers.get_child_count()
	assert(map.marker_count() == _map_stages().size(), "WorldMap 认领的关卡数与关卡表不符")

	# 关卡应按序号形成一条可读路径（前左 → 后右），相邻间距合理。
	var ordered: Array[Node3D] = []
	for stage in _map_stages():
		var sid := String(stage["id"])
		for child in markers.get_children():
			if String(child.get_meta("stage_id", "")) == sid:
				ordered.append(child as Node3D)
				break
	assert(ordered.size() == _map_stages().size(), "按序号收集关卡节点失败")
	var path := map.get_node_or_null("StagePath")
	assert(path != null, "缺少关卡行进路径 StagePath")
	assert(path.get_child_count() == _map_stages().size() - 1, "路径段数应为关卡数-1")
	for i in range(ordered.size() - 1):
		var a: Vector3 = ordered[i].global_position
		var b: Vector3 = ordered[i + 1].global_position
		var gap := a.distance_to(b)
		assert(gap >= 3.0 and gap < 16.0, "关卡 %d→%d 间距异常: %f" % [i + 1, i + 2, gap])
	assert(
		ordered[ordered.size() - 1].global_position.x > ordered[0].global_position.x + 2.0,
		"关卡路线没有形成从左到右的前进感"
	)

	var terrain := map.get_node("HexTerrain")
	var hex_floor := terrain.get_node_or_null("HexFloor")
	assert(hex_floor != null, "缺少六边地格 HexFloor")
	var hex_n := 0
	for child in hex_floor.get_children():
		var n := String(child.name)
		if n.begins_with("hex_") or n.begins_with("pad_"):
			hex_n += 1
	assert(hex_n >= 150, "六边地格没有铺满：%d" % hex_n)
	assert(terrain.get_node_or_null("PathScene") != null, "缺少 PathScene")
	var pads := 0
	for child in hex_floor.get_children():
		if String(child.name).begins_with("pad_"):
			pads += 1
	assert(pads >= 6, "关卡六边格太少：%d" % pads)
	for child in hex_floor.get_children():
		if not String(child.name).begins_with("pad_"):
			continue
		var built := false
		for prop in child.get_children():
			if String(prop.name).begins_with("building_"):
				built = true
				break
		assert(built, "关卡格 %s 上没有建筑" % child.name)
	assert(map.get_node_or_null("WorldMapUi/EdgeMist") != null, "缺少屏幕边缘卡通云雾")
	var grove := terrain.get_node_or_null("Grove")
	assert(grove != null and grove.get_child_count() >= 40, "林间植被太少")
	var tree_pos: Array[Vector3] = []
	for child in grove.get_children():
		var n := String(child.name)
		var is_tree := (
			n.begins_with("CommonTree") or n.begins_with("Pine_")
			or n.begins_with("TwistedTree") or n.begins_with("DeadTree")
		)
		if not is_tree:
			continue
		var p := (child as Node3D).position
		assert(
			(child as Node3D).scale.x <= 0.72,
			"树木缩放太大：%s %f" % [n, (child as Node3D).scale.x]
		)
		for other in tree_pos:
			var gap := Vector2(p.x - other.x, p.z - other.z).length()
			assert(gap >= 2.6, "树木间距过近会穿模：%f" % gap)
		tree_pos.append(p)
	assert(tree_pos.size() >= 10, "可种的树太少：%d" % tree_pos.size())
	# 陈列柜画风：奶油色平底，不用天空盒、不打雾、不泛光；光柱与深绿底板全部收掉。
	var env := (map.get_node("MapEnv") as WorldEnvironment).environment
	assert(env != null and env.background_mode == Environment.BG_COLOR, "应使用纯色台面背景")
	assert(env.background_color.is_equal_approx(WorldMap.BACKDROP), "台面底色应为奶油色")
	assert(not env.fog_enabled and not env.glow_enabled, "陈列柜画风不该有雾或泛光")
	var bed := map.get_node_or_null("SkyBed") as Node3D
	assert(bed == null or not bed.visible, "天空底面应收起")
	var rays := terrain.get_node_or_null("Atmosphere") as Node3D
	assert(rays == null or not rays.visible, "光柱/静态云应收起")
	var fill := terrain.get_node_or_null("GroundFill") as Node3D
	assert(fill == null or not fill.visible, "深绿底板应收起")
	for child in grove.get_children():
		assert(not String(child.name).begins_with("Grass_"), "草丛应整批收掉：%s" % child.name)
	var cam := map.get_node("MapCamera") as Camera3D
	map.present([], "", 0)
	await process_frame
	assert(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "选关图相机应为正交投影")
	assert(cam.size > 4.0, "正交尺寸没有随视距算出来：%f" % cam.size)
	# 体素地面：六边地格藏起来，方格地块铺出一块带缺口的矩形岛，关卡附近是石板。
	var voxels := map.get_node_or_null("VoxelFloor") as Node3D
	assert(voxels != null, "缺少体素地面 VoxelFloor")
	var cells := 0
	var cobble := 0
	for child in voxels.get_children():
		if not String(child.name).begins_with("Cell_"):
			continue
		cells += 1
		var kind := int(child.get_meta("voxel_kind", -1))
		if kind == WorldMap.VoxelKind.COBBLE or kind == WorldMap.VoxelKind.SOIL or kind == WorldMap.VoxelKind.PLANK:
			cobble += 1
	assert(cells >= 200, "体素地块太少：%d" % cells)
	assert(cobble >= 30, "关卡广场（石板/田土/木板）与石板路太少：%d" % cobble)
	assert(voxels.get_node_or_null("VoxelWater") is MeshInstance3D, "体素地面缺少水面")
	# 每关一副布景：广场旁有配楼/道具，且至少出现田土与木板两种主题地面。
	var dressing := voxels.get_node_or_null("Dressing") as Node3D
	assert(dressing != null and dressing.get_child_count() >= 10, "关卡布景道具太少")
	var kinds := {}
	for child in voxels.get_children():
		if String(child.name).begins_with("Cell_"):
			kinds[int(child.get_meta("voxel_kind", -1))] = true
	assert(kinds.has(WorldMap.VoxelKind.SOIL) and kinds.has(WorldMap.VoxelKind.PLANK), "主题地面（田土/木板）没有铺出来")
	for child in hex_floor.get_children():
		if String(child.name).begins_with("hex_"):
			assert(not (child as Node3D).visible, "六边地格应藏起来：%s" % child.name)
	for tile in map.all_tiles():
		var lifted: Array[Node3D] = map._hover_lift_targets(tile)
		var has_cell := false
		for node in lifted:
			if String(node.name).begins_with("Cell_"):
				has_cell = true
				break
		assert(has_cell, "关卡格 %s 悬停时没有带动脚下的体素地块" % tile.name)


func _check_drift_clouds(map: WorldMap) -> void:
	map.present([], "", 0)
	await process_frame
	var host := map.get_node_or_null("DriftClouds")
	assert(host != null, "缺少飘云层 DriftClouds")
	assert(host.get_child_count() >= 4, "飘云太少：%d" % host.get_child_count())
	for child in host.get_children():
		var caster := child.get_node_or_null("CloudShadow") as MeshInstance3D
		assert(caster != null, "云 %s 没有投影体" % child.name)
		assert(
			caster.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
			"云投影体应只投影、自己不可见：%s" % child.name
		)
		assert(child.position.y > 5.0, "云飞得太低会扎进树冠：%s" % child.name)
		assert((child as Node3D).scale.x <= 0.85, "云还是太大：%s %f" % [child.name, (child as Node3D).scale.x])
		var puffs := 0
		for sub in child.get_children():
			if String(sub.name).begins_with("Puff_"):
				puffs += 1
		assert(puffs >= 3, "云 %s 不是卡通圆球团：%d" % [child.name, puffs])
	var pond := map.get_node("Ponds").get_child(0) as MeshInstance3D
	var mat := pond.get_surface_override_material(0) as ShaderMaterial
	assert(mat != null, "池塘没有水面材质")
	map.set_process(true)
	var first := host.get_child(0) as Node3D
	var start := first.position
	await map.get_tree().create_timer(0.25).timeout
	assert(first.position.distance_to(start) > 0.02, "云没有在飘")
	assert(int(mat.get_shader_parameter("cloud_shadow_count")) >= 1, "水面没收到云影参数")


func _check_badge_states(map: WorldMap) -> void:
	var stages := StageTable.STAGES
	var cleared_id := String(stages[0]["id"])
	var resume_id := String(stages[1]["id"])
	var locked_id := String(stages[2]["id"])

	map.present([cleared_id], resume_id, 3)
	await process_frame

	var cleared_badge := map.badge_for(cleared_id)
	var resume_badge := map.badge_for(resume_id)
	var locked_badge := map.badge_for(locked_id)
	assert(cleared_badge != null and locked_badge != null, "悬浮牌没有铺满全部关卡")

	assert(cleared_badge.current_state() == StageBadge.State.CLEARED, "已通关的关卡没显示为已通关")
	assert(resume_badge.current_state() == StageBadge.State.IN_PROGRESS, "续局中的关卡没显示为进行中")
	assert(locked_badge.current_state() == StageBadge.State.LOCKED, "未通前一关时下一关居然解锁了")
	assert(locked_badge.disabled, "未解锁的悬浮牌没有 disabled")

	# 无续局时，已解锁的下一关应显示可挑战。
	map.present([cleared_id], "", 0)
	await process_frame
	var open_badge := map.badge_for(resume_id)
	assert(open_badge.current_state() == StageBadge.State.AVAILABLE, "已解锁未打的关卡状态不对")
	assert(not open_badge.disabled, "可挑战的悬浮牌被禁用了")

	var words := {}
	for state in [
		StageBadge.State.CLEARED, StageBadge.State.AVAILABLE,
		StageBadge.State.LOCKED, StageBadge.State.IN_PROGRESS,
	]:
		var word := String(StageBadge.STATE_WORDS[state])
		assert(not words.has(word), "两个状态共用了同一个词: %s" % word)
		words[word] = true
	var stage := StageTable.stage(resume_id)
	var name_label := open_badge.get_node("BadgeNameLabel") as Label
	var round_label := open_badge.get_node("BadgeRoundLabel") as Label
	assert(
		name_label.text == "%d · %s" % [int(stage["order"]), String(stage["name"])],
		"悬浮牌上的序号或名字不对: %s" % name_label.text
	)
	assert(
		round_label.text == "%d 盘" % int(stage["target_round"]),
		"悬浮牌上的目标盘数不对: %s" % round_label.text
	)

	# 有续局槽时点别的已解锁关：应弹确认。
	map.present([cleared_id], resume_id, 3)
	await process_frame
	# 先把第二关也标成已通，让第三关临时可点，用来测确认卡；测完再还原语义。
	# 更简单：点已通关的牌子不会进；点锁定的不能进。用「无续局点可挑战关」。
	var entered: Array = []
	map.stage_selected.connect(func(id: String) -> void: entered.append(id))

	map.present([cleared_id], "", 0)
	await process_frame
	map.badge_for(resume_id).pressed.emit()
	await process_frame
	assert(entered == [resume_id], "无续局槽时点关卡没有直接进入")

	entered.clear()
	map.badge_for(locked_id).pressed.emit()
	await process_frame
	assert(entered.is_empty(), "未解锁的关卡被点进去了")

	# 有续局时点另一已解锁关（需要第三关已开）：通两关后第四关仍锁，第三关可点。
	entered.clear()
	map.present([cleared_id, resume_id], resume_id, 1)
	await process_frame
	var open_id := String(stages[2]["id"])
	map.badge_for(open_id).pressed.emit()
	await process_frame
	assert(entered.is_empty(), "有续局槽时点别的关卡直接进去了，没弹确认")
	var confirm := map.get_node("WorldMapUi/AbandonConfirm") as Control
	assert(confirm.visible, "放弃确认卡没有弹出")
	var abandoned := [false]
	map.abandon_requested.connect(func() -> void: abandoned[0] = true)
	(confirm.get_node("ConfirmPanel/ConfirmYesButton") as Button).pressed.emit()
	await process_frame
	assert(abandoned[0], "确认放弃后没有发出 abandon_requested")
	assert(entered == [open_id], "确认放弃后没有进入刚点的那一关")


func _check_camera(map: WorldMap) -> void:
	map.present([], "", 0)
	await process_frame
	var camera := map.get_node("MapCamera") as Camera3D
	var pivot := map.camera_pivot()
	var bounds: Rect2 = map._map_bounds
	var center := bounds.get_center()

	# 第一屏对准整张地图中心，视距足以框住地格。
	assert(
		is_equal_approx(pivot.x, center.x) and is_equal_approx(pivot.z, center.y),
		"镜头中心不在地图包围盒中心：%s vs %s" % [pivot, center]
	)
	assert(map.camera_distance() > 8.0, "整图框定视距过近：%f" % map.camera_distance())
	assert(map.camera_distance() < 48.0, "关卡框定视距过远：%f" % map.camera_distance())
	assert(camera.position.y > pivot.y, "相机没有在地面之上")
	assert(
		is_equal_approx(rad_to_deg(camera.rotation.x), WorldMap.CAMERA_PITCH_DEG),
		"相机俯角被改掉了"
	)

	# 每块地格都必须有碰撞体 + 外描边。
	assert(map.tile_count() == _map_stages().size(), "原木落点数应等于关卡数：%d" % map.tile_count())
	var pick_count := 0
	for tile in map.all_tiles():
		assert(tile.get_node_or_null("TileOutline") != null, "地格 %s 缺少外描边" % tile.name)
		var pick := tile.get_node_or_null("TilePick") as StaticBody3D
		assert(pick != null, "地格 %s 缺少 TilePick 碰撞" % tile.name)
		assert(pick.collision_layer == WorldMap.TILE_PICK_COLLISION_LAYER, "地格 %s 碰撞层不对" % tile.name)
		assert(pick.get_child_count() >= 1, "地格 %s 的 TilePick 没有 CollisionShape" % tile.name)
		pick_count += 1
	assert(pick_count == map.tile_count(), "碰撞体数量 (%d) 与地格数 (%d) 不一致" % [pick_count, map.tile_count()])

	# 每个关卡都应绑到一格地格。
	for stage in _map_stages():
		var stage_id := String(stage["id"])
		var tile := map.bound_tile_for(stage_id)
		assert(tile != null, "关卡 %s 没有绑定地格" % stage_id)
		assert(String(tile.get_meta("stage_id", "")) == stage_id, "地格 meta 未写回 stage_id")
		var outline := map.outline_for(stage_id)
		assert(outline != null, "关卡 %s 缺少外描边" % stage_id)
		assert(not outline.visible, "初始外描边不应显示")

	# 等物理同步后再射线拾取；反复 3 轮确认不是一次性。
	map.set_process(false)
	await map.get_tree().physics_frame
	await map.get_tree().physics_frame
	var cam := map.get_node("MapCamera") as Camera3D
	cam.make_current()
	var plain: Node3D = null
	var on_screen := Vector2.ZERO
	for tile in map.all_tiles():
		if cam.is_position_behind(tile.global_position):
			continue
		var screen := cam.unproject_position(
			tile.global_position + Vector3(0.0, 0.35, 0.0)
		)
		var hit: Node3D = map._raycast_tile(screen)
		if hit != null:
			plain = hit
			on_screen = screen
			break
	assert(plain != null, "找不到镜头能打中的地格做悬停测试")
	var off_screen := Vector2(-2000.0, -2000.0)
	var outline_node := plain.get_node("TileOutline") as MeshInstance3D
	var base_y := outline_node.position.y

	# 射线必须能打到该格的 TilePick。
	var ray_hit := map._raycast_tile(on_screen)
	assert(ray_hit == plain, "物理射线没有打中目标地格，打到了 %s" % ray_hit)

	for cycle in 3:
		map._refresh_hover_at(on_screen)
		await map.get_tree().create_timer(0.18).timeout
		assert(outline_node.visible, "第 %d 次悬停没有外描边" % (cycle + 1))
		assert(outline_node.position.y > base_y + 0.05, "第 %d 次悬停没有上浮" % (cycle + 1))
		assert(is_zero_approx(plain.get_node("TilePick").position.y), "TilePick 不应随悬停上浮")
		map._refresh_hover_at(off_screen)
		await map.get_tree().create_timer(0.18).timeout
		assert(not outline_node.visible, "第 %d 次离开后外描边仍在" % (cycle + 1))

	map.set_process(true)

	map.set_process(false)
	var first_id := String(StageTable.STAGES[0]["id"])
	map._on_stage_hover(first_id, true)
	await process_frame
	assert(map.badge_for(first_id).is_hovering(), "悬停后牌子没有进入放大态")
	assert(map.outline_for(first_id).visible, "悬停后地格外描边没有显示")
	map._on_stage_hover(first_id, false)
	await process_frame
	assert(not map.outline_for(first_id).visible, "离开悬停后外描边应关掉")
	map.set_process(true)

	# 拖拽 / 滚轮不应再改镜头。
	var locked_pivot := map.camera_pivot()
	var locked_distance := map.camera_distance()
	assert(map.camera_pivot() == locked_pivot, "整图框定后镜头中心应保持不动")
	assert(is_equal_approx(map.camera_distance(), locked_distance), "整图框定后视距应保持不动")
	# 陈列柜视角：比正俯视侧一些，方块侧面与建筑立面读得出来，又不至于让牌子叠成一排。
	assert(
		absf(WorldMap.CAMERA_PITCH_DEG) >= 38.0 and absf(WorldMap.CAMERA_PITCH_DEG) <= 56.0,
		"体素选关图俯角应在 38–56 度：%f" % WorldMap.CAMERA_PITCH_DEG
	)
	assert(
		absf(WorldMap.CAMERA_YAW_DEG) >= 8.0 and absf(WorldMap.CAMERA_YAW_DEG) <= 30.0,
		"体素选关图应斜一个角看（8–30 度）：%f" % WorldMap.CAMERA_YAW_DEG
	)


func _check_flora_hover(map: WorldMap) -> void:
	map.present([], "", 0)
	await process_frame
	var plants := map.flora_props()
	assert(plants.size() >= 20, "可悬停的植被太少：%d" % plants.size())
	var tree: Node3D = null
	var shrub: Node3D = null
	for node in plants:
		assert(node.get_node_or_null("FloraPick") is StaticBody3D, "%s 缺少 FloraPick" % node.name)
		var pick := node.get_node("FloraPick") as StaticBody3D
		assert(pick.collision_layer == WorldMap.FLORA_PICK_COLLISION_LAYER, "%s 植被碰撞层不对" % node.name)
		if map._is_flora_tree(node):
			tree = node
		elif shrub == null:
			shrub = node
			assert(node.scale.x <= 0.80, "植被缩放太大：%s %f" % [node.name, node.scale.x])
	assert(tree != null and shrub != null, "既要有树也要有矮植被才能测悬停")

	var notes := map.get_node_or_null("WorldMapUi/MusicNotes") as Control
	assert(notes != null, "缺少音符层 MusicNotes")
	var voice := map.get_node_or_null("FloraBirdCall") as AudioStreamPlayer
	assert(voice != null, "缺少植被鸟鸣播放器")

	var shake_n := 0
	for _i in 200:
		if map._roll_flora_kind() == WorldMap.FLORA_KIND_SHAKE:
			shake_n += 1
	assert(shake_n >= 150, "悬停应大多只抖一下，实际抖动 %d/200" % shake_n)

	var base_rot := tree.rotation
	map.play_flora_react(tree, WorldMap.FLORA_KIND_SHAKE)
	await map.get_tree().create_timer(0.12).timeout
	assert(not tree.rotation.is_equal_approx(base_rot), "抖动没有转动树木")

	map.play_flora_react(tree, WorldMap.FLORA_KIND_SONG)
	await process_frame
	assert(notes.get_child_count() > 0, "唱歌没有炸出音符")
	assert(voice.playing, "唱歌没有播放鸟鸣")

	var crumbs := map.get_node_or_null("Breadcrumbs")
	assert(crumbs != null, "缺少面包屑根节点")
	var loaf_before := 0
	for child in crumbs.get_children():
		if String(child.get_meta("food_kind", "")) == "loaf":
			loaf_before += 1
	map.play_flora_react(tree, WorldMap.FLORA_KIND_BREAD)
	await process_frame
	var loaf_after := 0
	for child in crumbs.get_children():
		if String(child.get_meta("food_kind", "")) == "loaf":
			loaf_after += 1
	assert(loaf_after == loaf_before + 1, "悬停掉面包没有生成面包")

	map.set_process(false)
	await map.get_tree().physics_frame
	await map.get_tree().physics_frame
	var cam := map.get_node("MapCamera") as Camera3D
	cam.make_current()
	map._refresh_flora_at(Vector2(-2000.0, -2000.0))
	assert(map.hovered_flora() == null, "指针离开后仍记着植被")
	var on_screen: Node3D = null
	for node in plants:
		if map._is_flora_tree(node):
			continue
		if cam.is_position_behind(node.global_position):
			continue
		on_screen = node
		break
	assert(on_screen != null, "镜头里找不到可悬停的植被")
	var screen := cam.unproject_position(on_screen.global_position + Vector3(0.0, 0.28, 0.0))
	map._refresh_flora_at(screen)
	assert(map.hovered_flora() != null, "指针移到植被上没有触发悬停")
	map._refresh_flora_at(Vector2(-2000.0, -2000.0))
	map.set_process(true)


func _check_woodpecker_raid(map: WorldMap) -> void:
	map.present([], "", 0)
	await process_frame
	assert(map.get_node_or_null("Woodpecker") is Node3D, "缺少啄木鸟节点")
	assert(map.get_node_or_null("WoodpeckerPeck") is AudioStreamPlayer, "缺少啄木鸟音效")
	var card := map.get_node_or_null("Woodpecker/Card") as MeshInstance3D
	assert(card != null, "缺少啄木鸟立体面片")
	assert(card.mesh is QuadMesh, "啄木鸟应是 Quad 面片而不是广告牌")
	assert((card.mesh as QuadMesh).size.x >= 1.0, "啄木鸟面片太小，岛上看不见")
	assert(
		(card.material_override as StandardMaterial3D).billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED,
		"啄木鸟面片不该跟着镜头转"
	)
	assert(is_equal_approx(WorldMap.WOODPECKER_LAY_PITCH_DEG, -90.0), "啄木鸟面片应平放 90 度")
	assert(WorldMap.WOODPECKER_PECK_STEP > 0.1, "啄击高度应逐步下降")
	assert(WorldMap.WOODPECKER_FIRST_WAIT.y <= 5.0, "进图后第一次等太久")
	var trees := map.standing_trees()
	assert(trees.size() >= 1, "没有可啄的树")
	var tree := trees[0]
	map._burst_peck_text(tree.global_position + Vector3(0.0, 1.2, 0.0))
	map._burst_wood_chips(tree.global_position + Vector3(0.0, 1.2, 0.0))
	var fx := map.get_node("WoodpeckerFx")
	var texts := 0
	var chips := 0
	for child in fx.get_children():
		if child is Label3D:
			texts += 1
		elif child is MeshInstance3D:
			chips += 1
	assert(texts >= WorldMap.WOODPECKER_TEXT_COUNT, "啄击没有文字粒子")
	assert(chips >= WorldMap.WOODPECKER_CHIP_COUNT, "啄击没有木屑粒子")
	var rest_scale := tree.scale
	await map.play_woodpecker_raid(tree, 30.0)
	assert(bool(tree.get_meta("felled", false)), "啄木鸟没有把树标记为倒下")
	assert(not tree.visible, "倒下的树应该先消失")
	await map.regrow_tree(tree)
	assert(not bool(tree.get_meta("felled", false)), "树没有重新长回来")
	assert(tree.visible, "长回来的树应该看得见")
	assert(tree.scale.distance_to(rest_scale) < 0.08, "长回后缩放不对")


func _check_heron_snatch(map: WorldMap) -> void:
	map.present([], "", 0)
	await process_frame
	assert(map.get_node_or_null("NightHeron") is Node3D, "缺少夜鹭节点")
	assert(map.get_node_or_null("HeronCall") is AudioStreamPlayer, "缺少夜鹭叫声")
	var pond := map.pond_point()
	assert(map.is_in_water(pond), "池塘采样点不在水里")
	map._burst_heron_croaks(pond + Vector3(0.0, 0.2, 0.0))
	var fx := map.get_node_or_null("HeronFx")
	assert(fx != null, "缺少呱粒子层")
	assert(fx.get_parent() == map, "呱粒子应在世界坐标，不能继承夜鹭速度")
	var croaks := 0
	for child in fx.get_children():
		if child is Label3D and String((child as Label3D).text).begins_with("呱"):
			croaks += 1
	assert(croaks >= WorldMap.HERON_CROAK_COUNT, "夜鹭没有弹出呱粒子")
	map._spawn_loaf_at(pond, true)
	await map.get_tree().create_timer(WorldMap.LOAF_SETTLE_TIME + 0.05).timeout
	var loaf: Node3D = null
	var crumbs := map.get_node("Breadcrumbs")
	for child in crumbs.get_children():
		if String(child.get_meta("food_kind", "")) == "loaf":
			loaf = child as Node3D
			break
	assert(loaf != null, "水里没有落下面包")
	assert(bool(loaf.get_meta("in_water", false)), "落水面包没有标记 in_water")
	await map.play_heron_snatch(loaf)
	assert(not is_instance_valid(loaf) or loaf.is_queued_for_deletion(), "夜鹭没有把面包叼走")
	assert(map._map_loaves_eaten == 1, "夜鹭吃面包没有记账")
	var eggs: Array = []
	map.easter_egg_triggered.connect(func(id: String) -> void: eggs.append(id))
	for _i in 4:
		map._register_loaf_eaten()
	assert(eggs.has(AchievementCatalog.MAP_HERON_BREAD), "吃满五块面包应解锁「我的了！」")


func _check_kestrel_raid(map: WorldMap) -> void:
	map.present([], "", 0)
	await process_frame
	assert(map.get_node_or_null("Kestrel") is Node3D, "缺少红隼节点")
	assert(map.get_node_or_null("KestrelCall") is AudioStreamPlayer, "缺少红隼叫声")
	var fx := map.get_node_or_null("KestrelFx")
	assert(fx != null, "缺少咕粒子层")
	assert(fx.get_parent() == map, "咕粒子应在世界坐标，不能继承红隼速度")
	map._burst_kestrel_coos(Vector3(0.0, 0.4, 0.0))
	var coos := 0
	for child in fx.get_children():
		if child is Label3D and String((child as Label3D).text).begins_with("咕"):
			coos += 1
	assert(coos >= WorldMap.KESTREL_COO_COUNT, "红隼没有弹出咕粒子")
	var pigeons := map.standing_pigeons()
	assert(pigeons.size() >= 1, "没有可叼的跳跳鸽")
	var pigeon := pigeons[0]
	await map.play_kestrel_raid(pigeon, 30.0)
	assert(bool(pigeon.get_meta("snatched", false)) or not pigeon.visible, "红隼没有把鸽子叼走")
	map._return_pigeon(pigeon, true)
	assert(pigeon.visible, "鸽子没有放回来")
	assert(not bool(pigeon.get_meta("snatched", false)), "放回后仍记着被叼走")


func _check_redstart_photo(map: WorldMap) -> void:
	map.present([], "", 0)
	await process_frame
	assert(map.get_node_or_null("Redstart") is Node3D, "缺少红尾水鸲节点")
	assert(map.get_node_or_null("RedstartCall") is AudioStreamPlayer, "缺少红尾水鸲叫声")
	var sprite := map.get_node_or_null("Redstart/Sprite") as Sprite3D
	assert(sprite != null, "缺少红尾水鸲立绘")
	assert(
		String(sprite.texture.resource_path).contains("red_"),
		"拍照主体应是红尾水鸲立绘，不是水渠漫画"
	)
	var polaroid := map.get_node_or_null("WorldMapUi/PhotoLayer/Polaroid") as PanelContainer
	assert(polaroid != null, "缺少相框 Polaroid")
	assert(polaroid.get_node_or_null("Image") is TextureRect, "相框里没有照片层")
	var viewfinder := map.get_node_or_null("WorldMapUi/PhotoLayer/Viewfinder") as Control
	assert(viewfinder != null, "缺少相机镜头取景 Viewfinder")
	assert(viewfinder.get_class() != "Panel", "取景应是圆形镜头，不是矩形相框")
	var qte := map.get_node_or_null("WorldMapUi/PhotoLayer/FocusQte") as Control
	assert(qte != null, "缺少对焦滑动槽 FocusQte")
	var grade := map.get_node_or_null("WorldMapUi/PhotoLayer/FocusGrade") as Label
	assert(grade != null, "缺少对焦等级 FocusGrade")
	assert(is_equal_approx(map._focus_quality_from_slider(WorldMap.REDSTART_QTE_SWEET), 1.0), "甜区应对最实")
	assert(map._focus_quality_from_slider(0.0) < 0.05, "槽头应对最低档")
	assert(map.focus_grade_text(0.0) == "失焦", "不点应对失焦")
	assert(map.focus_grade_text(1.0) == "Get Daze！", "甜区应对 Get Daze！")
	assert(not map.is_successful_focus(0.0), "最低档不算成功对焦")
	assert(map.is_successful_focus(1.0), "满档应对成功对焦")
	await map.play_redstart_photo(0.08, 0.0)
	assert(not map.get_node("Redstart").visible, "拍完后红尾水鸲应飞走")
	assert(not polaroid.visible, "拍完后相框应收走")
	assert(not viewfinder.visible, "拍完后取景框应收走")
	assert(not qte.visible, "拍完后对焦槽应收走")
	assert(not grade.visible, "拍完后对焦等级应收走")
	assert(is_zero_approx(map._shot_yaw_off) and is_zero_approx(map._shot_pitch_off), "镜头没有转回框定")
	assert(map._shot_dist < 0.0, "视距没有拉回整图框定")
	assert(map._shot_look_off.is_zero_approx(), "注视点没有回到岛心")
	var cam := map.get_node("MapCamera") as Camera3D
	assert(
		absf(cam.global_position.distance_to(map.camera_pivot()) - map.camera_distance()) < 0.25,
		"相机没有退回整图框定距离"
	)
	assert(polaroid.get_node("Image").texture != null, "相框没有装上照片")


## 点悬浮牌或绑定地格都应进关。
func _check_click_without_drag(map: WorldMap) -> void:
	map.present([], "", 0)
	await process_frame
	var stage_id := String(StageTable.STAGES[0]["id"])
	var entered: Array = []
	map.stage_selected.connect(func(id: String) -> void: entered.append(id))
	map.badge_for(stage_id).pressed.emit()
	await process_frame
	assert(entered == [stage_id], "点击悬浮牌没有进关")

	entered.clear()
	map.set_process(false)
	await map.get_tree().physics_frame
	var tile := map.bound_tile_for(stage_id)
	assert(tile != null, "第一关没有绑定地格")
	var cam := map.get_node("MapCamera") as Camera3D
	cam.make_current()
	var screen := Vector2.ZERO
	var found_hit := false
	for candidate in map.all_tiles():
		if String(candidate.get_meta("stage_id", "")) != stage_id:
			continue
		if cam.is_position_behind(candidate.global_position):
			continue
		var at := cam.unproject_position(
			candidate.global_position + Vector3(0.0, 0.35, 0.0)
		)
		var hit: Node3D = map._raycast_tile(at)
		if hit != null and String(hit.get_meta("stage_id", "")) == stage_id:
			screen = at
			found_hit = true
			break
	assert(found_hit, "第一关地格没有可点的屏幕位置")
	assert(map._try_select_tile_at(screen), "点击关卡地格应当能选关")
	await process_frame
	assert(entered == [stage_id], "点击地格没有进关")
	map.set_process(true)


func _check_region_readout(map: WorldMap) -> void:
	map.present([], "", 0)
	await process_frame
	var name_label := map.get_node("WorldMapUi/TopBar/RegionNameLabel") as Label
	var progress_label := map.get_node("WorldMapUi/TopBar/RegionProgressLabel") as Label
	var region_name := String(StageTable.REGIONS[0]["name"])
	assert(
		name_label.text.begins_with(region_name),
		"初次显示时顶栏没报出栖息地，而是「%s」" % name_label.text
	)
	assert(progress_label.text.contains("已通关"), "顶栏没有进度文字: %s" % progress_label.text)
	assert(not progress_label.text.contains("开启"), "单区地图不应再提示开启下一区: %s" % progress_label.text)

	# 局外数值位本期只占位不填数（共识 5）。
	var meta_value := map.get_node("WorldMapUi/TopBar/MetaCurrencyBox/MetaValueLabel") as Label
	assert(meta_value.text == "— —", "局外数值位本期不该填真数字: %s" % meta_value.text)

	var all_btn := map.get_node("WorldMapUi/TopBar/AllLeaderboardsButton") as Button
	assert(all_btn != null, "顶栏没有全部排行榜按钮")
	var opened: Array = []
	map.all_leaderboards_requested.connect(func() -> void: opened.append(true))
	all_btn.pressed.emit()
	assert(not opened.is_empty(), "点全部排行榜没有发出信号")

	var last_id := String(_map_stages()[_map_stages().size() - 1]["id"])
	assert(
		map.badge_for(last_id).current_state() == StageBadge.State.LOCKED,
		"空存档下末关应当仍锁定"
	)


## 蚊子挂在 UI 层里、不吃鼠标；present 时飞进来，dismiss 时停掉。飞行与拍死细节见 test_map_mosquito。
func _check_mosquito(map: WorldMap) -> void:
	var bug := map.get_node_or_null("WorldMapUi/Mosquito") as MapMosquito
	assert(bug != null, "UI 层里没有 Mosquito")
	assert(map.mosquito() == bug, "mosquito() 没返回 UI 层里的那只")
	assert(bug.mouse_filter == Control.MOUSE_FILTER_IGNORE, "蚊子层会挡住地图点击")
	map.mosquito_events = true
	map.present([], "", 0)
	await process_frame
	bug.spawn_now()
	await process_frame
	assert(bug.is_flying(), "present 之后蚊子没在飞")
	map.dismiss()
	assert(not bug.is_flying(), "dismiss 之后蚊子还在飞")
	map.mosquito_events = false


## 老地图上有节点的关：关卡表去掉无尽关（第 7 关只在陈列柜里，老壳层没给它摆地格）。
func _map_stages() -> Array:
	var out: Array = []
	for stage in StageTable.STAGES:
		if not bool(stage.get("endless", false)):
			out.append(stage)
	return out
