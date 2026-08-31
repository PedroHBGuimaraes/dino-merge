extends CanvasLayer

## Ambient sky motion for the strip of open air above the pit: a couple of
## clouds drifting slowly sideways and, now and then, a far-off pterosaur
## gliding across. Purely decorative -- no gameplay, no input. Sits between
## the static background (layer -10) and the gameplay (layer 0).
##
## Placed in real viewport pixels (read live, re-read on resize) rather
## than gameplay design space: the gameplay is fit to the screen via the
## camera's zoom/offset (see main.gd) which a CanvasLayer does not inherit,
## and precise alignment with the pit isn't needed here -- the clouds just
## need to sit in the upper band of whatever the screen actually is.

const CLOUD_A := preload("res://assets/backgrounds/cloud_a.png")
const CLOUD_B := preload("res://assets/backgrounds/cloud_b.png")
const PTEROSAUR := preload("res://assets/backgrounds/pterosaur_far.png")

## Fraction of screen height the sky band occupies, measured from the top.
## The HUD panel and the top of the pit both live in here; clouds behind
## translucent UI read fine and the pit is drawn opaque over them.
const BAND_TOP_FRAC := 0.02
const BAND_BOTTOM_FRAC := 0.22

## px/sec, deliberately slow -- should register only at the edge of
## attention, never pull focus from the pile.
const CLOUD_SPEED_MIN := 4.0
const CLOUD_SPEED_MAX := 9.0
const PTEROSAUR_SPEED := 42.0
const PTEROSAUR_INTERVAL_MIN := 11.0
const PTEROSAUR_INTERVAL_MAX := 24.0

var _clouds: Array[Dictionary] = []
var _pterosaur: Sprite2D
var _pterosaur_dir := 1.0
var _next_pterosaur := 6.0
var _screen: Vector2


func _ready() -> void:
	layer = -9
	_screen = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_on_viewport_resized)

	var specs := [
		{"tex": CLOUD_A, "band": 0.1, "alpha": 0.75},
		{"tex": CLOUD_B, "band": 0.5, "alpha": 0.6},
		{"tex": CLOUD_A, "band": 0.8, "alpha": 0.4},
	]
	for spec in specs:
		var s := Sprite2D.new()
		s.texture = spec["tex"]
		s.centered = true
		s.modulate.a = spec["alpha"]
		add_child(s)
		s.position = Vector2(randf_range(0.0, _screen.x), _band_y(spec["band"]))
		(
			_clouds
			. append(
				{
					"node": s,
					"speed": randf_range(CLOUD_SPEED_MIN, CLOUD_SPEED_MAX),
					"band": spec["band"],
				}
			)
		)

	_pterosaur = Sprite2D.new()
	_pterosaur.texture = PTEROSAUR
	_pterosaur.centered = true
	_pterosaur.modulate.a = 0.5
	_pterosaur.visible = false
	add_child(_pterosaur)


func _band_y(t: float) -> float:
	return lerpf(_screen.y * BAND_TOP_FRAC, _screen.y * BAND_BOTTOM_FRAC, t)


func _on_viewport_resized() -> void:
	_screen = get_viewport().get_visible_rect().size
	for c in _clouds:
		c["node"].position.y = _band_y(c["band"])


func _process(delta: float) -> void:
	for c in _clouds:
		var node: Sprite2D = c["node"]
		node.position.x += c["speed"] * delta
		var half := node.texture.get_width() * 0.5
		if node.position.x - half > _screen.x:
			node.position.x = -half
			node.position.y = _band_y(randf_range(0.0, 1.0))

	if _pterosaur.visible:
		_pterosaur.position.x += PTEROSAUR_SPEED * _pterosaur_dir * delta
		var edge := float(_pterosaur.texture.get_width())
		if _pterosaur.position.x < -edge or _pterosaur.position.x > _screen.x + edge:
			_pterosaur.visible = false
			_next_pterosaur = randf_range(PTEROSAUR_INTERVAL_MIN, PTEROSAUR_INTERVAL_MAX)
	else:
		_next_pterosaur -= delta
		if _next_pterosaur <= 0.0:
			_launch_pterosaur()


func _launch_pterosaur() -> void:
	_pterosaur_dir = 1.0 if randf() < 0.5 else -1.0
	_pterosaur.flip_h = _pterosaur_dir < 0.0
	var w := float(_pterosaur.texture.get_width())
	_pterosaur.position = Vector2(
		-w if _pterosaur_dir > 0.0 else _screen.x + w, _band_y(randf_range(0.1, 0.8))
	)
	_pterosaur.visible = true
