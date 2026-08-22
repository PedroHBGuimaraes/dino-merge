extends Node

## Score + game-over state, shared across the run. Also owns persistent
## player progress (user://highscore.json -- high score + whether the
## tutorial has been shown), loaded once when the app starts -- this
## node is an autoload, so unlike the Main scene it survives
## get_tree().reload_current_scene().

signal score_changed(new_score: int)
signal game_over
signal continued
signal achievement_unlocked(id: String)

const GAME_OVER_DELAY := 3.0
const SAVE_PATH := "user://highscore.json"

## Global Y (real screen/world coordinates, NOT design coordinates) above
## which an item is "above the danger line". Main.gd computes this every
## time it fits the gameplay layout to the actual viewport, since it
## depends on the current screen size -- the value here is just a sane
## default before that first runs.
var danger_line_y: float = 220.0

var score: int = 0
var high_score: int = 0
var is_new_record: bool = false
var is_game_over: bool = false
var has_seen_tutorial: bool = false
var games_played: int = 0
var total_merges: int = 0
var unlocked_achievements: Dictionary = {}


func _ready() -> void:
	_load_progress()


func add_score(points: int) -> void:
	if is_game_over:
		return
	score += points
	score_changed.emit(score)
	for threshold in Achievements.SCORE_THRESHOLDS:
		if score >= threshold:
			_unlock("score_%d" % threshold)


func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	is_new_record = score > high_score
	if is_new_record:
		high_score = score
		_save_progress()
	game_over.emit()


## Resumes the current run after a rewarded-ad continue: clears the
## game-over state but deliberately keeps `score` untouched.
func continue_run() -> void:
	if not is_game_over:
		return
	is_game_over = false
	is_new_record = false
	continued.emit()


func reset() -> void:
	score = 0
	is_game_over = false
	is_new_record = false
	score_changed.emit(score)


func mark_tutorial_seen() -> void:
	if has_seen_tutorial:
		return
	has_seen_tutorial = true
	_save_progress()


## Called once per distinct match (fresh load or restart of Main.tscn --
## NOT a rewarded-ad continue, which reuses the same run/scene).
func register_game_started() -> void:
	games_played += 1
	for threshold in Achievements.GAMES_THRESHOLDS:
		if games_played >= threshold:
			_unlock("games_%d" % threshold)
	_save_progress()


## Called from dino.gd right as a merge produces `new_level_index`,
## regardless of whether that index is still within the chain (two
## Mosasaurus merging have nothing new to spawn, but it still counts
## as a merge for the lifetime-count achievements).
func register_merge(new_level_index: int) -> void:
	total_merges += 1
	if total_merges == 1:
		_unlock("first_merge")
	if total_merges >= Achievements.MERGES_THRESHOLD:
		_unlock("merges_100")
	if new_level_index == Achievements.TRICERATOPS_LEVEL:
		_unlock("triceratops")
	elif new_level_index == Achievements.TREX_LEVEL:
		_unlock("trex")
	elif new_level_index == DinoChain.level_count() - 1:
		_unlock("legendary")
	_save_progress()


func is_unlocked(id: String) -> bool:
	return unlocked_achievements.has(id)


func _unlock(id: String) -> void:
	if unlocked_achievements.has(id):
		return
	unlocked_achievements[id] = true
	achievement_unlocked.emit(id)
	_save_progress()


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	if data.has("high_score"):
		high_score = int(data["high_score"])
	if data.has("seen_tutorial"):
		has_seen_tutorial = bool(data["seen_tutorial"])
	if data.has("games_played"):
		games_played = int(data["games_played"])
	if data.has("total_merges"):
		total_merges = int(data["total_merges"])
	if data.has("unlocked_achievements") and typeof(data["unlocked_achievements"]) == TYPE_ARRAY:
		for id in data["unlocked_achievements"]:
			unlocked_achievements[str(id)] = true


func _save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameManager: could not open %s for writing" % SAVE_PATH)
		return
	var data := {
		"high_score": high_score,
		"seen_tutorial": has_seen_tutorial,
		"games_played": games_played,
		"total_merges": total_merges,
		"unlocked_achievements": unlocked_achievements.keys(),
	}
	file.store_string(JSON.stringify(data))
	file.close()
