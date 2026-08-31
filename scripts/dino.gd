extends RigidBody2D

## A single dino item in the merge chain. Falls under gravity, merges with
## another dino of the same level on contact, and contributes to the
## "stuck above the danger line" game-over timer.

const SETTLE_SPEED := 12.0
## Seconds each idle frame stays on screen -- slow enough to read as a
## gentle breathing loop rather than a flicker.
const IDLE_FRAME_DURATION := 0.35
## Seconds the two dinos visibly slide together and brighten before the
## merge actually resolves -- was 0.1s (barely readable as "two things
## joining" rather than an instant swap); long enough now to read
## clearly without dragging the pace of a fast-paced cascade down.
const APPROACH_DURATION := 0.22
## Sprites are pushed past white (values >1 brighten a non-fully-
## saturated pixel under normal multiply blending) toward a warm gold
## as the approach peaks, then a real additive glow (main.gd's
## spawn_pre_merge_glow, spawn_merge_flash) carries the rest of the
## "brilho" the merge itself can't fake without a real light/bloom pass.
const APPROACH_GLOW_COLOR := Color(1.6, 1.4, 0.9)

## A dropped dino kicks up a small puff of sand the first time it hits the
## pile/floor -- only once, and only if it landed with real downward speed
## (a dino that just rolled into contact shouldn't puff).
const DUST_TEXTURE := preload("res://assets/particles/sand_dust.png")
const DUST_MIN_LANDING_SPEED := 260.0

var level_index: int = 0
var _merging: bool = false
var _over_line_time: float = 0.0
## Distance from center to the sprite's top edge, used by the danger-line
## check below for the circle fallback only (a circle's top is always
## `radius` straight up regardless of rotation, so no per-frame work is
## needed there).
var _top_offset: float = 0.0
## Collision hull vertices (local space, already scaled), used instead
## of `_top_offset` for textured dinos: since dinos can now rotate and
## settle at any angle, the true topmost point of an irregular
## silhouette isn't a fixed offset from center any more -- it has to be
## re-derived each frame from the body's current rotation. Empty for
## the circle-collider fallback.
var _collision_points: PackedVector2Array = PackedVector2Array()
var _idle_frames: Array[Texture2D] = []
var _idle_frame_index: int = 0
var _idle_elapsed: float = 0.0
var _has_landed: bool = false
## True only during the brief post-merge growth animation (baby -> young ->
## adult). Blocks the idle-frame loop in _process so it doesn't overwrite
## the growth textures mid-animation.
var _birthing: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func setup(index: int) -> void:
	level_index = index
	var lvl := DinoChain.get_level(index)
	var scale_factor: float = (lvl.radius * 2.0) / max(lvl.content_size, 1.0)
	_top_offset = lvl.radius
	if lvl.texture and not lvl.collision_hull.is_empty():
		# Convex hull of the real sprite silhouette (see
		# DinoChain._load_collision_data) instead of a circle -- lets the
		# collider sit much closer to each dino's actual drawn shape than
		# the enclosing circle did, which left big gaps around non-square
		# sprites (wide-winged pterosaurs, flat marine reptiles). A single
		# convex shape, not a multi-piece decomposition: an earlier
		# version used one CollisionPolygon2D per decomposed piece for an
		# even tighter (near-pixel-perfect) fit, but adjacent pieces of
		# the same body share edges, and once dinos could rotate freely a
		# contact landing near one of those internal seams occasionally
		# got inconsistent normals from the two pieces -- the solver
		# resolved that into a huge separation impulse (a dino launching
		# off-screen at high speed, sometimes tunneling through a wall).
		# A single shape has no internal seams, so that class of bug
		# can't happen; the trade is losing concave detail (e.g. the gap
		# under a raised tail reads as solid instead of empty).
		_collision_points.clear()
		var hull_shape := ConvexPolygonShape2D.new()
		var scaled := PackedVector2Array()
		for point in lvl.collision_hull:
			var sp: Vector2 = point * scale_factor
			scaled.append(sp)
			_collision_points.append(sp)
		hull_shape.points = scaled
		collision.shape = hull_shape
	else:
		var shape := CircleShape2D.new()
		shape.radius = lvl.radius
		collision.shape = shape
	if lvl.texture:
		sprite.texture = lvl.texture
		sprite.visible = true
		# Scale by the sprite's actual content size, not the raw canvas --
		# see DinoLevel.content_size.
		sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		sprite.visible = false
	_idle_frames = lvl.idle_frames
	_idle_frame_index = 0
	_idle_elapsed = 0.0
	queue_redraw()


## Played when this dino is born from a merge (not when freshly dropped --
## the physical fall already reads as "arrival" for those). If the species
## has life-stage art it hatches small as a baby and grows through the
## juvenile form to full size in ~0.3s; otherwise it falls back to the
## old squash-and-recover pop. Never overshoots the final scale.
func play_birth_animation() -> void:
	if not sprite.visible:
		return
	var lvl := DinoChain.get_level(level_index)
	var base_scale := sprite.scale

	if lvl.idle_frames_baby.is_empty():
		sprite.scale = Vector2(base_scale.x, base_scale.y * 0.6)
		var pop := create_tween()
		pop.tween_property(sprite, "scale", base_scale, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(
			Tween.EASE_OUT
		)
		return

	_birthing = true
	var young := lvl.idle_frames_young if not lvl.idle_frames_young.is_empty() else lvl.idle_frames
	sprite.texture = lvl.idle_frames_baby[0]
	sprite.scale = base_scale * 0.5

	var tween := create_tween()
	(
		tween
		. tween_property(sprite, "scale", base_scale * 0.76, 0.14)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	tween.tween_callback(func(): sprite.texture = young[0])
	tween.tween_property(sprite, "scale", base_scale, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_callback(_finish_birth)


func _finish_birth() -> void:
	_birthing = false
	if not _idle_frames.is_empty():
		sprite.texture = _idle_frames[0]
	_idle_frame_index = 0
	_idle_elapsed = 0.0


## Low, brief sand puff at the dino's feet on its first real landing.
## Parented to the Dinos container (not self) so it stays put while the
## body keeps settling, and freed on its own after the burst.
func _spawn_landing_dust() -> void:
	var lvl := DinoChain.get_level(level_index)
	var dust := CPUParticles2D.new()
	get_parent().add_child(dust)
	dust.global_position = global_position + Vector2(0, _top_offset * 0.85)
	dust.z_index = -1
	dust.texture = DUST_TEXTURE
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.amount = 8 + int(lvl.radius / 12.0)
	dust.lifetime = 0.45
	dust.direction = Vector2.UP
	dust.spread = 90.0
	dust.gravity = Vector2(0, 140)
	dust.initial_velocity_min = 25.0
	dust.initial_velocity_max = 55.0 + lvl.radius * 0.4
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 0.9
	dust.damping_min = 30.0
	dust.damping_max = 60.0
	dust.color = Color(0.82, 0.68, 0.48, 0.7)
	dust.emitting = true
	var life := dust.lifetime
	get_tree().create_timer(life + 0.3).timeout.connect(dust.queue_free)


## Called on the dinos around a merge point: a shove away from it plus a
## quick sprite squash, so a merge visibly ripples through the pile
## instead of the pile just silently absorbing it.
func nudge(from: Vector2) -> void:
	if _merging or freeze or not sprite.visible:
		return
	var away := global_position - from
	var dist := away.length()
	if dist < 0.01:
		return
	apply_central_impulse(away.normalized() * clampf(140.0 - dist * 0.3, 20.0, 140.0))
	var base := sprite.scale
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2(base.x * 1.12, base.y * 0.88), 0.06)
	t.tween_property(sprite, "scale", base, 0.12).set_trans(Tween.TRANS_SINE)


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _merging or _birthing or _idle_frames.size() <= 1:
		return
	_idle_elapsed += delta
	if _idle_elapsed < IDLE_FRAME_DURATION:
		return
	_idle_elapsed -= IDLE_FRAME_DURATION
	_idle_frame_index = (_idle_frame_index + 1) % _idle_frames.size()
	sprite.texture = _idle_frames[_idle_frame_index]


func _draw() -> void:
	var lvl := DinoChain.get_level(level_index)
	if lvl.texture:
		return
	draw_circle(Vector2.ZERO, lvl.radius, lvl.color)
	draw_arc(Vector2.ZERO, lvl.radius, 0.0, TAU, 32, Color.BLACK, 2.0)
	var font := ThemeDB.fallback_font
	var font_size := 12
	var text := lvl.dino_name
	var text_size := font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_CENTER, lvl.radius * 1.8, font_size
	)
	draw_string(
		font,
		Vector2(-text_size.x / 2.0, text_size.y / 4.0),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		lvl.radius * 1.8,
		font_size,
		Color.BLACK
	)


func _physics_process(delta: float) -> void:
	if GameManager.is_game_over or _merging:
		return
	# World space == design space directly (GameplayRoot no longer scales
	# -- see main.gd's _fit_gameplay_to_viewport -- so no conversion is
	# needed here, and this deliberately does NOT read scale off `self`:
	# RigidBody2D does not support inherited *or* own scale for physics/
	# render sync, so that value can't be trusted for a physics body).
	var top_y: float
	if _collision_points.is_empty():
		top_y = global_position.y - _top_offset
	else:
		# Dinos can rotate and land at any angle now, so the topmost point
		# of an irregular silhouette has to be re-derived from the body's
		# current rotation every frame instead of a fixed offset.
		top_y = INF
		for p in _collision_points:
			top_y = minf(top_y, to_global(p).y)
	if top_y < GameManager.danger_line_y and linear_velocity.length() < SETTLE_SPEED:
		_over_line_time += delta
		if _over_line_time >= GameManager.GAME_OVER_DELAY:
			GameManager.trigger_game_over()
	else:
		_over_line_time = 0.0


func _on_body_entered(body: Node) -> void:
	if not _has_landed and not _merging and linear_velocity.y >= DUST_MIN_LANDING_SPEED:
		_has_landed = true
		_spawn_landing_dust()

	if _merging or not (body is RigidBody2D) or not body.is_in_group("dino"):
		return
	var other := body as RigidBody2D
	if other.get("_merging") or other.get("level_index") != level_index:
		return
	# Only the lower-id instance drives the merge so a pair never merges twice.
	if get_instance_id() < other.get_instance_id():
		_merging = true
		other.set("_merging", true)
		# body_entered fires while the physics server is still flushing
		# collision queries -- it refuses synchronous physics-state
		# changes at that point (freezing a body, add_child on a
		# RigidBody2D, reassigning a collision shape). Deferring the
		# whole call runs it right after the flush finishes, which is
		# safe, and _do_merge needs that safety for longer than a single
		# call now that it animates the approach before merging.
		_do_merge.call_deferred(other)


## Brief approach-and-merge sequence: the two dinos are pulled a bit
## toward their midpoint (with a light shrink, like they're being
## sucked together) instead of vanishing on contact, brightening as a
## soft glow blooms between them, then a sharper flash plays right as
## the merged dino is born -- play_birth_animation() grows it in
## landing pose.
func _do_merge(other: RigidBody2D) -> void:
	if not is_instance_valid(other):
		return
	freeze = true
	other.freeze = true
	linear_velocity = Vector2.ZERO
	other.linear_velocity = Vector2.ZERO

	var main := get_tree().current_scene
	var mid := (global_position + other.global_position) / 2.0
	var my_target: Vector2 = global_position.lerp(mid, 0.4)
	var other_target: Vector2 = other.global_position.lerp(mid, 0.4)
	main.spawn_pre_merge_glow(mid, APPROACH_DURATION)

	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(self, "global_position", my_target, APPROACH_DURATION)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	(
		tween
		. tween_property(other, "global_position", other_target, APPROACH_DURATION)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_property(sprite, "scale", sprite.scale * 0.75, APPROACH_DURATION)
	tween.tween_property(other.sprite, "scale", other.sprite.scale * 0.75, APPROACH_DURATION)
	(
		tween
		. tween_property(sprite, "modulate", APPROACH_GLOW_COLOR, APPROACH_DURATION)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	(
		tween
		. tween_property(other.sprite, "modulate", APPROACH_GLOW_COLOR, APPROACH_DURATION)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	await tween.finished

	if not is_instance_valid(other):
		return

	var lvl := DinoChain.get_level(level_index)
	var next_index := level_index + 1
	# Combo multiplier is resolved here, at the moment each merge in a
	# cascade actually lands, so chained merges are timed consistently
	# regardless of how long their approach/flash animation took.
	var combo_multiplier := GameManager.register_combo_step()
	var combo_count := GameManager.combo_count
	var awarded_score := int(round(lvl.score_value * combo_multiplier))
	GameManager.add_score(awarded_score)
	GameManager.register_merge(next_index)

	main.spawn_merge_flash(mid)
	if next_index < DinoChain.level_count():
		main.spawn_merged_dino(next_index, mid, awarded_score, combo_count)

	other.queue_free()
	queue_free()
