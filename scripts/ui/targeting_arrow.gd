class_name TargetingArrow
extends Control

var start_point := Vector2.ZERO
var end_point := Vector2.ZERO
var valid_target := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_aim(from_global: Vector2, to_global: Vector2, is_valid: bool) -> void:
	start_point = get_global_transform().affine_inverse() * from_global
	end_point = get_global_transform().affine_inverse() * to_global
	valid_target = is_valid
	queue_redraw()


func _draw() -> void:
	var delta := end_point - start_point
	var length := delta.length()
	if length < 20.0:
		return
	var direction := delta / length
	var normal := Vector2(-direction.y, direction.x)
	var bend := normal * minf(length * 0.14, 54.0)
	var points := PackedVector2Array()
	for step in range(25):
		var t := step / 24.0
		var curved := start_point.lerp(end_point, t) + bend * sin(t * PI)
		points.append(curved)
	var color := Color("ffd45c") if valid_target else Color("df6555")
	draw_polyline(points, Color(0.13, 0.06, 0.03, 0.62), 13.0, true)
	draw_polyline(points, color, 7.0, true)
	var tip_direction := (points[-1] - points[-2]).normalized()
	var tip_normal := Vector2(-tip_direction.y, tip_direction.x)
	var head := PackedVector2Array([
		end_point,
		end_point - tip_direction * 28.0 + tip_normal * 15.0,
		end_point - tip_direction * 28.0 - tip_normal * 15.0,
	])
	draw_colored_polygon(head, color)
	draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[0]]), Color("4a2115"), 4.0, true)
