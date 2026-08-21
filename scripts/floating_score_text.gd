extends Node2D

## Disposable "+N" popup shown where a merge just happened: rises and
## fades, then frees itself. No physics, no collision -- purely visual.

var text: String = ""
var color: Color = Color(1.0, 0.93, 0.6)


func _ready() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(self, "position:y", position.y - 54.0, 0.85)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(self, "modulate:a", 0.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var font_size := 26
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := Vector2(-size.x / 2.0, 0.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
