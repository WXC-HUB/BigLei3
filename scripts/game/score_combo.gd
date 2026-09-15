class_name ScoreComboTracker
extends RefCounted
## 关卡内的得分与连击。两者**各走各的**，而且计分口径只有两种，由 [member mode] 选：
##
## - [constant Mode.TIME]（关卡，默认）：每盘结束时按用时结算一笔奖励，1000 起步、
##   越拖越少、最低 100。盘中不加分也不扣分——排雷、踩雷、连击都不进这本账。
## - [constant Mode.MINES]（无尽关）：每排掉一枚雷 +[constant POINTS_PER_MINE]，
##   **不结算用时奖励**。
## - 连击：点一下 +1、认出一枚雷 +1，挨伤害或标错就断。两种口径下它都只喂表现层。
##
## 关卡的计分先后挂过连击倍率、又挂过排雷／踩雷数量，两次都让分数变成「做了多少动作」
## 的读数。改成只看时间之后，分数衡量的是「这一盘解得多快」——而解得快本身就要求雷排
## 得准、路走得对，那些东西是手段，不该再各自单独计一次分。
##
## 无尽关是那条规则唯一的例外，因为它没有终点：那里「解得多快」没有参照物，一盘一盘
## 结算用时只会奖励前期刷小盘。改成按排雷计数之后，分数直接等于「走了多远」，和牌子
## 上的「最远第 N 盘」是同一条曲线。
##
## 纯数值，不含 UI——主场景只负责喂事件与画反馈。

signal changed(score: int, combo: int)
signal hit(points: int, combo: int)
signal combo_broke(previous_combo: int)

## 计分口径。见文件头：关卡按用时，无尽关按排雷。
enum Mode {TIME, MINES}

## 无尽口径下每排掉一枚雷的分。
const POINTS_PER_MINE := 100

## 每盘用时奖励的起步分。开盘那一刻结算就是这个数。
const TIME_BONUS_MAX := 1000
## 衰减到底之后的保底分。再慢也有这一笔，避免长盘变成纯惩罚。
const TIME_BONUS_MIN := 100
## 每多花一秒扣多少分。1000 → 100 正好走 90 秒，之后一直是保底。
const TIME_BONUS_DECAY_PER_SECOND := 10

## 这一局用哪种口径计分。由主场景在进关时按关卡设定；[method reset] 会把它退回
## 默认的关卡口径，免得上一局的无尽设置漏进对战或教学。
var mode := Mode.TIME

var score := 0
var combo := 0
## 本次 run 已结算过用时奖励的盘数，以及最近一盘拿到的那一笔（账单要印）。
var boards_scored := 0
var last_time_bonus := 0


## 用时 `seconds` 秒能拿到多少分。静态的：账单、预览、测试都直接查这一份，
## 不必先有一个 tracker 实例。
static func time_bonus_for(seconds: float) -> int:
	var spent := maxi(int(floor(maxf(seconds, 0.0))), 0)
	return maxi(TIME_BONUS_MIN, TIME_BONUS_MAX - spent * TIME_BONUS_DECAY_PER_SECOND)


## 衰减到保底所需的秒数。给 UI 画进度条或写提示用。
static func time_bonus_floor_seconds() -> int:
	return (TIME_BONUS_MAX - TIME_BONUS_MIN) / TIME_BONUS_DECAY_PER_SECOND


func reset() -> void:
	mode = Mode.TIME
	score = 0
	combo = 0
	boards_scored = 0
	last_time_bonus = 0
	changed.emit(score, combo)


## 换盘：连击清零，已经结算进账的分数留着。
func reset_combo_keep_score() -> void:
	combo = 0
	changed.emit(score, combo)


## 一次有效动作：点一下翻开格子、推理推开安全格。只涨连击，两种口径下都不计分。
func register_combo_hit() -> void:
	combo += 1
	# 只发 hit：避免紧跟着的 changed 把表现层的冲能动画瞬间盖掉。
	# 分数恒为 0，表现层据此跳过「+N」飘字。
	hit.emit(0, combo)


## 认出一枚雷。连击照涨；无尽口径下再进 [constant POINTS_PER_MINE] 分，关卡口径下
## 和普通点击一样不计分。返回本次到手的分——表现层据此决定要不要飘「+N」。
##
## 去重在调用方：同一格撤旗重标不该再走到这里。
func register_mine_hit() -> int:
	combo += 1
	var points := POINTS_PER_MINE if mode == Mode.MINES else 0
	score += points
	hit.emit(points, combo)
	return points


## 一盘结束，按用时结算。返回这一盘到手的分。
## 无尽口径下不结算：那里的分全部来自排雷，再叠一笔用时就成了两本账。
func register_time_bonus(seconds: float) -> int:
	if mode == Mode.MINES:
		return 0
	var bonus := time_bonus_for(seconds)
	last_time_bonus = bonus
	boards_scored += 1
	score += bonus
	changed.emit(score, combo)
	return bonus


func break_combo() -> void:
	if combo <= 0:
		return
	var previous := combo
	combo = 0
	combo_broke.emit(previous)
	changed.emit(score, combo)
