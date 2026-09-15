extends Control

const BoardModel := preload("res://scripts/game/minesweeper_board.gd")
const CellView := preload("res://scenes/ui/mine_card.tscn")
const ShopOverlayView := preload("res://scenes/shop_overlay.tscn")
const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const PlayerStatusView := preload("res://scenes/player_status.tscn")
const NightMasterFishPopupView := preload("res://scenes/ui/night_master_fish_popup.tscn")
const VictoryBannerView := preload("res://scenes/ui/victory_banner.tscn")
const StageProgressBannerView := preload("res://scenes/ui/stage_progress_banner.tscn")
const StageProgressBannerScript := preload("res://scripts/ui/stage_progress_banner.gd")
const RoundIntroBannerScript := preload("res://scripts/ui/round_intro_banner.gd")
const HeadphoneNoticeView := preload("res://scenes/ui/headphone_notice.tscn")
const OpeningStoryView := preload("res://scenes/ui/opening_story.tscn")
const CreditsScreenView := preload("res://scenes/ui/credits_screen.tscn")
const AchievementsScreenView := preload("res://scenes/ui/achievements_screen.tscn")
const AchievementToastView := preload("res://scenes/ui/achievement_toast.tscn")
const WrongFlagGuideBannerView := preload("res://scenes/ui/wrong_flag_guide_banner.tscn")
const LevelBillView := preload("res://scenes/ui/level_bill.tscn")
const GameOverOverlayView := preload("res://scenes/ui/game_over_overlay.tscn")
const NightHeronUnlockView := preload("res://scenes/ui/night_heron_unlock.tscn")
const RedstartUnlockView := preload("res://scenes/ui/redstart_unlock.tscn")
const AttackerUnlockView := preload("res://scenes/ui/attacker_unlock.tscn")
const KestrelUnlockView := preload("res://scenes/ui/kestrel_unlock.tscn")
const TitUnlockView := preload("res://scenes/ui/tit_unlock.tscn")
const MagpieUnlockView := preload("res://scenes/ui/magpie_unlock.tscn")
const CrowUnlockView := preload("res://scenes/ui/crow_unlock.tscn")
const DoveUnlockView := preload("res://scenes/ui/dove_unlock.tscn")
const MusicBreakNoticeView := preload("res://scenes/ui/music_break_notice.tscn")
const StartScreenView := preload("res://scenes/ui/start_screen.tscn")
const TutorialSkipButtonView := preload("res://scenes/ui/tutorial_skip_button.tscn")
const RegularSkipControlView := preload("res://scenes/ui/regular_skip_control.tscn")
const GAME_CURSOR_TEXTURE := preload("res://assets/ui/cursor_dot.svg")
const CursorFxView := preload("res://scripts/ui/cursor_fx.gd")
const TUTORIAL_GUIDE_TEXTURE := preload("res://my_asset/guide.png")
const TUTORIAL_GUIDE_2_TEXTURE := preload("res://my_asset/guide_2.png")
const AchievementCatalogData := preload("res://scripts/game/achievement_catalog.gd")
const BirdCatalogData := preload("res://scripts/game/bird_catalog.gd")
const BirdCodexScreenScript := preload("res://scripts/ui/bird_codex_screen.gd")
const GameSaveData := preload("res://scripts/game/game_save.gd")
const ScoreComboTrackerScript := preload("res://scripts/game/score_combo.gd")
const ComboScoreHudScript := preload("res://scripts/ui/combo_score_hud.gd")
const ComboBoardFxScript := preload("res://scripts/ui/combo_board_fx.gd")
const LeaderboardApiScript := preload("res://scripts/game/leaderboard_api.gd")
const LeaderboardPanelScript := preload("res://scripts/ui/leaderboard_panel.gd")
const DuelSessionScript := preload("res://scripts/net/duel_session.gd")
const DuelHudScript := preload("res://scripts/ui/duel_hud.gd")
const DuelLobbyScript := preload("res://scripts/ui/duel_lobby.gd")
const CustomLevelEditorScript := preload("res://scripts/ui/custom_level_editor.gd")
const WorkshopPanelScript := preload("res://scripts/ui/workshop_panel.gd")
const ACHIEVEMENT_START_GAME := AchievementCatalogData.START_GAME
const ACHIEVEMENT_NIGHT_MASTER_FISH := AchievementCatalogData.NIGHT_MASTER_FISH

const START_BOARD_SIZE := 6
const TUTORIAL_LEVEL_COUNT := 8
## 新手第 1 盘强引导：遮罩挖洞在目标格外留的边距。
const GUIDED_HOLE_PADDING := 12.0
## 打到非教程第五关的时候插播一次「该换首音乐了」，然后把制作人名单拉起来放歌。
## 每局只演一次，回主菜单重开会重置。
const MUSIC_BREAK_LEVEL := TUTORIAL_LEVEL_COUNT + 5
const BOARD_SIZE_HOLD_LEVELS := 3
const MAX_BOARD_SIZE := 10
const MINE_DENSITY := 0.16
const MEDICAL_KIT_COUNT := 1
const XRAY_COUNT := 1
## 一盘里被串成一组的连携雷颗数。商店的「连携雷 +1」在这个基数上继续加。
const CHAIN_COUNT := 2
const ENLARGE_COUNT := 1
const DETECT_COUNT := 0
const SUPER_LUCK_CLICKS_PER_ITEM := 1
const CELL_SIZE := 88.0
const CELL_GAP := 7.0
## 分屏几何。以设计分辨率 1920×1080 为准：左半屏放我的棋盘，右半屏放对手棋盘位。
## SPLIT_HUD_BAND 是顶部让给 HUD 的高度（自身状态 + 读数行 / 对手面板都在这条带里）。
## 版式一律按设计分辨率算而不是读 get_viewport_rect()：stretch=canvas_items 下两者
## 本该一致，但 headless 里视口高度会被报成 1920，照它排就全乱了。
const DESIGN_VIEWPORT := Vector2(1920.0, 1080.0)
const SPLIT_VIEWPORT := DESIGN_VIEWPORT
const SPLIT_CENTER_SHIFT := 480.0
const SPLIT_MARGIN := 40.0
const SPLIT_HUD_BAND := 160.0
const SPLIT_BOTTOM_MARGIN := 12.0
const SPLIT_PANEL_PADDING := 24.0
## 10 颗心的自身 HUD 有 540px 宽，塞不进左半屏还不撞上读数行，缩一档正好。
const SPLIT_STATUS_SCALE := 0.72
const BOARD_VERTICAL_LIFT := 32.0
const BOARD_VERTICAL_SHIFT := CELL_SIZE - 36.0
# 棋盘上方读数：剩余雷与分列道具上下两行叠放，最上面再压一行关卡名。
const MINE_COUNTER_HEIGHT := 58.0
const MINE_COUNTER_SIZE := Vector2(224.0, MINE_COUNTER_HEIGHT)
const ITEM_COUNTER_HEIGHT := 58.0
const ITEM_CHIP_WIDTH := 70.0
const BOARD_COUNTER_GAP := 16.0
const STAGE_BOARD_LABEL_WIDTH := 260.0
const STAGE_BOARD_LABEL_HEIGHT := 34.0
const STAGE_BOARD_LABEL_GAP := 8.0
## 读数叠底边与棋盘上沿之间的空隙。
const BOARD_COUNTER_STACK_GAP := 14.0
## 读数叠占的总高。一律按最高一档（关卡名 + 剩余雷 + 分列道具）算：这几行是逐关
## 变的，跟着变会让相邻两盘的格子大小来回跳一下。
const BOARD_COUNTER_STACK_HEIGHT := (
	BOARD_COUNTER_STACK_GAP + ITEM_COUNTER_HEIGHT + BOARD_COUNTER_GAP
	+ MINE_COUNTER_HEIGHT + STAGE_BOARD_LABEL_GAP + STAGE_BOARD_LABEL_HEIGHT
)
## 单机版式给画布上下左右留的边。见 _apply_solo_board_fit。
const BOARD_FIT_TOP_MARGIN := 12.0
const BOARD_FIT_BOTTOM_MARGIN := 12.0
const BOARD_FIT_SIDE_MARGIN := 28.0
## 开局洗牌：从第一张牌起飞到最后一张起飞之间的总时长。单张的飞行时间在
## MineCell.DEAL_FLIGHT_TIME，两者相加才是整段发牌的长度。
const BOARD_DEAL_TOTAL_TIME := 0.62
## 甩出去时那点歪劲；相邻两张朝相反方向歪，看着才像一叠牌被拨开。
const BOARD_DEAL_SPIN := 16.0
const ITEM_TYPE_ORDER: Array[int] = [
	1, ## LANTERN
	2, ## COMPASS
	3, ## ORBITAL_STRIKE
	4, ## SUPER_LUCK
	5, ## MEDICAL_KIT
	6, ## XRAY
	7, ## CHAIN
	8, ## ENLARGE
	9, ## DETECT
]
# Impact weight. The shake is stepped rather than interpolated — smoothing the
# swing is what makes a hit read as a wobble instead of a punch.
const BOARD_SHAKE_STEP_TIME := 0.028
const BOARD_SHAKE_CLICK_STRENGTH := 2.5
const BOARD_SHAKE_CLICK_STEPS := 4
const BOARD_SHAKE_MINE_STRENGTH := 9.0
const BOARD_SHAKE_MINE_STEPS := 7
const BOARD_SHAKE_MONSTER_STRENGTH := 7.0
const BOARD_SHAKE_MONSTER_STEPS := 10
# Near-zero rather than a dead stop: a hard 0 leaves nothing to advance the
# unscaled timer against, and 5% is already indistinguishable from frozen.
const HITSTOP_TIME_SCALE := 0.05
const HITSTOP_MINE_SECONDS := 0.07
## How long the flag pose gets before the confirmed mine's card shatters away.
const FLAG_SHATTER_DELAY := 0.17
const HITSTOP_MONSTER_SECONDS := 0.09
## 正确标雷时棋盘的回弹：底噪很轻，靠热度往上加，封顶还是比踩雷小一圈。
const COMBO_SHAKE_BASE := 1.6
const COMBO_SHAKE_HEAT_GAIN := 5.2
const COMBO_SHAKE_STEPS := 4
const TARGET_GUIDE_Z := 40
const BIRD_FLYOVER_Z := 52
const BIRD_DROPPED_PROP_Z := 51
const PLAYER_START_MAX_HP := 3
## 商店基础价。刷新一直按这个价收，商品则按「同一件买过几次」逐次涨价。
const SHOP_ITEM_COST := 5
## 重复购买的涨价系数：同一件商品第 n 次（n 从 0 起）的价格 = 基础价 × 1.2ⁿ 向上取整，
## 也就是 5 / 6 / 8 / 9 / 11 / 13…。囤同一件东西越来越贵，逼玩家把钱摊开花。
const SHOP_PRICE_GROWTH := 1.2
## 单关通关奖励：打完一盘固定进账这么多，在账单上和标雷、吃鱼、连击各占一行。
const LEVEL_CLEAR_GOLD := 3
## 上限商品：红隼最多 3 只，长尾山雀最多 2 张（含每关自带的那一张）。买满之后整轮 run
## 里都不再上架——这两件是滚雪球最快的两张牌，堆多了关卡就没有威胁了。
const KESTREL_ITEM_LIMIT := 3
const TIT_ITEM_LIMIT := 2
const BIG_MONSTER_MAX_HP := 30
const MINE_ATTACK_DELAY := 3
const MINE_DAMAGE := 1

## --- 奖励盘 ---
## 一盘里的雷被提前清空、结算队列却还压着牌时，那些牌本来会落空。改成自动展开一张
## 同尺寸的【奖励盘】：只有雷、不发新牌（不发新牌是硬要求，否则队列会自己养自己、
## 一盘接一盘停不下来），剩下的伙伴牌在它上面继续结算，结算完照常进本该进的下一盘。
## 玩家不操作奖励盘，盘上标出的雷照常算金币与得分。
const BONUS_BOARD_LIMIT := 3
## 整盘压成暖金，和普通盘一眼分得开。
const BONUS_BOARD_TINT := Color(1.22, 1.0, 0.58)
const BONUS_BOARD_TINT_TIME := 0.3
## 光环亮起、标题弹出之后停一拍，再开始往上落牌。
const BONUS_BOARD_INTRO_HOLD := 0.5
## Marking a safe cell costs the same as stepping on a mine.
const WRONG_FLAG_DAMAGE := 1
const SMALL_MINE_ATTACK_DAMAGE := 10
const ITEM_SETTLEMENT_LAUNCH_INTERVAL := 0.14
const BIRD_DEPARTURE_QUEUE_INTERVAL := 0.09
## 长尾山雀从栖枝摔到目标格要飞多久、趴在地上多久再翻 3×3、翻开后多久顺势掉出屏幕、
## 掉出去多久后回到枝头。离场不等这一轮翻出的其他道具结算，只跟牌面翻开的节奏走。
const TIT_FALL_DURATION := 0.58
const TIT_CRASH_HOLD := 0.16
const TIT_TAKEOFF_DELAY := 0.28
const TIT_TUMBLE_DURATION := 0.5
const TIT_REAPPEAR_DELAY := 0.35
## 灰喜鹊接手连携：飞到起点多久、一格一格走每步多久、每步抬多高、走到头摆姿势各停多久。
## 连携：每只分身飞多久、彼此错开多久、弧线拐多远、翅膀几秒一帧、落地停多久再淡出。
## 同组的两颗连携雷之间可能隔着大半张盘，一格一格跳太慢，改成直接飞过去。
const MAGPIE_LINK_FLY_TIME := 0.38
const MAGPIE_LINK_STAGGER := 0.07
const MAGPIE_LINK_ARC := 42.0
const MAGPIE_FLAP_TIME := 0.09
const MAGPIE_LAND_HOLD := 0.12
const MAGPIE_VANISH_TIME := 0.22
## 小嘴乌鸦接手透视：飞到那格要多久、内容亮几秒、被撞见后僵多久、飞出屏幕多久。
const CROW_FLY_IN_TIME := 0.36
const XRAY_PEEK_SECONDS := 3.0
## 掀开之后原地顿一下就走，别杵在棋盘上挡着玩家看。
const CROW_PEEK_BEAT := 0.18
const CROW_VANISH_TIME := 0.2
## 斑鸠接手治愈：每程飞多久、翅膀几秒一帧、叼起枝停多久、递完多久淡掉、落点相对牌心偏多少。
const DOVE_FLY_TIME := 0.42
const DOVE_FLAP_TIME := 0.1
const DOVE_VANISH_TIME := 0.2
const DOVE_FLAP_CYCLE: Array[int] = [2, 3]
## 停在血条正上方一点，别糊住爱心本身。
const DOVE_HEAL_OFFSET := Vector2(0.0, -46.0)
## 偷看时乌鸦相对那一格中心站在哪：右上方一格多，让喙正好垂到格子上而身子不压住内容。
const CROW_PEEK_OFFSET := Vector2(CELL_SIZE * 1.25, -CELL_SIZE * 0.55)

const COLOR_BG := Color("172119")
const COLOR_PANEL_DARK := Color("1c281b")
const COLOR_INK := Color("f4e8c1")
const COLOR_MUTED := Color("b7bf95")
const COLOR_ACCENT := Color("f2bd4c")
const COLOR_DANGER := Color("e65a45")
const COLOR_SUCCESS := Color("8fd15b")
const COLOR_HUD_INK := Color("493722")
const COLOR_HUD_MUTED := Color("78664b")

const CELL_FX := preload("res://vfx/cell_fx.gd")

const MONSTER_SMALL_TEXTURE := preload("res://my_asset/monster_small.png")
const MONSTER_BIG_TEXTURE := preload("res://my_asset/monster_big.png")
const TRIGGERED_MINE_TEXTURE := preload("res://my_asset/effects/triggered_mine_red_cross.png")
const CORRECT_MARK_TEXTURE := preload("res://my_asset/effects/marked_mine_green_check.png")
const LANTERN_TEXTURE := preload("res://assets/sprites/generated/bird_items/item_bird_lantern.png")
const COMPASS_TEXTURE := preload("res://assets/sprites/generated/bird_items/item_bird_compass.png")
const ORBITAL_STRIKE_TEXTURE := preload("res://assets/sprites/generated/bird_items/item_bird_orbital.png")
const SUPER_LUCK_TEXTURE := preload("res://assets/sprites/generated/bird_items/item_bird_super_luck.png")
const MEDICAL_KIT_TEXTURE := preload("res://assets/sprites/generated/bird_items/item_bird_dove.png")
const XRAY_TEXTURE := preload("res://assets/sprites/generated/bird_items/item_bird_crow.png")
const CHAIN_TEXTURE := preload("res://assets/sprites/generated/bird_items/item_bird_magpie.png")
const ENLARGE_TEXTURE := preload("res://assets/sprites/generated/bird_items/item_bird_tit.png")
const DETECT_TEXTURE := preload("res://assets/sprites/generated/tool_metal_detector.png")
const ITEM_COUNTER_TEXTURE := preload("res://assets/sprites/generated/item_backpack.png")
const RED_FLY_TEXTURE := preload("res://my_asset/birds/red_fly_fx_only.png")
const BLACK_FLY_TEXTURE_1 := preload("res://my_asset/birds/black_fly_fx_only_1.png")
const BLACK_FLY_TEXTURE_2 := preload("res://my_asset/birds/black_fly_fx_only_2.png")
const EG_FLY_BIG_TEXTURE := preload("res://my_asset/birds/eg_fly_big.png")
const BLACK_FISH_TEXTURES := [
	preload("res://my_asset/effects/fish/fish_silver.png"),
	preload("res://my_asset/effects/fish/fish_orange.png"),
	preload("res://my_asset/effects/fish/fish_teal.png"),
]

# Per the art-state convention: bright `revealed_*` artwork is the unflipped
# face, while dark `fogged_*` artwork is shown after a tile has been flipped.
const GROUND_COVERED_TILES: Array[Texture2D] = [
	preload("res://outlined_tiles/ground_tiles/revealed_plain.png"),
	preload("res://outlined_tiles/ground_tiles/revealed_rock.png"),
	preload("res://outlined_tiles/ground_tiles/revealed_grass.png"),
	preload("res://outlined_tiles/ground_tiles/revealed_small_flowers.png"),
	preload("res://outlined_tiles/ground_tiles/revealed_large_flowers.png"),
	preload("res://outlined_tiles/ground_tiles/revealed_mushroom.png"),
]
const GROUND_FLIPPED_TILES: Array[Texture2D] = [
	preload("res://outlined_tiles/ground_tiles/fogged_plain.png"),
	preload("res://outlined_tiles/ground_tiles/fogged_rock.png"),
	preload("res://outlined_tiles/ground_tiles/fogged_grass.png"),
	preload("res://outlined_tiles/ground_tiles/fogged_small_flowers.png"),
	preload("res://outlined_tiles/ground_tiles/fogged_large_flowers.png"),
	preload("res://outlined_tiles/ground_tiles/fogged_mushroom.png"),
]

enum ShopOffer {
	MAX_HEALTH,
	HEALING_POWER,
	SUPER_LUCK_CACHE,
	SUPER_LUCK_DURATION,
	ORBITAL_STRIKE_CACHE,
	ORBITAL_CROSS,
	LANTERN_CACHE,
	LANTERN_RANGE,
	COMPASS_CACHE,
	COMPASS_MARKS,
	XRAY_CACHE,
	CHAIN_CACHE,
	ENLARGE_CACHE,
}

## --- 无尽关的槽位制商店（鸟窝）---
## 无尽关没有终点，「买到的强化永久叠加」那套会越滚越离谱。改成鸟窝：一格住一只
## 伙伴，每盘按窝里的鸟往棋盘上埋牌。窝满了还想买，就得请走一只换上去。
## 占格子的商品 → 它加的那个数值位。**鸟窝是这七个数的唯一真相**，改完窝就照着窝
## 重算（`_sync_bonuses_from_slots()`），所以替换 / 撤下永远不会算歪。
## 不在这张表里的是永久强化（血量上限、无敌步数、十字啄击……），不占格子。
const SLOT_OFFER_BONUS := {
	ShopOffer.LANTERN_CACHE: "_lantern_bonus",
	ShopOffer.COMPASS_CACHE: "_compass_bonus",
	ShopOffer.ORBITAL_STRIKE_CACHE: "_orbital_strike_bonus",
	ShopOffer.SUPER_LUCK_CACHE: "_super_luck_bonus",
	ShopOffer.XRAY_CACHE: "_xray_bonus",
	ShopOffer.CHAIN_CACHE: "_chain_bonus",
	ShopOffer.ENLARGE_CACHE: "_enlarge_bonus",
}
## 起手 6 格：`_prepare_stage_run()` 送的四只鸟先占掉 4 格，留 2 格给前两次采购。
const ENDLESS_SLOT_START := 6
const ENDLESS_SLOT_PER_EXPANSION := 3
## 三次扩建的价钱，越扩越贵；数组长度就是「最多扩几次」，窝最大 6 + 3×3 = 15 格。
const ENDLESS_SLOT_EXPANSION_COSTS := [12, 22, 36]
## 鸟窝里的空格。
const ENDLESS_SLOT_EMPTY := -1

## ============ 临时：无尽关的调试起手 ============
## 只为手测奖励盘 / 鸟窝而存在：进无尽关时鸟窝直接扩满塞满、强化拉满、金币管够。
## **发版前把这一行翻回 false**，起手就完全恢复正常（4 只鸟 + 6 格窝）。
## 写成变量而不是常量，是因为测试要把它关掉——它们校的是正式起手。
var endless_debug_loadout := true
## ===============================================

var _board: MinesweeperBoard
var _cells: Array[MineCell] = []
var _grid: Control
var _status_label: Label
var _mine_label: Label
var _mine_caption_label: Label
var _mine_counter_panel: PanelContainer
var _stage_board_label: Label
var _item_label: Label
var _item_counter_panel: PanelContainer
var _item_type_row: HBoxContainer
var _item_type_chips: Dictionary = {} ## ItemType -> { "root": Control, "label": Label }
var _item_type_remaining: Dictionary = {} ## ItemType -> int
var _item_counter_size := Vector2(244, ITEM_COUNTER_HEIGHT)
var _item_counter_pulse: Tween
var _item_counter_shown := -1
var _item_counter_total := -1
var _super_luck_watermark: CenterContainer
var _super_luck_watermark_count: Label
var _time_label: Label
var _health_bar: Control
var _player_status
var _effects_layer: Control
var _restart_button: Button
var _shop_layer: ShopOverlay
var _victory_banner: VictoryBanner
var _stage_progress_banner: StageProgressBannerScript
## 洗完牌之后亮一次的「这盘埋了什么」横幅。
var _round_intro_banner: RoundIntroBannerScript
var _headphone_notice: HeadphoneNotice
var _opening_story
var _music_break_notice
var _music_break_played := false
## 开场演出（耳机提示 + 开场剧情）是否已经放过。落盘，所以整个存档周期内只放一次；
## 老档没有这个键，读出来是 false，于是会补放一次。
var _intro_played := false
var _credits_screen: CreditsScreen
var _achievements_screen: AchievementsScreen
var _bird_codex_screen: BirdCodexScreen
var _achievement_toast: AchievementToast
var _wrong_flag_guide_banner: WrongFlagGuideBanner
var _wrong_flag_damage_guide_shown := false
var _night_master_fish_guide_banner: WrongFlagGuideBanner
var _night_master_fish_guide_shown := false
var _unlocked_achievements: Dictionary = {}
var _level_bill: LevelBill
var _game_over_overlay: GameOverOverlay
var _night_heron_unlock: NightHeronUnlock
var _redstart_unlock: RedstartUnlock
var _attacker_unlock: AttackerUnlock
var _kestrel_unlock: KestrelUnlock
var _tit_unlock: TitUnlock
var _magpie_unlock: MagpieUnlock
var _crow_unlock: CrowUnlock
var _dove_unlock: DoveUnlock
var _cursor_fx: CursorFx
var _board_panel: PanelContainer
var _board_interface_shown := false
var _board_interface_fade: Tween
var _tutorial_guide: TextureRect
var _run_number := 0
var _resume_level := 1
## 本次运行的 run 种子。每关的棋盘种子由它派生，于是同一次运行里的一局是可复现的。
## 对战下改由对局种子接管，双方因此长出逐格一致的棋盘。
var _run_seed := 0
## --- 世界地图 / 关卡 (FEAT-002 · WorldMap) ---
## 当前在打哪一关；空串 = 不在关卡里（标题页或对战）。
var _stage_id := ""
## 本关的目标盘数，从关卡表取。
var _stage_target_round := 0
## 本关已打到第几盘。**不能拿 `_run_number` 顶替**：`_run_number` 是全局盘序、驱动棋盘
## 尺寸曲线，教学关从 0 起、其余关卡从 TUTORIAL_LEVEL_COUNT 起，拿它比目标盘数会算出
## 完全不同的关长。
var _stage_round := 0
var _cleared_stages: Array = []
## 每关历史最高分：stage_id → int。跨 run 保留，放弃本轮也不清。
var _stage_high_scores: Dictionary = {}
## 无尽关（第 7 关）最远打到第几盘：只在打赢一盘时更新，跨 run 保留，放弃本轮也不清。
var _endless_best_round := 0
## 鸟窝：每格一个 ShopOffer，ENDLESS_SLOT_EMPTY = 空格。只有无尽关读它。
var _endless_slots: Array[int] = []
## 已扩建次数，上限 ENDLESS_SLOT_EXPANSION_COSTS.size()。
var _endless_slot_expansions := 0
## 窝满时按下的那件商品，等玩家点一格来换；-1 = 没有待定的替换。钱在玩家点格子
## 那一刻才扣，所以中途取消 / 关店都不会白花钱。
var _pending_slot_offer := -1
## 上榜昵称（本地记住，下次上榜预填）。
var _leaderboard_name := ""
var _leaderboard_panel
## 当前关卡 run 的得分/连击表（纯数值）。
var _score_combo
var _combo_hud
## 棋盘上的连击表现层（热度边框、能量槽、光波），常驻在格子网格里。
var _combo_board_fx
## 本盘已计入连击的雷格，防止撤旗再标重复加分。
var _combo_scored_cells: Dictionary = {}
## 奖励盘（见 BONUS_BOARD_LIMIT）：正展着的那张、本盘已经开过几张。
var _bonus_board_active := false
var _bonus_boards_this_round := 0
## 换上奖励盘之前，这一盘已经标对 / 已经计分的雷数。账单要把前后几块加起来，
## 否则旧盘那笔会被新盘直接顶掉。
var _banked_flagged_mines := 0
var _banked_scored_mines := 0
var _bonus_aura: BonusBoardAura
## 换盘请求的合流闸：正在换的时候后来者只等、不重复换。
var _bonus_board_opening := false
## 停在换盘闸前面的牌数。它们还挂在 `_active_item_settlements` 上，但已经停在生效
## 之前、碰不到盘面，所以算「等待换盘是否安全」时要把它们减掉。
var _bonus_board_waiters := 0
## 本盘连击收束累计的额外金币（仅计入 combo > 2 的收束）。
var _combo_bonus_gold := 0
## 唯一那个续局槽属于哪一关；空串 = 没有打到一半的关卡。
var _resume_stage_id := ""
## 选关界面：陈列柜（StageCabinet）。变量名沿用「world_map」，接口和老地图一样。
var _world_map: StageCabinet
var _duel: DuelSession
var _duel_hud: DuelHud
var _duel_lobby
## 自定义模式：编辑器懒建；`_custom_level` 非空即处于自定义局中（类比 `_stage_id`）。
## `_custom_level` 是一个**关卡包**：多张图按顺序打，`_custom_map_index` 是打到第几张
## （0 基）。图与图之间走单机那套账单 + 商店，所以多图包才有"连续、有商店"的玩法。
var _custom_editor
var _custom_level: Dictionary = {}
var _custom_map_index := 0
var _workshop_panel
var _workshop_http: HTTPRequest
var _duel_play_started := false
var _duel_leaving := false
## 入站的标雷伤害先排队。收到时本地可能正卡在结算锁、红隼模态或连携挂起里，
## 那时候直接扣血会把在飞的结算搅乱，只能等棋盘空下来再落地。
var _duel_pending_damage := 0
var _duel_frozen := false
var _duel_self_cleared := false
## 当前格子边长，上限恒为 CELL_SIZE，只缩不放。单机按「读数叠 + 棋盘」这一整块
## 能不能塞进画布来算（9×9 起开始微收，10×10 约 78）；分屏则按左半屏的可用宽高
## 算（只有 10×10 会缩到约 79.3，6×6 到 9×9 仍是 88）。
var _cell_size := CELL_SIZE
## 棋盘整体相对视口中心的位移。棋盘和它的读数、教程图、震屏都锚在中心，
## 挪到左半屏就是给所有 offset 写入点统一加上这一个量。
var _board_center_offset := Vector2.ZERO
var _blue_bird_unlocked := true
var _red_bird_unlocked := false
var _night_heron_unlocked := false
var _attacker_bird_unlocked := false
var _lucky_bird_unlocked := false
var _tit_bird_unlocked := false
## 灰喜鹊接手连携道具；教学第 6 盘打完解锁。
var _magpie_bird_unlocked := false
## 小嘴乌鸦接手透视道具；教学第 7 盘打完解锁。
var _crow_bird_unlocked := false
## 斑鸠接手治愈道具；教学第 8 盘打完解锁。
var _dove_bird_unlocked := false
var _lantern_bonus := 0
var _compass_bonus := 0
var _orbital_strike_bonus := 0
var _super_luck_bonus := 0
var _medical_kit_bonus := 0
var _healing_power_bonus := 0
var _super_luck_click_bonus := 0
var _orbital_cross_unlocked := false
var _lantern_target_bonus := 0
var _compass_mark_bonus := 0
var _xray_bonus := 0
var _chain_bonus := 0
var _enlarge_bonus := 0
var _player_max_hp := PLAYER_START_MAX_HP
var _player_hp := PLAYER_START_MAX_HP
var _invincible_until_msec := 0
var _pending_invincible_duration_msec := 0
var _invincible_was_active := false
var _super_luck_mode_active := false
var _super_luck_settling := false
var _super_luck_clicks_remaining := 0
var _super_luck_mode_generation := 0
var _super_luck_deferred_indices: Array[int] = []
var _super_luck_deferred_lookup: Dictionary = {}
var _super_luck_click_fly_count := 0
var _super_luck_activation_count := 0
var _super_luck_hover_index := -1
var _gold := 0
## 本轮 run 里每件商品各买过几次（offer → 次数），只用来算涨价。跟着存档走，续局回来
## 价格接着涨，不会因为回一趟标题就重新便宜。
var _offer_purchase_counts: Dictionary = {}
var _gold_rewarded_this_run := false
## 本盘的用时奖励是否已经结算过。和 _gold_rewarded_this_run 同进同退。
var _time_bonus_awarded_this_run := false
var _night_master_fish_count := 0
## 已经落地、还在等搭档的「连携」标记点 A（道具牌自己的格子）。
var _chain_pending_triggers: Array[int] = []
## 标记点 A 落地之后被标出的雷，排队等着当标记点 B。
## 连携翻牌会把新道具翻出来、进而触发新的连携，用这个标志把递归压平成一层循环。
var _chain_flush_active := false
var _enlarge_mark_charges := 0
var _enlarge_click_invincible := false
var _last_xray_target := -1
var _last_detect_target := -1
var _enlarge_hover_generation := 0
var _tutorial_first_reveal_pending := false
var _tutorial_night_heron_edge_index := -1
## 新手第 1 盘的强引导：当前步序（-1 = 没在引导），演出层见 GuidedTutorialOverlay。
var _guided_step := -1
var _guided_overlay: GuidedTutorialOverlay
## 当前这盘走哪套强引导脚本（GuidedTutorial / GuidedItemLesson）；null = 不在强引导里。
var _guided_lesson: GDScript
var _item_guide_screen: ItemGuideScreen
var _woodpecker_demo_pending := false
var _woodpecker_demo_index := -1
var _kestrel_demo_pending := false
var _kestrel_demo_index := -1
var _tit_demo_pending := false
var _tit_demo_index := -1
var _crow_demo_pending := false
var _crow_demo_index := -1
var _dove_demo_pending := false
var _dove_demo_index := -1
var _active_mines: Dictionary = {}
var _defeated_mines: Dictionary = {}
var _wrong_flagged_cells: Dictionary = {}
var _hovered_cell_index := -1
var _previewed_cells: Array[int] = []
var _prelaunched_item_indices: Dictionary = {}
var _queued_bird_event_counts: Dictionary = {}
var _active_item_settlements := 0
var _item_queue_dispatching := false
var _last_item_settlement_dispatch_frames: Array[int] = []
var _pending_bird_departures: Array[int] = []
var _bird_departure_dispatch_running := false
var _bird_departure_generation := 0
var _last_bird_departure_dispatch_times: Array[int] = []
var _last_bird_departure_dispatch_frames: Array[int] = []
var _item_tooltip: PanelContainer
var _item_tooltip_title: Label
var _item_tooltip_body: Label
var _started := false
var _elapsed := 0.0
var _resolving := false
var _game_finish_started := false
var _inference_highlights: Array[int] = []
var _inference_hover_targets: Array[int] = []
var _board_impact_tween: Tween
var _board_shake_tween: Tween
var _board_panel_size := Vector2.ZERO
var _board_shake_offset := Vector2.ZERO
var _hitstop_generation := 0
# 通关结算/回地图时加一，让已经 await 出去的 `_start_game` 回来后立刻停，
# 避免上榜点穿把本关第一盘又搭出来。
var _run_boot_generation := 0
var _map_settle_lock := false
var _last_reveal_wave_delays: Dictionary = {}
var _start_screen: Control
var _tutorial_skip_button
var _regular_skip_control
var _last_compass_target := -1
var _last_lantern_target := -1
var _last_lantern_noop := false
var _last_orbital_step := -1
var _last_orbital_vertical := false
var _orbital_orientation_override := -1
var _last_target_lock_indices: Array[int] = []
var _last_dashed_line_target_count := 0
var _last_compass_flyover_count := 0
var _last_lantern_fish_count := 0
@onready var _bgm_player: AudioStreamPlayer = $BGM
@onready var _card_reveal_sfx: AudioStreamPlayer = $CardRevealSFX
@onready var _correct_flag_sfx: AudioStreamPlayer = $CorrectFlagSFX
@onready var _wrong_flag_sfx: AudioStreamPlayer = $WrongFlagSFX
@onready var _mine_trigger_sfx: AudioStreamPlayer = $MineTriggerSFX
@onready var _blue_bird: BirdPerch = $BlueBirdPerch
@onready var _red_bird: BirdPerch = $RedBirdPerch
@onready var _black_bird: BirdPerch = $BlackBirdPerch
@onready var _attacker_bird: BirdPerch = $AttackerBirdPerch
@onready var _eg_bird: BirdPerch = $EgBirdPerch
@onready var _tit_bird: BirdPerch = $TitBirdPerch
@onready var _magpie_bird: BirdPerch = $MagpieBirdPerch
@onready var _crow_bird: BirdPerch = $CrowBirdPerch
@onready var _dove_bird: BirdPerch = $DoveBirdPerch


func _ready() -> void:
	_apply_game_cursor()
	_build_cursor_fx()
	_start_bgm()
	_build_interface()
	_build_shop_interface()
	_build_duel()
	_build_progression_interface()
	_build_tutorial_skip_interface()
	_build_guided_tutorial_overlay()
	_build_regular_skip_interface()
	_build_headphone_notice()
	_build_opening_story()
	_build_music_break_notice()
	_build_credits_screen()
	_build_achievements_screen()
	_build_bird_codex_screen()
	_build_achievement_toast()
	_build_wrong_flag_guide_banner()
	_build_night_master_fish_guide_banner()
	_build_item_tooltip()
	_load_saved_progress()
	_build_start_screen()
	_apply_bird_unlock_visibility()
	# 岛屿底图与碎石树木装饰层强制关掉（进关时也不会再被 _set_scenery_visible 打开）。
	for node_name in SCENERY_ALWAYS_HIDDEN:
		var decor := get_node_or_null(node_name) as CanvasItem
		if decor != null:
			decor.visible = false


func _apply_game_cursor() -> void:
	var hotspot := Vector2(16.0, 16.0)
	for cursor_shape in [
		Input.CURSOR_ARROW,
		Input.CURSOR_IBEAM,
		Input.CURSOR_POINTING_HAND,
		Input.CURSOR_CROSS,
		Input.CURSOR_WAIT,
		Input.CURSOR_BUSY,
		Input.CURSOR_DRAG,
		Input.CURSOR_CAN_DROP,
		Input.CURSOR_FORBIDDEN,
		Input.CURSOR_VSIZE,
		Input.CURSOR_HSIZE,
		Input.CURSOR_BDIAGSIZE,
		Input.CURSOR_FDIAGSIZE,
		Input.CURSOR_MOVE,
		Input.CURSOR_VSPLIT,
		Input.CURSOR_HSPLIT,
		Input.CURSOR_HELP,
	]:
		Input.set_custom_mouse_cursor(GAME_CURSOR_TEXTURE, cursor_shape, hotspot)


## 光标圆点的拖尾与点击涟漪。挂在所有表现层之上（成就横幅占 300），
## 否则弹窗一开特效就被盖住，光标看起来像是钻到界面底下去了。
func _build_cursor_fx() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 400
	add_child(canvas)
	_cursor_fx = CursorFxView.new()
	canvas.add_child(_cursor_fx)


func _start_bgm() -> void:
	if _bgm_player.stream is AudioStreamMP3:
		(_bgm_player.stream as AudioStreamMP3).loop = true
	_bgm_player.play()


func _build_headphone_notice() -> void:
	# Above every in-game overlay but below the title screen, which owns 150.
	var canvas := CanvasLayer.new()
	canvas.layer = 140
	add_child(canvas)
	_headphone_notice = HeadphoneNoticeView.instantiate()
	canvas.add_child(_headphone_notice)


func _build_opening_story() -> void:
	# It follows the headphone card and stays below the title/credits layers.
	var canvas := CanvasLayer.new()
	canvas.layer = 145
	add_child(canvas)
	_opening_story = OpeningStoryView.instantiate()
	canvas.add_child(_opening_story)


func _build_music_break_notice() -> void:
	# Same layer band as the opening story: over every in-game overlay, under the
	# title screen and the credits it hands off to.
	var canvas := CanvasLayer.new()
	canvas.layer = 146
	add_child(canvas)
	_music_break_notice = MusicBreakNoticeView.instantiate()
	canvas.add_child(_music_break_notice)


func _build_credits_screen() -> void:
	# Above the title screen, which is the only place it can be opened from.
	var canvas := CanvasLayer.new()
	canvas.layer = 160
	add_child(canvas)
	_credits_screen = CreditsScreenView.instantiate()
	_credits_screen.back_requested.connect(_on_credits_back_requested)
	canvas.add_child(_credits_screen)


func _build_achievements_screen() -> void:
	# The page remains display-only; Main supplies the persisted unlock state.
	var canvas := CanvasLayer.new()
	canvas.layer = 160
	add_child(canvas)
	_achievements_screen = AchievementsScreenView.instantiate()
	_achievements_screen.back_requested.connect(_on_achievements_back_requested)
	canvas.add_child(_achievements_screen)


## 鸟类图鉴。和成就页一样只是个展示器：解锁位仍然存在 Main 手里，
## `_apply_bird_unlock_visibility()` 每次跑都会把最新状态推给它。
func _build_bird_codex_screen() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 160
	add_child(canvas)
	_bird_codex_screen = BirdCodexScreenScript.new()
	_bird_codex_screen.name = "BirdCodexScreen"
	_bird_codex_screen.back_requested.connect(_on_bird_codex_back_requested)
	canvas.add_child(_bird_codex_screen)


func _build_achievement_toast() -> void:
	# Above every presentation layer so an unlock can be announced at any time.
	var canvas := CanvasLayer.new()
	canvas.layer = 300
	add_child(canvas)
	_achievement_toast = AchievementToastView.instantiate()
	canvas.add_child(_achievement_toast)


func _build_wrong_flag_guide_banner() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 295
	add_child(canvas)
	_wrong_flag_guide_banner = WrongFlagGuideBannerView.instantiate()
	canvas.add_child(_wrong_flag_guide_banner)


func _build_night_master_fish_guide_banner() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 295
	add_child(canvas)
	_night_master_fish_guide_banner = WrongFlagGuideBannerView.instantiate()
	canvas.add_child(_night_master_fish_guide_banner)
	_night_master_fish_guide_banner.configure(
		"夜鹭在没有可揭示格子时，会自己把鱼吃掉"
	)


func _show_wrong_flag_damage_guide_once() -> void:
	if _wrong_flag_damage_guide_shown:
		return
	_wrong_flag_damage_guide_shown = true
	_wrong_flag_guide_banner.present()


func _show_night_master_fish_guide_once() -> void:
	if _night_master_fish_guide_shown:
		return
	_night_master_fish_guide_shown = true
	_night_master_fish_guide_banner.present()


## 成就的文案和图标都在总表里，这里只负责去重、点亮列表、弹一次提示。
func _unlock_achievement(achievement_id: String) -> void:
	if _unlocked_achievements.has(achievement_id):
		return
	var entry := AchievementCatalogData.entry(achievement_id)
	if entry.is_empty():
		push_warning("Unknown achievement id: %s" % achievement_id)
		return
	_unlocked_achievements[achievement_id] = true
	_save_progress()
	# 从标题页翻开成就页本身就是一个成就，所以横幅必须当场刷新。
	_refresh_achievement_banner()
	if _achievements_screen != null:
		_achievements_screen.set_unlocked(achievement_id, true)
	if _achievement_toast != null:
		_achievement_toast.show_achievement(
			entry["title"], entry["description"], entry["icon"]
		)


## 标题页上的成就横幅只是个显示器，账在这里记。
func _refresh_achievement_banner() -> void:
	if _start_screen == null:
		return
	_start_screen.set_achievement_progress(
		_unlocked_achievements.size(), AchievementCatalogData.ENTRIES.size()
	)


func _save_progress() -> void:
	if _is_duel() or _is_custom():
		# 对战和自定义都不写存档。这一条挡在最外层，是因为成就解锁和商店购买都会绕道
		# 进来，逐个调用点去堵迟早会漏一个，然后单机那一槽就被别的模式污染了。
		return
	GameSaveData.write({
		"current_level": maxi(_resume_level, 1),
		"tutorial_completed": _resume_level > TUTORIAL_LEVEL_COUNT,
		"gold": _gold,
		"player_hp": _player_hp,
		"player_max_hp": _player_max_hp,
		"blue_bird_unlocked": _blue_bird_unlocked,
		"red_bird_unlocked": _red_bird_unlocked,
		"night_heron_unlocked": _night_heron_unlocked,
		"attacker_bird_unlocked": _attacker_bird_unlocked,
		"lucky_bird_unlocked": _lucky_bird_unlocked,
		"tit_bird_unlocked": _tit_bird_unlocked,
		"magpie_bird_unlocked": _magpie_bird_unlocked,
		"crow_bird_unlocked": _crow_bird_unlocked,
		"dove_bird_unlocked": _dove_bird_unlocked,
		"lantern_bonus": _lantern_bonus,
		"compass_bonus": _compass_bonus,
		"orbital_strike_bonus": _orbital_strike_bonus,
		"super_luck_bonus": _super_luck_bonus,
		"medical_kit_bonus": _medical_kit_bonus,
		"healing_power_bonus": _healing_power_bonus,
		"super_luck_click_bonus": _super_luck_click_bonus,
		"orbital_cross_unlocked": _orbital_cross_unlocked,
		"lantern_target_bonus": _lantern_target_bonus,
		"compass_mark_bonus": _compass_mark_bonus,
		"xray_bonus": _xray_bonus,
		"chain_bonus": _chain_bonus,
		"enlarge_bonus": _enlarge_bonus,
		# 商店涨价的计数器。JSON 只有字符串键，读回来时统一转成 int。
		"offer_purchase_counts": _offer_purchase_counts.duplicate(),
		"achievements": _unlocked_achievements.keys(),
		# --- FEAT-002 · schema v2 ---
		"cleared_stages": _cleared_stages.duplicate(),
		"resume_stage_id": _resume_stage_id,
		"stage_round": _stage_round,
		# 换歌插播原本只活在内存里，于是每次重开游戏都会再放一次。落盘后它在整个存档
		# 周期内只放一次——非教学关起点是第 4 盘，多数关都会经过触发点第 9 盘。
		"music_break_played": _music_break_played,
		"intro_played": _intro_played,
		"stage_high_scores": _stage_high_scores.duplicate(),
		"endless_best_round": _endless_best_round,
		# 鸟窝：无尽关续局要原样接上。别的关卡这两项是空窝，读回来也没人看。
		"endless_slots": _endless_slots.duplicate(),
		"endless_slot_expansions": _endless_slot_expansions,
		"leaderboard_name": _leaderboard_name,
	})
	_refresh_title_save_state()


func _load_saved_progress() -> bool:
	var data := GameSaveData.load_data()
	if data.is_empty():
		_reset_persistent_progress()
		return false
	_resume_level = maxi(int(data.get("current_level", 1)), 1)
	if bool(data.get("tutorial_completed", false)):
		_resume_level = maxi(_resume_level, TUTORIAL_LEVEL_COUNT + 1)
	# `_start_game` increments first, so the title holds the level immediately
	# before the checkpoint that should be rebuilt.
	_run_number = _resume_level - 1
	# --- FEAT-002 · schema v2 ---
	# 同理，`_stage_round` 也退一格，让 `_start_game` 把它加回存档里的那个值——续上的
	# 是"那一盘的开头"，和 `current_level` 的语义保持一致。
	_cleared_stages.clear()
	for stage_id in data.get("cleared_stages", []):
		var id := String(stage_id)
		if StageTable.has_stage(id) and not _cleared_stages.has(id):
			_cleared_stages.append(id)
	_resume_stage_id = String(data.get("resume_stage_id", ""))
	if not StageTable.has_stage(_resume_stage_id):
		_resume_stage_id = ""
	_stage_round = maxi(int(data.get("stage_round", 0)) - 1, 0)
	# 有半局进度但没写归属关卡的档（v1 老档，或任何只填了部分字段的存档），一律归给
	# 第一关——和 `GameSave._migrate` 同一条规则。放在读取侧再兜一次，是因为
	# `GameSave.write()` 总会盖上当前版本号，所以"版本是 2 但字段不全"这种档确实存在，
	# 那时迁移分支根本不会跑。
	if _resume_stage_id == "" and _resume_level > 1 and not StageTable.STAGES.is_empty():
		_resume_stage_id = String(StageTable.STAGES[0]["id"])
		_stage_round = maxi(_resume_level - 1, 0)
	# 关卡表精简后，老档的盘序可能超出当前关盘数；夹住避免开局 assert。
	if _resume_stage_id != "":
		var board_count := StageTable.target_round_of(_resume_stage_id)
		if board_count > 0:
			_stage_round = clampi(_stage_round, 0, board_count - 1)
	_music_break_played = bool(data.get("music_break_played", false))
	_intro_played = bool(data.get("intro_played", false))
	_stage_high_scores.clear()
	var high_scores = data.get("stage_high_scores", {})
	if high_scores is Dictionary:
		for stage_id in high_scores.keys():
			var id := String(stage_id)
			if StageTable.has_stage(id):
				_stage_high_scores[id] = maxi(int(high_scores[stage_id]), 0)
	_endless_best_round = maxi(int(data.get("endless_best_round", 0)), 0)
	_endless_slot_expansions = clampi(
		int(data.get("endless_slot_expansions", 0)), 0, ENDLESS_SLOT_EXPANSION_COSTS.size()
	)
	_endless_slots.clear()
	var saved_slots = data.get("endless_slots", [])
	if saved_slots is Array:
		for entry in saved_slots:
			var slot_offer := int(entry)
			_endless_slots.append(slot_offer if _is_slot_offer(slot_offer) else ENDLESS_SLOT_EMPTY)
	# 格子数必须和扩建次数对得上：档里多了就截掉，少了补空格，免得窝凭空长出或缩水。
	var slot_capacity := _slot_capacity()
	while _endless_slots.size() > slot_capacity:
		_endless_slots.pop_back()
	while _endless_slots.size() < slot_capacity:
		_endless_slots.append(ENDLESS_SLOT_EMPTY)
	_pending_slot_offer = -1
	_leaderboard_name = LeaderboardApiScript.normalize_name(String(data.get("leaderboard_name", "")))
	_gold = maxi(int(data.get("gold", 0)), 0)
	_player_max_hp = maxi(int(data.get("player_max_hp", PLAYER_START_MAX_HP)), PLAYER_START_MAX_HP)
	_player_hp = clampi(int(data.get("player_hp", _player_max_hp)), 0, _player_max_hp)
	_blue_bird_unlocked = bool(data.get("blue_bird_unlocked", true))
	_red_bird_unlocked = bool(data.get("red_bird_unlocked", false))
	_night_heron_unlocked = bool(data.get("night_heron_unlocked", false))
	_attacker_bird_unlocked = bool(data.get("attacker_bird_unlocked", false))
	_lucky_bird_unlocked = bool(data.get("lucky_bird_unlocked", false))
	# 老存档没有这一位：教学已完成的老玩家直接视为已解锁，别让他们再看不到鸟。
	_tit_bird_unlocked = bool(data.get("tit_bird_unlocked", bool(data.get("tutorial_completed", false))))
	_magpie_bird_unlocked = bool(data.get("magpie_bird_unlocked", bool(data.get("tutorial_completed", false))))
	_crow_bird_unlocked = bool(data.get("crow_bird_unlocked", bool(data.get("tutorial_completed", false))))
	_dove_bird_unlocked = bool(data.get("dove_bird_unlocked", bool(data.get("tutorial_completed", false))))
	_lantern_bonus = maxi(int(data.get("lantern_bonus", 0)), 0)
	_compass_bonus = maxi(int(data.get("compass_bonus", 0)), 0)
	_orbital_strike_bonus = maxi(int(data.get("orbital_strike_bonus", 0)), 0)
	_super_luck_bonus = maxi(int(data.get("super_luck_bonus", 0)), 0)
	_medical_kit_bonus = maxi(int(data.get("medical_kit_bonus", 0)), 0)
	_healing_power_bonus = maxi(int(data.get("healing_power_bonus", 0)), 0)
	_super_luck_click_bonus = maxi(int(data.get("super_luck_click_bonus", 0)), 0)
	_orbital_cross_unlocked = bool(data.get("orbital_cross_unlocked", false))
	_lantern_target_bonus = maxi(int(data.get("lantern_target_bonus", 0)), 0)
	_compass_mark_bonus = maxi(int(data.get("compass_mark_bonus", 0)), 0)
	_xray_bonus = maxi(int(data.get("xray_bonus", 0)), 0)
	_chain_bonus = maxi(int(data.get("chain_bonus", 0)), 0)
	_enlarge_bonus = maxi(int(data.get("enlarge_bonus", 0)), 0)
	# 缺席按空字典读：老档没有这一项，回来时价格从基础价重新起算。
	_offer_purchase_counts.clear()
	var saved_counts = data.get("offer_purchase_counts", {})
	if saved_counts is Dictionary:
		for offer_key in saved_counts:
			var offer_index := int(offer_key)
			if offer_index >= 0 and offer_index < ShopOffer.size():
				_offer_purchase_counts[offer_index] = maxi(int(saved_counts[offer_key]), 0)
	# v4 及更早的档没有鸟窝那两项，但那七个数值位就是当时的真相：照着它们把鸟摆回
	# 窝里，并补足够的扩建把窝撑到装得下——不然续无尽局时会凭空少掉一窝鸟。
	# 只能放在这里：数值位到上一行才读完。
	var had_saved_nest: bool = saved_slots is Array and not (saved_slots as Array).is_empty()
	if not had_saved_nest and StageTable.is_endless(_resume_stage_id):
		_rebuild_slots_from_bonuses()
	_unlocked_achievements.clear()
	for achievement_id in data.get("achievements", []):
		var id := str(achievement_id)
		if AchievementCatalogData.has(id):
			_unlocked_achievements[id] = true
	if _achievements_screen != null:
		for entry in AchievementCatalogData.ENTRIES:
			var id := str(entry["id"])
			_achievements_screen.set_unlocked(id, _unlocked_achievements.has(id))
	_shop_layer.set_offer_owned(ShopOffer.ORBITAL_CROSS, _orbital_cross_unlocked)
	_sync_shop_offer_limits()
	_shop_layer.set_offer_prices(_offer_price_table())
	_refresh_health_bar()
	_refresh_gold_display()
	return true


func _on_achievements_requested() -> void:
	if _achievements_screen == null:
		return
	_achievements_screen.present()
	# 先开页再解锁：这一条会在玩家眼皮底下从"未获得"翻成"已获得"。
	_unlock_achievement(AchievementCatalogData.OPEN_ACHIEVEMENTS)


func _on_achievements_back_requested() -> void:
	if _achievements_screen != null:
		await _achievements_screen.dismiss()


func _on_bird_codex_requested() -> void:
	if _bird_codex_screen == null:
		return
	_refresh_bird_codex()
	_bird_codex_screen.present()


func _on_bird_codex_back_requested() -> void:
	if _bird_codex_screen != null:
		await _bird_codex_screen.dismiss()


## 图鉴里的解锁状态和栖枝上那几只鸟同源：这一份名单就是两边唯一的映射。
func _bird_unlock_states() -> Dictionary:
	return {
		BirdCatalogData.BLUE: _blue_bird_unlocked,
		BirdCatalogData.NIGHT_HERON: _night_heron_unlocked,
		BirdCatalogData.REDSTART: _red_bird_unlocked,
		BirdCatalogData.WOODPECKER: _attacker_bird_unlocked,
		BirdCatalogData.KESTREL: _lucky_bird_unlocked,
		BirdCatalogData.TIT: _tit_bird_unlocked,
		BirdCatalogData.MAGPIE: _magpie_bird_unlocked,
		BirdCatalogData.CROW: _crow_bird_unlocked,
		BirdCatalogData.DOVE: _dove_bird_unlocked,
	}


## 把解锁位推给图鉴页和标题页上那颗按钮的提示气泡。挂在
## `_apply_bird_unlock_visibility()` 里，所以每一次送鸟、读盘、跳过教学都会带上它。
func _refresh_bird_codex() -> void:
	var states := _bird_unlock_states()
	if _bird_codex_screen != null:
		for bird_id in states:
			_bird_codex_screen.set_unlocked(String(bird_id), bool(states[bird_id]))
	if _start_screen != null and _start_screen.has_method("set_bird_codex_progress"):
		var unlocked := 0
		for bird_id in states:
			if bool(states[bird_id]):
				unlocked += 1
		_start_screen.set_bird_codex_progress(unlocked, BirdCatalogData.ENTRIES.size())


func _on_credits_requested() -> void:
	if _credits_screen == null:
		return
	# The menu music steps aside so the credits page owns the audio.
	_bgm_player.stream_paused = true
	_credits_screen.present()


func _on_credits_back_requested() -> void:
	if _credits_screen == null:
		return
	await _credits_screen.dismiss()
	_bgm_player.stream_paused = false


func _build_start_screen() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 150
	add_child(canvas)
	_start_screen = StartScreenView.instantiate()
	_start_screen.connect("start_requested", _on_start_game_requested)
	_start_screen.connect("achievements_requested", _on_achievements_requested)
	_start_screen.connect("credits_requested", _on_credits_requested)
	_start_screen.connect("clear_save_requested", _on_clear_save_requested)
	_start_screen.connect("abandon_run_requested", _on_abandon_run_requested)
	_start_screen.connect("duel_host_requested", _on_duel_host_requested)
	_start_screen.connect("duel_join_requested", _on_duel_join_requested)
	_start_screen.connect("custom_requested", _on_custom_requested)
	_start_screen.connect("workshop_requested", _on_workshop_requested)
	_start_screen.connect("bird_codex_requested", _on_bird_codex_requested)
	canvas.add_child(_start_screen)
	_refresh_title_save_state()
	_refresh_achievement_banner()
	_refresh_bird_codex()


## 标题页上有两组和存档有关的东西：「清除存档」看文件在不在，「继续游戏／放弃本
## 轮」看有没有一轮打到一半。成就和进度共用一个文件，所以这两件事必须分开问。
func _refresh_title_save_state() -> void:
	if _start_screen == null:
		return
	_start_screen.set_save_available(GameSaveData.exists())
	# 「有一关打到一半」现在由续局槽说话，而不是看盘序走到哪——盘序在关卡之间会重置，
	# 单看它会把"刚通关一整关"误判成"还有半局没打完"。
	_start_screen.set_run_in_progress(_resume_stage_id != "")


func _on_clear_save_requested() -> void:
	GameSaveData.clear()
	_return_to_main_menu()
	_refresh_title_save_state()
	if _start_screen != null:
		_refresh_achievement_banner()


## 放弃本轮：留下成就、丢掉跑图进度。做法是直接写一份「只剩成就」的存档，再走一
## 遍回标题页的常规流程——那条路会把内存清空后重新读盘，读到的就是这份新档。
##
## FEAT-002：**已通关的关卡也要留下**。放弃的是手上那一关的半局进度，不是整张地图的
## 战绩——把 `cleared_stages` 一起清掉等于把玩家几小时的推图作废。
func _on_abandon_run_requested() -> void:
	GameSaveData.write({
		"current_level": 1,
		"tutorial_completed": false,
		"achievements": _unlocked_achievements.keys(),
		"cleared_stages": _cleared_stages.duplicate(),
		"resume_stage_id": "",
		"stage_round": 0,
		"music_break_played": _music_break_played,
		"intro_played": _intro_played,
		"stage_high_scores": _stage_high_scores.duplicate(),
		"endless_best_round": _endless_best_round,
		"leaderboard_name": _leaderboard_name,
	})
	_return_to_main_menu()


func _on_start_game_requested() -> void:
	if _start_screen == null:
		return
	var screen := _start_screen
	_start_screen = null
	if is_instance_valid(screen) and screen.get_parent() != null:
		screen.get_parent().queue_free()
	# 开场演出（耳机提示 + 开场剧情）每份存档放一次。
	# FEAT-002 一度把判据改成"地图上一片空白"，于是只要通关过任何一关就再也看不到了；
	# 现在按落盘的 `intro_played` 走：老档补放一次，放完记账，回标题再开始不会重放。
	var show_intro := not _intro_played
	if show_intro:
		if _headphone_notice != null:
			await _headphone_notice.present()
		if _opening_story != null:
			await _opening_story.present()
		_intro_played = true
		_save_progress()
	# 「开始」不再直接开棋盘，而是进世界地图选关（FEAT-002 共识 1）。
	_show_world_map()


func _process(delta: float) -> void:
	if _is_duel():
		_tick_duel()
	if _started and not _board.game_over:
		_elapsed += delta
		_time_label.text = "%03d" % mini(int(_elapsed), 999)
	if _super_luck_mode_active and _super_luck_clicks_remaining <= 0:
		_finish_super_luck_mode_after_clicks(_super_luck_mode_generation)
	_refresh_super_luck_watermark()
	_refresh_item_counter()
	var invincible := _is_invincible()
	if _player_status != null:
		_player_status.set_invincible(
			invincible,
			float(_super_luck_clicks_remaining) if _super_luck_mode_active else _invincible_seconds_left(),
			_super_luck_mode_active
		)
	if _invincible_was_active and not invincible:
		_status_label.text = "红隼效果结束，小心怪物攻击。"
	_invincible_was_active = invincible
	if _item_tooltip.visible:
		var viewport_size := get_viewport_rect().size
		var desired := get_viewport().get_mouse_position() + Vector2(22, 20)
		_item_tooltip.position = Vector2(
			clampf(desired.x, 12.0, viewport_size.x - _item_tooltip.size.x - 12.0),
			clampf(desired.y, 12.0, viewport_size.y - _item_tooltip.size.y - 12.0)
		)


func _input(event: InputEvent) -> void:
	if _regular_skip_control != null and _regular_skip_control.is_confirmation_open():
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT and mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if not mouse_event.pressed or _hovered_cell_index < 0:
		return
	_on_cell_mouse_button_changed(_hovered_cell_index, mouse_event.button_index, true)


func _build_interface() -> void:
	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("margin_left", 28)
	page.add_theme_constant_override("margin_right", 28)
	page.add_theme_constant_override("margin_top", 24)
	page.add_theme_constant_override("margin_bottom", 24)
	add_child(page)

	var board_stage := Control.new()
	board_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(board_stage)

	# Time remains a hidden data sink; remaining mines now have a compact counter
	# that floats above the board without affecting its centered layout.
	_time_label = Label.new()
	_time_label.visible = false
	board_stage.add_child(_time_label)

	var board_panel := PanelContainer.new()
	var grid_size := Vector2(
		CELL_SIZE * START_BOARD_SIZE + CELL_GAP * (START_BOARD_SIZE - 1),
		CELL_SIZE * START_BOARD_SIZE + CELL_GAP * (START_BOARD_SIZE - 1)
	)
	var panel_size := grid_size + Vector2(24, 24)
	board_stage.add_child(board_panel)
	board_panel.set_anchors_preset(Control.PRESET_CENTER)
	_set_centered_board_panel_rect(board_panel, panel_size)
	board_panel.add_theme_stylebox_override("panel", _bird_board_style())
	_board_panel = board_panel

	_tutorial_guide = TextureRect.new()
	_tutorial_guide.name = "TutorialGuide"
	_tutorial_guide.visible = false
	_tutorial_guide.custom_minimum_size = Vector2(360, 270)
	_tutorial_guide.texture = TUTORIAL_GUIDE_TEXTURE
	_tutorial_guide.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tutorial_guide.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tutorial_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_guide.z_index = 7
	_tutorial_guide.set_anchors_preset(Control.PRESET_CENTER)
	board_stage.add_child(_tutorial_guide)
	_position_tutorial_guide(panel_size)

	var mine_counter := _build_board_counter(
		"MineCounter", MONSTER_SMALL_TEXTURE, "剩余雷", MINE_COUNTER_SIZE, 54.0, "000"
	)
	_mine_counter_panel = mine_counter[0]
	_mine_label = mine_counter[1]
	_mine_caption_label = mine_counter[2]
	board_stage.add_child(_mine_counter_panel)

	_stage_board_label = Label.new()
	_stage_board_label.name = "StageBoardLabel"
	_stage_board_label.visible = false
	_stage_board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_board_label.add_theme_font_size_override("font_size", 26)
	_stage_board_label.add_theme_color_override("font_color", COLOR_INK)
	_stage_board_label.add_theme_color_override("font_outline_color", Color(0.97, 0.94, 0.88, 0.95))
	_stage_board_label.add_theme_constant_override("outline_size", 6)
	_stage_board_label.z_index = 8
	# 读数面板都是居中锚点 + 对称偏移；这条标签的偏移同样是围着中心算的，锚点不居中
	# 就会被甩到左上角外面去。
	_stage_board_label.set_anchors_preset(Control.PRESET_CENTER)
	board_stage.add_child(_stage_board_label)

	# 道具卡按类型分列：图标 + 剩余/总数，本关没有的类型不占位。
	_item_counter_panel = _build_item_type_counter()
	board_stage.add_child(_item_counter_panel)
	_position_board_counters(panel_size)

	_grid = Control.new()
	_grid.name = "MineCardGrid"
	_grid.custom_minimum_size = grid_size
	board_panel.add_child(_grid)
	_build_super_luck_watermark(board_panel)
	_build_combo_board_fx(board_panel)

	# Keep player health and gold as a fixed top-left HUD. It must not participate
	# in the stage VBox, otherwise showing it would push the board downward.
	_player_status = PlayerStatusView.instantiate()
	_player_status.position = Vector2(24, 18)
	_player_status.z_index = 9
	add_child(_player_status)
	_health_bar = _player_status.health_bar

	_score_combo = ScoreComboTrackerScript.new()
	_combo_hud = ComboScoreHudScript.new()
	_combo_hud.name = "ComboScoreHud"
	# 鸟架 z=50，连击柱必须压在鸟上面。
	_combo_hud.z_index = 80
	add_child(_combo_hud)
	_score_combo.changed.connect(_on_score_combo_changed)
	_score_combo.hit.connect(_on_score_combo_hit)
	_score_combo.combo_broke.connect(_on_score_combo_broke)
	_position_combo_hud()

	# Gameplay systems still write to these controls. They stay alive but hidden
	# until their bird-tool equivalents are ready.
	_status_label = Label.new()
	_status_label.visible = false
	board_stage.add_child(_status_label)
	_restart_button = Button.new()
	_restart_button.visible = false
	board_stage.add_child(_restart_button)

	_effects_layer = Control.new()
	_effects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Canvas z sorting is per-sibling: a high z inside this layer cannot climb
	# over the HUD's subtree, so the layer itself has to outrank the HUD. Modal
	# UI lives on its own CanvasLayer and still wins.
	_effects_layer.z_index = 50
	add_child(_effects_layer)

	# 标题页、耳机提示和开场剧情之间都有淡入淡出，任何一次穿帮都会露出底下这块
	# 空棋盘。第一关真正搭起来之前，棋盘和它的信息 UI 一律不存在于画面上。
	_hide_board_interface()


## 棋盘上方的小读数面板：图标 + 说明文字 + 数值。返回 `[面板, 数值 Label]`，让调用
## 方自己决定挂到哪里、以及怎么刷新数值。
func _build_board_counter(
	node_name: String,
	icon_texture: Texture2D,
	caption_text: String,
	counter_size: Vector2,
	value_width: float,
	initial_value: String
) -> Array:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.custom_minimum_size = counter_size
	panel.z_index = 8
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var counter_style := StyleBoxFlat.new()
	counter_style.bg_color = Color("172719ed")
	counter_style.border_color = Color("d7c073")
	counter_style.set_border_width_all(2)
	counter_style.set_corner_radius_all(15)
	counter_style.set_content_margin_all(9.0)
	counter_style.shadow_color = Color("10170d70")
	counter_style.shadow_size = 8
	counter_style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", counter_style)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(38, 38)
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var caption := Label.new()
	caption.name = "Caption"
	caption.text = caption_text
	caption.add_theme_color_override("font_color", Color("f4e8c1"))
	caption.add_theme_font_size_override("font_size", 20)
	row.add_child(caption)

	var value := Label.new()
	value.name = "Value"
	value.text = initial_value
	value.add_theme_color_override("font_color", Color("ffd768"))
	value.add_theme_color_override("font_outline_color", Color("302418"))
	value.add_theme_constant_override("outline_size", 4)
	value.add_theme_font_size_override("font_size", 28)
	value.custom_minimum_size.x = value_width
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)

	return [panel, value, caption]


## 连击表现层和超幸运水印一样挂在棋盘面板上：PanelContainer 会把每个子节点都摊成
## 同一块内容矩形，所以它的矩形就是格子区，烟花按这个矩形往外找盘沿。
## 挂面板而不是挂网格，是因为换盘时网格的子节点会被整批 queue_free；
## 挂在面板里还有一个好处——棋盘抖动时烟花跟着一起晃，不会和盘面脱开。
## 它自己把 z_index 设成负值，所以画在面板和格子**背后**。
func _build_combo_board_fx(board_panel: PanelContainer) -> void:
	_combo_board_fx = ComboBoardFxScript.new()
	_combo_board_fx.name = "ComboBoardFx"
	board_panel.add_child(_combo_board_fx)


func _build_super_luck_watermark(board_panel: PanelContainer) -> void:
	_super_luck_watermark = CenterContainer.new()
	_super_luck_watermark.name = "SuperLuckWatermark"
	_super_luck_watermark.z_index = 24
	_super_luck_watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_super_luck_watermark.visible = false
	board_panel.add_child(_super_luck_watermark)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", -8)
	_super_luck_watermark.add_child(stack)

	var title := Label.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "无敌次数"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.42))
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.07, 0.22))
	title.add_theme_constant_override("outline_size", 7)
	title.add_theme_font_size_override("font_size", 40)
	stack.add_child(title)

	_super_luck_watermark_count = Label.new()
	_super_luck_watermark_count.name = "Count"
	_super_luck_watermark_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_super_luck_watermark_count.text = "0"
	_super_luck_watermark_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_super_luck_watermark_count.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.46))
	_super_luck_watermark_count.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.07, 0.24))
	_super_luck_watermark_count.add_theme_constant_override("outline_size", 10)
	_super_luck_watermark_count.add_theme_font_size_override("font_size", 94)
	stack.add_child(_super_luck_watermark_count)


func _refresh_super_luck_watermark() -> void:
	if _super_luck_watermark == null or _super_luck_watermark_count == null:
		return
	var should_show := _super_luck_mode_active and _super_luck_clicks_remaining > 0
	_super_luck_watermark.visible = should_show
	if should_show:
		var count_text := "%d" % _super_luck_clicks_remaining
		if _super_luck_watermark_count.text != count_text:
			_super_luck_watermark_count.text = count_text


## 剩余道具：每种类型单独一格（图标 + 剩余/总数），不再加总成一个数。
func _build_item_type_counter() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ItemCounter"
	panel.custom_minimum_size = Vector2(ITEM_CHIP_WIDTH, ITEM_COUNTER_HEIGHT)
	panel.z_index = 8
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var counter_style := StyleBoxFlat.new()
	counter_style.bg_color = Color("172719ed")
	counter_style.border_color = Color("d7c073")
	counter_style.set_border_width_all(2)
	counter_style.set_corner_radius_all(15)
	counter_style.set_content_margin_all(8.0)
	counter_style.shadow_color = Color("10170d70")
	counter_style.shadow_size = 8
	counter_style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", counter_style)

	_item_type_row = HBoxContainer.new()
	_item_type_row.name = "ItemTypeRow"
	_item_type_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_item_type_row.add_theme_constant_override("separation", 8)
	_item_type_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_item_type_row)

	# 兼容旧测试/调试：保留一个隐藏的汇总 Label。
	_item_label = Label.new()
	_item_label.name = "Value"
	_item_label.visible = false
	panel.add_child(_item_label)
	return panel


func _rebuild_item_type_chips() -> void:
	if _item_type_row == null or _board == null:
		return
	for child in _item_type_row.get_children():
		_item_type_row.remove_child(child)
		child.free()
	_item_type_chips.clear()
	_item_type_remaining.clear()
	var shown := 0
	for item_type in ITEM_TYPE_ORDER:
		var total := _board.total_item_count_of(item_type)
		if total <= 0:
			continue
		var chip := _make_item_type_chip(item_type, total)
		_item_type_row.add_child(chip["root"])
		_item_type_chips[item_type] = chip
		_item_type_remaining[item_type] = -1
		shown += 1
	var width := maxf(ITEM_CHIP_WIDTH, float(shown) * ITEM_CHIP_WIDTH + 16.0)
	_item_counter_size = Vector2(width, ITEM_COUNTER_HEIGHT)
	if _item_counter_panel != null:
		_item_counter_panel.custom_minimum_size = _item_counter_size
	# 教程前几盘配置道具全为 0 时 chips 会空着；这里直接写读数，禁止再进
	# `_refresh_item_counter`——否则空 chips 又会回调 rebuild，栈溢出。
	_write_item_counter_labels(true)
	if _board_panel != null:
		_position_board_counters(_board_panel_size)


func _make_item_type_chip(item_type: int, total: int) -> Dictionary:
	var root := HBoxContainer.new()
	root.name = "ItemChip_%d" % item_type
	root.add_theme_constant_override("separation", 4)
	# 需要接悬停才能弹出功能说明；IGNORE 会吃掉 mouse_entered。
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_entered.connect(_on_item_counter_chip_hovered.bind(item_type))
	root.mouse_exited.connect(_on_item_counter_chip_unhovered)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.texture = _item_texture(item_type)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)

	var value := Label.new()
	value.name = "Count"
	value.text = "%d/%d" % [total, total]
	value.add_theme_color_override("font_color", Color("ffd768"))
	value.add_theme_color_override("font_outline_color", Color("302418"))
	value.add_theme_constant_override("outline_size", 3)
	value.add_theme_font_size_override("font_size", 22)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(value)
	return {"root": root, "label": value, "total": total}


func _on_item_counter_chip_hovered(item_type: int) -> void:
	_show_item_tooltip(item_type as MinesweeperBoard.ItemType)


func _on_item_counter_chip_unhovered() -> void:
	if _item_tooltip != null:
		_item_tooltip.visible = false


## 剩余道具读数按类型刷新。`force` 用于换盘重建后立刻写一遍。
func _refresh_item_counter(force: bool = false) -> void:
	if _board == null:
		return
	if _item_type_chips.is_empty() and _item_type_row != null:
		_rebuild_item_type_chips()
		return
	_write_item_counter_labels(force)


func _write_item_counter_labels(force: bool = false) -> void:
	if _board == null:
		return
	var any_drop := false
	var remaining_sum := 0
	var total_sum := 0
	for item_type in _item_type_chips.keys():
		var chip: Dictionary = _item_type_chips[item_type]
		var total := _board.total_item_count_of(item_type)
		var remaining := _board.hidden_item_count_of(item_type)
		remaining_sum += remaining
		total_sum += total
		var previous := int(_item_type_remaining.get(item_type, -1))
		if not force and previous == remaining and int(chip.get("total", -1)) == total:
			continue
		if previous >= 0 and remaining < previous:
			any_drop = true
			_play_item_chip_pulse(chip["label"])
		_item_type_remaining[item_type] = remaining
		chip["total"] = total
		var label: Label = chip["label"]
		label.text = "%d/%d" % [remaining, total]
		label.add_theme_color_override(
			"font_color", Color("9adf88") if remaining == 0 else Color("ffd768")
		)
		var root: Control = chip["root"]
		root.tooltip_text = "%s · 剩余 %d / 本关 %d" % [
			_item_display_name(item_type), remaining, total
		]
	if _item_label != null:
		_item_label.text = "%d/%d" % [remaining_sum, total_sum]
	_item_counter_shown = remaining_sum
	_item_counter_total = total_sum
	if any_drop:
		_play_item_counter_pulse()


func _play_item_chip_pulse(label: Label) -> void:
	if label == null or not label.is_inside_tree():
		return
	label.pivot_offset = label.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.28, 1.28), 0.08)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.22)


## 捡到一件道具时给读数一个回弹，让「少了一件」这件事在余光里也能被注意到。
func _play_item_counter_pulse() -> void:
	if _item_counter_panel == null or not _item_counter_panel.is_inside_tree():
		return
	if _item_counter_pulse != null and _item_counter_pulse.is_valid():
		_item_counter_pulse.kill()
	_item_counter_panel.pivot_offset = _item_counter_panel.size * 0.5
	_item_counter_panel.scale = Vector2.ONE
	_item_counter_pulse = create_tween()
	_item_counter_pulse.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_item_counter_pulse.tween_property(_item_counter_panel, "scale", Vector2(1.06, 1.06), 0.09)
	_item_counter_pulse.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_item_counter_pulse.tween_property(_item_counter_panel, "scale", Vector2.ONE, 0.24)


func _build_interface_legacy() -> void:
	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("margin_left", 42)
	page.add_theme_constant_override("margin_right", 42)
	page.add_theme_constant_override("margin_top", 42)
	page.add_theme_constant_override("margin_bottom", 42)
	add_child(page)

	# Stable left HUD plus a larger right-hand play stage, matching the target
	# composition while keeping every block replaceable as art arrives.
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 34)
	page.add_child(layout)

	_effects_layer = Control.new()
	_effects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Canvas z sorting is per-sibling: a high z inside this layer cannot climb
	# over the HUD's subtree, so the layer itself has to outrank the HUD. Modal
	# UI lives on its own CanvasLayer and still wins.
	_effects_layer.z_index = 50
	add_child(_effects_layer)

	var hud_panel := PanelContainer.new()
	hud_panel.custom_minimum_size.x = 440
	hud_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud_panel.add_theme_stylebox_override("panel", _hud_panel_style())
	layout.add_child(hud_panel)

	var header := VBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	header.add_theme_constant_override("separation", 20)
	hud_panel.add_child(header)

	var profile_row := HBoxContainer.new()
	profile_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	profile_row.add_theme_constant_override("separation", 20)
	header.add_child(profile_row)

	_player_status = PlayerStatusView.instantiate()
	profile_row.add_child(_player_status)
	_health_bar = _player_status.health_bar

	# These values remain available to gameplay code but are intentionally not
	# presented in the reduced HUD.
	_mine_label = Label.new()
	_mine_label.visible = false
	header.add_child(_mine_label)
	_item_label = Label.new()
	_item_label.visible = false
	header.add_child(_item_label)
	_time_label = Label.new()
	_time_label.visible = false
	header.add_child(_time_label)

	var game_row := HBoxContainer.new()
	game_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_row.alignment = BoxContainer.ALIGNMENT_CENTER
	game_row.add_theme_constant_override("separation", 34)
	layout.add_child(game_row)

	# Use container margins so the board root keeps its offset after relayouts.
	var board_lift := MarginContainer.new()
	board_lift.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_lift.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Bias the visual board root toward the lower-right of the play stage while
	# preserving the grid's local geometry and pointer coordinates.
	board_lift.add_theme_constant_override("margin_left", 156)
	board_lift.add_theme_constant_override("margin_top", 84)
	game_row.add_child(board_lift)

	var board_panel := PanelContainer.new()
	# Background is below this layer, while the scene decorations remain at 0.
	# This lets foreground rocks and trees naturally overlap the board edges.
	board_panel.z_index = -1
	board_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_panel.add_theme_stylebox_override("panel", _board_field_style())
	board_lift.add_child(board_panel)

	_grid = Control.new()
	_grid.custom_minimum_size = Vector2(
		CELL_SIZE * START_BOARD_SIZE + CELL_GAP * (START_BOARD_SIZE - 1),
		CELL_SIZE * START_BOARD_SIZE + CELL_GAP * (START_BOARD_SIZE - 1)
	)
	board_panel.add_child(_grid)

	var sidebar := PanelContainer.new()
	# Keep status/restart logic alive, but remove the task panel from the layout so
	# the board is the sole element in this row and is truly centered.
	sidebar.visible = false
	sidebar.custom_minimum_size = Vector2(330, 0)
	sidebar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sidebar.add_theme_stylebox_override("panel", _panel_style(Color("283522"), Color("53633d"), 20, 28))
	game_row.add_child(sidebar)

	var sidebar_content := VBoxContainer.new()
	sidebar_content.add_theme_constant_override("separation", 22)
	sidebar.add_child(sidebar_content)

	var chapter := Label.new()
	chapter.text = "今日任务"
	chapter.add_theme_color_override("font_color", COLOR_ACCENT)
	chapter.add_theme_font_size_override("font_size", 18)
	sidebar_content.add_child(chapter)

	_status_label = Label.new()
	_status_label.text = "从任意草地开始挖掘"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", COLOR_INK)
	_status_label.add_theme_font_size_override("font_size", 28)
	_status_label.custom_minimum_size.y = 88
	sidebar_content.add_child(_status_label)

	var rule := HSeparator.new()
	rule.modulate = Color("7f8c62")
	sidebar_content.add_child(rule)

	var instructions := Label.new()
	instructions.text = "左键  翻开地格\n右键  插上旗帜\n\n夜鹭翻开后会随机在周围翻开 1 个格子（必没有雷）。\n红尾水鸲会自动标出1个雷。\n啄木鸟会清横线上的格子/清竖线上的格子。\n红隼会让你在 1 步内无敌，踩中雷不掉血。"
	instructions.add_theme_color_override("font_color", COLOR_MUTED)
	instructions.add_theme_font_size_override("font_size", 18)
	instructions.add_theme_constant_override("line_spacing", 8)
	sidebar_content.add_child(instructions)

	_restart_button = Button.new()
	_restart_button.visible = false
	header.add_child(_restart_button)


func _build_item_tooltip() -> void:
	_item_tooltip = PanelContainer.new()
	_item_tooltip.z_index = 70
	_item_tooltip.custom_minimum_size = Vector2(350, 0)
	_item_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_tooltip.add_theme_stylebox_override("panel", _panel_style(Color("1c281be8"), Color("71834d"), 14, 16))
	_item_tooltip.visible = false
	add_child(_item_tooltip)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)
	_item_tooltip.add_child(content)

	_item_tooltip_title = Label.new()
	_item_tooltip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_tooltip_title.add_theme_color_override("font_color", COLOR_ACCENT)
	_item_tooltip_title.add_theme_font_size_override("font_size", 20)
	content.add_child(_item_tooltip_title)

	_item_tooltip_body = Label.new()
	_item_tooltip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_tooltip_body.custom_minimum_size.x = 318
	_item_tooltip_body.add_theme_color_override("font_color", COLOR_INK)
	_item_tooltip_body.add_theme_font_size_override("font_size", 16)
	content.add_child(_item_tooltip_body)


func _build_shop_interface() -> void:
	# Gameplay content uses elevated local z-indices for oversized monsters and
	# labels.  A dedicated CanvasLayer keeps modal UI above the entire world,
	# independent of those local draw-order values.
	var shop_canvas := CanvasLayer.new()
	shop_canvas.layer = 100
	add_child(shop_canvas)
	_shop_layer = ShopOverlayView.instantiate()
	_shop_layer.offer_selected.connect(_choose_shop_offer)
	_shop_layer.refresh_requested.connect(_on_shop_refresh_requested)
	_shop_layer.continue_pressed.connect(_on_shop_continue)
	_shop_layer.ready_pressed.connect(_on_duel_ready_pressed)
	_shop_layer.slot_replace_chosen.connect(_on_shop_slot_replace_chosen)
	_shop_layer.slot_replace_cancelled.connect(_on_shop_slot_replace_cancelled)
	_shop_layer.expand_slots_requested.connect(_on_shop_expand_slots)
	_shop_layer.visible = false
	shop_canvas.add_child(_shop_layer)


func _build_tutorial_skip_interface() -> void:
	var tutorial_canvas := CanvasLayer.new()
	tutorial_canvas.layer = 90
	add_child(tutorial_canvas)
	_tutorial_skip_button = TutorialSkipButtonView.instantiate()
	_tutorial_skip_button.skip_requested.connect(_skip_all_tutorials)
	tutorial_canvas.add_child(_tutorial_skip_button)


func _build_regular_skip_interface() -> void:
	var skip_canvas := CanvasLayer.new()
	skip_canvas.layer = 95
	add_child(skip_canvas)
	_regular_skip_control = RegularSkipControlView.instantiate()
	_regular_skip_control.skip_requested.connect(_request_skip_current_level)
	_regular_skip_control.skip_confirmed.connect(_confirm_skip_current_level)
	_regular_skip_control.skip_cancelled.connect(_cancel_skip_current_level)
	_regular_skip_control.return_requested.connect(_request_return_to_main_menu)
	_regular_skip_control.return_confirmed.connect(_confirm_return_to_main_menu)
	_regular_skip_control.return_cancelled.connect(_cancel_return_to_main_menu)
	skip_canvas.add_child(_regular_skip_control)


func _build_progression_interface() -> void:
	var progression_canvas := CanvasLayer.new()
	progression_canvas.layer = 110
	add_child(progression_canvas)
	_victory_banner = VictoryBannerView.instantiate()
	_stage_progress_banner = StageProgressBannerView.instantiate()
	_round_intro_banner = RoundIntroBannerScript.new()
	_round_intro_banner.name = "RoundIntroBanner"
	_level_bill = LevelBillView.instantiate()
	_game_over_overlay = GameOverOverlayView.instantiate()
	_night_heron_unlock = NightHeronUnlockView.instantiate()
	_redstart_unlock = RedstartUnlockView.instantiate()
	_attacker_unlock = AttackerUnlockView.instantiate()
	_kestrel_unlock = KestrelUnlockView.instantiate()
	_tit_unlock = TitUnlockView.instantiate()
	_magpie_unlock = MagpieUnlockView.instantiate()
	_crow_unlock = CrowUnlockView.instantiate()
	_dove_unlock = DoveUnlockView.instantiate()
	_game_over_overlay.return_requested.connect(_on_game_over_return)
	# 六个解锁页里的彩蛋各自对应一条成就，触发时由页面自己报上来。
	for unlock_page in [
		_night_heron_unlock, _redstart_unlock, _attacker_unlock, _kestrel_unlock, _tit_unlock,
		_magpie_unlock, _crow_unlock, _dove_unlock
	]:
		unlock_page.easter_egg_triggered.connect(_unlock_achievement)
	progression_canvas.add_child(_victory_banner)
	progression_canvas.add_child(_stage_progress_banner)
	progression_canvas.add_child(_round_intro_banner)
	progression_canvas.add_child(_level_bill)
	progression_canvas.add_child(_game_over_overlay)
	progression_canvas.add_child(_night_heron_unlock)
	progression_canvas.add_child(_redstart_unlock)
	progression_canvas.add_child(_attacker_unlock)
	progression_canvas.add_child(_kestrel_unlock)
	progression_canvas.add_child(_tit_unlock)
	progression_canvas.add_child(_magpie_unlock)
	progression_canvas.add_child(_crow_unlock)
	progression_canvas.add_child(_dove_unlock)
	_build_leaderboard_ui(progression_canvas)


func _build_leaderboard_ui(_parent: Node) -> void:
	# CanvasLayer 直接挂主场景，避免嵌在 progression CanvasLayer 里被盖住。
	_leaderboard_panel = LeaderboardPanelScript.new()
	_leaderboard_panel.name = "LeaderboardPanel"
	add_child(_leaderboard_panel)
	_leaderboard_panel.name_remembered.connect(_on_leaderboard_name_remembered)


func _choose_shop_offer(offer: ShopOffer) -> void:
	if _player_hp <= 0:
		return
	if _offer_sold_out(offer):
		return
	var price := _offer_price(offer)
	if _gold < price:
		_shop_layer.show_insufficient_gold(_gold, price)
		return
	# 鸟窝满了还要买这只鸟：这一步只挂起，等玩家点一格说换谁，那时才扣钱。
	if _is_slot_shop() and _is_slot_offer(offer) and _free_slot_index() < 0:
		_pending_slot_offer = offer
		_shop_layer.begin_slot_replacement(offer)
		return
	_gold -= price
	_refresh_gold_display()
	match offer:
		ShopOffer.MAX_HEALTH:
			_player_max_hp += 1
			_player_hp += 1
			_refresh_health_bar()
		ShopOffer.HEALING_POWER:
			_healing_power_bonus += 1
		ShopOffer.SUPER_LUCK_CACHE:
			_super_luck_bonus += 1
		ShopOffer.SUPER_LUCK_DURATION:
			_super_luck_click_bonus += 1
		ShopOffer.ORBITAL_STRIKE_CACHE:
			_orbital_strike_bonus += 1
		ShopOffer.ORBITAL_CROSS:
			if _orbital_cross_unlocked:
				_gold += price
				_refresh_gold_display()
				return
			_orbital_cross_unlocked = true
			_shop_layer.set_offer_owned(ShopOffer.ORBITAL_CROSS, true)
		ShopOffer.LANTERN_CACHE:
			_lantern_bonus += 1
		ShopOffer.LANTERN_RANGE:
			_lantern_target_bonus += 1
		ShopOffer.COMPASS_CACHE:
			_compass_bonus += 1
		ShopOffer.COMPASS_MARKS:
			_compass_mark_bonus += 1
		ShopOffer.XRAY_CACHE:
			_xray_bonus += 1
		ShopOffer.CHAIN_CACHE:
			_chain_bonus += 1
		ShopOffer.ENLARGE_CACHE:
			_enlarge_bonus += 1
	# 无尽关：这只鸟要住进窝里的空格。上面 match 刚把数值位 +1，落窝之后再照窝重算
	# 一遍，两边算出来是同一个数——窝始终是唯一真相。
	if _is_slot_shop() and _is_slot_offer(offer):
		if _place_in_free_slot(offer):
			_sync_bonuses_from_slots()
		else:
			push_warning("鸟窝没有空格，这笔购买没落进窝里：%d" % int(offer))
		_sync_shop_slots()
	_offer_purchase_counts[int(offer)] = int(_offer_purchase_counts.get(int(offer), 0)) + 1
	_sync_shop_offer_limits()
	_shop_layer.set_offer_prices(_offer_price_table())
	_shop_layer.mark_offer_sold_out(offer)
	_shop_layer.update_gold(_gold, SHOP_ITEM_COST)
	if _is_duel():
		# Q7 选了全公开：买了什么要立刻让对面看见。
		_duel.report_upgrade(offer)
		_duel.report_state(_player_hp, _player_max_hp, _gold)
	_save_progress()


## 同一件商品的第 n 次售价。次数记在 `_offer_purchase_counts` 里，跨关卡累计，直到这一
## 轮 run 结束才归零。
func _offer_price(offer: int) -> int:
	var bought := int(_offer_purchase_counts.get(int(offer), 0))
	return ceili(SHOP_ITEM_COST * pow(SHOP_PRICE_GROWTH, bought))


func _offer_price_table() -> Dictionary:
	var prices := {}
	for offer in range(ShopOffer.size()):
		prices[offer] = _offer_price(offer)
	return prices


## 关内红隼张数 = 商店买的（教学第 4 盘先送 1 只）；长尾山雀每关自带一张，所以要把
## `ENLARGE_COUNT` 也算进去，否则"最多 2 只"会变成"能买 2 只、实际拿 3 只"。
func _kestrel_item_count() -> int:
	return _super_luck_bonus


func _tit_item_count() -> int:
	return ENLARGE_COUNT + _enlarge_bonus


func _offer_sold_out(offer: int) -> bool:
	# 无尽关用鸟窝格子当上限（买第 4 只红隼要挤掉窝里的谁），不再叠这一层单品上限。
	if _is_slot_shop():
		return false
	if offer == ShopOffer.SUPER_LUCK_CACHE:
		return _kestrel_item_count() >= KESTREL_ITEM_LIMIT
	if offer == ShopOffer.ENLARGE_CACHE:
		return _tit_item_count() >= TIT_ITEM_LIMIT
	return false


## 把上限状态同步给商店。买满的那件会从抽取池里摘掉，货架上也不再出现。
func _sync_shop_offer_limits() -> void:
	if _shop_layer == null:
		return
	for offer in [ShopOffer.SUPER_LUCK_CACHE, ShopOffer.ENLARGE_CACHE]:
		_shop_layer.set_offer_exhausted(offer, _offer_sold_out(offer))


# --- 槽位制商店（鸟窝 · 无尽关）---


## 这一关的商店是不是鸟窝制。目前只有无尽关。
func _is_slot_shop() -> bool:
	return _is_endless_stage()


func _is_slot_offer(offer: int) -> bool:
	return SLOT_OFFER_BONUS.has(offer)


func _slot_capacity() -> int:
	return ENDLESS_SLOT_START + _endless_slot_expansions * ENDLESS_SLOT_PER_EXPANSION


func _slot_expansions_left() -> int:
	return maxi(ENDLESS_SLOT_EXPANSION_COSTS.size() - _endless_slot_expansions, 0)


## 下一次扩建的价钱；扩到头了返回 0。
func _slot_expand_cost() -> int:
	if _slot_expansions_left() <= 0:
		return 0
	return int(ENDLESS_SLOT_EXPANSION_COSTS[_endless_slot_expansions])


func _free_slot_index() -> int:
	return _endless_slots.find(ENDLESS_SLOT_EMPTY)


func _place_in_free_slot(offer: int) -> bool:
	var index := _free_slot_index()
	if index < 0:
		return false
	_endless_slots[index] = offer
	return true


## 照七个数值位把鸟摆回窝里（老档升级用）。窝不够大就补扩建，最多三次；
## 真超过 15 只（老档能叠出来）就只能割舍多出来的那几只。
func _rebuild_slots_from_bonuses() -> void:
	var birds: Array[int] = []
	for offer in SLOT_OFFER_BONUS:
		for _i in maxi(int(get(String(SLOT_OFFER_BONUS[offer]))), 0):
			birds.append(int(offer))
	var overflow := maxi(birds.size() - ENDLESS_SLOT_START, 0)
	_endless_slot_expansions = clampi(
		ceili(float(overflow) / float(ENDLESS_SLOT_PER_EXPANSION)),
		0,
		ENDLESS_SLOT_EXPANSION_COSTS.size()
	)
	_endless_slots.clear()
	for _i in _slot_capacity():
		_endless_slots.append(ENDLESS_SLOT_EMPTY)
	for index in mini(birds.size(), _endless_slots.size()):
		_endless_slots[index] = birds[index]


## **临时**（见 `endless_debug_loadout`）：无尽关的调试起手。鸟窝一步扩满并塞满各族
## 伙伴，于是每盘埋一大堆牌，奖励盘很容易被顶出来；不占格子的那几项强化一并拉满。
## 把那个常量翻成 false，这个函数就没人调了，删掉它也不影响任何正式逻辑。
func _apply_endless_debug_loadout() -> void:
	_endless_slot_expansions = ENDLESS_SLOT_EXPANSION_COSTS.size()
	_endless_slots.clear()
	var roster := [
		ShopOffer.LANTERN_CACHE, ShopOffer.COMPASS_CACHE, ShopOffer.ORBITAL_STRIKE_CACHE,
		ShopOffer.SUPER_LUCK_CACHE, ShopOffer.XRAY_CACHE, ShopOffer.CHAIN_CACHE,
		ShopOffer.ENLARGE_CACHE,
	]
	for slot in range(_slot_capacity()):
		_endless_slots.append(int(roster[slot % roster.size()]))
	_sync_bonuses_from_slots()
	_lantern_target_bonus = 3
	_compass_mark_bonus = 3
	_healing_power_bonus = 3
	_super_luck_click_bonus = 3
	_medical_kit_bonus = 2
	_orbital_cross_unlocked = true
	_player_max_hp = 9
	_player_hp = _player_max_hp
	_gold = 999
	_offer_purchase_counts.clear()
	print("【调试】无尽关起手按调试配置发放：鸟窝 %d 格全满、强化拉满、金币 %d。"
		% [_slot_capacity(), _gold]
		+ "关掉请把 main.gd 的 endless_debug_loadout 翻成 false。")


## 清空鸟窝，回到起手的 6 个空格。
func _reset_endless_slots() -> void:
	_endless_slots.clear()
	_endless_slot_expansions = 0
	_pending_slot_offer = -1
	for _i in ENDLESS_SLOT_START:
		_endless_slots.append(ENDLESS_SLOT_EMPTY)


## 进无尽关：`_prepare_stage_run()` 送的那四只鸟直接住进窝里，于是起手就是 4 / 6。
func _seed_endless_slots() -> void:
	_reset_endless_slots()
	for offer in [
		ShopOffer.LANTERN_CACHE, ShopOffer.COMPASS_CACHE,
		ShopOffer.ORBITAL_STRIKE_CACHE, ShopOffer.SUPER_LUCK_CACHE,
	]:
		_place_in_free_slot(offer)
	_sync_bonuses_from_slots()


## 照着鸟窝重算那七个数值位。窝是唯一真相，所以任何改动之后调它一次就够。
func _sync_bonuses_from_slots() -> void:
	if not _is_slot_shop():
		return
	var counts := {}
	for offer in SLOT_OFFER_BONUS:
		counts[offer] = 0
	for offer in _endless_slots:
		if counts.has(offer):
			counts[offer] = int(counts[offer]) + 1
	for offer in counts:
		set(String(SLOT_OFFER_BONUS[offer]), int(counts[offer]))


## 把鸟窝现状灌给商店。非无尽关就把整个面板关掉。
func _sync_shop_slots() -> void:
	if _shop_layer == null:
		return
	_shop_layer.set_nest_shop(_is_slot_shop())
	if not _is_slot_shop():
		return
	_shop_layer.set_slots(
		_endless_slots, _slot_expand_cost(), _slot_expansions_left(), ENDLESS_SLOT_PER_EXPANSION
	)


## 窝满时买鸟：玩家点了第 slot_index 格。到这一步才扣钱。
func _on_shop_slot_replace_chosen(slot_index: int) -> void:
	var offer := _pending_slot_offer
	if offer < 0 or not _is_slot_shop():
		return
	if slot_index < 0 or slot_index >= _endless_slots.size():
		return
	_pending_slot_offer = -1
	var price := _offer_price(offer)
	if _gold < price:
		# 挂起期间钱少了（对战报价同步之类）：作废这笔，别扣成负数。
		_shop_layer.end_slot_replacement()
		_shop_layer.show_insufficient_gold(_gold, price)
		return
	_gold -= price
	_refresh_gold_display()
	_endless_slots[slot_index] = offer
	_sync_bonuses_from_slots()
	_offer_purchase_counts[int(offer)] = int(_offer_purchase_counts.get(int(offer), 0)) + 1
	_shop_layer.end_slot_replacement()
	_sync_shop_slots()
	_shop_layer.set_offer_prices(_offer_price_table())
	_shop_layer.mark_offer_sold_out(offer)
	_shop_layer.update_gold(_gold, SHOP_ITEM_COST)
	_save_progress()


func _on_shop_slot_replace_cancelled() -> void:
	_pending_slot_offer = -1


## 花钱扩建鸟窝：一次 +2 格，最多三次。
func _on_shop_expand_slots() -> void:
	if not _is_slot_shop() or _slot_expansions_left() <= 0:
		return
	var price := _slot_expand_cost()
	if _gold < price:
		_shop_layer.show_insufficient_gold(_gold, price)
		return
	_gold -= price
	_refresh_gold_display()
	_endless_slot_expansions += 1
	for _i in ENDLESS_SLOT_PER_EXPANSION:
		_endless_slots.append(ENDLESS_SLOT_EMPTY)
	_sync_shop_slots()
	_shop_layer.update_gold(_gold, SHOP_ITEM_COST)
	_save_progress()


func _on_shop_continue() -> void:
	_start_game()


func _on_shop_refresh_requested() -> void:
	if _gold < SHOP_ITEM_COST:
		_shop_layer.show_insufficient_gold(_gold, SHOP_ITEM_COST)
		return
	_gold -= SHOP_ITEM_COST
	_refresh_gold_display()
	_sync_shop_offer_limits()
	_shop_layer.set_offer_prices(_offer_price_table())
	_shop_layer.refresh_offers(_gold, SHOP_ITEM_COST)
	_save_progress()


func _start_game() -> void:
	var boot := _run_boot_generation
	# 插播要抢在这一关搭起来之前：等它演完再往下走，商店和上一局的画面就一直被
	# 盖着，不会在名单和棋盘之间闪一下。
	if _run_number + 1 == MUSIC_BREAK_LEVEL and not _music_break_played:
		_music_break_played = true
		await _play_music_break()
		if boot != _run_boot_generation:
			return
	# A level can start while a hitstop is still pending — restarting or dying
	# mid-freeze would otherwise strand the whole game at 5% speed.
	_hitstop_generation += 1
	Engine.time_scale = 1.0
	_cancel_board_shake()
	_clear_inference_highlights()
	_clear_inference_hover_preview()
	_gold_rewarded_this_run = false
	_time_bonus_awarded_this_run = false
	_night_master_fish_count = 0
	_reset_score_combo_board()
	_run_number += 1
	_resume_level = _run_number
	# 本关内的盘计数和全局盘序分开走：教学关从 0 起、其余关卡从 TUTORIAL_LEVEL_COUNT
	# 起，只有这一个计数器能和目标盘数直接比。
	if _is_stage_run():
		_stage_round += 1
	# The tutorial is allowed to teach through damage without carrying that
	# penalty into the real run. This happens exactly once, on level five.
	if _run_number == TUTORIAL_LEVEL_COUNT + 1:
		_player_hp = _player_max_hp
	var first_tutorial := _run_number == 1
	var second_tutorial := _run_number == 2
	var later_tutorial := _run_number >= 3 and _run_number <= TUTORIAL_LEVEL_COUNT
	var normal_level_number := maxi(_run_number - TUTORIAL_LEVEL_COUNT, 0)
	var growth_steps := maxi(normal_level_number - BOARD_SIZE_HOLD_LEVELS, 0)
	# 第 1 盘是强引导盘：尺寸与雷数跟 GuidedTutorial 写死的布局走。
	var board_width := GuidedTutorial.WIDTH if first_tutorial else (4 if second_tutorial else (5 if later_tutorial else mini(START_BOARD_SIZE + growth_steps, MAX_BOARD_SIZE)))
	var board_height := GuidedTutorial.HEIGHT if first_tutorial else board_width
	var mine_count := GuidedTutorial.MINES.size() if first_tutorial else maxi(3, roundi(board_width * board_height * MINE_DENSITY))
	var active_mask := PackedByteArray()
	# 关卡通路：每盘形状与雷数走关卡表。对战仍用上面的尺寸曲线，不进异形。
	if _is_stage_run() and not _is_duel():
		# 无尽关按 (盘序, 本盘种子) 现抽形状与雷数；有盘列表的关忽略第三个参数。
		var board_cfg := StageTable.board_at(_stage_id, _stage_round, _level_seed_for_current_round())
		if board_cfg.is_empty():
			# 跳过末盘后盘序会 +1 越界；当作通关结算，别静默扔回地图。
			push_warning("关卡 %s 第 %d 盘没有配置，按通关结算" % [_stage_id, _stage_round])
			if boot != _run_boot_generation:
				return
			if _stage_target_round > 0 and _stage_round > _stage_target_round:
				_stage_round = _stage_target_round
				await _on_stage_cleared()
				return
			_resume_stage_id = ""
			_stage_id = ""
			_return_to_world_map()
			return
		var shape := BoardShape.get_shape(String(board_cfg["shape"]))
		assert(not shape.is_empty(), "形状库没有 %s" % String(board_cfg["shape"]))
		board_width = int(shape["width"])
		board_height = int(shape["height"])
		mine_count = int(board_cfg["mines"])
		active_mask = shape["mask"]
	var bird_only_tutorial := _run_number <= TUTORIAL_LEVEL_COUNT
	var lanterns := _lantern_bonus
	var compasses := _compass_bonus
	var orbital_strikes := _orbital_strike_bonus
	var super_lucks := _super_luck_bonus
	var medical_kits := 0 if bird_only_tutorial else MEDICAL_KIT_COUNT + _medical_kit_bonus
	var xrays := 0 if bird_only_tutorial else XRAY_COUNT + _xray_bonus
	var chains := 0 if bird_only_tutorial else CHAIN_COUNT + _chain_bonus
	var enlarges := 0 if bird_only_tutorial else ENLARGE_COUNT + _enlarge_bonus
	var detects := 0 if bird_only_tutorial else DETECT_COUNT
	# 自定义模式：形状、雷数、每种道具的数量全部照编辑器里填的来，不走任何曲线。
	if _is_custom():
		# 形状和雷数跟着**当前这张图**走；道具数量一律读 `*_bonus`——那是
		# `_prepare_custom_run` 用作者填的初始道具铺好的底，商店在图与图之间买到的加成
		# 直接叠在同一批变量上，所以后面几张图才拿得到玩家买的东西。
		var custom_map := CustomLevel.map_at(_custom_level, _custom_map_index)
		board_width = int(custom_map.get("width", 8))
		board_height = int(custom_map.get("height", 6))
		mine_count = int(custom_map.get("mines", 1))
		active_mask = (custom_map.get("mask", PackedByteArray()) as PackedByteArray).duplicate()
		lanterns = _lantern_bonus
		compasses = _compass_bonus
		orbital_strikes = _orbital_strike_bonus
		super_lucks = _super_luck_bonus
		medical_kits = _medical_kit_bonus
		xrays = _xray_bonus
		chains = _chain_bonus
		enlarges = _enlarge_bonus
		detects = CustomLevel.item_count(_custom_level, "detect")
	var level_seed := _level_seed_for_current_round()
	_board = BoardModel.new(
		board_width,
		board_height,
		mine_count,
		level_seed,
		lanterns,
		compasses,
		orbital_strikes,
		super_lucks,
		medical_kits,
		xrays,
		chains,
		enlarges,
		detects,
		active_mask
	)
	# 强引导盘不布随机雷：雷位是步骤表的一部分，玩家每一步指向的格子都得是确定的。
	var fixed_layout := first_tutorial and not _is_duel() and not _is_custom() and board_width == GuidedTutorial.WIDTH and board_height == GuidedTutorial.HEIGHT
	if fixed_layout:
		_board.place_fixed_mines(PackedInt32Array(GuidedTutorial.MINES))
	_player_hp = clampi(_player_hp, 0, _player_max_hp)
	_shop_layer.visible = false
	_resize_board_layout(board_width, board_height)
	_active_mines.clear()
	_defeated_mines.clear()
	_wrong_flagged_cells.clear()
	_close_bonus_board(true)
	_bonus_boards_this_round = 0
	_bonus_board_opening = false
	_bonus_board_waiters = 0
	_banked_flagged_mines = 0
	_banked_scored_mines = 0
	_invincible_until_msec = 0
	_pending_invincible_duration_msec = 0
	_invincible_was_active = false
	_super_luck_mode_active = false
	_super_luck_settling = false
	_super_luck_clicks_remaining = 0
	_super_luck_mode_generation += 1
	_clear_super_luck_pending_borders()
	_super_luck_deferred_indices.clear()
	_super_luck_deferred_lookup.clear()
	_super_luck_click_fly_count = 0
	_super_luck_activation_count = 0
	_prelaunched_item_indices.clear()
	_queued_bird_event_counts.clear()
	_active_item_settlements = 0
	_item_queue_dispatching = false
	_last_item_settlement_dispatch_frames.clear()
	_pending_bird_departures.clear()
	_bird_departure_generation += 1
	_bird_departure_dispatch_running = false
	_last_bird_departure_dispatch_times.clear()
	_last_bird_departure_dispatch_frames.clear()
	_last_lantern_noop = false
	_last_orbital_vertical = false
	_last_target_lock_indices.clear()
	_last_dashed_line_target_count = 0
	_last_compass_flyover_count = 0
	_last_lantern_fish_count = 0
	_chain_pending_triggers.clear()
	_chain_flush_active = false
	_enlarge_mark_charges = 0
	_enlarge_click_invincible = false
	_enlarge_hover_generation += 1
	_last_xray_target = -1
	_last_detect_target = -1
	_tutorial_first_reveal_pending = second_tutorial
	_tutorial_night_heron_edge_index = -1
	_end_guided_tutorial()
	_woodpecker_demo_pending = _run_number == 4 and _attacker_bird_unlocked and _orbital_strike_bonus > 0
	_woodpecker_demo_index = -1
	_kestrel_demo_pending = _run_number == 5 and _lucky_bird_unlocked and _super_luck_bonus > 0
	_kestrel_demo_index = -1
	# 教学最后一关送完长尾山雀，第一盘正式关首次翻开的区域里必定有一张它的牌。
	_tit_demo_pending = _run_number == TUTORIAL_LEVEL_COUNT + 1 and _tit_bird_unlocked
	_tit_demo_index = -1
	_crow_demo_pending = _run_number == TUTORIAL_LEVEL_COUNT + 1 and _crow_bird_unlocked
	_crow_demo_index = -1
	_dove_demo_pending = _run_number == TUTORIAL_LEVEL_COUNT + 1 and _dove_bird_unlocked
	_dove_demo_index = -1
	_hovered_cell_index = -1
	_item_tooltip.visible = false
	_started = false
	_resolving = false
	_game_finish_started = false
	_restart_button.disabled = false
	_elapsed = 0.0
	_time_label.text = "000"
	_status_label.text = "从任意草地开始挖掘"
	_status_label.add_theme_color_override("font_color", COLOR_INK)
	_mine_label.text = "%03d" % _board.mine_count
	# 新棋盘按本关实际道具种类重建分列读数。
	_rebuild_item_type_chips()
	_refresh_stage_board_label()
	_refresh_health_bar()
	_refresh_gold_display()
	for bird in [_blue_bird, _red_bird, _black_bird, _attacker_bird, _eg_bird, _tit_bird, _magpie_bird, _crow_bird, _dove_bird]:
		bird.reset_to_idle()
	_apply_bird_unlock_visibility()
	for child in _grid.get_children():
		child.queue_free()
	_cells.clear()
	for index in range(_board.width * _board.height):
		var cell: MineCell = CellView.instantiate()
		var row := index / _board.width
		var column := index % _board.width
		var cell_rect := Rect2(
			Vector2(column, row) * (_cell_size + CELL_GAP),
			Vector2.ONE * _cell_size
		)
		cell.configure(index, _cell_size)
		cell.primary_pressed.connect(_on_cell_revealed)
		cell.secondary_pressed.connect(_on_cell_flagged)
		cell.hover_started.connect(_on_cell_hover_started)
		cell.hover_ended.connect(_on_cell_hover_ended)
		_grid.add_child(cell)
		cell.position = cell_rect.position
		cell.size = cell_rect.size
		if _board.is_active(index):
			cell.set_ground_texture(_ground_tile(index, false))
			cell.display_covered()
		else:
			# 空洞格占位但不参与交互，避免被当成未开的雷格。
			cell.visible = false
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.disabled = true
		_cells.append(cell)
	if boot != _run_boot_generation:
		return
	# 强引导那一盘每一步指哪点哪，洗牌和开局横幅都会打断它的节奏；对战两边各自
	# 一张半屏盘，开局格由种子直接点出来，也没有发牌的位置。这两种情况都跳过。
	var deal_cards := not _is_duel() and not _is_guided_tutorial_round()
	if deal_cards:
		_prepare_board_deal()
	_reveal_board_interface()
	_update_tutorial_skip_visibility()
	_update_regular_skip_visibility()
	if _is_duel():
		_duel_hud.set_round(_duel.round_index, board_width, board_height)
		_refresh_duel_opponent()
		_duel.report_state(_player_hp, _player_max_hp, _gold)
		# 开局格由种子决定而不是由玩家点出来 —— 这正是双方棋盘能逐格一致的原因，
		# 顺带让首点安全自动成立，不需要任何「生成后搬雷」的补丁。
		var opening := MinesweeperBoard.opening_cell_for(level_seed, board_width, board_height)
		if opening >= 0:
			_resolve_turn(opening)
		return
	# 这一盘的起点状态到这里已经齐了，先落盘再演开局横幅：横幅是一长串 await，
	# 中途玩家关游戏（或演出本身出问题）时，存档里记的仍是这一盘的开头，而不是
	# 上一盘——否则重开后会被退回去重打一盘，看起来就像"进度没了"。
	_save_progress()
	# 关卡每一盘开局先报进度，让玩家知道「还剩几盘」。
	if _is_stage_run() and _stage_progress_banner != null and (_stage_target_round > 0 or _is_endless_stage()):
		var stage := StageTable.stage(_stage_id)
		await _stage_progress_banner.present(
			String(stage.get("name", _stage_id)),
			_stage_round,
			_stage_target_round
		)
		if boot != _run_boot_generation:
			return
	if deal_cards:
		# 发牌到横幅收走这一段棋盘不接受点击，免得玩家在牌还在飞的时候就点下去。
		_set_board_interactable(false)
		await _play_board_deal_shuffle()
		if boot != _run_boot_generation:
			return
		if _round_intro_banner != null:
			await _round_intro_banner.present(
				_round_intro_entries(), "", _round_intro_banner_top()
			)
			if boot != _run_boot_generation:
				return
		if not _resolving:
			_set_board_interactable(true)
	_unlock_achievement(ACHIEVEMENT_START_GAME)
	if _is_guided_tutorial_round():
		_begin_guided_tutorial(boot)


func _resize_board_layout(columns: int, rows: int) -> void:
	_apply_split_layout(columns, rows)
	var grid_size := Vector2(
		_cell_size * columns + CELL_GAP * (columns - 1),
		_cell_size * rows + CELL_GAP * (rows - 1)
	)
	_grid.custom_minimum_size = grid_size
	_grid.size = grid_size
	var panel_size := grid_size + Vector2(SPLIT_PANEL_PADDING, SPLIT_PANEL_PADDING)
	_set_centered_board_panel_rect(_board_panel, panel_size)
	if _is_duel():
		# 右屏那块位的行列与格子边长全部取自**本地**棋盘：双方同种子同曲线，尺寸
		# 必然相同，所以画出对手的盘不需要任何网络数据。
		_duel_hud.set_opponent_board(columns, rows, _cell_size, CELL_GAP, _board_center_offset)


## 算出这一关的格子边长与棋盘位移。单机走原来的居中全屏，分屏才收缩并左移。
func _apply_split_layout(columns: int, rows: int) -> void:
	if not _is_duel():
		_apply_solo_board_fit(columns, rows)
		if _player_status != null:
			_player_status.scale = Vector2.ONE
			if _player_status.has_method("set_compact_hearts"):
				_player_status.set_compact_hearts(false)
		return
	var available := Vector2(
		SPLIT_VIEWPORT.x * 0.5 - SPLIT_MARGIN * 2.0 - SPLIT_PANEL_PADDING,
		SPLIT_VIEWPORT.y - SPLIT_HUD_BAND - SPLIT_BOTTOM_MARGIN - SPLIT_PANEL_PADDING
	)
	var fit_width := (available.x - CELL_GAP * (columns - 1)) / float(maxi(columns, 1))
	var fit_height := (available.y - CELL_GAP * (rows - 1)) / float(maxi(rows, 1))
	# 上限锁死在 CELL_SIZE：小棋盘按可用空间算能涨到 140，但整套牌面美术是按 88
	# 调的，放大只会露馅。缩得下就缩，绝不放大。
	_cell_size = minf(CELL_SIZE, minf(fit_width, fit_height))
	var board_band_center := SPLIT_HUD_BAND + (SPLIT_VIEWPORT.y - SPLIT_HUD_BAND - SPLIT_BOTTOM_MARGIN) * 0.5
	var rest_center_y := SPLIT_VIEWPORT.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT
	_board_center_offset = Vector2(-SPLIT_CENTER_SHIFT, board_band_center - rest_center_y)
	if _player_status != null:
		_player_status.scale = Vector2.ONE * SPLIT_STATUS_SCALE
		if _player_status.has_method("set_compact_hearts"):
			_player_status.set_compact_hearts(true)


## 单机的格子边长与棋盘位移。棋盘锚在屏幕正中，读数叠挂在它头顶：盘一大（10×10
## 时「读数叠 + 棋盘」高 1155px，比 1080 的画布还高），这叠东西就被顶出屏幕，玩家
## 看不见还剩多少雷。这里把读数叠和棋盘当成一整块来量：先只往下挪，挪不开才把格子
## 等比收一档（10×10 约 0.89，小到美术看不出来），再把整块摆进上下留白之间。
## 装得下的小盘一格都不动，仍是原来的居中版式。
func _apply_solo_board_fit(columns: int, rows: int) -> void:
	# 一整块能用的高度 = 画布 - 上下留白 - 头顶那叠读数。
	var band := (
		DESIGN_VIEWPORT.y - BOARD_FIT_TOP_MARGIN - BOARD_FIT_BOTTOM_MARGIN
		- BOARD_COUNTER_STACK_HEIGHT
	)
	# 格子之外的固定开销：格间距 + 棋盘边框内衬。
	var extra_height := CELL_GAP * float(maxi(rows - 1, 0)) + SPLIT_PANEL_PADDING
	var extra_width := CELL_GAP * float(maxi(columns - 1, 0)) + SPLIT_PANEL_PADDING
	var fit_height := (band - extra_height) / float(maxi(rows, 1))
	var fit_width := (
		(DESIGN_VIEWPORT.x - BOARD_FIT_SIDE_MARGIN * 2.0 - extra_width) / float(maxi(columns, 1))
	)
	# 只缩不放：牌面美术是按 88 调的，放大就露馅。
	_cell_size = maxf(minf(CELL_SIZE, minf(fit_width, fit_height)), 1.0)
	var panel_height := _cell_size * rows + extra_height
	# 默认版式下这一整块的顶沿（读数叠最上边）落在哪；超出画布多少就往下挪多少。
	var rest_top := (
		DESIGN_VIEWPORT.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT
		- panel_height * 0.5 - BOARD_COUNTER_STACK_HEIGHT
	)
	_board_center_offset = Vector2(0.0, maxf(BOARD_FIT_TOP_MARGIN - rest_top, 0.0))


func _set_centered_board_panel_rect(panel: Control, panel_size: Vector2) -> void:
	# The panel is center-anchored. Writing `position` before/after a resize mixes
	# viewport coordinates with anchor-relative offsets and can send it toward the
	# top-left. Keep all four offsets explicitly symmetric around the anchor.
	# Shake rides on top of this rest pose, so a resize has to drop any live shake
	# instead of baking its current displacement into the new rest position.
	_board_panel_size = panel_size
	_cancel_board_shake()
	panel.offset_left = -panel_size.x * 0.5 + _board_center_offset.x
	panel.offset_right = panel_size.x * 0.5 + _board_center_offset.x
	panel.offset_top = -panel_size.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT + _board_center_offset.y
	panel.offset_bottom = panel_size.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT + _board_center_offset.y
	_position_board_counters(panel_size)
	_position_tutorial_guide(panel_size)
	_position_combo_hud()


## 两块读数面板叠成两行，居中在棋盘正上方：上一行剩余雷，下一行分列道具。
func _position_board_counters(board_panel_size: Vector2) -> void:
	if _mine_counter_panel == null:
		return
	var stack_bottom := (
		-board_panel_size.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT
		+ _board_center_offset.y - BOARD_COUNTER_STACK_GAP
	)
	if _is_duel():
		# 分屏下读数贴在左半屏棋盘上方，避开顶部自身 HUD 带。
		stack_bottom = SPLIT_HUD_BAND - SPLIT_VIEWPORT.y * 0.5 - 10.0

	var item_height := _item_counter_size.y if _item_counter_panel != null else 0.0
	var stack_width := MINE_COUNTER_SIZE.x
	if _item_counter_panel != null:
		stack_width = maxf(stack_width, _item_counter_size.x)
	var stack_left := -stack_width * 0.5 + _board_center_offset.x
	if _is_duel():
		stack_left = -SPLIT_MARGIN - stack_width

	# 下一行：道具（更靠近棋盘）
	var item_bottom := stack_bottom
	var item_top := item_bottom - item_height
	# 上一行：剩余雷
	var mine_bottom := item_top - BOARD_COUNTER_GAP if _item_counter_panel != null else stack_bottom
	var mine_top := mine_bottom - MINE_COUNTER_SIZE.y
	var mine_left := stack_left + (stack_width - MINE_COUNTER_SIZE.x) * 0.5

	_mine_counter_panel.offset_left = mine_left
	_mine_counter_panel.offset_right = mine_left + MINE_COUNTER_SIZE.x
	_mine_counter_panel.offset_top = mine_top
	_mine_counter_panel.offset_bottom = mine_bottom
	if _stage_board_label != null:
		var label_h := STAGE_BOARD_LABEL_HEIGHT
		var label_w := STAGE_BOARD_LABEL_WIDTH
		var label_bottom := mine_top - STAGE_BOARD_LABEL_GAP
		var label_left := stack_left + (stack_width - label_w) * 0.5
		_stage_board_label.offset_left = label_left
		_stage_board_label.offset_right = label_left + label_w
		_stage_board_label.offset_top = label_bottom - label_h
		_stage_board_label.offset_bottom = label_bottom
	if _item_counter_panel == null:
		return
	var item_left := stack_left + (stack_width - _item_counter_size.x) * 0.5
	_item_counter_panel.offset_left = item_left
	_item_counter_panel.offset_right = item_left + _item_counter_size.x
	_item_counter_panel.offset_top = item_top
	_item_counter_panel.offset_bottom = item_bottom


func _position_tutorial_guide(board_panel_size: Vector2) -> void:
	if _tutorial_guide == null:
		return
	# The source has transparent padding above its drawings. Pulling the texture
	# rect slightly under the panel leaves the first visible pixel just below it.
	var guide_size := Vector2(360, 270)
	var board_bottom := (
		board_panel_size.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT
		+ _board_center_offset.y
	)
	var top := board_bottom - 38.0
	_tutorial_guide.offset_left = -guide_size.x * 0.5 + _board_center_offset.x
	_tutorial_guide.offset_right = guide_size.x * 0.5 + _board_center_offset.x
	_tutorial_guide.offset_top = top
	_tutorial_guide.offset_bottom = top + guide_size.y


## 棋盘本体（边框 + 网格）、剩余雷计数和左上角的血量金币 HUD 是一整套「关卡里才
## 该出现」的东西，统一由这两个函数开关，免得漏掉其中一件。
func _board_interface_nodes() -> Array[Control]:
	var nodes: Array[Control] = []
	for node in [_board_panel, _mine_counter_panel, _item_counter_panel, _player_status, _combo_hud, _stage_board_label]:
		if node != null:
			nodes.append(node as Control)
	return nodes


func _refresh_stage_board_label() -> void:
	if _stage_board_label == null:
		return
	if _is_custom():
		var custom_total := CustomLevel.map_count(_custom_level)
		var custom_progress := " · %d/%d" % [_custom_map_index + 1, custom_total] if custom_total > 1 else ""
		_stage_board_label.text = "自定义 · %s%s" % [
			String(_custom_level.get("name", "")), custom_progress
		]
		_stage_board_label.visible = _board_interface_shown
		return
	if not _is_stage_run() or _is_duel() or (_stage_target_round <= 0 and not _is_endless_stage()):
		_stage_board_label.visible = false
		return
	var stage := StageTable.stage(_stage_id)
	var stage_name := String(stage.get("name", ""))
	if _is_endless_stage():
		_stage_board_label.text = "%s · 第 %d 盘 · 无尽" % [stage_name, _stage_round]
	else:
		_stage_board_label.text = "%s · 第 %d / %d 盘" % [
			stage_name, _stage_round, _stage_target_round
		]
	_stage_board_label.visible = _board_interface_shown


func _hide_board_interface() -> void:
	_board_interface_shown = false
	if _board_interface_fade != null and _board_interface_fade.is_valid():
		_board_interface_fade.kill()
	for node in _board_interface_nodes():
		node.visible = false
		node.modulate.a = 1.0


## 关卡开场时才把这套 UI 交回画面。淡入是给标题→剧情→第一关这条链路准备的：剧情
## 的底片刚化开，棋盘硬弹出来会很突兀。局间换关时它本来就亮着，直接返回。
func _reveal_board_interface() -> void:
	if _board_interface_shown:
		return
	_board_interface_shown = true
	if _board_interface_fade != null and _board_interface_fade.is_valid():
		_board_interface_fade.kill()
	_board_interface_fade = create_tween().set_parallel(true)
	_board_interface_fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for node in _board_interface_nodes():
		node.modulate.a = 0.0
		# 对战不显示单机连击分；左右对称靠血金/标雷进度，不靠角落 combo。
		if node == _combo_hud and _is_duel():
			node.visible = false
			continue
		node.visible = true
		_board_interface_fade.tween_property(node, "modulate:a", 1.0, 0.3)
	_refresh_stage_board_label()


func _apply_bird_unlock_visibility() -> void:
	# 图鉴跟着同一批解锁位走，挂在最前面：底下那条对战早退的分支不该让它漏掉一次刷新。
	_refresh_bird_codex()
	# Each perch scene owns both its bird and its branch. Hiding the root keeps
	# the whole locked partner silhouette out of the gameplay composition.
	# 对战分屏里左右都是棋盘，外围栖枝会压住半屏；道具飞入仍走特效层，不受影响。
	if _is_duel():
		for bird in [_blue_bird, _red_bird, _black_bird, _attacker_bird, _eg_bird, _tit_bird, _magpie_bird, _crow_bird, _dove_bird]:
			bird.visible = true
			bird.set_stowed(true)
		return
	for bird in [_blue_bird, _red_bird, _black_bird, _attacker_bird, _eg_bird, _tit_bird, _magpie_bird, _crow_bird, _dove_bird]:
		bird.set_stowed(false)
	_blue_bird.visible = _blue_bird_unlocked
	_red_bird.visible = _red_bird_unlocked
	_black_bird.visible = _night_heron_unlocked
	_attacker_bird.visible = _attacker_bird_unlocked
	_eg_bird.visible = _lucky_bird_unlocked
	_tit_bird.visible = _tit_bird_unlocked
	_magpie_bird.visible = _magpie_bird_unlocked
	_crow_bird.visible = _crow_bird_unlocked
	_dove_bird.visible = _dove_bird_unlocked


func _update_tutorial_skip_visibility() -> void:
	var tutorial_active := _run_number >= 1 and _run_number <= TUTORIAL_LEVEL_COUNT
	if _tutorial_skip_button != null:
		_tutorial_skip_button.set_available(tutorial_active)
	if _tutorial_guide != null:
		if tutorial_active:
			_tutorial_guide.texture = (
				TUTORIAL_GUIDE_2_TEXTURE if _run_number >= 3
				else TUTORIAL_GUIDE_TEXTURE
			)
		# 第 1 盘由强引导逐步讲，静态说明图从第 2 盘起再出现。
		_tutorial_guide.visible = tutorial_active and not _is_guided_tutorial_round()


func _update_regular_skip_visibility() -> void:
	if _regular_skip_control != null:
		_regular_skip_control.set_return_destination("编辑器" if _is_custom() else "主界面")
		# 对战里跳过/返回会单端拆盘，且是单机控件残留。
		_regular_skip_control.set_available(
			not _is_duel()
			and _run_number > TUTORIAL_LEVEL_COUNT
			and not _game_finish_started
		)


func _request_skip_current_level() -> void:
	if (
		_board == null
		or _run_number <= TUTORIAL_LEVEL_COUNT
		or _resolving
		or _game_finish_started
		or _board.game_over
	):
		return
	_set_board_interactable(false)
	_regular_skip_control.open_confirmation()


func _cancel_skip_current_level() -> void:
	if _board != null and not _board.game_over and not _resolving and not _game_finish_started:
		_set_board_interactable(true)


func _confirm_skip_current_level() -> void:
	if (
		_board == null
		or _run_number <= TUTORIAL_LEVEL_COUNT
		or _resolving
		or _game_finish_started
		or _board.game_over
	):
		return
	# A skipped board never reaches the bill or shop, so none of its flags or
	# night-master fish can be converted into gold.
	_regular_skip_control.set_available(false)
	_started = false
	_set_board_interactable(false)
	# 正在打本关最后一盘时跳过 = 通关，走结算/排行，不要再 +1 盘序踩空。
	if _is_stage_run() and _stage_target_round > 0 and _stage_round >= _stage_target_round:
		await _on_stage_cleared()
		return
	_start_game()


func _request_return_to_main_menu() -> void:
	if (
		_board == null
		or _run_number <= TUTORIAL_LEVEL_COUNT
		or _resolving
		or _game_finish_started
		or _board.game_over
	):
		return
	_set_board_interactable(false)
	_regular_skip_control.open_return_confirmation()


func _cancel_return_to_main_menu() -> void:
	if _board != null and not _board.game_over and not _resolving and not _game_finish_started:
		_set_board_interactable(true)


func _confirm_return_to_main_menu() -> void:
	if (
		_board == null
		or _run_number <= TUTORIAL_LEVEL_COUNT
		or _resolving
		or _game_finish_started
		or _board.game_over
	):
		return
	_started = false
	_set_board_interactable(false)
	if _is_custom():
		_return_to_custom_editor()
		return
	_return_to_main_menu()


func _skip_all_tutorials() -> void:
	if (
		_board == null
		or _run_number < 1
		or _run_number > TUTORIAL_LEVEL_COUNT
		or _resolving
		or _game_finish_started
	):
		return
	_tutorial_skip_button.set_available(false)
	_end_guided_tutorial()
	_night_heron_unlocked = true
	_red_bird_unlocked = true
	_attacker_bird_unlocked = true
	_lucky_bird_unlocked = true
	_tit_bird_unlocked = true
	_magpie_bird_unlocked = true
	_crow_bird_unlocked = true
	_dove_bird_unlocked = true
	_lantern_bonus = maxi(_lantern_bonus, 1)
	_compass_bonus = maxi(_compass_bonus, 1)
	_orbital_strike_bonus = maxi(_orbital_strike_bonus, 1)
	_super_luck_bonus = maxi(_super_luck_bonus, 1)
	_player_hp = _player_max_hp
	_tutorial_first_reveal_pending = false
	_tutorial_night_heron_edge_index = -1
	_woodpecker_demo_pending = false
	_woodpecker_demo_index = -1
	_tit_demo_pending = false
	_tit_demo_index = -1
	_crow_demo_pending = false
	_crow_demo_index = -1
	_dove_demo_pending = false
	_dove_demo_index = -1
	_run_number = TUTORIAL_LEVEL_COUNT
	_start_game()


## --- 新手强引导 (GuidedTutorial / GuidedItemLesson) ---
## 第 1 盘：棋盘布局与步骤表在 scripts/game/guided_tutorial.gd；第 2 盘：伙伴牌课在
## scripts/game/guided_item_lesson.gd（含伙伴图鉴内容）。演出层在 scripts/ui/guided_tutorial_overlay.gd，
## 图鉴页在 scripts/ui/item_guide_screen.gd；这里只做编排：什么时候进下一步、放行哪一次点击。
func _build_guided_tutorial_overlay() -> void:
	_guided_overlay = GuidedTutorialOverlay.new()
	_guided_overlay.name = "GuidedTutorialOverlay"
	_guided_overlay.next_pressed.connect(_on_guided_tutorial_next)
	add_child(_guided_overlay)
	_item_guide_screen = ItemGuideScreen.new()
	_item_guide_screen.name = "ItemGuideScreen"
	_item_guide_screen.closed.connect(_on_item_guide_closed)
	add_child(_item_guide_screen)


## 只有单机流程的前两盘走强引导：第 1 盘教操作，第 2 盘（夜鹭刚解锁）教伙伴牌。
## 对战与自定义的盘序都从教学段之后起跳，天然不进这里。
func _is_guided_tutorial_round() -> bool:
	return _guided_lesson_for_round() != null and not _is_duel() and not _is_custom()


func _guided_lesson_for_round() -> GDScript:
	match _run_number:
		1:
			return GuidedTutorial
		2:
			return GuidedItemLesson
	return null


func _guided_tutorial_active() -> bool:
	return _guided_step >= 0 and _guided_lesson != null and _guided_overlay != null and _guided_overlay.is_presenting()


## 第 2 盘第一步还没走完：夜鹭牌翻出来时要先停下来讲，鸟不能在这之前就从枝头起飞。
func _guided_item_intro_pending() -> bool:
	return _guided_lesson == GuidedItemLesson and _guided_step == 0


func _begin_guided_tutorial(boot: int) -> void:
	var lesson := _guided_lesson_for_round()
	if boot != _run_boot_generation or _board == null or lesson == null:
		return
	if lesson == GuidedTutorial and not GuidedTutorial.layout_matches(_board):
		return
	# 等一帧让棋盘完成排版，洞和小手才落在格子的真实位置上。
	var board := _board
	await get_tree().process_frame
	# 这一帧里可能已经开了下一盘（连点重开 / 跳过教学），那就不是这盘的课了。
	if boot != _run_boot_generation or _board != board or _guided_lesson_for_round() != lesson:
		return
	if _game_finish_started or _cells.is_empty() or _board == null:
		return
	_guided_lesson = lesson
	_guided_step = 0
	_present_guided_step()


func _present_guided_step() -> void:
	var step: Dictionary = _guided_lesson.step(_guided_step) if _guided_lesson != null else {}
	if step.is_empty() or _guided_overlay == null:
		_end_guided_tutorial()
		return
	var hole := Rect2()
	match int(step["focus"]):
		GuidedTutorial.Focus.HEALTH:
			hole = _health_bar.get_global_rect().grow(18.0)
		GuidedTutorial.Focus.BOARD_ALL:
			hole = _cells_bounding_rect(_active_cell_indices()).grow(GUIDED_HOLE_PADDING)
		GuidedTutorial.Focus.ITEM:
			if _tutorial_night_heron_edge_index >= 0:
				hole = _cells_bounding_rect([_tutorial_night_heron_edge_index]).grow(GUIDED_HOLE_PADDING)
		_:
			hole = _cells_bounding_rect(step["spot"]).grow(GUIDED_HOLE_PADDING)
	var target := int(step["target"])
	var pointer := Vector2.INF
	var pointer_cell := target if target >= 0 else int(step.get("pointer_cell", -1))
	if pointer_cell >= 0 and pointer_cell < _cells.size():
		pointer = _cell_center(pointer_cell)
	var highlights: Array = step.get("highlight", [])
	if int(step["focus"]) == GuidedTutorial.Focus.ITEM and _tutorial_night_heron_edge_index >= 0:
		highlights = [_tutorial_night_heron_edge_index]
	for highlighted in highlights:
		var cell_index := int(highlighted)
		if cell_index >= 0 and cell_index < _cells.size():
			_cells[cell_index].play_border_flash(Color("ffd36b"), 5, 0.14)
	_guided_overlay.present_step({
		"hole": hole,
		"interactive": bool(step["interactive"]),
		"pointer": pointer,
		"pointer_side": String(step.get("pointer_side", "right")),
		"hint": String(step["hint"]),
		"text": _guided_lesson.step_bbcode(_guided_step),
		"show_next": int(step["action"]) == GuidedTutorial.Action.NEXT,
		"next_text": String(step.get("next_text", "知道了  »")),
		"step_index": _guided_step,
		"step_count": _guided_lesson.step_count(),
	})


func _active_cell_indices() -> Array:
	var indices: Array = []
	for index in range(_cells.size()):
		if _board == null or _board.is_active(index):
			indices.append(index)
	return indices


func _cells_bounding_rect(indices: Array) -> Rect2:
	var rect := Rect2()
	var first := true
	for entry in indices:
		var index := int(entry)
		if index < 0 or index >= _cells.size():
			continue
		var cell_rect := _cells[index].get_global_rect()
		rect = cell_rect if first else rect.merge(cell_rect)
		first = false
	return rect


## 棋盘每次回到可点状态就来问一句：这一步的目标达成了没有。达成就进下一步（连着达成的
## 一并跳过）。演出中途收起过引导层的（第 2 盘「看它表演」），棋盘回来了先把当前步亮回来。
func _sync_guided_tutorial() -> void:
	if _guided_step < 0 or _guided_lesson == null or _guided_overlay == null or _game_finish_started or _board == null:
		return
	if _item_guide_screen != null and _item_guide_screen.is_open():
		return
	var advanced := false
	while _guided_step < _guided_lesson.step_count() and _guided_lesson.is_step_done(_guided_step, _board):
		_guided_step += 1
		advanced = true
	if _guided_step >= _guided_lesson.step_count():
		_end_guided_tutorial()
		return
	if advanced or not _guided_overlay.is_presenting():
		_present_guided_step()


func _advance_guided_tutorial() -> void:
	_guided_step += 1
	if _guided_lesson == null or _guided_step >= _guided_lesson.step_count():
		_end_guided_tutorial()
		return
	_present_guided_step()


func _on_guided_tutorial_next() -> void:
	if not _guided_tutorial_active():
		return
	var step: Dictionary = _guided_lesson.step(_guided_step)
	if step.is_empty() or int(step["action"]) != GuidedTutorial.Action.NEXT:
		return
	if bool(step.get("opens_guide", false)):
		# 最后一步：收起引导层、弹伙伴图鉴；图鉴关掉就算这堂课上完了。
		_guided_overlay.dismiss()
		_item_guide_screen.present()
		return
	if bool(step.get("resume_on_board", false)):
		# 先让开让玩家看演出，棋盘回到可点状态时 _sync_guided_tutorial 再亮出下一步。
		_guided_step += 1
		_guided_overlay.dismiss()
		return
	_advance_guided_tutorial()


func _on_item_guide_closed() -> void:
	if _guided_lesson == null:
		return
	_end_guided_tutorial()
	if not _game_finish_started and _board != null and not _board.game_over:
		_status_label.text = "继续排查，别踩到它们。"


## 第 2 盘：夜鹭牌刚翻出来、鸟还在枝头时停下来讲一句，玩家按「看它表演」才继续结算。
## 牌没翻出来（或这盘压根没有夜鹭牌）就什么都不做，兜底交给 GuidedItemLesson.is_step_done。
func _guided_item_intro(item_queue: Array[int]) -> void:
	if not _guided_item_intro_pending() or _guided_overlay == null:
		return
	var item_index := _tutorial_night_heron_edge_index
	if item_index < 0 or not item_queue.has(item_index):
		return
	var boot := _run_boot_generation
	_guided_step = 1
	_present_guided_step()
	while (
		_guided_step == 1
		and boot == _run_boot_generation
		and not _game_finish_started
		and _guided_lesson == GuidedItemLesson
	):
		await get_tree().process_frame


func _end_guided_tutorial() -> void:
	_guided_step = -1
	_guided_lesson = null
	if _guided_overlay != null:
		_guided_overlay.dismiss()
	if _item_guide_screen != null and _item_guide_screen.is_open():
		_item_guide_screen.dismiss()


func _on_cell_mouse_button_changed(index: int, button_index: int, pressed: bool) -> void:
	if not pressed:
		return
	# 强引导期间只放行当前步骤指定的那一格、那一个键，其余点击一律拦下并提示。
	if _guided_tutorial_active() and not _guided_lesson.allows_click(_guided_step, index, button_index):
		_guided_overlay.play_nudge()
		return
	_clear_inference_highlights()
	_clear_inference_hover_preview()
	if button_index == MOUSE_BUTTON_LEFT:
		_on_cell_revealed(index)
	else:
		_on_cell_flagged(index)


func _begin_cell_inference(index: int) -> void:
	_clear_inference_highlights()
	if _resolving or _board.game_over:
		return
	var inference: Dictionary = _board.inference_at(index)
	for target in _inference_highlight_targets(index, inference):
		_inference_highlights.append(target)
		_cells[target].set_effect_preview(true, Color(1.28, 0.68, 0.56, 1.0))
	if not inference["unique"]:
		return
	var safe_cells: PackedInt32Array = inference["safe_cells"]
	if not safe_cells.is_empty():
		_resolve_inferred_safe_cells(safe_cells)
		return
	var mine_cells: PackedInt32Array = inference["potential_mines"]
	if not mine_cells.is_empty():
		_resolve_inferred_mine_cells(mine_cells)


func _inference_highlight_targets(index: int, inference: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	for target in inference["potential_mines"]:
		if not targets.has(target):
			targets.append(target)
	var constraint_cells := Array(_board.neighbors_of(index))
	constraint_cells.append(index)
	for target in constraint_cells:
		if _board.is_flagged(target) and not targets.has(target):
			targets.append(target)
		var corpse_core := _board.monster_core_at(target)
		if corpse_core >= 0 and _defeated_mines.has(corpse_core):
			_append_corpse_footprint(targets, corpse_core)
	return targets


func _append_corpse_footprint(targets: Array[int], core_index: int) -> void:
	if not targets.has(core_index):
		targets.append(core_index)
	if _board.monster_peripheral_count(core_index) == 0:
		return
	for footprint_cell in _board.neighbors_of(core_index):
		if _board.monster_core_at(footprint_cell) == core_index and not targets.has(footprint_cell):
			targets.append(footprint_cell)


func _resolve_inferred_safe_cells(safe_cells: PackedInt32Array) -> void:
	var targets: Array[int] = []
	for target in safe_cells:
		if _board.state_at(target) == MinesweeperBoard.CellState.COVERED:
			targets.append(target)
	if targets.is_empty():
		return
	_play_board_impact()
	# 推理翻开也是「点一下翻出格子」，同样 +1。挂在判空之后而不是挂在点击上——
	# 对着一格已经推完的空地连点不该白刷连击。
	_register_click_combo()
	await _resolve_reveal_targets(targets, "推理成立：安全格已全部翻开。")


func _resolve_inferred_mine_cells(mine_cells: PackedInt32Array) -> void:
	_resolving = true
	_restart_button.disabled = true
	_set_board_interactable(false)
	var marked := 0
	for target in mine_cells:
		if _board.mark_mine(target):
			marked += 1
			_refresh_cell(target)
			_play_correct_flag_feedback(target)
			_cells[target].play_border_flash(Color("ff8a67"), 3, 0.07)
			await get_tree().create_timer(0.035).timeout
	_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	_status_label.text = "推理成立：自动标记了 %d 个雷格。" % marked
	# 自动标记也算连携的标记点 B，趁锁还在手上把连线结清。
	await _flush_chain_links(false)
	if _game_finish_started:
		return
	_resolving = false
	_restart_button.disabled = false
	_set_board_interactable(true)
	_check_victory_now()


func _clear_inference_highlights() -> void:
	for index in _inference_highlights:
		if index >= 0 and index < _cells.size():
			_cells[index].set_effect_preview(false)
	_inference_highlights.clear()


func _inference_hover_targets_for(index: int) -> Array[int]:
	var targets: Array[int] = []
	if (
		index < 0
		or index >= _cells.size()
		or _board.state_at(index) != MinesweeperBoard.CellState.REVEALED
		or _board.has_mine(index)
		or _board.item_at(index) != MinesweeperBoard.ItemType.NONE
		or _board.adjacent_mines(index) <= 0
	):
		return targets
	for target in _board.neighbors_of(index):
		if (
			_board.state_at(target) != MinesweeperBoard.CellState.REVEALED
			or _board.has_mine(target)
		):
			targets.append(target)
	return targets


func _show_inference_hover_preview(index: int) -> void:
	_clear_inference_hover_preview()
	_inference_hover_targets = _inference_hover_targets_for(index)
	for target in _inference_hover_targets:
		_cells[target].set_inference_area_preview(true)


func _clear_inference_hover_preview() -> void:
	for target in _inference_hover_targets:
		if target >= 0 and target < _cells.size():
			_cells[target].set_inference_area_preview(false)
	_inference_hover_targets.clear()


func _ground_tile(index: int, flipped: bool) -> Texture2D:
	# Cycle through the six legacy face pairs in a fixed, even order. Each cell
	# keeps the same variant when it flips, without run-to-run randomness.
	var variant := index % GROUND_COVERED_TILES.size()
	return GROUND_FLIPPED_TILES[variant] if flipped else GROUND_COVERED_TILES[variant]


func _refresh_health_bar() -> void:
	if _player_status != null:
		_player_status.set_health(_player_hp, _player_max_hp)
		_player_status.set_invincible(
			# 奖励盘的免伤不倒计时，挂个「无敌 0.0s」反而像出了 bug；金盘加光环
			# 已经说明白这一段不会掉血了。
			_is_invincible() and not _bonus_board_active,
			float(_super_luck_clicks_remaining) if _super_luck_mode_active else _invincible_seconds_left(),
			_super_luck_mode_active
		)


func _is_invincible() -> bool:
	return (
		# 奖励盘是白送的：上面翻出雷只标记、不掉血，不然「奖励」会变成惩罚。
		_bonus_board_active
		or _super_luck_mode_active
		or _super_luck_settling
		or _enlarge_click_invincible
		or _pending_invincible_duration_msec > 0
		or Time.get_ticks_msec() < _invincible_until_msec
	)


func _invincible_seconds_left() -> float:
	var active_msec := maxi(_invincible_until_msec - Time.get_ticks_msec(), 0)
	return float(active_msec + _pending_invincible_duration_msec) / 1000.0


func _refresh_gold_display() -> void:
	if _player_status != null:
		_player_status.set_gold(_gold)


func _on_cell_revealed(index: int) -> void:
	if _board.game_over or _resolving:
		return
	if _board.state_at(index) == MinesweeperBoard.CellState.REVEALED:
		_begin_cell_inference(index)
		return
	if _enlarge_mark_charges > 0:
		_play_board_impact()
		_register_click_combo()
		_clear_effect_preview()
		_enlarge_mark_charges -= 1
		var consume_super_luck_click := _super_luck_mode_active
		_prepare_tutorial_first_reveal(index)
		if consume_super_luck_click:
			_fly_eg_small_over_cell(index)
		_enlarge_click_invincible = true
		_refresh_health_bar()
		# 鸟还在半空时棋盘就不能再点；翻开阶段接着用同一把锁，由 _resolve_reveal_targets 释放。
		_resolving = true
		_set_board_interactable(false)
		await _play_tit_bird_crash(index)
		_drop_tit_bird_offscreen_after(TIT_TAKEOFF_DELAY)
		await _resolve_reveal_targets(
			_area_3x3_targets(index), "长尾山雀砸开了目标周围的 3×3 区域。", true, Callable(), true
		)
		_enlarge_click_invincible = false
		_refresh_health_bar()
		if consume_super_luck_click and _super_luck_mode_active and not _game_finish_started:
			_consume_super_luck_click()
		return
	if _board.state_at(index) == MinesweeperBoard.CellState.COVERED:
		_play_board_impact()
		_register_click_combo()
		_prepare_tutorial_first_reveal(index)
		if _super_luck_mode_active:
			_board.ensure_mines_placed(index)
			if _board.has_mine(index):
				_mark_mine_in_super_luck_mode(index)
			else:
				_resolve_turn(index)
			if _check_victory_now():
				return
			_consume_super_luck_click()
		elif _is_invincible() and _is_small_monster(index):
			await _mark_small_mine_with_super_luck(index)
		else:
			_resolve_turn(index)


func _play_board_impact(
	shake_strength: float = BOARD_SHAKE_CLICK_STRENGTH,
	shake_direction: Vector2 = Vector2.ZERO,
	shake_steps: int = BOARD_SHAKE_CLICK_STEPS
) -> void:
	if _board_panel == null:
		return
	if _board_impact_tween != null and _board_impact_tween.is_valid():
		_board_impact_tween.kill()
	_board_panel.pivot_offset = _board_panel.size * 0.5
	_board_panel.scale = Vector2(0.965, 0.965)
	_board_impact_tween = create_tween()
	_board_impact_tween.tween_interval(0.045)
	_board_impact_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_board_impact_tween.tween_property(_board_panel, "scale", Vector2(1.018, 1.018), 0.075)
	_board_impact_tween.set_trans(Tween.TRANS_SINE)
	_board_impact_tween.tween_property(_board_panel, "scale", Vector2.ONE, 0.09)
	_play_board_shake(shake_strength, shake_direction, shake_steps)


func _play_board_shake(strength: float, direction: Vector2 = Vector2.ZERO, steps: int = 6) -> void:
	if _board_panel == null or strength <= 0.0 or steps <= 0:
		return
	if _board_shake_tween != null and _board_shake_tween.is_valid():
		_board_shake_tween.kill()
	var axis := direction
	if axis.length_squared() <= 0.0:
		axis = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	axis = axis.normalized()
	# Every displacement is decided up front and held for a fixed step, so the
	# shake reads the same at any frame rate. Jitter keeps repeated hits from
	# tracing an identical line; the alternating swing is what carries the punch.
	_board_shake_tween = create_tween()
	for step in range(steps):
		var decay := 1.0 - float(step) / float(steps)
		var swing := -1.0 if step % 2 == 1 else 1.0
		var jitter := Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))
		var offset := (axis + jitter).normalized() * strength * decay * swing
		_board_shake_tween.tween_callback(_apply_board_shake_offset.bind(offset))
		_board_shake_tween.tween_interval(BOARD_SHAKE_STEP_TIME)
	_board_shake_tween.tween_callback(_apply_board_shake_offset.bind(Vector2.ZERO))


func _apply_board_shake_offset(offset: Vector2) -> void:
	# Displacement is written as a delta on the anchored offsets rather than through
	# `position`, so it never mixes viewport and anchor-relative coordinates.
	# Vector2.ZERO restores the rest pose exactly.
	if _board_panel == null or _board_panel_size == Vector2.ZERO:
		return
	_board_shake_offset = offset
	# 这里独立重写四个 offset、绕过了 _set_centered_board_panel_rect()，所以分屏位移
	# 必须在这里也加一遍 —— 漏掉的话棋盘一震就会弹回屏幕正中。
	_board_panel.offset_left = -_board_panel_size.x * 0.5 + _board_center_offset.x + offset.x
	_board_panel.offset_right = _board_panel_size.x * 0.5 + _board_center_offset.x + offset.x
	_board_panel.offset_top = -_board_panel_size.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT + _board_center_offset.y + offset.y
	_board_panel.offset_bottom = _board_panel_size.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT + _board_center_offset.y + offset.y


func _cancel_board_shake() -> void:
	if _board_shake_tween != null and _board_shake_tween.is_valid():
		_board_shake_tween.kill()
	_board_shake_offset = Vector2.ZERO


func _board_recoil_direction(index: int) -> Vector2:
	# The board lurches away from whatever struck it, so the recoil points from the
	# hit cell back toward the board centre.
	if _board_panel == null or index < 0 or index >= _cells.size():
		return Vector2.ZERO
	return _board_panel.global_position + _board_panel.size * 0.5 - _cell_center(index)


func _play_hitstop(duration_seconds: float) -> void:
	if duration_seconds <= 0.0:
		return
	_hitstop_generation += 1
	var generation := _hitstop_generation
	Engine.time_scale = HITSTOP_TIME_SCALE
	# The freeze has to be measured in real time. A scaled timer would stretch by
	# the same factor it is trying to wait out and never fire on schedule.
	await get_tree().create_timer(duration_seconds, true, false, true).timeout
	# A newer hitstop already owns the clock; let that one restore the scale.
	if generation == _hitstop_generation:
		Engine.time_scale = 1.0


func _prepare_tutorial_first_reveal(index: int) -> void:
	if not _tutorial_first_reveal_pending:
		return
	_board.ensure_mines_placed(index)


func _place_tutorial_night_heron_on_reveal_edge(changed: PackedInt32Array, origin: int) -> void:
	if not _tutorial_first_reveal_pending or changed.is_empty():
		return
	var best_index := -1
	var best_covered_neighbors := -1
	var best_distance := -1
	for candidate in changed:
		if _board.has_mine(candidate):
			continue
		var covered_neighbors := 0
		for neighbor in _board.neighbors_of(candidate):
			if _board.state_at(neighbor) == MinesweeperBoard.CellState.COVERED:
				covered_neighbors += 1
		if covered_neighbors <= 0:
			continue
		var distance := absi(candidate % _board.width - origin % _board.width) + absi(candidate / _board.width - origin / _board.width)
		if covered_neighbors > best_covered_neighbors or (covered_neighbors == best_covered_neighbors and distance > best_distance):
			best_index = candidate
			best_covered_neighbors = covered_neighbors
			best_distance = distance
	if best_index < 0:
		best_index = changed[changed.size() - 1]
	if _board.force_item_at(best_index, MinesweeperBoard.ItemType.LANTERN):
		_tutorial_night_heron_edge_index = best_index
		_tutorial_first_reveal_pending = false


func _place_unlocked_woodpecker_in_first_reveal(changed: PackedInt32Array, origin: int) -> void:
	if not _woodpecker_demo_pending or changed.is_empty():
		return
	var best_index := -1
	var best_distance := -1
	for candidate in changed:
		if _board.has_mine(candidate):
			continue
		var distance := absi(candidate % _board.width - origin % _board.width) + absi(candidate / _board.width - origin / _board.width)
		if distance > best_distance:
			best_index = candidate
			best_distance = distance
	if best_index < 0:
		return
	if _board.force_item_at(best_index, MinesweeperBoard.ItemType.ORBITAL_STRIKE):
		_woodpecker_demo_index = best_index
		_woodpecker_demo_pending = false


func _place_unlocked_kestrel_in_first_reveal(changed: PackedInt32Array, origin: int) -> void:
	if not _kestrel_demo_pending or changed.is_empty():
		return
	var best_index := -1
	var best_distance := -1
	for candidate in changed:
		if _board.has_mine(candidate):
			continue
		var distance := absi(candidate % _board.width - origin % _board.width) + absi(candidate / _board.width - origin / _board.width)
		if distance > best_distance:
			best_index = candidate
			best_distance = distance
	if best_index < 0:
		return
	if _board.force_item_at(best_index, MinesweeperBoard.ItemType.SUPER_LUCK):
		_kestrel_demo_index = best_index
		_kestrel_demo_pending = false


func _place_unlocked_tit_in_first_reveal(changed: PackedInt32Array, origin: int) -> void:
	if not _tit_demo_pending or changed.is_empty():
		return
	var best_index := -1
	var best_distance := -1
	for candidate in changed:
		if _board.has_mine(candidate):
			continue
		var distance := absi(candidate % _board.width - origin % _board.width) + absi(candidate / _board.width - origin / _board.width)
		if distance > best_distance:
			best_index = candidate
			best_distance = distance
	if best_index < 0:
		return
	if _board.force_item_at(best_index, MinesweeperBoard.ItemType.ENLARGE):
		_tit_demo_index = best_index
		_tit_demo_pending = false


## 教学最后一关送完小嘴乌鸦，第一盘正式关首次翻开的区域里也必定有一张它的牌；
## 挑离起点最远、且不和长尾山雀那张挤同一格的空地。
func _place_unlocked_crow_in_first_reveal(changed: PackedInt32Array, origin: int) -> void:
	if not _crow_demo_pending or changed.is_empty():
		return
	var best_index := -1
	var best_distance := -1
	for candidate in changed:
		if _board.has_mine(candidate) or candidate == _tit_demo_index:
			continue
		if _board.item_at(candidate) != MinesweeperBoard.ItemType.NONE:
			continue
		var distance := absi(candidate % _board.width - origin % _board.width) + absi(candidate / _board.width - origin / _board.width)
		if distance > best_distance:
			best_index = candidate
			best_distance = distance
	if best_index < 0:
		return
	if _board.force_item_at(best_index, MinesweeperBoard.ItemType.XRAY):
		_crow_demo_index = best_index
		_crow_demo_pending = false


## 教学最后一关送完斑鸠，第一盘正式关首次翻开的区域里也必定有一张它的牌；
## 挑离起点最远、又不和长尾山雀、小嘴乌鸦那两张挤同一格的空地。
func _place_unlocked_dove_in_first_reveal(changed: PackedInt32Array, origin: int) -> void:
	if not _dove_demo_pending or changed.is_empty():
		return
	var best_index := -1
	var best_distance := -1
	for candidate in changed:
		if _board.has_mine(candidate) or candidate == _tit_demo_index or candidate == _crow_demo_index:
			continue
		if _board.item_at(candidate) != MinesweeperBoard.ItemType.NONE:
			continue
		var distance := absi(candidate % _board.width - origin % _board.width) + absi(candidate / _board.width - origin / _board.width)
		if distance > best_distance:
			best_index = candidate
			best_distance = distance
	if best_index < 0:
		return
	if _board.force_item_at(best_index, MinesweeperBoard.ItemType.MEDICAL_KIT):
		_dove_demo_index = best_index
		_dove_demo_pending = false


func _mark_mine_in_super_luck_mode(index: int) -> void:
	_resolving = true
	_restart_button.disabled = true
	_set_board_interactable(false)
	_fly_eg_small_over_cell(index)
	if not _board.mark_mine(index):
		_resolving = false
		_restart_button.disabled = false
		_set_board_interactable(true)
		return
	_refresh_cell(index)
	_play_correct_flag_feedback(index)
	_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	# 红隼模式里所有发现都留到次数耗尽后统一结算，连携也跟着排到那时候。
	_status_label.text = "红隼模式：发现小雷，已直接标记"
	_resolving = false
	_restart_button.disabled = false
	_set_board_interactable(true)


func _mark_small_mine_with_super_luck(index: int) -> void:
	if not _board.mark_mine(index):
		return
	_resolving = true
	_set_board_interactable(false)
	_refresh_cell(index)
	_play_correct_flag_feedback(index)
	_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	_status_label.text = "红隼发现了小雷，并将它安全标记！"
	if _check_victory_now():
		return
	var target := _nearest_active_big_monster(index)
	if target >= 0:
		await _attack_big_with_small_mines(target, [index])
	await _flush_chain_links(false)
	if _game_finish_started:
		return
	_update_round_completion()
	if _board.game_over:
		await _finish_game()
	else:
		_resolving = false
		_set_board_interactable(true)


func _on_cell_flagged(index: int) -> void:
	if _resolving or _board.game_over:
		return
	if _board.state_at(index) == MinesweeperBoard.CellState.REVEALED:
		return
	_board.ensure_mines_placed(index)
	var found_mine := _board.has_mine(index)
	if not found_mine:
		# Read the shield before the super-luck click is consumed: spending the
		# last click ends the mode, and the mark must not retroactively hurt.
		var shielded := _is_invincible()
		var marked_wrong := _reveal_wrong_player_mark(index)
		# 标错就断连击。护盾免的是血，不是这条纪律——连击奖励的是「一路没标错」，
		# 无敌状态下白标一格照样该把这串断掉。
		# `marked_wrong` 为假表示这一下什么也没发生（格子本来就翻开了），不算失误。
		if marked_wrong:
			_break_score_combo()
		if _super_luck_mode_active:
			_fly_eg_small_over_cell(index)
			_consume_super_luck_click()
		else:
			_blue_bird.play_find(false)
		if marked_wrong and shielded:
			_play_invincible_block_feedback()
		elif marked_wrong:
			# Fire-and-forget like the rest of the flag path: the hit plays out
			# without locking the board, it just costs a heart.
			await _play_wrong_flag_player_hit(index)
			if _game_finish_started:
				return
			if _player_hp <= 0:
				await _finish_game()
				return
		if not _super_luck_mode_active and not _super_luck_settling:
			_check_victory_now()
		return
	if not _board.toggle_flag(index):
		return
	_refresh_cell(index)
	_play_correct_flag_feedback(index)
	_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	var is_now_flagged := _board.state_at(index) == MinesweeperBoard.CellState.FLAGGED
	_sync_guided_tutorial()
	if is_now_flagged and found_mine:
		await _flush_chain_links()
		if _game_finish_started:
			return
	if _super_luck_mode_active:
		_fly_eg_small_over_cell(index)
		_status_label.text = "红隼模式：小鸟掠过了标记位置"
		if _check_victory_now():
			return
		_consume_super_luck_click()
	else:
		# Bird feedback is fire-and-forget. Flag state and subsequent board input
		# must never wait for the animation to finish.
		_blue_bird.play_find(found_mine)
		_status_label.text = "小蓝鸟确认：这里%s小雷" % ("有" if found_mine else "没有")
	if not _super_luck_mode_active and not _super_luck_settling:
		_check_victory_now()


## Returns true when the mark actually landed, so the caller knows whether the
## player still owes a heart for it.
func _reveal_wrong_player_mark(index: int) -> bool:
	var changed := _board.reveal_exact_forced_safe(index)
	if changed.is_empty():
		return false
	_play_wrong_flag_sfx()
	_wrong_flagged_cells[index] = true
	if _board.item_at(index) != MinesweeperBoard.ItemType.NONE:
		_board.consume_item(index)
	_refresh_cell(index, true)
	_cells[index].play_reveal()
	_spawn_reveal_debris(index)
	_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	_status_label.text = "错误标记：安全格已揭示，格内道具已毁坏。"
	return true


## A wrong mark hits the player exactly like a triggered mine does, minus the
## monster: the cell recoils, the board lurches, and the portrait takes it.
func _play_wrong_flag_player_hit(index: int) -> void:
	_cells[index].play_hit()
	await get_tree().create_timer(0.045).timeout
	CELL_FX.play_mine_explosion(_effects_layer, _cell_center(index), 0.75)
	_cells[index].play_border_flash(Color("ff5f3c"), 2, 0.07)
	await _play_hitstop(HITSTOP_MINE_SECONDS)
	_play_board_impact(
		BOARD_SHAKE_MINE_STRENGTH,
		_board_recoil_direction(index),
		BOARD_SHAKE_MINE_STEPS
	)
	_apply_player_damage(WRONG_FLAG_DAMAGE)
	_show_wrong_flag_damage_guide_once()
	_spawn_damage_number(
		_health_bar.global_position + _health_bar.size * 0.5,
		WRONG_FLAG_DAMAGE,
		Color("ff7864")
	)
	_refresh_health_bar()
	_player_status.play_hit_feedback()
	CELL_FX.play_impact_hit(_effects_layer, _player_status.hero_head_center())
	_status_label.text = "错误标记：安全格已揭示，道具毁坏，并损失 %d 点生命。" % WRONG_FLAG_DAMAGE
	await get_tree().create_timer(0.1).timeout


func _play_wrong_flag_sfx() -> void:
	if _wrong_flag_sfx == null or _wrong_flag_sfx.stream == null:
		return
	_wrong_flag_sfx.play()


## Tutorial boards keep the learner in the current lesson: a hit that would
## reduce HP to zero immediately restores one heart. This is intentionally a
## runtime rule, not a save/progression mutation, and normal levels still die.
func _apply_player_damage(amount: int) -> bool:
	if amount <= 0:
		return false
	_break_score_combo()
	_player_hp = maxi(0, _player_hp - amount)
	if _player_hp > 0 or _run_number < 1 or _run_number > TUTORIAL_LEVEL_COUNT:
		return false
	_player_hp += 1
	_show_tutorial_lifeline_feedback()
	return true


func _show_tutorial_lifeline_feedback() -> void:
	var center := _health_bar.global_position + _health_bar.size * 0.5
	_spawn_effect_ring(center, Color("9fe36f"), 16.0, 104.0, 0.32)
	var label := Label.new()
	label.text = "新手保护 +1"
	_animate_floating_label(label, center + Vector2(0, 24), Color("b8f28c"))


## 把棋盘刚记下的「新标出的雷」过一遍，留下属于连携组的那些。标雷的入口太多
## （手动右键、红尾水鸲、探测、夜鹭、啄木鸟、长尾山雀、推理……），全都汇进
## `take_marked_mine_log()`，所以这里一处就够，不用去 hook 每个调用点。
func _collect_chain_triggers() -> void:
	for index in _board.take_marked_mine_log():
		if _board.is_chain_mine(index) and not _chain_pending_triggers.has(index):
			_chain_pending_triggers.append(index)


## 连携结算：只要刚标出的雷属于连携组，同组剩下的雷就一并被灰喜鹊点出来。
## `manage_lock` 为 false 表示调用方已经持有 `_resolving` 锁并会自己收尾，这里不能
## 中途把棋盘交还给玩家。
func _flush_chain_links(manage_lock: bool = true) -> void:
	if _chain_flush_active:
		# 连锁点出来的雷会再进一次队列，交给外层这一轮循环接着处理即可。
		return
	_chain_flush_active = true
	_collect_chain_triggers()
	while not _chain_pending_triggers.is_empty():
		var trigger: int = _chain_pending_triggers.pop_front()
		# 撤旗之后这颗雷就不算标出来了，连携也不该再认它。
		if _board.state_at(trigger) != MinesweeperBoard.CellState.FLAGGED:
			continue
		var partners := _chain_link_order(trigger, _board.covered_chain_mines())
		if partners.is_empty():
			continue
		if manage_lock:
			_resolving = true
			_restart_button.disabled = true
			_set_board_interactable(false)
		await _play_chain_link(trigger, partners)
		# 连携把最后几颗雷标完就可能直接通关；那条路上由结算流程接管棋盘，
		# 这里不能再把输入交回去。
		if _game_finish_started or _board.game_over:
			_chain_flush_active = false
			return
		if manage_lock:
			_resolving = false
			_restart_button.disabled = false
			_set_board_interactable(true)
		_collect_chain_triggers()
	_chain_flush_active = false


## 灰喜鹊把同组剩下的连携雷一并点出来：**一颗雷派一只**，全部从刚标出的那一格同时出发，
## 各飞各的目标，翅膀一路扇着。点出来就是「标记」，不是引爆：
## 连携是奖励，走的和玩家自己标对一颗雷完全相同的结算路径。
func _play_chain_link(trigger: int, partners: Array[int]) -> void:
	_status_label.text = "连携雷！灰喜鹊倾巢而出，把同一组的另外 %d 颗雷一并标出。" % partners.size()
	_cells[trigger].play_border_flash(Color("74f3ff"), 5, 0.08)
	_play_target_lock(trigger, partners, Color("74f3ff"), 1.0)
	_magpie_bird.play_action_sfx()
	var start := _cell_center(trigger)
	var flyers: Array[TextureRect] = []
	var flights: Array[Tween] = []
	for index in range(partners.size()):
		var flyer := _spawn_chain_magpie(start)
		flyers.append(flyer)
		flights.append(_fly_chain_magpie(flyer, start, _cell_center(partners[index]), index * MAGPIE_LINK_STAGGER))
	var marked: PackedInt32Array = PackedInt32Array()
	for index in range(partners.size()):
		if flights[index].is_valid():
			await flights[index].finished
		_land_chain_magpie(flyers[index])
		var target: int = partners[index]
		if not _board.mark_mine(target):
			continue
		marked.append(target)
		_refresh_cell(target)
		_play_correct_flag_feedback(target)
		_cells[target].play_border_flash(Color("74f3ff"), 3, 0.07)
		_spawn_effect_ring(_cell_center(target), Color("74f3ff"), 14.0, 78.0, 0.26)
		_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	if _check_victory_now():
		return
	# 刚标出来的小雷照样扑向场上的大怪，和其他标雷入口的结算一致。
	await _attack_newly_flagged_smalls(marked)


## 连线顺序：从触发格出发，每次跳到还没点的雷里最近的那一颗，避免来回折返。
func _chain_link_order(trigger: int, partners: PackedInt32Array) -> Array[int]:
	var remaining: Array[int] = []
	for index in partners:
		remaining.append(index)
	var ordered: Array[int] = []
	var here := trigger
	while not remaining.is_empty():
		var best := 0
		var best_distance := 1_000_000
		for slot in range(remaining.size()):
			var distance := _cell_manhattan(here, remaining[slot])
			if distance < best_distance:
				best_distance = distance
				best = slot
		here = remaining[best]
		ordered.append(here)
		remaining.remove_at(best)
	return ordered


func _cell_manhattan(first: int, second: int) -> int:
	return (
		absi(first / _board.width - second / _board.width)
		+ absi(first % _board.width - second % _board.width)
	)


func _area_3x3_targets(center: int) -> Array[int]:
	var targets: Array[int] = [center]
	for neighbor in _board.neighbors_of(center):
		targets.append(neighbor)
	targets.sort()
	return targets


## `manage_lock` 为 false 时说明调用方已经握着 `_resolving` 锁并会自己收尾，这里就
## 不许中途把棋盘交还给玩家——否则嵌套结算会在上层还没跑完时放开输入。
## `walker` 给了的话，每个目标格翻开前先 `await walker.call(target)`——灰喜鹊就是这样
## 一格一格走过去、走到哪格翻哪格；不给就整批一起翻。
## `flag_mines` 为 true 时区域里的雷不引爆、直接标出来（长尾山雀），和啄木鸟的清线一个规矩。
func _resolve_reveal_targets(
	targets: Array[int], completion_text: String, manage_lock: bool = true, walker: Callable = Callable(),
	flag_mines: bool = false
) -> void:
	if manage_lock:
		_resolving = true
		_restart_button.disabled = true
		_set_board_interactable(false)
	var changed := PackedInt32Array()
	var flagged := PackedInt32Array()
	var item_queue: Array[int] = []
	var queued_items: Dictionary = {}
	var reveal_animation_duration := 0.0
	for target in targets:
		if walker.is_valid():
			await walker.call(target)
		if _board.state_at(target) == MinesweeperBoard.CellState.REVEALED:
			continue
		if (_super_luck_mode_active or flag_mines) and _board.is_monster_core(target):
			if _board.mark_mine(target):
				flagged.append(target)
			continue
		var target_changed := (
			_board.reveal(target)
			if _board.is_monster_core(target)
			else _board.reveal_exact_forced_safe(target)
		)
		var fresh := PackedInt32Array()
		for changed_index in target_changed:
			if not changed.has(changed_index):
				changed.append(changed_index)
				fresh.append(changed_index)
		if walker.is_valid() and not fresh.is_empty():
			reveal_animation_duration = _present_revealed(fresh, item_queue, queued_items)
	if not walker.is_valid():
		reveal_animation_duration = _present_revealed(changed, item_queue, queued_items)
	if _super_luck_mode_active:
		_defer_super_luck_reveals(changed)
		for flagged_index in flagged:
			_refresh_cell(flagged_index)
			_play_correct_flag_feedback(flagged_index)
		_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
		if _check_victory_now():
			return
		_status_label.text = "超级幸运模式：区域内的雷已标记，发现的道具将在模式结束后结算。"
		if manage_lock:
			_resolving = false
			_restart_button.disabled = false
			_set_board_interactable(true)
		return
	# 标出来的雷先亮旗再往下走：剩余雷读数和胜利判定都要看这一批。
	for flagged_index in flagged:
		_refresh_cell(flagged_index)
		_play_correct_flag_feedback(flagged_index)
		_spawn_effect_ring(_cell_center(flagged_index), Color("ffcf63"), 12.0, 62.0, 0.2)
	if not flagged.is_empty():
		_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	if reveal_animation_duration > 0.0:
		await get_tree().create_timer(reveal_animation_duration).timeout
	if not _has_unresolved_revealed_mine(changed) and _check_victory_now():
		return
	var revealed_big_monsters := await _register_revealed_combat_objects(changed)
	for big_index in revealed_big_monsters:
		await _attack_big_with_small_mines(big_index, _flagged_small_monsters())
	# 刚标出来的小雷照样扑向场上的大怪，和啄木鸟清线后的结算一致。
	await _attack_newly_flagged_smalls(flagged)
	await _resolve_item_queue(item_queue, queued_items)
	if _check_victory_now():
		return
	if _player_hp <= 0:
		await _finish_game()
		return
	# 这一批里可能既翻出了新的连携道具，也顺手标出了雷（红尾水鸲、探测……），
	# 在放开输入之前把凑成对的连携结清。
	await _flush_chain_links(false)
	if _game_finish_started:
		return
	_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	_status_label.text = (
		"%s 踩到的 %d 个雷已直接标出。" % [completion_text, flagged.size()]
		if not flagged.is_empty()
		else completion_text
	)
	if manage_lock:
		_resolving = false
		_restart_button.disabled = false
		_set_board_interactable(true)
		_sync_guided_tutorial()


func _on_cell_hover_started(index: int) -> void:
	_hovered_cell_index = index
	_clear_effect_preview()
	if (
		_super_luck_mode_active
		and _board.state_at(index) == MinesweeperBoard.CellState.COVERED
	):
		_super_luck_hover_index = index
		_cells[index].set_super_luck_pending(true)
	if _enlarge_mark_charges > 0:
		_clear_inference_hover_preview()
		_start_enlarge_hover_preview(index)
		return
	_show_inference_hover_preview(index)
	if (
		_board.state_at(index) != MinesweeperBoard.CellState.REVEALED
		or _board.is_item_used(index)
	):
		return
	_show_item_tooltip(_board.item_at(index))
	match _board.item_at(index):
		MinesweeperBoard.ItemType.LANTERN:
			_previewed_cells.assign(Array(_board.neighbors_of(index)))
			_previewed_cells.append(index)
			for target in _previewed_cells:
				_cells[target].set_effect_preview(true, Color(1.18, 1.10, 0.68, 1.0))
		MinesweeperBoard.ItemType.COMPASS:
			for target in range(_cells.size()):
				if not _board.is_active(target):
					continue
				if _board.state_at(target) == MinesweeperBoard.CellState.COVERED:
					_previewed_cells.append(target)
					_cells[target].set_effect_preview(true, Color(0.76, 1.12, 1.12, 1.0))
		MinesweeperBoard.ItemType.ORBITAL_STRIKE:
			var row: int = index / _board.width
			for column in range(_board.width):
				var target := row * _board.width + column
				if not _board.is_active(target):
					continue
				_previewed_cells.append(target)
				_cells[target].set_effect_preview(true, Color(1.18, 0.82, 0.62, 1.0))
		MinesweeperBoard.ItemType.SUPER_LUCK:
			_previewed_cells.append(index)
			_cells[index].set_effect_preview(true, Color(1.2, 1.12, 0.58, 1.0))
		MinesweeperBoard.ItemType.MEDICAL_KIT:
			_previewed_cells.append(index)
			_cells[index].set_effect_preview(true, Color(0.72, 1.18, 0.76, 1.0))
		MinesweeperBoard.ItemType.XRAY, MinesweeperBoard.ItemType.ENLARGE, MinesweeperBoard.ItemType.DETECT:
			_previewed_cells.append(index)
			_cells[index].set_effect_preview(true, _item_effect_color(_board.item_at(index)))


func _on_cell_hover_ended(index: int) -> void:
	if _hovered_cell_index == index:
		_hovered_cell_index = -1
	_clear_effect_preview()
	_clear_inference_hover_preview()
	_clear_inference_highlights()
	if _super_luck_hover_index == index:
		_super_luck_hover_index = -1
		if not _super_luck_deferred_lookup.has(index):
			_cells[index].set_super_luck_pending(false)
	_item_tooltip.visible = false


func _clear_effect_preview() -> void:
	_enlarge_hover_generation += 1
	for index in _previewed_cells:
		if index >= 0 and index < _cells.size():
			_cells[index].set_effect_preview(false)
	_previewed_cells.clear()


func _start_enlarge_hover_preview(index: int) -> void:
	if _enlarge_mark_charges <= 0 or index < 0 or index >= _cells.size():
		return
	_enlarge_hover_generation += 1
	var generation := _enlarge_hover_generation
	var targets := _area_3x3_targets(index)
	_previewed_cells.assign(targets)
	for target in targets:
		_cells[target].set_effect_preview(true, Color("d69bff"))
	_pulse_enlarge_hover_preview(generation, targets)


func _pulse_enlarge_hover_preview(generation: int, targets: Array[int]) -> void:
	while generation == _enlarge_hover_generation and _enlarge_mark_charges > 0:
		for target in targets:
			if target >= 0 and target < _cells.size():
				_cells[target].play_border_flash(Color("d69bff"), 2, 0.1)
		await get_tree().create_timer(0.42).timeout


func _show_item_tooltip(item: MinesweeperBoard.ItemType) -> void:
	match item:
		MinesweeperBoard.ItemType.LANTERN:
			_item_tooltip_title.text = "夜鹭 · 翻出后自动使用"
			_item_tooltip_body.text = "翻开后随机在周围翻开%d个格子（必没有雷）" % (1 + _lantern_target_bonus)
		MinesweeperBoard.ItemType.COMPASS:
			_item_tooltip_title.text = "红尾水鸲 · 翻出后自动使用"
			_item_tooltip_body.text = "自动标出%d个雷" % (1 + _compass_mark_bonus)
		MinesweeperBoard.ItemType.ORBITAL_STRIKE:
			_item_tooltip_title.text = "啄木鸟 · 翻出后自动使用"
			_item_tooltip_body.text = (
				"十字清理所在的整行和整列：翻开安全格，并标记尚未揭示的怪物。"
				if _orbital_cross_unlocked
				else "清横线上的格子/清竖线上的格子"
			)
		MinesweeperBoard.ItemType.SUPER_LUCK:
			_item_tooltip_title.text = "红隼 · 翻出后自动使用"
			_item_tooltip_body.text = "%d步内无敌，踩中雷不掉血" % (SUPER_LUCK_CLICKS_PER_ITEM + _super_luck_click_bonus)
		MinesweeperBoard.ItemType.MEDICAL_KIT:
			_item_tooltip_title.text = "斑鸠 · 翻出后自动使用"
			_item_tooltip_body.text = "斑鸠衔一枝飞到血条边，补回 %d 颗爱心，但不会超过生命上限。" % (1 + _healing_power_bonus)
		MinesweeperBoard.ItemType.XRAY:
			_item_tooltip_title.text = "小嘴乌鸦 · 翻出后自动使用"
			_item_tooltip_body.text = "小嘴乌鸦飞去随机一格掀开偷看：那一格的内容亮 3 秒，但不会被翻开"
		MinesweeperBoard.ItemType.ENLARGE:
			_item_tooltip_title.text = "长尾山雀 · 翻出后自动使用"
			_item_tooltip_body.text = "下一步无敌：长尾山雀会摔到你选中的格子上，把周围 3×3 一起砸开，踩到的雷直接标出来"
		MinesweeperBoard.ItemType.DETECT:
			_item_tooltip_title.text = "探测 · 翻出后自动使用"
			_item_tooltip_body.text = "自动找出并标记一个尚未处理的雷。"
		_:
			_item_tooltip.visible = false
			return
	_item_tooltip.reset_size()
	_item_tooltip.visible = true


func _refresh_cell(index: int, animate_reveal: bool = false) -> void:
	# 道具结算是跨 await 的协程：上一盘还没结算完就换了盘（关卡包的下一张图、或者
	# 玩家手快点穿了账单和商店），迟到的那一笔会拿着旧盘的格号进来。新盘更小就越界。
	# 这里当成空操作挡掉——要刷的那个格子已经不存在了，本来也没什么可刷的。
	if _board == null or index < 0 or index >= _cells.size():
		return
	var state := _board.state_at(index)
	var is_flipped := (
		state == MinesweeperBoard.CellState.REVEALED
		or state == MinesweeperBoard.CellState.FLAGGED
	)
	var next_ground := _ground_tile(index, is_flipped)
	if animate_reveal:
		_cells[index].prepare_reveal_face(next_ground)
	else:
		_cells[index].set_ground_texture(next_ground)
	match state:
		MinesweeperBoard.CellState.COVERED:
			_cells[index].display_covered()
		MinesweeperBoard.CellState.FLAGGED:
			# 正确标记：雷图 + 底板绿勾，和已触发雷的红叉底板同一套读法。
			var marked_span := 3 if _board.monster_peripheral_count(index) == 8 else 1
			_cells[index].display_revealed(
				_monster_texture(index),
				MineCell.ContentKind.TRIGGERED,
				false,
				marked_span,
				0,
				CORRECT_MARK_TEXTURE
			)
		MinesweeperBoard.CellState.REVEALED:
			var fault_plate: Texture2D = null
			var content: Texture2D
			var kind := MineCell.ContentKind.EMPTY
			var number_value := 0
			if _wrong_flagged_cells.has(index):
				# 误标：数字 + 底板红叉（道具已毁，不再显示道具图）。
				fault_plate = TRIGGERED_MINE_TEXTURE
				number_value = _board.adjacent_mines(index)
				if number_value > 0:
					kind = MineCell.ContentKind.NUMBER
				_cells[index].display_revealed(
					null, kind, animate_reveal, 1, number_value, fault_plate
				)
				return
			if _board.is_monster_core(index) and _defeated_mines.has(index):
				# 已触发雷：雷图 + 底板红叉。
				content = _monster_texture(index)
				kind = MineCell.ContentKind.TRIGGERED
				fault_plate = TRIGGERED_MINE_TEXTURE
			elif _board.is_monster_core(index):
				content = _monster_texture(index)
				kind = MineCell.ContentKind.MONSTER
			elif (
				_board.item_at(index) != MinesweeperBoard.ItemType.NONE
				and not _board.is_item_used(index)
			):
				content = _item_texture(_board.item_at(index))
				kind = MineCell.ContentKind.ITEM
			else:
				# 普通数字格，或道具已触发后变回数字。
				number_value = _board.adjacent_mines(index)
				if number_value > 0:
					kind = MineCell.ContentKind.NUMBER
			var is_monster_visual := (
				kind == MineCell.ContentKind.MONSTER or kind == MineCell.ContentKind.TRIGGERED
			)
			var content_span := 3 if is_monster_visual and _board.monster_peripheral_count(index) == 8 else 1
			_cells[index].display_revealed(
				content, kind, animate_reveal, content_span, number_value, fault_plate
			)
			if _active_mines.has(index):
				var mine_data: Dictionary = _active_mines[index]
				_cells[index].set_combat_mine_status(mine_data["hp"], BIG_MONSTER_MAX_HP, mine_data["turns"])


func _resolve_turn(index: int) -> void:
	_resolving = true
	_restart_button.disabled = true
	_set_board_interactable(false)
	_started = true
	if _super_luck_mode_active:
		_fly_eg_small_over_cell(index)
	var item_queue: Array[int] = []
	var queued_items: Dictionary = {}
	var changed: PackedInt32Array = _board.reveal(index)
	_place_tutorial_night_heron_on_reveal_edge(changed, index)
	_place_unlocked_woodpecker_in_first_reveal(changed, index)
	_place_unlocked_kestrel_in_first_reveal(changed, index)
	_place_unlocked_tit_in_first_reveal(changed, index)
	_place_unlocked_crow_in_first_reveal(changed, index)
	_place_unlocked_dove_in_first_reveal(changed, index)
	var reveal_animation_duration := _present_revealed(changed, item_queue, queued_items, index)
	if _super_luck_mode_active:
		_defer_super_luck_reveals(changed)
		_status_label.text = "红隼模式：发现内容已暂存"
		_resolving = false
		_restart_button.disabled = false
		_set_board_interactable(true)
		return
	# Clearing the board with the last mine still has to cost the player a heart:
	# settling the win here would end the run before the hit resolves.
	if not _has_unresolved_revealed_mine(changed) and _check_victory_now():
		return
	if not changed.is_empty():
		await get_tree().create_timer(reveal_animation_duration).timeout
	# 第 2 盘：夜鹭牌刚翻出来，先圈住它讲一句，玩家点了「看它表演」再往下结算。
	var board_before_intro := _board
	await _guided_item_intro(item_queue)
	if _board != board_before_intro or _game_finish_started:
		return

	var revealed_big_monsters := await _register_revealed_combat_objects(changed)
	if _check_victory_now():
		return
	for big_index in revealed_big_monsters:
		await _attack_big_with_small_mines(big_index, _flagged_small_monsters())
	await _resolve_item_queue(item_queue, queued_items)
	if _game_finish_started:
		return
	# 这一手可能刚翻出连携，也可能被道具顺手标出了雷，趁锁还在手上把连线结清。
	await _flush_chain_links(false)
	if _game_finish_started:
		return
	_update_round_completion()
	if _player_hp <= 0 or _board.game_over:
		await _finish_game()
		return

	var player_defeated := await _advance_combat_turn()
	if player_defeated:
		await _finish_game()
		return

	_status_label.text = "继续排查，别踩到它们。"
	_resolving = false
	_restart_button.disabled = false
	_set_board_interactable(true)
	_sync_guided_tutorial()


func _present_revealed(changed: PackedInt32Array, item_queue: Array[int], queued_items: Dictionary, reveal_origin: int = -1) -> float:
	var effect_stride := maxi(1, ceili(changed.size() / 18.0))
	var effect_index := 0
	var maximum_delay := 0.0
	_last_reveal_wave_delays.clear()
	var wave_center := Vector2.ZERO
	if reveal_origin >= 0:
		wave_center = Vector2(reveal_origin % _board.width, reveal_origin / _board.width)
	elif not changed.is_empty():
		for changed_index in changed:
			wave_center += Vector2(changed_index % _board.width, changed_index / _board.width)
		wave_center /= float(changed.size())
	for changed_index in changed:
		_refresh_cell(changed_index, true)
		var cell_position := Vector2(changed_index % _board.width, changed_index / _board.width)
		var wave_distance := maxi(
			ceili(absf(cell_position.x - wave_center.x)),
			ceili(absf(cell_position.y - wave_center.y))
		)
		var reveal_delay := float(wave_distance) * 0.135 if changed.size() > 1 else 0.0
		maximum_delay = maxf(maximum_delay, reveal_delay)
		_last_reveal_wave_delays[changed_index] = reveal_delay
		_play_card_reveal_sfx(reveal_delay)
		if _board.is_monster_core(changed_index) and _board.monster_peripheral_count(changed_index) == 8:
			_cells[changed_index].prepare_monster_emerge()
		else:
			_cells[changed_index].play_reveal(reveal_delay)
		if _board.is_monster_core(changed_index) and not _defeated_mines.has(changed_index):
			_telegraph_mine_reveal(changed_index, reveal_delay)
		if effect_index % effect_stride == 0:
			_spawn_reveal_debris(changed_index)
		effect_index += 1
	var ordered := Array(changed)
	ordered.sort()
	for changed_index in ordered:
		if (
			_board.item_at(changed_index) != MinesweeperBoard.ItemType.NONE
			and not _board.is_item_used(changed_index)
			and not queued_items.has(changed_index)
		):
			queued_items[changed_index] = true
			item_queue.append(changed_index)
			# 第 2 盘的夜鹭牌要先停下来讲，鸟不能这时就起飞；走不预飞的那条结算路。
			if not (_guided_item_intro_pending() and changed_index == _tutorial_night_heron_edge_index):
				_prelaunch_queued_bird(changed_index, _board.item_at(changed_index))
	return maximum_delay + 0.65 if not changed.is_empty() else 0.0


func _play_card_reveal_sfx(delay: float = 0.0) -> void:
	if _card_reveal_sfx == null or _card_reveal_sfx.stream == null:
		return
	_play_card_reveal_sfx_delayed(delay)


func _play_card_reveal_sfx_delayed(delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_instance_valid(_card_reveal_sfx):
		return
	# Each card gets its own short-lived voice. This preserves every reveal in a
	# radial flood instead of restarting a single shared AudioStreamPlayer.
	var voice := AudioStreamPlayer.new()
	voice.stream = _card_reveal_sfx.stream
	voice.volume_db = _card_reveal_sfx.volume_db
	voice.bus = _card_reveal_sfx.bus
	add_child(voice)
	voice.play()
	await get_tree().create_timer(maxf(voice.stream.get_length(), 0.1) + 0.05).timeout
	if is_instance_valid(voice):
		voice.queue_free()


func _register_revealed_combat_objects(changed: PackedInt32Array) -> Array[int]:
	var revealed_big_monsters: Array[int] = []
	for index in changed:
		if not _board.is_monster_core(index) or _defeated_mines.has(index):
			continue
		if _is_small_monster(index):
			await _play_small_mine_player_hit(index)
			if _is_invincible():
				_play_invincible_block_feedback()
			else:
				_apply_player_damage(MINE_DAMAGE)
				_spawn_damage_number(_health_bar.global_position + _health_bar.size * 0.5, MINE_DAMAGE, Color("ff7864"))
			_defeated_mines[index] = true
			_board.resolve_monster_core(index)
			_refresh_cell(index)
			_refresh_health_bar()
		else:
			if not _active_mines.has(index):
				_active_mines[index] = {"hp": BIG_MONSTER_MAX_HP, "turns": MINE_ATTACK_DELAY + 1}
				revealed_big_monsters.append(index)
				await _play_big_monster_reveal(index)
			_refresh_cell(index)
	_refresh_health_bar()
	return revealed_big_monsters


# --- 奖励盘 ---


## 这一盘算不算赢。奖励盘上没有「打完」这回事——真正的胜负在它展开之前就定了，
## 所以只要这一盘开过奖励盘，就一路按赢处理。
func _round_is_won() -> bool:
	return _bonus_boards_this_round > 0 or (_board != null and _board.won)


## 该不该展开奖励盘：本盘的雷已经用尽，而还有牌要落。调用方自己就是那张待落的牌
## （或是队列里还压着牌），所以这里只看盘面与闸门。
## 对战与自定义包排除在外：它们各有自己的换盘/同步节奏，再插一张盘只会把两套流程
## 搅在一起。教学盘也不进——那几盘的每一步都是写死的。
func _should_open_bonus_board() -> bool:
	return (
		_board != null
		and _board.won
		and not _game_finish_started
		and not _is_duel()
		and not _is_custom()
		and _guided_lesson == null
		and _run_number > TUTORIAL_LEVEL_COUNT
		and _bonus_boards_this_round < BONUS_BOARD_LIMIT
	)


## 换盘请求。可能有好几张牌同时走到这一步，用一个「正在换」的闸把它们并成一次换盘：
## 先到的那张负责换，其余的等换好再继续，于是大家都落在同一张奖励盘上。
func _request_bonus_board(item_queue: Array[int], queued_items: Dictionary) -> void:
	_bonus_board_waiters += 1
	if _bonus_board_opening:
		while _bonus_board_opening and not _game_finish_started:
			await get_tree().process_frame
		_bonus_board_waiters -= 1
		return
	_bonus_board_opening = true
	await _open_bonus_board(item_queue, queued_items)
	_bonus_board_opening = false
	_bonus_board_waiters -= 1


## 展开一张奖励盘：同尺寸、同雷数、不发新牌，只把队列里剩下的那几张原样种回去。
func _open_bonus_board(item_queue: Array[int], queued_items: Dictionary) -> void:
	# 还在跑效果的牌踩着旧盘的格号，等它们落地再换。**等在这道闸前面的不算**
	# （含调用者自己）——它们停在生效之前，碰不到盘；不减掉就会互相等成死锁。
	while _active_item_settlements - _bonus_board_waiters > 0 and not _game_finish_started:
		await get_tree().create_timer(0.04).timeout
	if _game_finish_started or _board == null or not _board.won:
		return
	var previous := _board
	_banked_flagged_mines = _correctly_flagged_mines()
	_banked_scored_mines += _combo_scored_cells.size()
	_bonus_boards_this_round += 1
	_bonus_board_active = true
	_board = BoardModel.new(
		previous.width,
		previous.height,
		previous.mine_count,
		_bonus_board_seed(),
		0, 0, 0, 0, 0, 0, 0, 0, 0,
		_mask_of_board(previous)
	)
	# 牌一落下就要有雷可标，所以立刻布雷，不等谁去点第一下。
	_board.ensure_mines_placed(_board_center_index())
	# 旧盘的临时账目跟着旧盘翻篇（要留的那两笔上面已经存过了）。
	_active_mines.clear()
	_defeated_mines.clear()
	_wrong_flagged_cells.clear()
	_chain_pending_triggers.clear()
	_combo_scored_cells.clear()
	_last_target_lock_indices.clear()
	_replant_queued_cards(previous, item_queue, queued_items)
	for index in range(_cells.size()):
		_refresh_cell(index)
	_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	_status_label.text = "雷全清光了——奖励盘展开，剩下的伙伴接着上！"
	_status_label.add_theme_color_override("font_color", COLOR_ACCENT)
	await _play_bonus_board_intro()


## 队列里存的是旧盘的格号，而奖励盘上并没有这些牌。把它们照原样种回同一格并翻开，
## 后面的结算流程就能一行不改地跑下去；原格被雷占了就就近挪一格，队列同步改写。
func _replant_queued_cards(
	previous: MinesweeperBoard, item_queue: Array[int], queued_items: Dictionary
) -> void:
	var taken := {}
	for position in range(item_queue.size()):
		var origin: int = item_queue[position]
		var kind: MinesweeperBoard.ItemType = previous.item_at(origin)
		if kind == MinesweeperBoard.ItemType.NONE:
			continue
		var slot := _bonus_card_slot(origin, taken)
		if slot < 0:
			continue
		taken[slot] = true
		item_queue[position] = slot
		queued_items.erase(origin)
		queued_items[slot] = true
		# 预飞账本按格号记：不跟着挪，这张牌结算完就找不到自己那只鸟，鸟再也回不了
		# 枝头（`_complete_prelaunched_bird()` 查的就是这张表）。
		if slot != origin and _prelaunched_item_indices.has(origin):
			_prelaunched_item_indices.erase(origin)
			_prelaunched_item_indices[slot] = true
		_board.reveal_exact_forced_safe(slot)
		# preserve_count = false：这几张是同时在场的，默认那套「同类只留一张」会互相顶掉。
		_board.force_item_at(slot, kind, false)


## 奖励盘上放牌的格子：优先用原来那一格，被雷占了或已被别的牌占了就由近及远另找。
func _bonus_card_slot(preferred: int, taken: Dictionary) -> int:
	if _bonus_slot_free(preferred, taken):
		return preferred
	var total := _board.width * _board.height
	for offset in range(1, total):
		for candidate in [preferred - offset, preferred + offset]:
			if _bonus_slot_free(candidate, taken):
				return candidate
	return -1


func _bonus_slot_free(index: int, taken: Dictionary) -> bool:
	return (
		index >= 0
		and index < _board.width * _board.height
		and _board.is_active(index)
		and not _board.is_monster_core(index)
		and not taken.has(index)
	)


## 奖励盘的雷位种子：跟着本盘种子和这是第几张奖励盘走，所以同一局可复现。
func _bonus_board_seed() -> int:
	var mixed := _level_seed_for_current_round() ^ (0x5F3A7B1 * (_bonus_boards_this_round + 1))
	return mixed if mixed != 0 else 1


func _board_center_index() -> int:
	return int(_board.height / 2) * _board.width + int(_board.width / 2)


## 照抄一块盘的可玩格掩码（异形盘的奖励盘要长得一模一样）。
func _mask_of_board(board: MinesweeperBoard) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(board.width * board.height)
	for index in range(mask.size()):
		mask[index] = 1 if board.is_active(index) else 0
	return mask


## 奖励盘的开场：整盘压成暖金、光环与标题亮起来，然后把牌一张张发下去。
func _play_bonus_board_intro() -> void:
	_prepare_board_deal()
	if _grid != null:
		create_tween().tween_property(_grid, "modulate", BONUS_BOARD_TINT, BONUS_BOARD_TINT_TIME)
	_build_bonus_aura()
	if _bonus_aura != null and _grid != null:
		_bonus_aura.present(Rect2(_grid.global_position, _grid.size))
	await get_tree().create_timer(BONUS_BOARD_INTRO_HOLD).timeout
	if _game_finish_started:
		return
	await _play_board_deal_shuffle()


## 光环懒建，和别的演出层一样挂在 `_effects_layer` 上（不吃鼠标、压在棋盘之上）。
func _build_bonus_aura() -> void:
	if _bonus_aura != null or _effects_layer == null:
		return
	_bonus_aura = BonusBoardAura.new()
	_effects_layer.add_child(_bonus_aura)


## 收走奖励盘的演出。盘面本身留着——`_finish_game()` 会照常把它摊开结算。
func _close_bonus_board(immediate: bool = false) -> void:
	_bonus_board_active = false
	if _grid != null:
		_grid.modulate = Color.WHITE
	if _bonus_aura != null:
		_bonus_aura.dismiss(immediate)


func _resolve_item_queue(item_queue: Array[int], queued_items: Dictionary) -> void:
	_item_queue_dispatching = true
	var deferred_super_luck: Array[int] = []
	# Start a new event at a fixed short cadence. Each coroutine completes in
	# the background, so a long flyover never prevents the next bird/effect
	# from entering the scene. Chained reveals may append more work here.
	while not item_queue.is_empty() or _active_item_settlements > 0:
		# 队列里还压着牌、盘面却已经没雷了：先换盘再往下发，省得白发一张。
		# 真正兜底的是 `_resolve_queued_item()` 里那一道——牌离队后才生效，那时才准。
		if not item_queue.is_empty() and _should_open_bonus_board():
			await _request_bonus_board(item_queue, queued_items)
			if _game_finish_started:
				_item_queue_dispatching = false
				return
		if not item_queue.is_empty():
			var item_index: int = item_queue.pop_front()
			if _board.is_item_used(item_index):
				_complete_prelaunched_bird(item_index, _board.item_at(item_index))
				continue
			var item: MinesweeperBoard.ItemType = _board.item_at(item_index)
			if item == MinesweeperBoard.ItemType.SUPER_LUCK:
				deferred_super_luck.append(item_index)
				continue
			_active_item_settlements += 1
			_last_item_settlement_dispatch_frames.append(Engine.get_process_frames())
			_run_queued_item_nonblocking(item_index, item, item_queue, queued_items)
			await get_tree().create_timer(ITEM_SETTLEMENT_LAUNCH_INTERVAL).timeout
			await get_tree().process_frame
		else:
			await get_tree().create_timer(0.04).timeout
		if _game_finish_started:
			_item_queue_dispatching = false
			return

	# Super luck is a mode transition, so it starts only after every regular
	# item, including regular items found by chained effects, has settled.
	if not _game_finish_started:
		await _resolve_merged_super_luck(deferred_super_luck)
	if _pending_invincible_duration_msec > 0:
		_invincible_until_msec = maxi(_invincible_until_msec, Time.get_ticks_msec()) + _pending_invincible_duration_msec
		_pending_invincible_duration_msec = 0
		_refresh_health_bar()
	_item_queue_dispatching = false
	if _bonus_board_active and not _game_finish_started:
		# 奖励盘上永远凑不齐「雷全标完」，`_check_victory_now()` 收不了场。胜负在它
		# 展开之前就定了（那时本盘已经赢），所以这里直接收。
		_finish_game()
		return
	_check_victory_now()


func _run_queued_item_nonblocking(
	item_index: int,
	item: MinesweeperBoard.ItemType,
	item_queue: Array[int],
	queued_items: Dictionary
) -> void:
	await _resolve_queued_item(item_index, item, item_queue, queued_items)
	_complete_prelaunched_bird(item_index, item)
	_active_item_settlements = maxi(0, _active_item_settlements - 1)


func _prelaunch_queued_bird(item_index: int, item: MinesweeperBoard.ItemType) -> void:
	var bird := _bird_for_item(item)
	if bird == null:
		return
	_prelaunched_item_indices[item_index] = true
	var count := int(_queued_bird_event_counts.get(item, 0)) + 1
	_queued_bird_event_counts[item] = count
	if count > 1:
		return
	_pending_bird_departures.append(item)
	if not _bird_departure_dispatch_running:
		_bird_departure_dispatch_running = true
		var generation := _bird_departure_generation
		_dispatch_bird_departure_queue.call_deferred(generation)


func _dispatch_bird_departure_queue(generation: int) -> void:
	# Gather everything discovered in the current reveal frame, then launch the
	# perched actors in a quick queue. The first starts on the next frame; later
	# birds are staggered without waiting for an earlier flight to finish.
	while generation == _bird_departure_generation and not _pending_bird_departures.is_empty():
		var item: MinesweeperBoard.ItemType = _pending_bird_departures.pop_front()
		var bird := _bird_for_item(item)
		if bird != null:
			_last_bird_departure_dispatch_times.append(Time.get_ticks_msec())
			_last_bird_departure_dispatch_frames.append(Engine.get_process_frames())
			var direction := Vector2.DOWN if item == MinesweeperBoard.ItemType.LANTERN else Vector2.RIGHT
			bird.depart_for_queued_action(direction)
		if not _pending_bird_departures.is_empty():
			await get_tree().create_timer(BIRD_DEPARTURE_QUEUE_INTERVAL).timeout
			# A long frame can expire several short timers together. Crossing an
			# explicit process frame guarantees distinct visual trigger moments.
			await get_tree().process_frame
	if generation == _bird_departure_generation:
		_bird_departure_dispatch_running = false


func _complete_prelaunched_bird(item_index: int, item: MinesweeperBoard.ItemType) -> void:
	if not _prelaunched_item_indices.has(item_index):
		return
	_prelaunched_item_indices.erase(item_index)
	var remaining := maxi(0, int(_queued_bird_event_counts.get(item, 1)) - 1)
	_queued_bird_event_counts[item] = remaining
	if remaining == 0:
		var bird := _bird_for_item(item)
		if bird != null:
			bird.reset_to_idle()


func _bird_for_item(item: MinesweeperBoard.ItemType) -> BirdPerch:
	match item:
		MinesweeperBoard.ItemType.LANTERN:
			return _black_bird
		MinesweeperBoard.ItemType.COMPASS:
			return _red_bird
		MinesweeperBoard.ItemType.ORBITAL_STRIKE:
			return _attacker_bird
		MinesweeperBoard.ItemType.SUPER_LUCK:
			return _eg_bird
	return null


func _resolve_merged_super_luck(item_indices: Array[int]) -> void:
	var pending: Array[int] = []
	for item_index in item_indices:
		if not _board.is_item_used(item_index):
			pending.append(item_index)
	if pending.is_empty():
		return
	_status_label.text = "发现 %d 只红隼，正在合并结算……" % pending.size()
	var focus_color := _item_effect_color(MinesweeperBoard.ItemType.SUPER_LUCK)
	for item_index in pending:
		_cells[item_index].play_item_focus(focus_color)
		_spawn_effect_ring(_cell_center(item_index), focus_color, 18.0, 68.0, 0.3)
	await get_tree().create_timer(0.3).timeout
	for item_index in pending:
		_board.consume_item(item_index)
		_refresh_cell(item_index)
	await _resolve_super_luck(pending[0], _super_luck_clicks_for_items(pending.size()))
	for item_index in pending:
		_complete_prelaunched_bird(item_index, MinesweeperBoard.ItemType.SUPER_LUCK)


func _super_luck_clicks_for_items(item_count: int) -> int:
	return maxi(item_count, 0) * (SUPER_LUCK_CLICKS_PER_ITEM + _super_luck_click_bonus)


func _resolve_queued_item(
	item_index: int,
	item: MinesweeperBoard.ItemType,
	item_queue: Array[int],
	queued_items: Dictionary
) -> void:
	var focus_color := _item_effect_color(item)
	var board := _board
	if item_index < 0 or item_index >= _cells.size():
		return
	_status_label.text = "发现%s，正在结算……" % _item_display_name(item)
	_cells[item_index].play_item_focus(focus_color)
	_spawn_effect_ring(_cell_center(item_index), focus_color, 18.0, 68.0, 0.3)
	await get_tree().create_timer(0.3).timeout
	# 等这 0.3 秒的工夫棋盘可能已经换了（关卡包翻到下一张图）。换了就别再往下结算，
	# 不然会拿旧盘的格号去改新盘——照代码库其它异步处的写法，捕获再比对。
	if board != _board:
		return
	_board.consume_item(item_index)
	_refresh_cell(item_index)
	# **奖励盘的真正触发点**：这张牌马上要生效，可本盘的雷已经被前面几张清光了。
	# 先把奖励盘展开，让它落在新盘上，而不是空转一句「没找到雷」。
	# 判据必须在这里而不是派发处：派发不等结果，一大把牌会在盘面变「已赢」之前就离队。
	if _should_open_bonus_board():
		await _request_bonus_board(item_queue, queued_items)
		if _game_finish_started:
			return
	match item:
		MinesweeperBoard.ItemType.LANTERN:
			await _resolve_lantern(item_index, item_queue, queued_items)
		MinesweeperBoard.ItemType.COMPASS:
			await _resolve_compass(item_index, item_queue, queued_items)
		MinesweeperBoard.ItemType.ORBITAL_STRIKE:
			await _resolve_orbital_strike(item_index, item_queue, queued_items)
		MinesweeperBoard.ItemType.SUPER_LUCK:
			await _resolve_super_luck(item_index)
		MinesweeperBoard.ItemType.MEDICAL_KIT:
			await _resolve_medical_kit(item_index)
		MinesweeperBoard.ItemType.XRAY:
			await _resolve_xray(item_index)
		MinesweeperBoard.ItemType.ENLARGE:
			await _resolve_enlarge(item_index)
		MinesweeperBoard.ItemType.DETECT:
			await _resolve_detect(item_index)
	_check_victory_now()


## 斑鸠接手治愈：叼着枝从栖位直接飞到血条上，到了才回血、才飘字——奖励落在看得见的
## 落点上，而不是凭空跳数字。不绕去那张牌了：来回两程太长，玩家的眼睛只跟着血条走。
func _resolve_medical_kit(item_index: int) -> void:
	var previous_hp := _player_hp
	var healing := 1 + _healing_power_bonus
	var health_center := _health_bar.global_position + _health_bar.size * 0.5 + DOVE_HEAL_OFFSET
	_spawn_effect_ring(_cell_center(item_index), Color("87e58b"), 16.0, 76.0, 0.3)
	await _dove_fly_to_health_bar(health_center)
	_player_hp = mini(_player_hp + healing, _player_max_hp)
	_refresh_health_bar()
	_player_status.play_heal_feedback()
	_spawn_effect_ring(health_center, Color("87e58b"), 18.0, 104.0, 0.36)
	var gained := _player_hp - previous_hp
	var popup := Label.new()
	if gained > 0:
		popup.text = "+%d" % gained
		_status_label.text = "斑鸠衔来一枝，补回了 %d 颗爱心。" % gained
	else:
		popup.text = "已满"
		_status_label.text = "爱心已满，斑鸠把枝叼回去了。"
	_animate_floating_label(popup, health_center, Color("9dffa8"))
	_dove_fly_home(_run_boot_generation)
	await get_tree().create_timer(0.2).timeout


## 一程直飞：叼着枝（帧 0 站姿叼枝起手）扇着翅膀奔血条去。
func _dove_fly_to_health_bar(health_center: Vector2) -> void:
	await _dove_bird.begin_travel_action(DOVE_FLAP_CYCLE[0], true)
	_dove_bird.set_travel_facing_right(health_center.x > _dove_bird.get_launch_global_position().x)
	await _dove_bird.flap_travel_sprite_to_global_center(
		health_center, DOVE_FLY_TIME, DOVE_FLAP_CYCLE, DOVE_FLAP_TIME, 52.0
	)


## 递完就走：就地淡出，回栖位。不阻塞结算；中途重开或换关就收手，免得动到已经归位的鸟。
func _dove_fly_home(boot: int) -> void:
	await _dove_bird.fade_out_travel_sprite(DOVE_VANISH_TIME)
	if boot != _run_boot_generation:
		return
	_dove_bird.reappear_on_perch(0.25)


func _resolve_xray(item_index: int) -> void:
	_last_xray_target = _board.random_hidden_cell()
	if _last_xray_target < 0:
		_status_label.text = "小嘴乌鸦转了一圈，没找到还盖着的格子。"
		return
	var content: Texture2D
	var number_value := 0
	if _board.is_monster_core(_last_xray_target):
		content = _monster_texture(_last_xray_target)
	elif _board.item_at(_last_xray_target) != MinesweeperBoard.ItemType.NONE:
		content = _item_texture(_board.item_at(_last_xray_target))
	else:
		number_value = _board.adjacent_mines(_last_xray_target)
	var spot := _cell_center(_last_xray_target) + CROW_PEEK_OFFSET
	await _crow_peek_in(spot)
	_cells[_last_xray_target].show_xray_hint(content, number_value, XRAY_PEEK_SECONDS)
	_spawn_effect_ring(_cell_center(item_index), Color("c58cff"), 16.0, 74.0, 0.28)
	_status_label.text = "小嘴乌鸦掀开偷看了一眼：这一格的内容会亮 %d 秒。" % int(XRAY_PEEK_SECONDS)
	# 内容自己亮满 3 秒，鸟不留下陪看：顿一拍就地消失，省得挡住刚掀开的那一格。
	_crow_peek_out(spot, _run_boot_generation)
	await get_tree().create_timer(0.18).timeout


## 小嘴乌鸦替透视干活：飞到那一格**旁边**，探身掀起卡片的一角偷看（帧 5 探身、帧 6 掀开）。
## 它落在格子右上方而不是格子上，而且下棋盘时会缩到一格左右（board_travel_scale）：
## 栖位上的鸟有三格宽，照原样压上去就把要给玩家看的内容盖住了。素材的喙朝左下，
## 所以站在右上时正好低头对着那一格。
func _crow_peek_in(spot: Vector2) -> void:
	await _crow_bird.begin_travel_action(0, true)
	_crow_bird.set_travel_facing_right(spot.x > _crow_bird.get_launch_global_position().x)
	await _crow_bird.move_travel_sprite_to_global_center(spot, CROW_FLY_IN_TIME)
	_crow_bird.set_travel_frame(1)


## 掀完就走：换成被自己掀出来的东西吓一跳那一帧（帧 7）、叫一声、冒个圈，随即原地消失，
## 内容留在那儿自己亮完。`boot` 是发起时的开局代号，中途重开或换关就收手，免得动到已经归位的鸟。
func _crow_peek_out(spot: Vector2, boot: int) -> void:
	_crow_bird.set_travel_frame(2)
	_crow_bird.play_action_sfx()
	_spawn_effect_ring(spot, Color("c58cff"), 12.0, 62.0, 0.28)
	await get_tree().create_timer(CROW_PEEK_BEAT).timeout
	if boot != _run_boot_generation:
		return
	await _crow_bird.fade_out_travel_sprite(CROW_VANISH_TIME)
	if boot != _run_boot_generation:
		return
	_crow_bird.reappear_on_perch(0.25)


## 连携用的灰喜鹊分身：帧和栖位上那只同一套，尺寸也照它的 board_travel_scale 缩到一格上下。
## 一颗雷派一只，所以不能共用栖位那一个精灵——那只留在枝上，只负责叫一声。
func _spawn_chain_magpie(start: Vector2) -> TextureRect:
	var source := _magpie_bird.get_node("Sprite") as TextureRect
	var flyer := TextureRect.new()
	flyer.texture = _magpie_bird.action_frames[0]
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.size = source.size * _magpie_bird.get_global_transform().get_scale() * _magpie_bird.board_travel_scale
	flyer.pivot_offset = flyer.size * 0.5
	flyer.z_index = BIRD_FLYOVER_Z
	_effects_layer.add_child(flyer)
	flyer.global_position = start - flyer.size * 0.5
	return flyer


## 飞过去：沿一条微微外拐的弧线，翅膀按固定帧率扇——帧号是拿**真实走过的时间**除以
## MAGPIE_FLAP_TIME 算的，所以这条 tween 必须是线性的；一挂缓动，翅膀就会在两头慢下来。
## 返回这条 tween，调用方等它落地再结算那颗雷。
func _fly_chain_magpie(flyer: TextureRect, start: Vector2, destination: Vector2, delay: float) -> Tween:
	var frames := _magpie_bird.action_frames
	var lateral := (destination - start).orthogonal().normalized() * MAGPIE_LINK_ARC
	var control := (start + destination) * 0.5 + lateral
	flyer.flip_h = (destination.x >= start.x) != _magpie_bird.art_faces_right
	var flight := flyer.create_tween()
	if delay > 0.0:
		flight.tween_interval(delay)
	flight.tween_method(func(progress: float) -> void:
		flyer.global_position = _quadratic_bezier(start, control, destination, progress) - flyer.size * 0.5
		var frame := int(progress * MAGPIE_LINK_FLY_TIME / MAGPIE_FLAP_TIME)
		flyer.texture = frames[frame % frames.size()]
	, 0.0, 1.0, MAGPIE_LINK_FLY_TIME).set_trans(Tween.TRANS_LINEAR)
	return flight


## 落到那颗雷上：收翅摆个姿势，随即一边飘起一边淡掉。
func _land_chain_magpie(flyer: TextureRect) -> void:
	if not is_instance_valid(flyer):
		return
	flyer.texture = _magpie_bird.action_frames[2]
	var settle := flyer.create_tween().set_parallel(true)
	settle.tween_property(flyer, "modulate:a", 0.0, MAGPIE_VANISH_TIME).set_delay(MAGPIE_LAND_HOLD)
	settle.tween_property(flyer, "position:y", flyer.position.y - 24.0, MAGPIE_LAND_HOLD + MAGPIE_VANISH_TIME)
	settle.finished.connect(flyer.queue_free)


func _resolve_enlarge(item_index: int) -> void:
	_enlarge_mark_charges += 1
	_spawn_effect_ring(_cell_center(item_index), Color("d69bff"), 18.0, 88.0, 0.32)
	_status_label.text = "长尾山雀已就位：下一步无敌，它会摔到选中格子上砸开周围 3×3，踩到的雷直接标出来。"
	if _hovered_cell_index >= 0:
		_start_enlarge_hover_preview(_hovered_cell_index)
	await get_tree().create_timer(0.22).timeout


## 巨大化：长尾山雀从栖枝上滑下来，扑腾两下、俯冲、趴在目标格上；3×3 翻开紧跟落地。
## 帧序：action_frames[0] 失足、[1] 扑腾、[2] 俯冲、[3] 趴地。栖枝本体不动，只有鸟离开。
func _play_tit_bird_crash(target_index: int) -> void:
	var target := _cell_center(target_index)
	await _tit_bird.begin_travel_action(0, false)
	var start := _tit_bird.get_launch_global_position()
	# 先微微向上抛再加速坠落：控制点抬到起点与终点之上。
	var apex := Vector2(lerpf(start.x, target.x, 0.3), minf(start.y, target.y) - 150.0)
	var fall := create_tween().set_parallel(true)
	fall.tween_method(func(progress: float) -> void:
		_tit_bird.set_travel_sprite_global_center(_quadratic_bezier(start, apex, target, progress))
	, 0.0, 1.0, TIT_FALL_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(_tit_bird.set_travel_frame.bind(1)).set_delay(TIT_FALL_DURATION * 0.3)
	fall.tween_callback(_tit_bird.set_travel_frame.bind(2)).set_delay(TIT_FALL_DURATION * 0.62)
	await fall.finished
	_tit_bird.set_travel_frame(3)
	_tit_bird.play_action_sfx()
	_play_board_impact(BOARD_SHAKE_MONSTER_STRENGTH, Vector2.DOWN, BOARD_SHAKE_MONSTER_STEPS)
	_spawn_effect_ring(target, Color("d69bff"), CELL_SIZE * 0.6, CELL_SIZE * 3.6, 0.36)
	await get_tree().create_timer(TIT_CRASH_HOLD).timeout


## 落地稍作停留，惊起一小下（扑腾帧）就翻着身子掉出屏幕底（失足帧），过一拍再悄悄淡回枝头。
## 与 3×3 翻牌同时进行；不等后续道具结算，也不阻塞它。
func _drop_tit_bird_offscreen_after(delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	await _tit_bird.tumble_sprite_offscreen_bottom(TIT_TUMBLE_DURATION, 1, 0)
	await get_tree().create_timer(TIT_REAPPEAR_DELAY).timeout
	_tit_bird.reappear_on_perch(0.3)


func _resolve_detect(item_index: int) -> void:
	_last_detect_target = _board.random_hidden_mine_cell()
	if _last_detect_target < 0:
		_status_label.text = "探测没有找到尚未处理的雷。"
		return
	_board.mark_mine(_last_detect_target)
	_refresh_cell(_last_detect_target)
	_play_correct_flag_feedback(_last_detect_target)
	_cells[_last_detect_target].play_border_flash(Color("7be4a0"), 4, 0.1)
	_spawn_effect_ring(_cell_center(_last_detect_target), Color("7be4a0"), 14.0, 72.0, 0.28)
	_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	_status_label.text = "探测自动标出了一个雷。"
	await get_tree().create_timer(0.24).timeout
	_check_victory_now()


func _item_display_name(item: MinesweeperBoard.ItemType) -> String:
	match item:
		MinesweeperBoard.ItemType.LANTERN:
			return "夜鹭"
		MinesweeperBoard.ItemType.COMPASS:
			return "红尾水鸲"
		MinesweeperBoard.ItemType.ORBITAL_STRIKE:
			return "啄木鸟"
		MinesweeperBoard.ItemType.SUPER_LUCK:
			return "红隼"
		MinesweeperBoard.ItemType.MEDICAL_KIT:
			return "斑鸠"
		MinesweeperBoard.ItemType.XRAY:
			return "小嘴乌鸦"
		MinesweeperBoard.ItemType.CHAIN:
			return "灰喜鹊"
		MinesweeperBoard.ItemType.ENLARGE:
			return "长尾山雀"
		MinesweeperBoard.ItemType.DETECT:
			return "探测"
	return "道具"


func _item_effect_color(item: MinesweeperBoard.ItemType) -> Color:
	match item:
		MinesweeperBoard.ItemType.LANTERN:
			return Color("ffe58a")
		MinesweeperBoard.ItemType.COMPASS:
			return Color("8ceff2")
		MinesweeperBoard.ItemType.ORBITAL_STRIKE:
			return Color("ff8b58")
		MinesweeperBoard.ItemType.SUPER_LUCK:
			return Color("f7dc4f")
		MinesweeperBoard.ItemType.MEDICAL_KIT:
			return Color("87e58b")
		MinesweeperBoard.ItemType.XRAY:
			return Color("c58cff")
		MinesweeperBoard.ItemType.CHAIN:
			return Color("6de8f2")
		MinesweeperBoard.ItemType.ENLARGE:
			return Color("d69bff")
		MinesweeperBoard.ItemType.DETECT:
			return Color("7be4a0")
	return Color.WHITE


func _is_small_monster(index: int) -> bool:
	return _board.is_monster_core(index) and _board.monster_peripheral_count(index) == 0


func _flagged_small_monsters() -> Array[int]:
	var result: Array[int] = []
	for index in range(_cells.size()):
		if (
			_is_small_monster(index)
			and _board.state_at(index) == MinesweeperBoard.CellState.FLAGGED
			and not _defeated_mines.has(index)
		):
			result.append(index)
	return result


func _nearest_active_big_monster(source_index: int) -> int:
	var source_x := source_index % _board.width
	var source_y := source_index / _board.width
	var best_index := -1
	var best_distance := 1000000
	for candidate_variant in _active_mines.keys():
		var candidate := int(candidate_variant)
		if _board.monster_peripheral_count(candidate) != 8:
			continue
		var distance := absi(candidate % _board.width - source_x) + absi(candidate / _board.width - source_y)
		if distance < best_distance or (distance == best_distance and candidate < best_index):
			best_distance = distance
			best_index = candidate
	return best_index


func _cell_center(index: int) -> Vector2:
	return _cells[index].global_position + _cells[index].size * 0.5


## 牌堆位置：棋盘正中。发牌从这里甩出去，收牌也朝这里收。
func _board_deal_origin() -> Vector2:
	if _grid == null:
		return Vector2.ZERO
	return _grid.global_position + _grid.size * 0.5


## 开局洗牌（一）：把所有草地牌收进牌堆并藏起来。必须在棋盘 UI 淡入之前调用，
## 否则玩家会先看到摆好的盘、再看着它们缩回牌堆去。
func _prepare_board_deal() -> void:
	var origin := _board_deal_origin()
	for index in range(_cells.size()):
		if not _board.is_active(index):
			continue
		var spin := deg_to_rad(-BOARD_DEAL_SPIN if index % 2 == 0 else BOARD_DEAL_SPIN)
		_cells[index].prepare_deal(origin - _cell_center(index), spin)


## 开局洗牌（二）：一张张甩到各自的格子上，近的先落、远的后落。
func _play_board_deal_shuffle() -> void:
	var order := _board_deal_order()
	if order.is_empty():
		return
	var step := BOARD_DEAL_TOTAL_TIME / float(order.size())
	for slot in range(order.size()):
		_cells[order[slot]].play_deal_in(float(slot) * step)
	await get_tree().create_timer(BOARD_DEAL_TOTAL_TIME + MineCell.DEAL_FLIGHT_TIME).timeout
	# 最后一张落地时轻轻一震，给这段发牌收个尾。
	_play_board_impact()


func _board_deal_order() -> Array[int]:
	var order: Array[int] = []
	for index in range(_cells.size()):
		if _board.is_active(index):
			order.append(index)
	var origin := _board_deal_origin()
	order.sort_custom(func(first: int, second: int) -> bool:
		return (
			_cell_center(first).distance_squared_to(origin)
			< _cell_center(second).distance_squared_to(origin)
		)
	)
	return order


## 横幅摆在棋盘下沿之下那条空木板带上：上方的读数行和刚发完的牌都不挡。
func _round_intro_banner_top() -> float:
	if _board_panel == null:
		return -1.0
	return _board_panel.global_position.y + _board_panel.size.y + 20.0


## 开局横幅的内容：先报雷和连携雷，再按固定顺序列出这一盘埋着的每种伙伴牌。
## 只报数量不报位置——布雷本来也要等玩家第一下点击才发生。
func _round_intro_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _board == null:
		return entries
	entries.append({
		"icon": MONSTER_SMALL_TEXTURE,
		"name": "雷",
		"count": _board.mine_count,
		"accent": Color("ff9a7a"),
	})
	var chain_mines := _board.chain_mine_total()
	if chain_mines > 0:
		entries.append({
			"icon": CHAIN_TEXTURE,
			"name": "连携雷",
			"count": chain_mines,
			"accent": Color("74f3ff"),
		})
	for item_type in ITEM_TYPE_ORDER:
		var total := _board.configured_item_count(item_type)
		if total <= 0:
			continue
		entries.append({
			"icon": _item_texture(item_type),
			"name": _item_display_name(item_type),
			"count": total,
			"accent": _item_effect_color(item_type),
		})
	return entries


func _play_big_monster_reveal(core_index: int) -> void:
	_status_label.text = "地下传来震动……大型怪物出现了！"
	var footprint := Array(_board.neighbors_of(core_index))
	footprint.append(core_index)
	for cell_index in footprint:
		var distance := maxi(
			absi(cell_index % _board.width - core_index % _board.width),
			absi(cell_index / _board.width - core_index / _board.width)
		)
		_cells[cell_index].play_rumble(float(distance) * 0.035)
		if cell_index != core_index:
			_spawn_reveal_debris(cell_index)
	_spawn_effect_ring(_cell_center(core_index), Color("d8b36a"), 32.0, 178.0, 0.42)
	# A long low shake under the rumble, then a freeze on the emerge itself.
	_play_board_shake(BOARD_SHAKE_MONSTER_STRENGTH, Vector2.ZERO, BOARD_SHAKE_MONSTER_STEPS)
	await get_tree().create_timer(0.16).timeout
	_cells[core_index].play_monster_emerge()
	await _play_hitstop(HITSTOP_MONSTER_SECONDS)
	await get_tree().create_timer(0.44).timeout


func _play_mine_trigger_sfx() -> void:
	if _mine_trigger_sfx == null or _mine_trigger_sfx.stream == null:
		return
	_mine_trigger_sfx.play()


func _play_small_mine_player_hit(index: int) -> void:
	_status_label.text = "小雷被触发了！"
	_play_mine_trigger_sfx()
	_cells[index].play_hit()
	# Let the cell reach its contact pose, hold it, then release into the recoil.
	# Freezing before contact would only stall the anticipation; the stall has to
	# land on the hit itself, and the shake after it so it stays visible.
	await get_tree().create_timer(0.045).timeout
	# The blast goes off one frame before the freeze so the hitstop lands on the
	# flash instead of on an empty cell.
	CELL_FX.play_mine_explosion(_effects_layer, _cell_center(index))
	_cells[index].play_border_flash(Color("ff5f3c"), 2, 0.07)
	await _play_hitstop(HITSTOP_MINE_SECONDS)
	_play_board_impact(
		BOARD_SHAKE_MINE_STRENGTH,
		_board_recoil_direction(index),
		BOARD_SHAKE_MINE_STEPS
	)
	await get_tree().create_timer(0.065).timeout
	var projectile := TextureRect.new()
	projectile.texture = MONSTER_SMALL_TEXTURE
	projectile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	projectile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	projectile.size = Vector2(64, 64)
	projectile.pivot_offset = projectile.size * 0.5
	_effects_layer.add_child(projectile)
	var source := _cell_center(index)
	# The monster lands on the portrait, which is what reacts to the damage; the
	# hearts still get their own ring so the cost stays readable.
	var target: Vector2 = _player_status.hero_head_center()
	projectile.global_position = source - projectile.size * 0.5
	var control := (source + target) * 0.5 + Vector2(0, -90)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(func(progress: float) -> void:
		var point := source * pow(1.0 - progress, 2.0) + control * 2.0 * (1.0 - progress) * progress + target * pow(progress, 2.0)
		projectile.global_position = point - projectile.size * 0.5
	, 0.0, 1.0, 0.34)
	tween.tween_property(projectile, "rotation", TAU * 0.8, 0.34)
	tween.tween_property(projectile, "scale", Vector2(0.55, 0.55), 0.34)
	await tween.finished
	projectile.queue_free()
	_spawn_effect_ring(_health_bar.global_position + _health_bar.size * 0.5, Color("ff6658"), 16.0, 86.0, 0.24)
	_player_status.play_hit_feedback()
	CELL_FX.play_impact_hit(_effects_layer, _player_status.hero_head_center())
	await get_tree().create_timer(0.1).timeout


func _spawn_effect_ring(
	center: Vector2,
	color: Color,
	start_diameter: float,
	end_diameter: float,
	duration: float,
	delay: float = 0.0
) -> void:
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2(start_diameter, start_diameter)
	ring.pivot_offset = ring.size * 0.5
	ring.global_position = center - ring.size * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.08)
	style.border_color = Color(color.r, color.g, color.b, 0.82)
	style.set_border_width_all(3)
	style.set_corner_radius_all(999)
	ring.add_theme_stylebox_override("panel", style)
	_effects_layer.add_child(ring)
	var target_scale := Vector2.ONE * (end_diameter / start_diameter)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", target_scale, duration).set_delay(delay)
	tween.tween_property(ring, "modulate:a", 0.0, duration * 0.72).set_delay(delay + duration * 0.28)
	tween.finished.connect(ring.queue_free)


func _play_target_lock(
	source_index: int,
	targets: Array[int],
	color: Color,
	duration: float = 1.0
) -> void:
	_last_target_lock_indices.assign(targets)
	_last_dashed_line_target_count = 0
	var flashes := maxi(2, ceili(duration / 0.2))
	for target in targets:
		_cells[target].play_border_flash(color, flashes, 0.1)
		if target == source_index:
			continue
		_spawn_dashed_target_line(_cell_center(source_index), _cell_center(target), color, duration)
		_last_dashed_line_target_count += 1


func _spawn_dashed_target_line(start: Vector2, finish: Vector2, color: Color, duration: float) -> void:
	var guide := Node2D.new()
	guide.name = "DashedTargetLine"
	# Targeting feedback must stay over the board, but under every bird actor.
	guide.z_index = TARGET_GUIDE_Z
	guide.modulate.a = 0.0
	_effects_layer.add_child(guide)
	var local_start := start - _effects_layer.global_position
	var local_finish := finish - _effects_layer.global_position
	var distance := local_start.distance_to(local_finish)
	var direction := local_start.direction_to(local_finish)
	var dash_length := 13.0
	var gap_length := 9.0
	var cursor := 8.0
	while cursor < distance - 6.0:
		var segment_end := minf(cursor + dash_length, distance - 6.0)
		var dash := Line2D.new()
		dash.width = 4.0
		dash.default_color = Color(color.r, color.g, color.b, 0.96)
		dash.begin_cap_mode = Line2D.LINE_CAP_ROUND
		dash.end_cap_mode = Line2D.LINE_CAP_ROUND
		dash.points = PackedVector2Array([
			local_start + direction * cursor,
			local_start + direction * segment_end,
		])
		guide.add_child(dash)
		cursor += dash_length + gap_length
	var pulse := create_tween()
	pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(guide, "modulate:a", 1.0, 0.1)
	pulse.tween_property(guide, "modulate:a", 0.42, 0.1)
	pulse.tween_property(guide, "modulate:a", 1.0, 0.1)
	pulse.tween_interval(maxf(duration - 0.48, 0.02))
	pulse.tween_property(guide, "modulate:a", 0.0, 0.18)
	pulse.finished.connect(guide.queue_free)


func _spawn_damage_number(center: Vector2, amount: int, color: Color) -> void:
	var label := Label.new()
	label.text = "-%d" % amount
	_animate_floating_label(label, center, color)


func _play_invincible_block_feedback() -> void:
	var center := _health_bar.global_position + _health_bar.size * 0.5
	_status_label.text = "红隼挡住了伤害！"
	_spawn_effect_ring(center, Color("ffe75c"), 18.0, 112.0, 0.3)
	var label := Label.new()
	label.text = "无敌！"
	_animate_floating_label(label, center, Color("ffe75c"))


func _animate_floating_label(label: Label, center: Vector2, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("351a18"))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", 30)
	label.size = Vector2(90, 44)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.global_position = center - label.size * 0.5
	_effects_layer.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position:y", label.global_position.y - 54.0, 0.52)
	tween.tween_property(label, "scale", Vector2(1.18, 1.18), 0.18)
	tween.tween_property(label, "modulate:a", 0.0, 0.24).set_delay(0.28)
	tween.finished.connect(label.queue_free)


func _attack_big_with_small_mines(big_index: int, candidates: Array[int]) -> void:
	if not _active_mines.has(big_index):
		return
	var attackers: Array[int] = []
	for small_index in candidates:
		if (
			_is_small_monster(small_index)
			and _board.state_at(small_index) == MinesweeperBoard.CellState.FLAGGED
			and not _defeated_mines.has(small_index)
		):
			attackers.append(small_index)
	if attackers.is_empty():
		return

	_status_label.text = "%d 枚已标记的小雷正在攻击大型怪物！" % attackers.size()
	for attack_index in range(attackers.size()):
		var small_index := attackers[attack_index]
		_defeated_mines[small_index] = true
		_board.resolve_monster_core(small_index)
		_refresh_cell(small_index)
		await _fly_small_monster(small_index, big_index)
		if not _active_mines.has(big_index):
			break

		# Resolve every projectile as its own hit. The health bar and floating
		# number update before the next small mine starts moving.
		var mine_data: Dictionary = _active_mines[big_index]
		mine_data["hp"] -= SMALL_MINE_ATTACK_DAMAGE
		_cells[big_index].play_hit()
		_spawn_effect_ring(_cell_center(big_index), Color("ff7058"), 24.0, 126.0, 0.26)
		_spawn_damage_number(
			_cell_center(big_index) + Vector2(0, -34),
			SMALL_MINE_ATTACK_DAMAGE,
			Color("ffcf72")
		)
		if mine_data["hp"] <= 0:
			_active_mines.erase(big_index)
			_defeated_mines[big_index] = true
			await get_tree().create_timer(0.2).timeout
			_refresh_cell(big_index)
			break
		_active_mines[big_index] = mine_data
		_cells[big_index].set_combat_mine_status(
			mine_data["hp"], BIG_MONSTER_MAX_HP, mine_data["turns"]
		)
		await get_tree().create_timer(0.22).timeout
		_cells[big_index].play_light(Color("ff7658"))
	_mine_label.text = "%03d" % maxi(_board.mine_count - _defeated_mines.size(), 0)


func _fly_small_monster(source_index: int, target_index: int) -> void:
	var projectile := TextureRect.new()
	projectile.texture = MONSTER_SMALL_TEXTURE
	projectile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	projectile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	projectile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	projectile.size = Vector2(72, 72)
	projectile.pivot_offset = projectile.size * 0.5
	_effects_layer.add_child(projectile)
	var source_center := _cell_center(source_index)
	var target_center := _cell_center(target_index)
	projectile.global_position = source_center - projectile.size * 0.5
	projectile.scale = Vector2(1.05, 0.72)
	var arc_height := 70.0 + source_center.distance_to(target_center) * 0.12
	var control := (source_center + target_center) * 0.5 + Vector2(0, -arc_height)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(progress: float) -> void:
		var point := source_center * pow(1.0 - progress, 2.0) + control * 2.0 * (1.0 - progress) * progress + target_center * pow(progress, 2.0)
		projectile.global_position = point - projectile.size * 0.5
	, 0.0, 1.0, 0.42)
	tween.tween_property(projectile, "scale", Vector2(0.7, 0.7), 0.42)
	tween.tween_property(projectile, "rotation", TAU * 0.9, 0.42)
	await tween.finished
	projectile.queue_free()


func _advance_combat_turn() -> bool:
	for index in _active_mines.keys():
		var mine_data: Dictionary = _active_mines[index]
		mine_data["turns"] -= 1
		if mine_data["turns"] <= 0:
			await _play_big_monster_attack(index)
			if _is_invincible():
				_play_invincible_block_feedback()
			else:
				_apply_player_damage(MINE_DAMAGE)
				_spawn_damage_number(_health_bar.global_position + _health_bar.size * 0.5, MINE_DAMAGE, Color("ff7864"))
			mine_data["turns"] = MINE_ATTACK_DELAY
			_refresh_health_bar()
		_active_mines[index] = mine_data
		_refresh_cell(index)
	_refresh_health_bar()
	return _player_hp <= 0


func _play_big_monster_attack(index: int) -> void:
	_status_label.text = "大型怪物发动攻击！"
	_cells[index].play_hit()
	_spawn_effect_ring(_cell_center(index), Color("ff684f"), 28.0, 142.0, 0.3)
	await _play_hitstop(HITSTOP_MINE_SECONDS)
	_play_board_impact(
		BOARD_SHAKE_MINE_STRENGTH,
		_board_recoil_direction(index),
		BOARD_SHAKE_MINE_STEPS
	)
	await get_tree().create_timer(0.16).timeout
	var source := _cell_center(index)
	var target := _health_bar.global_position + _health_bar.size * 0.5
	var bolt := Line2D.new()
	bolt.width = 10.0
	bolt.default_color = Color("ff6958e6")
	bolt.begin_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.end_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.points = PackedVector2Array([Vector2.ZERO, target - source])
	bolt.global_position = source
	bolt.scale = Vector2(0.0, 1.0)
	_effects_layer.add_child(bolt)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(bolt, "scale:x", 1.0, 0.2)
	tween.tween_property(bolt, "modulate:a", 0.0, 0.14).set_delay(0.2)
	_spawn_effect_ring(target, Color("ff684f"), 18.0, 96.0, 0.26, 0.17)
	await get_tree().create_timer(0.3).timeout
	bolt.queue_free()
	_player_status.play_hit_feedback()
	CELL_FX.play_impact_hit(_effects_layer, _player_status.hero_head_center())


func _update_round_completion() -> void:
	if _board.all_mines_triggered_or_flagged():
		_board.won = true
		_board.game_over = true
	else:
		_board.won = false
		_board.game_over = false


## True while this reveal still owes the player a mine hit.
func _has_unresolved_revealed_mine(changed: PackedInt32Array) -> bool:
	for index in changed:
		if _board.is_monster_core(index) and not _defeated_mines.has(index):
			return true
	return false


func _check_victory_now() -> bool:
	if _game_finish_started or _player_hp <= 0:
		return _game_finish_started and _round_is_won()
	_update_round_completion()
	if not _board.won:
		return false
	# Concurrent bird effects must all clean up and return their actors before
	# progression replaces the board underneath their coroutines.
	if _item_queue_dispatching:
		return false
	_finish_game()
	return true


## 得分/连击柱贴齐整个画面最右边（含对战全屏右缘）。
func _position_combo_hud() -> void:
	if _combo_hud == null:
		return
	var viewport := get_viewport_rect().size
	var pos := Vector2(
		viewport.x - ComboScoreHudScript.HUD_SIZE.x - ComboScoreHudScript.EDGE_INSET,
		(viewport.y - ComboScoreHudScript.HUD_SIZE.y) * 0.5
	)
	_combo_hud.set_home(pos)


## 换盘后把格子几何喂给棋盘表现层：光波的逐格判定查这份缓存，异形盘的空洞格不参与。
func _on_score_combo_changed(score: int, combo: int) -> void:
	if _combo_hud != null:
		_combo_hud.sync_state(score, combo)
	if _combo_board_fx != null:
		_combo_board_fx.set_state(combo)


func _on_score_combo_hit(points: int, combo: int) -> void:
	if _score_combo == null:
		return
	if _combo_hud != null:
		_combo_hud.play_hit(_score_combo.score, points, combo)
	_play_combo_board_hit(combo)
	# 这里不再更新最高分：分数只在每盘结算时进账，刷新点跟着挪到了 _award_time_bonus()。


func _on_score_combo_broke(previous_combo: int) -> void:
	if _combo_hud != null:
		_combo_hud.play_combo_break()
	if _combo_board_fx != null:
		_combo_board_fx.play_break(previous_combo)
	_award_combo_gold_bonus(previous_combo)


## 连击收束时结算额外金币：仅 combo > 2，奖金 = combo - 2。
func _award_combo_gold_bonus(combo_count: int) -> void:
	if combo_count <= 2 or _is_duel():
		return
	var bonus := combo_count - 2
	_combo_bonus_gold += bonus
	_gold += bonus
	_refresh_gold_display()
	if _combo_hud != null:
		_combo_hud.play_gold_bonus(bonus)
	if _board_panel != null and _player_status != null:
		CELL_FX.play_gold_flight(
			_effects_layer,
			_board_panel.global_position + _board_panel.size * 0.5,
			_player_status.gold_center(),
			bonus
		)


## 盘末若还有未断的连击，先收束发奖，再进账单。
func _cash_out_active_combo() -> void:
	if _score_combo == null:
		return
	if _score_combo.combo > 0:
		_score_combo.break_combo()


## 返回这一次是否真的计了分——撤旗重标同一格会走到这里，但不该再加连击，
## 表现层也要靠这个返回值决定要不要跟着炸一次。
func _register_mine_score_hit(cell_index: int = -1) -> bool:
	if _score_combo == null:
		return false
	if cell_index >= 0:
		if _combo_scored_cells.has(cell_index):
			return false
		_combo_scored_cells[cell_index] = true
	# 认雷走这条路，不是普通点击那条：无尽关的分全从这里来。
	_score_combo.register_mine_hit()
	return true


## 一次「翻开了格子」的操作 +1，翻出来多少格都只算一次：手点覆盖格、长尾山雀砸盘、
## 推理推出安全格，三条路都走这里。和「每认出一枚雷 +1」并行计数——一次点击如果
## 顺带自动标出了三枚雷，这一下就是 1 + 3。
##
## 三个调用点都放在「确实会翻开格子」的判断之后，不是放在点击入口上：挂在入口的话，
## 对着一格已经推完的空地连点就能白刷连击。
func _register_click_combo() -> void:
	if _score_combo == null:
		return
	_score_combo.register_combo_hit()


## 这一局按哪种口径计分：无尽关按排雷（每枚 100 分），其余一律按每盘用时。
## 必须在 `_stage_id` 定下来之后、开盘之前调用——`_reset_run_state()` 里的
## `reset()` 会把口径退回关卡默认，所以新开与续局两条路都要各自走一遍。
func _apply_score_mode() -> void:
	if _score_combo == null:
		return
	_score_combo.mode = (
		ScoreComboTrackerScript.Mode.MINES
		if _is_endless_stage()
		else ScoreComboTrackerScript.Mode.TIME
	)


## 这一盘靠排雷拿到的分与雷数。`_combo_scored_cells` 每盘清一次，所以它的大小
## 就是「这一盘真正计了分的雷」——和盘末还插着几面旗不是一回事（标了又撤、
## 或者撤了没补，两边就会对不上）。
func _endless_board_mine_points() -> Array:
	var mines := _combo_scored_cells.size() + _banked_scored_mines
	return [mines, mines * ScoreComboTrackerScript.POINTS_PER_MINE]


## 一盘打完按用时结算：1000 起步、每秒衰减、最低 100（口径在 ScoreComboTracker）。
## 和金币奖励共用同一道重入闸——`_finish_game` 这条路不保证只走一次，
## 少一道闸就会出现「同一盘结算两次分」。
func _award_time_bonus() -> int:
	if _score_combo == null or _time_bonus_awarded_this_run:
		return 0
	_time_bonus_awarded_this_run = true
	# `_score_combo` 是无类型 var，这里必须显式标注，否则推不出返回类型。
	var bonus: int = _score_combo.register_time_bonus(_elapsed)
	_try_update_stage_high_score()
	return bonus


func _break_score_combo() -> void:
	if _score_combo == null:
		return
	_score_combo.break_combo()


func _reset_score_combo_board() -> void:
	if _score_combo == null:
		return
	_combo_scored_cells.clear()
	_combo_bonus_gold = 0
	# 换盘只清连击表；盘末奖金已在账单前 `_cash_out_active_combo` 结算过。
	_score_combo.reset_combo_keep_score()
	if _combo_hud != null:
		_combo_hud.sync_state(_score_combo.score, 0, false)
	if _combo_board_fx != null:
		_combo_board_fx.reset_visuals()


func _reset_score_combo_run() -> void:
	_combo_scored_cells.clear()
	_combo_bonus_gold = 0
	if _score_combo != null:
		_score_combo.reset()
	if _combo_hud != null:
		_combo_hud.reset_visuals()
	if _combo_board_fx != null:
		_combo_board_fx.reset_visuals()


func _try_update_stage_high_score() -> void:
	if not _is_stage_run() or _score_combo == null:
		return
	var score: int = _score_combo.score
	if score <= int(_stage_high_scores.get(_stage_id, 0)):
		return
	_stage_high_scores[_stage_id] = score
	_save_progress()


## Every correct mark — player, compass, lantern, detector, inference — goes
## through here so the confirmation reads the same wherever it comes from.
## 连击的落点表现也全挂在这里：音高、封印染色、盘外烟花，一处改处处一致。
func _play_correct_flag_feedback(cell_index: int) -> void:
	if cell_index < 0 or cell_index >= _cells.size():
		return
	var cell := _cells[cell_index]
	# 只在「插上旗」时计分；撤旗也会进这个反馈函数，不能加连击。
	var scored: bool = (
		_board != null
		and _board.is_flagged(cell_index)
		and _register_mine_score_hit(cell_index)
	)
	# 撤旗重标同一格不再计分，表现也退回原来那发单色封印，别让它白蹭一束烟花。
	var combo: int = _score_combo.combo if scored and _score_combo != null else 0
	_play_correct_flag_sfx(combo)
	cell.play_flag()
	CELL_FX.play_flag_seal(
		_effects_layer,
		_cell_center(cell_index),
		ComboStyle.tier_color(combo) if combo > 0 else Color(1.0, 0.84, 0.42, 1.0),
		ComboStyle.heat(combo)
	)


## 连击的棋盘反馈：盘外炸烟花，棋盘按热度回弹，里程碑再补一帧顿。
## 只由 `_on_score_combo_hit` 一处调用——连击每 +1 就是一束，点击和认雷走同一条路，
## 两边各喊一次就会一下点击炸两束。
func _play_combo_board_hit(combo: int) -> void:
	if combo <= 0:
		return
	var heat: float = ComboStyle.heat(combo)
	if _combo_board_fx != null:
		_combo_board_fx.play_hit(combo)
		if ComboStyle.is_milestone(combo):
			_combo_board_fx.play_milestone(combo)
	# 只晃不缩放：连击是「确认」不是「撞击」，缩放会把格子的点击判定一起挪走。
	# 这里刻意不给顿帧。里程碑是每 5 连一次，而现在点一下就 +1——
	# 顿帧会变成每五次点击卡一下，越连越卡。升调、烟花和抖动已经够撑起递进了。
	_play_board_shake(
		COMBO_SHAKE_BASE + COMBO_SHAKE_HEAT_GAIN * heat, Vector2.ZERO, COMBO_SHAKE_STEPS
	)


## 确认音跟着连击往上爬半音阶，爬满一个八度封顶。连击真正的节奏感八成来自这条，
## 视觉再足也替代不了；断连时连击归零，音高自然落回起点。
func _play_correct_flag_sfx(combo: int = 0) -> void:
	if _correct_flag_sfx == null or _correct_flag_sfx.stream == null:
		return
	# Correct marks can arrive in quick inference batches, so keep each
	# confirmation voice independent instead of cutting the previous one off.
	var voice := AudioStreamPlayer.new()
	voice.stream = _correct_flag_sfx.stream
	voice.volume_db = _correct_flag_sfx.volume_db + ComboStyle.gain_db_for(combo)
	voice.pitch_scale = ComboStyle.pitch_for(combo)
	voice.bus = _correct_flag_sfx.bus
	add_child(voice)
	voice.play()
	_release_correct_flag_sfx_voice(voice)


func _release_correct_flag_sfx_voice(voice: AudioStreamPlayer) -> void:
	# 升调同时把时长压短了，回收窗口要跟着除掉，长连击才不会挂一串播完的空 voice。
	var length := voice.stream.get_length() / maxf(voice.pitch_scale, 0.01)
	await get_tree().create_timer(maxf(length, 0.1) + 0.05).timeout
	if is_instance_valid(voice):
		voice.queue_free()


## Flipping a mine open telegraphs the danger before the hit resolves; the wave
## can still be running, so the alert waits out this cell's own reveal delay.
func _telegraph_mine_reveal(cell_index: int, delay: float) -> void:
	if cell_index < 0 or cell_index >= _cells.size():
		return
	var cell := _cells[cell_index]
	await get_tree().create_timer(maxf(delay, 0.0) + 0.2).timeout
	# A level change during the wave frees the board this alert was aimed at.
	if not is_instance_valid(cell) or not cell.is_inside_tree():
		return
	CELL_FX.play_mine_alert(_effects_layer, cell.global_position + cell.size * 0.5)
	cell.play_border_flash(Color("ff5f3c"), 2, 0.09)


func _spawn_reveal_debris(cell_index: int) -> void:
	var center := _cells[cell_index].global_position + _cells[cell_index].size * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = _board.seed ^ (cell_index * 7919) ^ Time.get_ticks_msec()
	var fragment_colors := [Color("7d9c35"), Color("9ab849"), Color("79502d"), Color("9a6737")]
	for fragment_index in range(4):
		var fragment := ColorRect.new()
		var fragment_size := rng.randf_range(6.0, 11.0)
		fragment.size = Vector2(fragment_size, fragment_size * rng.randf_range(0.55, 0.9))
		fragment.color = fragment_colors[fragment_index]
		fragment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fragment.pivot_offset = fragment.size * 0.5
		_effects_layer.add_child(fragment)
		fragment.global_position = center + Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-8.0, 8.0))
		var angle := rng.randf_range(-2.75, -0.4)
		var distance := rng.randf_range(34.0, 62.0)
		var destination := fragment.global_position + Vector2(cos(angle), sin(angle)) * distance + Vector2(0, 30)
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(fragment, "global_position", destination, 0.38)
		tween.tween_property(fragment, "rotation", rng.randf_range(-2.5, 2.5), 0.38)
		tween.tween_property(fragment, "modulate:a", 0.0, 0.28).set_delay(0.1)
		tween.finished.connect(fragment.queue_free)

	var dust := Panel.new()
	dust.size = Vector2(48, 22)
	dust.pivot_offset = dust.size * 0.5
	dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dust_style := StyleBoxFlat.new()
	dust_style.bg_color = Color(0.72, 0.53, 0.3, 0.28)
	dust_style.set_corner_radius_all(30)
	dust.add_theme_stylebox_override("panel", dust_style)
	_effects_layer.add_child(dust)
	dust.global_position = center - dust.size * 0.5 + Vector2(0, 15)
	dust.scale = Vector2(0.45, 0.45)
	var dust_tween := create_tween().set_parallel(true)
	dust_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	dust_tween.tween_property(dust, "scale", Vector2(1.55, 1.2), 0.3)
	dust_tween.tween_property(dust, "global_position:y", dust.global_position.y - 13.0, 0.3)
	dust_tween.tween_property(dust, "modulate:a", 0.0, 0.3)
	dust_tween.finished.connect(dust.queue_free)


func _resolve_lantern(item_index: int, item_queue: Array[int], queued_items: Dictionary) -> void:
	var was_prelaunched := _prelaunched_item_indices.has(item_index)
	_last_lantern_target = item_index
	var target_count := 1 + _lantern_target_bonus
	var targets: PackedInt32Array = _board.random_lantern_targets(item_index, target_count)
	_last_lantern_noop = targets.is_empty()
	if not _last_lantern_noop:
		var lantern_lock_targets: Array[int] = []
		lantern_lock_targets.assign(Array(targets))
		_play_target_lock(item_index, lantern_lock_targets, Color("ffe477"), 2.2)
	if not was_prelaunched:
		await _black_bird.play_action()
		await _black_bird.fly_sprite_offscreen_bottom()
	if _last_lantern_noop:
		_night_master_fish_count += 1
		_unlock_achievement(ACHIEVEMENT_NIGHT_MASTER_FISH)
		_show_night_master_fish_guide_once()
		await _show_night_master_fish_popup()
		if not was_prelaunched:
			_black_bird.reset_to_idle()
		_status_label.text = "夜师傅吃了你的鱼。"
		return
	var flying_bird := await _fly_black_bird_to_target(item_index)
	var fish_drop_state := {"remaining": targets.size()}
	_last_lantern_fish_count = targets.size()
	for target in targets:
		var fish_bomb := _spawn_black_bird_fish(flying_bird)
		_drop_black_bird_fish_for_queue(fish_bomb, target, fish_drop_state)
		await get_tree().create_timer(0.075).timeout
		await get_tree().process_frame
	var departure := _start_black_bird_dive_away(flying_bird)
	while int(fish_drop_state["remaining"]) > 0:
		await get_tree().process_frame
	_status_label.text = "夜鹭正在随机照亮 %d 个周围格子……" % targets.size()
	_spawn_effect_ring(_cell_center(item_index), Color("ffe477"), 30.0, 150.0, 0.34)
	for target in targets:
		_cells[target].play_light(Color("ffe9a0"))
	await get_tree().create_timer(0.16).timeout

	var result: Dictionary = _board.apply_lantern_targets(targets)
	var revealed: PackedInt32Array = result["revealed"]
	_present_revealed(revealed, item_queue, queued_items)
	if _check_victory_now():
		if not was_prelaunched:
			_black_bird.reset_to_idle()
		return
	if not revealed.is_empty():
		await get_tree().create_timer(0.2).timeout
	var flagged: PackedInt32Array = result["flagged"]
	for flagged_index in flagged:
		_refresh_cell(flagged_index)
		_play_correct_flag_feedback(flagged_index)
		_spawn_effect_ring(_cell_center(flagged_index), Color("f7c95b"), 12.0, 58.0, 0.2)
		await get_tree().create_timer(0.055).timeout
	_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	var attack_groups: Dictionary = {}
	for flagged_index in flagged:
		if not _is_small_monster(flagged_index):
			continue
		var target := _nearest_active_big_monster(flagged_index)
		if target < 0:
			continue
		if not attack_groups.has(target):
			attack_groups[target] = []
		var group: Array = attack_groups[target]
		group.append(flagged_index)
		attack_groups[target] = group
	for target_variant in attack_groups.keys():
		var target := int(target_variant)
		var untyped_attackers: Array = attack_groups[target]
		var attackers: Array[int] = []
		attackers.assign(untyped_attackers)
		await _attack_big_with_small_mines(target, attackers)
	if departure.is_running():
		await departure.finished
	if not was_prelaunched:
		_black_bird.reset_to_idle()
	await get_tree().create_timer(0.12).timeout


func _show_night_master_fish_popup() -> void:
	var popup := NightMasterFishPopupView.instantiate() as NightMasterFishPopup
	_effects_layer.add_child(popup)
	await popup.play()


func _fly_black_bird_to_target(target_index: int) -> TextureRect:
	var flyer := TextureRect.new()
	flyer.texture = BLACK_FLY_TEXTURE_1
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.size = Vector2(164, 164)
	flyer.pivot_offset = flyer.size * 0.5
	flyer.z_index = BIRD_FLYOVER_Z
	_effects_layer.add_child(flyer)

	var target_center := _cell_center(target_index)
	var viewport_size := get_viewport_rect().size
	var flyover_center := target_center + Vector2(-18.0, -112.0)
	var dive_start := target_center + Vector2(-250.0, -260.0)
	dive_start.x = clampf(dive_start.x, 260.0, viewport_size.x - 240.0)
	dive_start.y = clampf(dive_start.y, 90.0, 280.0)
	var screen_entry := Vector2(-180.0, clampf(dive_start.y - 45.0, 70.0, 230.0))
	flyer.global_position = screen_entry - flyer.size * 0.5

	var cruise_control := (screen_entry + dive_start) * 0.5 + Vector2(0, -72.0)
	var cruise := create_tween().set_parallel(true)
	cruise.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cruise.tween_method(func(progress: float) -> void:
		var point := _quadratic_bezier(screen_entry, cruise_control, dive_start, progress)
		flyer.global_position = point - flyer.size * 0.5
	, 0.0, 1.0, 0.7)
	cruise.tween_property(flyer, "rotation", -0.06, 0.32)
	cruise.tween_property(flyer, "rotation", 0.02, 0.38).set_delay(0.32)
	await cruise.finished

	# The second FX is a distinct, sudden dive pose.
	flyer.texture = BLACK_FLY_TEXTURE_2
	var dive_control := dive_start.lerp(flyover_center, 0.48) + Vector2(45.0, -65.0)
	var dive := create_tween().set_parallel(true)
	dive.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dive.tween_method(func(progress: float) -> void:
		var point := _quadratic_bezier(dive_start, dive_control, flyover_center, progress)
		flyer.global_position = point - flyer.size * 0.5
	, 0.0, 1.0, 0.3)
	dive.tween_property(flyer, "scale", Vector2(1.12, 1.12), 0.3)
	await dive.finished
	return flyer


func _spawn_black_bird_fish(flyer: TextureRect) -> TextureRect:
	var fish := TextureRect.new()
	var texture_index := randi_range(0, BLACK_FISH_TEXTURES.size() - 1)
	fish.texture = BLACK_FISH_TEXTURES[texture_index]
	fish.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fish.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fish.size = Vector2(82, 82)
	fish.pivot_offset = fish.size * 0.5
	fish.z_index = BIRD_DROPPED_PROP_Z
	_effects_layer.add_child(fish)
	var release_center := flyer.global_position + flyer.size * 0.5 + Vector2(5.0, 34.0)
	fish.global_position = release_center - fish.size * 0.5
	fish.rotation = -0.18
	return fish


func _drop_black_bird_fish(fish: TextureRect, target_index: int) -> void:
	var start_center := fish.global_position + fish.size * 0.5
	var target_center := _cell_center(target_index)
	var drop_control := start_center.lerp(target_center, 0.45) + Vector2(38.0, -58.0)
	var drop := create_tween().set_parallel(true)
	drop.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_method(func(progress: float) -> void:
		var point := _quadratic_bezier(start_center, drop_control, target_center, progress)
		fish.global_position = point - fish.size * 0.5
	, 0.0, 1.0, 0.36)
	drop.tween_property(fish, "rotation", TAU * 0.82, 0.36)
	drop.tween_property(fish, "scale", Vector2(0.78, 0.78), 0.36)
	await drop.finished
	_play_black_fish_blast(target_index)
	var squash := create_tween().set_parallel(true)
	squash.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	squash.tween_property(fish, "scale", Vector2(1.28, 0.34), 0.1)
	squash.tween_property(fish, "modulate:a", 0.0, 0.1)
	await squash.finished
	fish.queue_free()


func _drop_black_bird_fish_for_queue(fish: TextureRect, target_index: int, state: Dictionary) -> void:
	await _drop_black_bird_fish(fish, target_index)
	state["remaining"] = maxi(0, int(state["remaining"]) - 1)


func _play_black_fish_blast(target_index: int) -> void:
	var center := _cell_center(target_index)
	var targets := _board.neighbors_of(target_index)
	targets.append(target_index)
	_spawn_effect_ring(center, Color("d9f5ff"), 18.0, CELL_SIZE * 3.25, 0.34)
	_spawn_effect_ring(center, Color("78cde8"), 12.0, CELL_SIZE * 2.25, 0.24, 0.04)
	for target in targets:
		var distance := maxi(
			absi(target % _board.width - target_index % _board.width),
			absi(target / _board.width - target_index / _board.width)
		)
		_cells[target].play_rumble(float(distance) * 0.025)
		_cells[target].play_light(Color("d8f3ec"))
	_spawn_reveal_debris(target_index)


func _start_black_bird_dive_away(flyer: TextureRect) -> Tween:
	var start_center := flyer.global_position + flyer.size * 0.5
	var viewport_size := get_viewport_rect().size
	var exit_center := Vector2(viewport_size.x + 190.0, viewport_size.y + 170.0)
	var pass_control := start_center + Vector2(185.0, 115.0)
	var departure := create_tween().set_parallel(true)
	departure.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	departure.tween_method(func(progress: float) -> void:
		var point := _quadratic_bezier(start_center, pass_control, exit_center, progress)
		flyer.global_position = point - flyer.size * 0.5
	, 0.0, 1.0, 0.38)
	departure.tween_property(flyer, "scale", Vector2(0.94, 0.94), 0.38)
	departure.finished.connect(flyer.queue_free)
	return departure


func _resolve_compass(item_index: int, item_queue: Array[int], queued_items: Dictionary) -> void:
	var was_prelaunched := _prelaunched_item_indices.has(item_index)
	var targets: Array[int] = []
	for count in range(1 + _compass_mark_bonus):
		var target := _board.random_hidden_mine_cell_excluding(targets)
		if target < 0:
			break
		targets.append(target)
	if targets.is_empty():
		_status_label.text = "红尾水鸲没有找到尚未处理的雷。"
		return
	_last_compass_target = targets[0]
	_status_label.text = "红尾水鸲正在锁定 %d 个有雷格子……" % targets.size()
	_play_target_lock(item_index, targets, Color("8ceff2"), 1.45)
	if not was_prelaunched:
		await _red_bird.play_action()
		await _red_bird.fly_sprite_offscreen_right()
	var flyover_state := {"remaining": targets.size()}
	_last_compass_flyover_count = targets.size()
	for target in targets:
		_resolve_redstart_target_flyover(target, flyover_state)
		await get_tree().create_timer(0.10).timeout
		await get_tree().process_frame
	while int(flyover_state["remaining"]) > 0:
		await get_tree().process_frame
	_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	if _check_victory_now():
		if not was_prelaunched:
			_red_bird.reset_to_idle()
		return
	if not was_prelaunched:
		_red_bird.reset_to_idle()
	await get_tree().create_timer(0.12).timeout


func _resolve_redstart_target_flyover(target: int, state: Dictionary) -> void:
	var flying_bird := await _fly_red_bird_to_target(target)
	if _board.mark_mine(target):
		_refresh_cell(target)
		_play_correct_flag_feedback(target)
		_cells[target].play_border_flash(Color("8ceff2"), 4, 0.1)
		_spawn_effect_ring(_cell_center(target), Color("8ceff2"), 14.0, 72.0, 0.28)
	await _fly_red_bird_away(flying_bird, target)
	state["remaining"] = maxi(0, int(state["remaining"]) - 1)


func _resolve_orbital_strike(item_index: int, item_queue: Array[int], queued_items: Dictionary) -> void:
	var was_prelaunched := _prelaunched_item_indices.has(item_index)
	var vertical := _choose_orbital_vertical(item_index)
	_last_orbital_vertical = vertical
	var targets := _orbital_cross_targets(item_index) if _orbital_cross_unlocked else _orbital_line_targets(item_index, vertical)
	_status_label.text = (
		"啄木鸟锁定第 %d 行与第 %d 列……" % [item_index / _board.width + 1, item_index % _board.width + 1]
		if _orbital_cross_unlocked
		else ("啄木鸟锁定第 %d 列……" % (item_index % _board.width + 1) if vertical else "啄木鸟锁定第 %d 行……" % (item_index / _board.width + 1))
	)
	_last_orbital_step = -1
	_play_target_lock(item_index, targets, Color("ffb45f"), 1.55)
	_attacker_bird.play_trigger_sfx()
	var queued_traveler: TextureRect
	if was_prelaunched:
		queued_traveler = _spawn_queued_attacker_traveler()
	else:
		await _attacker_bird.begin_travel_action(0, false)
	var entry := (
		_cell_center(targets[0]) + Vector2(CELL_SIZE * 1.05, -CELL_SIZE * 0.18)
		if _orbital_cross_unlocked or not vertical
		else _cell_center(targets[0]) + Vector2(0, -CELL_SIZE * 1.25)
	)
	if was_prelaunched:
		await _move_effect_sprite_to_center(queued_traveler, entry, 0.38)
	else:
		await _attacker_bird.move_travel_sprite_to_global_center(entry, 0.38)

	var flagged := PackedInt32Array()
	if was_prelaunched:
		queued_traveler.texture = _attacker_bird.action_frames[1]
	else:
		_attacker_bird.set_travel_frame(1)
	for target in targets:
		var peck_center := _woodpecker_peck_visual_center(target)
		if was_prelaunched:
			await _move_effect_sprite_to_center(queued_traveler, peck_center, 0.055)
		else:
			await _attacker_bird.move_travel_sprite_to_global_center(peck_center, 0.055)
		_attacker_bird.play_action_sfx()
		_last_orbital_step = target
		_cells[target].play_rumble()
		_cells[target].play_light(Color("ffdf92"))
		var result: Dictionary = _board.apply_orbital_strike_cell(target)
		var revealed: PackedInt32Array = result["revealed"]
		_present_revealed(revealed, item_queue, queued_items)
		var newly_flagged: PackedInt32Array = result["flagged"]
		for flagged_index in newly_flagged:
			flagged.append(flagged_index)
			_refresh_cell(flagged_index)
			_play_correct_flag_feedback(flagged_index)
			_spawn_effect_ring(_cell_center(flagged_index), Color("ffcf63"), 12.0, 62.0, 0.2)
		if _check_victory_now():
			_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
			if was_prelaunched:
				queued_traveler.queue_free()
			else:
				_attacker_bird.reset_to_idle()
			return
		await get_tree().create_timer(0.055).timeout

	if was_prelaunched:
		queued_traveler.texture = _attacker_bird.action_frames[0]
		await _fly_effect_sprite_offscreen(queued_traveler, 0.28)
	else:
		_attacker_bird.set_travel_frame(0)
		await _attacker_bird.finish_travel_action(0.34)
	_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	await _attack_newly_flagged_smalls(flagged)
	await get_tree().create_timer(0.16).timeout


func _woodpecker_peck_visual_center(target: int) -> Vector2:
	# The action sprite's beak sits low inside its square frame. One extra cell of
	# lift aligns the visible peck with the target while gameplay stays unchanged.
	return _cell_center(target) + Vector2(0, -CELL_SIZE * 2.0)


func _spawn_queued_attacker_traveler() -> TextureRect:
	var source := _attacker_bird.get_node("Sprite") as TextureRect
	var traveler := TextureRect.new()
	traveler.texture = _attacker_bird.action_frames[0]
	traveler.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	traveler.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	traveler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	traveler.size = source.size
	traveler.pivot_offset = traveler.size * 0.5
	traveler.z_index = BIRD_FLYOVER_Z
	_effects_layer.add_child(traveler)
	traveler.global_position = Vector2(-traveler.size.x * 1.5, get_viewport_rect().size.y * 0.22)
	return traveler


func _move_effect_sprite_to_center(sprite: TextureRect, target_center: Vector2, duration: float) -> void:
	if not is_instance_valid(sprite):
		return
	var target_position := target_center - sprite.size * 0.5
	var travel := create_tween()
	travel.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	travel.tween_property(sprite, "global_position", target_position, duration)
	await travel.finished


func _fly_effect_sprite_offscreen(sprite: TextureRect, duration: float) -> void:
	if not is_instance_valid(sprite):
		return
	var destination := Vector2(get_viewport_rect().size.x + sprite.size.x, sprite.global_position.y - 80.0)
	var departure := create_tween()
	departure.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	departure.tween_property(sprite, "global_position", destination, duration)
	await departure.finished
	sprite.queue_free()


func _choose_orbital_vertical(item_index: int) -> bool:
	var horizontal_targets := _orbital_line_targets(item_index, false)
	var vertical_targets := _orbital_line_targets(item_index, true)
	var horizontal_has_work := _orbital_line_would_change(horizontal_targets)
	var vertical_has_work := _orbital_line_would_change(vertical_targets)
	if not horizontal_has_work and vertical_has_work:
		return true
	if not vertical_has_work and horizontal_has_work:
		return false
	if _orbital_orientation_override >= 0:
		return _orbital_orientation_override == 1
	return randi_range(0, 1) == 1


func _orbital_line_targets(item_index: int, vertical: bool) -> Array[int]:
	var targets: Array[int] = []
	if vertical:
		var column := item_index % _board.width
		for row in range(_board.height):
			var target := row * _board.width + column
			if _board.is_active(target):
				targets.append(target)
	else:
		var row: int = item_index / _board.width
		for column in range(_board.width - 1, -1, -1):
			var target := row * _board.width + column
			if _board.is_active(target):
				targets.append(target)
	return targets


func _orbital_cross_targets(item_index: int) -> Array[int]:
	var targets := _orbital_line_targets(item_index, false)
	for target in _orbital_line_targets(item_index, true):
		if not targets.has(target):
			targets.append(target)
	return targets


func _orbital_line_would_change(targets: Array[int]) -> bool:
	for target in targets:
		if _board.is_monster_core(target):
			if _board.state_at(target) == MinesweeperBoard.CellState.COVERED:
				return true
		elif _board.state_at(target) != MinesweeperBoard.CellState.REVEALED:
			return true
	return false


func _defer_super_luck_reveals(changed: PackedInt32Array) -> void:
	for index in changed:
		if _super_luck_deferred_lookup.has(index):
			continue
		_super_luck_deferred_lookup[index] = true
		_super_luck_deferred_indices.append(index)
		if index >= 0 and index < _cells.size():
			_cells[index].set_super_luck_pending(true)


func _clear_super_luck_pending_borders() -> void:
	for index in _super_luck_deferred_indices:
		if index >= 0 and index < _cells.size():
			_cells[index].set_super_luck_pending(false)
	if _super_luck_hover_index >= 0 and _super_luck_hover_index < _cells.size():
		_cells[_super_luck_hover_index].set_super_luck_pending(false)
	_super_luck_hover_index = -1


func _fly_eg_small_over_cell(index: int) -> void:
	_super_luck_click_fly_count += 1
	var flyer := TextureRect.new()
	flyer.texture = EG_FLY_BIG_TEXTURE
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.size = Vector2(148, 148)
	flyer.pivot_offset = flyer.size * 0.5
	flyer.z_index = 56
	_effects_layer.add_child(flyer)

	var target_center := _cell_center(index)
	var viewport_size := get_viewport_rect().size
	var direction := Vector2(1.0, -0.72).normalized()
	var outside_margin := flyer.size.x * 0.5 + 24.0
	var start_distance := maxf(
		(target_center.x + outside_margin) / direction.x,
		(viewport_size.y + outside_margin - target_center.y) / -direction.y
	)
	var finish_distance := maxf(
		(viewport_size.x + outside_margin - target_center.x) / direction.x,
		(target_center.y + outside_margin) / -direction.y
	)
	var start_center := target_center - direction * start_distance
	var finish_center := target_center + direction * finish_distance
	flyer.global_position = start_center - flyer.size * 0.5
	var flight := create_tween().set_parallel(true)
	flight.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flight.tween_method(func(progress: float) -> void:
		var point := start_center.lerp(finish_center, progress)
		flyer.global_position = point - flyer.size * 0.5
	, 0.0, 1.0, 0.72)
	flight.tween_property(flyer, "scale", Vector2(0.9, 0.9), 0.72)
	await flight.finished
	flyer.queue_free()


## 红隼模式把外围的鸟收到屏外，只留红隼自己独占这一刻。两个例外：
## 红隼是主角，长尾山雀要留在枝上——模式里那一次左键仍可能翻出巨大，它得等着摔下来。
## 其余七只一律收走；新加的鸟别忘了挂进来，漏一只就是它孤零零留在原地。
func _super_luck_other_birds() -> Array[BirdPerch]:
	return [
		_blue_bird, _red_bird, _black_bird, _attacker_bird,
		_magpie_bird, _crow_bird, _dove_bird,
	]


func _enter_super_luck_mode(click_count: int = SUPER_LUCK_CLICKS_PER_ITEM) -> void:
	_super_luck_mode_generation += 1
	_super_luck_mode_active = true
	_super_luck_settling = false
	_super_luck_clicks_remaining = maxi(click_count, 1)
	_clear_super_luck_pending_borders()
	_super_luck_deferred_indices.clear()
	_super_luck_deferred_lookup.clear()
	_super_luck_click_fly_count = 0
	if (
		_hovered_cell_index >= 0
		and _hovered_cell_index < _cells.size()
		and _board.state_at(_hovered_cell_index) == MinesweeperBoard.CellState.COVERED
	):
		_super_luck_hover_index = _hovered_cell_index
		_cells[_hovered_cell_index].set_super_luck_pending(true)
	for bird in _super_luck_other_birds():
		bird.slide_sprite_offscreen_nearest()
	await get_tree().create_timer(0.4).timeout
	_invincible_was_active = true
	_refresh_health_bar()


func _consume_super_luck_click() -> void:
	if not _super_luck_mode_active or _super_luck_clicks_remaining <= 0:
		return
	_super_luck_clicks_remaining -= 1
	if _super_luck_clicks_remaining > 0:
		_status_label.text = "红隼模式：还可点击 %d 次" % _super_luck_clicks_remaining
		return
	_finish_super_luck_mode_after_clicks(_super_luck_mode_generation)


func _finish_super_luck_mode_after_clicks(generation: int) -> void:
	if generation != _super_luck_mode_generation or not _super_luck_mode_active:
		return
	# Close the click-taking state synchronously, before the first await.
	_super_luck_mode_active = false
	_super_luck_settling = true
	_restart_button.disabled = true
	_set_board_interactable(false)
	# Let the input callback and the final cell state finish before settlement.
	await get_tree().process_frame
	while _resolving:
		await get_tree().process_frame
		if generation != _super_luck_mode_generation:
			return
	_resolving = true
	_status_label.text = "红隼模式结束，正在统一结算发现的内容……"
	for bird in _super_luck_other_birds():
		bird.return_sprite_from_last_exit()
	await get_tree().create_timer(0.4).timeout
	_apply_bird_unlock_visibility()
	await _settle_super_luck_reveals()
	# A deferred super-luck item may have started a newer generation while this
	# settlement was running. The old generation must not erase its click count.
	if generation != _super_luck_mode_generation:
		if _super_luck_mode_active and not _game_finish_started:
			_resolving = false
			_restart_button.disabled = false
			_set_board_interactable(true)
			_refresh_health_bar()
		return
	_super_luck_settling = false
	_super_luck_clicks_remaining = 0
	if _board.game_over or _player_hp <= 0:
		return
	_resolving = false
	_restart_button.disabled = false
	_set_board_interactable(true)
	_refresh_health_bar()
	_status_label.text = "红隼模式结束，发现的内容已全部结算。"


func _settle_super_luck_reveals() -> void:
	var changed := PackedInt32Array()
	for index in _super_luck_deferred_indices:
		changed.append(index)
	_clear_super_luck_pending_borders()
	_super_luck_deferred_indices.clear()
	_super_luck_deferred_lookup.clear()
	if _check_victory_now():
		return

	var revealed_big_monsters := await _register_revealed_combat_objects(changed)
	for big_index in revealed_big_monsters:
		await _attack_big_with_small_mines(big_index, _flagged_small_monsters())

	var item_queue: Array[int] = []
	var queued_items: Dictionary = {}
	var ordered := Array(changed)
	ordered.sort()
	for index in ordered:
		if (
			_board.item_at(index) != MinesweeperBoard.ItemType.NONE
			and not _board.is_item_used(index)
			and not queued_items.has(index)
		):
			queued_items[index] = true
			item_queue.append(index)
			_prelaunch_queued_bird(index, _board.item_at(index))
	await _resolve_item_queue(item_queue, queued_items)
	# 红隼模式里被直接标掉的雷也算连携的标记点 B，攒到这里一起结算。
	await _flush_chain_links(false)
	if _game_finish_started:
		return
	_update_round_completion()
	if _player_hp <= 0 or _board.game_over:
		await _finish_game()
		return
	var player_defeated := await _advance_combat_turn()
	if player_defeated:
		await _finish_game()


func _resolve_super_luck(item_index: int, click_count: int = SUPER_LUCK_CLICKS_PER_ITEM) -> void:
	_super_luck_activation_count += 1
	_eg_bird.play_trigger_sfx()
	await _fly_eg_big_across_screen()
	await _enter_super_luck_mode(click_count)
	_status_label.text = "红隼模式！可点击 %d 次，发现的内容将在次数耗尽后结算。" % click_count
	var health_center := _health_bar.global_position + _health_bar.size * 0.5
	_spawn_effect_ring(_cell_center(item_index), Color("ffe75c"), 18.0, 118.0, 0.34)
	_spawn_effect_ring(health_center, Color("ffe75c"), 22.0, 136.0, 0.4, 0.12)
	_cells[item_index].play_light(Color("fff19a"))
	await get_tree().create_timer(0.34).timeout


func _fly_eg_big_across_screen() -> void:
	var flyer := TextureRect.new()
	flyer.texture = EG_FLY_BIG_TEXTURE
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.size = Vector2(720, 720)
	flyer.pivot_offset = flyer.size * 0.5
	flyer.z_index = 80
	_effects_layer.add_child(flyer)

	var viewport_size := get_viewport_rect().size
	var start_center := Vector2(-360.0, viewport_size.y + 300.0)
	var end_center := Vector2(viewport_size.x + 360.0, -300.0)
	var arc_control := (start_center + end_center) * 0.5 + Vector2(-80.0, 90.0)
	flyer.global_position = start_center - flyer.size * 0.5
	flyer.modulate.a = 0.0
	var flight := create_tween().set_parallel(true)
	flight.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flight.tween_method(func(progress: float) -> void:
		var point := _quadratic_bezier(start_center, arc_control, end_center, progress)
		flyer.global_position = point - flyer.size * 0.5
	, 0.0, 1.0, 0.9)
	flight.tween_property(flyer, "modulate:a", 1.0, 0.12)
	flight.tween_property(flyer, "modulate:a", 0.0, 0.16).set_delay(0.74)
	flight.tween_property(flyer, "scale", Vector2(1.12, 1.12), 0.9)
	await flight.finished
	flyer.queue_free()


func _attack_newly_flagged_smalls(flagged: PackedInt32Array) -> void:
	var attack_groups: Dictionary = {}
	for flagged_index in flagged:
		if not _is_small_monster(flagged_index):
			continue
		var target := _nearest_active_big_monster(flagged_index)
		if target < 0:
			continue
		if not attack_groups.has(target):
			attack_groups[target] = []
		var group: Array = attack_groups[target]
		group.append(flagged_index)
		attack_groups[target] = group
	for target_variant in attack_groups.keys():
		var target := int(target_variant)
		var untyped_attackers: Array = attack_groups[target]
		var attackers: Array[int] = []
		attackers.assign(untyped_attackers)
		await _attack_big_with_small_mines(target, attackers)


func _fly_red_bird_to_target(target_index: int) -> TextureRect:
	var flyer := TextureRect.new()
	flyer.texture = RED_FLY_TEXTURE
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.size = Vector2(154, 154)
	flyer.pivot_offset = flyer.size * 0.5
	flyer.z_index = BIRD_FLYOVER_Z
	_effects_layer.add_child(flyer)

	var target_center := _cell_center(target_index)
	var viewport_size := get_viewport_rect().size
	var start_center := Vector2(viewport_size.x + 130.0, minf(viewport_size.y - 110.0, target_center.y + 230.0))
	flyer.global_position = start_center - flyer.size * 0.5
	var arc_control := (start_center + target_center) * 0.5 + Vector2(0, -190)
	var flight := create_tween().set_parallel(true)
	flight.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flight.tween_method(func(progress: float) -> void:
		var point := _quadratic_bezier(start_center, arc_control, target_center, progress)
		flyer.global_position = point - flyer.size * 0.5
	, 0.0, 1.0, 0.72)
	flight.tween_property(flyer, "rotation", -0.12, 0.28)
	flight.tween_property(flyer, "rotation", 0.08, 0.44).set_delay(0.28)
	flight.tween_property(flyer, "scale", Vector2(1.08, 1.08), 0.36)
	flight.tween_property(flyer, "scale", Vector2.ONE, 0.36).set_delay(0.36)
	await flight.finished
	_cells[target_index].play_light(Color("ffd783"))
	_spawn_effect_ring(target_center, Color("ffd783"), 16.0, 88.0, 0.28)
	return flyer


func _fly_red_bird_away(flyer: TextureRect, target_index: int) -> void:
	var start_center := _cell_center(target_index)
	var exit_center := Vector2(-180, maxf(start_center.y - 260.0, 80.0))
	var arc_control := (start_center + exit_center) * 0.5 + Vector2(0, -150)
	var departure := create_tween().set_parallel(true)
	departure.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	departure.tween_method(func(progress: float) -> void:
		var point := _quadratic_bezier(start_center, arc_control, exit_center, progress)
		flyer.global_position = point - flyer.size * 0.5
	, 0.0, 1.0, 0.52)
	departure.tween_property(flyer, "rotation", -0.18, 0.52)
	departure.tween_property(flyer, "modulate:a", 0.0, 0.16).set_delay(0.36)
	await departure.finished
	flyer.queue_free()


func _quadratic_bezier(start: Vector2, control: Vector2, finish: Vector2, progress: float) -> Vector2:
	var inverse := 1.0 - progress
	return start * inverse * inverse + control * 2.0 * inverse * progress + finish * progress * progress


func _set_board_interactable(value: bool) -> void:
	for cell in _cells:
		cell.set_interactable(value)


func _item_texture(item: MinesweeperBoard.ItemType) -> Texture2D:
	match item:
		MinesweeperBoard.ItemType.LANTERN:
			return LANTERN_TEXTURE
		MinesweeperBoard.ItemType.COMPASS:
			return COMPASS_TEXTURE
		MinesweeperBoard.ItemType.ORBITAL_STRIKE:
			return ORBITAL_STRIKE_TEXTURE
		MinesweeperBoard.ItemType.SUPER_LUCK:
			return SUPER_LUCK_TEXTURE
		MinesweeperBoard.ItemType.MEDICAL_KIT:
			return MEDICAL_KIT_TEXTURE
		MinesweeperBoard.ItemType.XRAY:
			return XRAY_TEXTURE
		MinesweeperBoard.ItemType.CHAIN:
			return CHAIN_TEXTURE
		MinesweeperBoard.ItemType.ENLARGE:
			return ENLARGE_TEXTURE
		MinesweeperBoard.ItemType.DETECT:
			return DETECT_TEXTURE
	return null


func _monster_texture(core_index: int) -> Texture2D:
	return MONSTER_BIG_TEXTURE if _board.monster_peripheral_count(core_index) == 8 else MONSTER_SMALL_TEXTURE


## Settlement shows what every cell was hiding. Cells whose card was already
## blown away by a confirmed mark keep their crater instead of growing a new one.
func _settle_cell(
	index: int,
	content: Texture2D,
	kind: MineCell.ContentKind,
	content_span: int = 1,
	number_value: int = 0,
	fault_plate: Texture2D = null
) -> void:
	var cell := _cells[index]
	var sealed := cell.is_flag_sealed()
	cell.set_ground_texture(_ground_tile(index, true))
	if sealed:
		cell.display_revealed_in_crater(content, kind, content_span, number_value, fault_plate)
	else:
		cell.display_revealed(content, kind, false, content_span, number_value, fault_plate)


func _finish_game() -> void:
	if _game_finish_started:
		return
	_game_finish_started = true
	_enlarge_click_invincible = false
	_end_guided_tutorial()
	if _tutorial_skip_button != null:
		_tutorial_skip_button.set_available(false)
	if _regular_skip_control != null:
		_regular_skip_control.set_available(false)
	if _super_luck_mode_active or _super_luck_settling:
		_super_luck_mode_generation += 1
		_super_luck_mode_active = false
		_super_luck_settling = false
		_super_luck_clicks_remaining = 0
		_clear_super_luck_pending_borders()
		_super_luck_deferred_indices.clear()
		_super_luck_deferred_lookup.clear()
		_invincible_was_active = false
		for bird in _super_luck_other_birds():
			bird.reset_to_idle()
		_apply_bird_unlock_visibility()
	_started = false
	_resolving = false
	_restart_button.disabled = false
	for index in range(_cells.size()):
		_cells[index].set_interactable(false)
		if _board.is_monster_core(index) and _defeated_mines.has(index):
			var content_span := 3 if _board.monster_peripheral_count(index) == 8 else 1
			_settle_cell(
				index,
				_monster_texture(index),
				MineCell.ContentKind.TRIGGERED,
				content_span,
				0,
				TRIGGERED_MINE_TEXTURE
			)
		elif _board.is_monster_core(index):
			var content_span := 3 if _board.monster_peripheral_count(index) == 8 else 1
			if _board.state_at(index) == MinesweeperBoard.CellState.FLAGGED:
				# 正确标记：结算时仍是雷图 + 绿勾，不要退回成普通怪物立绘。
				_settle_cell(
					index,
					_monster_texture(index),
					MineCell.ContentKind.TRIGGERED,
					content_span,
					0,
					CORRECT_MARK_TEXTURE
				)
			else:
				_settle_cell(index, _monster_texture(index), MineCell.ContentKind.MONSTER, content_span)
		elif (
			_board.state_at(index) == MinesweeperBoard.CellState.FLAGGED
			and not _board.is_monster_core(index)
		):
			var number_value := _board.adjacent_mines(index)
			var kind := (
				MineCell.ContentKind.NUMBER if number_value > 0 else MineCell.ContentKind.EMPTY
			)
			_settle_cell(index, null, kind, 1, number_value, TRIGGERED_MINE_TEXTURE)
	if _player_hp <= 0:
		_board.won = false
		_status_label.text = "生命归零，旅程结束。"
		_status_label.add_theme_color_override("font_color", COLOR_DANGER)
	elif _round_is_won():
		_status_label.text = "雷区清理完成！\n干得漂亮。"
		_status_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		_mine_label.text = "000"
	else:
		_status_label.text = "轰！挖到了地雷。\n再试一次吧。"
		_status_label.add_theme_color_override("font_color", COLOR_DANGER)
	if _is_duel():
		# 对战不走单机的解锁演出／关卡账单／存档续关，直接进对战局的结算。
		_finish_duel_round()
		return
	await get_tree().create_timer(0.55).timeout
	if _is_custom():
		# 自定义局不进解锁演出。赢了且关卡包还有下一张图，就照单机那套走账单 → 商店 →
		# 下一张；否则（打完最后一张，或者输了）弹结果卡：再来一局／返回编辑／回标题。
		var custom_won := _board.won and _player_hp > 0
		var custom_total := CustomLevel.map_count(_custom_level)
		if custom_won and _custom_map_index < custom_total - 1:
			var custom_flagged := _correctly_flagged_mines()
			_cash_out_active_combo()
			var custom_seconds := int(_elapsed)
			var custom_time_bonus := _award_time_bonus()
			if not _gold_rewarded_this_run:
				_gold += custom_flagged + _night_master_fish_count + LEVEL_CLEAR_GOLD
				_gold_rewarded_this_run = true
				_refresh_gold_display()
			await _level_bill.present(
				_custom_map_index + 1,
				custom_flagged,
				_night_master_fish_count,
				_combo_bonus_gold,
				LEVEL_CLEAR_GOLD,
				_gold,
				custom_seconds,
				custom_time_bonus,
				0,
				0,
				false
			)
			_custom_map_index += 1
			_show_shop()
			return
		if _custom_editor != null:
			_custom_editor.present_result(
				custom_won,
				_correctly_flagged_mines(),
				_board.mine_count,
				_custom_map_index + 1,
				custom_total
			)
		return
	if _player_hp <= 0 or not _round_is_won():
		_game_over_overlay.present(_run_number)
		return
	await _victory_banner.present(_run_number)
	if _run_number == 1:
		_night_heron_unlocked = true
		_lantern_bonus += 1
		_apply_bird_unlock_visibility()
		await _night_heron_unlock.present()
		_start_game()
		return
	if _run_number == 2:
		_red_bird_unlocked = true
		_compass_bonus += 1
		_apply_bird_unlock_visibility()
		await _redstart_unlock.present()
		_start_game()
		return
	if _run_number == 3:
		_attacker_bird_unlocked = true
		_orbital_strike_bonus += 1
		_apply_bird_unlock_visibility()
		await _attacker_unlock.present()
		_start_game()
		return
	if _run_number == 4:
		_lucky_bird_unlocked = true
		_super_luck_bonus += 1
		_apply_bird_unlock_visibility()
		await _kestrel_unlock.present()
		_start_game()
		return
	if _run_number == TUTORIAL_LEVEL_COUNT - 3:
		# 第 5 盘：送长尾山雀。它的道具每关默认自带一张，所以不再另加强化。
		_tit_bird_unlocked = true
		_apply_bird_unlock_visibility()
		await _tit_unlock.present()
		_start_game()
		return
	if _run_number == TUTORIAL_LEVEL_COUNT - 2:
		# 第 6 盘：送灰喜鹊。它接手连携，靠棋盘上现成的连携雷组干活，不用另加强化。
		_magpie_bird_unlocked = true
		_apply_bird_unlock_visibility()
		await _magpie_unlock.present()
		_start_game()
		return
	if _run_number == TUTORIAL_LEVEL_COUNT - 1:
		# 第 7 盘：送小嘴乌鸦。它接手透视，每关默认自带一张，所以不再另加强化。
		_crow_bird_unlocked = true
		_apply_bird_unlock_visibility()
		await _crow_unlock.present()
		_start_game()
		return
	if _run_number == TUTORIAL_LEVEL_COUNT:
		# 教学收尾：送斑鸠。它接手治愈，每关默认自带一张，所以不再另加强化；
		# 演出完照常走账单 / 通关流程，这一盘也是教学关的最后一盘。
		_dove_bird_unlocked = true
		_apply_bird_unlock_visibility()
		await _dove_unlock.present()
	var flagged_mines := _correctly_flagged_mines()
	_cash_out_active_combo()
	_bank_endless_round()
	var seconds_used := int(_elapsed)
	# 无尽关的账单印排雷那一行，用时奖励在那边恒为 0（口径在 ScoreComboTracker）。
	var mine_tally := _endless_board_mine_points() if _is_endless_stage() else [0, 0]
	var time_bonus := _award_time_bonus()
	if not _gold_rewarded_this_run:
		_gold += flagged_mines + _night_master_fish_count + LEVEL_CLEAR_GOLD
		_gold_rewarded_this_run = true
		_refresh_gold_display()
	_resume_level = _run_number + 1
	_save_progress()
	await _level_bill.present(
		_run_number,
		flagged_mines,
		_night_master_fish_count,
		_combo_bonus_gold,
		LEVEL_CLEAR_GOLD,
		_gold,
		seconds_used,
		time_bonus,
		int(mine_tally[0]),
		int(mine_tally[1]),
		_is_endless_stage()
	)
	# 到点叫停：本关打满目标盘数就是通关，不再进商店、不再往下发盘，回世界地图
	# （FEAT-002 共识 1）。没打满则照旧走商店 → 下一盘。
	if _stage_complete():
		await _on_stage_cleared()
		return
	_show_shop()


## 「我们注意到／玩到这里／应该换首音乐／请您欣赏」，然后把制作人名单当点唱机拉
## 起来，右边挂一个大得离谱的【继续玩】等玩家听够。
func _play_music_break() -> void:
	if _music_break_notice != null:
		await _music_break_notice.present()
	if _credits_screen == null:
		return
	_bgm_player.stream_paused = true
	_credits_screen.present(true)
	await _credits_screen.continue_requested
	await _credits_screen.dismiss()
	_bgm_player.stream_paused = false


## 这一盘标对的雷数。开过奖励盘时，旧盘那几笔存在 `_banked_flagged_mines` 里，
## 这里要一并算上——`_board` 已经换成奖励盘了，只数它会把之前的战果抹掉。
func _correctly_flagged_mines() -> int:
	var total := _banked_flagged_mines
	for index in range(_board.width * _board.height):
		if _board.is_monster_core(index) and _board.state_at(index) == MinesweeperBoard.CellState.FLAGGED:
			total += 1
	return total


func _show_shop() -> void:
	var result_template := "第 %d 局清扫完成" if _round_is_won() else "第 %d 局遭遇地雷"
	var result := result_template % _run_number
	if _is_custom():
		# 自定义包里"第几局"该按包内图序说，`_run_number` 是全局盘序，玩家看不懂。
		var custom_template := "第 %d 张清扫完成" if _board.won else "第 %d 张遭遇地雷"
		result = custom_template % _custom_map_index
	var progress := "夜鹭 %d（随机 %d）｜红尾水鸲 %d（标记 %d）｜啄木鸟 %d（%s）｜红隼 %d（无敌 %d）｜小嘴乌鸦 %d｜灰喜鹊 %d｜长尾山雀 %d｜回血 +%d｜生命上限 %d" % [
		_lantern_bonus,
		1 + _lantern_target_bonus,
		_compass_bonus,
		1 + _compass_mark_bonus,
		_orbital_strike_bonus,
		"十字" if _orbital_cross_unlocked else "单线",
		_super_luck_bonus,
		SUPER_LUCK_CLICKS_PER_ITEM + _super_luck_click_bonus,
		_xray_bonus,
		_chain_bonus,
		_enlarge_bonus,
		1 + _healing_power_bonus,
		_player_max_hp,
	]
	_sync_shop_offer_limits()
	_pending_slot_offer = -1
	_sync_shop_slots()
	_shop_layer.set_offer_prices(_offer_price_table())
	_shop_layer.present(result, progress, _gold, SHOP_ITEM_COST)


func _return_to_main_menu() -> void:
	_leave_duel()
	if _custom_editor != null:
		_custom_editor.dismiss()
	# This path is also available during an active normal level. Invalidate every
	# non-blocking gameplay presentation before rebuilding the title screen, so
	# a late flyover or queued bird callback cannot touch the discarded board.
	_hitstop_generation += 1
	Engine.time_scale = 1.0
	_cancel_board_shake()
	_clear_inference_highlights()
	_clear_inference_hover_preview()
	_clear_effect_preview()
	_super_luck_mode_generation += 1
	_super_luck_mode_active = false
	_super_luck_settling = false
	_super_luck_clicks_remaining = 0
	_clear_super_luck_pending_borders()
	_super_luck_deferred_indices.clear()
	_super_luck_deferred_lookup.clear()
	_pending_bird_departures.clear()
	_bird_departure_generation += 1
	_bird_departure_dispatch_running = false
	_queued_bird_event_counts.clear()
	_prelaunched_item_indices.clear()
	_item_queue_dispatching = false
	_active_item_settlements = 0
	if _effects_layer != null:
		for effect in _effects_layer.get_children():
			effect.queue_free()
	_shop_layer.visible = false
	_wrong_flag_damage_guide_shown = false
	if _wrong_flag_guide_banner != null:
		_wrong_flag_guide_banner.hide_immediately()
	_night_master_fish_guide_shown = false
	if _night_master_fish_guide_banner != null:
		_night_master_fish_guide_banner.hide_immediately()
	if _stage_progress_banner != null:
		_stage_progress_banner.hide_immediately()
	if _round_intro_banner != null:
		_round_intro_banner.hide_immediately()
	if _leaderboard_panel != null:
		_leaderboard_panel.hide_immediately()
	if _tutorial_skip_button != null:
		_tutorial_skip_button.set_available(false)
	if _tutorial_guide != null:
		_tutorial_guide.visible = false
	_end_guided_tutorial()
	if _regular_skip_control != null:
		_regular_skip_control.set_available(false)
	_victory_banner.visible = false
	_level_bill.visible = false
	_game_over_overlay.visible = false
	_night_heron_unlock.visible = false
	_redstart_unlock.visible = false
	_attacker_unlock.visible = false
	_kestrel_unlock.visible = false
	_tit_unlock.visible = false
	for child in _grid.get_children():
		child.queue_free()
	_cells.clear()
	# 回到标题页等于回到「第一关还没开始」，棋盘和信息 UI 要跟着一起收走。
	_hide_board_interface()
	_hide_world_map()
	_reset_run_state()
	# 成就是跨关卡的账，只在"回标题页"这条路上清空后重读——**不能**放进
	# `_reset_run_state()`，否则每次进关都会把成就一起抹掉。
	_unlocked_achievements.clear()
	if _achievements_screen != null:
		for entry in AchievementCatalogData.ENTRIES:
			_achievements_screen.set_unlocked(str(entry["id"]), false)
	_music_break_played = false
	_intro_played = false
	_load_saved_progress()
	_apply_bird_unlock_visibility()
	if _start_screen == null:
		_build_start_screen()
	else:
		_refresh_title_save_state()
		_refresh_achievement_banner()


## 盘外的那几笔账：推图战绩、每关最高分、无尽记录、上榜昵称、续局槽。它们活得比一
## 轮长，所以 [method _reset_run_state] 故意不碰——但「盘上没有存档」必须等于「这几笔账
## 也是空的」，否则「清除存档」删完文件，内存里的战绩还在，下一次落盘又把它们原样写
## 回来，地图上的 ✓ 和「继续游戏」一个都没少。
func _reset_persistent_progress() -> void:
	_cleared_stages.clear()
	_stage_high_scores.clear()
	_endless_best_round = 0
	_leaderboard_name = ""
	_resume_stage_id = ""
	_resume_level = 1
	_run_number = 0
	_stage_round = 0
	_music_break_played = false
	_intro_played = false


## 把一局的全部 run 级状态推回起点。回标题页与"进一个全新的关卡"共用这一段——
## 关卡的定义就是"一整局从头开始的肉鸽"（FEAT-002 共识 1），两者要清的东西完全一样。
##
## 刻意**不动**的四样：成就（跨关卡）、`_cleared_stages`（推图战绩）、
## `_music_break_played`（已落盘，清了就会每关重放插播）、`_endless_best_round`（无尽关记录）。
func _reset_run_state() -> void:
	_player_max_hp = PLAYER_START_MAX_HP
	_player_hp = PLAYER_START_MAX_HP
	_gold = 0
	_night_master_fish_count = 0
	_tutorial_first_reveal_pending = false
	_tutorial_night_heron_edge_index = -1
	_woodpecker_demo_pending = false
	_woodpecker_demo_index = -1
	_kestrel_demo_pending = false
	_kestrel_demo_index = -1
	_tit_demo_pending = false
	_tit_demo_index = -1
	_crow_demo_pending = false
	_crow_demo_index = -1
	_dove_demo_pending = false
	_dove_demo_index = -1
	_run_number = 0
	_resume_level = 1
	_stage_id = ""
	_stage_target_round = 0
	_stage_round = 0
	_custom_level = {}
	_run_seed = 0
	_blue_bird_unlocked = true
	_red_bird_unlocked = false
	_night_heron_unlocked = false
	_attacker_bird_unlocked = false
	_lucky_bird_unlocked = false
	_tit_bird_unlocked = false
	_magpie_bird_unlocked = false
	_crow_bird_unlocked = false
	_dove_bird_unlocked = false
	_lantern_bonus = 0
	_compass_bonus = 0
	_orbital_strike_bonus = 0
	_super_luck_bonus = 0
	_medical_kit_bonus = 0
	_healing_power_bonus = 0
	_super_luck_click_bonus = 0
	_orbital_cross_unlocked = false
	_offer_purchase_counts.clear()
	_reset_endless_slots()
	_shop_layer.set_offer_owned(ShopOffer.ORBITAL_CROSS, false)
	_lantern_target_bonus = 0
	_compass_mark_bonus = 0
	_xray_bonus = 0
	_chain_bonus = 0
	_enlarge_bonus = 0
	_sync_shop_offer_limits()
	_shop_layer.set_offer_prices(_offer_price_table())
	_enlarge_click_invincible = false
	_game_finish_started = false
	_started = false
	_resolving = false
	_reset_score_combo_run()
	_refresh_health_bar()
	for bird in [_blue_bird, _red_bird, _black_bird, _attacker_bird, _eg_bird, _tit_bird, _magpie_bird, _crow_bird, _dove_bird]:
		bird.reset_to_idle()
	_apply_bird_unlock_visibility()
	_refresh_gold_display()


func _board_field_style() -> StyleBoxFlat:
	# The map tiles define the complete board silhouette; no extra backing plate.
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_content_margin_all(0.0)
	return style


func _bird_board_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("5a351d70")
	style.border_color = Color("4a2c1db8")
	style.set_border_width_all(5)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(12.0)
	style.shadow_color = Color("2f1c1266")
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 7)
	return style


func _bird_hud_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f7e9cce8")
	style.border_color = Color("795438cc")
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(10.0)
	style.shadow_color = Color("35221555")
	style.shadow_size = 9
	style.shadow_offset = Vector2(0, 5)
	return style


func _make_counter(parent: Control, caption: String, value: String) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 76)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _hud_counter_style())
	parent.add_child(panel)
	var stack := HBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_label.add_theme_color_override("font_color", COLOR_HUD_MUTED)
	caption_label.add_theme_font_size_override("font_size", 17)
	stack.add_child(caption_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", COLOR_HUD_INK)
	value_label.add_theme_font_size_override("font_size", 27)
	stack.add_child(value_label)
	return value_label


func _hud_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_content_margin_all(12.0)
	return style


func _hud_counter_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ead9b9c4")
	style.border_color = Color("a889574c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14.0)
	return style


func _panel_style(color: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(float(margin))
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10.0)
	return style


# --- 世界地图 / 关卡 (FEAT-002 · WorldMap) ---


func _is_stage_run() -> bool:
	return _stage_id != ""


## 当前在打的是无尽关（第 7 关）：盘随机、越打越难、没有目标盘数，只有血量归零才收场。
func _is_endless_stage() -> bool:
	return _is_stage_run() and StageTable.is_endless(_stage_id)


## 无尽关打赢一盘：刷新「最远第几盘」。只记打赢的盘，死在哪一盘不算；紧随其后的
## `_save_progress()` 会把它落盘。
func _bank_endless_round() -> void:
	if not _is_endless_stage():
		return
	if _stage_round > _endless_best_round:
		_endless_best_round = _stage_round


## 陈列柜要显示的「最远第几盘」：目前只有无尽关有这项记录。
func _best_rounds_for_map() -> Dictionary:
	return {StageTable.ENDLESS_STAGE_ID: _endless_best_round}


func _leaderboard_blocks_stage_entry() -> bool:
	return _leaderboard_panel != null and _leaderboard_panel.visible


## 「到点叫停」的判据单独成一个谓词，好让测试直接在边界值上打它——胜利结算那条路径有
## 一长串 await，靠真打完一整关来验证这一条既慢又脆。
func _stage_complete() -> bool:
	# 无尽关没有目标盘数，永远打不「满」：只有血量归零才收场。
	if _is_endless_stage():
		return false
	return _is_stage_run() and _stage_round >= _stage_target_round


## 地图场景**懒加载**：标题页不该为 3D 内容付启动成本（项目约束「首屏避免加载整局
## 内容」）。第一次真要看地图时才 instantiate，之后一直留着 show/hide。
func _build_world_map() -> void:
	if _world_map != null:
		return
	var scene := load("res://scenes/stage_cabinet.tscn") as PackedScene
	if scene == null:
		push_warning("陈列柜场景缺失，无法选关")
		return
	_world_map = scene.instantiate() as StageCabinet
	add_child(_world_map)
	_world_map.stage_selected.connect(_on_world_map_stage_selected)
	_world_map.title_requested.connect(_on_world_map_title_requested)
	_world_map.resume_requested.connect(_on_world_map_resume_requested)
	_world_map.abandon_requested.connect(_on_world_map_abandon_requested)
	_world_map.leaderboard_requested.connect(_on_world_map_leaderboard_requested)
	_world_map.all_leaderboards_requested.connect(_on_world_map_all_leaderboards_requested)
	_world_map.easter_egg_triggered.connect(_unlock_achievement)
	_world_map.visible = false


## 这一屏的 2D 布景。地图开着时必须整组收走（3D 会被 2D CanvasItem 盖住）。
## 碎石草木、棋盘台、羊皮纸底保持隐藏；天空、两侧林叶与中央大树进关要亮。
const SCENERY_ALWAYS_HIDDEN := [
	"Backdrop", "BoardPlatform", "Scenery",
]
const SCENERY_PLAY_NODES := [
	"Background", "SideFoliageLeft", "SideFoliageRight", "CentralTreeBackground",
	"BlueBirdPerch", "RedBirdPerch", "BlackBirdPerch", "AttackerBirdPerch", "EgBirdPerch",
	"TitBirdPerch", "MagpieBirdPerch", "CrowBirdPerch", "DoveBirdPerch",
]


func _set_scenery_visible(value: bool) -> void:
	for node_name in SCENERY_ALWAYS_HIDDEN:
		var hidden := get_node_or_null(node_name) as CanvasItem
		if hidden != null:
			hidden.visible = false
	for node_name in SCENERY_PLAY_NODES:
		var node := get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.visible = value
	if value:
		# 鸟架有自己的解锁显隐规则，统一开完之后要交还给它。
		_apply_bird_unlock_visibility()


func _show_world_map() -> void:
	_build_world_map()
	if _world_map == null:
		# 地图起不来时不能把玩家卡在空屏上，退回原来的直进第一关。
		_enter_stage(String(StageTable.STAGES[0]["id"]), _resume_stage_id != "")
		return
	_hide_board_interface()
	_set_scenery_visible(false)
	_shop_layer.visible = false
	_world_map.present(_cleared_stages, _resume_stage_id, _stage_round + 1, _stage_high_scores, _best_rounds_for_map())


func _hide_world_map() -> void:
	if _world_map != null:
		_world_map.dismiss()
	_set_scenery_visible(true)


func _on_world_map_title_requested() -> void:
	_return_to_main_menu()


func _on_world_map_stage_selected(stage_id: String) -> void:
	_enter_stage(stage_id, false)


func _on_world_map_resume_requested() -> void:
	if _resume_stage_id == "":
		return
	_enter_stage(_resume_stage_id, true)


## 地图上确认了「放弃当前进度」。只清续局槽，推图战绩留着。
func _on_world_map_abandon_requested() -> void:
	_resume_stage_id = ""
	_stage_round = 0
	_reset_run_state()
	_save_progress()
	if _world_map != null:
		_world_map.present(_cleared_stages, _resume_stage_id, 0, _stage_high_scores, _best_rounds_for_map())


## 进入一个关卡。`resume` 为真时沿用已经读进内存的血量/金币/强化，从上次那一盘的开头
## 接着打；为假时整局推回起点。
func _enter_stage(stage_id: String, resume: bool) -> void:
	if _map_settle_lock or _leaderboard_blocks_stage_entry():
		return
	var stage := StageTable.stage(stage_id)
	if stage.is_empty():
		push_warning("关卡表里没有 %s" % stage_id)
		return
	if not StageTable.is_stage_unlocked(stage_id, _cleared_stages):
		return
	_hide_world_map()
	if not resume:
		_reset_run_state()
		_prepare_stage_run(stage)
	else:
		# 续局：`_load_saved_progress` 已经把 `_run_number` 与 `_stage_round` 退了一格，
		# `_start_game` 会把两者加回去，于是重建的正是离开时那一盘的开头。
		_stage_id = stage_id
		_stage_target_round = int(stage["target_round"])
		# 鸟窝是数值位的唯一真相：续无尽关时以存档里的窝为准重算一遍。
		_sync_bonuses_from_slots()
	_resume_stage_id = stage_id
	_apply_score_mode()
	_start_game()


## 关卡的起手状态。血量/金币走单机常量——每关起跑线完全相同，唯一变量是目标盘数
## （FEAT-002 共识 1），所以这里没有任何按关卡取值的数值。
##
## 关键分歧在教程：只有第一关带那 8 盘教学（`teaches`），其余关卡从
## `TUTORIAL_LEVEL_COUNT` 起跳过教学段。跳过就拿不到教学那 8 段解锁演出送的鸟和强化
## （main.gd 的胜利分支里 `_run_number == 1..8` 各送一只鸟，前四只还各带 1 点对应强化），所以必须
## 在这里补发——不补的话整关只有蓝鸟可用。这一条沿用 `_prepare_duel_run()` 的先例。
func _prepare_stage_run(stage: Dictionary) -> void:
	_stage_id = String(stage["id"])
	_stage_target_round = int(stage["target_round"])
	_stage_round = 0
	if bool(stage.get("teaches", false)):
		_run_number = 0
		return
	_run_number = TUTORIAL_LEVEL_COUNT
	_blue_bird_unlocked = true
	_red_bird_unlocked = true
	_night_heron_unlocked = true
	_attacker_bird_unlocked = true
	_lucky_bird_unlocked = true
	_tit_bird_unlocked = true
	_magpie_bird_unlocked = true
	_crow_bird_unlocked = true
	_dove_bird_unlocked = true
	_lantern_bonus = 1
	_compass_bonus = 1
	_orbital_strike_bonus = 1
	_super_luck_bonus = 1
	# 无尽关：这四只直接住进鸟窝，往后的增减一律经由窝。
	if _is_slot_shop():
		_seed_endless_slots()
		if endless_debug_loadout:
			_apply_endless_debug_loadout()
	_apply_bird_unlock_visibility()
	_refresh_health_bar()
	_refresh_gold_display()


## 打满目标盘数了。记账、清续局槽、回地图。
func _on_stage_cleared() -> void:
	_map_settle_lock = true
	_run_boot_generation += 1
	var offer_stage := _stage_id
	var offer_score := int(_score_combo.score) if _score_combo != null else 0
	if not _cleared_stages.has(_stage_id):
		_cleared_stages.append(_stage_id)
	_resume_stage_id = ""
	_stage_round = 0
	_stage_id = ""
	_stage_target_round = 0
	# 盘序也要回到 1。否则存档里留着"打到第 5 盘"，下次回标题时读取侧的兜底规则会据此
	# 又推出一个续局槽，刚通关的那一关会诡异地变回「进行中」。
	_run_number = 0
	_resume_level = 1
	_save_progress()
	_return_to_world_map()
	await _present_clear_leaderboard(offer_stage, offer_score)
	# 上榜/跳过点可能同时点穿地图、误开一关。榜关掉后无条件钉回选关。
	_stage_id = ""
	_stage_target_round = 0
	_stage_round = 0
	_resume_stage_id = ""
	_run_number = 0
	_resume_level = 1
	_started = false
	_return_to_world_map()
	_save_progress()
	# 吞掉关榜同一帧可能落到地格上的残留点击，再允许进关。
	await get_tree().process_frame
	_map_settle_lock = false


## 从关卡里退回地图。棋盘和一切在飞的演出都要收干净。
## 中途暂离（未死）时 run 数值与续局槽由调用方保留；血量归零则在 `_on_game_over_return` 里先清槽。
func _return_to_world_map() -> void:
	_clear_board_presentation()
	_show_world_map()


## 拆掉棋盘和一切在飞的演出，但不决定下一步去哪——回地图和回自定义编辑器共用。
func _clear_board_presentation() -> void:
	_run_boot_generation += 1
	_close_bonus_board(true)
	_hitstop_generation += 1
	Engine.time_scale = 1.0
	_cancel_board_shake()
	_clear_inference_highlights()
	_clear_inference_hover_preview()
	_clear_effect_preview()
	_super_luck_mode_generation += 1
	_super_luck_mode_active = false
	_super_luck_settling = false
	_super_luck_clicks_remaining = 0
	_clear_super_luck_pending_borders()
	_super_luck_deferred_indices.clear()
	_super_luck_deferred_lookup.clear()
	_pending_bird_departures.clear()
	_bird_departure_generation += 1
	_bird_departure_dispatch_running = false
	_queued_bird_event_counts.clear()
	_prelaunched_item_indices.clear()
	_item_queue_dispatching = false
	_active_item_settlements = 0
	if _effects_layer != null:
		for effect in _effects_layer.get_children():
			effect.queue_free()
	_shop_layer.visible = false
	if _wrong_flag_guide_banner != null:
		_wrong_flag_guide_banner.hide_immediately()
	if _night_master_fish_guide_banner != null:
		_night_master_fish_guide_banner.hide_immediately()
	if _stage_progress_banner != null:
		_stage_progress_banner.hide_immediately()
	if _round_intro_banner != null:
		_round_intro_banner.hide_immediately()
	# 通关榜还开着时不要掐掉，否则 hide_immediately 会把上榜判成跳过。
	if _leaderboard_panel != null and not (_map_settle_lock and _leaderboard_panel.visible):
		_leaderboard_panel.hide_immediately()
	if _tutorial_skip_button != null:
		_tutorial_skip_button.set_available(false)
	if _tutorial_guide != null:
		_tutorial_guide.visible = false
	_end_guided_tutorial()
	if _regular_skip_control != null:
		_regular_skip_control.set_available(false)
	_victory_banner.visible = false
	_level_bill.visible = false
	_game_over_overlay.visible = false
	_night_heron_unlock.visible = false
	_redstart_unlock.visible = false
	_attacker_unlock.visible = false
	_kestrel_unlock.visible = false
	_tit_unlock.visible = false
	for child in _grid.get_children():
		child.queue_free()
	_cells.clear()
	_started = false
	_resolving = false
	_game_finish_started = false


## 结算界面的「返回」：在关卡里就回地图，否则（对战/异常）回标题页。
## 血量归零算本局作废——清掉续局槽并复位 run，避免回地图后再点别的关还弹「放弃进度」。
func _on_game_over_return() -> void:
	if _is_stage_run():
		# 无尽关只有倒下一种收场：这一局的累计分在这里上榜，和其他关通关时一样。
		var fallen_endless := _is_endless_stage() and _player_hp <= 0
		var fallen_stage := _stage_id
		var fallen_round := _stage_round
		var fallen_score := int(_score_combo.score) if _score_combo != null else 0
		if _player_hp <= 0:
			_resume_stage_id = ""
			_reset_run_state()
			_save_progress()
		_return_to_world_map()
		if fallen_endless:
			await _present_endless_fall(fallen_stage, fallen_round, fallen_score)
		return
	_return_to_main_menu()


## 无尽关倒下：弹和通关结算同一张阻塞榜页，标题改成「止步第 N 盘」。榜开着时结算锁挡住
## 点穿进关，关掉后再放开，与 `_on_stage_cleared` 同一套收尾。
func _present_endless_fall(stage_id: String, fallen_round: int, score: int) -> void:
	var stage_name := String(StageTable.stage(stage_id).get("name", stage_id))
	_map_settle_lock = true
	await _present_clear_leaderboard(
		stage_id, score, "「%s」止步第 %d 盘" % [stage_name, maxi(fallen_round, 1)]
	)
	# 吞掉关榜同一帧可能落到展品上的残留点击，再允许进关。
	await get_tree().process_frame
	_map_settle_lock = false


func _on_world_map_leaderboard_requested(stage_id: String) -> void:
	_open_stage_leaderboard(stage_id)


func _on_world_map_all_leaderboards_requested() -> void:
	if _leaderboard_panel == null:
		return
	_sync_leaderboard_local_context()
	_leaderboard_panel.present_all()


## 通关后弹出阻塞式排行页：中间是榜（可能仍在加载）；可随时跳过，加载完才能上榜。
## `title` 非空时换掉「通关结算」标题（无尽关倒下时用）。
func _present_clear_leaderboard(stage_id: String, score: int, title: String = "") -> void:
	if stage_id == "" or _is_duel() or _leaderboard_panel == null:
		return
	if not StageTable.has_stage(stage_id):
		return
	# 教学关通关不弹结算榜：第一次打通的人正要去看地图，不该先被一张「上榜吗」拦一道。
	if not StageTable.has_leaderboard(stage_id):
		return
	var stage := StageTable.stage(stage_id)
	var stage_name := String(stage.get("name", stage_id))
	var result: Dictionary = await _leaderboard_panel.present_after_clear(
		stage_id, stage_name, score, _leaderboard_name, title
	)
	var player_name := LeaderboardApiScript.normalize_name(String(result.get("name", "")))
	if player_name != "":
		_leaderboard_name = player_name
		_save_progress()
	if bool(result.get("submitted", false)) and _status_label != null:
		var rank := int(result.get("rank", 0))
		_status_label.text = "上榜成功：%s · 第 %d 名" % [player_name, rank]


## 浏览页的「上传我的最高分」拿的就是这份本地记录，所以每次开榜前都要灌一次新的。
func _sync_leaderboard_local_context() -> void:
	if _leaderboard_panel == null:
		return
	_leaderboard_panel.set_local_context(_stage_high_scores, _leaderboard_name)


## 在浏览页里补传成功：把用过的昵称记进存档，下次预填就是它。
func _on_leaderboard_name_remembered(player_name: String) -> void:
	var cleaned := LeaderboardApiScript.normalize_name(player_name)
	if cleaned == "" or cleaned == _leaderboard_name:
		return
	_leaderboard_name = cleaned
	_save_progress()


func _open_stage_leaderboard(stage_id: String, stage_name: String = "") -> void:
	if _leaderboard_panel == null or not StageTable.has_stage(stage_id):
		return
	if not StageTable.has_leaderboard(stage_id):
		return
	if stage_name == "":
		stage_name = String(StageTable.stage(stage_id).get("name", stage_id))
	_sync_leaderboard_local_context()
	_leaderboard_panel.present(stage_id, stage_name)


# --- 对战局 (FEAT-001 · Netplay) ---


func _is_duel() -> bool:
	return _duel != null and _duel.is_active()


func _build_duel() -> void:
	_duel = DuelSessionScript.new()
	_duel.name = "DuelSession"
	add_child(_duel)
	_duel.linked.connect(_on_duel_linked)
	_duel.link_lost.connect(_on_duel_link_lost)
	_duel.link_failed.connect(_on_duel_link_failed)
	_duel.round_started.connect(_on_duel_round_started)
	_duel.opponent_changed.connect(_refresh_duel_opponent)
	_duel.damage_taken.connect(_on_duel_damage_taken)
	_duel.round_frozen.connect(_on_duel_round_frozen)
	_duel.duel_finished.connect(_on_duel_finished)
	# 商店在 layer 100：对战 HUD 要压住棋盘、又不能盖住商店。
	var duel_canvas := CanvasLayer.new()
	duel_canvas.layer = 80
	add_child(duel_canvas)
	_duel_hud = DuelHudScript.new()
	_duel_hud.name = "DuelHud"
	duel_canvas.add_child(_duel_hud)
	_duel_hud.leave_pressed.connect(_on_duel_leave_pressed)
	_duel_lobby = DuelLobbyScript.new()
	_duel_lobby.name = "DuelLobby"
	add_child(_duel_lobby)
	_duel_lobby.cancelled.connect(_on_duel_lobby_cancelled)
	_duel_lobby.join_submitted.connect(_start_duel_join)


## 这一关的棋盘种子。对战下由对局种子派生，双方算出同一个值，于是长出逐格一致的
## 棋盘；单机下由本次运行的 run 种子派生，同一次运行里可复现。
func _level_seed_for_current_round() -> int:
	if _is_duel():
		return _duel.level_seed_for(_duel.round_index)
	if _run_seed == 0:
		var picker := RandomNumberGenerator.new()
		picker.randomize()
		_run_seed = picker.randi()
	var mixed := _run_seed ^ (_run_number * 0x9E3779B9)
	# 0 是 BoardModel 的哨兵值（会退回去用系统时间），得躲开。
	return mixed if mixed != 0 else 1


func _on_duel_host_requested() -> void:
	if _duel != null and _duel.is_active():
		return
	_duel_leaving = false
	_duel_play_started = false
	if _duel.host_duel() != OK:
		if _duel_lobby != null:
			_duel_lobby.present_join()
			_duel_lobby.set_error("这个房间口被占用了，请稍后再试。")
		return
	if _duel_lobby != null:
		_duel_lobby.present_host(_duel.room_code)


func _on_duel_join_requested() -> void:
	if _duel != null and _duel.is_active():
		return
	_duel_leaving = false
	_duel_play_started = false
	if _duel_lobby != null:
		_duel_lobby.present_join()


func _start_duel_join(room_code: String, address: String) -> void:
	_duel_leaving = false
	_duel_play_started = false
	if _duel.join_duel(address, -1, room_code) != OK:
		if _duel_lobby != null:
			_duel_lobby.set_error("连不上。请核对房间码和地址。")
		return
	if _duel_lobby != null:
		_duel_lobby.set_joining(_duel.room_code)


## 大厅一直盖在标题页上；真正开第一轮才拆菜单、亮对战 HUD。
func _enter_duel_play() -> void:
	if _duel_play_started:
		return
	_duel_play_started = true
	if _duel_lobby != null:
		_duel_lobby.dismiss()
	if _start_screen != null:
		var screen := _start_screen
		_start_screen = null
		screen.visible = false
		screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var parent := screen.get_parent()
		if is_instance_valid(parent):
			parent.visible = false
			parent.queue_free()
	_duel_hud.show_duel(true)
	_duel_hud.set_connection(true)
	_duel_hud.set_frozen(false, "", "")


func _on_duel_lobby_cancelled() -> void:
	_duel_leaving = true
	if _duel != null:
		_duel.leave()
	if _duel_lobby != null:
		_duel_lobby.dismiss()
	if _duel_hud != null:
		_duel_hud.show_duel(false)
	_duel_play_started = false
	_duel_leaving = false


func _on_duel_leave_pressed() -> void:
	_leave_duel()
	_return_to_main_menu()


func _on_duel_linked() -> void:
	if _duel_lobby != null and _duel_lobby.is_open():
		_duel_lobby.set_status("对手已连入，正在开局…")
		return
	_duel_hud.set_connection(true)
	_duel_hud.set_frozen(true, "对手已连入", "正在开局…")


func _on_duel_link_failed(reason: String) -> void:
	if _duel_leaving or _duel_play_started:
		return
	if _duel_lobby != null and _duel_lobby.is_open():
		_duel_lobby.set_error(reason)


func _on_duel_link_lost() -> void:
	if _duel_leaving or not _duel_play_started:
		return
	_duel_hud.set_connection(false)
	_duel_hud.set_frozen(true, "对手已断开 — 本局作废", "即将返回标题页")
	_set_board_interactable(false)
	await get_tree().create_timer(2.0).timeout
	if _duel_leaving or not _duel_play_started:
		return
	_return_to_main_menu()


func _on_duel_round_started(round_index: int) -> void:
	_enter_duel_play()
	if round_index <= 1:
		_prepare_duel_run()
	_duel_frozen = false
	_duel_pending_damage = 0
	_shop_layer.visible = false
	_duel_hud.set_frozen(false, "", "")
	_apply_duel_mine_counter_mode(true)
	_start_game()


## 对战局的起手状态。血量/金币走 DuelConfig；五只鸟的强化全部解锁（大全商店 13 项
## 都能买），但栖枝本身在分屏里藏起来，避免压住左右棋盘。关卡计数跳过整段教程。
func _prepare_duel_run() -> void:
	_player_max_hp = DuelConfig.START_HP
	_player_hp = DuelConfig.START_HP
	_gold = DuelConfig.START_GOLD
	# 对战自带一套经济：涨价次数不从上一局单机带过来，中场商店从基础价开卖。
	_offer_purchase_counts.clear()
	_blue_bird_unlocked = true
	_red_bird_unlocked = true
	_night_heron_unlocked = true
	_attacker_bird_unlocked = true
	_lucky_bird_unlocked = true
	_tit_bird_unlocked = true
	_magpie_bird_unlocked = true
	_crow_bird_unlocked = true
	_dove_bird_unlocked = true
	_run_number = TUTORIAL_LEVEL_COUNT
	# 单机的换歌插播落在第 9 关，对战打到那一轮时不该被它打断。
	_music_break_played = true
	_apply_bird_unlock_visibility()
	_refresh_health_bar()
	_refresh_gold_display()


func _tick_duel() -> void:
	_settle_duel_marks()
	_try_settle_duel_damage()
	_refresh_duel_mine_progress()
	if _shop_layer != null and _shop_layer.visible:
		_shop_layer.set_duel_countdown(_duel.intermission_seconds_left())


## 对战读数显示「已正确标出的雷 / 总雷数」，避免错旗把「剩余雷」刷成 000
## 却还没真正清盘——这是玩家以为商店不弹的常见原因。
func _apply_duel_mine_counter_mode(active: bool) -> void:
	if _mine_caption_label == null:
		return
	_mine_caption_label.text = "已标雷" if active else "剩余雷"


func _count_resolved_mines() -> int:
	if _board == null:
		return 0
	var resolved := 0
	for index in range(_board.width * _board.height):
		if not _board.is_monster_core(index):
			continue
		var state: int = _board.state_at(index)
		if (
			state == MinesweeperBoard.CellState.FLAGGED
			or state == MinesweeperBoard.CellState.REVEALED
		):
			resolved += 1
	return resolved


func _refresh_duel_mine_progress() -> void:
	if not _is_duel() or _board == null or _mine_label == null:
		return
	_mine_label.text = "%d/%d" % [_count_resolved_mines(), _board.mine_count]


## 结算棋盘刚记下的「已计分的雷」：每颗给自己 1 金、给对手 1 点伤害。
##
## 取的是 `take_scored_mine_log()` 而不是连携那条队列——两条互不相干，共用会互相
## 偷事件。所有标雷入口（右键、灯笼、罗盘、夜鹭、连携、探测）都汇进这一条，所以
## 这里不需要去 hook 任何单独的调用点。
func _settle_duel_marks() -> void:
	if _board == null:
		return
	var scored := _board.take_scored_mine_log()
	if scored.is_empty() or _duel_frozen:
		# 本轮已冻结，落后方剩下的雷不再结算（Q2 定的立即冻结）。
		return
	for _mine_index in scored:
		_gold += DuelConfig.MARK_GOLD
		_duel.report_mine_marked()
	_refresh_gold_display()
	_refresh_duel_mine_progress()
	_duel.report_state(_player_hp, _player_max_hp, _gold)


func _on_duel_damage_taken(amount: int) -> void:
	_duel_pending_damage += amount
	# 迷雾罩整片闪一下。事件源就是这条既有的 MINE_MARKED，零协议成本；闪的是整片雾
	# 而不是某一格，所以不泄漏对手在盘上的任何位置。
	if _duel_hud != null:
		_duel_hud.flash_opponent_board()


## 只有棋盘真正空下来才让伤害落地。红隼模态和连携挂起都是「回合中间态」，在那个
## 当口扣血会把在飞的结算搅乱。
func _try_settle_duel_damage() -> void:
	if _duel_pending_damage <= 0 or _duel_frozen or _game_finish_started:
		return
	if _resolving or _super_luck_mode_active or _super_luck_settling:
		return
	if _chain_flush_active:
		return
	var amount := _duel_pending_damage
	_duel_pending_damage = 0
	_break_score_combo()
	# 分屏下自身 HUD 被整体缩放过，`size` 是未缩放的局部尺寸，算出来会偏。
	var target := _health_bar.get_global_rect().get_center()
	for _step in range(amount):
		_duel_hud.play_incoming_damage(DuelConfig.MARK_DAMAGE, target)
	# 对手的伤害不吃红隼的无敌盾：那面盾的说明写的是「踩中雷不掉血」，它挡的是雷，
	# 不是对手。
	_player_hp = maxi(0, _player_hp - amount)
	_refresh_health_bar()
	if _player_status != null:
		_player_status.play_hit_feedback()
	_duel.report_state(_player_hp, _player_max_hp, _gold)
	if _player_hp <= 0 and not _game_finish_started:
		_game_finish_started = true
		_set_board_interactable(false)
		_duel.report_defeat()


func _refresh_duel_opponent() -> void:
	if _duel_hud == null or _duel == null:
		return
	var total_mines := _board.mine_count if _board != null else 0
	_duel_hud.refresh_opponent(_duel.opponent, total_mines)
	if _shop_layer != null and _shop_layer.visible:
		_shop_layer.set_duel_opponent(
			int(_duel.opponent["hp"]),
			int(_duel.opponent["max_hp"]),
			int(_duel.opponent["gold"]),
			_duel.opponent["upgrades"]
		)
		_shop_layer.set_duel_opponent_ready(_duel.opponent_ready)


## 本轮打完了：血没了就报输，清盘了就报清盘（对面收到即冻结）。
func _finish_duel_round() -> void:
	if _player_hp <= 0:
		_duel.report_defeat()
		return
	if _board.won:
		_duel.report_round_cleared()


func _on_duel_round_frozen(self_cleared: bool) -> void:
	if _duel_frozen:
		return
	_duel_frozen = true
	_duel_self_cleared = self_cleared
	_set_board_interactable(false)
	_duel_hud.set_frozen(
		true,
		"你率先清盘 — 本轮结束" if self_cleared else "对手已清盘 — 本轮结束",
		"即将进入中场商店，买强化后点「准备好了」"
	)
	await get_tree().create_timer(1.2).timeout
	if not _is_duel():
		return
	_open_duel_intermission()


func _open_duel_intermission() -> void:
	_duel_hud.set_frozen(false, "", "")
	_duel.enter_intermission()
	_sync_shop_offer_limits()
	_shop_layer.set_offer_prices(_offer_price_table())
	_shop_layer.present_full(_gold, SHOP_ITEM_COST)
	_shop_layer.set_duel_round_result(
		"第 %d 轮 — %s" % [_duel.round_index, "你率先清盘" if _duel_self_cleared else "对手率先清盘"]
	)
	_duel_hud.set_flow_tip("中场商店：双方各自购买 · 都点准备或倒计时结束进入下一轮")
	_refresh_duel_opponent()


func _on_duel_ready_pressed() -> void:
	if _is_duel():
		_duel.mark_ready()


func _on_duel_finished(self_won: bool) -> void:
	_duel_frozen = true
	_set_board_interactable(false)
	_shop_layer.visible = false
	_shop_layer.exit_duel_mode()
	_duel_hud.set_frozen(
		true,
		"对战胜利！" if self_won else "对战失败",
		"即将返回标题页"
	)
	await get_tree().create_timer(2.4).timeout
	_return_to_main_menu()


func _leave_duel() -> void:
	if _duel == null:
		return
	_duel_leaving = true
	_duel_pending_damage = 0
	_duel_frozen = false
	_duel_self_cleared = false
	_duel_play_started = false
	_apply_duel_mine_counter_mode(false)
	if _player_status != null and _player_status.has_method("set_compact_hearts"):
		_player_status.set_compact_hearts(false)
	if _duel_lobby != null:
		_duel_lobby.dismiss()
	if _duel_hud != null:
		_duel_hud.show_duel(false)
	if _shop_layer != null:
		_shop_layer.exit_duel_mode()
	_duel.leave()


## ---- 自定义模式（CustomLevel）----
## 玩家自己画地图、配道具的一局。和对战一样不写存档、不进商店、不算关卡战绩；
## 打完弹结果卡，能原配置重开、回编辑器改了再开、或回标题。

func _is_custom() -> bool:
	return not _custom_level.is_empty()


func _build_custom_editor() -> void:
	if _custom_editor != null:
		return
	_custom_editor = CustomLevelEditorScript.new()
	_custom_editor.name = "CustomLevelEditor"
	add_child(_custom_editor)
	_custom_editor.play_requested.connect(_on_custom_play_requested)
	_custom_editor.back_requested.connect(_on_custom_back_requested)
	_custom_editor.replay_requested.connect(_on_custom_replay_requested)
	_custom_editor.edit_requested.connect(_return_to_custom_editor)
	_custom_editor.exit_requested.connect(_return_to_main_menu)
	_custom_editor.publish_requested.connect(_on_custom_publish_requested)


## 标题页点「自定义」：拆菜单、亮编辑器。编辑器懒建，标题页不为它付启动成本。
func _on_custom_requested() -> void:
	if _is_duel():
		return
	_build_custom_editor()
	if _start_screen != null:
		var screen := _start_screen
		_start_screen = null
		var parent := screen.get_parent()
		if is_instance_valid(parent):
			parent.queue_free()
	_hide_board_interface()
	_custom_editor.present()


func _on_custom_back_requested() -> void:
	_return_to_main_menu()


func _on_custom_play_requested(level: Dictionary) -> void:
	if not CustomLevel.is_valid(level):
		push_warning("自定义关卡配置不合法，拒绝开局")
		return
	# 进了自定义模式就一定要有编辑器：结算时的结果卡、「返回编辑」都挂在它身上。
	# 从工坊直接开局这条路不经过标题页的自定义按钮，所以这里补一次建。
	_build_custom_editor()
	_run_boot_generation += 1
	_reset_run_state()
	_custom_level = level.duplicate(true)
	_custom_map_index = 0
	_prepare_custom_run()
	if _custom_editor != null:
		_custom_editor.dismiss()
	_start_game()


## 结果卡上的「再来一局」：同一个关卡包从第一张图重来，金币/血量/商店加成一并清干净。
## 不清的话上一局的残留会带进新一轮，多图包尤其明显（第二轮开局就带着上一轮买的东西）。
func _on_custom_replay_requested() -> void:
	if not _is_custom():
		return
	var pack: Dictionary = _custom_level.duplicate(true)
	if _custom_editor != null:
		_custom_editor.dismiss()
	_run_boot_generation += 1
	_reset_run_state()
	_custom_level = pack
	_custom_map_index = 0
	_prepare_custom_run()
	_start_game()


## 自定义局的起手状态：五只鸟全开（道具要靠鸟演出），盘序从教学段之后起跳，
## 免得踩到第 1～4 盘的教学钩子；换歌插播也不该打断。
func _prepare_custom_run() -> void:
	_run_number = TUTORIAL_LEVEL_COUNT
	_blue_bird_unlocked = true
	_red_bird_unlocked = true
	_night_heron_unlocked = true
	_attacker_bird_unlocked = true
	_lucky_bird_unlocked = true
	_tit_bird_unlocked = true
	_magpie_bird_unlocked = true
	_crow_bird_unlocked = true
	_dove_bird_unlocked = true
	# 九种初始道具全部铺进 `*_bonus`：开盘时直接拿这批数当"这张图上埋几张牌"，
	# 商店买到的加成叠在同一批变量上，于是后面几张图能吃到玩家买的东西。
	_lantern_bonus = CustomLevel.item_count(_custom_level, "lantern")
	_compass_bonus = CustomLevel.item_count(_custom_level, "compass")
	_orbital_strike_bonus = CustomLevel.item_count(_custom_level, "orbital_strike")
	_super_luck_bonus = CustomLevel.item_count(_custom_level, "super_luck")
	_medical_kit_bonus = CustomLevel.item_count(_custom_level, "medical_kit")
	_xray_bonus = CustomLevel.item_count(_custom_level, "xray")
	_chain_bonus = CustomLevel.item_count(_custom_level, "chain")
	_enlarge_bonus = CustomLevel.item_count(_custom_level, "enlarge")
	_music_break_played = true
	_apply_bird_unlock_visibility()
	_refresh_health_bar()
	_refresh_gold_display()


## ---- 创意工坊 ----
## 总开关在 `WorkshopApi.ENABLED`。关着的时候标题页不长按钮、编辑器不显示发布，
## 这里的函数也就没人调得到，整套功能对玩家不存在。

func _workshop_request_node() -> HTTPRequest:
	if _workshop_http == null or not is_instance_valid(_workshop_http):
		_workshop_http = HTTPRequest.new()
		_workshop_http.name = "WorkshopHttp"
		_workshop_http.timeout = WorkshopApi.REQUEST_TIMEOUT_SEC
		add_child(_workshop_http)
	return _workshop_http


func _on_custom_publish_requested(pack: Dictionary, author: String) -> void:
	if not WorkshopApi.ENABLED:
		return
	var result := await WorkshopApi.publish(
		_workshop_request_node(), String(pack.get("name", "")), author, _workshop_payload(pack)
	)
	if _custom_editor == null:
		return
	if bool(result.get("ok", false)):
		_custom_editor.set_publish_status("已发布到创意工坊。", true)
		return
	_custom_editor.set_publish_status("发布失败：" + _workshop_error_text(result), false)


## 关卡包在网络上走的是 JSON 文本那套（mask 写成 0/1 二维数组），和导出的文件同构，
## 这样服务端存下来的东西可以直接丢回 `CustomLevel.from_json` 读。
func _workshop_payload(pack: Dictionary) -> Dictionary:
	var parsed = JSON.parse_string(CustomLevel.to_json(pack))
	return parsed as Dictionary if parsed is Dictionary else {}


func _workshop_error_text(result: Dictionary) -> String:
	var error := String(result.get("error", ""))
	if error == "http_result" or error == "request_failed":
		return "连不上工坊服务器"
	if error == "bad_pack":
		return "关卡包不合法（%s）" % String(result.get("detail", ""))
	if error == "bad_name":
		return "名称不能为空"
	return error if not error.is_empty() else "未知错误"


func _build_workshop_panel() -> void:
	if _workshop_panel != null:
		return
	_workshop_panel = WorkshopPanelScript.new()
	_workshop_panel.name = "WorkshopPanel"
	add_child(_workshop_panel)
	_workshop_panel.play_requested.connect(_on_workshop_play_requested)
	_workshop_panel.closed.connect(_on_workshop_closed)


func _on_workshop_requested() -> void:
	if not WorkshopApi.ENABLED or _is_duel():
		return
	_build_workshop_panel()
	_workshop_panel.present()


## 从工坊下载的包直接开局；打完走的还是自定义那条路，结果卡上的「返回编辑」会把它
## 装进编辑器，玩家可以在别人的图上接着改。
func _on_workshop_play_requested(pack: Dictionary, id: String) -> void:
	if not CustomLevel.is_valid(pack):
		return
	_build_custom_editor()
	_custom_editor.load_level(pack)
	if _start_screen != null:
		var screen := _start_screen
		_start_screen = null
		var parent := screen.get_parent()
		if is_instance_valid(parent):
			parent.queue_free()
	if not id.is_empty():
		WorkshopApi.mark_play(_workshop_request_node(), id)
	_on_custom_play_requested(pack)


func _on_workshop_closed() -> void:
	if _start_screen == null and not _is_custom():
		_return_to_main_menu()


## 从自定义局退回编辑器：拆盘，配置留在编辑器里等着改。
func _return_to_custom_editor() -> void:
	if _custom_editor == null:
		_return_to_main_menu()
		return
	_clear_board_presentation()
	_hide_board_interface()
	_custom_level = {}
	_custom_map_index = 0
	_custom_editor.present()
