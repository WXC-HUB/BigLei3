extends Control

const BoardModel := preload("res://scripts/game/minesweeper_board.gd")
const CellView := preload("res://scripts/ui/mine_cell.gd")
const MapTileView := preload("res://scripts/ui/map_tile_layer.gd")
const ShopOverlayView := preload("res://scenes/shop_overlay.tscn")
const PlayerStatusView := preload("res://scenes/player_status.tscn")

const BOARD_WIDTH := 10
const BOARD_HEIGHT := 8
const MINE_COUNT := 12
const LANTERN_COUNT := 3
const COMPASS_COUNT := 3
const CELL_SIZE := 100.0
const BOARD_TOP_SCALE := 0.96
const PLAYER_MAX_HP := 10
const LEVEL_GOLD_REWARD := 5
const SHOP_ITEM_COST := 5
const MINE_MAX_HP := 3
const MINE_ATTACK_DELAY := 3
const MINE_DAMAGE := 2
const SMALL_MINE_ATTACK_DAMAGE := MINE_MAX_HP

const COLOR_BG := Color("172119")
const COLOR_PANEL_DARK := Color("1c281b")
const COLOR_INK := Color("f4e8c1")
const COLOR_MUTED := Color("b7bf95")
const COLOR_ACCENT := Color("f2bd4c")
const COLOR_DANGER := Color("e65a45")
const COLOR_SUCCESS := Color("8fd15b")
const COLOR_HUD_INK := Color("493722")
const COLOR_HUD_MUTED := Color("78664b")

const FLAG_TEXTURE := preload("res://assets/sprites/generated/marker_flag.png")
const MONSTER_SMALL_TEXTURE := preload("res://my_asset/monster_small.png")
const MONSTER_BIG_TEXTURE := preload("res://my_asset/monster_big.png")
const WRONG_FLAG_TEXTURE := preload("res://assets/sprites/generated/marker_unknown.png")
const LANTERN_TEXTURE := preload("res://assets/sprites/generated/item_lantern.png")
const COMPASS_TEXTURE := preload("res://assets/sprites/generated/item_compass.png")

# Per the art-state convention: bright `revealed_*` artwork is the unflipped
# face, while dark `fogged_*` artwork is shown after a tile has been flipped.
const GROUND_COVERED_TILES: Array[Texture2D] = [
	preload("res://outlined_tiles/ground_tiles/revealed_plain.png"),
	preload("res://outlined_tiles/ground_tiles/revealed_rock.png"),
	preload("res://outlined_tiles/ground_tiles/revealed_grass.png"),
	preload("res://outlined_tiles/ground_tiles/revealed_small_flowers.png"),
	preload("res://outlined_tiles/ground_tiles/revealed_large_flowers.png"),
	preload("res://outlined_tiles/ground_tiles/revealed_mushroom.png"),
]
const GROUND_FLIPPED_TILES: Array[Texture2D] = [
	preload("res://outlined_tiles/ground_tiles/fogged_plain.png"),
	preload("res://outlined_tiles/ground_tiles/fogged_rock.png"),
	preload("res://outlined_tiles/ground_tiles/fogged_grass.png"),
	preload("res://outlined_tiles/ground_tiles/fogged_small_flowers.png"),
	preload("res://outlined_tiles/ground_tiles/fogged_large_flowers.png"),
	preload("res://outlined_tiles/ground_tiles/fogged_mushroom.png"),
]
const GROUND_VARIANT_POOL := [
	0, 0, 0, 0, 0, 0, 0, # plain
	1, 1, 1,             # rock
	2, 2, 2, 2,          # grass
	3, 3,                 # small flowers
	4, 4,                 # large flowers
	5, 5,                 # mushroom
]

enum ShopOffer { LANTERN_CACHE, COMPASS_CACHE, SAFER_PATH }

var _board: MinesweeperBoard
var _cells: Array[MineCell] = []
var _grid: Control
var _tile_layer: MapTileLayer
var _ground_variants := PackedInt32Array()
var _status_label: Label
var _mine_label: Label
var _time_label: Label
var _health_bar: ProgressBar
var _player_status
var _effects_layer: Control
var _restart_button: Button
var _shop_layer: ShopOverlay
var _run_number := 0
var _lantern_bonus := 0
var _compass_bonus := 0
var _mine_reduction := 0
var _player_hp := PLAYER_MAX_HP
var _gold := 0
var _gold_rewarded_this_run := false
var _active_mines: Dictionary = {}
var _defeated_mines: Dictionary = {}
var _hovered_cell_index := -1
var _previewed_cells: Array[int] = []
var _item_tooltip: PanelContainer
var _item_tooltip_title: Label
var _item_tooltip_body: Label
var _started := false
var _elapsed := 0.0
var _resolving := false
var _mouse_buttons_down := 0
var _mouse_press_cell := -1
var _inference_chord_used := false
var _inference_highlights: Array[int] = []


func _ready() -> void:
	_build_interface()
	_build_shop_interface()
	_build_item_tooltip()
	_start_game()


func _process(delta: float) -> void:
	if _started and not _board.game_over:
		_elapsed += delta
		_time_label.text = "%03d" % mini(int(_elapsed), 999)
	if _item_tooltip.visible:
		var viewport_size := get_viewport_rect().size
		var desired := get_viewport().get_mouse_position() + Vector2(22, 20)
		_item_tooltip.position = Vector2(
			clampf(desired.x, 12.0, viewport_size.x - _item_tooltip.size.x - 12.0),
			clampf(desired.y, 12.0, viewport_size.y - _item_tooltip.size.y - 12.0)
		)


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT and mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	# GUI controls do not reliably deliver both halves of a left+right chord to
	# the same TextureButton. Track the gesture at board level using the hovered
	# cell captured by the first press.
	var target_index := _hovered_cell_index if mouse_event.pressed else _mouse_press_cell
	if target_index >= 0:
		_on_cell_mouse_button_changed(target_index, mouse_event.button_index, mouse_event.pressed)


func _build_interface() -> void:
	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("margin_left", 42)
	page.add_theme_constant_override("margin_right", 42)
	page.add_theme_constant_override("margin_top", 42)
	page.add_theme_constant_override("margin_bottom", 42)
	add_child(page)

	# Stable left HUD plus a larger right-hand play stage, matching the target
	# composition while keeping every block replaceable as art arrives.
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 34)
	page.add_child(layout)

	_effects_layer = Control.new()
	_effects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_effects_layer)

	var hud_panel := PanelContainer.new()
	hud_panel.custom_minimum_size.x = 440
	hud_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud_panel.add_theme_stylebox_override("panel", _hud_panel_style())
	layout.add_child(hud_panel)

	var header := VBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	header.add_theme_constant_override("separation", 20)
	hud_panel.add_child(header)

	var profile_row := HBoxContainer.new()
	profile_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	profile_row.add_theme_constant_override("separation", 20)
	header.add_child(profile_row)

	_player_status = PlayerStatusView.instantiate()
	profile_row.add_child(_player_status)
	_health_bar = _player_status.health_bar

	var debug_pass_button := Button.new()
	debug_pass_button.text = "DEBUG · 直接通过本关"
	debug_pass_button.custom_minimum_size = Vector2(0, 46)
	debug_pass_button.add_theme_font_size_override("font_size", 17)
	debug_pass_button.add_theme_color_override("font_color", Color("fff4d0"))
	debug_pass_button.add_theme_stylebox_override("normal", _button_style(Color("536b72")))
	debug_pass_button.add_theme_stylebox_override("hover", _button_style(Color("6f8b90")))
	debug_pass_button.add_theme_stylebox_override("pressed", _button_style(Color("394d53")))
	debug_pass_button.pressed.connect(_debug_pass_level)
	header.add_child(debug_pass_button)

	# These values remain available to gameplay code but are intentionally not
	# presented in the reduced HUD.
	_mine_label = Label.new()
	_mine_label.visible = false
	header.add_child(_mine_label)
	_time_label = Label.new()
	_time_label.visible = false
	header.add_child(_time_label)

	var game_row := HBoxContainer.new()
	game_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_row.alignment = BoxContainer.ALIGNMENT_CENTER
	game_row.add_theme_constant_override("separation", 34)
	layout.add_child(game_row)

	# Use container margins so the board root keeps its offset after relayouts.
	var board_lift := MarginContainer.new()
	board_lift.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_lift.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Bias the visual board root toward the lower-right of the play stage while
	# preserving the grid's local geometry and pointer coordinates.
	board_lift.add_theme_constant_override("margin_left", 156)
	board_lift.add_theme_constant_override("margin_top", 84)
	game_row.add_child(board_lift)

	var board_panel := PanelContainer.new()
	# Background is below this layer, while the scene decorations remain at 0.
	# This lets foreground rocks and trees naturally overlap the board edges.
	board_panel.z_index = -1
	board_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_panel.add_theme_stylebox_override("panel", _board_field_style())
	board_lift.add_child(board_panel)

	_grid = Control.new()
	_grid.custom_minimum_size = Vector2(CELL_SIZE * BOARD_WIDTH, _board_visual_height())
	board_panel.add_child(_grid)

	var sidebar := PanelContainer.new()
	# Keep status/restart logic alive, but remove the task panel from the layout so
	# the board is the sole element in this row and is truly centered.
	sidebar.visible = false
	sidebar.custom_minimum_size = Vector2(330, 0)
	sidebar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sidebar.add_theme_stylebox_override("panel", _panel_style(Color("283522"), Color("53633d"), 20, 28))
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
	_restart_button.visible = false
	header.add_child(_restart_button)


func _build_item_tooltip() -> void:
	_item_tooltip = PanelContainer.new()
	_item_tooltip.custom_minimum_size = Vector2(350, 0)
	_item_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_tooltip.add_theme_stylebox_override("panel", _panel_style(Color("1c281be8"), Color("71834d"), 14, 16))
	_item_tooltip.visible = false
	add_child(_item_tooltip)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)
	_item_tooltip.add_child(content)

	_item_tooltip_title = Label.new()
	_item_tooltip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_tooltip_title.add_theme_color_override("font_color", COLOR_ACCENT)
	_item_tooltip_title.add_theme_font_size_override("font_size", 20)
	content.add_child(_item_tooltip_title)

	_item_tooltip_body = Label.new()
	_item_tooltip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_tooltip_body.custom_minimum_size.x = 318
	_item_tooltip_body.add_theme_color_override("font_color", COLOR_INK)
	_item_tooltip_body.add_theme_font_size_override("font_size", 16)
	content.add_child(_item_tooltip_body)


func _build_shop_interface() -> void:
	# Gameplay content uses elevated local z-indices for oversized monsters and
	# labels.  A dedicated CanvasLayer keeps modal UI above the entire world,
	# independent of those local draw-order values.
	var shop_canvas := CanvasLayer.new()
	shop_canvas.layer = 100
	add_child(shop_canvas)
	_shop_layer = ShopOverlayView.instantiate()
	_shop_layer.offer_selected.connect(_choose_shop_offer)
	_shop_layer.visible = false
	shop_canvas.add_child(_shop_layer)


func _choose_shop_offer(offer: ShopOffer) -> void:
	if _player_hp <= 0:
		return
	if _gold < SHOP_ITEM_COST:
		_shop_layer.show_insufficient_gold(_gold, SHOP_ITEM_COST)
		return
	_gold -= SHOP_ITEM_COST
	_refresh_gold_display()
	match offer:
		ShopOffer.LANTERN_CACHE:
			_lantern_bonus += 1
		ShopOffer.COMPASS_CACHE:
			_compass_bonus += 1
		ShopOffer.SAFER_PATH:
			_mine_reduction += 2
	_start_game()


func _start_game() -> void:
	_clear_inference_highlights()
	_mouse_buttons_down = 0
	_mouse_press_cell = -1
	_inference_chord_used = false
	_gold_rewarded_this_run = false
	_run_number += 1
	_board = BoardModel.new(
		BOARD_WIDTH,
		BOARD_HEIGHT,
		maxi(6, MINE_COUNT - _mine_reduction),
		0,
		LANTERN_COUNT + _lantern_bonus,
		COMPASS_COUNT + _compass_bonus
	)
	_roll_ground_variants()
	_shop_layer.visible = false
	_active_mines.clear()
	_defeated_mines.clear()
	_hovered_cell_index = -1
	_item_tooltip.visible = false
	_started = false
	_resolving = false
	_restart_button.disabled = false
	_elapsed = 0.0
	_time_label.text = "000"
	_status_label.text = "从任意草地开始挖掘"
	_status_label.add_theme_color_override("font_color", COLOR_INK)
	_mine_label.text = "%03d" % _board.mine_count
	_refresh_health_bar()
	_refresh_gold_display()
	for child in _grid.get_children():
		child.queue_free()
	_cells.clear()
	var map_tiles: Array[Texture2D] = []
	for index in range(BOARD_WIDTH * BOARD_HEIGHT):
		map_tiles.append(_ground_tile(index, false))
	_tile_layer = MapTileView.new()
	_tile_layer.configure(BOARD_WIDTH, BOARD_HEIGHT, CELL_SIZE, BOARD_TOP_SCALE, map_tiles)
	_grid.add_child(_tile_layer)
	for index in range(BOARD_WIDTH * BOARD_HEIGHT):
		var cell: MineCell = CellView.new()
		var row := index / BOARD_WIDTH
		var column := index % BOARD_WIDTH
		var cell_rect := _tile_layer.cell_rect(column, row)
		cell.configure(index, cell_rect.size.x)
		cell.primary_pressed.connect(_on_cell_revealed)
		cell.secondary_pressed.connect(_on_cell_flagged)
		cell.hover_started.connect(_on_cell_hover_started)
		cell.hover_ended.connect(_on_cell_hover_ended)
		_grid.add_child(cell)
		cell.position = cell_rect.position
		cell.size = cell_rect.size
		cell.set_ground_texture(null)
		_cells.append(cell)
		cell.display_covered()


func _debug_pass_level() -> void:
	if _board == null or _board.game_over or _resolving:
		return
	_clear_inference_highlights()
	_resolving = true
	_active_mines.clear()
	for index in range(_cells.size()):
		if _board.is_monster_core(index):
			_defeated_mines[index] = true
	_board.won = true
	_board.game_over = true
	_finish_game()


func _on_cell_mouse_button_changed(index: int, button_index: int, pressed: bool) -> void:
	var button_bit := 1 if button_index == MOUSE_BUTTON_LEFT else 2
	if pressed:
		if _mouse_buttons_down == 0:
			_mouse_press_cell = index
			_inference_chord_used = false
		_mouse_buttons_down |= button_bit
		if _mouse_buttons_down == 3 and _mouse_press_cell == index:
			_inference_chord_used = true
			_begin_cell_inference(index)
		return

	_clear_inference_highlights()
	var was_chord := _inference_chord_used
	_mouse_buttons_down &= ~button_bit
	if not was_chord and _mouse_press_cell == index:
		if button_index == MOUSE_BUTTON_LEFT:
			_on_cell_revealed(index)
		else:
			_on_cell_flagged(index)
	if _mouse_buttons_down == 0:
		_mouse_press_cell = -1
		_inference_chord_used = false


func _begin_cell_inference(index: int) -> void:
	_clear_inference_highlights()
	if _resolving or _board.game_over:
		return
	var inference: Dictionary = _board.inference_at(index)
	for target in _inference_highlight_targets(index, inference):
		_inference_highlights.append(target)
		_cells[target].set_effect_preview(true, Color(1.28, 0.68, 0.56, 1.0))
	if not inference["unique"]:
		return
	var safe_cells: PackedInt32Array = inference["safe_cells"]
	if safe_cells.is_empty():
		return
	_resolve_inferred_safe_cells(safe_cells)


func _inference_highlight_targets(index: int, inference: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	for target in inference["potential_mines"]:
		if not targets.has(target):
			targets.append(target)
	var constraint_cells := Array(_board.neighbors_of(index))
	constraint_cells.append(index)
	for target in constraint_cells:
		if _board.is_flagged(target) and not targets.has(target):
			targets.append(target)
		var corpse_core := _board.monster_core_at(target)
		if corpse_core >= 0 and _defeated_mines.has(corpse_core):
			_append_corpse_footprint(targets, corpse_core)
	return targets


func _append_corpse_footprint(targets: Array[int], core_index: int) -> void:
	if not targets.has(core_index):
		targets.append(core_index)
	if _board.monster_peripheral_count(core_index) == 0:
		return
	for footprint_cell in _board.neighbors_of(core_index):
		if _board.monster_core_at(footprint_cell) == core_index and not targets.has(footprint_cell):
			targets.append(footprint_cell)


func _resolve_inferred_safe_cells(safe_cells: PackedInt32Array) -> void:
	for target in safe_cells:
		if _board.game_over:
			break
		if _board.state_at(target) == MinesweeperBoard.CellState.COVERED:
			await _resolve_turn(target)


func _clear_inference_highlights() -> void:
	for index in _inference_highlights:
		if index >= 0 and index < _cells.size():
			_cells[index].set_effect_preview(false)
	_inference_highlights.clear()


func _row_cell_size(row: int) -> float:
	var top_depth := float(row) / float(BOARD_HEIGHT)
	var bottom_depth := float(row + 1) / float(BOARD_HEIGHT)
	return CELL_SIZE * (lerpf(BOARD_TOP_SCALE, 1.0, top_depth) + lerpf(BOARD_TOP_SCALE, 1.0, bottom_depth)) * 0.5


func _row_offset(row: int) -> float:
	var offset := 0.0
	for previous_row in range(row):
		offset += _row_cell_size(previous_row)
	return offset


func _board_visual_height() -> float:
	return _row_offset(BOARD_HEIGHT)


func _ground_tile(index: int, flipped: bool) -> Texture2D:
	# Keep each cell's motif stable across the state change so only its lighting
	# and fog treatment change when it is flipped.
	var variant := _ground_variants[index] if index < _ground_variants.size() else 0
	return GROUND_FLIPPED_TILES[variant] if flipped else GROUND_COVERED_TILES[variant]


func _roll_ground_variants() -> void:
	var rng := RandomNumberGenerator.new()
	# Tie the art layout to the board run: it changes next game, but a cell keeps
	# the same motif while transitioning between covered and flipped artwork.
	rng.seed = _board.seed ^ 0x47524F554E44
	_ground_variants.resize(BOARD_WIDTH * BOARD_HEIGHT)
	for index in range(_ground_variants.size()):
		_ground_variants[index] = GROUND_VARIANT_POOL[rng.randi_range(0, GROUND_VARIANT_POOL.size() - 1)]


func _refresh_health_bar() -> void:
	if _player_status != null:
		_player_status.set_health(_player_hp, PLAYER_MAX_HP)


func _refresh_gold_display() -> void:
	if _player_status != null:
		_player_status.set_gold(_gold)


func _on_cell_revealed(index: int) -> void:
	if _board.game_over or _resolving:
		return
	if _board.state_at(index) == MinesweeperBoard.CellState.COVERED:
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
	_update_round_completion()
	if _board.game_over:
		await _finish_game()
		return
	if (
		_board.state_at(index) == MinesweeperBoard.CellState.FLAGGED
		and _is_small_monster(index)
	):
		var target := _nearest_active_big_monster(index)
		if target >= 0:
			_resolving = true
			_set_board_interactable(false)
			await _attack_big_with_small_mines(target, [index])
			_update_round_completion()
			if _board.game_over:
				await _finish_game()
			else:
				_resolving = false
				_set_board_interactable(true)


func _on_cell_hover_started(index: int) -> void:
	_hovered_cell_index = index
	_clear_effect_preview()
	if (
		_board.state_at(index) != MinesweeperBoard.CellState.REVEALED
		or _board.is_item_used(index)
	):
		return
	_show_item_tooltip(_board.item_at(index))
	match _board.item_at(index):
		MinesweeperBoard.ItemType.LANTERN:
			_previewed_cells.assign(Array(_board.neighbors_of(index)))
			_previewed_cells.append(index)
			for target in _previewed_cells:
				_cells[target].set_effect_preview(true, Color(1.18, 1.10, 0.68, 1.0))
		MinesweeperBoard.ItemType.COMPASS:
			for target in range(_cells.size()):
				if _board.state_at(target) == MinesweeperBoard.CellState.COVERED:
					_previewed_cells.append(target)
					_cells[target].set_effect_preview(true, Color(0.76, 1.12, 1.12, 1.0))


func _on_cell_hover_ended(index: int) -> void:
	if _hovered_cell_index == index:
		_hovered_cell_index = -1
	_clear_effect_preview()
	_item_tooltip.visible = false


func _clear_effect_preview() -> void:
	for index in _previewed_cells:
		if index >= 0 and index < _cells.size():
			_cells[index].set_effect_preview(false)
	_previewed_cells.clear()


func _show_item_tooltip(item: MinesweeperBoard.ItemType) -> void:
	match item:
		MinesweeperBoard.ItemType.LANTERN:
			_item_tooltip_title.text = "提灯 · 翻出后自动使用"
			_item_tooltip_body.text = "结算时照亮周围 3×3 区域：翻开安全格，并标记尚未翻开的怪物。"
		MinesweeperBoard.ItemType.COMPASS:
			_item_tooltip_title.text = "罗盘 · 翻出后自动使用"
			_item_tooltip_body.text = "结算时寻找并翻开一处尚未探索的安全格，不会触发怪物。"
		_:
			_item_tooltip.visible = false
			return
	_item_tooltip.reset_size()
	_item_tooltip.visible = true


func _refresh_cell(index: int, animate_reveal: bool = false) -> void:
	var is_flipped := _board.state_at(index) == MinesweeperBoard.CellState.REVEALED
	_tile_layer.set_tile(index, _ground_tile(index, is_flipped))
	match _board.state_at(index):
		MinesweeperBoard.CellState.COVERED:
			_cells[index].display_covered()
		MinesweeperBoard.CellState.FLAGGED:
			_cells[index].display_covered(FLAG_TEXTURE)
		MinesweeperBoard.CellState.REVEALED:
			var content: Texture2D
			var kind := MineCell.ContentKind.EMPTY
			var number_value := 0
			if _board.is_monster_core(index) and _defeated_mines.has(index):
				content = _monster_texture(index)
				kind = MineCell.ContentKind.CORPSE
			elif _board.is_monster_core(index):
				content = _monster_texture(index)
				kind = MineCell.ContentKind.MONSTER
			elif _board.item_at(index) != MinesweeperBoard.ItemType.NONE and not _board.is_item_used(index):
				content = _item_texture(_board.item_at(index))
				kind = MineCell.ContentKind.ITEM
			else:
				number_value = _board.adjacent_mines(index)
				if number_value > 0:
					kind = MineCell.ContentKind.NUMBER
			var is_monster_visual := kind == MineCell.ContentKind.MONSTER or kind == MineCell.ContentKind.CORPSE
			var content_span := 3 if is_monster_visual and _board.monster_peripheral_count(index) == 8 else 1
			_cells[index].display_revealed(content, kind, animate_reveal, content_span, number_value)
			if _board.is_flagged(index):
				_cells[index].set_flag_marker(FLAG_TEXTURE)
			if _active_mines.has(index):
				var mine_data: Dictionary = _active_mines[index]
				_cells[index].set_combat_mine_status(mine_data["hp"], mine_data["turns"])


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

	var revealed_big_monsters := await _register_revealed_combat_objects(changed)
	for big_index in revealed_big_monsters:
		await _attack_big_with_small_mines(big_index, _flagged_small_monsters())
	await _resolve_item_queue(item_queue, queued_items)
	_update_round_completion()
	if _player_hp <= 0 or _board.game_over:
		await _finish_game()
		return

	var player_defeated := await _advance_combat_turn()
	if player_defeated:
		await _finish_game()
		return

	_status_label.text = "继续排查，别踩到它们。"
	_resolving = false
	_restart_button.disabled = false
	_set_board_interactable(true)


func _present_revealed(changed: PackedInt32Array, item_queue: Array[int], queued_items: Dictionary) -> void:
	var effect_stride := maxi(1, ceili(changed.size() / 18.0))
	var effect_index := 0
	for changed_index in changed:
		_refresh_cell(changed_index, true)
		if _board.is_monster_core(changed_index) and _board.monster_peripheral_count(changed_index) == 8:
			_cells[changed_index].prepare_monster_emerge()
		else:
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


func _register_revealed_combat_objects(changed: PackedInt32Array) -> Array[int]:
	var revealed_big_monsters: Array[int] = []
	for index in changed:
		if not _board.is_monster_core(index) or _defeated_mines.has(index):
			continue
		if _is_small_monster(index):
			await _play_small_mine_player_hit(index)
			_player_hp = maxi(0, _player_hp - MINE_DAMAGE)
			_defeated_mines[index] = true
			_board.resolve_monster_core(index)
			_refresh_cell(index)
			_refresh_health_bar()
			_spawn_damage_number(_health_bar.global_position + _health_bar.size * 0.5, MINE_DAMAGE, Color("ff7864"))
		else:
			if not _active_mines.has(index):
				_active_mines[index] = {"hp": MINE_MAX_HP, "turns": MINE_ATTACK_DELAY + 1}
				revealed_big_monsters.append(index)
				await _play_big_monster_reveal(index)
			_refresh_cell(index)
	_refresh_health_bar()
	return revealed_big_monsters


func _resolve_item_queue(item_queue: Array[int], queued_items: Dictionary) -> void:
	while not item_queue.is_empty():
		var item_index: int = item_queue.pop_front()
		if _board.is_item_used(item_index):
			continue
		var item: MinesweeperBoard.ItemType = _board.item_at(item_index)
		var focus_color := Color("ffe58a") if item == MinesweeperBoard.ItemType.LANTERN else Color("8ceff2")
		_status_label.text = "发现%s，正在结算……" % ("提灯" if item == MinesweeperBoard.ItemType.LANTERN else "罗盘")
		_cells[item_index].play_item_focus(focus_color)
		_spawn_effect_ring(_cell_center(item_index), focus_color, 18.0, 68.0, 0.3)
		await get_tree().create_timer(0.3).timeout
		_board.consume_item(item_index)
		_refresh_cell(item_index)
		match item:
			MinesweeperBoard.ItemType.LANTERN:
				await _resolve_lantern(item_index, item_queue, queued_items)
			MinesweeperBoard.ItemType.COMPASS:
				await _resolve_compass(item_index, item_queue, queued_items)


func _is_small_monster(index: int) -> bool:
	return _board.is_monster_core(index) and _board.monster_peripheral_count(index) == 0


func _flagged_small_monsters() -> Array[int]:
	var result: Array[int] = []
	for index in range(_cells.size()):
		if (
			_is_small_monster(index)
			and _board.state_at(index) == MinesweeperBoard.CellState.FLAGGED
			and not _defeated_mines.has(index)
		):
			result.append(index)
	return result


func _nearest_active_big_monster(source_index: int) -> int:
	var source_x := source_index % BOARD_WIDTH
	var source_y := source_index / BOARD_WIDTH
	var best_index := -1
	var best_distance := 1000000
	for candidate_variant in _active_mines.keys():
		var candidate := int(candidate_variant)
		if _board.monster_peripheral_count(candidate) != 8:
			continue
		var distance := absi(candidate % BOARD_WIDTH - source_x) + absi(candidate / BOARD_WIDTH - source_y)
		if distance < best_distance or (distance == best_distance and candidate < best_index):
			best_distance = distance
			best_index = candidate
	return best_index


func _cell_center(index: int) -> Vector2:
	return _cells[index].global_position + _cells[index].size * 0.5


func _play_big_monster_reveal(core_index: int) -> void:
	_status_label.text = "地下传来震动……大型怪物出现了！"
	var footprint := Array(_board.neighbors_of(core_index))
	footprint.append(core_index)
	for cell_index in footprint:
		var distance := maxi(
			absi(cell_index % BOARD_WIDTH - core_index % BOARD_WIDTH),
			absi(cell_index / BOARD_WIDTH - core_index / BOARD_WIDTH)
		)
		_cells[cell_index].play_rumble(float(distance) * 0.035)
		if cell_index != core_index:
			_spawn_reveal_debris(cell_index)
	_spawn_effect_ring(_cell_center(core_index), Color("d8b36a"), 32.0, 178.0, 0.42)
	await get_tree().create_timer(0.16).timeout
	_cells[core_index].play_monster_emerge()
	await get_tree().create_timer(0.44).timeout


func _play_small_mine_player_hit(index: int) -> void:
	_status_label.text = "小雷被触发了！"
	_cells[index].play_hit()
	await get_tree().create_timer(0.11).timeout
	var projectile := TextureRect.new()
	projectile.texture = MONSTER_SMALL_TEXTURE
	projectile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	projectile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	projectile.size = Vector2(64, 64)
	projectile.pivot_offset = projectile.size * 0.5
	_effects_layer.add_child(projectile)
	var source := _cell_center(index)
	var target := _health_bar.global_position + _health_bar.size * 0.5
	projectile.global_position = source - projectile.size * 0.5
	var control := (source + target) * 0.5 + Vector2(0, -90)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(func(progress: float) -> void:
		var point := source * pow(1.0 - progress, 2.0) + control * 2.0 * (1.0 - progress) * progress + target * pow(progress, 2.0)
		projectile.global_position = point - projectile.size * 0.5
	, 0.0, 1.0, 0.34)
	tween.tween_property(projectile, "rotation", TAU * 0.8, 0.34)
	tween.tween_property(projectile, "scale", Vector2(0.55, 0.55), 0.34)
	await tween.finished
	projectile.queue_free()
	_spawn_effect_ring(target, Color("ff6658"), 16.0, 86.0, 0.24)
	_player_status.play_hit_feedback()
	await get_tree().create_timer(0.1).timeout


func _spawn_effect_ring(
	center: Vector2,
	color: Color,
	start_diameter: float,
	end_diameter: float,
	duration: float,
	delay: float = 0.0
) -> void:
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2(start_diameter, start_diameter)
	ring.pivot_offset = ring.size * 0.5
	ring.global_position = center - ring.size * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.08)
	style.border_color = Color(color.r, color.g, color.b, 0.82)
	style.set_border_width_all(3)
	style.set_corner_radius_all(999)
	ring.add_theme_stylebox_override("panel", style)
	_effects_layer.add_child(ring)
	var target_scale := Vector2.ONE * (end_diameter / start_diameter)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", target_scale, duration).set_delay(delay)
	tween.tween_property(ring, "modulate:a", 0.0, duration * 0.72).set_delay(delay + duration * 0.28)
	tween.finished.connect(ring.queue_free)


func _spawn_damage_number(center: Vector2, amount: int, color: Color) -> void:
	var label := Label.new()
	label.text = "-%d" % amount
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("351a18"))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", 30)
	label.size = Vector2(90, 44)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = center - label.size * 0.5
	_effects_layer.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position:y", label.global_position.y - 54.0, 0.52)
	tween.tween_property(label, "scale", Vector2(1.18, 1.18), 0.18)
	tween.tween_property(label, "modulate:a", 0.0, 0.24).set_delay(0.28)
	tween.finished.connect(label.queue_free)


func _attack_big_with_small_mines(big_index: int, candidates: Array[int]) -> void:
	if not _active_mines.has(big_index):
		return
	var attackers: Array[int] = []
	for small_index in candidates:
		if (
			_is_small_monster(small_index)
			and _board.state_at(small_index) == MinesweeperBoard.CellState.FLAGGED
			and not _defeated_mines.has(small_index)
		):
			attackers.append(small_index)
	if attackers.is_empty():
		return

	_status_label.text = "%d 枚已标记的小雷正在攻击大型怪物！" % attackers.size()
	for attack_index in range(attackers.size()):
		var small_index := attackers[attack_index]
		_defeated_mines[small_index] = true
		_board.resolve_monster_core(small_index)
		_refresh_cell(small_index)
		_fly_small_monster(small_index, big_index, float(attack_index) * 0.055)
	await get_tree().create_timer(0.46 + float(attackers.size() - 1) * 0.055).timeout

	if not _active_mines.has(big_index):
		return
	var mine_data: Dictionary = _active_mines[big_index]
	var damage := attackers.size() * SMALL_MINE_ATTACK_DAMAGE
	mine_data["hp"] -= damage
	_cells[big_index].play_hit()
	_spawn_effect_ring(_cell_center(big_index), Color("ff7058"), 24.0, 126.0, 0.26)
	_spawn_damage_number(_cell_center(big_index) + Vector2(0, -34), damage, Color("ffcf72"))
	await get_tree().create_timer(0.2).timeout
	if mine_data["hp"] <= 0:
		_active_mines.erase(big_index)
		_defeated_mines[big_index] = true
	else:
		_active_mines[big_index] = mine_data
	_cells[big_index].play_light(Color("ff7658"))
	_refresh_cell(big_index)
	_mine_label.text = "%03d" % maxi(MINE_COUNT - _defeated_mines.size(), 0)


func _fly_small_monster(source_index: int, target_index: int, delay: float = 0.0) -> void:
	var projectile := TextureRect.new()
	projectile.texture = MONSTER_SMALL_TEXTURE
	projectile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	projectile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	projectile.size = Vector2(72, 72)
	projectile.pivot_offset = projectile.size * 0.5
	_effects_layer.add_child(projectile)
	var source_center := _cell_center(source_index)
	var target_center := _cell_center(target_index)
	projectile.global_position = source_center - projectile.size * 0.5
	projectile.scale = Vector2(1.05, 0.72)
	var arc_height := 70.0 + source_center.distance_to(target_center) * 0.12
	var control := (source_center + target_center) * 0.5 + Vector2(0, -arc_height)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(progress: float) -> void:
		var point := source_center * pow(1.0 - progress, 2.0) + control * 2.0 * (1.0 - progress) * progress + target_center * pow(progress, 2.0)
		projectile.global_position = point - projectile.size * 0.5
	, 0.0, 1.0, 0.42).set_delay(delay)
	tween.tween_property(projectile, "scale", Vector2(0.7, 0.7), 0.42).set_delay(delay)
	tween.tween_property(projectile, "rotation", TAU * 0.9, 0.42).set_delay(delay)
	tween.finished.connect(projectile.queue_free)


func _advance_combat_turn() -> bool:
	for index in _active_mines.keys():
		var mine_data: Dictionary = _active_mines[index]
		mine_data["turns"] -= 1
		if mine_data["turns"] <= 0:
			await _play_big_monster_attack(index)
			_player_hp = maxi(0, _player_hp - MINE_DAMAGE)
			mine_data["turns"] = MINE_ATTACK_DELAY
			_refresh_health_bar()
			_spawn_damage_number(_health_bar.global_position + _health_bar.size * 0.5, MINE_DAMAGE, Color("ff7864"))
		_active_mines[index] = mine_data
		_refresh_cell(index)
	_refresh_health_bar()
	return _player_hp <= 0


func _play_big_monster_attack(index: int) -> void:
	_status_label.text = "大型怪物发动攻击！"
	_cells[index].play_hit()
	_spawn_effect_ring(_cell_center(index), Color("ff684f"), 28.0, 142.0, 0.3)
	await get_tree().create_timer(0.16).timeout
	var source := _cell_center(index)
	var target := _health_bar.global_position + _health_bar.size * 0.5
	var bolt := Line2D.new()
	bolt.width = 10.0
	bolt.default_color = Color("ff6958e6")
	bolt.begin_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.end_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.points = PackedVector2Array([Vector2.ZERO, target - source])
	bolt.global_position = source
	bolt.scale = Vector2(0.0, 1.0)
	_effects_layer.add_child(bolt)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(bolt, "scale:x", 1.0, 0.2)
	tween.tween_property(bolt, "modulate:a", 0.0, 0.14).set_delay(0.2)
	_spawn_effect_ring(target, Color("ff684f"), 18.0, 96.0, 0.26, 0.17)
	await get_tree().create_timer(0.3).timeout
	bolt.queue_free()
	_player_status.play_hit_feedback()


func _update_round_completion() -> void:
	if _board.all_mines_triggered_or_flagged():
		_board.won = true
		_board.game_over = true
	else:
		_board.won = false
		_board.game_over = false


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
	_status_label.text = "提灯点亮，光芒正在扩散……"
	var targets := _board.neighbors_of(item_index)
	targets.append(item_index)
	for radius in range(2):
		_spawn_effect_ring(_cell_center(item_index), Color("ffe477"), 30.0, 112.0 + radius * 92.0, 0.34, radius * 0.06)
		for target in targets:
			var distance := maxi(
				absi(target % BOARD_WIDTH - item_index % BOARD_WIDTH),
				absi(target / BOARD_WIDTH - item_index / BOARD_WIDTH)
			)
			if distance == radius:
				_cells[target].play_light(Color("ffe9a0"))
		await get_tree().create_timer(0.16).timeout

	var result: Dictionary = _board.apply_lantern(item_index)
	var revealed: PackedInt32Array = result["revealed"]
	_present_revealed(revealed, item_queue, queued_items)
	if not revealed.is_empty():
		await get_tree().create_timer(0.2).timeout
	var flagged: PackedInt32Array = result["flagged"]
	for flagged_index in flagged:
		_refresh_cell(flagged_index)
		_cells[flagged_index].play_flag()
		_spawn_effect_ring(_cell_center(flagged_index), Color("f7c95b"), 12.0, 58.0, 0.2)
		await get_tree().create_timer(0.055).timeout
	_mine_label.text = "%03d" % maxi(MINE_COUNT - _board.flag_count(), 0)
	var attack_groups: Dictionary = {}
	for flagged_index in flagged:
		if not _is_small_monster(flagged_index):
			continue
		var target := _nearest_active_big_monster(flagged_index)
		if target < 0:
			continue
		if not attack_groups.has(target):
			attack_groups[target] = []
		var group: Array = attack_groups[target]
		group.append(flagged_index)
		attack_groups[target] = group
	for target_variant in attack_groups.keys():
		var target := int(target_variant)
		var untyped_attackers: Array = attack_groups[target]
		var attackers: Array[int] = []
		attackers.assign(untyped_attackers)
		await _attack_big_with_small_mines(target, attackers)
	await get_tree().create_timer(0.12).timeout


func _resolve_compass(item_index: int, item_queue: Array[int], queued_items: Dictionary) -> void:
	var target := _board.random_hidden_safe_cell()
	if target < 0:
		return
	_status_label.text = "罗盘正在搜寻安全位置……"
	await _fly_compass(item_index, target)
	var revealed: PackedInt32Array = _board.reveal_forced_safe(target)
	_present_revealed(revealed, item_queue, queued_items)
	_mine_label.text = "%03d" % maxi(MINE_COUNT - _board.flag_count(), 0)
	await get_tree().create_timer(0.24).timeout


func _fly_compass(source_index: int, target_index: int) -> void:
	var compass := TextureRect.new()
	compass.texture = COMPASS_TEXTURE
	compass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	compass.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass.size = Vector2(86, 86)
	compass.pivot_offset = compass.size * 0.5
	_effects_layer.add_child(compass)
	var source_center := _cell_center(source_index)
	var target_center := _cell_center(target_index)
	compass.global_position = source_center - compass.size * 0.5 + Vector2(0, 10)
	compass.scale = Vector2(0.62, 0.62)
	compass.modulate.a = 0.0
	var rise := create_tween().set_parallel(true)
	rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(compass, "global_position:y", compass.global_position.y - 28.0, 0.3)
	rise.tween_property(compass, "scale", Vector2.ONE, 0.3)
	rise.tween_property(compass, "modulate:a", 1.0, 0.15)
	rise.tween_property(compass, "rotation", TAU * 1.8, 0.38)
	await rise.finished

	var direction := target_center - source_center
	var locked_rotation := direction.angle() + PI * 0.5
	var lock := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lock.tween_property(compass, "rotation", locked_rotation, 0.16)
	await lock.finished

	var beam := Line2D.new()
	beam.width = 7.0
	beam.default_color = Color("8ff6f0d9")
	beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam.points = PackedVector2Array([Vector2.ZERO, direction])
	beam.global_position = source_center
	beam.scale = Vector2(0.0, 1.0)
	_effects_layer.add_child(beam)
	var trace := create_tween().set_parallel(true)
	trace.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	trace.tween_property(beam, "scale:x", 1.0, 0.24)
	trace.tween_property(beam, "modulate:a", 0.0, 0.18).set_delay(0.22)
	_spawn_effect_ring(target_center, Color("75e6e1"), 18.0, 92.0, 0.3, 0.16)
	await get_tree().create_timer(0.3).timeout
	_cells[target_index].play_light(Color("8ff6f0"))
	compass.queue_free()
	beam.queue_free()
	await get_tree().create_timer(0.12).timeout


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


func _monster_texture(core_index: int) -> Texture2D:
	return MONSTER_BIG_TEXTURE if _board.monster_peripheral_count(core_index) == 8 else MONSTER_SMALL_TEXTURE


func _finish_game() -> void:
	_started = false
	_resolving = false
	_restart_button.disabled = false
	for index in range(_cells.size()):
		_cells[index].set_interactable(false)
		if _board.is_monster_core(index) and _defeated_mines.has(index):
			_tile_layer.set_tile(index, _ground_tile(index, true))
			var corpse_span := 3 if _board.monster_peripheral_count(index) == 8 else 1
			_cells[index].display_revealed(_monster_texture(index), MineCell.ContentKind.CORPSE, false, corpse_span)
		elif _board.is_monster_core(index):
			_tile_layer.set_tile(index, _ground_tile(index, true))
			var content_span := 3 if _board.monster_peripheral_count(index) == 8 else 1
			_cells[index].display_revealed(_monster_texture(index), MineCell.ContentKind.MONSTER, false, content_span)
		elif (
			_board.state_at(index) == MinesweeperBoard.CellState.FLAGGED
			and not _board.is_monster_core(index)
		):
			_tile_layer.set_tile(index, _ground_tile(index, true))
			_cells[index].display_revealed(WRONG_FLAG_TEXTURE, MineCell.ContentKind.ITEM)
	if _player_hp <= 0:
		_board.won = false
		_status_label.text = "生命归零，旅程结束。"
		_status_label.add_theme_color_override("font_color", COLOR_DANGER)
	elif _board.won:
		if not _gold_rewarded_this_run:
			_gold += LEVEL_GOLD_REWARD
			_gold_rewarded_this_run = true
			_refresh_gold_display()
		_status_label.text = "雷区清理完成！\n干得漂亮。"
		_status_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		_mine_label.text = "000"
	else:
		_status_label.text = "轰！挖到了地雷。\n再试一次吧。"
		_status_label.add_theme_color_override("font_color", COLOR_DANGER)
	await get_tree().create_timer(0.55).timeout
	if _player_hp <= 0:
		_shop_layer.present_game_over()
		return
	_show_shop()


func _show_shop() -> void:
	var result_template := "第 %d 局清扫完成" if _board.won else "第 %d 局遭遇地雷"
	var result := result_template % _run_number
	var progress := "当前传承：提灯 +%d｜罗盘 +%d｜地雷 -%d" % [
		_lantern_bonus,
		_compass_bonus,
		_mine_reduction,
	]
	_shop_layer.present(result, progress, _gold, SHOP_ITEM_COST)


func _board_field_style() -> StyleBoxFlat:
	# The map tiles define the complete board silhouette; no extra backing plate.
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_content_margin_all(0.0)
	return style


func _make_counter(parent: Control, caption: String, value: String) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 76)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _hud_counter_style())
	parent.add_child(panel)
	var stack := HBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_label.add_theme_color_override("font_color", COLOR_HUD_MUTED)
	caption_label.add_theme_font_size_override("font_size", 17)
	stack.add_child(caption_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", COLOR_HUD_INK)
	value_label.add_theme_font_size_override("font_size", 27)
	stack.add_child(value_label)
	return value_label


func _hud_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_content_margin_all(12.0)
	return style


func _hud_counter_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ead9b9c4")
	style.border_color = Color("a889574c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14.0)
	return style


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
