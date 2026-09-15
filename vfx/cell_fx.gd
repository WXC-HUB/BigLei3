extends RefCounted
## 棋盘格关键事件特效库：翻出雷的预警、踩雷爆炸、正确标记雷的封印爆发。
##
## 全部特效为程序化生成，不依赖外部素材，兼容 GL Compatibility 渲染器。
## 每个特效只创建一个自毁根节点，并统一登记在 BURST_GROUP 中：
## 同屏数量超过软上限自动降级为精简版，超过硬上限直接跳过，
## 满足《项目约束》里“高频特效必须设上限、可池化、可降级”的要求。

const BURST_GROUP := "cell_fx_burst"
const SOFT_BURST_LIMIT := 7
const HARD_BURST_LIMIT := 16

enum { GRADE_FULL, GRADE_LITE, GRADE_SKIP }

## 低性能设备可以打开这个开关，把所有爆发降级为“核心 + 冲击波”。
static var reduced_quality := false

static var _dot_texture: Texture2D = null


# ---------------------------------------------------------------------------
# 对外接口
# ---------------------------------------------------------------------------


## 翻牌翻出雷的瞬间：一次低成本的红色预警脉冲，先于爆炸建立紧张感。
static func play_mine_alert(layer: Control, center: Vector2) -> void:
	var grade := _grade(layer)
	if grade == GRADE_SKIP:
		return
	var root := _spawn_root(layer, center, 0.7)
	if root == null:
		return

	var warn := Color(1.0, 0.36, 0.24, 0.9)
	for pulse_index in range(2 if grade == GRADE_FULL else 1):
		var ring := ShockRing.new()
		ring.color = warn
		ring.radius = 14.0
		ring.thickness = 9.0
		root.add_child(ring)
		var delay := float(pulse_index) * 0.13
		var tween := root.create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ring, "radius", 118.0, 0.36).set_delay(delay)
		tween.tween_property(ring, "thickness", 3.0, 0.36).set_delay(delay)
		tween.tween_property(ring, "modulate:a", 0.0, 0.3).set_delay(delay + 0.08)

	var glow := RadialGlow.new()
	glow.color = Color(1.0, 0.3, 0.2, 0.6)
	glow.radius = 10.0
	glow.falloff = 1.6
	root.add_child(glow)
	var glow_tween := root.create_tween().set_parallel(true)
	glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	glow_tween.tween_property(glow, "radius", 92.0, 0.22)
	glow_tween.tween_property(glow, "modulate:a", 0.0, 0.34).set_delay(0.1)


## 踩雷爆炸：白热核心、双层冲击波、放射光刺、火星、余烬、浓烟与焦土碎块。
static func play_mine_explosion(layer: Control, center: Vector2, power: float = 1.0) -> void:
	var grade := _grade(layer)
	if grade == GRADE_SKIP:
		return
	var root := _spawn_root(layer, center, 1.6)
	if root == null:
		return
	var lite := grade == GRADE_LITE
	var boost := clampf(power, 0.6, 2.0)

	# 白热核心：最亮、最短，负责“命中”的那一帧。
	var core := RadialGlow.new()
	core.color = Color(1.0, 0.97, 0.86, 1.0)
	core.radius = 6.0
	root.add_child(core)
	var core_tween := root.create_tween().set_parallel(true)
	core_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	core_tween.tween_property(core, "radius", 152.0 * boost, 0.15)
	core_tween.tween_property(core, "modulate:a", 0.0, 0.24).set_delay(0.06)

	# 橙色火球在核心熄灭后继续撑住画面。
	var fireball := RadialGlow.new()
	fireball.color = Color(1.0, 0.52, 0.2, 0.85)
	fireball.radius = 18.0
	fireball.falloff = 1.9
	root.add_child(fireball)
	var fireball_tween := root.create_tween().set_parallel(true)
	fireball_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fireball_tween.tween_property(fireball, "radius", 182.0 * boost, 0.3)
	fireball_tween.tween_property(fireball, "modulate:a", 0.0, 0.36).set_delay(0.12)

	# 主冲击波：又快又薄；第二道橙环稍慢，制造层次。
	var shock := ShockRing.new()
	shock.color = Color(1.0, 0.95, 0.84, 0.95)
	shock.radius = 18.0
	shock.thickness = 15.0
	root.add_child(shock)
	var shock_tween := root.create_tween().set_parallel(true)
	shock_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	shock_tween.tween_property(shock, "radius", 252.0 * boost, 0.32)
	shock_tween.tween_property(shock, "thickness", 5.0, 0.32)
	shock_tween.tween_property(shock, "modulate:a", 0.0, 0.22).set_delay(0.12)

	if not lite:
		var ember_ring := ShockRing.new()
		ember_ring.color = Color(1.0, 0.45, 0.16, 0.8)
		ember_ring.radius = 10.0
		ember_ring.thickness = 10.0
		root.add_child(ember_ring)
		var ember_tween := root.create_tween().set_parallel(true)
		ember_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ember_tween.tween_property(ember_ring, "radius", 198.0 * boost, 0.44).set_delay(0.05)
		ember_tween.tween_property(ember_ring, "thickness", 3.0, 0.44).set_delay(0.05)
		ember_tween.tween_property(ember_ring, "modulate:a", 0.0, 0.3).set_delay(0.19)

		# 压扁的地面冲击环，让爆炸贴住棋盘而不是浮在空中。
		var ground_ring := ShockRing.new()
		ground_ring.color = Color(0.86, 0.68, 0.42, 0.7)
		ground_ring.radius = 22.0
		ground_ring.thickness = 13.0
		ground_ring.squash = 0.34
		ground_ring.position = Vector2(0.0, 18.0)
		root.add_child(ground_ring)
		var ground_tween := root.create_tween().set_parallel(true)
		ground_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ground_tween.tween_property(ground_ring, "radius", 244.0 * boost, 0.5)
		ground_tween.tween_property(ground_ring, "thickness", 4.0, 0.5)
		ground_tween.tween_property(ground_ring, "modulate:a", 0.0, 0.32).set_delay(0.18)

	# 放射光刺：爆炸的“形状记忆”，比纯圆环更有冲击力。
	var spikes := SpikeBurst.new()
	spikes.color = Color(1.0, 0.86, 0.55, 0.95)
	spikes.count = 8
	spikes.inner = 8.0
	spikes.outer = 30.0
	spikes.thickness = 15.0
	spikes.rotation = float(int(center.x + center.y)) * 0.37
	root.add_child(spikes)
	var spike_tween := root.create_tween().set_parallel(true)
	spike_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	spike_tween.tween_property(spikes, "inner", 148.0 * boost, 0.34)
	spike_tween.tween_property(spikes, "outer", 312.0 * boost, 0.3)
	spike_tween.tween_property(spikes, "thickness", 3.0, 0.3)
	spike_tween.tween_property(spikes, "modulate:a", 0.0, 0.2).set_delay(0.12)

	# 火星
	var sparks := _make_particles(32 if not lite else 14, 0.6)
	sparks.texture = _soft_dot()
	sparks.lifetime_randomness = 0.4
	sparks.direction = Vector2(0.0, -1.0)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 300.0 * boost
	sparks.initial_velocity_max = 720.0 * boost
	sparks.gravity = Vector2(0.0, 980.0)
	sparks.damping_min = 20.0
	sparks.damping_max = 90.0
	sparks.scale_amount_min = 0.45
	sparks.scale_amount_max = 0.95
	sparks.scale_amount_curve = _fade_curve()
	sparks.color_ramp = _fire_ramp()
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 14.0
	root.add_child(sparks)

	if not lite:
		# 余烬：慢、飘、寿命长，负责爆炸的尾韵。
		var embers := _make_particles(10, 1.1)
		embers.texture = _soft_dot()
		embers.lifetime_randomness = 0.5
		embers.direction = Vector2(0.0, -1.0)
		embers.spread = 70.0
		embers.initial_velocity_min = 70.0
		embers.initial_velocity_max = 230.0
		embers.gravity = Vector2(0.0, -90.0)
		embers.damping_min = 8.0
		embers.damping_max = 24.0
		embers.scale_amount_min = 0.24
		embers.scale_amount_max = 0.5
		embers.scale_amount_curve = _pulse_curve()
		embers.color_ramp = _ember_ramp()
		embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		embers.emission_sphere_radius = 24.0
		root.add_child(embers)

		# 浓烟
		var smoke := _make_particles(8, 0.95)
		smoke.texture = _soft_dot()
		smoke.lifetime_randomness = 0.35
		smoke.direction = Vector2(0.0, -1.0)
		smoke.spread = 105.0
		smoke.initial_velocity_min = 60.0
		smoke.initial_velocity_max = 190.0
		smoke.gravity = Vector2(0.0, -150.0)
		smoke.damping_min = 40.0
		smoke.damping_max = 80.0
		smoke.scale_amount_min = 2.0
		smoke.scale_amount_max = 3.8
		smoke.scale_amount_curve = _grow_curve()
		smoke.color_ramp = _smoke_ramp()
		smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		smoke.emission_sphere_radius = 22.0
		root.add_child(smoke)

		# 焦土碎块：无贴图的方块，配合高重力和自旋。
		var debris := _make_particles(11, 0.8)
		debris.lifetime_randomness = 0.3
		debris.direction = Vector2(0.0, -1.0)
		debris.spread = 120.0
		debris.initial_velocity_min = 280.0
		debris.initial_velocity_max = 620.0
		debris.gravity = Vector2(0.0, 1650.0)
		debris.angle_min = -180.0
		debris.angle_max = 180.0
		debris.angular_velocity_min = -520.0
		debris.angular_velocity_max = 520.0
		debris.scale_amount_min = 7.0
		debris.scale_amount_max = 16.0
		debris.color_ramp = _debris_ramp()
		debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		debris.emission_sphere_radius = 18.0
		root.add_child(debris)

		_screen_flash(layer, Color(1.0, 0.34, 0.22), 0.2, 0.3)

	for child in root.get_children():
		if child is CPUParticles2D:
			child.emitting = true


## 正确标记雷：外扩的金色确认环 + 向内收束的封印环，读作“锁定并封住”。
## `tint` 和 `power` 由连击热度喂进来（见 ComboStyle）：档位色染在外环和星屑上，
## power 0-1 把整个封印撑大一圈。默认值就是原来的单发金色封印。
static func play_flag_seal(
	layer: Control,
	center: Vector2,
	tint: Color = Color(1.0, 0.84, 0.42, 1.0),
	power: float = 0.0
) -> void:
	var grade := _grade(layer)
	if grade == GRADE_SKIP:
		return
	var root := _spawn_root(layer, center, 0.95)
	if root == null:
		return
	var lite := grade == GRADE_LITE
	var heat := clampf(power, 0.0, 1.0)

	var gold := tint
	var cyan := Color(0.55, 0.94, 0.95, 1.0)

	# 立刻起爆的金色核心，保证高频操作下反馈不迟到。
	var core := RadialGlow.new()
	core.color = Color(1.0, 0.96, 0.8, 0.95)
	core.radius = 6.0
	root.add_child(core)
	var core_tween := root.create_tween().set_parallel(true)
	core_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	core_tween.tween_property(core, "radius", 78.0 + 30.0 * heat, 0.14)
	core_tween.tween_property(core, "modulate:a", 0.0, 0.22).set_delay(0.06)

	# 外扩确认环
	var ring := ShockRing.new()
	ring.color = Color(gold.r, gold.g, gold.b, 0.95)
	ring.radius = 13.0
	ring.thickness = 12.0
	root.add_child(ring)
	var ring_tween := root.create_tween().set_parallel(true)
	ring_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "radius", 152.0 + 64.0 * heat, 0.34)
	ring_tween.tween_property(ring, "thickness", 4.0, 0.34)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.2).set_delay(0.16)

	# 向内收束的封印环：和外环反向，形成“咔哒锁死”的读感。
	var seal := ShockRing.new()
	seal.color = Color(cyan.r, cyan.g, cyan.b, 0.9)
	seal.radius = 158.0
	seal.thickness = 3.0
	root.add_child(seal)
	var seal_tween := root.create_tween().set_parallel(true)
	seal_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	seal_tween.tween_property(seal, "radius", 22.0, 0.2)
	seal_tween.tween_property(seal, "thickness", 10.0, 0.2)
	seal_tween.tween_property(seal, "modulate:a", 0.0, 0.12).set_delay(0.16)

	# 四芒星闪光：命中封印那一刻的“叮”。
	var gleam := StarGleam.new()
	gleam.color = Color(1.0, 0.95, 0.78, 0.95)
	gleam.length = 0.0
	gleam.rotation = -0.25
	root.add_child(gleam)
	var gleam_tween := root.create_tween()
	gleam_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gleam_tween.tween_property(gleam, "length", 96.0 + 40.0 * heat, 0.18).set_delay(0.14)
	gleam_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	gleam_tween.tween_property(gleam, "length", 0.0, 0.22)
	gleam_tween.parallel().tween_property(gleam, "rotation", 0.42, 0.22)

	if lite:
		return

	# 金色星屑：连击越高撒得越多。
	var sparkles := _make_particles(14 + int(round(12.0 * heat)), 0.6)
	sparkles.texture = _soft_dot()
	sparkles.lifetime_randomness = 0.4
	sparkles.direction = Vector2(0.0, -1.0)
	sparkles.spread = 180.0
	sparkles.initial_velocity_min = 160.0
	sparkles.initial_velocity_max = 400.0
	sparkles.gravity = Vector2(0.0, 220.0)
	sparkles.damping_min = 60.0
	sparkles.damping_max = 140.0
	sparkles.scale_amount_min = 0.32
	sparkles.scale_amount_max = 0.7
	sparkles.scale_amount_curve = _fade_curve()
	sparkles.color_ramp = _gold_ramp()
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 12.0
	sparkles.color_ramp = _tint_ramp(tint)
	root.add_child(sparkles)

	# 上浮光尘，把“已封印”的状态留在格子上多停半拍。
	var motes := _make_particles(6, 0.9)
	motes.texture = _soft_dot()
	motes.lifetime_randomness = 0.5
	motes.direction = Vector2(0.0, -1.0)
	motes.spread = 34.0
	motes.initial_velocity_min = 45.0
	motes.initial_velocity_max = 120.0
	motes.gravity = Vector2(0.0, -70.0)
	motes.scale_amount_min = 0.18
	motes.scale_amount_max = 0.4
	motes.scale_amount_curve = _pulse_curve()
	motes.color_ramp = _gold_ramp()
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 34.0
	motes.color_ramp = _tint_ramp(tint)
	root.add_child(motes)

	for child in root.get_children():
		if child is CPUParticles2D:
			child.emitting = true


## 连击收束的奖金：金币从棋盘抛向左上角的钱袋。奖金原本只在屏幕角落飘一行数字，
## 玩家不会把它和刚刚打完的那串连击联系起来——得让钱自己走完这段路。
static func play_gold_flight(layer: Control, from: Vector2, to: Vector2, count: int) -> void:
	var grade := _grade(layer)
	if grade == GRADE_SKIP:
		return
	var coins := clampi(count, 1, 6 if grade == GRADE_LITE else 10)
	for i in range(coins):
		var root := _spawn_root(layer, from, 1.5)
		if root == null:
			return
		var coin := RadialGlow.new()
		coin.color = Color(1.0, 0.86, 0.42, 1.0)
		coin.radius = 0.0
		coin.falloff = 1.5
		root.add_child(coin)
		# 每枚币走自己的一条抛物线，否则一串金币会连成一根直棍。
		var control := from.lerp(to, 0.42) + Vector2(
			randf_range(-90.0, 90.0), randf_range(-150.0, -55.0)
		)
		var flight := randf_range(0.46, 0.62)
		var tween := root.create_tween()
		tween.tween_interval(float(i) * 0.06)
		tween.tween_property(coin, "radius", 11.0, 0.1)
		tween.parallel().tween_method(
			func(t: float) -> void:
				root.global_position = from.lerp(control, t).lerp(control.lerp(to, t), t),
			0.0,
			1.0,
			flight
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(coin, "radius", 0.0, 0.12)
		tween.tween_callback(root.queue_free)


## 正确标记的格子在封印动效之后整块炸碎：泥土碎块 + 金色火花 + 扬尘。
static func play_flag_shatter(layer: Control, center: Vector2, cell_size: float = 86.0) -> void:
	var grade := _grade(layer)
	if grade == GRADE_SKIP:
		return
	var root := _spawn_root(layer, center, 1.25)
	if root == null:
		return
	var lite := grade == GRADE_LITE
	var reach := maxf(cell_size, 24.0)

	var flash := RadialGlow.new()
	flash.color = Color(1.0, 0.92, 0.7, 0.95)
	flash.radius = 10.0
	flash.falloff = 1.7
	root.add_child(flash)
	var flash_tween := root.create_tween().set_parallel(true)
	flash_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(flash, "radius", reach * 1.5, 0.14)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.22).set_delay(0.05)

	var ring := ShockRing.new()
	ring.color = Color(1.0, 0.86, 0.46, 0.9)
	ring.radius = reach * 0.28
	ring.thickness = 13.0
	root.add_child(ring)
	var ring_tween := root.create_tween().set_parallel(true)
	ring_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "radius", reach * 2.5, 0.3)
	ring_tween.tween_property(ring, "thickness", 4.0, 0.3)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.2).set_delay(0.12)

	# 泥土碎块：撑起“整块地格被掀掉”的读感。
	var shards := _make_particles(12 if not lite else 6, 0.8)
	shards.lifetime_randomness = 0.3
	shards.direction = Vector2(0.0, -1.0)
	shards.spread = 165.0
	shards.initial_velocity_min = 240.0
	shards.initial_velocity_max = 560.0
	shards.gravity = Vector2(0.0, 1500.0)
	shards.angle_min = -180.0
	shards.angle_max = 180.0
	shards.angular_velocity_min = -600.0
	shards.angular_velocity_max = 600.0
	shards.scale_amount_min = 8.0
	shards.scale_amount_max = 18.0
	shards.color_ramp = _soil_ramp()
	shards.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	shards.emission_sphere_radius = reach * 0.34
	root.add_child(shards)

	var sparks := _make_particles(14 if not lite else 7, 0.55)
	sparks.texture = _soft_dot()
	sparks.lifetime_randomness = 0.4
	sparks.direction = Vector2(0.0, -1.0)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 230.0
	sparks.initial_velocity_max = 500.0
	sparks.gravity = Vector2(0.0, 620.0)
	sparks.damping_min = 30.0
	sparks.damping_max = 90.0
	sparks.scale_amount_min = 0.34
	sparks.scale_amount_max = 0.75
	sparks.scale_amount_curve = _fade_curve()
	sparks.color_ramp = _gold_ramp()
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = reach * 0.24
	root.add_child(sparks)

	if not lite:
		var dust := _make_particles(7, 0.8)
		dust.texture = _soft_dot()
		dust.lifetime_randomness = 0.35
		dust.direction = Vector2(0.0, -1.0)
		dust.spread = 120.0
		dust.initial_velocity_min = 50.0
		dust.initial_velocity_max = 170.0
		dust.gravity = Vector2(0.0, -110.0)
		dust.damping_min = 40.0
		dust.damping_max = 90.0
		dust.scale_amount_min = 1.6
		dust.scale_amount_max = 3.2
		dust.scale_amount_curve = _grow_curve()
		dust.color_ramp = _dust_ramp()
		dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		dust.emission_sphere_radius = reach * 0.3
		root.add_child(dust)

	for child in root.get_children():
		if child is CPUParticles2D:
			child.emitting = true


## 玩家受击：打在头像上的短促红色冲击，语汇和踩雷爆炸同源但更收敛。
static func play_impact_hit(layer: Control, center: Vector2, tint := Color(1.0, 0.36, 0.28)) -> void:
	var grade := _grade(layer)
	if grade == GRADE_SKIP:
		return
	var root := _spawn_root(layer, center, 0.9)
	if root == null:
		return
	var lite := grade == GRADE_LITE

	var core := RadialGlow.new()
	core.color = Color(1.0, 0.94, 0.88, 0.95)
	core.radius = 6.0
	root.add_child(core)
	var core_tween := root.create_tween().set_parallel(true)
	core_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	core_tween.tween_property(core, "radius", 138.0, 0.14)
	core_tween.tween_property(core, "modulate:a", 0.0, 0.2).set_delay(0.05)

	var ring := ShockRing.new()
	ring.color = Color(tint.r, tint.g, tint.b, 0.95)
	ring.radius = 18.0
	ring.thickness = 20.0
	root.add_child(ring)
	var ring_tween := root.create_tween().set_parallel(true)
	ring_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "radius", 272.0, 0.3)
	ring_tween.tween_property(ring, "thickness", 6.0, 0.3)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.18).set_delay(0.1)

	var spikes := SpikeBurst.new()
	spikes.color = Color(1.0, 0.82, 0.66, 0.9)
	spikes.count = 6
	spikes.inner = 7.0
	spikes.outer = 28.0
	spikes.thickness = 18.0
	spikes.rotation = 0.4
	root.add_child(spikes)
	var spike_tween := root.create_tween().set_parallel(true)
	spike_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	spike_tween.tween_property(spikes, "inner", 140.0, 0.28)
	spike_tween.tween_property(spikes, "outer", 300.0, 0.26)
	spike_tween.tween_property(spikes, "thickness", 3.5, 0.26)
	spike_tween.tween_property(spikes, "modulate:a", 0.0, 0.16).set_delay(0.1)

	if lite:
		return

	var sparks := _make_particles(16, 0.5)
	sparks.texture = _soft_dot()
	sparks.lifetime_randomness = 0.4
	sparks.direction = Vector2(0.0, -1.0)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 340.0
	sparks.initial_velocity_max = 760.0
	sparks.gravity = Vector2(0.0, 780.0)
	sparks.damping_min = 30.0
	sparks.damping_max = 90.0
	sparks.scale_amount_min = 0.3
	sparks.scale_amount_max = 0.65
	sparks.scale_amount_curve = _fade_curve()
	sparks.color_ramp = _blood_ramp(tint)
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 13.0
	root.add_child(sparks)
	sparks.emitting = true


# ---------------------------------------------------------------------------
# 预算与根节点
# ---------------------------------------------------------------------------


static func _grade(layer: Control) -> int:
	if layer == null or not is_instance_valid(layer) or not layer.is_inside_tree():
		return GRADE_SKIP
	# 组内数量会随节点释放自动减少，不需要额外维护计数器。
	var live := layer.get_tree().get_node_count_in_group(BURST_GROUP)
	if live >= HARD_BURST_LIMIT:
		return GRADE_SKIP
	if reduced_quality or live >= SOFT_BURST_LIMIT:
		return GRADE_LITE
	return GRADE_FULL


static func _spawn_root(layer: Control, center: Vector2, lifetime: float) -> Node2D:
	var tree := layer.get_tree()
	if tree == null:
		return null
	var root := Node2D.new()
	root.z_index = 40
	root.add_to_group(BURST_GROUP)
	layer.add_child(root)
	root.global_position = center
	# Bind the callable to the node itself rather than capturing it in a lambda:
	# if the board tears the burst down early, the connection goes with it.
	tree.create_timer(lifetime).timeout.connect(root.queue_free)
	return root


static func _screen_flash(layer: Control, color: Color, peak: float, duration: float) -> void:
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = color
	flash.modulate.a = 0.0
	# z_index 是相对父节点的：负值会被压到棋盘下面，必须取正值才盖得住画面，
	# 同时低于爆发根节点的 40，避免把火星和碎块洗白。
	flash.z_index = 30
	layer.add_child(flash)
	var tween := flash.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(flash, "modulate:a", peak, 0.05)
	tween.tween_property(flash, "modulate:a", 0.0, duration)
	tween.finished.connect(flash.queue_free)


# ---------------------------------------------------------------------------
# 粒子资源
# ---------------------------------------------------------------------------


static func _make_particles(amount: int, lifetime: float) -> CPUParticles2D:
	# CPU 粒子在 GL Compatibility 与 Web 导出上表现一致，不需要额外的 shader 编译。
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.amount = maxi(amount, 1)
	particles.lifetime = lifetime
	return particles


static func _soft_dot() -> Texture2D:
	if _dot_texture != null:
		return _dot_texture
	var extent := 32
	var image := Image.create_empty(extent, extent, false, Image.FORMAT_RGBA8)
	var center := Vector2(extent - 1, extent - 1) * 0.5
	var radius := float(extent) * 0.5
	for y in range(extent):
		for x in range(extent):
			var distance := Vector2(x, y).distance_to(center) / radius
			var alpha := pow(clampf(1.0 - distance, 0.0, 1.0), 1.7)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_dot_texture = ImageTexture.create_from_image(image)
	return _dot_texture


static func _fade_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


static func _grow_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(1.0, 1.0))
	return curve


static func _pulse_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


static func _fire_ramp() -> Gradient:
	return _ramp([
		[0.0, Color(1.0, 1.0, 0.92, 1.0)],
		[0.22, Color(1.0, 0.82, 0.4, 1.0)],
		[0.6, Color(1.0, 0.48, 0.18, 0.95)],
		[1.0, Color(0.62, 0.12, 0.06, 0.0)],
	])


static func _ember_ramp() -> Gradient:
	return _ramp([
		[0.0, Color(1.0, 0.78, 0.36, 0.0)],
		[0.2, Color(1.0, 0.6, 0.24, 0.9)],
		[1.0, Color(0.72, 0.2, 0.08, 0.0)],
	])


static func _smoke_ramp() -> Gradient:
	return _ramp([
		[0.0, Color(0.35, 0.27, 0.22, 0.0)],
		[0.32, Color(0.31, 0.24, 0.19, 0.06)],
		[0.55, Color(0.29, 0.22, 0.18, 0.36)],
		[1.0, Color(0.24, 0.2, 0.18, 0.0)],
	])


static func _debris_ramp() -> Gradient:
	return _ramp([
		[0.0, Color(0.42, 0.29, 0.18, 1.0)],
		[0.7, Color(0.24, 0.16, 0.12, 1.0)],
		[1.0, Color(0.18, 0.12, 0.09, 0.0)],
	])


static func _soil_ramp() -> Gradient:
	return _ramp([
		[0.0, Color(0.51, 0.6, 0.24, 1.0)],
		[0.4, Color(0.44, 0.32, 0.18, 1.0)],
		[1.0, Color(0.3, 0.21, 0.13, 0.0)],
	])


static func _dust_ramp() -> Gradient:
	return _ramp([
		[0.0, Color(0.78, 0.66, 0.46, 0.0)],
		[0.2, Color(0.74, 0.61, 0.4, 0.42)],
		[1.0, Color(0.68, 0.57, 0.4, 0.0)],
	])


static func _blood_ramp(tint: Color) -> Gradient:
	return _ramp([
		[0.0, Color(1.0, 0.95, 0.9, 1.0)],
		[0.3, Color(tint.r, tint.g, tint.b, 1.0)],
		[1.0, Color(tint.r * 0.55, tint.g * 0.25, tint.b * 0.22, 0.0)],
	])


## 把确认星屑染成当前连击档位的颜色，落点和角落的 COMBO 柱才是同一套光。
static func _tint_ramp(tint: Color) -> Gradient:
	return _ramp([
		[0.0, Color(1.0, 1.0, 0.94, 1.0)],
		[0.35, Color(tint.r, tint.g, tint.b, 1.0)],
		[1.0, Color(tint.r * 0.92, tint.g * 0.74, tint.b * 0.58, 0.0)],
	])


static func _gold_ramp() -> Gradient:
	return _ramp([
		[0.0, Color(1.0, 1.0, 0.9, 1.0)],
		[0.35, Color(1.0, 0.85, 0.45, 1.0)],
		[1.0, Color(1.0, 0.7, 0.3, 0.0)],
	])


static func _ramp(stops: Array) -> Gradient:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop in stops:
		offsets.append(float(stop[0]))
		colors.append(stop[1])
	gradient.offsets = offsets
	gradient.colors = colors
	return gradient


# ---------------------------------------------------------------------------
# 绘制节点
# ---------------------------------------------------------------------------


## 用同心圆堆出的柔光球，避免为一次爆炸引入额外贴图。
class RadialGlow extends Node2D:
	var color := Color.WHITE
	var radius := 10.0
	var falloff := 2.2
	var steps := 18


	func _process(_delta: float) -> void:
		queue_redraw()


	func _draw() -> void:
		if radius <= 0.5:
			return
		for step in range(steps, 0, -1):
			var ratio := float(step) / float(steps)
			var alpha := pow(1.0 - ratio, falloff) * color.a
			if alpha <= 0.004:
				continue
			draw_circle(Vector2.ZERO, radius * ratio, Color(color.r, color.g, color.b, alpha))


class ShockRing extends Node2D:
	var color := Color.WHITE
	var radius := 10.0
	var thickness := 4.0
	## 小于 1 时把环压扁成贴地的椭圆。
	var squash := 1.0


	func _process(_delta: float) -> void:
		queue_redraw()


	func _draw() -> void:
		if radius <= 0.5 or thickness <= 0.05:
			return
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, color, thickness, true)


## 放射状光刺；inner 与 outer 分别推进就能做出“拉长再抽走”的速度感。
class SpikeBurst extends Node2D:
	var color := Color.WHITE
	var count := 7
	var inner := 6.0
	var outer := 30.0
	var thickness := 6.0


	func _process(_delta: float) -> void:
		queue_redraw()


	func _draw() -> void:
		if outer <= inner or thickness <= 0.05:
			return
		for index in range(count):
			var angle := TAU * float(index) / float(count)
			var direction := Vector2(cos(angle), sin(angle))
			draw_line(direction * inner, direction * outer, color, thickness, true)


class StarGleam extends Node2D:
	var color := Color.WHITE
	var length := 0.0
	var waist_ratio := 0.16


	func _process(_delta: float) -> void:
		queue_redraw()


	func _draw() -> void:
		if length <= 0.5:
			return
		var points := PackedVector2Array()
		for index in range(8):
			var angle := TAU * float(index) / 8.0
			var reach := length if index % 2 == 0 else length * waist_ratio
			points.append(Vector2(cos(angle), sin(angle)) * reach)
		draw_colored_polygon(points, color)
