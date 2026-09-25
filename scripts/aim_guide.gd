extends Node2D

## A directional guide only: it does not promise a physics landing position.
var main: Node2D
var endpoint := 1190.0


func _physics_process(_delta: float) -> void:
	visible = main.can_drop and not GameManager.is_game_over and not get_tree().paused
	if not visible:
		return
	var start := Vector2(main.preview_x, main.SPAWN_Y + 65.0)
	var query := PhysicsRayQueryParameters2D.create(start, Vector2(start.x, 1190.0))
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	endpoint = hit.position.y if not hit.is_empty() else 1190.0
	queue_redraw()


func _draw() -> void:
	if main == null:
		return
	var x: float = main.preview_x
	var y: float = main.SPAWN_Y + 65.0
	var color := Color(0.65, 0.84, 0.78, 0.34)
	while y < endpoint - 8:
		draw_line(Vector2(x, y), Vector2(x, minf(y + 12, endpoint - 8)), color, 2.0, true)
		y += 26
	draw_line(Vector2(x - 10, endpoint - 4), Vector2(x + 10, endpoint - 4), color, 2.0, true)
