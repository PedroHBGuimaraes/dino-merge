extends Node2D

## Flattened shadow ellipse marking where the currently-held dino would
## land. Drawn directly with draw_circle (flattened via a transform,
## same technique dino.gd already uses for its fallback circle) rather
## than a texture -- no new art asset needed, and avoids any texture/
## gradient edge cases at small on-screen sizes.

const SHADOW_COLOR := Color(0, 0, 0, 0.6)
const FLATTEN := 0.45
## Drawn a bit larger than the actual dino radius -- a shadow sized to
## match exactly reads as too subtle/thin at the small end of the size
## range to work as a landing-zone cue.
const SIZE_BOOST := 1.25

var radius: float = 20.0


func set_radius(r: float) -> void:
	if r == radius:
		return
	radius = r
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, FLATTEN))
	draw_circle(Vector2.ZERO, radius * SIZE_BOOST, SHADOW_COLOR)
