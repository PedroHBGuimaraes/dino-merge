extends Node

## Score + game-over state, shared across the run. Also owns the
## persistent high score (user://highscore.json), loaded once when the
## app starts -- this node is an autoload, so unlike the Main scene it
## survives get_tree().reload_current_scene().

signal score_changed(new_score: int)
signal game_over
signal continued

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


func _ready() -> void:
	_load_high_score()


func add_score(points: int) -> void:
	if is_game_over:
		return
	score += points
	score_changed.emit(score)


func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	is_new_record = score > high_score
	if is_new_record:
		high_score = score
		_save_high_score()
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


func _load_high_score() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) == TYPE_DICTIONARY and data.has("high_score"):
		high_score = int(data["high_score"])


func _save_high_score() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameManager: could not open %s for writing" % SAVE_PATH)
		return
	file.store_string(JSON.stringify({"high_score": high_score}))
	file.close()
