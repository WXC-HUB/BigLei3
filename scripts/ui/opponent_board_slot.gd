class_name OpponentBoardSlot
extends Control
## 分屏右侧的对手棋盘位：一层格子轮廓底 + 一层不透明迷雾罩。
##
## 为什么不铺一副真的 MineCell 棋盘：FEAT-003 定的是「棋盘全遮」，雾底下没有任何
## 格子状态需要显示。摆 100 张 MineCard（每张运行时还要再建 19 层子节点，一共约
## 2000 个节点）只为了让它们被一层不透明的雾整个盖住，是拿两千个节点换零像素。
##
## 也正因为全遮，对手的棋盘状态**完全不需要过线**——本类画出来的行列数取自本地
## 棋盘（双方同种子同曲线，尺寸必然相同），一个网络字节都没用到。

const FACE_COLOR := Color(0.086, 0.114, 0.094, 1.0)
const LINE_COLOR := Color(0.180, 0.235, 0.196, 1.0)
const VEIL_COLOR := Color(0.043, 0.063, 0.051, 0.972)
const VEIL_FLASH_COLOR := Color(0.196, 0.255, 0.207, 0.949)
const HINT_COLOR := Color(0.404, 0.463, 0.396, 1.0)
const PANEL_PADDING := 24.0


## 格子轮廓底。只画行列，不带任何状态——它存在的唯一意义是让右屏读得出
## 「那边是一副和我一样大的盘」，而棋盘尺寸本来就是公开信息。
class FogGridBackdrop extends Control:
	var columns := 0
	var rows := 0
	var cell_size := 0.0
	var gap := 0.0

	func configure(new_columns: int, new_rows: int, new_cell_size: float, new_gap: float) -> void:
		columns = maxi(new_columns, 0)
		rows = maxi(new_rows, 0)
		cell_size = maxf(new_cell_size, 0.0)
		gap = maxf(new_gap, 0.0)
		var grid := Vector2(
			cell_size * columns + gap * maxi(columns - 1, 0),
			cell_size * rows + gap * maxi(rows - 1, 0)
		)
		custom_minimum_size = grid
		size = grid
		queue_redraw()

	func _draw() -> void:
		if columns <= 0 or rows <= 0 or cell_size <= 0.0:
			return
		for row in range(rows):
			for column in range(columns):
				var rect := Rect2(
					Vector2(column, row) * (cell_size + gap),
					Vector2.ONE * cell_size
				)
				draw_rect(rect, OpponentBoardSlot.FACE_COLOR, true)
				draw_rect(rect, OpponentBoardSlot.LINE_COLOR, false, 2.0)


var _backdrop: FogGridBackdrop
var _veil: ColorRect
var _hint: Label
var _flash_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = FogGridBackdrop.new()
	_backdrop.name = "FogGridBackdrop"
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_veil = ColorRect.new()
	_veil.name = "FogVeil"
	_veil.color = VEIL_COLOR
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	_hint = Label.new()
	_hint.name = "FogHintLabel"
	_hint.text = "对手的雷区"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 34)
	_hint.add_theme_color_override("font_color", HINT_COLOR)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.add_child(_hint)


## 按对手棋盘的行列与格子边长重排。双方同种子同曲线，所以这些数都能从**本地**棋盘
## 拿到，不需要任何网络数据。返回整块位（含面板内边距）的尺寸，方便调用方定位。
func set_board(columns: int, rows: int, cell_size: float, gap: float) -> Vector2:
	if _backdrop == null:
		return Vector2.ZERO
	_backdrop.configure(columns, rows, cell_size, gap)
	var grid: Vector2 = _backdrop.size
	var panel_size := grid + Vector2(PANEL_PADDING, PANEL_PADDING)
	custom_minimum_size = panel_size
	size = panel_size
	_backdrop.position = Vector2(PANEL_PADDING, PANEL_PADDING) * 0.5
	_veil.position = _backdrop.position
	_veil.size = grid
	_hint.position = Vector2.ZERO
	_hint.size = grid
	return panel_size


## 对手标出一个雷时整片雾闪一下。事件源是 FEAT-001 既有的 MINE_MARKED 消息，零协议
## 成本；闪的是整片雾而不是某一格，所以不泄漏任何位置信息。
func flash() -> void:
	if _veil == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_veil.color = VEIL_FLASH_COLOR
	_flash_tween = create_tween()
	_flash_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_veil, "color", VEIL_COLOR, 0.42)
