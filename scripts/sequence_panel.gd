extends Control

## The "Dinopédia": every dino in the merge chain, in order. Species the
## player has already seen in the pit show their real sprite; the rest are
## black silhouettes with a "?" -- so the screen doubles as a collection
## goal, not just a cheat sheet. Opened from the in-game "i" button.
## Embedded directly in Main.tscn (only used here).

signal closed

const REVEALED_NUMBER_COLOR := Color(0.97, 0.9, 0.76, 1)
const LOCKED_NUMBER_COLOR := Color(0.5, 0.45, 0.4, 1)
const SILHOUETTE_TINT := Color(0.0, 0.0, 0.0, 0.92)

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var grid: GridContainer = $CenterContainer/VBoxContainer/ScrollContainer/Grid
@onready var close_button: Button = $CenterContainer/VBoxContainer/CloseButton


func _ready() -> void:
	close_button.pressed.connect(dismiss)


func open() -> void:
	_rebuild()
	visible = true


func dismiss() -> void:
	visible = false
	closed.emit()


## Rebuilt every open so a species discovered since last time shows up
## revealed. Cheap -- 32 cells.
func _rebuild() -> void:
	for child in grid.get_children():
		child.queue_free()

	var total := DinoChain.level_count()
	title_label.text = (
		"%s  %d/%d" % [Loc.t("SEQUENCE_TITLE"), GameManager.discovered_count(), total]
	)

	for i in total:
		grid.add_child(_build_cell(i, GameManager.is_species_discovered(i)))


func _build_cell(index: int, revealed: bool) -> Control:
	var lvl := DinoChain.get_level(index)
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.texture = lvl.texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color.WHITE if revealed else SILHOUETTE_TINT
	cell.add_child(icon)

	var number_label := Label.new()
	number_label.text = str(index + 1) if revealed else "?"
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.add_theme_font_size_override("font_size", 12)
	number_label.add_theme_color_override(
		"font_color", REVEALED_NUMBER_COLOR if revealed else LOCKED_NUMBER_COLOR
	)
	cell.add_child(number_label)
	return cell
