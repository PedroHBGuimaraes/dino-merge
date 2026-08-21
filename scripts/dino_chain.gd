extends Node

## Builds the 32-level evolution chain, smallest to biggest, from the real
## sprite set in res://assets/dino/ (dino_<species>_adulto.png).
##
## SPECIES order is a curated small->large ramp mixing small runners, small
## flyers, mid herbivores, big theropods and marine reptiles, ending on
## Mosasaurus as the final "boss" tier. Reorder this array if you want a
## different progression -- everything else derives from it.

const SPECIES := [
	"compsognathus",
	"dimorphodon",
	"pterodactylus",
	"rhamphorhynchus",
	"velociraptor",
	"deinonychus",
	"ichthyosaurus",
	"gallimimus",
	"pachycephalosaurus",
	"kentrosaurus",
	"styracosaurus",
	"tapejara",
	"corythosaurus",
	"ouranosaurus",
	"triceratops",
	"iguanodon",
	"parasaurolophus",
	"stegosaurus",
	"ankylosaurus",
	"carnotaurus",
	"plesiosaurus",
	"pteranodon",
	"allosaurus",
	"elasmosaurus",
	"therizinosaurus",
	"giganotosaurus",
	"trex",
	"quetzalcoatlus",
	"spinosaurus",
	"diplodocus",
	"brachiosaurus",
	"mosasaurus",
]

const DISPLAY_NAMES := {
	"trex": "T-Rex",
}

## Longest side (px) of each sprite's actual drawn content within its
## 64x64 canvas, measured from the real PNGs (non-transparent bbox).
## See DinoLevel.content_size for why this matters.
const CONTENT_SIZE := {
	"compsognathus": 56.0,
	"dimorphodon": 57.0,
	"pterodactylus": 60.0,
	"rhamphorhynchus": 56.0,
	"velociraptor": 52.0,
	"deinonychus": 54.0,
	"ichthyosaurus": 55.0,
	"gallimimus": 48.0,
	"pachycephalosaurus": 47.0,
	"kentrosaurus": 54.0,
	"styracosaurus": 54.0,
	"tapejara": 43.0,
	"corythosaurus": 50.0,
	"ouranosaurus": 46.0,
	"triceratops": 53.0,
	"iguanodon": 42.0,
	"parasaurolophus": 49.0,
	"stegosaurus": 49.0,
	"ankylosaurus": 52.0,
	"carnotaurus": 50.0,
	"plesiosaurus": 40.0,
	"pteranodon": 52.0,
	"allosaurus": 54.0,
	"elasmosaurus": 48.0,
	"therizinosaurus": 43.0,
	"giganotosaurus": 54.0,
	"trex": 56.0,
	"quetzalcoatlus": 58.0,
	"spinosaurus": 49.0,
	"diplodocus": 52.0,
	"brachiosaurus": 60.0,
	"mosasaurus": 56.0,
}

const ASSET_DIR := "res://assets/dino"
const MIN_RADIUS := 18.0
const RADIUS_STEP := 3.8

var levels: Array[DinoLevel] = []


func _ready() -> void:
	levels.clear()
	for i in SPECIES.size():
		var species_id: String = SPECIES[i]
		var lvl := DinoLevel.new()
		lvl.id = i
		lvl.dino_name = DISPLAY_NAMES.get(species_id, species_id.capitalize())
		lvl.radius = MIN_RADIUS + i * RADIUS_STEP
		lvl.score_value = (i + 1) * 10
		lvl.color = Color.from_hsv(float(i) / SPECIES.size(), 0.65, 0.9)
		lvl.texture = _try_load_texture(species_id)
		lvl.content_size = CONTENT_SIZE.get(species_id, 64.0)
		levels.append(lvl)


func _try_load_texture(species_id: String) -> Texture2D:
	var path := "%s/dino_%s_adulto.png" % [ASSET_DIR, species_id]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func level_count() -> int:
	return levels.size()


func get_level(index: int) -> DinoLevel:
	return levels[index]
