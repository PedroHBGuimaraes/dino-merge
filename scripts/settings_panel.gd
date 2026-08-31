extends Control

## Reusable settings overlay. Instanced as a hidden child inside both
## MainMenu.tscn and Main.tscn's pause overlay (NOT swapped to via
## change_scene) so opening it mid-run never tears down an in-progress
## match. Caller shows/hides it and listens for `closed`.

signal closed

@onready var music_slider: HSlider = $CenterContainer/VBoxContainer/MusicRow/Slider
@onready var sfx_slider: HSlider = $CenterContainer/VBoxContainer/SfxRow/Slider
@onready var vibration_toggle: CheckButton = $CenterContainer/VBoxContainer/VibrationRow/Toggle
@onready
var language_option: OptionButton = $CenterContainer/VBoxContainer/LanguageRow/LanguageOption
@onready var reset_button: Button = $CenterContainer/VBoxContainer/ResetButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton
@onready var confirm_reset: Control = $ConfirmReset
@onready var confirm_yes_button: Button = $ConfirmReset/Center/Box/YesButton
@onready var confirm_cancel_button: Button = $ConfirmReset/Center/Box/CancelButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_slider.value_changed.connect(GameManager.set_music_volume)
	sfx_slider.value_changed.connect(GameManager.set_sfx_volume)
	vibration_toggle.toggled.connect(_on_vibration_toggled)
	reset_button.pressed.connect(func(): confirm_reset.visible = true)
	confirm_cancel_button.pressed.connect(func(): confirm_reset.visible = false)
	confirm_yes_button.pressed.connect(_on_reset_confirmed)
	back_button.pressed.connect(_on_back_pressed)
	_populate_language_option()
	language_option.item_selected.connect(_on_language_selected)
	_sync_from_settings()


func open() -> void:
	confirm_reset.visible = false
	_sync_from_settings()
	_select_current_language()
	visible = true


func close() -> void:
	confirm_reset.visible = false
	visible = false
	closed.emit()


## Pulls widget state from GameManager -- called on open and once on ready
## so the panel always reflects the persisted prefs.
func _sync_from_settings() -> void:
	music_slider.set_value_no_signal(GameManager.music_volume)
	sfx_slider.set_value_no_signal(GameManager.sfx_volume)
	vibration_toggle.set_pressed_no_signal(GameManager.vibration_enabled)


func _on_vibration_toggled(pressed: bool) -> void:
	GameManager.set_vibration_enabled(pressed)
	if pressed:
		GameManager.vibrate(30)  # sample buzz so the toggle has feedback


func _on_reset_confirmed() -> void:
	GameManager.reset_all_progress()
	confirm_reset.visible = false


## Cada item usa o nome do idioma NO PRÓPRIO idioma (Loc.LOCALE_NATIVE_NAMES),
## pra ficar reconhecível seja qual for o idioma atual da UI. O índice do
## item == índice em Loc.SUPPORTED_LOCALES.
func _populate_language_option() -> void:
	language_option.clear()
	for i in Loc.SUPPORTED_LOCALES.size():
		var locale: String = Loc.SUPPORTED_LOCALES[i]
		language_option.add_item(Loc.LOCALE_NATIVE_NAMES[locale], i)
	_select_current_language()


func _select_current_language() -> void:
	var idx := Loc.SUPPORTED_LOCALES.find(LocaleManager.language)
	if idx >= 0:
		language_option.selected = idx


func _on_language_selected(index: int) -> void:
	LocaleManager.set_language(Loc.SUPPORTED_LOCALES[index])


func _on_back_pressed() -> void:
	if confirm_reset.visible:
		confirm_reset.visible = false
		return
	close()
