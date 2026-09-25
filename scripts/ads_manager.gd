extends Node

## Wraps the godot-sdk-integrations/godot-admob plugin: init + GDPR/UMP
## consent flow, one rewarded slot ("continue after game over"), and one
## interstitial slot (shown between matches every INTERSTITIAL_EVERY_N
## completed runs). Mirrors the flow in the plugin's own demo/Main.gd.
##
## The native addon is loaded dynamically only on Android/iOS. Desktop and
## headless runs remain safe no-ops, while exported mobile builds create and
## configure the Admob node before initializing the SDK.

const INTERSTITIAL_EVERY_N := 3

## Production AdMob configuration for Android.
const ANDROID_APPLICATION_ID := "ca-app-pub-1898448267289061~1570505998"
const ANDROID_REWARDED_ID := "ca-app-pub-1898448267289061/9170717853"
const ANDROID_INTERSTITIAL_ID := "ca-app-pub-1898448267289061/6005323456"
const ADMOB_SCRIPT_PATH := "res://addons/AdmobPlugin/Admob.gd"

var admob = null

var _rewarded_loaded: bool = false
var _rewarded_ad_id := ""
var _reward_earned_this_show: bool = false
var _pending_reward_callback := Callable()

var _interstitial_loaded: bool = false
var _interstitial_ad_id := ""
var _games_since_interstitial: int = 0
var _pending_interstitial_callback := Callable()


func _ready() -> void:
	if not ResourceLoader.exists(ADMOB_SCRIPT_PATH):
		push_warning("AdsManager: AdMob addon not installed -- ads are disabled.")
		return
	if not OS.get_name() in ["Android", "iOS"]:
		return
	var admob_script = load(ADMOB_SCRIPT_PATH)
	admob = admob_script.new()
	admob.name = "Admob"
	admob.is_real = not OS.is_debug_build()
	admob.android_debug_application_id = "ca-app-pub-3940256099942544~3347511713"
	admob.android_debug_rewarded_id = "ca-app-pub-3940256099942544/5224354917"
	admob.android_debug_interstitial_id = "ca-app-pub-3940256099942544/1033173712"
	admob.android_real_application_id = ANDROID_APPLICATION_ID
	admob.android_real_rewarded_id = ANDROID_REWARDED_ID
	admob.android_real_interstitial_id = ANDROID_INTERSTITIAL_ID
	add_child(admob)
	_connect_admob_signals()
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
	_call_show_ad("show_rewarded_ad", _rewarded_ad_id)


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
		_call_show_ad("show_interstitial_ad", _interstitial_ad_id)
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


func _call_show_ad(method_name: String, ad_id: String) -> void:
	# Newer plugin versions require the loaded ad ID; older ones do not.
	for method_info in admob.get_method_list():
		if method_info.get("name", "") != method_name:
			continue
		var arguments: Array = method_info.get("args", [])
		if arguments.size() > 0 and not ad_id.is_empty():
			admob.call(method_name, ad_id)
		else:
			admob.call(method_name)
		return
	push_warning("AdsManager: AdMob method '%s' is unavailable" % method_name)


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


func _on_rewarded_ad_loaded(ad_info, _response_info) -> void:
	_rewarded_loaded = true
	_rewarded_ad_id = _extract_ad_id(ad_info)


func _on_rewarded_ad_failed_to_load(_ad_info, _error_data) -> void:
	_rewarded_loaded = false
	_rewarded_ad_id = ""


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


func _on_interstitial_ad_loaded(ad_info, _response_info) -> void:
	_interstitial_loaded = true
	_interstitial_ad_id = _extract_ad_id(ad_info)


func _on_interstitial_ad_failed_to_load(_ad_info, _error_data) -> void:
	_interstitial_loaded = false
	_interstitial_ad_id = ""


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


func _extract_ad_id(ad_info) -> String:
	if ad_info is String:
		return ad_info
	if ad_info != null and ad_info.has_method("get_ad_id"):
		return str(ad_info.get_ad_id())
	if ad_info is Dictionary:
		return str(ad_info.get("ad_id", ""))
	return ""
