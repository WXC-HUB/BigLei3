class_name OpeningStory
extends Control
## 开场剧情：四张插画，一张配一句主文本加一行小字，插画和文字左右交替。
##
## 主文本用的是标题界面那套「文字过山车」（[TextCoaster]）——同一份实现，所以两边
## 的字是同一个动法：一列相位递减的正弦波沿着句子往后跑，队尾两个字上不断冒出
## 「9」。句子本身逐字打出来，每露一个字就并入波形，开打的瞬间叫一声小蓝鸟。
## 小字只逐字显影、不上过山车：它是主文本的注脚，跟着一起跳就抢戏了。
##
## 这里没有对白框：插画自带手绘画框和卡纸边，整页只靠纸色明暗、留白和一条细分隔
## 线分区，不再套第二层外框。
##
## 全程支持长按跳过，表演交给 [LongPressSkip]。跳过是靠 [member _skipped] 标志退
## 出的：await 出去的计时器和补间没法中途取消，所以每个等待点回来都要复查一次，
## 而且等待要切片（见 [method _sleep]），否则最长要压着一秒多才反应过来。

const TextCoaster := preload("res://scripts/ui/text_coaster.gd")
const LongPressSkipView := preload("res://scenes/ui/long_press_skip.tscn")

const STORY_IMAGES: Array[Texture2D] = [
	preload("res://my_asset/story/st_1.png"),
	preload("res://my_asset/story/st_2.png"),
	preload("res://my_asset/story/st_3.png"),
	preload("res://my_asset/story/st_4.png"),
]
## 大字是鸟叫本身：同一个字重复十四遍，过山车的波形跑过去就是一串起伏的啼鸣。
## 十四个全角字在 92 号下正好 1288 像素，文字列的宽度是照着这个数留的，改字数或
## 字号都要跟着调 TextColumn 的 custom_minimum_size，否则字会漫出去压到插画。
const STORY_MAIN_TEXTS := [
	"啾啾啾啾啾啾啾啾啾啾啾啾啾啾",
	"救救救救救救救救救救救救救救",
	"鹫鹫鹫鹫鹫鹫鹫鹫鹫鹫鹫鹫鹫鹫",
	"揪揪揪揪揪揪揪揪揪揪揪揪揪揪",
]
## 小字是这串叫声的翻译。
const STORY_SUB_TEXTS := [
	"叫声大意：快看看这棵树生病了",
	"叫声大意：快想办法救救他",
	"叫声大意：有了，我去叫其他鸟！",
	"叫声大意：我们上吧！",
]

## 打字机的出字间隔，以及打完之后留给读者的时间。
const TYPE_INTERVAL := 0.085
## 小字比主文本快一档：它是注脚，不该抢主文本的节奏。
const SUB_TYPE_INTERVAL := 0.038
const LINE_HOLD := 0.75
## 收尾那句多留一拍，交接到棋盘时不显得被切断。
const FINAL_LINE_EXTRA_HOLD := 0.2
## 每一幕的鸟叫依次升调，四声连起来是一条上扬的线。
const CALL_PITCH_RANGE := Vector2(0.94, 1.12)
## 等待切片的长度：跳过最多迟这么久才生效。
const SLEEP_SLICE := 0.05

@onready var backdrop: Control = %Backdrop
@onready var header: VBoxContainer = %Header
@onready var stage: MarginContainer = %Stage
@onready var composition: HBoxContainer = %Composition
@onready var illustration: TextureRect = %Illustration
@onready var text_column: VBoxContainer = %TextColumn
@onready var main_text: Label = %MainText
@onready var sub_text: Label = %SubText
@onready var bird_call: AudioStreamPlayer = %BirdCall
@onready var beat_pips: Array[Node] = %Beats.get_children()

var playback_speed := 1.0
var _presenting := false
var _presentation_count := 0
var _segment_history: Array[int] = []
var _coaster: TextCoaster
var _skip: LongPressSkip
var _skipped := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 过山车挂在 Stage 外面：它的单字拷贝是绝对定位的，放进容器会被当成新的一行。
	# 排在最后一个子节点，「9」才会从插画和页脚前面飘过去。
	_coaster = TextCoaster.new()
	_coaster.name = "MainTextCoaster"
	add_child(_coaster)
	_coaster.bind(main_text)
	_coaster.set_visible_glyph_count(0)
	# 长按层排在最后：水印和探头的小鸟要压在插画、文字和「9」上面。
	_skip = LongPressSkipView.instantiate()
	add_child(_skip)
	_skip.skip_triggered.connect(_on_skip_triggered)
	stage.modulate.a = 0.0
	_reset_beat_pips()


func present() -> void:
	if _presenting:
		return
	_presenting = true
	_presentation_count += 1
	_segment_history.clear()
	_skipped = false
	visible = true
	backdrop.modulate.a = 0.0
	header.modulate.a = 0.0
	stage.modulate.a = 0.0
	_coaster.modulate.a = 0.0
	_coaster.set_visible_glyph_count(0)
	_reset_beat_pips()
	await get_tree().process_frame
	_skip.set_active(true)

	var opening := create_tween().set_parallel(true)
	opening.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	opening.tween_property(backdrop, "modulate:a", 1.0, _duration(0.3))
	opening.tween_property(header, "modulate:a", 1.0, _duration(0.42)).set_delay(_duration(0.14))
	await opening.finished

	for beat_index in range(STORY_IMAGES.size()):
		if _skipped:
			break
		_advance_beat_pips(beat_index)
		await _play_beat(beat_index)

	_skip.set_active(false)
	var closing := create_tween().set_parallel(true)
	closing.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	closing.tween_property(header, "modulate:a", 0.0, _duration(0.26))
	closing.tween_property(stage, "modulate:a", 0.0, _duration(0.26))
	closing.tween_property(_coaster, "modulate:a", 0.0, _duration(0.26))
	closing.tween_property(backdrop, "modulate:a", 0.0, _duration(0.42))
	await closing.finished
	_coaster.set_visible_glyph_count(0)
	visible = false
	_presenting = false


func _play_beat(beat_index: int) -> void:
	_segment_history.append(beat_index)
	# 先把上一句收掉再换文本，重排出来的新字才不会闪一下全亮。
	_coaster.set_visible_glyph_count(0)
	illustration.texture = STORY_IMAGES[beat_index]
	main_text.text = String(STORY_MAIN_TEXTS[beat_index])
	sub_text.text = String(STORY_SUB_TEXTS[beat_index])
	sub_text.visible_ratio = 0.0
	_layout_sides(beat_index)
	stage.modulate.a = 0.0
	_coaster.modulate.a = 1.0
	# 两帧：一帧让容器收到换边和换文本的通知，一帧等它真的重排完。过山车是照着
	# 主文本的最终落点摆字的，早一帧量到的还是上一幕的位置。
	await get_tree().process_frame
	await get_tree().process_frame
	_coaster.rebuild_now()

	# 插画像被放到纸上的照片：带一点倾斜地落定，落定后就不再动。
	illustration.pivot_offset = illustration.size * 0.5
	illustration.scale = Vector2.ONE * 0.94
	illustration.rotation = deg_to_rad(-1.4 if _image_on_left(beat_index) else 1.4)
	var entrance := create_tween().set_parallel(true)
	entrance.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	entrance.tween_property(stage, "modulate:a", 1.0, _duration(0.32))
	entrance.set_trans(Tween.TRANS_BACK)
	entrance.tween_property(illustration, "scale", Vector2.ONE, _duration(0.5))
	entrance.tween_property(illustration, "rotation", 0.0, _duration(0.5))
	await entrance.finished
	if _skipped:
		return

	_play_bird_call(beat_index)
	await _type_out()
	if _skipped:
		return

	var hold := LINE_HOLD
	if beat_index == STORY_IMAGES.size() - 1:
		hold += FINAL_LINE_EXTRA_HOLD
	await _sleep(hold)
	if _skipped:
		return

	var exit := create_tween().set_parallel(true)
	exit.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_property(stage, "modulate:a", 0.0, _duration(0.3))
	exit.tween_property(_coaster, "modulate:a", 0.0, _duration(0.3))
	await exit.finished
	_coaster.set_visible_glyph_count(0)


## 单数幕图在左、双数幕图在右，四幕连起来是左右左右。
func _image_on_left(beat_index: int) -> bool:
	return beat_index % 2 == 0


func _layout_sides(beat_index: int) -> void:
	composition.move_child(illustration, 0 if _image_on_left(beat_index) else 1)
	composition.move_child(text_column, 1 if _image_on_left(beat_index) else 0)


## 主文本逐字露出来，露出的字立刻并入波形，句子是一边打一边跑起来的；小字紧随
## 其后，只走 visible_ratio，不上过山车。
func _type_out() -> void:
	var total := _coaster.glyph_count()
	for count in range(1, total + 1):
		if _skipped:
			return
		_coaster.set_visible_glyph_count(count)
		await get_tree().create_timer(_duration(TYPE_INTERVAL)).timeout
	var sub_length := sub_text.text.length()
	for count in range(1, sub_length + 1):
		if _skipped:
			return
		sub_text.visible_ratio = float(count) / float(sub_length)
		await get_tree().create_timer(_duration(SUB_TYPE_INTERVAL)).timeout


func _on_skip_triggered() -> void:
	_skipped = true


## 切片等待：整段睡下去的话，长按最多要压到一句话读完才生效。
func _sleep(seconds: float) -> void:
	var remaining := _duration(seconds)
	while remaining > 0.0 and not _skipped:
		var slice := minf(remaining, _duration(SLEEP_SLICE))
		await get_tree().create_timer(slice).timeout
		remaining -= slice


func _play_bird_call(beat_index: int) -> void:
	if bird_call == null or bird_call.stream == null:
		return
	var progress := float(beat_index) / maxf(float(STORY_IMAGES.size() - 1), 1.0)
	bird_call.pitch_scale = lerpf(CALL_PITCH_RANGE.x, CALL_PITCH_RANGE.y, progress)
	bird_call.play()


func _reset_beat_pips() -> void:
	for pip in beat_pips:
		var panel := pip as Control
		panel.custom_minimum_size.x = 16.0
		panel.modulate = Color(1.0, 1.0, 1.0, 0.22)


func _advance_beat_pips(beat_index: int) -> void:
	for index in beat_pips.size():
		var panel := beat_pips[index] as Control
		var active := index == beat_index
		var alpha := 1.0 if active else (0.45 if index < beat_index else 0.22)
		var pip_tween := create_tween().set_parallel(true)
		pip_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pip_tween.tween_property(panel, "custom_minimum_size:x", 42.0 if active else 16.0, _duration(0.3))
		pip_tween.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, alpha), _duration(0.3))


func _duration(seconds: float) -> float:
	return seconds / maxf(playback_speed, 0.01)
