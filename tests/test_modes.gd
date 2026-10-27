extends SceneTree

## Smoke test for the selectable run modes and their shared run state.

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
	printerr("FAIL " if not value else "PASS ", message)


func _run() -> void:
	var gm = root.get_node("GameManager")

	gm.select_mode("classic")
	gm.reset()
	_check(gm.run_mode == "classic", "classic mode starts normally")
	_check(gm.time_remaining == 0.0, "classic mode has no countdown")

	gm.select_mode("time_attack")
	gm.reset()
	_check(gm.run_mode == "time_attack", "time attack mode is selected")
	_check(gm.time_remaining == gm.TIME_ATTACK_SECONDS, "time attack starts with 90 seconds")
	_check(gm.is_time_mode(), "time attack exposes countdown state")

	gm.select_mode("daily")
	gm.reset()
	_check(gm.run_mode == "daily", "daily mode is selected")
	_check(gm.mission_target > 0, "daily mode creates a mission")
	_check(gm.time_remaining == gm.TIME_ATTACK_SECONDS, "daily mode has a countdown")

	gm.select_mode("zen")
	gm.reset()
	_check(gm.run_mode == "zen", "zen mode is selected")
	_check(gm.is_zen_mode(), "zen mode disables danger-line logic")
	_check(gm.time_remaining == 0.0, "zen mode has no countdown")

	gm.select_mode("classic")
	gm.reset()
	if failures == 0:
		print("MODES: 0 failures")
		quit(0)
		return
	printerr("MODES: %d failures" % failures)
	quit(1)
