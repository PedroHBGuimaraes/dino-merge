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
		var tex_size := lvl.texture.get_size()
		var largest_side := max(tex_size.x, tex_size.y, 1.0)
		var scale_factor := (lvl.radius * 2.0) / largest_side
		sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		sprite.visible = false
	queue_redraw()


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
	var top_y := global_position.y - radius
	if top_y < GameManager.DANGER_LINE_Y and linear_velocity.length() < SETTLE_SPEED:
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
		main.spawn_merged_dino(next_index, mid)
	other.queue_free()
	queue_free()
