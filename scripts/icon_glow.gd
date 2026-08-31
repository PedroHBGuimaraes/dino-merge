extends TextureRect

## Slow additive-blended breathing glow placed behind a TopBar icon
## button (see Main.tscn's SoundToggleButton/PauseButton/InfoButton) --
## the "neon" pulse is what reads as "alive"/tappable at a glance,
## versus a static icon that blends into the background.

## Additive blending barely shows up against an already-bright/warm
## background (this sits over the sky gradient in the TopBar, not a
## dark area) unless pushed fairly strong -- these were tuned up from a
## more "tasteful" 0.35-0.85 that read as basically invisible there.
const MIN_ALPHA := 0.55
const MAX_ALPHA := 1.0
const PERIOD := 1.8


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate:a", MAX_ALPHA, PERIOD / 2.0)
	tween.tween_property(self, "modulate:a", MIN_ALPHA, PERIOD / 2.0)
