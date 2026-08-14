extends Control

const BoardModel := preload("res://scripts/game/minesweeper_board.gd")
const CellView := preload("res://scripts/ui/mine_cell.gd")

const BOARD_WIDTH := 10
const BOARD_HEIGHT := 8
const MINE_COUNT := 12
const LANTERN_COUNT := 3
const COMPASS_COUNT := 3
const CELL_SIZE := 100.0

const COLOR_BG := Color("172119")
const COLOR_PANEL := Color("283522")
const COLOR_PANEL_DARK := Color("1c281b")
const COLOR_INK := Color("f4e8c1")
const COLOR_MUTED := Color("b7bf95")
const COLOR_ACCENT := Color("f2bd4c")
const COLOR_DANGER := Color("e65a45")
const COLOR_SUCCESS := Color("8fd15b")

const COVERED_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/generated/tile_grass_dense.png"),
	preload("res://assets/sprites/generated/tile_grass_sparse.png"),
	preload("res://assets/sprites/generated/tile_grass_flowers.png"),
	preload("res://assets/sprites/generated/tile_grass_stones.png"),
]
const REVEALED_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/generated/tile_dirt_empty.png"),
	preload("res://assets/sprites/generated/tile_dirt_pebbles.png"),
	preload("res://assets/sprites/generated/tile_dirt_cracked.png"),
]
const NUMBER_TEXTURES: Array[Texture2D] = [
	null,
	preload("res://assets/sprites/generated/number_1.png"),
	preload("res://assets/sprites/generated/number_2.png"),
	preload("res://assets/sprites/generated/number_3.png"),
	preload("res://assets/sprites/generated/number_4.png"),
	preload("res://assets/sprites/generated/number_5.png"),
	preload("res://assets/sprites/generated/number_6.png"),
	preload("res://assets/sprites/generated/number_7.png"),
	preload("res://assets/sprites/generated/number_8.png"),
]
const FLAG_TEXTURE := preload("res://assets/sprites/generated/marker_flag.png")
const MINE_TEXTURE := preload("res://assets/sprites/generated/mine_basic.png")
const FLAGGED_MINE_TEXTURE := preload("res://assets/sprites/generated/mine_flagged.png")
const WRONG_FLAG_TEXTURE := preload("res://assets/sprites/generated/marker_unknown.png")
const LANTERN_TEXTURE := preload("res://assets/sprites/generated/item_lantern.png")
const COMPASS_TEXTURE := preload("res://assets/sprites/generated/item_compass.png")

var _board: MinesweeperBoard
var _cells: Array[MineCell] = []
var _grid: GridContainer
var _status_label: Label
var _mine_label: Label
var _time_label: Label
var _effects_layer: Control
var _restart_button: Button
var _started := false
var _elapsed := 0.0
var _resolving := false


func _ready() -> void:
	_build_interface()
	_start_game()


func _process(delta: float) -> void:
	if _started and not _board.game_over:
		_elapsed += delta
		_time_label.text = "%03d" % mini(int(_elapsed), 999)


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("margin_left", 56)
	page.add_theme_constant_override("margin_right", 56)
	page.add_theme_constant_override("margin_top", 30)
	page.add_theme_constant_override("margin_bottom", 30)
	add_child(page)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	page.add_child(layout)

	_effects_layer = Control.new()
	_effects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_effects_layer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	layout.add_child(header)

	var title_group := VBoxContainer.new()
	title_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_group.add_theme_constant_override("separation", 2)
	header.add_child(title_group)

	var eyebrow := Label.new()
	eyebrow.text = "FIELD NOTE  ·  01"
	eyebrow.add_theme_color_override("font_color", COLOR_ACCENT)
	eyebrow.add_theme_font_size_override("font_size", 18)
	title_group.add_child(eyebrow)

	var title := Label.new()
	title.text = "花园雷区"
	title.add_theme_color_override("font_color", COLOR_INK)
	title.add_theme_font_size_override("font_size", 42)
	title_group.add_child(title)

	var counters := HBoxContainer.new()
	counters.add_theme_constant_override("separation", 12)
	header.add_child(counters)
	_mine_label = _make_counter(counters, "地雷", "012")
	_time_label = _make_counter(counters, "时间", "000")

	var game_row := HBoxContainer.new()
	game_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_row.alignment = BoxContainer.ALIGNMENT_CENTER
	game_row.add_theme_constant_override("separation", 34)
	layout.add_child(game_row)

	var board_panel := PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_panel.add_theme_stylebox_override("panel", _panel_style(Color("4a2e1d"), Color("28170f"), 18, 10))
	game_row.add_child(board_panel)

	_grid = GridContainer.new()
	_grid.columns = BOARD_WIDTH
	_grid.add_theme_constant_override("h_separation", 0)
	_grid.add_theme_constant_override("v_separation", 0)
	board_panel.add_child(_grid)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(330, 0)
	sidebar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sidebar.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, Color("53633d"), 20, 28))
	game_row.add_child(sidebar)

	var sidebar_content := VBoxContainer.new()
	sidebar_content.add_theme_constant_override("separation", 22)
	sidebar.add_child(sidebar_content)

	var chapter := Label.new()
	chapter.text = "今日任务"
	chapter.add_theme_color_override("font_color", COLOR_ACCENT)
	chapter.add_theme_font_size_override("font_size", 18)
	sidebar_content.add_child(chapter)

	_status_label = Label.new()
	_status_label.text = "从任意草地开始挖掘"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", COLOR_INK)
	_status_label.add_theme_font_size_override("font_size", 28)
	_status_label.custom_minimum_size.y = 88
	sidebar_content.add_child(_status_label)

	var rule := HSeparator.new()
	rule.modulate = Color("7f8c62")
	sidebar_content.add_child(rule)

	var instructions := Label.new()
	instructions.text = "左键  翻开地格\n右键  插上旗帜\n\n灯会照亮周围九格。\n罗盘会寻找一处安全地格。"
	instructions.add_theme_color_override("font_color", COLOR_MUTED)
	instructions.add_theme_font_size_override("font_size", 18)
	instructions.add_theme_constant_override("line_spacing", 8)
	sidebar_content.add_child(instructions)

	_restart_button = Button.new()
	_restart_button.text = "重新布置雷区"
	_restart_button.custom_minimum_size = Vector2(0, 58)
	_restart_button.add_theme_font_size_override("font_size", 19)
	_restart_button.add_theme_color_override("font_color", COLOR_PANEL_DARK)
	_restart_button.add_theme_stylebox_override("normal", _button_style(COLOR_ACCENT))
	_restart_button.add_theme_stylebox_override("hover", _button_style(Color("ffd66d")))
	_restart_button.add_theme_stylebox_override("pressed", _button_style(Color("dca43a")))
	_restart_button.pressed.connect(_start_game)
	sidebar_content.add_child(_restart_button)


func _start_game() -> void:
	_board = BoardModel.new(
		BOARD_WIDTH,
		BOARD_HEIGHT,
		MINE_COUNT,
		0,
		LANTERN_COUNT,
		COMPASS_COUNT
	)
	_started = false
	_resolving = false
	_restart_button.disabled = false
	_elapsed = 0.0
	_time_label.text = "000"
	_status_label.text = "从任意草地开始挖掘"
	_status_label.add_theme_color_override("font_color", COLOR_INK)
	_mine_label.text = "%03d" % MINE_COUNT
	for child in _grid.get_children():
		child.queue_free()
	_cells.clear()
	for index in range(BOARD_WIDTH * BOARD_HEIGHT):
		var cell: MineCell = CellView.new()
		cell.configure(index, CELL_SIZE)
		cell.primary_pressed.connect(_on_cell_revealed)
		cell.secondary_pressed.connect(_on_cell_flagged)
		_grid.add_child(cell)
		_cells.append(cell)
		cell.display_covered(_covered_texture(index), _revealed_texture(index))


func _on_cell_revealed(index: int) -> void:
	if _board.game_over or _resolving:
		return
	_resolve_turn(index)


func _on_cell_flagged(index: int) -> void:
	if _resolving:
		return
	if not _board.toggle_flag(index):
		return
	_refresh_cell(index)
	_cells[index].play_flag()
	_mine_label.text = "%03d" % maxi(MINE_COUNT - _board.flag_count(), 0)
	_status_label.text = "已标记 %d 处可疑位置" % _board.flag_count()


func _refresh_cell(index: int, animate_reveal: bool = false) -> void:
	match _board.state_at(index):
		MinesweeperBoard.CellState.COVERED:
			_cells[index].display_covered(_covered_texture(index), _revealed_texture(index))
		MinesweeperBoard.CellState.FLAGGED:
			_cells[index].display_covered(_covered_texture(index), _revealed_texture(index), FLAG_TEXTURE)
		MinesweeperBoard.CellState.REVEALED:
			var content: Texture2D
			var kind := MineCell.ContentKind.EMPTY
			if _board.has_mine(index):
				content = MINE_TEXTURE
				kind = MineCell.ContentKind.MINE
			elif _board.item_at(index) != MinesweeperBoard.ItemType.NONE:
				content = _item_texture(_board.item_at(index))
				kind = MineCell.ContentKind.ITEM
			else:
				content = NUMBER_TEXTURES[_board.adjacent_mines(index)]
				if content != null:
					kind = MineCell.ContentKind.NUMBER
			_cells[index].display_revealed(_revealed_texture(index), content, kind, animate_reveal)


func _resolve_turn(index: int) -> void:
	_resolving = true
	_restart_button.disabled = true
	_set_board_interactable(false)
	_started = true
	var item_queue: Array[int] = []
	var queued_items: Dictionary = {}
	var changed: PackedInt32Array = _board.reveal(index)
	_present_revealed(changed, item_queue, queued_items)
	if not changed.is_empty():
		await get_tree().create_timer(0.2).timeout

	while not item_queue.is_empty():
		var item_index: int = item_queue.pop_front()
		var item := _board.consume_item(item_index)
		match item:
			MinesweeperBoard.ItemType.LANTERN:
				await _resolve_lantern(item_index, item_queue, queued_items)
			MinesweeperBoard.ItemType.COMPASS:
				await _resolve_compass(item_index, item_queue, queued_items)

	if _board.game_over:
		_finish_game()
	else:
		_status_label.text = "继续排查，别踩到它们。"
		_resolving = false
		_restart_button.disabled = false
		_set_board_interactable(true)


func _present_revealed(changed: PackedInt32Array, item_queue: Array[int], queued_items: Dictionary) -> void:
	var effect_stride := maxi(1, ceili(changed.size() / 18.0))
	var effect_index := 0
	for changed_index in changed:
		_refresh_cell(changed_index, true)
		_cells[changed_index].play_reveal()
		if effect_index % effect_stride == 0:
			_spawn_reveal_debris(changed_index)
		effect_index += 1
	var ordered := Array(changed)
	ordered.sort()
	for changed_index in ordered:
		if (
			_board.item_at(changed_index) != MinesweeperBoard.ItemType.NONE
			and not _board.is_item_used(changed_index)
			and not queued_items.has(changed_index)
		):
			queued_items[changed_index] = true
			item_queue.append(changed_index)


func _spawn_reveal_debris(cell_index: int) -> void:
	var center := _cells[cell_index].global_position + _cells[cell_index].size * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = _board.seed ^ (cell_index * 7919) ^ Time.get_ticks_msec()
	var fragment_colors := [Color("7d9c35"), Color("9ab849"), Color("79502d"), Color("9a6737")]
	for fragment_index in range(4):
		var fragment := ColorRect.new()
		var fragment_size := rng.randf_range(6.0, 11.0)
		fragment.size = Vector2(fragment_size, fragment_size * rng.randf_range(0.55, 0.9))
		fragment.color = fragment_colors[fragment_index]
		fragment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fragment.pivot_offset = fragment.size * 0.5
		_effects_layer.add_child(fragment)
		fragment.global_position = center + Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-8.0, 8.0))
		var angle := rng.randf_range(-2.75, -0.4)
		var distance := rng.randf_range(34.0, 62.0)
		var destination := fragment.global_position + Vector2(cos(angle), sin(angle)) * distance + Vector2(0, 30)
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(fragment, "global_position", destination, 0.38)
		tween.tween_property(fragment, "rotation", rng.randf_range(-2.5, 2.5), 0.38)
		tween.tween_property(fragment, "modulate:a", 0.0, 0.28).set_delay(0.1)
		tween.finished.connect(fragment.queue_free)

	var dust := Panel.new()
	dust.size = Vector2(48, 22)
	dust.pivot_offset = dust.size * 0.5
	dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dust_style := StyleBoxFlat.new()
	dust_style.bg_color = Color(0.72, 0.53, 0.3, 0.28)
	dust_style.set_corner_radius_all(30)
	dust.add_theme_stylebox_override("panel", dust_style)
	_effects_layer.add_child(dust)
	dust.global_position = center - dust.size * 0.5 + Vector2(0, 15)
	dust.scale = Vector2(0.45, 0.45)
	var dust_tween := create_tween().set_parallel(true)
	dust_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	dust_tween.tween_property(dust, "scale", Vector2(1.55, 1.2), 0.3)
	dust_tween.tween_property(dust, "global_position:y", dust.global_position.y - 13.0, 0.3)
	dust_tween.tween_property(dust, "modulate:a", 0.0, 0.3)
	dust_tween.finished.connect(dust.queue_free)


func _resolve_lantern(item_index: int, item_queue: Array[int], queued_items: Dictionary) -> void:
	_status_label.text = "灯被点亮了！\n正在照亮周围地格……"
	var targets := _board.neighbors_of(item_index)
	targets.append(item_index)
	for target in targets:
		_cells[target].play_light(Color("ffe477"))
	await get_tree().create_timer(0.38).timeout

	var result: Dictionary = _board.apply_lantern(item_index)
	var flagged: PackedInt32Array = result["flagged"]
	for flagged_index in flagged:
		_refresh_cell(flagged_index)
		_cells[flagged_index].play_flag()
	_mine_label.text = "%03d" % maxi(MINE_COUNT - _board.flag_count(), 0)
	var revealed: PackedInt32Array = result["revealed"]
	_present_revealed(revealed, item_queue, queued_items)
	await get_tree().create_timer(0.24).timeout


func _resolve_compass(item_index: int, item_queue: Array[int], queued_items: Dictionary) -> void:
	var target := _board.random_hidden_safe_cell()
	if target < 0:
		return
	_status_label.text = "罗盘开始转动……\n它找到了一处安全位置！"
	await _fly_compass(item_index, target)
	var revealed: PackedInt32Array = _board.reveal_forced_safe(target)
	_present_revealed(revealed, item_queue, queued_items)
	_mine_label.text = "%03d" % maxi(MINE_COUNT - _board.flag_count(), 0)
	await get_tree().create_timer(0.24).timeout


func _fly_compass(source_index: int, target_index: int) -> void:
	var flying := TextureRect.new()
	flying.texture = COMPASS_TEXTURE
	flying.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flying.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flying.size = Vector2(82, 82)
	flying.pivot_offset = flying.size * 0.5
	_effects_layer.add_child(flying)
	var source_center := _cells[source_index].global_position + _cells[source_index].size * 0.5
	var target_center := _cells[target_index].global_position + _cells[target_index].size * 0.5
	flying.global_position = source_center - flying.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(flying, "global_position", target_center - flying.size * 0.5, 0.58)
	tween.tween_property(flying, "rotation", TAU * 1.25, 0.58)
	tween.tween_property(flying, "scale", Vector2(0.76, 0.76), 0.58)
	await tween.finished
	flying.queue_free()
	_cells[target_index].play_light(Color("75e6e1"))
	await get_tree().create_timer(0.14).timeout


func _set_board_interactable(value: bool) -> void:
	for cell in _cells:
		cell.set_interactable(value)


func _item_texture(item: MinesweeperBoard.ItemType) -> Texture2D:
	match item:
		MinesweeperBoard.ItemType.LANTERN:
			return LANTERN_TEXTURE
		MinesweeperBoard.ItemType.COMPASS:
			return COMPASS_TEXTURE
	return null


func _finish_game() -> void:
	_started = false
	_resolving = false
	_restart_button.disabled = false
	for index in range(_cells.size()):
		_cells[index].set_interactable(false)
		if _board.has_mine(index):
			var mine_art: Texture2D = FLAGGED_MINE_TEXTURE if _board.state_at(index) == MinesweeperBoard.CellState.FLAGGED else MINE_TEXTURE
			_cells[index].display_revealed(_revealed_texture(index), mine_art, MineCell.ContentKind.MINE)
		elif _board.state_at(index) == MinesweeperBoard.CellState.FLAGGED:
			_cells[index].display_revealed(_revealed_texture(index), WRONG_FLAG_TEXTURE, MineCell.ContentKind.ITEM)
	if _board.won:
		_status_label.text = "雷区清理完成！\n干得漂亮。"
		_status_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		_mine_label.text = "000"
	else:
		_status_label.text = "轰！挖到了地雷。\n再试一次吧。"
		_status_label.add_theme_color_override("font_color", COLOR_DANGER)


func _covered_texture(index: int) -> Texture2D:
	return COVERED_TEXTURES[(index * 7 + index / BOARD_WIDTH * 3) % COVERED_TEXTURES.size()]


func _revealed_texture(index: int) -> Texture2D:
	return REVEALED_TEXTURES[(index * 5 + index / BOARD_WIDTH) % REVEALED_TEXTURES.size()]


func _make_counter(parent: Control, caption: String, value: String) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(132, 76)
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, Color("4c5d3b"), 12, 12))
	parent.add_child(panel)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", -2)
	panel.add_child(stack)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_color_override("font_color", COLOR_MUTED)
	caption_label.add_theme_font_size_override("font_size", 14)
	stack.add_child(caption_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", COLOR_INK)
	value_label.add_theme_font_size_override("font_size", 27)
	stack.add_child(value_label)
	return value_label


func _panel_style(color: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(float(margin))
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10.0)
	return style
