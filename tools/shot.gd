extends SceneTree

## Throwaway screenshot / playtest harness. Run with:
##   godot --path . -s tools/shot.gd -- <scene_res_path> <out_png> [warmup] [mode]
## mode: "plain" (default) | "play" (drops dinos to fill the pit first)
## Not shipped.

var _out := "user://shot.png"
var _warmup := 2.5
var _scene_path := "res://scenes/MainMenu.tscn"
var _mode := "plain"
var _node: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_scene_path = args[0]
	if args.size() >= 2:
		_out = args[1]
	if args.size() >= 3:
		_warmup = float(args[2])
	if args.size() >= 4:
		_mode = args[3]
	var gm := root.get_node_or_null("GameManager")
	if gm != null:
		gm.has_seen_tutorial = true
	var packed: PackedScene = load(_scene_path)
	_node = packed.instantiate()
	root.add_child(_node)
	current_scene = _node
	_run()


func _run() -> void:
	await process_frame
	await process_frame
	var tut := _node.get_node_or_null("UI/TutorialPanel")
	if tut != null:
		tut.visible = false
	if _mode.begins_with("play") and _node.has_method("_drop"):
		await _play()
	elif _mode == "gameover":
		await _play()
		root.get_node_or_null("GameManager").trigger_game_over()
	elif _mode == "pause":
		_node._on_pause_pressed()
	elif _mode == "sequence":
		_node._on_info_pressed()
	elif _mode == "dinopedia_detail":
		# discover a mid-chain species first so a cell is tappable
		root.get_node_or_null("GameManager").mark_species_discovered(14)
		_node._on_info_pressed()
		await create_timer(0.3).timeout
		var sp := _node.get_node("UI/SequencePanel")
		sp._show_detail(14)
	elif _mode == "settings_game":
		_node._on_pause_pressed()
		_node._on_pause_settings_pressed()
	elif _mode == "achievements":
		_node.get_node("AchievementsScreen").open()
	elif _mode == "settings_menu":
		_node.get_node("SettingsPanel").open()
	elif _mode == "toast":
		await create_timer(0.4).timeout
		root.get_node_or_null("GameManager").achievement_unlocked.emit("first_merge")
		await create_timer(0.6).timeout
	elif _mode == "birth":
		# Two dinos down the same column so they merge, then grab the frame
		# mid growth animation.
		for x in [360.0, 360.0]:
			_node.current_level_index = 2
			_node.next_level_index = 2
			_node.preview_x = x
			_node._move_preview(x)
			_node.can_drop = true
			_node._drop()
			await create_timer(0.7).timeout
		await create_timer(0.4).timeout
	await create_timer(_warmup).timeout
	var img := root.get_texture().get_image()
	img.save_png(_out)
	print("SHOT_SAVED ", _out)
	quit()


func _play() -> void:
	# Deterministic-ish fill: nudge the preview across the pit and drop
	# repeatedly so the pile, merges and HUD score all have something to show.
	var xs := [
		120.0,
		300.0,
		480.0,
		600.0,
		200.0,
		400.0,
		360.0,
		260.0,
		520.0,
		160.0,
		440.0,
		320.0,
		240.0,
		500.0,
		380.0,
		280.0,
		420.0,
		340.0
	]
	if _mode == "play_lite":
		xs = [140.0, 320.0, 460.0, 300.0, 220.0, 380.0]
	for x in xs:
		_node.preview_x = x
		if _node.has_method("_move_preview"):
			_node._move_preview(x)
		_node.can_drop = true
		_node._drop()
		await create_timer(0.5).timeout
	# let the pile settle / cascade
	await create_timer(2.5).timeout
