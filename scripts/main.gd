extends Node2D

const DINO_SCENE := preload("res://scenes/Dino.tscn")
const FLOATING_SCORE_SCENE := preload("res://scenes/FloatingScoreText.tscn")

const LEFT_X := 40.0
const RIGHT_X := 680.0
const SPAWN_Y := 100.0
const MAX_SPAWN_LEVEL := 4  # only the 5 smallest species come out of the spawner
const SOUND_ON_ICON := preload("res://assets/ui/merge/icon_sound_on.png")
const SOUND_OFF_ICON := preload("res://assets/ui/merge/icon_sound_off.png")

## From this level index up, a merge is rare/special enough to earn a
## screen shake on top of the usual particles/pop (top ~6 of 32 levels).
const HIGH_MERGE_SHAKE_LEVEL := 26

var next_level_index: int = 0
var can_drop: bool = true
var preview_x: float = 360.0

@onready var camera: Camera2D = $Camera2D
@onready var dinos: Node2D = $Dinos
@onready var spawner_preview: Node2D = $SpawnerPreview
@onready var score_label: Label = $UI/ScoreRow/ScoreLabel
@onready var next_label: Label = $UI/NextLabel
@onready var sound_toggle_btn: TextureButton = $UI/SoundToggleButton
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var game_over_vbox: VBoxContainer = $UI/GameOverPanel/CenterContainer/VBoxContainer
@onready
var final_score_label: Label = $UI/GameOverPanel/CenterContainer/VBoxContainer/FinalScoreLabel
@onready var record_label: Label = $UI/GameOverPanel/CenterContainer/VBoxContainer/NewRecordLabel
@onready
var best_label: Label = $UI/GameOverPanel/CenterContainer/VBoxContainer/HighScoreRow/HighScoreLabel
@onready var continue_btn: Button = $UI/GameOverPanel/CenterContainer/VBoxContainer/ContinueButton
@onready var restart_button: Button = $UI/GameOverPanel/CenterContainer/VBoxContainer/RestartButton
@onready var drop_sfx: AudioStreamPlayer = $DropSfx
@onready var merge_sfx: AudioStreamPlayer = $MergeSfx
@onready var music: AudioStreamPlayer = $Music
@onready var game_over_sfx: AudioStreamPlayer = $GameOverSfx
@onready var record_sfx: AudioStreamPlayer = $RecordSfx
@onready var ui_click_sfx: AudioStreamPlayer = $UiClickSfx


func _ready() -> void:
	GameManager.reset()
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.game_over.connect(_on_game_over)
	restart_button.pressed.connect(_on_restart_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	sound_toggle_btn.pressed.connect(_on_sound_toggle_pressed)
	_update_sound_icon()
	music.finished.connect(func(): music.play())
	randomize()
	game_over_panel.visible = false
	next_level_index = _random_spawn_level()
	_update_preview()


func _random_spawn_level() -> int:
	return randi() % (MAX_SPAWN_LEVEL + 1)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_game_over:
		return
	if event is InputEventScreenDrag:
		_move_preview(event.position.x)
	elif event is InputEventScreenTouch:
		_move_preview(event.position.x)
		if not event.pressed:
			_drop()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_move_preview(event.position.x)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_move_preview(event.position.x)
		if not event.pressed:
			_drop()


func _move_preview(x: float) -> void:
	var radius := DinoChain.get_level(next_level_index).radius
	preview_x = clamp(x, LEFT_X + radius, RIGHT_X - radius)
	spawner_preview.position.x = preview_x


func _drop() -> void:
	if not can_drop or GameManager.is_game_over:
		return
	can_drop = false
	var dino := DINO_SCENE.instantiate()
	dinos.add_child(dino)
	dino.add_to_group("dino")
	dino.global_position = Vector2(preview_x, SPAWN_Y)
	dino.setup(next_level_index)
	drop_sfx.play()
	next_level_index = _random_spawn_level()
	_update_preview()
	await get_tree().create_timer(0.45).timeout
	can_drop = true


func _update_preview() -> void:
	spawner_preview.set_level(next_level_index)
	spawner_preview.position.x = preview_x
	next_label.text = "Próximo: " + DinoChain.get_level(next_level_index).dino_name


func spawn_merged_dino(index: int, global_pos: Vector2, score_awarded: int) -> void:
	var dino := DINO_SCENE.instantiate()
	dinos.add_child(dino)
	dino.add_to_group("dino")
	dino.global_position = global_pos
	dino.setup(index)
	dino.play_spawn_bounce()

	# Pitch (and a touch of volume) climbs with the merged level, so a
	# low-tier merge sounds subtly different from a top-of-the-chain one.
	var level_fraction := float(index) / float(DinoChain.level_count() - 1)
	merge_sfx.pitch_scale = 1.0 + level_fraction * 1.1
	merge_sfx.volume_db = level_fraction * 4.0
	merge_sfx.play()

	_spawn_floating_score(global_pos, score_awarded)
	_spawn_merge_particles(global_pos, index)
	if index >= HIGH_MERGE_SHAKE_LEVEL:
		_screen_shake(7.0, 0.35)


func _spawn_floating_score(global_pos: Vector2, amount: int) -> void:
	var popup := FLOATING_SCORE_SCENE.instantiate()
	add_child(popup)
	popup.global_position = global_pos + Vector2(0, -20)
	popup.text = "+%d" % amount


func _spawn_merge_particles(global_pos: Vector2, index: int) -> void:
	var particles := CPUParticles2D.new()
	add_child(particles)
	particles.global_position = global_pos
	particles.one_shot = true
	particles.emitting = false
	particles.amount = 10 + index * 2
	particles.lifetime = 0.45 + index * 0.015
	particles.explosiveness = 0.9
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 320)
	particles.initial_velocity_min = 60.0 + index * 3.5
	particles.initial_velocity_max = 110.0 + index * 5.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 5.0 + index * 0.25
	# Bright/pale version of the level's hue -- the level's own color (same
	# saturation as the dino) blended right into the dino and background
	# and was invisible in practice; low saturation + near-white value
	# reads as a "sparkle" against anything behind it.
	var level_hue := DinoChain.get_level(index).color.h
	particles.color = Color.from_hsv(level_hue, 0.35, 1.0)
	particles.emitting = true
	await get_tree().create_timer(particles.lifetime + 0.2).timeout
	particles.queue_free()


func _screen_shake(strength: float, duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		await get_tree().create_timer(0.02).timeout
		elapsed += 0.02
	camera.offset = Vector2.ZERO


func _on_sound_toggle_pressed() -> void:
	ui_click_sfx.play()
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus, not AudioServer.is_bus_mute(master_bus))
	_update_sound_icon()


func _update_sound_icon() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	var muted := AudioServer.is_bus_mute(master_bus)
	sound_toggle_btn.texture_normal = SOUND_OFF_ICON if muted else SOUND_ON_ICON


func _on_score_changed(new_score: int) -> void:
	score_label.text = "Pontos: %d" % new_score


func _on_game_over() -> void:
	final_score_label.text = "Pontuação final: %d" % GameManager.score
	best_label.text = "Recorde pessoal: %d" % GameManager.high_score
	record_label.visible = GameManager.is_new_record
	continue_btn.visible = AdsManager.is_rewarded_ad_ready()
	continue_btn.disabled = false
	restart_button.disabled = false

	if GameManager.is_new_record:
		record_sfx.play()
	else:
		game_over_sfx.play()

	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	game_over_vbox.scale = Vector2(0.7, 0.7)
	await get_tree().process_frame  # let layout settle so pivot_offset/size are valid
	game_over_vbox.pivot_offset = game_over_vbox.size / 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(game_over_panel, "modulate:a", 1.0, 0.25)
	(
		tween
		. tween_property(game_over_vbox, "scale", Vector2.ONE, 0.35)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _on_continue_pressed() -> void:
	ui_click_sfx.play()
	continue_btn.disabled = true
	restart_button.disabled = true
	AdsManager.offer_rewarded_continue(_on_rewarded_continue_result)


func _on_rewarded_continue_result(earned: bool) -> void:
	if not earned:
		# Declined, ad failed, or became unavailable -- normal game over stands.
		continue_btn.disabled = false
		restart_button.disabled = false
		continue_btn.visible = AdsManager.is_rewarded_ad_ready()
		return
	_clear_top_dinos_for_continue()
	GameManager.continue_run()
	game_over_panel.visible = false
	can_drop = true
	next_level_index = _random_spawn_level()
	_update_preview()


## Frees the topmost half of the current pile (by Y position, so
## whatever is closest to / above the danger line goes first) to make
## room for the run to keep going instead of resetting it.
func _clear_top_dinos_for_continue() -> void:
	var pile := dinos.get_children()
	pile.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	var clear_count := int(ceil(pile.size() * 0.5))
	for i in range(min(clear_count, pile.size())):
		pile[i].queue_free()


func _on_restart_pressed() -> void:
	ui_click_sfx.play()
	restart_button.disabled = true
	continue_btn.disabled = true
	AdsManager.register_game_over_and_continue(func(): get_tree().reload_current_scene())
