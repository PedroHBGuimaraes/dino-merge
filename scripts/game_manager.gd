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
signal species_discovered(index: int)
signal timer_changed(seconds_left: float)
signal mission_changed(description: String, progress: int, target: int, completed: bool)
signal fossils_changed(total: int)

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
## Kept tight on purpose: a settling pile keeps nudging pairs together
## for a second or more after the player's last drop, and a wide window
## turned those physics after-shocks into free combo multipliers -- the
## same 18 drops could score 230 or 1140 purely on how the stack
## resettled. 0.7s still rewards a genuine drop-triggered cascade.
const COMBO_WINDOW := 0.7
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
## Chain indices the player has ever seen in the pit -- the spawner pool
## (0..MAX_SPAWN_LEVEL, always) plus every level ever produced by a merge.
## Drives the silhouette/reveal state of the sequence ("Dinopédia") screen.
## Keys are the index as a string (JSON dictionary keys are strings).
var discovered_species: Dictionary = {}

## Audio + haptics prefs, persisted (Godot persists none of these itself).
## `master_muted` is the HUD quick-mute (mutes everything); music/sfx are
## 0..1 volumes from the SettingsPanel sliders. Applied to the buses on
## boot by _apply_audio_settings().
var master_muted: bool = false
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var vibration_enabled: bool = true

## How many merges deep the current chain combo is (1 = a lone merge,
## no bonus). Read by main.gd right after register_combo_step() to
## decide whether/how to show combo feedback.
var combo_count: int = 0
## Highest chain index produced by a merge in the CURRENT run (-1 = no
## merge yet). Reset each run; shown on the game-over screen.
var run_highest_level: int = -1
var selected_mode: String = "classic"
var run_mode: String = "classic"
var time_remaining: float = 0.0
const TIME_ATTACK_SECONDS := 90.0
var mission_id: String = ""
var mission_target: int = 0
var mission_progress: int = 0
var mission_reward: int = 0
var mission_completed: bool = false
var fossils: int = 0
var unlocked_cosmetics: Dictionary = {}
var daily_best_score: int = 0
var daily_date: String = ""
## Time.get_ticks_msec() of the last merge, or far enough in the past
## that the very first merge of a run never reads as "chained".
var _last_merge_ms: int = -1000000000


func _ready() -> void:
	_load_progress()
	_apply_audio_settings()


func _process(delta: float) -> void:
	if is_game_over or run_mode not in ["time_attack", "daily"]:
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	timer_changed.emit(time_remaining)
	if time_remaining <= 0.0:
		trigger_game_over()


## Pushes the persisted audio prefs onto the actual buses. Called once on
## boot; the setters below keep the buses in sync after that. A 0 volume
## mutes the bus outright (linear_to_db(0) is -inf).
func _apply_audio_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), master_muted)
	_apply_bus_volume("Music", music_volume)
	_apply_bus_volume("SFX", sfx_volume)


func _apply_bus_volume(bus_name: String, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	if volume > 0.001:
		AudioServer.set_bus_volume_db(bus, linear_to_db(volume))


func set_master_muted(value: bool) -> void:
	master_muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value)
	_save_progress()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("Music", music_volume)
	_save_progress()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("SFX", sfx_volume)
	_save_progress()


func set_vibration_enabled(value: bool) -> void:
	vibration_enabled = value
	_save_progress()


## Haptic tap, routed through the vibration pref so SettingsPanel's toggle
## actually does something. Call this instead of Input.vibrate_handheld.
func vibrate(ms: int) -> void:
	if vibration_enabled:
		Input.vibrate_handheld(ms)


## Wipes run/collection progress (keeps language + audio prefs). Behind a
## confirm in SettingsPanel.
func reset_all_progress() -> void:
	high_score = 0
	games_played = 0
	total_merges = 0
	has_seen_tutorial = false
	unlocked_achievements.clear()
	discovered_species.clear()
	fossils = 0
	unlocked_cosmetics.clear()
	daily_best_score = 0
	daily_date = ""
	_save_progress()
	fossils_changed.emit(fossils)


func add_score(points: int) -> void:
	if is_game_over:
		return
	score += points
	score_changed.emit(score)
	if mission_id == "score":
		_set_mission_progress(score)
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
	if run_mode == "daily":
		var today := Time.get_date_string_from_system()
		if daily_date != today:
			daily_date = today
			daily_best_score = score
		elif score > daily_best_score:
			daily_best_score = score
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
	run_mode = selected_mode
	is_game_over = false
	is_new_record = false
	combo_count = 0
	run_highest_level = -1
	_last_merge_ms = -1000000000
	time_remaining = TIME_ATTACK_SECONDS if run_mode in ["time_attack", "daily"] else 0.0
	_setup_mission()
	score_changed.emit(score)
	timer_changed.emit(time_remaining)


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
	run_highest_level = maxi(run_highest_level, new_level_index)
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
	if mission_id == "merges":
		_set_mission_progress(total_merges)
	if total_merges % 5 == 0:
		add_fossils(1)
	_save_progress()


## Called by main.gd for every dino that enters the pit (dropped or born
## from a merge). First sighting of a species persists and fires
## species_discovered so the Dinopédia can reveal it.
func mark_species_discovered(index: int) -> void:
	var key := str(index)
	if discovered_species.has(key):
		return
	discovered_species[key] = true
	species_discovered.emit(index)
	if mission_id == "species":
		_set_mission_progress(discovered_count())
	_save_progress()


func is_species_discovered(index: int) -> bool:
	return discovered_species.has(str(index))


func discovered_count() -> int:
	return discovered_species.size()


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


func select_mode(mode: String) -> void:
	if mode in ["classic", "time_attack", "daily", "zen"]:
		selected_mode = mode


func is_zen_mode() -> bool:
	return run_mode == "zen"


func is_time_mode() -> bool:
	return run_mode in ["time_attack", "daily"]


func mode_loc_key() -> String:
	match run_mode:
		"time_attack": return "MODE_TIME_ATTACK"
		"daily": return "MODE_DAILY"
		"zen": return "MODE_ZEN"
		_: return "MODE_CLASSIC"


func selected_mode_loc_key() -> String:
	match selected_mode:
		"time_attack": return "MODE_TIME_ATTACK"
		"daily": return "MODE_DAILY"
		"zen": return "MODE_ZEN"
		_: return "MODE_CLASSIC"


func mission_description() -> String:
	match mission_id:
		"merges": return Loc.t("MISSION_MERGES", {"target": mission_target})
		"species": return Loc.t("MISSION_SPECIES", {"target": mission_target})
		_: return Loc.t("MISSION_SCORE", {"target": mission_target})


func _setup_mission() -> void:
	var day_index := int(Time.get_unix_time_from_system() / 86400.0)
	var choice := day_index % 3 if run_mode == "daily" else (games_played + day_index) % 3
	mission_id = ["score", "merges", "species"][choice]
	mission_target = 1500 if mission_id == "score" else (12 if mission_id == "merges" else 6)
	mission_reward = 5 if run_mode == "daily" else 3
	mission_progress = 0
	mission_completed = false
	mission_changed.emit(mission_description(), mission_progress, mission_target, mission_completed)


func _set_mission_progress(value: int) -> void:
	if mission_completed:
		return
	mission_progress = mini(value, mission_target)
	if mission_progress >= mission_target:
		mission_completed = true
		add_fossils(mission_reward)
		mission_changed.emit(mission_description(), mission_progress, mission_target, true)
		return
	mission_changed.emit(mission_description(), mission_progress, mission_target, false)


func add_fossils(amount: int) -> void:
	if amount <= 0:
		return
	fossils += amount
	if fossils >= 10:
		unlocked_cosmetics["theme_volcanic"] = true
	if fossils >= 25:
		unlocked_cosmetics["theme_amber"] = true
	fossils_changed.emit(fossils)
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
		if data.has("master_muted"):
			master_muted = bool(data["master_muted"])
		# music_volume/sfx_volume superseded the old music_muted/sfx_muted
		# bools -- migrate a pre-slider save so a muted category stays off.
		if data.has("music_volume"):
			music_volume = clampf(float(data["music_volume"]), 0.0, 1.0)
		elif bool(data.get("music_muted", false)):
			music_volume = 0.0
		if data.has("sfx_volume"):
			sfx_volume = clampf(float(data["sfx_volume"]), 0.0, 1.0)
		elif bool(data.get("sfx_muted", false)):
			sfx_volume = 0.0
		if data.has("vibration_enabled"):
			vibration_enabled = bool(data["vibration_enabled"])
		if data.has("fossils"):
			fossils = maxi(0, int(data["fossils"]))
		if data.has("unlocked_cosmetics") and typeof(data["unlocked_cosmetics"]) == TYPE_ARRAY:
			for cosmetic in data["unlocked_cosmetics"]:
				unlocked_cosmetics[str(cosmetic)] = true
		if data.has("daily_best_score"):
			daily_best_score = maxi(0, int(data["daily_best_score"]))
		if data.has("daily_date"):
			daily_date = str(data["daily_date"])
		if (
			data.has("unlocked_achievements")
			and typeof(data["unlocked_achievements"]) == TYPE_ARRAY
		):
			for id in data["unlocked_achievements"]:
				unlocked_achievements[str(id)] = true
		if data.has("discovered_species") and typeof(data["discovered_species"]) == TYPE_ARRAY:
			for idx in data["discovered_species"]:
				discovered_species[str(idx)] = true
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
		"discovered_species": discovered_species.keys(),
		"language": LocaleManager.language,
		"master_muted": master_muted,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"vibration_enabled": vibration_enabled,
		"fossils": fossils,
		"unlocked_cosmetics": unlocked_cosmetics.keys(),
		"daily_best_score": daily_best_score,
		"daily_date": daily_date,
	}
	file.store_string(JSON.stringify(data))
	file.close()
