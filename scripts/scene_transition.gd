extends CanvasLayer

## Autoload. Fades to black, swaps the active scene, then fades back in.
## Survives scene changes (it's an autoload), so it's the one thing that
## can visually bridge MainMenu <-> Main without a hard cut. Runs even
## while the tree is paused (leaving pause via "voltar ao menu" needs
## the fade to still animate).

var _busy: bool = false

@onready var fade_rect: ColorRect = $FadeRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	# Bound to self, which is PROCESS_MODE_ALWAYS, so this keeps
	# animating even mid-pause (leaving pause via "voltar ao menu").
	var fade_out := create_tween()
	fade_out.tween_property(fade_rect, "color:a", 1.0, 0.25)
	await fade_out.finished

	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame

	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "color:a", 0.0, 0.25)
	await fade_in.finished
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
