extends Node2D

## All the visual dressing of the play well -- interior darkening, walls,
## floor, and the animated danger line -- drawn in one place, in design
## space (Container is unscaled, see main.gd). The three StaticBody2D
## siblings still own the actual collision; this node is purely cosmetic
## and renders behind the dinos (Container comes before Dinos under
## GameplayRoot).
##
## Why a darkened interior at all: the background art (bg_crater*) has its
## own canyon walls, lava veins and big skeletons. Against that, the old
## thin-outline "container" and the little gameplay dinos were nearly
## invisible. This lays an opaque-ish warm-dark well over the busy art so
## the pile reads as the foreground it is.

## Physical interior the dinos move in (matches the wall/floor colliders).
var x_left := 50.0
var x_right := 670.0
const Y_TOP := 44.0
const Y_FLOOR := 1190.0

## How far the drawn walls/floor extend past the physical interior.
const WALL_OUTER := 40.0
const WALL_RIM := 3.0
const FLOOR_DEPTH := 34.0
## Warm sandy "ground" band the pile visibly rests on.
const GROUND_HEIGHT := 150.0

## Near-opaque on purpose: the point is to replace the busy canyon art
## (skeletons, lava river) with a clean surface the dinos read against.
## The theme still lives in the walls, the sky strip above, and the menu.
const INTERIOR_TOP_COLOR := Color("1c323be0")
const INTERIOR_BOTTOM_COLOR := Color("2d4850e0")
const GROUND_TOP_COLOR := Color("3d555773")
const GROUND_BOTTOM_COLOR := Color("344c4f73")
const WALL_OUTER_COLOR := Color("12242b")
const WALL_INNER_COLOR := Color("435e61")
const WALL_STRATA_COLOR := Color(0.0, 0.0, 0.0, 0.16)
const RIM_COLOR := Color("88aca1")
const FLOOR_TOP_COLOR := Color("526966")
const FLOOR_BOTTOM_COLOR := Color("20363c")

const DANGER_BASE_COLOR := Color(1.0, 0.56, 0.40)
const DANGER_DASH := 22.0
const DANGER_GAP := 16.0
## A dino whose centre is within this many px below the line pushes the
## pulse toward its loud extreme.
const THREAT_RANGE := 190.0

var _t := 0.0
var _dash_scroll := 0.0
var _threat := 0.0
## 0..1, driven by run score (main.gd). The old bg_crater tier swap is
## mostly hidden behind the opaque pit now, so the "canyon heats up as you
## climb" idea moved in here: embers pooling on the floor and the wall
## strata glowing toward lava.
var _intensity := 0.0


## Eased toward `value` by main.gd on each score tier change.
func set_intensity(value: float) -> void:
	create_tween().tween_property(self, "_intensity", clampf(value, 0.0, 1.0), 1.2)


func _process(delta: float) -> void:
	_t += delta
	_dash_scroll = fmod(_dash_scroll + delta * 12.0, DANGER_DASH + DANGER_GAP)

	var closest := INF
	for dino in get_tree().get_nodes_in_group("dino"):
		if is_instance_valid(dino):
			closest = minf(closest, dino.global_position.y)
	var danger_y := _danger_y()
	var target := clampf((danger_y + THREAT_RANGE - closest) / THREAT_RANGE, 0.0, 1.0)
	_threat = move_toward(_threat, target, delta * 3.0)

	queue_redraw()


func _danger_y() -> float:
	# GameManager.danger_line_y is stored in this same (design) space by
	# main.gd (it seeds a sane default before that first runs).
	return GameManager.danger_line_y


func _draw() -> void:
	_draw_interior()
	_draw_walls()
	_draw_embers()
	_draw_floor()
	_draw_danger_line()


## Warm additive glow pooling up from the floor as the run heats up.
func _draw_embers() -> void:
	if _intensity <= 0.01:
		return
	var breathe := 0.85 + 0.15 * sin(_t * 1.6)
	var a := _intensity * 0.4 * breathe
	var top := Color(0.9, 0.35, 0.1, 0.0)
	var bot := Color(1.0, 0.5, 0.16, a)
	var y_top := Y_FLOOR - 340.0
	draw_polygon(
		PackedVector2Array(
			[
				Vector2(x_left, y_top),
				Vector2(x_right, y_top),
				Vector2(x_right, Y_FLOOR),
				Vector2(x_left, Y_FLOOR),
			]
		),
		PackedColorArray([top, top, bot, bot])
	)


func _draw_interior() -> void:
	var pts := PackedVector2Array(
		[
			Vector2(x_left, Y_TOP),
			Vector2(x_right, Y_TOP),
			Vector2(x_right, Y_FLOOR),
			Vector2(x_left, Y_FLOOR),
		]
	)
	var cols := PackedColorArray(
		[
			INTERIOR_TOP_COLOR,
			INTERIOR_TOP_COLOR,
			INTERIOR_BOTTOM_COLOR,
			INTERIOR_BOTTOM_COLOR,
		]
	)
	draw_polygon(pts, cols)

	# Warm ground band the pile sits on.
	var g_top := Y_FLOOR - GROUND_HEIGHT
	draw_polygon(
		PackedVector2Array(
			[
				Vector2(x_left, g_top),
				Vector2(x_right, g_top),
				Vector2(x_right, Y_FLOOR),
				Vector2(x_left, Y_FLOOR),
			]
		),
		PackedColorArray(
			[GROUND_TOP_COLOR, GROUND_TOP_COLOR, GROUND_BOTTOM_COLOR, GROUND_BOTTOM_COLOR]
		)
	)

	# Soft inner shadow hugging the top lip -- sells "you're looking down
	# into a hole", and darkens exactly where the danger line lives.
	var shade := Color(0.0, 0.0, 0.0, 0.3)
	draw_polygon(
		PackedVector2Array(
			[
				Vector2(x_left, Y_TOP),
				Vector2(x_right, Y_TOP),
				Vector2(x_right, Y_TOP + 140.0),
				Vector2(x_left, Y_TOP + 140.0),
			]
		),
		PackedColorArray([shade, shade, Color(0, 0, 0, 0), Color(0, 0, 0, 0)])
	)
	# Side vignette -- keeps focus centre-pit.
	var edge := Color(0.0, 0.0, 0.0, 0.22)
	var clear := Color(0, 0, 0, 0)
	draw_polygon(
		PackedVector2Array(
			[
				Vector2(x_left, Y_TOP),
				Vector2(x_left + 70, Y_TOP),
				Vector2(x_left + 70, Y_FLOOR),
				Vector2(x_left, Y_FLOOR)
			]
		),
		PackedColorArray([edge, clear, clear, edge])
	)
	draw_polygon(
		PackedVector2Array(
			[
				Vector2(x_right - 70, Y_TOP),
				Vector2(x_right, Y_TOP),
				Vector2(x_right, Y_FLOOR),
				Vector2(x_right - 70, Y_FLOOR)
			]
		),
		PackedColorArray([clear, edge, edge, clear])
	)


func _draw_wall(inner_x: float, outer_x: float) -> void:
	var top := Y_TOP
	var bottom := Y_FLOOR + FLOOR_DEPTH
	draw_polygon(
		PackedVector2Array(
			[
				Vector2(outer_x, top),
				Vector2(inner_x, top),
				Vector2(inner_x, bottom),
				Vector2(outer_x, bottom),
			]
		),
		PackedColorArray([WALL_OUTER_COLOR, WALL_INNER_COLOR, WALL_INNER_COLOR, WALL_OUTER_COLOR])
	)
	# Horizontal rock strata for a bit of texture on an otherwise flat band.
	var lo := minf(inner_x, outer_x)
	var hi := maxf(inner_x, outer_x)
	var y := top + 70.0
	while y < bottom:
		draw_line(Vector2(lo, y), Vector2(hi, y), WALL_STRATA_COLOR, 2.0)
		y += 96.0

	var rim_x := inner_x - signf(inner_x - outer_x) * WALL_RIM
	draw_line(Vector2(inner_x, top), Vector2(inner_x, bottom), RIM_COLOR, WALL_RIM)
	# faint secondary rim just inside, for a chiselled edge
	draw_line(Vector2(rim_x, top), Vector2(rim_x, bottom), Color(RIM_COLOR, 0.25), 1.0)


func _draw_walls() -> void:
	_draw_wall(x_left, x_left - WALL_OUTER)
	_draw_wall(x_right, x_right + WALL_OUTER)


func _draw_floor() -> void:
	var pts := PackedVector2Array(
		[
			Vector2(x_left - WALL_OUTER, Y_FLOOR),
			Vector2(x_right + WALL_OUTER, Y_FLOOR),
			Vector2(x_right + WALL_OUTER, Y_FLOOR + FLOOR_DEPTH),
			Vector2(x_left - WALL_OUTER, Y_FLOOR + FLOOR_DEPTH),
		]
	)
	var cols := PackedColorArray(
		[FLOOR_TOP_COLOR, FLOOR_TOP_COLOR, FLOOR_BOTTOM_COLOR, FLOOR_BOTTOM_COLOR]
	)
	draw_polygon(pts, cols)
	draw_line(Vector2(x_left, Y_FLOOR), Vector2(x_right, Y_FLOOR), RIM_COLOR, WALL_RIM)


func _draw_danger_line() -> void:
	var y := _danger_y()
	var pulse := 0.5 + 0.5 * sin(_t * lerpf(2.0, 6.0, _threat))
	var alpha := lerpf(0.35, 0.7, _threat) + pulse * lerpf(0.15, 0.3, _threat)
	var col := Color(DANGER_BASE_COLOR, clampf(alpha, 0.0, 1.0))
	var width := lerpf(2.0, 4.0, _threat)

	var x := x_left - _dash_scroll
	while x < x_right:
		var x0 := maxf(x, x_left)
		var x1 := minf(x + DANGER_DASH, x_right)
		if x1 > x0:
			draw_line(Vector2(x0, y), Vector2(x1, y), col, width)
		x += DANGER_DASH + DANGER_GAP

	# warning chevrons pointing down from each end, brighter with threat
	var chev := Color(DANGER_BASE_COLOR, clampf(0.4 + 0.6 * _threat, 0.0, 1.0))
	for cx in [x_left + 8.0, x_right - 8.0]:
		draw_polyline(
			PackedVector2Array(
				[Vector2(cx - 7, y + 3), Vector2(cx, y + 13), Vector2(cx + 7, y + 3)]
			),
			chev,
			2.0
		)
