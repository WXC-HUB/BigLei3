class_name CursorFx
extends Control
## 鼠标光标的拖尾与点击涟漪。
##
## 全部靠一次 _draw 画完：不生成子节点、不用粒子、不做逐帧分配（顶点缓冲全部复用），
## 涟漪走固定大小的对象池，最多同屏 MAX_RIPPLES 发；鼠标停稳且涟漪播完后自动关掉
## _process，闲置时零开销。低端设备可以打开 reduced_quality 砍掉外层辉光、描边、
## 内环和火花，满足《项目约束》里"高频特效必须设上限、可池化、可降级"的要求。

## 低性能设备/低端浏览器可以打开：只保留拖尾主体和主涟漪环。
static var reduced_quality := false

const TRAIL_POINTS := 14
## 每一节追赶上一节的速度，指数平滑，收拢的手感不受帧率影响。越大越贴手、拖尾越短。
const TRAIL_FOLLOW_SPEED := 34.0
## 每一节最多拉开这么远。日常移动速度就会顶到这个上限，于是拖尾长度锁定在
## 约 TRAIL_POINTS × 这个值，既不会被甩成半个屏幕，也不会因为帧率不同忽长忽短。
const TRAIL_MAX_SEGMENT := 18.0
## 拖尾的浓度按"头尾拉开的距离"给：鼠标停下时自己收干净，不会留一坨在屏幕上。
const TRAIL_FULL_SPREAD := 70.0
## 头尾距离小于这个值就认为拖尾已经收拢，可以休眠。
const TRAIL_SLEEP_SPREAD := 0.6
## 短于这个长度的一节直接跳过，避免画出退化的四边形。
const MIN_SEGMENT_SQUARED := 0.16
## 单帧位移超过 500 逻辑像素按"瞬移"处理，直接把拖尾归位。
const TRAIL_TELEPORT_SQUARED := 250000.0
## 半宽，单位是物理像素（见 _pixel_scale）。光标圆点直径约 20 物理像素，
## 拖尾略窄一点，读起来才像是从圆点后面拖出来的。
const TRAIL_HEAD_HALF_WIDTH := 7.0
const TRAIL_TAPER := 0.75
## 外层琥珀色辉光更宽更淡，内层奶白核心更窄更实：两层叠出"发光"的读感，
## 在亮木纹和暗面板上都能看清。
const TRAIL_GLOW_WIDTH_SCALE := 3.2
const TRAIL_HEAD_COLOR := Color(1.0, 0.97, 0.87, 0.95)
const TRAIL_TAIL_COLOR := Color(0.97, 0.76, 0.32, 0.0)
const TRAIL_GLOW_HEAD_COLOR := Color(1.0, 0.72, 0.3, 0.32)
const TRAIL_GLOW_TAIL_COLOR := Color(0.94, 0.55, 0.2, 0.0)

const MAX_RIPPLES := 5
const RIPPLE_DURATION := 0.46
## 涟漪半径同样按物理像素给定，跟着光标圆点走而不是跟着窗口缩放走。
const RIPPLE_START_RADIUS := 9.0
const RIPPLE_END_RADIUS := 46.0
const RIPPLE_WIDTH := 5.0
const RIPPLE_INNER_DELAY := 0.08
const RIPPLE_FLASH_TIME := 0.28
const RIPPLE_SPARK_COUNT := 6
## 左键翻格用暖金，右键插旗用封印环的青色，和 cell_fx 的语汇保持一致。
const RIPPLE_LEFT_TINT := Color(1.0, 0.87, 0.46)
const RIPPLE_RIGHT_TINT := Color(0.58, 0.94, 0.95)
const RIPPLE_OTHER_TINT := Color(0.96, 0.93, 0.82)


## 一发涟漪。池子里的实例反复使用，点击再快也不会产生新对象。
class Ripple:
	var position := Vector2.ZERO
	var tint := Color.WHITE
	var age := 0.0
	var spin := 0.0
	var alive := false


var _trail := PackedVector2Array()
var _segment_normals := PackedVector2Array()
var _ripples: Array[Ripple] = []
var _next_ripple := 0
var _trail_spread := 0.0
var _pointer_override := false
var _pointer_position := Vector2.ZERO
## 物理像素换算成逻辑坐标的系数，每帧刷新一次。
var _pixel_scale := 1.0
# 四边形顶点缓冲复用，_draw 里不再新建数组。
var _quad := PackedVector2Array()
var _quad_colors := PackedColorArray()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 顿帧（Engine.time_scale）和暂停都不该让光标反馈跟着卡住。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_trail.resize(TRAIL_POINTS)
	_segment_normals.resize(TRAIL_POINTS - 1)
	_quad.resize(4)
	_quad_colors.resize(4)
	for _index in range(MAX_RIPPLES):
		_ripples.append(Ripple.new())
	_reset_trail(_pointer())
	set_process(false)


# ---------------------------------------------------------------------------
# 对外接口
# ---------------------------------------------------------------------------


## 在指定位置放一发点击涟漪。对外暴露是为了让教学演示或测试直接触发。
func emit_click(local_position: Vector2, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	# 池子满了就顶掉最老的一发：同屏数量恒定，点得再快也不会堆积。
	var ripple := _ripples[_next_ripple]
	_next_ripple = (_next_ripple + 1) % MAX_RIPPLES
	ripple.position = local_position
	ripple.tint = _ripple_tint(button_index)
	ripple.age = 0.0
	# 火花的朝向由坐标推出来，既有随机感又不动用会影响可复现性的随机源。
	ripple.spin = fposmod(local_position.x * 0.031 + local_position.y * 0.017, TAU)
	ripple.alive = true
	_wake()


## 当前还在播的涟漪数量。
func active_ripple_count() -> int:
	var count := 0
	for ripple in _ripples:
		if ripple.alive:
			count += 1
	return count


## 拖尾当前拉开的长度，0 表示已经完全收拢在光标上。
func trail_spread() -> float:
	return _trail_spread


## 截图工具和自动化测试用：直接喂一个指针坐标，不再读真实鼠标。
## 无头环境里没有鼠标事件，只有这样才能把拖尾推到有形状的状态去验证。
func drive_pointer(local_position: Vector2) -> void:
	_pointer_override = true
	_pointer_position = local_position
	_wake()


## 交还给真实鼠标。
func follow_real_pointer() -> void:
	_pointer_override = false


# ---------------------------------------------------------------------------
# 输入与推进
# ---------------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	# 只是旁听：不调用 accept_event，输入照常流给下面的 UI 和棋盘。
	if event is InputEventMouseMotion:
		_wake()
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	# 滚轮也是"按键"，但它不该产生点击涟漪。
	if button.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		return
	emit_click(get_local_mouse_position(), button.button_index)


func _process(delta: float) -> void:
	# 命中顿帧会把 delta 压到 5%，光标反馈必须走真实时间，否则拖尾会黏在原地。
	var step := delta / maxf(Engine.time_scale, 0.01)
	_pixel_scale = _viewport_pixel_scale()
	var trailing := _advance_trail(step)
	var rippling := _advance_ripples(step)
	queue_redraw()
	if not trailing and not rippling:
		# 收干净了就彻底停下：闲置的光标不占一帧预算。
		set_process(false)


func _wake() -> void:
	if not is_processing():
		set_process(true)


func _reset_trail(origin: Vector2) -> void:
	for index in range(TRAIL_POINTS):
		_trail[index] = origin
	_trail_spread = 0.0


func _pointer() -> Vector2:
	return _pointer_position if _pointer_override else get_local_mouse_position()


func _advance_trail(step: float) -> bool:
	var target := _pointer()
	# 一帧跨了大半个屏幕只可能是切窗口回来或者程序里搬了指针，这种"瞬移"不该
	# 拖出一条横贯画面的光带，直接把整条拖尾归位。
	if _trail[0].distance_squared_to(target) > TRAIL_TELEPORT_SQUARED:
		_reset_trail(target)
		return false
	_trail[0] = target
	var follow := 1.0 - exp(-TRAIL_FOLLOW_SPEED * step)
	var spread := 0.0
	for index in range(1, TRAIL_POINTS):
		var lead := _trail[index - 1]
		var point := _trail[index].lerp(lead, follow)
		var offset := point - lead
		var distance := offset.length()
		if distance > TRAIL_MAX_SEGMENT:
			point = lead + offset / distance * TRAIL_MAX_SEGMENT
		_trail[index] = point
		spread = maxf(spread, point.distance_to(target))
	_trail_spread = spread
	return spread > TRAIL_SLEEP_SPREAD


func _advance_ripples(step: float) -> bool:
	var alive := false
	for ripple in _ripples:
		if not ripple.alive:
			continue
		ripple.age += step
		if ripple.age >= RIPPLE_DURATION:
			ripple.alive = false
			continue
		alive = true
	return alive


func _ripple_tint(button_index: int) -> Color:
	match button_index:
		MOUSE_BUTTON_LEFT:
			return RIPPLE_LEFT_TINT
		MOUSE_BUTTON_RIGHT:
			return RIPPLE_RIGHT_TINT
		_:
			return RIPPLE_OTHER_TINT


## 光标圆点是操作系统级的贴图，不跟着 canvas_items 拉伸；特效尺寸按物理像素给定
## 再换算回逻辑坐标，窗口拉大拉小时才不会和圆点脱节。
func _viewport_pixel_scale() -> float:
	var viewport := get_viewport()
	if viewport == null:
		return 1.0
	var scale := viewport.get_final_transform().get_scale().x
	if scale <= 0.001:
		return 1.0
	return 1.0 / scale


# ---------------------------------------------------------------------------
# 绘制
# ---------------------------------------------------------------------------


func _draw() -> void:
	_draw_trail()
	for ripple in _ripples:
		if ripple.alive:
			_draw_ripple(ripple)


func _draw_trail() -> void:
	var intensity := clampf(_trail_spread / TRAIL_FULL_SPREAD, 0.0, 1.0)
	if intensity <= 0.02:
		return
	_rebuild_trail_normals()
	if not reduced_quality:
		_draw_ribbon(TRAIL_GLOW_WIDTH_SCALE, TRAIL_GLOW_HEAD_COLOR, TRAIL_GLOW_TAIL_COLOR, intensity)
	_draw_ribbon(1.0, TRAIL_HEAD_COLOR, TRAIL_TAIL_COLOR, intensity)


## 一节一条法线，而不是把相邻两段的法线插值成"斜接"：斜接虽然接缝更平滑，
## 但急转弯时两端法线会倒向，四边形拧成蝴蝶结，draw_polygon 当场三角化失败。
## 每节各用各的法线画出来的一定是矩形，永远退化不了。
func _rebuild_trail_normals() -> void:
	var last_normal := Vector2.UP
	for index in range(TRAIL_POINTS - 1):
		var offset := _trail[index + 1] - _trail[index]
		var length := offset.length()
		if length > 0.35:
			last_normal = Vector2(-offset.y, offset.x) / length
		_segment_normals[index] = last_normal


func _draw_ribbon(width_scale: float, head_color: Color, tail_color: Color, intensity: float) -> void:
	for index in range(TRAIL_POINTS - 1):
		# 相邻两点重合时矩形会退化成一条线，同样会三角化失败。
		if _trail[index].distance_squared_to(_trail[index + 1]) < MIN_SEGMENT_SQUARED:
			continue
		var head_ratio := float(index) / float(TRAIL_POINTS - 1)
		var tail_ratio := float(index + 1) / float(TRAIL_POINTS - 1)
		var normal := _segment_normals[index]
		var head_normal := normal * _trail_half_width(head_ratio) * width_scale
		var tail_normal := normal * _trail_half_width(tail_ratio) * width_scale
		var head_point := _trail[index]
		var tail_point := _trail[index + 1]
		_quad[0] = head_point + head_normal
		_quad[1] = tail_point + tail_normal
		_quad[2] = tail_point - tail_normal
		_quad[3] = head_point - head_normal
		var near := _trail_color(head_color, tail_color, head_ratio, intensity)
		var far := _trail_color(head_color, tail_color, tail_ratio, intensity)
		_quad_colors[0] = near
		_quad_colors[1] = far
		_quad_colors[2] = far
		_quad_colors[3] = near
		draw_polygon(_quad, _quad_colors)


## 尾端保留一丝宽度：收到 0 会让最后一节的两个顶点重合，四边形退化成三角形，
## 三角化就会失败。这一丝的透明度已经是 0，画面上看不出来。
func _trail_half_width(ratio: float) -> float:
	return maxf(TRAIL_HEAD_HALF_WIDTH * pow(1.0 - ratio, TRAIL_TAPER), 0.4) * _pixel_scale


func _trail_color(head_color: Color, tail_color: Color, ratio: float, intensity: float) -> Color:
	var color := head_color.lerp(tail_color, ratio)
	color.a *= intensity
	return color


func _draw_ripple(ripple: Ripple) -> void:
	var progress := clampf(ripple.age / RIPPLE_DURATION, 0.0, 1.0)
	# 外扩用三次缓出：起手最快，读起来才像是被"弹"出去的。
	var expansion := 1.0 - pow(1.0 - progress, 3.0)
	var fade := pow(1.0 - progress, 1.15)
	var radius := lerpf(RIPPLE_START_RADIUS, RIPPLE_END_RADIUS, expansion) * _pixel_scale
	var width := maxf(RIPPLE_WIDTH * (1.0 - progress * 0.6), 1.0) * _pixel_scale
	var tint := ripple.tint
	var segments := _arc_segments(radius)
	# 先垫一圈深色描边。整套美术都是带描边的卡通风，亮木纹背景上没有这一圈，
	# 暖金的环会直接糊进背景里。
	if not reduced_quality:
		draw_arc(
			ripple.position,
			radius,
			0.0,
			TAU,
			segments,
			Color(0.28, 0.2, 0.12, 0.34 * fade),
			width + 3.0 * _pixel_scale,
			true
		)
	draw_arc(
		ripple.position,
		radius,
		0.0,
		TAU,
		segments,
		Color(tint.r, tint.g, tint.b, fade),
		width,
		true
	)

	# 起手一瞬间的白心，负责"按下去了"的那一帧。
	if progress < RIPPLE_FLASH_TIME:
		var flash := 1.0 - progress / RIPPLE_FLASH_TIME
		draw_circle(
			ripple.position,
			15.0 * flash * _pixel_scale,
			Color(1.0, 0.98, 0.9, 0.6 * flash * flash)
		)

	if reduced_quality:
		return

	# 慢半拍的内环，让涟漪有厚度而不是一条孤零零的线。
	if ripple.age > RIPPLE_INNER_DELAY:
		var inner_progress := clampf(
			(ripple.age - RIPPLE_INNER_DELAY) / (RIPPLE_DURATION - RIPPLE_INNER_DELAY), 0.0, 1.0
		)
		var inner_expansion := 1.0 - pow(1.0 - inner_progress, 3.0)
		var inner_radius := lerpf(
			RIPPLE_START_RADIUS * 0.5, RIPPLE_END_RADIUS * 0.66, inner_expansion
		) * _pixel_scale
		draw_arc(
			ripple.position,
			inner_radius,
			0.0,
			TAU,
			_arc_segments(inner_radius),
			Color(1.0, 0.99, 0.94, 0.5 * pow(1.0 - inner_progress, 2.0)),
			maxf(2.4 * (1.0 - inner_progress) * _pixel_scale, 1.0),
			true
		)

	# 放射火花：只在前半程出现，收尾时已经追不上外环，正好读作"炸开后散掉"。
	if progress >= 0.62:
		return
	var spark_fade := 1.0 - progress / 0.62
	var spark_color := Color(tint.r, tint.g, tint.b, 0.9 * spark_fade)
	var spark_inner := radius * 0.94
	var spark_outer := spark_inner + 16.0 * spark_fade * _pixel_scale
	var spark_width := maxf(3.0 * spark_fade * _pixel_scale, 1.2)
	for index in range(RIPPLE_SPARK_COUNT):
		var angle := ripple.spin + TAU * float(index) / float(RIPPLE_SPARK_COUNT)
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(
			ripple.position + direction * spark_inner,
			ripple.position + direction * spark_outer,
			spark_color,
			spark_width,
			true
		)


## 半径越小需要的分段越少；上限锁住，避免大圈时白白提交一堆顶点。
func _arc_segments(radius: float) -> int:
	return clampi(int(radius * 0.6), 12, 40)
