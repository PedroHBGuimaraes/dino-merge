extends Node

## Score + game-over state, shared across the run.

signal score_changed(new_score: int)
signal game_over

const DANGER_LINE_Y := 220.0
const GAME_OVER_DELAY := 3.0

var score: int = 0
var is_game_over: bool = false

func add_score(points: int) -> void:
	if is_game_over:
		return
	score += points
	score_changed.emit(score)

func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	game_over.emit()

func reset() -> void:
	score = 0
	is_game_over = false
	score_changed.emit(score)
