extends Control

## Two-step dismissible onboarding shown once, the first time the
## player ever reaches gameplay (GameManager.has_seen_tutorial persisted
## to disk). Embedded directly in Main.tscn -- only used in one place,
## so unlike SettingsPanel there's no reuse case for a separate scene.

signal closed

var _step: int = 0

@onready var step1: Control = $CenterContainer/VBoxContainer/Step1
@onready var step2: Control = $CenterContainer/VBoxContainer/Step2
@onready var next_button: Button = $CenterContainer/VBoxContainer/NextButton
@onready var skip_button: Button = $CenterContainer/VBoxContainer/SkipButton


func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(_on_skip_pressed)


func open() -> void:
	_step = 0
	_refresh_step()
	visible = true


func _on_next_pressed() -> void:
	if _step == 0:
		_step = 1
		_refresh_step()
	else:
		dismiss()


func _on_skip_pressed() -> void:
	dismiss()


## Public: also called directly by main.gd's back-button dispatch, so
## the Android/Escape "cancel" gesture dismisses the tutorial like Skip.
func dismiss() -> void:
	visible = false
	GameManager.mark_tutorial_seen()
	closed.emit()


## The panel is shown once, before any settings screen is reachable, so the
## language can't change while it's open -- `open()` sets the button label
## fresh every time via _refresh_step(), no live re-translation needed.
func _refresh_step() -> void:
	step1.visible = _step == 0
	step2.visible = _step == 1
	next_button.text = Loc.t("TUTORIAL_GOT_IT") if _step == 1 else Loc.t("TUTORIAL_NEXT")
