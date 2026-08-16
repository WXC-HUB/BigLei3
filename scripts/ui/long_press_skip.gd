class_name LongPressSkip
extends Control
## 长按跳过：按住不放，屏幕中间偏上浮出半透明白色水印大字「长~按~跳~过」，同时
## 其他小鸟从四条边上缓缓探出头来看热闹；按满一段时间就跳过，中途松手则全部缩
## 回去。
##
## 整段表演只由一个 [member _progress]（0～1）驱动：按住时按 1/HOLD_SECONDS 的速
## 度往上走，松手按 RELEASE_RATE 往回落。水印的横向擦除进度、小鸟探出的距离和探
## 头的倾角都是这一个值的函数，所以「按到一半松手」自然就是倒着播一遍，不需要另
## 写一套取消动画。

signal skip_triggered

## 按满多久算一次跳过。留得长，一来不会误触，二来四只鸟错开探头这段表演才走得完
## ——最后一只要到六成进度才开始动。
const HOLD_SECONDS := 2.3
## 松手回落比按下去快，取消要干脆。
const RELEASE_RATE := 2.6
## 小鸟探头的配置：各自的藏身点、探出点、探头时的倾角，以及在整段进度里从第几成
## 才开始动——错开出场，四只才不像一起被推出来的。
## 立绘是 780 见方的整只鸟，探出来的只有靠屏幕内侧的三百来像素——正好是脑袋。所以
## 左边的鸟必须朝右、右边的鸟必须朝左（朝向不对就变成探出个屁股），红尾水鸲在场景
## 里是靠 flip_h 掉头的。
const PEEKS := [
	{"node": "Black", "from": Vector2(-780.0, -100.0), "to": Vector2(-470.0, -128.0), "tilt": 6.0, "delay": 0.0},
	{"node": "Kestrel", "from": Vector2(1920.0, -140.0), "to": Vector2(1600.0, -166.0), "tilt": -5.0, "delay": 0.18},
	{"node": "Redstart", "from": Vector2(-780.0, 360.0), "to": Vector2(-380.0, 300.0), "tilt": -6.0, "delay": 0.32},
	{"node": "Woodpecker", "from": Vector2(1920.0, 390.0), "to": Vector2(1620.0, 366.0), "tilt": 5.0, "delay": 0.46},
]
## 探出来之后轻轻晃，看着才像活的。
const BOB_AMPLITUDE := 13.0
const BOB_SPEED := 2.1

@onready var hint: Control = %Hint
@onready var wipe: Control = %Wipe
@onready var birds: Control = %Birds

var _active := false
var _holding := false
var _progress := 0.0
var _fired := false
var _bob_time := 0.0
var _peek_nodes: Array[Control] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	for peek in PEEKS:
		_peek_nodes.append(birds.get_node(String(peek["node"])) as Control)
	_apply_progress()


## 开始／停止接管长按。停用时立刻把水印和小鸟收回去。
func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	_holding = false
	if not value:
		_progress = 0.0
		_fired = false
		_apply_progress()
	set_process(value)


func is_holding() -> bool:
	return _holding


## 当前的长按进度，0～1。测试和调试用。
func hold_progress() -> float:
	return _progress


func _process(delta: float) -> void:
	_bob_time += delta
	var target_delta := delta / HOLD_SECONDS if _holding else -delta * RELEASE_RATE
	_progress = clampf(_progress + target_delta, 0.0, 1.0)
	_apply_progress()
	if _progress >= 1.0 and not _fired:
		_fired = true
		_holding = false
		set_active(false)
		skip_triggered.emit()


## 用 _input 而不是 _gui_input：剧情页自己是吃鼠标的，按键也不该要求这层拿到焦点。
func _input(event: InputEvent) -> void:
	if not _active:
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
		_holding = mouse.pressed
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key != null and not key.echo:
		_holding = key.pressed
		get_viewport().set_input_as_handled()


func _apply_progress() -> void:
	# 水印：先整体淡进，再由左往右擦亮，擦满即触发。
	var fade := clampf(_progress / 0.22, 0.0, 1.0)
	hint.modulate.a = fade
	hint.pivot_offset = hint.size * 0.5
	# 顶多放到 1.0：这行字在满进度时已经贴着左右两边，再放大就要切掉头尾两个字。
	hint.scale = Vector2.ONE * lerpf(0.93, 1.0, _progress)
	wipe.size.x = hint.size.x * _progress

	birds.modulate.a = fade
	for index in _peek_nodes.size():
		var bird := _peek_nodes[index]
		var peek: Dictionary = PEEKS[index]
		var delay: float = peek["delay"]
		var local := clampf((_progress - delay) / maxf(1.0 - delay, 0.001), 0.0, 1.0)
		# 慢起：探头是「犹豫地伸出来」，不是弹出来。
		var eased := local * local * (3.0 - 2.0 * local)
		var from: Vector2 = peek["from"]
		var to: Vector2 = peek["to"]
		var bob := sin(_bob_time * BOB_SPEED + float(index) * 1.7) * BOB_AMPLITUDE * eased
		bird.position = from.lerp(to, eased) + Vector2(0.0, bob)
		bird.pivot_offset = bird.size * 0.5
		bird.rotation = deg_to_rad(float(peek["tilt"]) * eased)
