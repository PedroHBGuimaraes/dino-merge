extends Control

## Full-screen achievements list, embedded directly in MainMenu.tscn
## (only used from there, so no separate reusable scene like
## SettingsPanel). Rebuilds its rows from Achievements.list every time
## it opens so newly-unlocked achievements show correctly without
## needing a signal connection.

signal closed

const UNLOCKED_TITLE_COLOR := Color(0.97, 0.9, 0.76, 1)
const UNLOCKED_DESC_COLOR := Color(0.8, 0.7, 0.55, 1)
const LOCKED_TITLE_COLOR := Color(0.55, 0.5, 0.45, 1)
const LOCKED_DESC_COLOR := Color(0.4, 0.37, 0.34, 1)
const LOCKED_ICON_TINT := Color(0.05, 0.05, 0.05, 0.85)

@onready var list_container: VBoxContainer = $Margin/VBox/ScrollContainer/List
@onready var back_button: Button = $Margin/VBox/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	back_button.pressed.connect(_on_back_pressed)


func open() -> void:
	_rebuild_list()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _on_back_pressed() -> void:
	close()


## Rows are rebuilt on every open() and their text comes from tr() at build
## time, so a language changed elsewhere is already reflected next time the
## screen opens (it can't change while the screen is visible).
func _rebuild_list() -> void:
	for child in list_container.get_children():
		child.queue_free()
	for achievement in Achievements.list:
		list_container.add_child(_build_row(achievement))


func _build_row(achievement: Achievement) -> Control:
	var unlocked := GameManager.is_unlocked(achievement.id)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.texture = achievement.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not unlocked:
		icon.modulate = LOCKED_ICON_TINT
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)

	var title := Label.new()
	title.text = tr(achievement.title)
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override(
		"font_color", UNLOCKED_TITLE_COLOR if unlocked else LOCKED_TITLE_COLOR
	)
	text_box.add_child(title)

	var desc := Label.new()
	desc.text = tr(achievement.description)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override(
		"font_color", UNLOCKED_DESC_COLOR if unlocked else LOCKED_DESC_COLOR
	)
	text_box.add_child(desc)

	row.add_child(text_box)
	return row
