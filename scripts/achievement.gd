class_name Achievement
extends Resource
## One entry in the achievements catalog. Unlock state itself lives in
## GameManager (persisted to the save file); this only carries the
## display data.

@export var id: String = ""
## Translation keys (see translations.csv), not literal text -- resolved
## with tr() by achievements_screen.gd at render time.
@export var title: String = ""
@export var description: String = ""
@export var icon: Texture2D
