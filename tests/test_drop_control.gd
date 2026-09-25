extends SceneTree

var failures: Array[String] = []
var main
var vp: SubViewport


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
	print("PASS " if value else "FAIL ", message)


func _touch(position: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	event.index = index
	main._unhandled_input(event)


func _run() -> void:
	root.get_node("GameManager").has_seen_tutorial = true
	vp = SubViewport.new()
	vp.size = Vector2i(400, 700)
	root.add_child(vp)
	main = load("res://scenes/Main.tscn").instantiate()
	vp.add_child(main)
	for i in range(5):
		await process_frame
	var before: int = main.dinos.get_child_count()
	_touch(Vector2(200, 400), false)
	_check(
		main.dinos.get_child_count() == before, "release without a playfield press does not drop"
	)
	main.can_drop = true
	before = main.dinos.get_child_count()
	_touch(Vector2(200, 20), true)
	_touch(Vector2(200, 400), false)
	_check(main.dinos.get_child_count() == before, "a drag starting on the HUD does not drop")
	main.current_level_index = 0
	main._move_preview(9999.0)
	main.current_level_index = 14
	main._update_preview()
	var radius: float = root.get_node("DinoChain").get_level(14).radius
	_check(main.preview_x <= main.right_x - radius, "new larger preview stays inside the wall")
	main.current_level_index = 0
	main.can_drop = true
	before = main.dinos.get_child_count()
	_touch(Vector2(200, 400), true)
	var release_over_hud := InputEventScreenTouch.new()
	release_over_hud.position = Vector2(200, 20)
	main._input(release_over_hud)
	_check(main._active_pointer == -2, "a release consumed by the HUD ends the gesture")
	_touch(Vector2(200, 400), true)
	main._on_pause_pressed()
	main._on_pause_resume_pressed()
	_touch(Vector2(200, 400), false)
	_check(main.dinos.get_child_count() == before, "pause cancels a pending drop")
	_touch(Vector2(200, 400), true)
	_touch(Vector2(220, 400), false, 1)
	_check(main.dinos.get_child_count() == before, "another finger cannot release the active piece")
	_touch(Vector2(200, 400), false)
	_check(
		main.dinos.get_child_count() == before + 1,
		"matching press and release drops exactly one dino"
	)
	for body in main.dinos.get_children():
		if body is RigidBody2D:
			body.freeze = true
			body.collision_layer = 0
			body.collision_mask = 0
	main.can_drop = true
	main.current_level_index = 0
	main.next_level_index = 1
	main.second_next_level_index = 2
	main._drop()
	_check(
		main.current_level_index == 1 and main.next_level_index == 2,
		"preview queue advances in the displayed order"
	)
	for dimensions in [Vector2i(400, 700), Vector2i(400, 900), Vector2i(600, 800)]:
		vp.size = dimensions
		for frame in range(6):
			await process_frame
		var floor_y: float = ((Vector2(360, 1224) - main.camera.position) * main._game_scale).y
		_check(floor_y <= dimensions.y, "playfield fits viewport %s" % dimensions)
		_check(main._game_scale >= 0.4, "playfield remains large enough at %s" % dimensions)
	print("DROP CONTROL: ", failures.size(), " failures")
	await create_timer(0.6).timeout
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
