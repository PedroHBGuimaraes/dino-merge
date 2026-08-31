extends Control

## Reference screen listing every dino in the merge chain, in order, with
## its sprite -- opened from the in-game "i" button so players can check
## what's coming without leaving the run. Embedded directly in Main.tscn,
## same as TutorialPanel (only used in one place).

signal closed

var _built: bool = false

@onready var grid: GridContainer = $CenterContainer/VBoxContainer/ScrollContainer/Grid
@onready var close_button: Button = $CenterContainer/VBoxContainer/CloseButton


func _ready() -> void:
	close_button.pressed.connect(dismiss)


func open() -> void:
	if not _built:
		_build_grid()
		_built = true
	visible = true


func dismiss() -> void:
	visible = false
	closed.emit()


## Built once (species never change mid-run) straight from DinoChain, so
## a new species added there shows up here automatically.
func _build_grid() -> void:
	for i in DinoChain.level_count():
		var lvl := DinoChain.get_level(i)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.texture = lvl.texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var number_label := Label.new()
		number_label.text = str(i + 1)
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.add_theme_font_size_override("font_size", 12)
		number_label.add_theme_color_override("font_color", Color(0.97, 0.9, 0.76, 1))

		cell.add_child(icon)
		cell.add_child(number_label)
		grid.add_child(cell)
