@tool
class_name BuildingLayout
extends LevelLayout
## Composition of existing single-floor layouts. Each floor stays in local X/Z;
## floor_origins place matching access doorways against an enclosed stair wing.
@export var floors: Array[LevelLayout] = []
@export var access_room_ids: PackedStringArray = PackedStringArray()
@export var floor_origins: PackedVector3Array = PackedVector3Array()
@export var floor_height: float = 4.0
@export var stair_width: float = 1.8

func fingerprint() -> String:
	var parts: PackedStringArray = ["building:1", str(floor_origins), str(access_room_ids), str(floor_height), str(stair_width)]
	for floor_layout in floors:
		parts.append(floor_layout.fingerprint() if floor_layout != null else "null")
	return "|".join(parts).sha256_text()
