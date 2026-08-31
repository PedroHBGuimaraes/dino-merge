extends Control

## In-run popup when an achievement unlocks. GameManager.achievement_unlocked
## fires the moment a threshold is crossed mid-play (add_score / register_merge
## / register_game_started) but nothing was listening -- the player only found
## out by opening the menu screen later. This slides a card down from the top
## edge, holds, slides back, one at a time from a queue.
##
## Built entirely in code and dropped in as a single node (same pattern as
## FloatingScoreText) -- it has no editable layout worth a .tscn.

const CARD_WIDTH := 300.0
const CARD_HEIGHT := 64.0
const HIDDEN_Y := -CARD_HEIGHT - 8.0
## Below the HUD's top bar (which fills the top ~96px), above the danger
## line -- a toast at y=10 sat right on top of the score readout.
const SHOWN_Y := 102.0
const HOLD_SECONDS := 2.2
const SLIDE_IN := 0.35
const SLIDE_OUT := 0.3

var _queue: Array[String] = []
var _busy := false
var _card: Panel
var _icon: TextureRect
var _title: Label
var _sfx: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_card.position.y = HIDDEN_Y
	GameManager.achievement_unlocked.connect(_on_achievement_unlocked)


func _on_achievement_unlocked(id: String) -> void:
	_queue.append(id)
	if not _busy:
		_pump()


func _pump() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var id: String = _queue.pop_front()
	var achievement := Achievements.get_by_id(id)
	if achievement == null:
		_pump()
		return
	_icon.texture = achievement.icon
	_title.text = tr(achievement.title)
	_card.position.x = (size.x - CARD_WIDTH) * 0.5
	if _sfx.stream != null:
		_sfx.play()

	var tween := create_tween()
	(
		tween
		. tween_property(_card, "position:y", SHOWN_Y, SLIDE_IN)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_interval(HOLD_SECONDS)
	(
		tween
		. tween_property(_card, "position:y", HIDDEN_Y, SLIDE_OUT)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_callback(_pump)


func _build() -> void:
	_card = Panel.new()
	_card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.09, 0.05, 0.97)
	style.border_color = Color(1.0, 0.72, 0.2, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 6
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(40, 40)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_icon)

	var text := VBoxContainer.new()
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 1)
	row.add_child(text)

	var kicker := Label.new()
	kicker.text = tr("ACH_TOAST_UNLOCKED")
	kicker.add_theme_font_size_override("font_size", 12)
	kicker.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35, 1.0))
	text.add_child(kicker)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78, 1.0))
	text.add_child(_title)

	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"SFX"
	_sfx.stream = load("res://assets/audio/sfx/new_record.wav")
	_sfx.volume_db = -4.0
	add_child(_sfx)
