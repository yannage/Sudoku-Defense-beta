extends Control
## Compact, pointer-transparent equipment token. The same voxel module artwork
## appears in the bag, on the tower, and here while it is in the player's hand.
const VoxelIcon = preload("res://scripts/voxel_icon.gd")
const Loot = preload("res://scripts/loot.gd")
var item: Dictionary = {}
var rarity_color := Color("83e7c1")

func configure(data: Dictionary) -> void:
	item = data
	rarity_color = Loot.rarity_color(str(item.get("rarity", "common")))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size = Vector2(56,56)
	var icon: Control = VoxelIcon.new()
	icon.kind = str(item.get("kind", "gear"))
	icon.tint = Color(str(Loot.KIND_COLORS.get(icon.kind, "6ce3c5")))
	icon.position = Vector2(4,4)
	icon.size = Vector2(48,48)
	add_child(icon)

func _draw() -> void:
	var center := Vector2(28,28)
	draw_circle(center+Vector2(0,3),27,Color(0,0,0,0.22))
	draw_circle(center,25,Color("081923d9"))
	draw_arc(center,25,0,TAU,40,Color(rarity_color,0.48),1.25,true)
	for quadrant in range(4):
		var angle: float = float(quadrant)*PI*0.5+0.18
		draw_arc(center,27,angle,angle+0.46,8,rarity_color,2.0,true)
