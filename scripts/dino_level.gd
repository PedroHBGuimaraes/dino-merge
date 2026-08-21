class_name DinoLevel
extends Resource
## One rung of the merge chain: from the smallest dino to the biggest.

@export var id: int = 0
@export var dino_name: String = ""
@export var radius: float = 20.0
@export var color: Color = Color.WHITE
@export var texture: Texture2D
@export var score_value: int = 10
## Longest side (px) of the sprite's actual non-transparent content,
## not the raw canvas size. Sprites share a 64x64 canvas but differ a
## lot in how much of it they fill, so scaling by canvas size alone
## makes some "bigger" levels look smaller on screen than the level
## before them. Scaling by this instead keeps the visible silhouette
## size monotonic with `radius`. Defaults to 64 (= old behavior) when
## a species has no measured value.
@export var content_size: float = 64.0
