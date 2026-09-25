extends Control

const MergeUI := preload("res://scripts/merge_ui.gd")

@onready var high_score_label: Label = $CenterContainer/VBoxContainer/HighScoreRow/HighScoreLabel
@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready
var achievements_button: Button = $CenterContainer/VBoxContainer/ButtonRow/AchievementsButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/ButtonRow/SettingsButton
@onready var settings_panel: Control = $SettingsPanel
@onready var achievements_screen: Control = $AchievementsScreen
@onready var ui_click_sfx: AudioStreamPlayer = $UiClickSfx


func _ready() -> void:
	_polish_menu()
	_refresh_high_score()
	play_button.pressed.connect(_on_play_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_panel.closed.connect(_on_settings_closed)
	settings_panel.visible = false
	achievements_screen.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if settings_panel.visible:
		settings_panel.close()
		get_viewport().set_input_as_handled()
		return
	if achievements_screen.visible:
		achievements_screen.close()
		get_viewport().set_input_as_handled()
	# Otherwise this is the true root screen -- let ui_cancel fall
	# through to the OS default (Android back exits the app here, same
	# as any other app's home screen).


func _on_play_pressed() -> void:
	ui_click_sfx.play()
	SceneTransition.change_scene("res://scenes/Main.tscn")


func _on_settings_pressed() -> void:
	ui_click_sfx.play()
	settings_panel.open()


## Settings is the only place the language can change from this screen, and
## it closes before the label is visible again -- so a refresh on close is
## enough, no need to listen for the switch itself.
func _on_settings_closed() -> void:
	_refresh_high_score()


func _refresh_high_score() -> void:
	high_score_label.text = Loc.t("MENU_HIGH_SCORE", {"score": GameManager.high_score})
	$CenterContainer/VBoxContainer/CollectionCount.text = Loc.t(
		"UI_COLLECTION", {"count": GameManager.discovered_count(), "total": DinoChain.level_count()}
	)


func _on_achievements_pressed() -> void:
	ui_click_sfx.play()
	achievements_screen.open()


func _polish_menu() -> void:
	MergeUI.primary(play_button)
	for pair in [[achievements_button, "ACHIEVEMENTS_TITLE"], [settings_button, "SETTINGS_TITLE"]]:
		var button: Button = pair[0]
		button.text = pair[1]
		button.custom_minimum_size = Vector2(154, 56)
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_constant_override("icon_max_width", 22)
		button.add_theme_constant_override("h_separation", 8)
	var collection := MergeUI.label("", 15, MergeUI.MUTED)
	collection.name = "CollectionCount"
	collection.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collection.text = Loc.t(
		"UI_COLLECTION", {"count": GameManager.discovered_count(), "total": DinoChain.level_count()}
	)
	$CenterContainer/VBoxContainer.add_child(collection)
