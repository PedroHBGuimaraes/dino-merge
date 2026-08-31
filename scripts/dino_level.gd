class_name DinoLevel
extends Resource
## One rung of the merge chain: from the smallest dino to the biggest.

@export var id: int = 0
@export var dino_name: String = ""
@export var radius: float = 20.0
@export var color: Color = Color.WHITE
@export var texture: Texture2D
@export var score_value: int = 10
## Idle-breathing animation frames (frame 0 == `texture`, then 1+ generated
## via PixelLab's animate_image). Empty when this species has no idle
## animation yet -- dino.gd falls back to the static `texture` in that case.
@export var idle_frames: Array[Texture2D] = []
## Baby / juvenile idle frames (assets/dino/idle/dino_<species>_idle_filhote_N
## and _jovem_N). Used only for the brief "just born" growth animation a
## merged dino plays (see dino.gd play_birth_animation) -- the settled
## idle loop always uses the adult `idle_frames`. Empty when a species has
## no life-stage art, in which case the merge just scales up the adult.
@export var idle_frames_baby: Array[Texture2D] = []
@export var idle_frames_young: Array[Texture2D] = []
## Longest side (px) of the sprite's actual non-transparent content,
## not the raw canvas size. Sprites share a 64x64 canvas but differ a
## lot in how much of it they fill, so scaling by canvas size alone
## makes some "bigger" levels look smaller on screen than the level
## before them. Scaling by this instead keeps the visible silhouette
## size monotonic with `radius`. Defaults to 64 (= old behavior) when
## a species has no measured value.
@export var content_size: float = 64.0
## Convex hull of the sprite's real alpha silhouette (pixel-space,
## centered on the 64x64 canvas), generated from assets/dino/collision_data.json.
## A single shape, not a multi-piece decomposition -- see tools/gen_collision.gd
## for why (compound colliders caused real physics explosions once dinos
## could rotate freely). Empty when a species has no measured data --
## dino.gd falls back to a circle sized by `radius` in that case.
@export var collision_hull: PackedVector2Array = PackedVector2Array()
