@tool
class_name BuildingPlanner
extends RefCounted
## Reuses the single-floor planner and compiler. Stairs occupy a reserved wing
## outside each floor's frontmost wall, avoiding hidden holes through room slabs.

static func generate(config: DungeonConfig) -> DungeonBuildResult:
	var result := DungeonBuildResult.new()
	result.seed = config.seed
	if config.floor_count < 2 or config.floor_count > 8 or not is_finite(config.floor_height) or config.floor_height > 12.0 or config.floor_height < config.room_size.y + config.ceiling_thickness + config.floor_thickness:
		result.report.add_error("BUILDING_HEIGHT", "Use 2–8 floors with enough height for room, ceiling and floor slabs.")
		return result
	if not is_finite(config.stair_width) or config.stair_width < maxf(config.door_width, config.player_radius * 2.0 + 0.2) or config.stair_width > 4.0:
		result.report.add_error("STAIR_WIDTH", "Stair width must clear the doorway/capsule and stay at most 4 m.")
		return result
	if config.enable_free_yaw_dungeons or config.enable_offgrid_socket_packing or not config.room_modules.is_empty() or not config.structural_prefabs.is_empty():
		result.report.add_error("BUILDING_SHELL", "Stacked floors currently use cardinal procedural shells; use native export for custom art.")
		return result
	var building := BuildingLayout.new()
	building.seed = config.seed
	building.floor_height = config.floor_height
	building.stair_width = config.stair_width
	for index in config.floor_count:
		var floor_config := config.duplicate(true) as DungeonConfig
		floor_config.floor_count = 1
		floor_config.generate_exterior_doors = false
		floor_config.seed = config.seed + index * 104729
		var generated := DungeonPlanner.generate_layout(floor_config)
		result.attempts += generated.attempts
		if not generated.success:
			result.report = generated.report
			return result
		var floor_layout := generated.layout
		if config.algorithm == DungeonConfig.Algorithm.HALLWAY_HOUSE and index > 0:
			for room in floor_layout.rooms:
				if room.purpose in [&"living_room", &"kitchen"]:
					room.purpose = &"bedroom"
				elif room.purpose == &"hallway":
					room.purpose = &"landing"
		var portal: RoomPlacementData
		var front: float = INF
		for room in floor_layout.rooms:
			var boundary: float = room.world_transform.origin.z - DungeonPlanner.actual_size(floor_layout, room).z * 0.5
			if boundary < front:
				portal = room
				front = boundary
		# The frontmost rectangular procedural room has no occupied front neighbor.
		if portal.shape != RoomFootprint.Shape.RECTANGLE:
			result.report.add_error("STAIR_PORTAL_SHAPE", "Use rectangular rooms for the frontmost stair access room.")
			return result
		building.floors.append(floor_layout)
		building.access_room_ids.append(portal.stable_id)
		building.floor_origins.append(Vector3(-portal.world_transform.origin.x, index * config.floor_height, -front))
	result.report = validate(building)
	result.success = result.report.is_valid()
	if result.success:
		result.layout = building
	return result


static func access_openings(building: BuildingLayout, index: int) -> Dictionary:
	var floor_layout: LevelLayout = building.floors[index]
	var opening := RoomOpening.new()
	opening.stable_id = "building_stair_access"
	opening.wall = RoomOpening.Wall.FRONT
	opening.width = floor_layout.exterior_door_width
	opening.height = floor_layout.exterior_door_height
	return {building.access_room_ids[index]: [opening]}


static func validate(building: BuildingLayout) -> RoomValidationReport:
	var report := RoomValidationReport.new()
	if building.floors.size() < 2 or building.floors.size() > 8 or building.floor_origins.size() != building.floors.size() or building.access_room_ids.size() != building.floors.size():
		report.add_error("BUILDING_FLOORS", "Floors, origins and access room IDs must match (2–8 floors).")
		return report
	if not is_finite(building.floor_height) or not is_finite(building.stair_width) or building.floor_height > 12.0 or building.stair_width <= 0.0 or building.stair_width > 4.0:
		report.add_error("BUILDING_METRICS", "Invalid stair dimensions.")
		return report
	for floor_layout in building.floors:
		if floor_layout == null or floor_layout is BuildingLayout:
			report.add_error("BUILDING_NESTING", "A building must contain ordinary floor layouts.")
			return report
	for index in building.floors.size():
		var floor_layout: LevelLayout = building.floors[index]
		var checked := DungeonPlanner.validate_layout(floor_layout)
		for error in checked.errors:
			report.add_error("BUILDING_FLOOR", "Floor %d: %s" % [index, error])
		if not checked.is_valid():
			continue
		if floor_layout.collision_layer != building.floors[0].collision_layer or floor_layout.collision_mask != building.floors[0].collision_mask:
			report.add_error("BUILDING_PHYSICS", "All floors must use the same stair collision layers and masks.")
		if floor_layout.free_yaw_enabled or floor_layout.exterior_doors_enabled or building.floor_height < floor_layout.room_size.y + floor_layout.ceiling_thickness + floor_layout.floor_thickness or building.floor_height < floor_layout.player_height + 0.5:
			report.add_error("BUILDING_CLEARANCE", "Floors require cardinal shells, closed exterior and sufficient headroom.")
		if building.stair_width < maxf(floor_layout.exterior_door_width, floor_layout.player_radius * 2.0 + 0.2):
			report.add_error("BUILDING_WIDTH", "Stairs must clear every floor's player and doorway.")
		if index + 1 < building.floors.size():
			var next_floor: LevelLayout = building.floors[index + 1]
			if building.floor_height - next_floor.floor_thickness < floor_layout.room_size.y + floor_layout.ceiling_thickness:
				report.add_error("BUILDING_SLABS", "The next floor slab intersects the ceiling below it.")
		var origin: Vector3 = building.floor_origins[index]
		if not origin.is_finite() or absf(origin.y - index * building.floor_height) > 0.001:
			report.add_error("BUILDING_ORIGIN", "Floor origins must match the fixed storey heights.")
		var found: bool = false
		for room in floor_layout.rooms:
			var size: Vector3 = DungeonPlanner.actual_size(floor_layout, room)
			var front: Vector3 = origin + room.world_transform.origin - Vector3(0, 0, size.z * 0.5)
			if front.z < -0.001:
				report.add_error("STAIR_RESERVATION", "A room enters the reserved stair wing.")
			if room.stable_id != building.access_room_ids[index]:
				continue
			found = true
			if room.shape != RoomFootprint.Shape.RECTANGLE or room.structural_prefab != null or room.module_profile != null or absf(front.x) > 0.001 or absf(front.z) > 0.001:
				report.add_error("STAIR_ACCESS", "Keep the stair access room's front socket at the reserved landing.")
			var blueprint := DungeonPlanner.make_blueprint(floor_layout, room)
			blueprint.openings.append(access_openings(building, index)[room.stable_id][0])
			for error in RoomGeometryBuilder.validate(blueprint).errors:
				report.add_error("STAIR_DOOR", error)
		for edge in floor_layout.connections:
			for point in edge.route_points:
				if point.z + origin.z - edge.clear_width * 0.5 - floor_layout.wall_thickness < -0.001:
					report.add_error("STAIR_CORRIDOR", "A routed corridor enters the reserved stair wing.")
		if not found:
			report.add_error("STAIR_ROOM", "The stair access room was removed.")
	return report
