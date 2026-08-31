extends Node2D

const DINO_SCENE := preload("res://scenes/Dino.tscn")
const FLOATING_SCORE_SCENE := preload("res://scenes/FloatingScoreText.tscn")

## The whole container/dinos/spawner subtree was designed against this
## reference canvas, and lives directly in it -- GameplayRoot itself is
## never scaled or repositioned (unlike an earlier version of this
## file). Fitting that canvas to whatever the actual viewport is (see
## _fit_gameplay_to_viewport) happens purely through the Camera2D's zoom
## and position instead: RigidBody2D/StaticBody2D silently ignore any
## scale inherited from an ancestor for both physics and rendering, so
## scaling GameplayRoot used to leave every dino (and the walls/floor)
## rendering as if that scale weren't applied at all -- ~1/scale times
## too big. Camera zoom is a pure rendering-time transform and doesn't
## have that problem.
const DESIGN_SIZE := Vector2(720.0, 1280.0)

const LEFT_X := 40.0
const RIGHT_X := 680.0
const SPAWN_Y := 100.0
const DANGER_LINE_Y_DESIGN := 220.0
## Real screen pixels (not design space -- the UI CanvasLayer's TopBar
## sits at fixed pixel offsets, unscaled) reserved above the pit so the
## score/next-dino panel never overlaps GameplayRoot. Must stay >=
## scenes/Main.tscn's TopBar offset_bottom (94) plus a small gap --
## otherwise a dino resting near the top of the pit renders partly
## behind that panel and is unreadable.
const TOP_UI_MARGIN := 100.0
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

## The dino currently loaded in the spawner (dragged/dropped on release).
var current_level_index: int = 0
## The one that will load next, after `current_level_index` drops --
## shown ahead of time via next_icon so the player can plan the drop
## after this one, not just the one they're already holding.
var next_level_index: int = 0
var can_drop: bool = true
var preview_x: float = 360.0
var _bg_tier: int = 0
## Design-space-to-viewport-pixel zoom factor, applied via the camera
## (see _fit_gameplay_to_viewport) rather than by scaling GameplayRoot.
## RigidBody2D/StaticBody2D do not support inherited scale for physics
## or render sync -- Godot silently treats a scaled ancestor as if it
## weren't there for any physics body underneath it, which used to
## render every dropped dino ~1/_game_scale times too big (and would
## have equally broken the walls'/floor's collision-vs-visual
## alignment) while GameplayRoot itself carried that scale instead.
var _game_scale: float = 1.0
var _shake_strength := 0.0
var _shake_until := 0.0
var _shaking := false

@onready var camera: Camera2D = $Camera2D
@onready var background: TextureRect = $BackgroundLayer/Background
@onready var gameplay_root: Node2D = $GameplayRoot
@onready var pit_visual: Node2D = $GameplayRoot/Container/PitVisual
@onready var dinos: Node2D = $GameplayRoot/Dinos
@onready var spawner_preview: Node2D = $GameplayRoot/SpawnerPreview
@onready var score_label: Label = $UI/ScoreRow/ScoreLabel
@onready var next_icon: TextureRect = $UI/NextRow/Icon
@onready var sound_toggle_btn: TextureButton = $UI/SoundToggleButton
@onready var pause_button: TextureButton = $UI/PauseButton
@onready var info_button: TextureButton = $UI/InfoButton
@onready var sequence_panel: Control = $UI/SequencePanel
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
@onready var game_over_menu_btn: Button = $UI/GameOverPanel/CenterContainer/VBoxContainer/MenuButton
@onready var reached_row: HBoxContainer = $UI/GameOverPanel/CenterContainer/VBoxContainer/ReachedRow
@onready
var reached_icon: TextureRect = $UI/GameOverPanel/CenterContainer/VBoxContainer/ReachedRow/Icon
@onready var reached_label: Label = $UI/GameOverPanel/CenterContainer/VBoxContainer/ReachedRow/Label
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
	game_over_menu_btn.pressed.connect(_on_pause_menu_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	sound_toggle_btn.pressed.connect(_on_sound_toggle_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	info_button.pressed.connect(_on_info_pressed)
	pause_resume_btn.pressed.connect(_on_pause_resume_pressed)
	pause_restart_btn.pressed.connect(_on_pause_restart_pressed)
	pause_settings_btn.pressed.connect(_on_pause_settings_pressed)
	pause_menu_btn.pressed.connect(_on_pause_menu_pressed)
	confirm_restart_yes_btn.pressed.connect(_on_confirm_restart_yes)
	confirm_cancel_btn.pressed.connect(_on_confirm_restart_cancel)
	pause_settings_panel.closed.connect(_on_pause_settings_closed)
	sequence_panel.closed.connect(_on_sequence_panel_closed)
	_update_sound_icon()
	music.finished.connect(func(): music.play())
	randomize()
	game_over_panel.visible = false
	pause_panel.visible = false
	confirm_restart_panel.visible = false
	pause_settings_panel.visible = false
	legendary_banner.visible = false
	tutorial_panel.visible = false
	sequence_panel.visible = false
	current_level_index = _random_spawn_level()
	next_level_index = _random_spawn_level()
	_update_preview()
	# GameManager.reset() emits score_changed before the connect above, so
	# seed the HUD label once here (also picks the right locale on boot).
	_on_score_changed(GameManager.score)

	if not GameManager.has_seen_tutorial:
		tutorial_panel.open()


## Scales + centers GameplayRoot so the fixed-coordinate container/dinos/
## spawner subtree (designed for DESIGN_SIZE) always fits fully inside
## whatever the actual viewport turns out to be -- otherwise anything
## set up assuming a 720x1280 canvas (walls at x=680, floor at y=1200,
## ...) simply falls outside a smaller one and is never seen.
## GameplayRoot itself is left unscaled/unpositioned (identity transform)
## on purpose: it -- and everything under it, including the dino/wall/
## floor physics bodies -- lives directly in "design space" units, which
## this function makes equal to world space 1:1. The fit-to-viewport
## zoom happens only at the camera, which is a pure rendering-time
## transform and so is the one place this adjustment can live without
## quietly breaking physics bodies (see the _game_scale comment above).
func _fit_gameplay_to_viewport() -> void:
	var vp_size := get_viewport_rect().size
	var available_height: float = max(vp_size.y - TOP_UI_MARGIN, 1.0)
	_game_scale = min(vp_size.x / DESIGN_SIZE.x, available_height / DESIGN_SIZE.y)
	camera.zoom = Vector2(_game_scale, _game_scale)
	# Center horizontally as before, but any vertical slack is only ever
	# added *below* TOP_UI_MARGIN, never eating into it -- otherwise a
	# device whose aspect ratio leaves little slack could still let the
	# pit creep back up under the TopBar. Camera2D's anchor_mode is
	# FIXED_TOP_LEFT (set on the node), so `camera.position` maps to the
	# viewport's top-left corner, not its center -- these formulas are
	# the inverse of `screen = (world - camera.position) * zoom`, solved
	# for the camera.position that puts design (360, 0) at screen
	# (vp_size.x/2, TOP_UI_MARGIN + extra_height/2).
	var extra_height: float = available_height - DESIGN_SIZE.y * _game_scale
	camera.position = Vector2(
		360.0 - (vp_size.x / 2.0) / _game_scale, -(TOP_UI_MARGIN + extra_height / 2.0) / _game_scale
	)
	GameManager.danger_line_y = DANGER_LINE_Y_DESIGN


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
## coordinates (LEFT_X..RIGHT_X) are design/world-space, mapped to the
## viewport only by the camera's zoom/position -- this is the inverse of
## that same `screen = (world - camera.position) * zoom` mapping used in
## _fit_gameplay_to_viewport.
func _to_gameplay_x(viewport_x: float) -> float:
	return camera.position.x + viewport_x / _game_scale


func _move_preview(x: float) -> void:
	var radius := DinoChain.get_level(current_level_index).radius
	preview_x = clamp(x, LEFT_X + radius, RIGHT_X - radius)
	spawner_preview.position.x = preview_x


func _drop() -> void:
	if not can_drop or GameManager.is_game_over:
		return
	can_drop = false
	var dino := DINO_SCENE.instantiate()
	dinos.add_child(dino)
	dino.add_to_group("dino")
	# preview_x/SPAWN_Y are already world-space (== design-space, since
	# GameplayRoot is unscaled -- see _fit_gameplay_to_viewport), same as
	# spawner_preview.position, so no conversion is needed here.
	dino.global_position = Vector2(preview_x, SPAWN_Y)
	dino.setup(current_level_index)
	GameManager.mark_species_discovered(current_level_index)
	drop_sfx.play()
	current_level_index = next_level_index
	next_level_index = _random_spawn_level()
	_update_preview()
	await get_tree().create_timer(0.45).timeout
	can_drop = true


func _update_preview() -> void:
	spawner_preview.set_level(current_level_index)
	spawner_preview.position.x = preview_x
	next_icon.texture = DinoChain.get_level(next_level_index).texture


func spawn_merged_dino(
	index: int, global_pos: Vector2, score_awarded: int, combo_count: int = 1
) -> void:
	var dino := DINO_SCENE.instantiate()
	dinos.add_child(dino)
	dino.add_to_group("dino")
	dino.global_position = global_pos
	dino.setup(index)
	GameManager.mark_species_discovered(index)
	dino.play_birth_animation()

	# Pitch (and a touch of volume) climbs with the merged level, so a
	# low-tier merge sounds subtly different from a top-of-the-chain one
	# -- plus an extra rising bump per chained combo step, same idea as
	# the level pitch but keyed to combo instead, so a fast cascade
	# audibly "climbs" merge to merge. Clamped so a long combo doesn't
	# end up an inaudible chipmunk squeal.
	var level_fraction := float(index) / float(DinoChain.level_count() - 1)
	merge_sfx.pitch_scale = clampf(1.0 + level_fraction * 1.1 + 0.12 * (combo_count - 1), 0.5, 2.5)
	merge_sfx.volume_db = level_fraction * 4.0
	merge_sfx.play()

	_spawn_floating_score(global_pos, score_awarded)
	if combo_count >= 2:
		_spawn_combo_text(global_pos, combo_count)
	_spawn_merge_particles(global_pos, index)
	_spawn_shockwave(global_pos, index)

	# Subtle by default, stronger the higher the merged level -- and the
	# very top of the chain gets a distinctly longer buzz on top of its
	# own shake + banner, since that merge is rare enough to deserve a
	# more noticeable cue than "just a bigger version of every other one".
	GameManager.vibrate(int(20 + level_fraction * 60))

	if index >= HIGH_MERGE_SHAKE_LEVEL:
		_screen_shake(7.0, 0.35)
	if index == DinoChain.level_count() - 1:
		GameManager.vibrate(200)
		_show_legendary_banner()


## Soft glow that blooms at the meeting point while the two merging
## dinos slide together (see dino.gd's _do_merge's approach tween) --
## builds anticipation into the sharper spawn_merge_flash() burst that
## fires right after, so the merge reads as "charging up, then
## releasing" instead of a flat instant swap. Additive-blended (same
## trick as icon_glow.gd) so it brightens what's behind it like a real
## light bloom rather than covering it with a flat colored disc.
func spawn_pre_merge_glow(global_pos: Vector2, duration: float) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.85, 0.5, 1.0))
	gradient.set_color(1, Color(1.0, 0.85, 0.5, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 96
	tex.height = 96

	var glow := Sprite2D.new()
	gameplay_root.add_child(glow)
	glow.texture = tex
	glow.global_position = global_pos
	glow.modulate.a = 0.0
	glow.scale = Vector2(0.25, 0.25)
	glow.z_index = 9
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat

	var tween := create_tween()
	tween.tween_property(glow, "modulate:a", 0.9, duration).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	(
		tween
		. parallel()
		. tween_property(glow, "scale", Vector2(0.95, 0.95), duration)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_property(glow, "modulate:a", 0.0, 0.12)
	tween.tween_callback(glow.queue_free)


## Quick expanding radial flash at the merge point, played right as the
## two source dinos vanish and the merged one is born -- masks that
## swap instant with a "morph" pulse instead of a bare pop. Built from a
## GradientTexture2D purely in code, no art asset needed. Additive-
## blended for a real bloom/glow look instead of a flat white disc.
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
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = mat

	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 1.0, 0.05)
	(
		tween
		. parallel()
		. tween_property(flash, "scale", Vector2(1.7, 1.7), 0.2)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(flash, "modulate:a", 0.0, 0.16)
	tween.tween_callback(flash.queue_free)


## Expanding ring that snaps out from the merge point -- a crisper,
## directional companion to the soft radial flash. Built from a radial
## GradientTexture2D (transparent core, bright annulus, transparent edge),
## additive-blended, scaled up and faded in one short tween. Bigger and a
## touch warmer the higher the merged level.
func _spawn_shockwave(global_pos: Vector2, index: int) -> void:
	var frac := float(index) / float(DinoChain.level_count() - 1)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 0.78, 1.0])
	var ring := Color(1.0, lerpf(0.9, 0.6, frac), lerpf(0.7, 0.3, frac), 1.0)
	gradient.colors = PackedColorArray([Color(ring, 0.0), Color(ring, 0.0), ring, Color(ring, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128

	var wave := Sprite2D.new()
	gameplay_root.add_child(wave)
	wave.texture = tex
	wave.global_position = global_pos
	wave.z_index = 9
	wave.scale = Vector2(0.2, 0.2)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	wave.material = mat

	var end_scale := 1.6 + frac * 1.8
	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(wave, "scale", Vector2(end_scale, end_scale), 0.34)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(wave, "modulate:a", 0.0, 0.34).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(wave.queue_free)


func _spawn_floating_score(global_pos: Vector2, amount: int) -> void:
	var popup := FLOATING_SCORE_SCENE.instantiate()
	gameplay_root.add_child(popup)
	popup.global_position = global_pos + Vector2(0, -20)
	popup.text = "+%d" % amount


## "COMBO xN!" callout for a chained merge (combo_count >= 2), reusing
## the same disposable popup as the score number but offset above it so
## the two don't overlap. Scale and color both ramp with combo_count,
## capped at the same combo tier (5) the score multiplier caps at --
## past that point a bigger combo doesn't need to shout any louder.
func _spawn_combo_text(global_pos: Vector2, combo_count: int) -> void:
	var popup := FLOATING_SCORE_SCENE.instantiate()
	gameplay_root.add_child(popup)
	popup.global_position = global_pos + Vector2(0, -46)
	popup.text = Loc.t("HUD_COMBO", {"count": combo_count})
	var t := clampf(float(combo_count - 2) / 3.0, 0.0, 1.0)  # 0 at combo 2, 1 at combo 5+
	popup.color = Color.from_hsv(lerpf(0.13, 0.0, t), 0.85, 1.0)
	popup.scale = Vector2.ONE * (1.0 + 0.15 * lerpf(0.0, 4.0, t))


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


## Overlapping shakes (two top-tier merges within ~0.35s) share one loop:
## each call bumps the active strength/deadline, and only the last loop
## still running snaps the camera back to rest -- so a second shake can't
## leave the camera parked at a random jittered offset.
func _screen_shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_until = maxf(_shake_until, float(Time.get_ticks_msec()) / 1000.0 + duration)
	if _shaking:
		return
	_shaking = true
	while float(Time.get_ticks_msec()) / 1000.0 < _shake_until:
		var s := _shake_strength
		camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
		await get_tree().create_timer(0.02).timeout
		_shake_strength = maxf(0.0, _shake_strength - strength * 0.02 / maxf(duration, 0.01))
	camera.offset = Vector2.ZERO
	_shake_strength = 0.0
	_shaking = false


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
	GameManager.set_master_muted(not GameManager.master_muted)
	_update_sound_icon()


func _update_sound_icon() -> void:
	sound_toggle_btn.texture_normal = SOUND_OFF_ICON if GameManager.master_muted else SOUND_ON_ICON


## One dispatch point for the Android back button / desktop Escape
## (both map to the built-in "ui_cancel" action), rather than every
## overlay listening for it independently -- keeps the priority between
## nested overlays explicit instead of depending on input propagation
## order between sibling Controls.
func _handle_back_button() -> void:
	if tutorial_panel.visible:
		tutorial_panel.dismiss()
		return
	if sequence_panel.visible:
		sequence_panel.dismiss()
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


## Opens the reference screen listing every dino in merge order (see
## sequence_panel.gd) -- pauses like PausePanel so the pile doesn't keep
## falling/merging while the player is just checking the chain.
func _on_info_pressed() -> void:
	ui_click_sfx.play()
	get_tree().paused = true
	sequence_panel.open()


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
	# Settings is the only in-run way to change language; the static labels
	# auto-translate but the score label is code-built, so refresh it here
	# (it's still hidden behind the pause overlay at this point).
	score_label.text = Loc.t("HUD_SCORE", {"score": GameManager.score})


func _on_sequence_panel_closed() -> void:
	get_tree().paused = false


func _on_pause_menu_pressed() -> void:
	ui_click_sfx.play()
	get_tree().paused = false
	AdsManager.register_game_over_and_continue(
		func(): SceneTransition.change_scene("res://scenes/MainMenu.tscn")
	)


func _on_score_changed(new_score: int) -> void:
	score_label.text = Loc.t("HUD_SCORE", {"score": new_score})
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
	# The opaque pit hides most of that swap now -- the visible "heating up"
	# is the ember glow inside the well (see pit.gd).
	pit_visual.set_intensity(tier / 2.0)


func _on_game_over() -> void:
	final_score_label.text = Loc.t("GAMEOVER_FINAL_SCORE", {"score": GameManager.score})
	best_label.text = Loc.t("GAMEOVER_BEST_SCORE", {"score": GameManager.high_score})
	record_label.visible = GameManager.is_new_record
	_update_reached_row()
	continue_btn.visible = AdsManager.is_rewarded_ad_ready()
	continue_btn.disabled = false
	restart_button.disabled = false
	pause_button.visible = false
	info_button.visible = false

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


## "You reached the {species}" line -- the highest dino a merge produced
## this run. Hidden if the player never merged anything.
func _update_reached_row() -> void:
	var lvl_index := GameManager.run_highest_level
	if lvl_index < 0:
		reached_row.visible = false
		return
	var lvl := DinoChain.get_level(lvl_index)
	reached_row.visible = true
	reached_icon.texture = lvl.texture
	reached_label.text = Loc.t("GAMEOVER_REACHED", {"species": lvl.dino_name})


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
	info_button.visible = true
	can_drop = true
	current_level_index = _random_spawn_level()
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
