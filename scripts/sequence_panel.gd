extends Control

## The "Dinopédia": every dino in the merge chain, in order. Species the
## player has already seen in the pit show their real sprite; the rest are
## black silhouettes with a "?" -- so the screen doubles as a collection
## goal, not just a cheat sheet. Tapping a discovered dino opens a detail
## card (big sprite + a real paleo fact). Opened from the in-game "i"
## button. Embedded directly in Main.tscn (only used here).

signal closed

const REVEALED_NUMBER_COLOR := Color(0.97, 0.9, 0.76, 1)
const LOCKED_NUMBER_COLOR := Color(0.5, 0.45, 0.4, 1)
const SILHOUETTE_TINT := Color(0.0, 0.0, 0.0, 0.92)

var _detail: Control
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_fact: Label

@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var grid: GridContainer = $CenterContainer/Panel/VBoxContainer/ScrollContainer/Grid
@onready var close_button: Button = $CenterContainer/Panel/VBoxContainer/CloseButton


func _ready() -> void:
	close_button.pressed.connect(dismiss)
	_build_detail()


func open() -> void:
	_detail.visible = false
	_rebuild()
	visible = true


func dismiss() -> void:
	if _detail.visible:
		_detail.visible = false
		return
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

	var icon_holder: Control
	if revealed:
		var btn := TextureButton.new()
		btn.texture_normal = lvl.texture
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.pressed.connect(_show_detail.bind(index))
		icon_holder = btn
	else:
		var rect := TextureRect.new()
		rect.texture = lvl.texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.modulate = SILHOUETTE_TINT
		icon_holder = rect
	icon_holder.custom_minimum_size = Vector2(48, 48)
	cell.add_child(icon_holder)

	var number_label := Label.new()
	number_label.text = str(index + 1) if revealed else "?"
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.add_theme_font_size_override("font_size", 12)
	number_label.add_theme_color_override(
		"font_color", REVEALED_NUMBER_COLOR if revealed else LOCKED_NUMBER_COLOR
	)
	cell.add_child(number_label)
	return cell


func _show_detail(index: int) -> void:
	var lvl := DinoChain.get_level(index)
	_detail_icon.texture = lvl.texture
	_detail_name.text = "#%d/%d  %s" % [index + 1, DinoChain.level_count(), lvl.dino_name]
	# DINO_FACT_<SPECIES> keys live in translations.csv; fall back to nothing
	# rather than showing a raw key if a species has no fact yet.
	var key := "DINO_FACT_%s" % DinoChain.SPECIES[index].to_upper()
	var fact := Loc.t(key)
	_detail_fact.text = "" if fact == key else fact
	_detail.visible = true


## Detail card, built once. Tapped species fill it in; a tap on the dim
## backdrop (or Android-back) closes it back to the grid.
func _build_detail() -> void:
	_detail = Control.new()
	_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail.visible = false
	add_child(_detail)

	var backdrop := Button.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.flat = true
	backdrop.modulate = Color(0, 0, 0, 0)
	backdrop.pressed.connect(func(): _detail.visible = false)
	_detail.add_child(backdrop)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.06, 0.03, 0.02, 0.75)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(center)

	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.08, 0.05, 1.0)
	style.border_color = Color(0.82, 0.56, 0.25, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(300, 0)
	box.add_child(vb)

	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(128, 128)
	_detail_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(_detail_icon)

	_detail_name = Label.new()
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.add_theme_font_size_override("font_size", 20)
	_detail_name.add_theme_color_override("font_color", Color(1, 0.62, 0.2, 1))
	vb.add_child(_detail_name)

	_detail_fact = Label.new()
	_detail_fact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_fact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_fact.add_theme_font_size_override("font_size", 16)
	_detail_fact.add_theme_color_override("font_color", Color(0.9, 0.82, 0.68, 1))
	vb.add_child(_detail_fact)

	var close := Button.new()
	close.text = Loc.t("COMMON_CLOSE")
	close.custom_minimum_size = Vector2(180, 46)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): _detail.visible = false)
	vb.add_child(close)
