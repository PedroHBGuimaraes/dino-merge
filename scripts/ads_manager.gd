extends Node

## Wraps the godot-sdk-integrations/godot-admob plugin: init + GDPR/UMP
## consent flow, one rewarded slot ("continue after game over"), and one
## interstitial slot (shown between matches every INTERSTITIAL_EVERY_N
## completed runs). Mirrors the flow in the plugin's own demo/Main.gd.
##
## The `Admob` node itself is NOT part of this project yet -- installing
## the actual addon (native Android/iOS binaries) is a manual step done
## through the Godot editor, not something this script can create. Until
## that node exists as a child of this autoload, every method below is a
## safe no-op: ads report as "not ready", offer_rewarded_continue()
## always resolves to `false`, and register_game_over_and_continue()
## just calls its callback immediately. Nothing here needs to change
## when the addon is installed -- get_node_or_null() picks the real node
## up on the next run.

const INTERSTITIAL_EVERY_N := 3

var admob: Node = null

var _rewarded_loaded: bool = false
var _reward_earned_this_show: bool = false
var _pending_reward_callback := Callable()

var _interstitial_loaded: bool = false
var _games_since_interstitial: int = 0
var _pending_interstitial_callback := Callable()


func _ready() -> void:
	admob = get_node_or_null("Admob")
	if admob == null:
		push_warning(
			"AdsManager: no Admob child node found -- ads are disabled (addon not installed)."
		)
		return
	_connect_admob_signals()
	if not Engine.is_editor_hint():
		admob.initialize()


func is_rewarded_ad_ready() -> bool:
	return admob != null and _rewarded_loaded


func is_interstitial_ad_ready() -> bool:
	return admob != null and _interstitial_loaded


## Offers a rewarded ad. Calls `on_result.call(earned: bool)` once the
## outcome is known: true only if the user watched enough to earn the
## reward, false if they backed out, the ad failed, or none was ready.
func offer_rewarded_continue(on_result: Callable) -> void:
	if not is_rewarded_ad_ready():
		on_result.call(false)
		return
	_reward_earned_this_show = false
	_pending_reward_callback = on_result
	_rewarded_loaded = false
	admob.show_rewarded_ad()


## Call once per completed match (i.e. when the player actually leaves
## the game-over screen, not on every trigger_game_over()). Increments
## the between-matches counter and, once it reaches
## INTERSTITIAL_EVERY_N, shows the interstitial -- but only if one is
## loaded; otherwise it keeps the count so the next match retries.
## `on_done` always fires exactly once, whether or not an ad was shown.
func register_game_over_and_continue(on_done: Callable) -> void:
	_games_since_interstitial += 1
	if _games_since_interstitial >= INTERSTITIAL_EVERY_N and is_interstitial_ad_ready():
		_games_since_interstitial = 0
		_interstitial_loaded = false
		_pending_interstitial_callback = on_done
		admob.show_interstitial_ad()
	else:
		on_done.call()


func _connect_admob_signals() -> void:
	admob.initialization_completed.connect(_on_initialization_completed)
	admob.consent_info_updated.connect(_on_consent_info_updated)
	admob.consent_info_update_failed.connect(_on_consent_info_update_failed)
	admob.consent_form_loaded.connect(_on_consent_form_loaded)
	admob.consent_form_failed_to_load.connect(_on_consent_form_failed_to_load)
	admob.consent_form_dismissed.connect(_on_consent_form_dismissed)

	admob.rewarded_ad_loaded.connect(_on_rewarded_ad_loaded)
	admob.rewarded_ad_failed_to_load.connect(_on_rewarded_ad_failed_to_load)
	admob.rewarded_ad_user_earned_reward.connect(_on_rewarded_ad_user_earned_reward)
	admob.rewarded_ad_dismissed_full_screen_content.connect(
		_on_rewarded_ad_dismissed_full_screen_content
	)
	admob.rewarded_ad_failed_to_show_full_screen_content.connect(
		_on_rewarded_ad_failed_to_show_full_screen_content
	)

	admob.interstitial_ad_loaded.connect(_on_interstitial_ad_loaded)
	admob.interstitial_ad_failed_to_load.connect(_on_interstitial_ad_failed_to_load)
	admob.interstitial_ad_dismissed_full_screen_content.connect(
		_on_interstitial_ad_dismissed_full_screen_content
	)
	admob.interstitial_ad_failed_to_show_full_screen_content.connect(
		_on_interstitial_ad_failed_to_show_full_screen_content
	)


# --- init / consent (same flow as the plugin's demo/Main.gd) ---


func _on_initialization_completed(_status_data) -> void:
	_process_consent_status(admob.get_consent_status())


## Matches on to_status_string() rather than the UserConsent.Status enum
## on purpose: the UserConsent class only exists once the real addon is
## installed, and referencing it by name here would fail to parse until
## then. Verify these string values against the installed plugin.
func _process_consent_status(a_consent_status) -> void:
	match a_consent_status.to_status_string():
		"UNKNOWN":
			admob.update_consent_info()
		"NOT_REQUIRED":
			_load_ads()
		"REQUIRED":
			admob.load_consent_form()
		"OBTAINED":
			_load_ads()
		_:
			push_warning(
				"AdsManager: unrecognized consent status '%s'" % a_consent_status.to_status_string()
			)


func _on_consent_info_updated() -> void:
	_process_consent_status(admob.get_consent_status())


func _on_consent_info_update_failed(_error_data) -> void:
	push_warning("AdsManager: consent info update failed")


func _on_consent_form_loaded() -> void:
	admob.show_consent_form()


func _on_consent_form_failed_to_load(_error_data) -> void:
	push_warning("AdsManager: consent form failed to load")


func _on_consent_form_dismissed(_error_data) -> void:
	_process_consent_status(admob.get_consent_status())


func _load_ads() -> void:
	admob.load_rewarded_ad()
	admob.load_interstitial_ad()


# --- rewarded ---


func _on_rewarded_ad_loaded(_ad_info, _response_info) -> void:
	_rewarded_loaded = true


func _on_rewarded_ad_failed_to_load(_ad_info, _error_data) -> void:
	_rewarded_loaded = false


func _on_rewarded_ad_user_earned_reward(_ad_info, _reward_data) -> void:
	_reward_earned_this_show = true


func _on_rewarded_ad_dismissed_full_screen_content(_ad_info) -> void:
	_resolve_pending_reward(_reward_earned_this_show)
	admob.load_rewarded_ad()


func _on_rewarded_ad_failed_to_show_full_screen_content(_ad_info, _error_data) -> void:
	_resolve_pending_reward(false)
	admob.load_rewarded_ad()


func _resolve_pending_reward(earned: bool) -> void:
	if _pending_reward_callback.is_valid():
		_pending_reward_callback.call(earned)
	_pending_reward_callback = Callable()


# --- interstitial ---


func _on_interstitial_ad_loaded(_ad_info, _response_info) -> void:
	_interstitial_loaded = true


func _on_interstitial_ad_failed_to_load(_ad_info, _error_data) -> void:
	_interstitial_loaded = false


func _on_interstitial_ad_dismissed_full_screen_content(_ad_info) -> void:
	_resolve_pending_interstitial()
	admob.load_interstitial_ad()


func _on_interstitial_ad_failed_to_show_full_screen_content(_ad_info, _error_data) -> void:
	_resolve_pending_interstitial()
	admob.load_interstitial_ad()


func _resolve_pending_interstitial() -> void:
	if _pending_interstitial_callback.is_valid():
		_pending_interstitial_callback.call()
	_pending_interstitial_callback = Callable()
