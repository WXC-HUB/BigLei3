class_name ScoreComboTracker
extends RefCounted
## 关卡内得分与连击表。正确确认一枚雷格 → 连击 +1、表充能；表空则连击归零。
## 纯数值，不含 UI——主场景只负责喂事件与画反馈。

signal changed(score: int, combo: int, meter: float)
signal hit(points: int, combo: int, meter: float)
signal combo_broke(previous_combo: int)

const BASE_POINTS := 100
## 连击倍率：第 n 次得 BASE * (1 + (n-1) * STEP)
const COMBO_STEP := 0.28
const METER_GAIN := 0.48
const METER_DECAY := 0.085
const METER_IDLE_BEFORE_ACCEL := 1.15
const METER_DECAY_ACCEL := 0.20

var score := 0
var combo := 0
var meter := 0.0

var _idle_seconds := 0.0


func reset() -> void:
	score = 0
	combo = 0
	meter = 0.0
	_idle_seconds = 0.0
	changed.emit(score, combo, meter)


## 换盘：只清连击与能量槽，保留本关累计分。
func reset_combo_keep_score() -> void:
	combo = 0
	meter = 0.0
	_idle_seconds = 0.0
	changed.emit(score, combo, meter)


func points_for_combo(combo_count: int) -> int:
	var n := maxi(combo_count, 1)
	return int(round(float(BASE_POINTS) * (1.0 + float(n - 1) * COMBO_STEP)))


## 正确确认一枚雷格。返回本次加分。
func register_mine_cleared() -> int:
	combo += 1
	meter = minf(1.0, meter + METER_GAIN)
	_idle_seconds = 0.0
	var points := points_for_combo(combo)
	score += points
	# 只发 hit：避免紧跟着的 changed 把 HUD 冲能动画瞬间盖掉。
	hit.emit(points, combo, meter)
	return points


func break_combo() -> void:
	if combo <= 0 and meter <= 0.0:
		return
	var previous := combo
	combo = 0
	meter = 0.0
	_idle_seconds = 0.0
	if previous > 0:
		combo_broke.emit(previous)
	changed.emit(score, combo, meter)


func tick(delta: float) -> void:
	if meter <= 0.0:
		if combo > 0:
			break_combo()
		return
	_idle_seconds += delta
	var rate := METER_DECAY
	if _idle_seconds > METER_IDLE_BEFORE_ACCEL:
		rate += METER_DECAY_ACCEL * (_idle_seconds - METER_IDLE_BEFORE_ACCEL)
	meter = maxf(0.0, meter - rate * delta)
	if meter <= 0.0:
		break_combo()
	else:
		changed.emit(score, combo, meter)


func resume_decay() -> void:
	_idle_seconds = 0.0
