extends Control

## Reusable settings overlay. Instanced as a hidden child inside both
## MainMenu.tscn and Main.tscn's pause overlay (NOT swapped to via
## change_scene) so opening it mid-run never tears down an in-progress
## match. Caller shows/hides it and listens for `closed`.

signal closed

const SOUND_ON_ICON := preload("res://assets/ui/merge/icon_sound_on.png")
const SOUND_OFF_ICON := preload("res://assets/ui/merge/icon_sound_off.png")

@onready var music_toggle_btn: TextureButton = $CenterContainer/VBoxContainer/MusicRow/Toggle
@onready var sfx_toggle_btn: TextureButton = $CenterContainer/VBoxContainer/SfxRow/Toggle
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_toggle_btn.pressed.connect(_on_music_toggle_pressed)
	sfx_toggle_btn.pressed.connect(_on_sfx_toggle_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_refresh_icons()


func open() -> void:
	_refresh_icons()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _on_music_toggle_pressed() -> void:
	var bus := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
	_refresh_icons()


func _on_sfx_toggle_pressed() -> void:
	var bus := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
	_refresh_icons()


func _on_back_pressed() -> void:
	close()


func _refresh_icons() -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	music_toggle_btn.texture_normal = (
		SOUND_OFF_ICON if AudioServer.is_bus_mute(music_bus) else SOUND_ON_ICON
	)
	sfx_toggle_btn.texture_normal = (
		SOUND_OFF_ICON if AudioServer.is_bus_mute(sfx_bus) else SOUND_ON_ICON
	)
