class_name ScenerySway
extends Control

const SWAY_SHADER := preload("res://shaders/tree_sway.gdshader")

@export_range(0.0, 8.0, 0.1) var amplitude_pixels := 4.0
@export_range(0.1, 2.0, 0.05) var angular_speed := 0.72
@export_range(0.0, 0.6, 0.01) var fixed_bottom_ratio := 0.34
@export_range(0.1, 0.6, 0.01) var transition_height := 0.34
@export_range(1.0, 10.0, 0.5) var click_shake_pixels := 4.0

var _trees: Array[TextureRect] = []
var _texture_images: Dictionary = {}
var _active_tweens: Dictionary = {}


func _ready() -> void:
	_apply_sway_materials(self)


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	for index in range(_trees.size() - 1, -1, -1):
		var tree := _trees[index]
		if is_instance_valid(tree) and tree.is_visible_in_tree() and _is_opaque_at(tree, mouse_event.position):
			_play_click_shake(tree)
			return


func _apply_sway_materials(parent: Node) -> void:
	for child in parent.get_children():
		if child is TextureRect:
			var tree := child as TextureRect
			_trees.append(tree)
			var identity := hash(String(tree.get_path()))
			var material := ShaderMaterial.new()
			material.shader = SWAY_SHADER
			material.set_shader_parameter("amplitude_px", amplitude_pixels)
			material.set_shader_parameter(
				"angular_speed",
				angular_speed * (0.82 + float(posmod(identity, 37)) / 100.0)
			)
			material.set_shader_parameter(
				"phase",
				float(posmod(identity, 1000)) / 1000.0 * TAU
			)
			material.set_shader_parameter("fixed_bottom_ratio", fixed_bottom_ratio)
			material.set_shader_parameter("transition_height", transition_height)
			tree.material = material
		_apply_sway_materials(child)


func _is_opaque_at(tree: TextureRect, viewport_point: Vector2) -> bool:
	if tree.texture == null or tree.size.x <= 0.0 or tree.size.y <= 0.0:
		return false
	var local_point := tree.get_global_transform_with_canvas().affine_inverse() * viewport_point
	var texture_size := tree.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return false
	var fit_scale := minf(tree.size.x / texture_size.x, tree.size.y / texture_size.y)
	var drawn_size := texture_size * fit_scale
	var drawn_offset := (tree.size - drawn_size) * 0.5
	var drawn_rect := Rect2(drawn_offset, drawn_size)
	if not drawn_rect.has_point(local_point):
		return false
	var texture_key := tree.texture.get_instance_id()
	if not _texture_images.has(texture_key):
		_texture_images[texture_key] = tree.texture.get_image()
	var image := _texture_images[texture_key] as Image
	if image == null or image.is_empty():
		return false
	var uv := (local_point - drawn_offset) / drawn_size
	var pixel := Vector2i(
		clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1),
		clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1)
	)
	return image.get_pixelv(pixel).a > 0.12


func _play_click_shake(tree: TextureRect) -> void:
	var tree_id := tree.get_instance_id()
	if _active_tweens.has(tree_id):
		var previous := _active_tweens[tree_id] as Tween
		if previous != null and previous.is_valid():
			previous.kill()
	var material := tree.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("click_strength", click_shake_pixels)
	var tween := create_tween()
	_active_tweens[tree_id] = tween
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		_set_click_strength.bind(material),
		click_shake_pixels,
		0.0,
		0.30
	)
	tween.finished.connect(_finish_click_shake.bind(material, tree_id))


func _set_click_strength(value: float, material: ShaderMaterial) -> void:
	material.set_shader_parameter("click_strength", value)


func _finish_click_shake(material: ShaderMaterial, tree_id: int) -> void:
	if is_instance_valid(material):
		material.set_shader_parameter("click_strength", 0.0)
	_active_tweens.erase(tree_id)
