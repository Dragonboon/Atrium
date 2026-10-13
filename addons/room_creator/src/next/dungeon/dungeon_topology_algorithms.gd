@tool
class_name DungeonTopologyAlgorithms
extends RefCounted
## Alternative graph builders feed the existing geometry/socket validation pipeline.
## Tree modes target critical_path_max + branch_count rooms; the shortest path
## must still meet critical_path_min. House mode fills a three-column footprint.

static func create(config: DungeonConfig, rng: RandomNumberGenerator) -> LevelLayout:
	if config.algorithm == DungeonConfig.Algorithm.HALLWAY_HOUSE:
		return _house(config, rng)
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var parents: Array[int] = [-1]
	var occupied: Dictionary = {Vector2i.ZERO: 0}
	var active: Array[int] = [0]
	var target: int = config.critical_path_max + config.branch_count
	while cells.size() < target and not active.is_empty():
		var slot: int = active.size() - 1
		if config.algorithm == DungeonConfig.Algorithm.RANDOM_FRONTIER_TREE:
			slot = rng.randi_range(0, active.size() - 1)
		var parent: int = active[slot]
		var options: Array[Vector2i] = []
		for direction in DungeonPlanner._shuffled_directions(rng):
			var cell: Vector2i = cells[parent] + direction
			if DungeonPlanner._inside(cell, config.grid_size) and not occupied.has(cell):
				options.append(cell)
		if options.is_empty():
			active.remove_at(slot)
			continue
		var chosen: Vector2i = options[0]
		occupied[chosen] = cells.size()
		active.append(cells.size())
		cells.append(chosen)
		parents.append(parent)
	if cells.size() != target:
		return null
	var path: Array[Vector2i] = [cells[0], cells[1]]
	var layout := DungeonPlanner._assemble_path(config, path)
	layout.rooms.clear()
	layout.connections.clear()
	for i in cells.size():
		layout.rooms.append(DungeonPlanner._make_room(layout, cells[i], RoomPlacementData.Role.BRANCH))
		if i > 0:
			layout.connections.append(DungeonPlanner._make_connection(
				config, layout.rooms[parents[i]], layout.rooms[i], layout.connections.size()))
	layout.expected_room_count = target
	if not DungeonPlanner._add_loops(config, layout, occupied, rng):
		return null
	# BFS records the actual shortest path, including any added shortcuts.
	var adjacency: Dictionary = {}
	for room in layout.rooms:
		adjacency[room.stable_id] = []
	for edge in layout.connections:
		adjacency[edge.from_room_id].append(edge.to_room_id)
		adjacency[edge.to_room_id].append(edge.from_room_id)
	var queue: Array[String] = [layout.rooms[0].stable_id]
	var previous: Dictionary = {queue[0]: ""}
	var cursor: int = 0
	while cursor < queue.size():
		var current: String = queue[cursor]
		cursor += 1
		for neighbor: String in adjacency[current]:
			if not previous.has(neighbor):
				previous[neighbor] = current
				queue.append(neighbor)
	var ids: Array[String] = []
	var last: String = queue.back()
	while not last.is_empty():
		ids.push_front(last)
		last = previous[last]
	if ids.size() < config.critical_path_min:
		return null
	layout.critical_path_ids = PackedStringArray(ids)
	layout.entrance_id = ids.front()
	layout.exit_id = ids.back()
	# Existing exterior selection addresses the main path first.
	var reordered: Array[RoomPlacementData] = []
	for id in ids:
		for room in layout.rooms:
			if room.stable_id == id:
				room.role = RoomPlacementData.Role.MAIN
				reordered.append(room)
	for room in layout.rooms:
		if not ids.has(room.stable_id):
			reordered.append(room)
	layout.rooms = reordered
	layout.rooms[0].role = RoomPlacementData.Role.ENTRANCE
	layout.rooms[ids.size() - 1].role = RoomPlacementData.Role.EXIT
	return layout


static func _house(config: DungeonConfig, rng: RandomNumberGenerator) -> LevelLayout:
	var path: Array[Vector2i] = []
	for row in config.grid_size.y:
		path.append(Vector2i(1, row))
	var layout := DungeonPlanner._assemble_path(config, path)
	for hall in layout.rooms:
		hall.purpose = &"hallway"
	var uses: Array[StringName] = [&"living_room", &"kitchen", &"bedroom", &"bathroom", &"study", &"storage"]
	for i in range(uses.size() - 1, 0, -1):
		var swap: int = rng.randi_range(0, i)
		var value: StringName = uses[i]
		uses[i] = uses[swap]
		uses[swap] = value
	for row in config.grid_size.y:
		for side in [0, 2]:
			var room := DungeonPlanner._make_room(layout, Vector2i(side, row), RoomPlacementData.Role.BRANCH)
			room.purpose = uses[(row * 2 + (0 if side == 0 else 1)) % uses.size()]
			layout.rooms.append(room)
			layout.connections.append(DungeonPlanner._make_connection(config, layout.rooms[row], room, layout.connections.size()))
	layout.expected_room_count = layout.rooms.size()
	return layout
