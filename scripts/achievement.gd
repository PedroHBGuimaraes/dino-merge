class_name Achievement
extends Resource
## One entry in the achievements catalog. Unlock state itself lives in
## GameManager (persisted to the save file); this only carries the
## display data.

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var icon: Texture2D
