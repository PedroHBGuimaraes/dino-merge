extends RigidBody2D

## A single dino item in the merge chain. Falls under gravity, merges with
## another dino of the same level on contact, and contributes to the
## "stuck above the danger line" game-over timer.

const SETTLE_SPEED := 12.0

var level_index: int = 0
var _merging: bool = false
var _over_line_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func setup(index: int) -> void:
	level_index = index
	var lvl := DinoChain.get_level(index)
	var shape := CircleShape2D.new()
	shape.radius = lvl.radius
	collision.shape = shape
	if lvl.texture:
		sprite.texture = lvl.texture
		sprite.visible = true
		# Scale by the sprite's actual content size, not the raw canvas --
		# see DinoLevel.content_size.
		var scale_factor: float = (lvl.radius * 2.0) / max(lvl.content_size, 1.0)
		sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		sprite.visible = false
	queue_redraw()


## Quick squash-and-overshoot pop, played when this dino was just born
## from a merge (not when freshly dropped -- the physical fall already
## reads as "arrival" for those).
func play_spawn_bounce() -> void:
	if not sprite.visible:
		return
	var base_scale := sprite.scale
	sprite.scale = base_scale * 0.25
	var tween := create_tween()
	(
		tween
		. tween_property(sprite, "scale", base_scale * 1.18, 0.1)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(sprite, "scale", base_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)


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
	var radius := DinoChain.get_level(level_index).radius
	# lvl.radius is in GameplayRoot's fixed design space; convert to real
	# global pixels via the node's cumulative scale before comparing
	# against danger_line_y, which is already a global-space value.
	var global_radius := radius * get_global_transform().get_scale().x
	var top_y := global_position.y - global_radius
	if top_y < GameManager.danger_line_y and linear_velocity.length() < SETTLE_SPEED:
		_over_line_time += delta
		if _over_line_time >= GameManager.GAME_OVER_DELAY:
			GameManager.trigger_game_over()
	else:
		_over_line_time = 0.0


func _on_body_entered(body: Node) -> void:
	if _merging or not (body is RigidBody2D) or not body.is_in_group("dino"):
		return
	var other := body as RigidBody2D
	if other.get("_merging") or other.get("level_index") != level_index:
		return
	# Only the lower-id instance drives the merge so a pair never merges twice.
	if get_instance_id() < other.get_instance_id():
		_merging = true
		other.set("_merging", true)
		_do_merge(other)


func _do_merge(other: RigidBody2D) -> void:
	var mid := (global_position + other.global_position) / 2.0
	var lvl := DinoChain.get_level(level_index)
	var next_index := level_index + 1
	GameManager.add_score(lvl.score_value)
	if next_index < DinoChain.level_count():
		var main := get_tree().current_scene
		# _do_merge runs from the body_entered signal, which fires while
		# the physics server is still flushing collision queries -- it
		# refuses synchronous physics-state changes at that point
		# (add_child on a RigidBody2D, then assigning its collision
		# shape in setup()). Deferring the whole call runs it right
		# after the flush finishes, which is safe.
		main.spawn_merged_dino.call_deferred(next_index, mid, lvl.score_value)
	other.queue_free()
	queue_free()
