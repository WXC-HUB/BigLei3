extends SceneTree
## 把三种新特效逐帧截到 artifacts/ 下，方便肉眼确认强度和配色。
## 运行方式（需要渲染窗口，不能加 --headless）：
##   godot --fixed-fps 60 --script tools/capture_cell_fx.gd
## --fixed-fps 必须带上：保存 PNG 会拖长真实帧间隔，不固定步长的话每张截图
## 的时间点都会漂移，特效经常已经播完了。

const CELL_FX := preload("res://vfx/cell_fx.gd")
const OUTPUT_DIR := "res://artifacts/cell_fx"

var _game: Node
var _board: MinesweeperBoard


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	await process_frame
	await process_frame
	# The title screen sits on its own canvas layer and would cover every frame.
	_game.call("_on_start_game_requested")
	_game.call("_start_game")
	_game.call("_start_game")
	await process_frame
	_board = _game.get("_board")
	var center := int(_board.height / 2) * _board.width + int(_board.width / 2)
	_game.call("_on_cell_revealed", center)
	await create_timer(1.6).timeout

	await _capture_flag_seal()
	await _capture_mine_explosion()
	await _capture_player_hit()

	print("Saved cell FX frames to ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _capture_flag_seal() -> void:
	var mine_index := -1
	for index in range(_board.width * _board.height):
		if _board.state_at(index) == MinesweeperBoard.CellState.COVERED and _board.has_mine(index):
			mine_index = index
			break
	if mine_index < 0:
		return
	_game.call("_on_cell_flagged", mine_index)
	await _shoot("flag_00_seal", 0.06)
	await _shoot("flag_01_pose", 0.11)
	await _shoot("flag_02_shatter", 0.08)
	await _shoot("flag_03_shards", 0.12)
	await _shoot("flag_04_settled", 0.5)


func _capture_mine_explosion() -> void:
	var target := -1
	for index in range(_board.width * _board.height):
		if _board.state_at(index) == MinesweeperBoard.CellState.COVERED and _board.has_mine(index):
			target = index
			break
	if target < 0:
		return
	var cells: Array = _game.get("_cells")
	var cell: Control = cells[target]
	var layer: Control = _game.get("_effects_layer")
	var center: Vector2 = cell.global_position + cell.size * 0.5
	CELL_FX.play_mine_alert(layer, center)
	await _shoot("mine_00_alert", 0.1)
	CELL_FX.play_mine_explosion(layer, center)
	await _shoot("mine_01_flash", 0.045)
	await _shoot("mine_02_shock", 0.1)
	await _shoot("mine_03_sparks", 0.14)
	await _shoot("mine_04_smoke", 0.35)


func _capture_player_hit() -> void:
	var status: Node = _game.get("_player_status")
	var layer: Control = _game.get("_effects_layer")
	var head_center: Vector2 = status.call("hero_head_center")
	status.call("play_hit_feedback")
	CELL_FX.play_impact_hit(layer, head_center)

	await _shoot("hit_00_flash", 0.04)
	await _shoot("hit_01_ring", 0.08)
	await _shoot("hit_02_shake", 0.1)
	await _shoot("hit_03_recover", 0.25)


func _shoot(name: String, wait: float) -> void:
	await create_timer(wait).timeout
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [OUTPUT_DIR, name])
