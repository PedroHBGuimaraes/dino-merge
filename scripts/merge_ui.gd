extends RefCounted

const INK := Color("15272d")
const SURFACE := Color("22383f")
const TEXT := Color("fff2db")
const MUTED := Color("a9c4c0")
const ACCENT := Color("c7643d")


static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = Color("40575b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(14)
	return style


static func primary(button: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var style := panel_style()
		style.set_content_margin_all(8)
		style.bg_color = ACCENT
		if state == "hover":
			style.bg_color = ACCENT.lightened(0.1)
		elif state == "pressed":
			style.bg_color = ACCENT.darkened(0.12)
		style.border_color = style.bg_color.lightened(0.16)
		button.add_theme_stylebox_override(state, style)


static func label(text: String, font_size: int, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node


static func preview_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


static func build_hud(host: CanvasLayer, buttons: Array) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "MergeHUD"
	panel.anchor_right = 1.0
	panel.offset_left = 12
	panel.offset_right = -12
	panel.offset_top = 10
	panel.add_theme_stylebox_override("panel", panel_style())
	host.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	stack.add_child(top)
	var score_column := VBoxContainer.new()
	score_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_column.add_theme_constant_override("separation", 0)
	top.add_child(score_column)
	var score := label("0", 32)
	score_column.add_child(score)
	var record := label("", 13, MUTED)
	score_column.add_child(record)
	var future := VBoxContainer.new()
	future.add_theme_constant_override("separation", 0)
	top.add_child(future)
	var title := label("UI_UP_NEXT", 13, MUTED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	future.add_child(title)
	var previews := HBoxContainer.new()
	previews.add_theme_constant_override("separation", 8)
	future.add_child(previews)
	var first := preview_icon()
	previews.add_child(first)
	previews.add_child(label("›", 20, MUTED))
	var second := preview_icon()
	second.modulate.a = 0.65
	previews.add_child(second)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	stack.add_child(bottom)
	var hint := label("UI_AIM", 14, MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(hint)
	var timer := label("", 14, TEXT)
	timer.custom_minimum_size.x = 64
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(timer)
	for button in buttons:
		button.reparent(bottom)
		button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(44, 44)
	return {
		"panel": panel,
		"score": score,
		"record": record,
		"next": first,
		"second": second,
		"mission": hint,
		"timer": timer,
	}
