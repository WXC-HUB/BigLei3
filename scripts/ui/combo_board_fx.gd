class_name ComboBoardFx
extends Control
## 棋盘的连击表现层：盘后的热度光晕 + 沿棋盘四周炸开的烟花。
##
## 这一层画在**棋盘背后**（z_index 为负，排在面板自绘和格子之前），烟花从盘沿往外
## 炸，所以再怎么热闹也压不住盘面上的数字和标记——棋盘是解谜面，可读性优先于场面。
##
## 整块效果只有这一个节点在画，而且烟花没有逐粒子的节点或 tween：每束的火星位置
## 都是从 (种子, 序号) 现算的抛物线，所以一帧里连炸十几束也只是多几百条 draw_line。
## 配色与热度曲线走 ComboStyle，和角落那根 COMBO 柱同源。

## 烟花从盘沿再往外这么多像素起爆，免得贴着木框炸、被面板边缘切掉半朵。
const BURST_OUTSET := 26.0
## 起爆点在盘沿法线方向上的随机进深。
const BURST_DEPTH := Vector2(4.0, 58.0)

## 每束火星数：底噪 + 热度加成。底噪不能太低——「点一下就炸一下」要求第一次点击
## 就看得见，1 连那束太稀的话玩家只会觉得没反馈。上限压在这里，批量标雷时才不会
## 一帧炸出几千条线。
const SPARKS_MIN := 16
const SPARKS_HEAT_GAIN := 22
## 同时存活的烟花束上限，超了顶掉最老的。
const BURST_LIMIT := 12

const SPARK_SPEED_MIN := 265.0
const SPARK_SPEED_HEAT_GAIN := 300.0
## 火星受的重力，让每束都往下坠成烟花而不是均匀的圆环。
const SPARK_GRAVITY := 340.0
## 拖尾取多长一段时间的位移来画。
const SPARK_TRAIL_SECONDS := 0.075
## 火星只往盘外这个张角里炸。起爆点贴着盘沿，全向炸的话有一半直接被棋盘吃掉。
const SPARK_SPREAD_DEGREES := 118.0
## 所有亮色都先描一道这个暗边。背景是浅色羊皮纸，白热档（近白色）不描边就是隐形的。
const INK := Color(0.10, 0.06, 0.03, 1.0)

const BURST_LIFE_MIN := 0.62
const BURST_LIFE_HEAT_GAIN := 0.45

## 盘后光晕画在盘沿外这一圈。
const HALO_SPREAD := 52.0
## 层数越多外缘越软。每层都是一个 draw_rect，层数就是这圈光晕的「渐变精度」。
const HALO_LAYERS := 9


## 一束烟花。位置全部由 (种子, 序号) 现算，所以这里只存参数，不存粒子。
class _Burst extends RefCounted:
	var origin := Vector2.ZERO
	## 盘外方向。火星只往这一侧炸，朝内的部分会被棋盘整个盖掉。
	var normal := Vector2.UP
	var age := 0.0
	var delay := 0.0
	var life := 0.8
	var color := Color.WHITE
	var power := 0.5
	var sparks := 16
	var seed := 0

	func elapsed() -> float:
		return age - delay

	func alive() -> bool:
		return age < delay + life

	func fade() -> float:
		var t := elapsed()
		if t <= 0.0:
			return 0.0
		return clampf(1.0 - t / life, 0.0, 1.0)


var _combo := 0
var _pulse := 0.0
## 命中时光晕的瞬时爆亮，指数衰减回底值。
var _halo_flash := 0.0
## 断连时压上来的冷色。
var _break_wash := 0.0
var _bursts: Array[_Burst] = []
var _next_seed := 1


func _ready() -> void:
	# 这层盖在棋盘范围上，绝不能吃掉点击。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 负 z 让它排在父面板自绘和所有格子之前 —— 也就是画在棋盘背后。
	z_index = -1
	# 面板不裁剪子节点，所以烟花可以画到自身矩形之外、落在棋盘四周。
	clip_contents = false
	set_process(false)


func set_state(combo: int) -> void:
	_combo = maxi(combo, 0)
	_wake()


## 一次有效动作：沿盘沿炸一到几束烟花，光晕跟着爆一下。连击越高炸得越多越大。
func play_hit(combo: int) -> void:
	_combo = maxi(combo, 0)
	var heat := ComboStyle.heat(_combo)
	_halo_flash = minf(1.2, _halo_flash + 0.45 + 0.45 * heat)
	var count := 1 + int(floor(heat * 3.0))
	for i in range(count):
		var burst := _make_burst(heat)
		burst.delay = float(i) * 0.055
		_push_burst(burst)
	_wake()


## 里程碑：绕棋盘一圈的齐射，是「连击越多越强」最直观的那个回报。
func play_milestone(combo: int) -> void:
	_combo = maxi(combo, 0)
	var heat := ComboStyle.heat(_combo)
	_halo_flash = 1.4
	var count := 8 + int(round(heat * 4.0))
	for i in range(count):
		# 沿周长均匀铺开再加抖动，读起来才是「绕着盘转了一圈」而不是随机撒点。
		var burst := _make_burst(minf(1.0, heat + 0.25), (float(i) + randf() * 0.6) / float(count))
		burst.delay = float(i) * 0.05
		_push_burst(burst)
	_wake()


## 断连：烟花全灭，光晕转冷后塌下去。丢掉一串长连击不该是无声的。
func play_break(previous_combo: int) -> void:
	_combo = 0
	_halo_flash = 0.0
	_bursts.clear()
	if previous_combo > 0:
		_break_wash = 0.5 + 0.5 * ComboStyle.heat(previous_combo)
	_wake()


func reset_visuals() -> void:
	_combo = 0
	_halo_flash = 0.0
	_break_wash = 0.0
	_bursts.clear()
	queue_redraw()
	set_process(false)


## `perimeter` 给定时按这个比例取盘沿上的点（里程碑齐射用），否则随机。
func _make_burst(heat: float, perimeter: float = -1.0) -> _Burst:
	var burst := _Burst.new()
	burst.origin = _perimeter_point(perimeter if perimeter >= 0.0 else randf())
	burst.normal = _outward_normal(burst.origin)
	burst.color = ComboStyle.board_color(_combo, _pulse * 0.25 + randf() * 0.12)
	burst.power = clampf(heat, 0.0, 1.0)
	burst.sparks = SPARKS_MIN + int(round(float(SPARKS_HEAT_GAIN) * burst.power))
	burst.life = BURST_LIFE_MIN + BURST_LIFE_HEAT_GAIN * burst.power
	burst.seed = _next_seed
	_next_seed += 1
	return burst


## 盘沿外一点的起爆位置。`t` 是绕棋盘一圈的比例（0 = 顶边中点，顺时针）。
func _perimeter_point(t: float) -> Vector2:
	var rect := Rect2(Vector2.ZERO, size).grow(BURST_OUTSET)
	var perimeter := 2.0 * (rect.size.x + rect.size.y)
	var walked := fposmod(t, 1.0) * perimeter
	# 从顶边中点起步顺时针走，和角落那根柱子的能量读法保持同一个起点。
	var start := rect.size.x * 0.5
	walked = fposmod(walked + start, perimeter)
	var point := rect.position
	var normal := Vector2.UP
	if walked < rect.size.x:
		point += Vector2(walked, 0.0)
		normal = Vector2.UP
	elif walked < rect.size.x + rect.size.y:
		point += Vector2(rect.size.x, walked - rect.size.x)
		normal = Vector2.RIGHT
	elif walked < 2.0 * rect.size.x + rect.size.y:
		point += Vector2(rect.size.x - (walked - rect.size.x - rect.size.y), rect.size.y)
		normal = Vector2.DOWN
	else:
		point += Vector2(0.0, rect.size.y - (walked - 2.0 * rect.size.x - rect.size.y))
		normal = Vector2.LEFT
	return point + normal * randf_range(BURST_DEPTH.x, BURST_DEPTH.y)


## 起爆点落在棋盘外，法线就是它所在的那条边朝外的方向。
func _outward_normal(point: Vector2) -> Vector2:
	if point.y < 0.0:
		return Vector2.UP
	if point.y > size.y:
		return Vector2.DOWN
	if point.x > size.x:
		return Vector2.RIGHT
	return Vector2.LEFT


func _push_burst(burst: _Burst) -> void:
	_bursts.append(burst)
	while _bursts.size() > BURST_LIMIT:
		_bursts.pop_front()


func _wake() -> void:
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	_halo_flash = lerpf(_halo_flash, 0.0, 1.0 - exp(-5.0 * delta))
	_break_wash = lerpf(_break_wash, 0.0, 1.0 - exp(-2.6 * delta))

	var index := _bursts.size() - 1
	while index >= 0:
		var burst := _bursts[index]
		burst.age += delta
		if not burst.alive():
			_bursts.remove_at(index)
		index -= 1

	queue_redraw()
	# 完全冷下来就停掉 _process，空闲时一帧成本都不留。
	if _combo <= 0 and _bursts.is_empty() and _halo_flash < 0.01 and _break_wash < 0.01:
		set_process(false)


func _draw() -> void:
	_draw_halo()
	for burst in _bursts:
		_draw_burst(burst)


## 盘后光晕：连击活着的时候棋盘边缘一直透着光，热度越高越亮、喘得越快。
func _draw_halo() -> void:
	var glow := ComboStyle.heat(_combo) * 0.55 + _halo_flash
	if _combo > 0:
		glow += 0.12
	if glow <= 0.01 and _break_wash <= 0.01:
		return
	var color := ComboStyle.board_color(_combo, _pulse * 0.25) if _combo > 0 else ComboStyle.BREAK_COLOR
	if _break_wash > 0.01:
		color = color.lerp(ComboStyle.BREAK_COLOR, clampf(_break_wash, 0.0, 1.0))
		glow = maxf(glow, _break_wash * 0.8)
	var breathe := 0.84 + 0.16 * sin(_pulse * (3.6 + 2.2 * float(ComboStyle.tier_for(_combo))))
	glow = clampf(glow * breathe, 0.0, 1.6)
	var base := Rect2(Vector2.ZERO, size)
	# 暗底先垫一圈：白热档的光晕本身就接近背景色，不垫底整层会直接消失。
	for bed in range(3):
		var bed_spread := HALO_SPREAD * (0.72 - 0.22 * float(bed))
		draw_rect(
			base.grow(bed_spread),
			Color(INK.r, INK.g, INK.b, clampf(glow * 0.12, 0.0, 0.22)),
			true
		)
	# 再由外向内一层层叠上去，累加出向盘沿收紧的渐变。
	# 每层的 alpha 也跟着往外递减，否则最外那一层会留下一道硬邦邦的矩形边。
	for layer in range(HALO_LAYERS):
		var depth := float(layer + 1) / float(HALO_LAYERS)
		var spread := HALO_SPREAD * (1.0 - depth) + 4.0
		var alpha := glow * 0.085 * (0.25 + 0.75 * depth)
		if alpha <= 0.004:
			continue
		draw_rect(base.grow(spread), Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0)), true)


func _draw_burst(burst: _Burst) -> void:
	var t := burst.elapsed()
	if t <= 0.0:
		return
	var fade := burst.fade()
	if fade <= 0.01:
		return
	# 起爆瞬间的核心闪光，给烟花一个「炸开」的起手而不是凭空出现一圈点。
	if t < 0.14:
		var flash := 1.0 - t / 0.14
		var radius := 17.0 + 27.0 * burst.power * flash
		draw_circle(burst.origin, radius + 3.0, Color(INK.r, INK.g, INK.b, 0.40 * flash))
		draw_circle(burst.origin, radius, Color(1.0, 0.97, 0.88, 0.85 * flash))

	var speed := SPARK_SPEED_MIN + SPARK_SPEED_HEAT_GAIN * burst.power
	var trail := minf(SPARK_TRAIL_SECONDS, t)
	var width := 2.4 + 2.6 * burst.power
	var spread := deg_to_rad(SPARK_SPREAD_DEGREES)
	var base_angle := burst.normal.angle()
	var count := burst.sparks
	var heads := PackedVector2Array()
	var tails := PackedVector2Array()
	var alphas := PackedFloat32Array()
	heads.resize(count)
	tails.resize(count)
	alphas.resize(count)
	for i in range(count):
		var angle := base_angle + (_hash01(burst.seed, i) * 2.0 - 1.0) * spread
		# 每颗火星自己的初速差，炸开后才有层次而不是一个完美的扇面。
		var spark_speed := speed * (0.55 + 0.45 * _hash01(burst.seed, i + 977))
		var direction := Vector2(cos(angle), sin(angle))
		heads[i] = _spark_position(burst.origin, direction, spark_speed, t)
		tails[i] = _spark_position(burst.origin, direction, spark_speed, t - trail)
		alphas[i] = pow(fade, 1.4) * (0.6 + 0.4 * _hash01(burst.seed, i + 1861))

	# 两趟画：先把所有暗边描完，再叠亮线。混在一趟里，后画的暗边会啃掉前一颗的亮部。
	for i in range(count):
		draw_line(tails[i], heads[i], Color(INK.r, INK.g, INK.b, alphas[i] * 0.7), width + 2.6, true)
	for i in range(count):
		var color := Color(burst.color.r, burst.color.g, burst.color.b, alphas[i])
		draw_line(tails[i], heads[i], color, width, true)
		# 火星头部的白心，给每条拖尾一个亮点收口。
		draw_circle(heads[i], width * 0.75, Color(1.0, 0.97, 0.88, alphas[i] * 0.9))


## 抛物线：初速直线 + 重力下坠。没有逐粒子状态，任意时刻都能现算。
func _spark_position(origin: Vector2, direction: Vector2, speed: float, t: float) -> Vector2:
	var clamped := maxf(t, 0.0)
	return origin + direction * speed * clamped + Vector2(0.0, SPARK_GRAVITY * clamped * clamped * 0.5)


## 由 (种子, 序号) 现算的 0-1 伪随机数，保证同一颗火星每帧都落在同一条轨迹上。
static func _hash01(seed_value: int, index: int) -> float:
	var h := (seed_value * 73856093) ^ (index * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 1000003) / 1000003.0
