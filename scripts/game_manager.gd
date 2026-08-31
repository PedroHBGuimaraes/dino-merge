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

## Game over fires as soon as a dino is settled (see dino.gd's velocity
## check) above the danger line. Can't be 0.0: a freshly-spawned dino
## has linear_velocity == ZERO for exactly one physics frame before
## gravity accelerates it past SETTLE_SPEED, which would otherwise read
## as "instantly settled" and end the run on every single drop. This
## only needs to outlast that one frame -- it's not a real grace period.
const GAME_OVER_DELAY := 0.2
const SAVE_PATH := "user://highscore.json"

## Chain-combo scoring: merges land close together in time (a cascade,
## one merge's landing setting up the next) rather than each being
## proven to physically cause the next -- RigidBody2D contact chains are
## too indirect (a nudge, the pile resettling) to attribute cleanly, so
## a shared timer since the last merge is the robust signal here. A
## merge within COMBO_WINDOW seconds of the previous one extends the
## chain; a gap resets it to a fresh combo of 1 (i.e. no bonus).
const COMBO_WINDOW := 1.5
## +0.5x per chained merge, capped at 3x (combo 5+) so a long lucky
## cascade can't runaway the score indefinitely.
const COMBO_MULTIPLIER_STEP := 0.5
const COMBO_MAX_MULTIPLIER := 3.0

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

## How many merges deep the current chain combo is (1 = a lone merge,
## no bonus). Read by main.gd right after register_combo_step() to
## decide whether/how to show combo feedback.
var combo_count: int = 0
## Time.get_ticks_msec() of the last merge, or far enough in the past
## that the very first merge of a run never reads as "chained".
var _last_merge_ms: int = -1000000000


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


## Call once per merge, right as it lands (see dino.gd's _do_merge),
## before add_score. Advances/resets the chain combo and returns the
## score multiplier that applies to THIS merge.
func register_combo_step() -> float:
	var now := Time.get_ticks_msec()
	if now - _last_merge_ms <= int(COMBO_WINDOW * 1000.0):
		combo_count += 1
	else:
		combo_count = 1
	_last_merge_ms = now
	return minf(1.0 + COMBO_MULTIPLIER_STEP * (combo_count - 1), COMBO_MAX_MULTIPLIER)


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
	combo_count = 0
	_last_merge_ms = -1000000000
	continued.emit()


func reset() -> void:
	score = 0
	is_game_over = false
	is_new_record = false
	combo_count = 0
	_last_merge_ms = -1000000000
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


## Chamado pelo LocaleManager.set_language() pra gravar a escolha manual
## de idioma (já em LocaleManager.language) no mesmo save do progresso.
func save_language() -> void:
	_save_progress()


func _load_progress() -> void:
	# `true` = o save não tinha idioma gravado (jogador novo ou save
	# pré-i18n): grava agora o idioma detectado pelo LocaleManager no boot.
	var persist_language := true
	var data: Variant = null
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			data = JSON.parse_string(file.get_as_text())
			file.close()
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("high_score"):
			high_score = int(data["high_score"])
		if data.has("seen_tutorial"):
			has_seen_tutorial = bool(data["seen_tutorial"])
		if data.has("games_played"):
			games_played = int(data["games_played"])
		if data.has("total_merges"):
			total_merges = int(data["total_merges"])
		if (
			data.has("unlocked_achievements")
			and typeof(data["unlocked_achievements"]) == TYPE_ARRAY
		):
			for id in data["unlocked_achievements"]:
				unlocked_achievements[str(id)] = true
		persist_language = LocaleManager.load_prefs(str(data.get("language", "")))
	if persist_language:
		_save_progress()


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
		"language": LocaleManager.language,
	}
	file.store_string(JSON.stringify(data))
	file.close()
