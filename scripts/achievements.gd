extends Node

## Static catalog of every achievement (id, display text, icon), built
## once from the curated list below. GameManager owns which ids are
## actually unlocked (persisted); this is just the shared definition
## both GameManager (to check thresholds) and AchievementsScreen (to
## render the list) read from -- same split as DinoChain vs. DinoLevel.

const ASSET_DIR := "res://assets/ui/achievements"

## Merging into these two species specifically also unlocks an
## achievement -- kept here (not just in game_manager.gd) so the ids
## below and the thresholds that trigger them stay next to each other.
const TRICERATOPS_LEVEL := 14
const TREX_LEVEL := 26

const SCORE_THRESHOLDS := [500, 1500, 3000]
const GAMES_THRESHOLDS := [10, 50]
const MERGES_THRESHOLD := 100

const DEFS := [
	{
		"id": "first_merge",
		"title": "Primeira Fusão",
		"description": "Funda dois dinos pela primeira vez.",
	},
	{
		"id": "triceratops",
		"title": "Triceratops!",
		"description": "Crie um Triceratops fundindo dois Ouranosaurus.",
	},
	{
		"id": "trex",
		"title": "T-Rex!",
		"description": "Crie um Tiranossauro Rex através de uma fusão.",
	},
	{
		"id": "legendary",
		"title": "Lendário",
		"description": "Crie o Mosasaurus, o maior de todos os dinos.",
	},
	{
		"id": "score_500",
		"title": "Recorde: 500",
		"description": "Alcance 500 pontos em uma única partida.",
	},
	{
		"id": "score_1500",
		"title": "Recorde: 1500",
		"description": "Alcance 1500 pontos em uma única partida.",
	},
	{
		"id": "score_3000",
		"title": "Recorde: 3000",
		"description": "Alcance 3000 pontos em uma única partida.",
	},
	{
		"id": "games_10",
		"title": "Explorador",
		"description": "Jogue 10 partidas.",
	},
	{
		"id": "games_50",
		"title": "Veterano",
		"description": "Jogue 50 partidas.",
	},
	{
		"id": "merges_100",
		"title": "Mestre da Fusão",
		"description": "Realize 100 fusões ao todo.",
	},
]

var list: Array[Achievement] = []


func _ready() -> void:
	list.clear()
	for def in DEFS:
		var a := Achievement.new()
		a.id = def.id
		a.title = def.title
		a.description = def.description
		a.icon = _try_load_icon(def.id)
		list.append(a)


func _try_load_icon(id: String) -> Texture2D:
	var path := "%s/ach_%s.png" % [ASSET_DIR, id]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
