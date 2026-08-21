extends Node2D

## Purely visual: shows which dino will drop next, follows the player's
## drag before release. No physics body until the player actually drops it.

var level_index: int = 0

func set_level(index: int) -> void:
	level_index = index
	queue_redraw()

func _draw() -> void:
	var lvl := DinoChain.get_level(level_index)
	if lvl.texture:
		var tex_size := lvl.texture.get_size()
		var largest_side: float = max(tex_size.x, tex_size.y, 1.0)
		var scale_factor: float = (lvl.radius * 2.0) / largest_side
		var draw_size: Vector2 = tex_size * scale_factor
		draw_texture_rect(lvl.texture, Rect2(-draw_size / 2.0, draw_size), false)
	else:
		draw_circle(Vector2.ZERO, lvl.radius, lvl.color)
		draw_arc(Vector2.ZERO, lvl.radius, 0.0, TAU, 32, Color.BLACK, 2.0)
