extends Node2D

const DINO_SCENE := preload("res://scenes/Dino.tscn")
const FLOATING_SCORE_SCENE := preload("res://scenes/FloatingScoreText.tscn")

## The whole container/dinos/spawner subtree was designed against this
## reference canvas. GameplayRoot gets scaled + centered to fit whatever
## the actual viewport is (see _fit_gameplay_to_viewport), so every
## coordinate below stays in this fixed design space regardless of the
## real screen/window size -- nothing else needs to change per device.
const DESIGN_SIZE := Vector2(720.0, 1280.0)

const LEFT_X := 40.0
const RIGHT_X := 680.0
const SPAWN_Y := 100.0
const DANGER_LINE_Y_DESIGN := 220.0
const MAX_SPAWN_LEVEL := 4  # only the 5 smallest species come out of the spawner
const SOUND_ON_ICON := preload("res://assets/ui/merge/icon_sound_on.png")
const SOUND_OFF_ICON := preload("res://assets/ui/merge/icon_sound_off.png")

## Background swaps to a more intense variant as the current run's score
## climbs -- more bones, brighter lava cracks -- purely a score
## threshold, not a continuous transition (see bg_crater_mid/_high.png).
const BG_BASE := preload("res://assets/scenes/bg_crater.png")
const BG_MID := preload("res://assets/scenes/bg_crater_mid.png")
const BG_HIGH := preload("res://assets/scenes/bg_crater_high.png")
const BG_MID_SCORE := 300
const BG_HIGH_SCORE := 800

## From this level index up, a merge is rare/special enough to earn a
## screen shake on top of the usual particles/pop (top ~6 of 32 levels).
const HIGH_MERGE_SHAKE_LEVEL := 26

var next_level_index: int = 0
var can_drop: bool = true
var preview_x: float = 360.0
var _bg_tier: int = 0

@onready var camera: Camera2D = $Camera2D
@onready var background: TextureRect = $BackgroundLayer/Background
@onready var gameplay_root: Node2D = $GameplayRoot
@onready var dinos: Node2D = $GameplayRoot/Dinos
@onready var spawner_preview: Node2D = $GameplayRoot/SpawnerPreview
@onready var score_label: Label = $UI/ScoreRow/ScoreLabel
@onready var next_label: Label = $UI/NextLabel
@onready var sound_toggle_btn: TextureButton = $UI/SoundToggleButton
@onready var pause_button: TextureButton = $UI/PauseButton
@onready var pause_panel: Control = $UI/PausePanel
@onready var pause_main_buttons: VBoxContainer = $UI/PausePanel/CenterContainer/MainButtons
@onready var pause_resume_btn: Button = $UI/PausePanel/CenterContainer/MainButtons/ResumeButton
@onready var pause_restart_btn: Button = $UI/PausePanel/CenterContainer/MainButtons/RestartButton
@onready var pause_settings_btn: Button = $UI/PausePanel/CenterContainer/MainButtons/SettingsButton
@onready var pause_menu_btn: Button = $UI/PausePanel/CenterContainer/MainButtons/MenuButton
@onready var confirm_restart_panel: Control = $UI/PausePanel/ConfirmPanel
@onready var confirm_restart_yes_btn: Button = $UI/PausePanel/ConfirmPanel/Center/Box/YesButton
@onready var confirm_cancel_btn: Button = $UI/PausePanel/ConfirmPanel/Center/Box/CancelButton
@onready var pause_settings_panel: Control = $UI/PausePanel/SettingsPanel
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
@onready var legendary_banner: Label = $UI/LegendaryBanner
@onready var tutorial_panel: Control = $UI/TutorialPanel


func _ready() -> void:
	_fit_gameplay_to_viewport()
	GameManager.reset()
	GameManager.register_game_started()
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.game_over.connect(_on_game_over)
	restart_button.pressed.connect(_on_restart_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	sound_toggle_btn.pressed.connect(_on_sound_toggle_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	pause_resume_btn.pressed.connect(_on_pause_resume_pressed)
	pause_restart_btn.pressed.connect(_on_pause_restart_pressed)
	pause_settings_btn.pressed.connect(_on_pause_settings_pressed)
	pause_menu_btn.pressed.connect(_on_pause_menu_pressed)
	confirm_restart_yes_btn.pressed.connect(_on_confirm_restart_yes)
	confirm_cancel_btn.pressed.connect(_on_confirm_restart_cancel)
	pause_settings_panel.closed.connect(_on_pause_settings_closed)
	_update_sound_icon()
	music.finished.connect(func(): music.play())
	randomize()
	game_over_panel.visible = false
	pause_panel.visible = false
	confirm_restart_panel.visible = false
	pause_settings_panel.visible = false
	legendary_banner.visible = false
	tutorial_panel.visible = false
	next_level_index = _random_spawn_level()
	_update_preview()

	if not GameManager.has_seen_tutorial:
		tutorial_panel.open()


## Scales + centers GameplayRoot so the fixed-coordinate container/dinos/
## spawner subtree (designed for DESIGN_SIZE) always fits fully inside
## whatever the actual viewport turns out to be -- otherwise anything
## set up assuming a 720x1280 canvas (walls at x=680, floor at y=1200,
## ...) simply falls outside a smaller one and is never seen.
func _fit_gameplay_to_viewport() -> void:
	var vp_size := get_viewport_rect().size
	var scale_factor: float = min(vp_size.x / DESIGN_SIZE.x, vp_size.y / DESIGN_SIZE.y)
	gameplay_root.scale = Vector2(scale_factor, scale_factor)
	gameplay_root.position = (vp_size - DESIGN_SIZE * scale_factor) / 2.0
	GameManager.danger_line_y = gameplay_root.to_global(Vector2(0, DANGER_LINE_Y_DESIGN)).y


func _random_spawn_level() -> int:
	return randi() % (MAX_SPAWN_LEVEL + 1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_handle_back_button()
		get_viewport().set_input_as_handled()
		return
	if GameManager.is_game_over:
		return
	if event is InputEventScreenDrag:
		_move_preview(_to_gameplay_x(event.position.x))
	elif event is InputEventScreenTouch:
		_move_preview(_to_gameplay_x(event.position.x))
		if not event.pressed:
			_drop()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_move_preview(_to_gameplay_x(event.position.x))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_move_preview(_to_gameplay_x(event.position.x))
		if not event.pressed:
			_drop()


## Touch/mouse positions arrive in real viewport pixels; gameplay
## coordinates (LEFT_X..RIGHT_X) are in GameplayRoot's fixed design
## space, so convert before using them.
func _to_gameplay_x(viewport_x: float) -> float:
	return gameplay_root.to_local(Vector2(viewport_x, 0)).x


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
	# preview_x/SPAWN_Y are in GameplayRoot's local design space (same as
	# spawner_preview.position, which tracks the drag correctly) -- must
	# go through to_global() before assigning global_position, otherwise
	# this only lines up when the runtime scale/offset happens to be
	# identity, and drifts right/down from the actual drag position by
	# more the further GameplayRoot's fit differs from 1:1.
	dino.global_position = gameplay_root.to_global(Vector2(preview_x, SPAWN_Y))
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

	# Subtle by default, stronger the higher the merged level -- and the
	# very top of the chain gets a distinctly longer buzz on top of its
	# own shake + banner, since that merge is rare enough to deserve a
	# more noticeable cue than "just a bigger version of every other one".
	Input.vibrate_handheld(int(20 + level_fraction * 60))

	if index >= HIGH_MERGE_SHAKE_LEVEL:
		_screen_shake(7.0, 0.35)
	if index == DinoChain.level_count() - 1:
		Input.vibrate_handheld(200)
		_show_legendary_banner()


## Quick expanding radial flash at the merge point, played right as the
## two source dinos vanish and the merged one is born -- masks that
## swap instant with a "morph" pulse instead of a bare pop. Built from a
## GradientTexture2D purely in code, no art asset needed.
func spawn_merge_flash(global_pos: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 0.9, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 0.9, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128

	var flash := Sprite2D.new()
	gameplay_root.add_child(flash)
	flash.texture = tex
	flash.global_position = global_pos
	flash.modulate.a = 0.0
	flash.scale = Vector2(0.3, 0.3)
	flash.z_index = 10

	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 1.0, 0.05)
	(
		tween
		. parallel()
		. tween_property(flash, "scale", Vector2(1.4, 1.4), 0.18)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)


func _spawn_floating_score(global_pos: Vector2, amount: int) -> void:
	var popup := FLOATING_SCORE_SCENE.instantiate()
	gameplay_root.add_child(popup)
	popup.global_position = global_pos + Vector2(0, -20)
	popup.text = "+%d" % amount


func _spawn_merge_particles(global_pos: Vector2, index: int) -> void:
	var particles := CPUParticles2D.new()
	gameplay_root.add_child(particles)
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


## Big transient banner for the rarest possible event: creating the
## very last (highest) level in the chain via a merge. Timed alongside
## the screen shake that already fires for this same top tier.
func _show_legendary_banner() -> void:
	legendary_banner.modulate.a = 0.0
	legendary_banner.scale = Vector2(0.5, 0.5)
	legendary_banner.visible = true
	await get_tree().process_frame
	legendary_banner.pivot_offset = legendary_banner.size / 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(legendary_banner, "modulate:a", 1.0, 0.2)
	(
		tween
		. tween_property(legendary_banner, "scale", Vector2.ONE, 0.3)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.set_parallel(false)
	tween.tween_interval(1.2)
	tween.tween_property(legendary_banner, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): legendary_banner.visible = false)


func _on_sound_toggle_pressed() -> void:
	ui_click_sfx.play()
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus, not AudioServer.is_bus_mute(master_bus))
	_update_sound_icon()


func _update_sound_icon() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	var muted := AudioServer.is_bus_mute(master_bus)
	sound_toggle_btn.texture_normal = SOUND_OFF_ICON if muted else SOUND_ON_ICON


## One dispatch point for the Android back button / desktop Escape
## (both map to the built-in "ui_cancel" action), rather than every
## overlay listening for it independently -- keeps the priority between
## nested overlays explicit instead of depending on input propagation
## order between sibling Controls.
func _handle_back_button() -> void:
	if tutorial_panel.visible:
		tutorial_panel.dismiss()
		return
	if pause_settings_panel.visible:
		pause_settings_panel.close()
		return
	if confirm_restart_panel.visible:
		_on_confirm_restart_cancel()
		return
	if pause_panel.visible:
		_on_pause_resume_pressed()
		return
	if GameManager.is_game_over:
		return
	_on_pause_pressed()


func _on_pause_pressed() -> void:
	if GameManager.is_game_over or pause_panel.visible:
		return
	ui_click_sfx.play()
	get_tree().paused = true
	pause_main_buttons.visible = true
	confirm_restart_panel.visible = false
	pause_settings_panel.visible = false
	pause_panel.visible = true


func _on_pause_resume_pressed() -> void:
	ui_click_sfx.play()
	get_tree().paused = false
	pause_panel.visible = false


func _on_pause_restart_pressed() -> void:
	ui_click_sfx.play()
	pause_main_buttons.visible = false
	confirm_restart_panel.visible = true


func _on_confirm_restart_cancel() -> void:
	ui_click_sfx.play()
	confirm_restart_panel.visible = false
	pause_main_buttons.visible = true


func _on_confirm_restart_yes() -> void:
	ui_click_sfx.play()
	pause_panel.visible = false
	get_tree().paused = false
	AdsManager.register_game_over_and_continue(func(): get_tree().reload_current_scene())


func _on_pause_settings_pressed() -> void:
	ui_click_sfx.play()
	pause_main_buttons.visible = false
	pause_settings_panel.open()


func _on_pause_settings_closed() -> void:
	pause_main_buttons.visible = true


func _on_pause_menu_pressed() -> void:
	ui_click_sfx.play()
	get_tree().paused = false
	AdsManager.register_game_over_and_continue(
		func(): SceneTransition.change_scene("res://scenes/MainMenu.tscn")
	)


func _on_score_changed(new_score: int) -> void:
	score_label.text = "Pontos: %d" % new_score
	_update_background(new_score)


## Only swaps the texture when crossing into a new tier, not every
## score change -- background.texture assignment isn't free and most
## score_changed events don't cross a threshold.
func _update_background(current_score: int) -> void:
	var tier := 0
	if current_score >= BG_HIGH_SCORE:
		tier = 2
	elif current_score >= BG_MID_SCORE:
		tier = 1
	if tier == _bg_tier:
		return
	_bg_tier = tier
	match tier:
		0:
			background.texture = BG_BASE
		1:
			background.texture = BG_MID
		2:
			background.texture = BG_HIGH


func _on_game_over() -> void:
	final_score_label.text = "Pontuação final: %d" % GameManager.score
	best_label.text = "Recorde pessoal: %d" % GameManager.high_score
	record_label.visible = GameManager.is_new_record
	continue_btn.visible = AdsManager.is_rewarded_ad_ready()
	continue_btn.disabled = false
	restart_button.disabled = false
	pause_button.visible = false

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
	pause_button.visible = true
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
