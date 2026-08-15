class_name MapTileLayer
extends Control

var _columns := 0
var _rows := 0
var _cell_size := 0.0
var _top_scale := 1.0
var _tiles: Array[Texture2D] = []


func configure(columns: int, rows: int, cell_size: float, top_scale: float, tiles: Array[Texture2D]) -> void:
	_columns = columns
	_rows = rows
	_cell_size = cell_size
	_top_scale = top_scale
	_tiles = tiles
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(cell_size * columns, visual_height())
	size = custom_minimum_size
	queue_redraw()


func boundary_scale(row_boundary: int) -> float:
	return lerpf(_top_scale, 1.0, float(row_boundary) / float(maxi(_rows, 1)))


func row_top(row: int) -> float:
	var result := 0.0
	for boundary in range(row):
		result += _cell_size * (boundary_scale(boundary) + boundary_scale(boundary + 1)) * 0.5
	return result


func row_height(row: int) -> float:
	return _cell_size * (boundary_scale(row) + boundary_scale(row + 1)) * 0.5


func visual_height() -> float:
	return row_top(_rows)


func cell_rect(column: int, row: int) -> Rect2:
	var middle_scale := (boundary_scale(row) + boundary_scale(row + 1)) * 0.5
	var width := _cell_size * middle_scale
	var board_width := _cell_size * _columns
	return Rect2(
		Vector2((board_width - board_width * middle_scale) * 0.5 + column * width, row_top(row)),
		Vector2(width, row_height(row))
	)


func set_tile(index: int, texture: Texture2D) -> void:
	if index < 0 or index >= _tiles.size() or _tiles[index] == texture:
		return
	_tiles[index] = texture
	queue_redraw()


func _draw() -> void:
	if _columns <= 0 or _rows <= 0 or _tiles.size() != _columns * _rows:
		return
	var board_width := _cell_size * _columns
	var center_x := board_width * 0.5
	var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	for row in range(_rows):
		var top_scale := boundary_scale(row)
		var bottom_scale := boundary_scale(row + 1)
		var top_y := row_top(row)
		var bottom_y := top_y + row_height(row)
		for column in range(_columns):
			var source_left := column * _cell_size - center_x
			var source_right := (column + 1) * _cell_size - center_x
			var polygon := PackedVector2Array([
				Vector2(center_x + source_left * top_scale, top_y),
				Vector2(center_x + source_right * top_scale, top_y),
				Vector2(center_x + source_right * bottom_scale, bottom_y),
				Vector2(center_x + source_left * bottom_scale, bottom_y),
			])
			draw_polygon(polygon, colors, uvs, _tiles[row * _columns + column])
