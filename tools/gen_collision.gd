extends SceneTree

## One-off/regen tool: builds assets/dino/collision_data.json, a single
## convex-hull collider per species traced from the real sprite
## silhouette (dino_<species>_adulto.png's non-transparent alpha),
## consumed by DinoChain/_load_collision_data() and dino.gd's setup()
## to give each dino a collider flush to its actual drawn shape instead
## of the enclosing circle.
##
## Run after adding a new species (see .claude/skills/add-dino-species)
## or replacing any dino_*_adulto.png, from the project root:
##   godot --headless --path . --script res://tools/gen_collision.gd
##
## Single convex hull, not a multi-piece decomposition: an earlier
## version of this tool emitted a compound collider (one CollisionPolygon2D
## per convex piece from Geometry2D.decompose_polygon_in_convex), which
## traced the silhouette (incl. concave dents) almost exactly but caused
## real, reproduced-in-play physics explosions once free rotation was
## enabled -- adjacent convex pieces of the same body share edges, and a
## contact landing near one of those internal seams gets slightly
## inconsistent normals from the two pieces, which the solver resolves
## into a large separation impulse (a dino suddenly launching off-screen
## at high speed, sometimes tunneling through a wall on the way). A
## single convex shape per body has no internal seams, so this class of
## bug can't happen -- the cost is losing concave detail (e.g. the gap
## under a raised tail), which reads as "slightly bigger than the
## sprite" in a few spots rather than "sometimes flies off the map".
const EPSILON := 2.5

const ASSET_DIR := "res://assets/dino"
const OUT_PATH := "res://assets/dino/collision_data.json"


func poly_area(pts: PackedVector2Array) -> float:
	var a := 0.0
	var n := pts.size()
	for i in n:
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		a += p1.x * p2.y - p2.x * p1.y
	return absf(a) * 0.5


func _initialize() -> void:
	var dino_chain := root.get_node("DinoChain")
	var out := {}
	for species in dino_chain.SPECIES:
		var path := "%s/dino_%s_adulto.png" % [ASSET_DIR, species]
		if not ResourceLoader.exists(path):
			print("MISSING: ", species)
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		img.convert(Image.FORMAT_RGBA8)
		var size := img.get_size()
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(img, 0.1)
		var true_px := bitmap.get_true_bit_count()
		var rect := Rect2(Vector2.ZERO, Vector2(size))
		var polygons: Array = bitmap.opaque_to_polygons(rect, EPSILON)
		var all_points := PackedVector2Array()
		for poly in polygons:
			all_points.append_array(poly)
		if all_points.size() < 3:
			push_error("no usable silhouette for " + species)
			continue
		var hull: PackedVector2Array = Geometry2D.convex_hull(all_points)
		var area := poly_area(hull)
		print(
			(
				"%s (px=%d): hull_pts=%d area%%=%.0f"
				% [species, true_px, hull.size(), (area / true_px) * 100.0]
			)
		)
		var pts := []
		for p in hull:
			pts.append([p.x - size.x / 2.0, p.y - size.y / 2.0])
		out[species] = pts
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("WROTE ", OUT_PATH)
	quit()
