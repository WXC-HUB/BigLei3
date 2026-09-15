class_name ComboStyle
extends RefCounted
## 连击热度的统一口径：档位、配色、音高、强度曲线。
## 角落的 COMBO 柱和棋盘四周的烟花共读这一份——两边各调各的色，画面就会散成两个游戏。
## 整套连击表现的手感旋钮都在这个文件里，调参只改这里。

## 四档配色。跨过 TIER_THRESHOLDS 里的连击数就换一档。
const TIER_COLORS := [
	Color("e8c56a"), ## 1-4 暖金
	Color("ff9a3c"), ## 5-9 熔橙
	Color("ff5a3c"), ## 10-19 炽红
	Color("fff4d0"), ## 20+ 白热
]
## 档位名直接显示给玩家，所以用通用档位词，不用配色代号。
## 「暖金／熔橙／炽红／白热」是给这份文件里的调色注释看的，摆到屏幕上只会让人出戏。
const TIER_NAMES := ["GOOD", "GREAT", "EXCELLENT", "PERFECT"]
const TIER_THRESHOLDS := [5, 10, 20]

## 断连时棋盘扫过的冷色：和任何一档热色都不沾边，失去感才立得住。
const BREAK_COLOR := Color("6f9ad6")

## 确认音的音高阶梯：每连一次升一个半音，爬满一个八度封顶。
const PITCH_MAX_SEMITONES := 12
## 连击越高确认音越响，封顶 +3.5 dB——再高就压过爆炸声了。
const GAIN_MAX_DB := 3.5

## 热度爬满所需的连击数。棋盘侧所有强度都按这条曲线缩放。
const HEAT_FULL_COMBO := 20.0

## 每多少连算一个里程碑。
const MILESTONE_STEP := 5


static func tier_for(combo: int) -> int:
	var tier := 0
	for threshold in TIER_THRESHOLDS:
		if combo >= threshold:
			tier += 1
	return tier


static func tier_color(combo: int) -> Color:
	return TIER_COLORS[tier_for(combo)]


static func tier_name(combo: int) -> String:
	return TIER_NAMES[tier_for(combo)]


## 角落那根 COMBO 柱用的流光强度：字小，色相得走满一圈才够闪。
const HUD_COLOR_FLOW := 0.55
## 棋盘用的流光强度。边框和光波是大面积色块，色相一走就认不出是哪一档了——
## 20 连的「白热」画成一圈绿框，玩家只会觉得随机变色。只留一点呼吸感。
const BOARD_COLOR_FLOW := 0.14


## 棋盘侧的档位色。前三档和 TIER_COLORS 一致，**只有顶档换掉**。
## 原因：COMBO 柱画在深色 HUD 上，「白热」= 近白色是最亮的一档；但棋盘背景是浅
## 羊皮纸，同一个近白色摊在上面对比度几乎为零，结果 20 连比 10 连还不显眼——
## 「连击越多越强」直接反了。所以棋盘的顶档往高饱和的炽粉走，白只留在火星头部。
const BOARD_TIER_COLORS := [
	Color("e8c56a"), ## 1-4 暖金
	Color("ff9a3c"), ## 5-9 熔橙
	Color("ff5a3c"), ## 10-19 炽红
	Color("ff2f5e"), ## 20+ 炽粉（顶档，替掉 HUD 那边的白热）
]


## 以档位色为底，叠一段流光色相，让连击期间的颜色一直在走。
## `flow` 越大越偏流光、越小越贴档位色；大面积色块一律走 board_color()。
static func live_color(combo: int, phase: float, flow: float = HUD_COLOR_FLOW) -> Color:
	return _flow_color(TIER_COLORS[tier_for(combo)], phase, flow)


## 棋盘侧统一走这个：任何相位下都还读得出档位色，只带一点流光呼吸。
static func board_color(combo: int, phase: float) -> Color:
	return _flow_color(board_tier_color(combo), phase, BOARD_COLOR_FLOW)


static func board_tier_color(combo: int) -> Color:
	return BOARD_TIER_COLORS[tier_for(combo)]


static func _flow_color(base: Color, phase: float, flow: float) -> Color:
	var shift := Color.from_hsv(fposmod(phase, 1.0), 0.75, 1.0)
	return base.lerp(shift, clampf(flow, 0.0, 1.0)).lightened(0.08)


## 0-1 的热度，只看连击数。棋盘侧的烟花密度、火星初速、光晕亮度都按它缩放。
static func heat(combo: int) -> float:
	if combo <= 0:
		return 0.0
	return clampf(float(combo) / HEAT_FULL_COMBO, 0.0, 1.0)


## 确认音的音高：半音阶梯，一个八度封顶。断连后连击归零，音高自然回到起点。
static func pitch_for(combo: int) -> float:
	var semitones := clampi(combo - 1, 0, PITCH_MAX_SEMITONES)
	return pow(2.0, float(semitones) / 12.0)


static func gain_db_for(combo: int) -> float:
	return GAIN_MAX_DB * heat(combo)


## 里程碑：5、10、15、20，之后每 5 一次。
static func is_milestone(combo: int) -> bool:
	return combo >= MILESTONE_STEP and combo % MILESTONE_STEP == 0


## 距离下一个里程碑的进度 0-1。能量槽拆掉之后，COMBO 字形的填充改由它驱动：
## 原来那条填充读的是「还剩多少时间」，现在读的是「离下一档还有几刀」。
static func milestone_progress(combo: int) -> float:
	if combo <= 0:
		return 0.0
	var step := combo % MILESTONE_STEP
	return 1.0 if step == 0 else float(step) / float(MILESTONE_STEP)
