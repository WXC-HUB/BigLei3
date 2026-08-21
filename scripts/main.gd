extends Control

const BoardModel := preload("res://scripts/game/minesweeper_board.gd")
const CellView := preload("res://scenes/ui/mine_card.tscn")
const ShopOverlayView := preload("res://scenes/shop_overlay.tscn")
const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const PlayerStatusView := preload("res://scenes/player_status.tscn")
const NightMasterFishPopupView := preload("res://scenes/ui/night_master_fish_popup.tscn")
const VictoryBannerView := preload("res://scenes/ui/victory_banner.tscn")
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
const MusicBreakNoticeView := preload("res://scenes/ui/music_break_notice.tscn")
const StartScreenView := preload("res://scenes/ui/start_screen.tscn")
const TutorialSkipButtonView := preload("res://scenes/ui/tutorial_skip_button.tscn")
const RegularSkipControlView := preload("res://scenes/ui/regular_skip_control.tscn")
const GAME_CURSOR_TEXTURE := preload("res://assets/ui/cursor_dot.svg")
const CursorFxView := preload("res://scripts/ui/cursor_fx.gd")
const TUTORIAL_GUIDE_TEXTURE := preload("res://my_asset/guide.png")
const TUTORIAL_GUIDE_2_TEXTURE := preload("res://my_asset/guide_2.png")
const AchievementCatalogData := preload("res://scripts/game/achievement_catalog.gd")
const GameSaveData := preload("res://scripts/game/game_save.gd")
const ACHIEVEMENT_START_GAME := AchievementCatalogData.START_GAME
const ACHIEVEMENT_NIGHT_MASTER_FISH := AchievementCatalogData.NIGHT_MASTER_FISH

const START_BOARD_SIZE := 6
const TUTORIAL_LEVEL_COUNT := 4
## 打到非教程第五关的时候插播一次「该换首音乐了」，然后把制作人名单拉起来放歌。
## 每局只演一次，回主菜单重开会重置。
const MUSIC_BREAK_LEVEL := TUTORIAL_LEVEL_COUNT + 5
const BOARD_SIZE_HOLD_LEVELS := 3
const MAX_BOARD_SIZE := 10
const MINE_DENSITY := 0.16
const MEDICAL_KIT_COUNT := 1
const XRAY_COUNT := 1
const CHAIN_COUNT := 0
const ENLARGE_COUNT := 0
const DETECT_COUNT := 0
const SUPER_LUCK_CLICKS_PER_ITEM := 1
const CELL_SIZE := 88.0
const CELL_GAP := 7.0
const BOARD_VERTICAL_LIFT := 32.0
const BOARD_VERTICAL_SHIFT := CELL_SIZE - 36.0
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
const TARGET_GUIDE_Z := 40
const BIRD_FLYOVER_Z := 52
const BIRD_DROPPED_PROP_Z := 51
const PLAYER_START_MAX_HP := 3
const SHOP_ITEM_COST := 5
const BIG_MONSTER_MAX_HP := 30
const MINE_ATTACK_DELAY := 3
const MINE_DAMAGE := 1
## Marking a safe cell costs the same as stepping on a mine.
const WRONG_FLAG_DAMAGE := 1
const SMALL_MINE_ATTACK_DAMAGE := 10
const ITEM_SETTLEMENT_LAUNCH_INTERVAL := 0.14
const BIRD_DEPARTURE_QUEUE_INTERVAL := 0.09

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

const FLAG_TEXTURE := preload("res://assets/sprites/generated/marker_flag.png")
const MONSTER_SMALL_TEXTURE := preload("res://my_asset/monster_small.png")
const MONSTER_BIG_TEXTURE := preload("res://my_asset/monster_big.png")
const TRIGGERED_MINE_TEXTURE := preload("res://my_asset/effects/triggered_mine_red_cross.png")
const WRONG_FLAG_TEXTURE := preload("res://assets/sprites/generated/marker_wrong_flag_skull.png")
const LANTERN_TEXTURE := preload("res://assets/sprites/generated/bird_items/item_bird_lantern.png")
const COMPASS_TEXTURE := preload("res://assets/sprites/generated/bird_items/item_bird_compass.png")
const ORBITAL_STRIKE_TEXTURE := preload("res://assets/sprites/generated/bird_items/item_bird_orbital.png")
const SUPER_LUCK_TEXTURE := preload("res://assets/sprites/generated/bird_items/item_bird_super_luck.png")
const MEDICAL_KIT_TEXTURE := preload("res://assets/sprites/generated/potion_heal_green.png")
const XRAY_TEXTURE := preload("res://assets/sprites/generated/item_treasure_map.png")
const CHAIN_TEXTURE := preload("res://assets/sprites/generated/item_rope.png")
const ENLARGE_TEXTURE := preload("res://assets/sprites/generated/potion_star_purple.png")
const DETECT_TEXTURE := preload("res://assets/sprites/generated/tool_metal_detector.png")
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

var _board: MinesweeperBoard
var _cells: Array[MineCell] = []
var _grid: Control
var _status_label: Label
var _mine_label: Label
var _mine_counter_panel: PanelContainer
var _super_luck_watermark: CenterContainer
var _super_luck_watermark_count: Label
var _time_label: Label
var _health_bar: Control
var _player_status
var _effects_layer: Control
var _restart_button: Button
var _shop_layer: ShopOverlay
var _victory_banner: VictoryBanner
var _headphone_notice: HeadphoneNotice
var _opening_story
var _music_break_notice
var _music_break_played := false
var _credits_screen: CreditsScreen
var _achievements_screen: AchievementsScreen
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
var _cursor_fx: CursorFx
var _board_panel: PanelContainer
var _board_interface_shown := false
var _board_interface_fade: Tween
var _tutorial_guide: TextureRect
var _run_number := 0
var _resume_level := 1
var _blue_bird_unlocked := true
var _red_bird_unlocked := false
var _night_heron_unlocked := false
var _attacker_bird_unlocked := false
var _lucky_bird_unlocked := false
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
var _gold_rewarded_this_run := false
var _night_master_fish_count := 0
var _chain_mark_charges := 0
var _chain_marked_mines: Array[int] = []
var _enlarge_mark_charges := 0
var _enlarge_click_invincible := false
var _last_xray_target := -1
var _last_detect_target := -1
var _enlarge_hover_generation := 0
var _tutorial_first_reveal_pending := false
var _tutorial_night_heron_edge_index := -1
var _woodpecker_demo_pending := false
var _woodpecker_demo_index := -1
var _kestrel_demo_pending := false
var _kestrel_demo_index := -1
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


func _ready() -> void:
	_apply_game_cursor()
	_build_cursor_fx()
	_start_bgm()
	_build_interface()
	_build_shop_interface()
	_build_progression_interface()
	_build_tutorial_skip_interface()
	_build_regular_skip_interface()
	_build_headphone_notice()
	_build_opening_story()
	_build_music_break_notice()
	_build_credits_screen()
	_build_achievements_screen()
	_build_achievement_toast()
	_build_wrong_flag_guide_banner()
	_build_night_master_fish_guide_banner()
	_build_item_tooltip()
	_load_saved_progress()
	_build_start_screen()
	_apply_bird_unlock_visibility()


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
		"achievements": _unlocked_achievements.keys(),
	})
	_refresh_title_save_state()


func _load_saved_progress() -> bool:
	var data := GameSaveData.load_data()
	if data.is_empty():
		return false
	_resume_level = maxi(int(data.get("current_level", 1)), 1)
	if bool(data.get("tutorial_completed", false)):
		_resume_level = maxi(_resume_level, TUTORIAL_LEVEL_COUNT + 1)
	# `_start_game` increments first, so the title holds the level immediately
	# before the checkpoint that should be rebuilt.
	_run_number = _resume_level - 1
	_gold = maxi(int(data.get("gold", 0)), 0)
	_player_max_hp = maxi(int(data.get("player_max_hp", PLAYER_START_MAX_HP)), PLAYER_START_MAX_HP)
	_player_hp = clampi(int(data.get("player_hp", _player_max_hp)), 0, _player_max_hp)
	_blue_bird_unlocked = bool(data.get("blue_bird_unlocked", true))
	_red_bird_unlocked = bool(data.get("red_bird_unlocked", false))
	_night_heron_unlocked = bool(data.get("night_heron_unlocked", false))
	_attacker_bird_unlocked = bool(data.get("attacker_bird_unlocked", false))
	_lucky_bird_unlocked = bool(data.get("lucky_bird_unlocked", false))
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
	canvas.add_child(_start_screen)
	_refresh_title_save_state()
	_refresh_achievement_banner()


## 标题页上有两组和存档有关的东西：「清除存档」看文件在不在，「继续游戏／放弃本
## 轮」看有没有一轮打到一半。成就和进度共用一个文件，所以这两件事必须分开问。
func _refresh_title_save_state() -> void:
	if _start_screen == null:
		return
	_start_screen.set_save_available(GameSaveData.exists())
	_start_screen.set_run_in_progress(_resume_level > 1)


func _on_clear_save_requested() -> void:
	GameSaveData.clear()
	_return_to_main_menu()
	_refresh_title_save_state()
	if _start_screen != null:
		_refresh_achievement_banner()


## 放弃本轮：留下成就、丢掉跑图进度。做法是直接写一份「只剩成就」的存档，再走一
## 遍回标题页的常规流程——那条路会把内存清空后重新读盘，读到的就是这份新档。
func _on_abandon_run_requested() -> void:
	GameSaveData.write({
		"current_level": 1,
		"tutorial_completed": false,
		"achievements": _unlocked_achievements.keys(),
	})
	_return_to_main_menu()


func _on_start_game_requested() -> void:
	if _start_screen == null:
		return
	var screen := _start_screen
	_start_screen = null
	if is_instance_valid(screen) and screen.get_parent() != null:
		screen.get_parent().queue_free()
	# Intro pages only belong to a fresh first level, not a resumed checkpoint.
	var show_intro := _run_number == 0
	if show_intro and _headphone_notice != null:
		await _headphone_notice.present()
	if show_intro and _opening_story != null:
		await _opening_story.present()
	_start_game()


func _process(delta: float) -> void:
	if _started and not _board.game_over:
		_elapsed += delta
		_time_label.text = "%03d" % mini(int(_elapsed), 999)
	if _super_luck_mode_active and _super_luck_clicks_remaining <= 0:
		_finish_super_luck_mode_after_clicks(_super_luck_mode_generation)
	_refresh_super_luck_watermark()
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

	_mine_counter_panel = PanelContainer.new()
	_mine_counter_panel.name = "MineCounter"
	_mine_counter_panel.custom_minimum_size = Vector2(224, 58)
	_mine_counter_panel.z_index = 8
	_mine_counter_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mine_counter_panel.set_anchors_preset(Control.PRESET_CENTER)
	var counter_style := StyleBoxFlat.new()
	counter_style.bg_color = Color("172719ed")
	counter_style.border_color = Color("d7c073")
	counter_style.set_border_width_all(2)
	counter_style.set_corner_radius_all(15)
	counter_style.set_content_margin_all(9.0)
	counter_style.shadow_color = Color("10170d70")
	counter_style.shadow_size = 8
	counter_style.shadow_offset = Vector2(0, 4)
	_mine_counter_panel.add_theme_stylebox_override("panel", counter_style)
	board_stage.add_child(_mine_counter_panel)

	var mine_counter_row := HBoxContainer.new()
	mine_counter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mine_counter_row.add_theme_constant_override("separation", 10)
	_mine_counter_panel.add_child(mine_counter_row)
	var mine_icon := TextureRect.new()
	mine_icon.custom_minimum_size = Vector2(38, 38)
	mine_icon.texture = MONSTER_SMALL_TEXTURE
	mine_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mine_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mine_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mine_counter_row.add_child(mine_icon)
	var mine_caption := Label.new()
	mine_caption.text = "剩余雷"
	mine_caption.add_theme_color_override("font_color", Color("f4e8c1"))
	mine_caption.add_theme_font_size_override("font_size", 20)
	mine_counter_row.add_child(mine_caption)
	_mine_label = Label.new()
	_mine_label.text = "000"
	_mine_label.add_theme_color_override("font_color", Color("ffd768"))
	_mine_label.add_theme_color_override("font_outline_color", Color("302418"))
	_mine_label.add_theme_constant_override("outline_size", 4)
	_mine_label.add_theme_font_size_override("font_size", 28)
	_mine_label.custom_minimum_size.x = 54
	_mine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mine_counter_row.add_child(_mine_label)
	_position_mine_counter(panel_size)

	_grid = Control.new()
	_grid.name = "MineCardGrid"
	_grid.custom_minimum_size = grid_size
	board_panel.add_child(_grid)
	_build_super_luck_watermark(board_panel)

	# Keep player health and gold as a fixed top-left HUD. It must not participate
	# in the stage VBox, otherwise showing it would push the board downward.
	_player_status = PlayerStatusView.instantiate()
	_player_status.position = Vector2(24, 18)
	_player_status.z_index = 9
	add_child(_player_status)
	_health_bar = _player_status.health_bar

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
	_level_bill = LevelBillView.instantiate()
	_game_over_overlay = GameOverOverlayView.instantiate()
	_night_heron_unlock = NightHeronUnlockView.instantiate()
	_redstart_unlock = RedstartUnlockView.instantiate()
	_attacker_unlock = AttackerUnlockView.instantiate()
	_kestrel_unlock = KestrelUnlockView.instantiate()
	_game_over_overlay.return_requested.connect(_return_to_main_menu)
	# 四个解锁页里的彩蛋各自对应一条成就，触发时由页面自己报上来。
	for unlock_page in [
		_night_heron_unlock, _redstart_unlock, _attacker_unlock, _kestrel_unlock
	]:
		unlock_page.easter_egg_triggered.connect(_unlock_achievement)
	progression_canvas.add_child(_victory_banner)
	progression_canvas.add_child(_level_bill)
	progression_canvas.add_child(_game_over_overlay)
	progression_canvas.add_child(_night_heron_unlock)
	progression_canvas.add_child(_redstart_unlock)
	progression_canvas.add_child(_attacker_unlock)
	progression_canvas.add_child(_kestrel_unlock)


func _choose_shop_offer(offer: ShopOffer) -> void:
	if _player_hp <= 0:
		return
	if _gold < SHOP_ITEM_COST:
		_shop_layer.show_insufficient_gold(_gold, SHOP_ITEM_COST)
		return
	_gold -= SHOP_ITEM_COST
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
				_gold += SHOP_ITEM_COST
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
	_shop_layer.mark_offer_sold_out(offer)
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
	_shop_layer.refresh_offers(_gold, SHOP_ITEM_COST)
	_save_progress()


func _start_game() -> void:
	# 插播要抢在这一关搭起来之前：等它演完再往下走，商店和上一局的画面就一直被
	# 盖着，不会在名单和棋盘之间闪一下。
	if _run_number + 1 == MUSIC_BREAK_LEVEL and not _music_break_played:
		_music_break_played = true
		await _play_music_break()
	# A level can start while a hitstop is still pending — restarting or dying
	# mid-freeze would otherwise strand the whole game at 5% speed.
	_hitstop_generation += 1
	Engine.time_scale = 1.0
	_cancel_board_shake()
	_clear_inference_highlights()
	_clear_inference_hover_preview()
	_gold_rewarded_this_run = false
	_night_master_fish_count = 0
	_run_number += 1
	_resume_level = _run_number
	# The tutorial is allowed to teach through damage without carrying that
	# penalty into the real run. This happens exactly once, on level five.
	if _run_number == TUTORIAL_LEVEL_COUNT + 1:
		_player_hp = _player_max_hp
	var first_tutorial := _run_number == 1
	var second_tutorial := _run_number == 2
	var later_tutorial := _run_number >= 3 and _run_number <= TUTORIAL_LEVEL_COUNT
	var normal_level_number := maxi(_run_number - TUTORIAL_LEVEL_COUNT, 0)
	var growth_steps := maxi(normal_level_number - BOARD_SIZE_HOLD_LEVELS, 0)
	var board_width := 2 if first_tutorial else (4 if second_tutorial else (5 if later_tutorial else mini(START_BOARD_SIZE + growth_steps, MAX_BOARD_SIZE)))
	var board_height := 1 if first_tutorial else board_width
	var mine_count := 1 if first_tutorial else maxi(3, roundi(board_width * board_height * MINE_DENSITY))
	var bird_only_tutorial := _run_number <= TUTORIAL_LEVEL_COUNT
	_board = BoardModel.new(
		board_width,
		board_height,
		mine_count,
		0,
		_lantern_bonus,
		_compass_bonus,
		_orbital_strike_bonus,
		_super_luck_bonus,
		0 if bird_only_tutorial else MEDICAL_KIT_COUNT + _medical_kit_bonus,
		0 if bird_only_tutorial else XRAY_COUNT + _xray_bonus,
		CHAIN_COUNT + _chain_bonus,
		ENLARGE_COUNT + _enlarge_bonus,
		0 if bird_only_tutorial else DETECT_COUNT
	)
	_player_hp = clampi(_player_hp, 0, _player_max_hp)
	_shop_layer.visible = false
	_resize_board_layout(board_width, board_height)
	_active_mines.clear()
	_defeated_mines.clear()
	_wrong_flagged_cells.clear()
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
	_chain_mark_charges = 0
	_chain_marked_mines.clear()
	_enlarge_mark_charges = 0
	_enlarge_click_invincible = false
	_enlarge_hover_generation += 1
	_last_xray_target = -1
	_last_detect_target = -1
	_tutorial_first_reveal_pending = second_tutorial
	_tutorial_night_heron_edge_index = -1
	_woodpecker_demo_pending = _run_number == 4 and _attacker_bird_unlocked and _orbital_strike_bonus > 0
	_woodpecker_demo_index = -1
	_kestrel_demo_pending = _run_number == 5 and _lucky_bird_unlocked and _super_luck_bonus > 0
	_kestrel_demo_index = -1
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
	_refresh_health_bar()
	_refresh_gold_display()
	for bird in [_blue_bird, _red_bird, _black_bird, _attacker_bird, _eg_bird]:
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
			Vector2(column, row) * (CELL_SIZE + CELL_GAP),
			Vector2.ONE * CELL_SIZE
		)
		cell.configure(index, CELL_SIZE)
		cell.primary_pressed.connect(_on_cell_revealed)
		cell.secondary_pressed.connect(_on_cell_flagged)
		cell.hover_started.connect(_on_cell_hover_started)
		cell.hover_ended.connect(_on_cell_hover_ended)
		_grid.add_child(cell)
		cell.position = cell_rect.position
		cell.size = cell_rect.size
		cell.set_ground_texture(_ground_tile(index, false))
		_cells.append(cell)
		cell.display_covered()
	_reveal_board_interface()
	_update_tutorial_skip_visibility()
	_update_regular_skip_visibility()
	_unlock_achievement(ACHIEVEMENT_START_GAME)
	_save_progress()


func _resize_board_layout(columns: int, rows: int) -> void:
	var grid_size := Vector2(
		CELL_SIZE * columns + CELL_GAP * (columns - 1),
		CELL_SIZE * rows + CELL_GAP * (rows - 1)
	)
	_grid.custom_minimum_size = grid_size
	_grid.size = grid_size
	var panel_size := grid_size + Vector2(24, 24)
	_set_centered_board_panel_rect(_board_panel, panel_size)


func _set_centered_board_panel_rect(panel: Control, panel_size: Vector2) -> void:
	# The panel is center-anchored. Writing `position` before/after a resize mixes
	# viewport coordinates with anchor-relative offsets and can send it toward the
	# top-left. Keep all four offsets explicitly symmetric around the anchor.
	# Shake rides on top of this rest pose, so a resize has to drop any live shake
	# instead of baking its current displacement into the new rest position.
	_board_panel_size = panel_size
	_cancel_board_shake()
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT
	panel.offset_bottom = panel_size.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT
	_position_mine_counter(panel_size)
	_position_tutorial_guide(panel_size)


func _position_mine_counter(board_panel_size: Vector2) -> void:
	if _mine_counter_panel == null:
		return
	var counter_size := Vector2(224, 58)
	var bottom := -board_panel_size.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT - 14.0
	_mine_counter_panel.offset_left = -counter_size.x * 0.5
	_mine_counter_panel.offset_right = counter_size.x * 0.5
	_mine_counter_panel.offset_top = bottom - counter_size.y
	_mine_counter_panel.offset_bottom = bottom


func _position_tutorial_guide(board_panel_size: Vector2) -> void:
	if _tutorial_guide == null:
		return
	# The source has transparent padding above its drawings. Pulling the texture
	# rect slightly under the panel leaves the first visible pixel just below it.
	var guide_size := Vector2(360, 270)
	var board_bottom := board_panel_size.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT
	var top := board_bottom - 38.0
	_tutorial_guide.offset_left = -guide_size.x * 0.5
	_tutorial_guide.offset_right = guide_size.x * 0.5
	_tutorial_guide.offset_top = top
	_tutorial_guide.offset_bottom = top + guide_size.y


## 棋盘本体（边框 + 网格）、剩余雷计数和左上角的血量金币 HUD 是一整套「关卡里才
## 该出现」的东西，统一由这两个函数开关，免得漏掉其中一件。
func _board_interface_nodes() -> Array[Control]:
	var nodes: Array[Control] = []
	for node in [_board_panel, _mine_counter_panel, _player_status]:
		if node != null:
			nodes.append(node as Control)
	return nodes


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
		node.visible = true
		_board_interface_fade.tween_property(node, "modulate:a", 1.0, 0.3)


func _apply_bird_unlock_visibility() -> void:
	# Each perch scene owns both its bird and its branch. Hiding the root keeps
	# the whole locked partner silhouette out of the gameplay composition.
	_blue_bird.visible = _blue_bird_unlocked
	_red_bird.visible = _red_bird_unlocked
	_black_bird.visible = _night_heron_unlocked
	_attacker_bird.visible = _attacker_bird_unlocked
	_eg_bird.visible = _lucky_bird_unlocked


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
		_tutorial_guide.visible = tutorial_active


func _update_regular_skip_visibility() -> void:
	if _regular_skip_control != null:
		_regular_skip_control.set_available(
			_run_number > TUTORIAL_LEVEL_COUNT
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
	_night_heron_unlocked = true
	_red_bird_unlocked = true
	_attacker_bird_unlocked = true
	_lucky_bird_unlocked = true
	_lantern_bonus = maxi(_lantern_bonus, 1)
	_compass_bonus = maxi(_compass_bonus, 1)
	_orbital_strike_bonus = maxi(_orbital_strike_bonus, 1)
	_super_luck_bonus = maxi(_super_luck_bonus, 1)
	_player_hp = _player_max_hp
	_tutorial_first_reveal_pending = false
	_tutorial_night_heron_edge_index = -1
	_woodpecker_demo_pending = false
	_woodpecker_demo_index = -1
	_run_number = TUTORIAL_LEVEL_COUNT
	_start_game()


func _on_cell_mouse_button_changed(index: int, button_index: int, pressed: bool) -> void:
	if not pressed:
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
			_is_invincible(),
			float(_super_luck_clicks_remaining) if _super_luck_mode_active else _invincible_seconds_left(),
			_super_luck_mode_active
		)


func _is_invincible() -> bool:
	return (
		_super_luck_mode_active
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
		_clear_effect_preview()
		_enlarge_mark_charges -= 1
		var consume_super_luck_click := _super_luck_mode_active
		_prepare_tutorial_first_reveal(index)
		if consume_super_luck_click:
			_fly_eg_small_over_cell(index)
		_enlarge_click_invincible = true
		_refresh_health_bar()
		await _resolve_reveal_targets(_area_3x3_targets(index), "变大翻开了目标周围的 3×3 区域。")
		_enlarge_click_invincible = false
		_refresh_health_bar()
		if consume_super_luck_click and _super_luck_mode_active and not _game_finish_started:
			_consume_super_luck_click()
		return
	if _board.state_at(index) == MinesweeperBoard.CellState.COVERED:
		_play_board_impact()
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
	_board_panel.offset_left = -_board_panel_size.x * 0.5 + offset.x
	_board_panel.offset_right = _board_panel_size.x * 0.5 + offset.x
	_board_panel.offset_top = -_board_panel_size.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT + offset.y
	_board_panel.offset_bottom = _board_panel_size.y * 0.5 - BOARD_VERTICAL_LIFT + BOARD_VERTICAL_SHIFT + offset.y


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
	if not is_now_flagged:
		_chain_marked_mines.erase(index)
	elif found_mine:
		await _handle_correct_player_mark(index)
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
	_chain_marked_mines.erase(index)
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


func _handle_correct_player_mark(index: int) -> void:
	if _chain_mark_charges > 0:
		_chain_mark_charges -= 1
		if not _chain_marked_mines.has(index):
			_chain_marked_mines.append(index)
		_refresh_cell(index)
		_cells[index].set_chain_marker(true)
		_status_label.text = "这颗正确标记的雷已成为【标记雷】。"
		return
	var anchor := _nearest_aligned_chain_marker(index)
	if anchor < 0:
		return
	var targets := _line_between_targets(anchor, index)
	if targets.is_empty():
		return
	_cells[anchor].play_border_flash(Color("74f3ff"), 5, 0.08)
	_play_target_lock(anchor, [index], Color("74f3ff"), 1.0)
	await _resolve_reveal_targets(targets, "连携翻开了两颗雷之间的所有格子。")


func _nearest_aligned_chain_marker(index: int) -> int:
	var best := -1
	var best_distance := 1_000_000
	var row: int = index / _board.width
	var column := index % _board.width
	for anchor in _chain_marked_mines:
		if anchor == index or _board.state_at(anchor) != MinesweeperBoard.CellState.FLAGGED:
			continue
		var anchor_row: int = anchor / _board.width
		var anchor_column := anchor % _board.width
		if anchor_row != row and anchor_column != column:
			continue
		var distance := absi(anchor_row - row) + absi(anchor_column - column)
		if distance < best_distance:
			best = anchor
			best_distance = distance
	return best


func _line_between_targets(first: int, second: int) -> Array[int]:
	var targets: Array[int] = []
	var first_row: int = first / _board.width
	var second_row: int = second / _board.width
	var first_column := first % _board.width
	var second_column := second % _board.width
	if first_row == second_row:
		for column in range(mini(first_column, second_column) + 1, maxi(first_column, second_column)):
			targets.append(first_row * _board.width + column)
	elif first_column == second_column:
		for row in range(mini(first_row, second_row) + 1, maxi(first_row, second_row)):
			targets.append(row * _board.width + first_column)
	return targets


func _area_3x3_targets(center: int) -> Array[int]:
	var targets: Array[int] = [center]
	for neighbor in _board.neighbors_of(center):
		targets.append(neighbor)
	targets.sort()
	return targets


func _resolve_reveal_targets(targets: Array[int], completion_text: String) -> void:
	_resolving = true
	_restart_button.disabled = true
	_set_board_interactable(false)
	var changed := PackedInt32Array()
	var flagged := PackedInt32Array()
	for target in targets:
		if _board.state_at(target) == MinesweeperBoard.CellState.REVEALED:
			continue
		if _super_luck_mode_active and _board.is_monster_core(target):
			if _board.mark_mine(target):
				flagged.append(target)
			continue
		var target_changed := (
			_board.reveal(target)
			if _board.is_monster_core(target)
			else _board.reveal_exact_forced_safe(target)
		)
		for changed_index in target_changed:
			if not changed.has(changed_index):
				changed.append(changed_index)
	var item_queue: Array[int] = []
	var queued_items: Dictionary = {}
	var reveal_animation_duration := _present_revealed(changed, item_queue, queued_items)
	if _super_luck_mode_active:
		_defer_super_luck_reveals(changed)
		for flagged_index in flagged:
			_refresh_cell(flagged_index)
			_play_correct_flag_feedback(flagged_index)
		_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
		if _check_victory_now():
			return
		_status_label.text = "超级幸运模式：区域内的雷已标记，发现的道具将在模式结束后结算。"
		_resolving = false
		_restart_button.disabled = false
		_set_board_interactable(true)
		return
	if reveal_animation_duration > 0.0:
		await get_tree().create_timer(reveal_animation_duration).timeout
	if not _has_unresolved_revealed_mine(changed) and _check_victory_now():
		return
	var revealed_big_monsters := await _register_revealed_combat_objects(changed)
	for big_index in revealed_big_monsters:
		await _attack_big_with_small_mines(big_index, _flagged_small_monsters())
	await _resolve_item_queue(item_queue, queued_items)
	if _check_victory_now():
		return
	if _player_hp <= 0:
		await _finish_game()
		return
	_mine_label.text = "%03d" % maxi(_board.mine_count - _board.flag_count(), 0)
	_status_label.text = completion_text
	_resolving = false
	_restart_button.disabled = false
	_set_board_interactable(true)


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
				if _board.state_at(target) == MinesweeperBoard.CellState.COVERED:
					_previewed_cells.append(target)
					_cells[target].set_effect_preview(true, Color(0.76, 1.12, 1.12, 1.0))
		MinesweeperBoard.ItemType.ORBITAL_STRIKE:
			var row: int = index / _board.width
			for column in range(_board.width):
				var target := row * _board.width + column
				_previewed_cells.append(target)
				_cells[target].set_effect_preview(true, Color(1.18, 0.82, 0.62, 1.0))
		MinesweeperBoard.ItemType.SUPER_LUCK:
			_previewed_cells.append(index)
			_cells[index].set_effect_preview(true, Color(1.2, 1.12, 0.58, 1.0))
		MinesweeperBoard.ItemType.MEDICAL_KIT:
			_previewed_cells.append(index)
			_cells[index].set_effect_preview(true, Color(0.72, 1.18, 0.76, 1.0))
		MinesweeperBoard.ItemType.XRAY, MinesweeperBoard.ItemType.CHAIN, MinesweeperBoard.ItemType.ENLARGE, MinesweeperBoard.ItemType.DETECT:
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
			_item_tooltip_title.text = "疗愈鸟 · 翻出后自动使用"
			_item_tooltip_body.text = "恢复 %d 颗爱心，但不能超过当前生命上限。" % (1 + _healing_power_bonus)
		MinesweeperBoard.ItemType.XRAY:
			_item_tooltip_title.text = "透视 · 翻出后自动使用"
			_item_tooltip_body.text = "随机1个格子出现内容（不翻开）3s后消失"
		MinesweeperBoard.ItemType.CHAIN:
			_item_tooltip_title.text = "连携 · 翻出后自动使用"
			_item_tooltip_body.text = "特殊标记，标记连线雷后中间全被翻开"
		MinesweeperBoard.ItemType.ENLARGE:
			_item_tooltip_title.text = "变大 · 翻出后自动使用"
			_item_tooltip_body.text = "无敌，下一步选中的格子周围会被一起翻开"
		MinesweeperBoard.ItemType.DETECT:
			_item_tooltip_title.text = "探测 · 翻出后自动使用"
			_item_tooltip_body.text = "自动找出并标记一个尚未处理的雷。"
		_:
			_item_tooltip.visible = false
			return
	_item_tooltip.reset_size()
	_item_tooltip.visible = true


func _refresh_cell(index: int, animate_reveal: bool = false) -> void:
	var is_flipped := _board.state_at(index) == MinesweeperBoard.CellState.REVEALED
	var next_ground := _ground_tile(index, is_flipped)
	if animate_reveal:
		_cells[index].prepare_reveal_face(next_ground)
	else:
		_cells[index].set_ground_texture(next_ground)
	match _board.state_at(index):
		MinesweeperBoard.CellState.COVERED:
			_cells[index].display_covered()
		MinesweeperBoard.CellState.FLAGGED:
			_cells[index].display_covered(FLAG_TEXTURE)
			_cells[index].set_chain_marker(_chain_marked_mines.has(index))
		MinesweeperBoard.CellState.REVEALED:
			if _wrong_flagged_cells.has(index):
				_cells[index].display_destroyed(WRONG_FLAG_TEXTURE, animate_reveal)
				return
			var content: Texture2D
			var kind := MineCell.ContentKind.EMPTY
			var number_value := 0
			if _board.is_monster_core(index) and _defeated_mines.has(index):
				content = TRIGGERED_MINE_TEXTURE
				kind = MineCell.ContentKind.TRIGGERED
			elif _board.is_monster_core(index):
				content = _monster_texture(index)
				kind = MineCell.ContentKind.MONSTER
			elif _board.item_at(index) != MinesweeperBoard.ItemType.NONE:
				content = _item_texture(_board.item_at(index))
				kind = MineCell.ContentKind.ITEM
			else:
				number_value = _board.adjacent_mines(index)
				if number_value > 0:
					kind = MineCell.ContentKind.NUMBER
			var is_monster_visual := kind == MineCell.ContentKind.MONSTER
			var content_span := 3 if is_monster_visual and _board.monster_peripheral_count(index) == 8 else 1
			_cells[index].display_revealed(content, kind, animate_reveal, content_span, number_value)
			if kind == MineCell.ContentKind.ITEM:
				_cells[index].set_item_used_visual(_board.is_item_used(index))
			if _board.is_flagged(index):
				_cells[index].set_flag_marker(FLAG_TEXTURE)
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

	var revealed_big_monsters := await _register_revealed_combat_objects(changed)
	if _check_victory_now():
		return
	for big_index in revealed_big_monsters:
		await _attack_big_with_small_mines(big_index, _flagged_small_monsters())
	await _resolve_item_queue(item_queue, queued_items)
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


func _resolve_item_queue(item_queue: Array[int], queued_items: Dictionary) -> void:
	_item_queue_dispatching = true
	var deferred_super_luck: Array[int] = []
	# Start a new event at a fixed short cadence. Each coroutine completes in
	# the background, so a long flyover never prevents the next bird/effect
	# from entering the scene. Chained reveals may append more work here.
	while not item_queue.is_empty() or _active_item_settlements > 0:
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
	_status_label.text = "发现%s，正在结算……" % _item_display_name(item)
	_cells[item_index].play_item_focus(focus_color)
	_spawn_effect_ring(_cell_center(item_index), focus_color, 18.0, 68.0, 0.3)
	await get_tree().create_timer(0.3).timeout
	_board.consume_item(item_index)
	_refresh_cell(item_index)
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
		MinesweeperBoard.ItemType.CHAIN:
			await _resolve_chain(item_index)
		MinesweeperBoard.ItemType.ENLARGE:
			await _resolve_enlarge(item_index)
		MinesweeperBoard.ItemType.DETECT:
			await _resolve_detect(item_index)
	_check_victory_now()


func _resolve_medical_kit(item_index: int) -> void:
	var previous_hp := _player_hp
	var healing := 1 + _healing_power_bonus
	_player_hp = mini(_player_hp + healing, _player_max_hp)
	_refresh_health_bar()
	_player_status.play_heal_feedback()
	var health_center := _health_bar.global_position + _health_bar.size * 0.5
	_spawn_effect_ring(_cell_center(item_index), Color("87e58b"), 16.0, 76.0, 0.3)
	_spawn_effect_ring(health_center, Color("87e58b"), 18.0, 104.0, 0.36, 0.08)
	if _player_hp > previous_hp:
		_status_label.text = "疗愈鸟恢复了 %d 颗爱心。" % (_player_hp - previous_hp)
	else:
		_status_label.text = "爱心已满，疗愈鸟没有溢出上限。"
	await get_tree().create_timer(0.34).timeout


func _resolve_xray(item_index: int) -> void:
	_last_xray_target = _board.random_hidden_cell()
	if _last_xray_target < 0:
		_status_label.text = "透视没有找到仍被覆盖的格子。"
		return
	var content: Texture2D
	var number_value := 0
	if _board.is_monster_core(_last_xray_target):
		content = _monster_texture(_last_xray_target)
	elif _board.item_at(_last_xray_target) != MinesweeperBoard.ItemType.NONE:
		content = _item_texture(_board.item_at(_last_xray_target))
	else:
		number_value = _board.adjacent_mines(_last_xray_target)
	_cells[_last_xray_target].show_xray_hint(content, number_value, 3.0)
	_spawn_effect_ring(_cell_center(item_index), Color("c58cff"), 16.0, 74.0, 0.28)
	_status_label.text = "透视显示了一个格子的内容，3 秒后消失。"
	await get_tree().create_timer(0.18).timeout


func _resolve_chain(item_index: int) -> void:
	_chain_mark_charges += 1
	_spawn_effect_ring(_cell_center(item_index), Color("6de8f2"), 16.0, 76.0, 0.3)
	_status_label.text = "连携已准备：下一次正确标雷将成为标记雷。"
	await get_tree().create_timer(0.22).timeout


func _resolve_enlarge(item_index: int) -> void:
	_enlarge_mark_charges += 1
	_spawn_effect_ring(_cell_center(item_index), Color("d69bff"), 18.0, 88.0, 0.32)
	_status_label.text = "变大已准备：下一步无敌，选中格子周围会被一起翻开。"
	if _hovered_cell_index >= 0:
		_start_enlarge_hover_preview(_hovered_cell_index)
	await get_tree().create_timer(0.22).timeout


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
			return "疗愈鸟"
		MinesweeperBoard.ItemType.XRAY:
			return "透视"
		MinesweeperBoard.ItemType.CHAIN:
			return "连携"
		MinesweeperBoard.ItemType.ENLARGE:
			return "变大"
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
		return _game_finish_started and _board.won
	_update_round_completion()
	if not _board.won:
		return false
	# Concurrent bird effects must all clean up and return their actors before
	# progression replaces the board underneath their coroutines.
	if _item_queue_dispatching:
		return false
	_finish_game()
	return true


## Every correct mark — player, compass, lantern, detector, inference — goes
## through here so the confirmation reads the same wherever it comes from.
func _play_correct_flag_feedback(cell_index: int) -> void:
	if cell_index < 0 or cell_index >= _cells.size():
		return
	var cell := _cells[cell_index]
	_play_correct_flag_sfx()
	cell.play_flag()
	CELL_FX.play_flag_seal(_effects_layer, _cell_center(cell_index))
	# The flag pose lands first, then the card it sits on is blown off the board.
	await get_tree().create_timer(FLAG_SHATTER_DELAY).timeout
	# A level change or an undo during that beat retires the cell we aimed at.
	if not is_instance_valid(cell) or not cell.is_inside_tree():
		return
	if _board.state_at(cell_index) != MinesweeperBoard.CellState.FLAGGED:
		return
	cell.play_flag_shatter()
	CELL_FX.play_flag_shatter(
		_effects_layer,
		cell.global_position + cell.size * 0.5,
		cell.size.x
	)


func _play_correct_flag_sfx() -> void:
	if _correct_flag_sfx == null or _correct_flag_sfx.stream == null:
		return
	# Correct marks can arrive in quick inference batches, so keep each
	# confirmation voice independent instead of cutting the previous one off.
	var voice := AudioStreamPlayer.new()
	voice.stream = _correct_flag_sfx.stream
	voice.volume_db = _correct_flag_sfx.volume_db
	voice.bus = _correct_flag_sfx.bus
	add_child(voice)
	voice.play()
	_release_correct_flag_sfx_voice(voice)


func _release_correct_flag_sfx_voice(voice: AudioStreamPlayer) -> void:
	await get_tree().create_timer(maxf(voice.stream.get_length(), 0.1) + 0.05).timeout
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
			targets.append(row * _board.width + column)
	else:
		var row: int = item_index / _board.width
		for column in range(_board.width - 1, -1, -1):
			targets.append(row * _board.width + column)
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


func _super_luck_other_birds() -> Array[BirdPerch]:
	return [_blue_bird, _red_bird, _black_bird, _attacker_bird]


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
	content_span: int = 1
) -> void:
	var cell := _cells[index]
	var sealed := cell.is_flag_sealed()
	cell.set_ground_texture(_ground_tile(index, true))
	if sealed:
		cell.display_revealed_in_crater(content, kind, content_span)
	else:
		cell.display_revealed(content, kind, false, content_span)


func _finish_game() -> void:
	if _game_finish_started:
		return
	_game_finish_started = true
	_enlarge_click_invincible = false
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
			_settle_cell(index, TRIGGERED_MINE_TEXTURE, MineCell.ContentKind.TRIGGERED)
		elif _board.is_monster_core(index):
			var content_span := 3 if _board.monster_peripheral_count(index) == 8 else 1
			_settle_cell(index, _monster_texture(index), MineCell.ContentKind.MONSTER, content_span)
		elif (
			_board.state_at(index) == MinesweeperBoard.CellState.FLAGGED
			and not _board.is_monster_core(index)
		):
			_settle_cell(index, WRONG_FLAG_TEXTURE, MineCell.ContentKind.ITEM)
	if _player_hp <= 0:
		_board.won = false
		_status_label.text = "生命归零，旅程结束。"
		_status_label.add_theme_color_override("font_color", COLOR_DANGER)
	elif _board.won:
		_status_label.text = "雷区清理完成！\n干得漂亮。"
		_status_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		_mine_label.text = "000"
	else:
		_status_label.text = "轰！挖到了地雷。\n再试一次吧。"
		_status_label.add_theme_color_override("font_color", COLOR_DANGER)
	await get_tree().create_timer(0.55).timeout
	if _player_hp <= 0 or not _board.won:
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
	var flagged_mines := _correctly_flagged_mines()
	if not _gold_rewarded_this_run:
		_gold += flagged_mines + _night_master_fish_count
		_gold_rewarded_this_run = true
		_refresh_gold_display()
	_resume_level = _run_number + 1
	_save_progress()
	await _level_bill.present(_run_number, flagged_mines, _night_master_fish_count, _gold)
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


func _correctly_flagged_mines() -> int:
	var total := 0
	for index in range(_board.width * _board.height):
		if _board.is_monster_core(index) and _board.state_at(index) == MinesweeperBoard.CellState.FLAGGED:
			total += 1
	return total


func _show_shop() -> void:
	var result_template := "第 %d 局清扫完成" if _board.won else "第 %d 局遭遇地雷"
	var result := result_template % _run_number
	var progress := "夜鹭 %d（随机 %d）｜红尾水鸲 %d（标记 %d）｜啄木鸟 %d（%s）｜红隼 %d（无敌 %d）｜透视 %d｜连携 %d｜变大 %d｜回血 +%d｜生命上限 %d" % [
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
	_shop_layer.present(result, progress, _gold, SHOP_ITEM_COST)


func _return_to_main_menu() -> void:
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
	if _tutorial_skip_button != null:
		_tutorial_skip_button.set_available(false)
	if _tutorial_guide != null:
		_tutorial_guide.visible = false
	if _regular_skip_control != null:
		_regular_skip_control.set_available(false)
	_victory_banner.visible = false
	_level_bill.visible = false
	_game_over_overlay.visible = false
	_night_heron_unlock.visible = false
	_redstart_unlock.visible = false
	_attacker_unlock.visible = false
	_kestrel_unlock.visible = false
	for child in _grid.get_children():
		child.queue_free()
	_cells.clear()
	# 回到标题页等于回到「第一关还没开始」，棋盘和信息 UI 要跟着一起收走。
	_hide_board_interface()
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
	_run_number = 0
	_resume_level = 1
	_music_break_played = false
	_blue_bird_unlocked = true
	_red_bird_unlocked = false
	_night_heron_unlocked = false
	_attacker_bird_unlocked = false
	_lucky_bird_unlocked = false
	_lantern_bonus = 0
	_compass_bonus = 0
	_orbital_strike_bonus = 0
	_super_luck_bonus = 0
	_medical_kit_bonus = 0
	_healing_power_bonus = 0
	_super_luck_click_bonus = 0
	_orbital_cross_unlocked = false
	_shop_layer.set_offer_owned(ShopOffer.ORBITAL_CROSS, false)
	_lantern_target_bonus = 0
	_compass_mark_bonus = 0
	_xray_bonus = 0
	_chain_bonus = 0
	_enlarge_bonus = 0
	_unlocked_achievements.clear()
	if _achievements_screen != null:
		for entry in AchievementCatalogData.ENTRIES:
			_achievements_screen.set_unlocked(str(entry["id"]), false)
	_enlarge_click_invincible = false
	_game_finish_started = false
	_started = false
	_resolving = false
	_refresh_health_bar()
	for bird in [_blue_bird, _red_bird, _black_bird, _attacker_bird, _eg_bird]:
		bird.reset_to_idle()
	_apply_bird_unlock_visibility()
	_refresh_gold_display()
	_load_saved_progress()
	_apply_bird_unlock_visibility()
	if _start_screen == null:
		_build_start_screen()
	else:
		_refresh_title_save_state()
		_refresh_achievement_banner()


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
