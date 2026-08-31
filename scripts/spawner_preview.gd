extends Node2D

## Purely visual: shows which dino will drop next, follows the player's
## drag before release. No physics body until the player actually drops it.
## Drawn at the exact same scale dino.gd uses for the real dropped sprite
## (see DinoLevel.content_size) so the held preview never mismatches the
## size the dino actually lands at.

## Gentle vertical bob so the held dino reads as "alive / ready", not a
## decal stuck to the top of the pit. Amplitude is in design px.
const BOB_AMPLITUDE := 4.0
const BOB_SPEED := 2.4

var level_index: int = 0
var _base_y: float = 0.0
var _bob_t: float = 0.0


func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	_bob_t += delta * BOB_SPEED
	position.y = _base_y + sin(_bob_t) * BOB_AMPLITUDE


func set_level(index: int) -> void:
	level_index = index
	queue_redraw()
	# Quick "loaded" pop each time a fresh dino drops into the spawner.
	scale = Vector2(0.72, 0.72)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


func _draw() -> void:
	var lvl := DinoChain.get_level(level_index)
	if lvl.texture:
		var tex_size := lvl.texture.get_size()
		# Scale by the sprite's actual content size, not the raw canvas --
		# see DinoLevel.content_size.
		var scale_factor: float = (lvl.radius * 2.0) / max(lvl.content_size, 1.0)
		var draw_size: Vector2 = tex_size * scale_factor
		draw_texture_rect(lvl.texture, Rect2(-draw_size / 2.0, draw_size), false)
	else:
		draw_circle(Vector2.ZERO, lvl.radius, lvl.color)
		draw_arc(Vector2.ZERO, lvl.radius, 0.0, TAU, 32, Color.BLACK, 2.0)
