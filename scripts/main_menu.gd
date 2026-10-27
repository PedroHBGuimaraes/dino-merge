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
var mode_button: Button
var mode_popup: Control
var fossils_label: Label


func _ready() -> void:
	_polish_menu()
	_refresh_high_score()
	play_button.pressed.connect(_on_play_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_panel.closed.connect(_on_settings_closed)
	settings_panel.visible = false
	achievements_screen.visible = false
	_build_mode_picker()


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
	if is_instance_valid(fossils_label):
		fossils_label.text = Loc.t("MENU_FOSSILS", {"count": GameManager.fossils})
	_refresh_mode_button()
	var bg: TextureRect = $Background
	if GameManager.fossils >= 25:
		bg.texture = load("res://assets/scenes/bg_crater_high.png")
	elif GameManager.fossils >= 10:
		bg.texture = load("res://assets/scenes/bg_crater_mid.png")


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
	fossils_label = MergeUI.label("", 14, MergeUI.MUTED)
	fossils_label.name = "FossilsCount"
	fossils_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$CenterContainer/VBoxContainer.add_child(fossils_label)
	mode_button = Button.new()
	mode_button.name = "ModeButton"
	mode_button.custom_minimum_size = Vector2(320, 48)
	mode_button.pressed.connect(_on_mode_pressed)
	MergeUI.primary(mode_button)
	$CenterContainer/VBoxContainer.add_child(mode_button)
	$CenterContainer/VBoxContainer.move_child(mode_button, $CenterContainer/VBoxContainer.get_child_count() - 2)
	_refresh_mode_button()


func _refresh_mode_button() -> void:
	if not is_instance_valid(mode_button):
		return
	mode_button.text = Loc.t("MENU_MODE_BUTTON", {"mode": Loc.t(GameManager.selected_mode_loc_key())})


func _on_mode_pressed() -> void:
	ui_click_sfx.play()
	mode_popup.visible = true


func _build_mode_picker() -> void:
	mode_popup = Control.new()
	mode_popup.name = "ModePicker"
	mode_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mode_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mode_popup)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.04, 0.07, 0.08, 0.86)
	mode_popup.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mode_popup.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MergeUI.panel_style())
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	var title := MergeUI.label("MODE_TITLE", 28, Color("ff8c2f"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := MergeUI.label("MODE_SUBTITLE", 13, MergeUI.MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size.x = 280
	stack.add_child(subtitle)
	for item in [
		["classic", "MODE_CLASSIC", "MODE_CLASSIC_DESC"],
		["time_attack", "MODE_TIME_ATTACK", "MODE_TIME_ATTACK_DESC"],
		["daily", "MODE_DAILY", "MODE_DAILY_DESC"],
		["zen", "MODE_ZEN", "MODE_ZEN_DESC"],
	]:
		var mode_id: String = item[0]
		var button := Button.new()
		button.custom_minimum_size = Vector2(280, 54)
		button.text = Loc.t(item[1]) + "\n" + Loc.t(item[2])
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_stylebox_override("normal", MergeUI.panel_style())
		button.pressed.connect(func():
			GameManager.select_mode(mode_id)
			_refresh_mode_button()
			mode_popup.visible = false
		)
		stack.add_child(button)
	var close := Button.new()
	close.text = "COMMON_CLOSE"
	close.custom_minimum_size = Vector2(200, 48)
	close.pressed.connect(func(): mode_popup.visible = false)
	stack.add_child(close)
	mode_popup.visible = false
