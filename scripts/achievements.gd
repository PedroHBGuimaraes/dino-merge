extends Node

## Static catalog of every achievement (id, translation keys, icon), built
## once from the curated list below. GameManager owns which ids are
## actually unlocked (persisted); this is just the shared definition
## both GameManager (to check thresholds) and AchievementsScreen (to
## render the list) read from -- same split as DinoChain vs. DinoLevel.
##
## `title`/`description` hold translation KEYS (see translations.csv), not
## literal text -- AchievementsScreen resolves them with tr() at render
## time so the list follows a runtime language switch.

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
		"title": "ACH_FIRST_MERGE_NAME",
		"description": "ACH_FIRST_MERGE_DESC",
	},
	{
		"id": "triceratops",
		"title": "ACH_TRICERATOPS_NAME",
		"description": "ACH_TRICERATOPS_DESC",
	},
	{
		"id": "trex",
		"title": "ACH_TREX_NAME",
		"description": "ACH_TREX_DESC",
	},
	{
		"id": "legendary",
		"title": "ACH_LEGENDARY_NAME",
		"description": "ACH_LEGENDARY_DESC",
	},
	{
		"id": "score_500",
		"title": "ACH_SCORE_500_NAME",
		"description": "ACH_SCORE_500_DESC",
	},
	{
		"id": "score_1500",
		"title": "ACH_SCORE_1500_NAME",
		"description": "ACH_SCORE_1500_DESC",
	},
	{
		"id": "score_3000",
		"title": "ACH_SCORE_3000_NAME",
		"description": "ACH_SCORE_3000_DESC",
	},
	{
		"id": "games_10",
		"title": "ACH_GAMES_10_NAME",
		"description": "ACH_GAMES_10_DESC",
	},
	{
		"id": "games_50",
		"title": "ACH_GAMES_50_NAME",
		"description": "ACH_GAMES_50_DESC",
	},
	{
		"id": "merges_100",
		"title": "ACH_MERGES_100_NAME",
		"description": "ACH_MERGES_100_DESC",
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
