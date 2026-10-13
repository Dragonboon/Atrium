@tool
class_name BuildingSceneCompiler
extends RefCounted
## Native, editable floors and enclosed switchback stairs. Visible treads use
## a continuous wedge collider so CharacterBody3D needs no custom step solver.

static func build(building: BuildingLayout, collisions: bool = true) -> Node3D:
	if not BuildingPlanner.validate(building).is_valid():
		return null
	var root := Node3D.new()
	root.name = "BuildingGeometry"
	root.set_meta("room_creator_generated", true)
	root.set_meta("layout_fingerprint", building.fingerprint())
	root.set_meta("layout_seed", building.seed)
	for index in building.floors.size():
		var floor_root := DungeonSceneCompiler.build(building.floors[index], collisions,
			BuildingPlanner.access_openings(building, index))
		if floor_root == null:
			root.free()
			return null
		floor_root.name = "Floor_%02d" % index
		floor_root.position = building.floor_origins[index]
		root.add_child(floor_root)
		if index < building.floors.size() - 1:
			_close_storey_gap(floor_root, building, index, collisions)
	var floor_layout: LevelLayout = building.floors[0]
	var metrics := RoomBlueprint.new()
	metrics.collision_layer = floor_layout.collision_layer
	metrics.collision_mask = floor_layout.collision_mask
	metrics.floor_material = floor_layout.floor_material
	var width: float = building.stair_width
	var landing: float = landing_depth(width)
	var run: float = building.floor_height * 0.5 / tan(deg_to_rad(30.0))
	var span: float = width * 2.0 + 0.2
	var length: float = landing * 2.0 + run
	var top_height: float = 0.0
	for floor_plan in building.floors:
		top_height = maxf(top_height, floor_plan.room_size.y)
	var shell := RoomBlueprint.new()
	shell.room_size = Vector3(span + 0.4, (building.floors.size() - 1) * building.floor_height + top_height, length)
	shell.agent_radius = floor_layout.player_radius
	shell.agent_height = floor_layout.player_height
	shell.collision_layer = metrics.collision_layer
	shell.collision_mask = metrics.collision_mask
	shell.wall_material = floor_layout.wall_material
	shell.floor_material = floor_layout.floor_material
	shell.ceiling_material = floor_layout.ceiling_material
	for index in building.floors.size():
		var door := RoomOpening.new()
		door.stable_id = "floor_access_%02d" % index
		door.wall = RoomOpening.Wall.BACK
		door.kind = RoomOpening.Kind.DOOR if index == 0 else RoomOpening.Kind.WINDOW
		door.sill_height = index * building.floor_height
		door.width = building.floors[index].exterior_door_width
		door.height = building.floors[index].exterior_door_height
		shell.openings.append(door)
	var entrance := RoomOpening.new()
	entrance.stable_id = "building_entrance"
	entrance.wall = RoomOpening.Wall.LEFT
	entrance.offset = length * 0.5 - landing * 0.5
	entrance.width = floor_layout.exterior_door_width
	entrance.height = floor_layout.exterior_door_height
	shell.openings.append(entrance)
	var stairs := RoomGeometryBuilder.build(shell, collisions)
	if stairs == null:
		root.free()
		return null
	stairs.name = "Stairwell"
	stairs.position.z = -length * 0.5
	root.add_child(stairs)
	var flights := Node3D.new()
	flights.name = "Flights"
	root.add_child(flights)
	for index in building.floors.size():
		var height: float = index * building.floor_height
		_box(flights, "Landing_%02d" % index, Vector3(0, height - 0.1, -landing * 0.5), Vector3(span, 0.2, landing), metrics, collisions)
		if index == building.floors.size() - 1:
			continue
		var half: float = building.floor_height * 0.5
		_box(flights, "Turn_%02d" % index, Vector3(0, height + half - 0.1, -landing - run - landing * 0.5), Vector3(span, 0.2, landing), metrics, collisions)
		_flight(flights, Vector3((width + 0.2) * 0.5, height, -landing), -1.0, width, run, half, metrics, collisions)
		_flight(flights, Vector3(-(width + 0.2) * 0.5, height + half, -landing - run), 1.0, width, run, half, metrics, collisions)
		_box(flights, "Divider_%02d" % index, Vector3(0, height + building.floor_height * 0.5, -landing - run * 0.5), Vector3(0.2, building.floor_height, run), metrics, collisions)
	return root


static func _box(root: Node3D, label: String, center: Vector3, size: Vector3, metrics: RoomBlueprint, collisions: bool) -> void:
	RoomGeometryBuilder._add_box(root, label, center, size, metrics.floor_material, metrics, collisions)


static func _flight(root: Node3D, start: Vector3, direction: float, width: float, run: float, rise: float, metrics: RoomBlueprint, collisions: bool) -> void:
	var flight := Node3D.new()
	flight.name = "Flight_%d" % root.get_child_count()
	flight.position = start
	root.add_child(flight)
	var steps: int = ceili(rise / 0.18)
	for index in steps:
		var depth: float = run / steps
		var height: float = rise * (index + 1) / steps
		_box(flight, "Tread_%02d" % index, Vector3(0, height * 0.5, direction * depth * (index + 0.5)), Vector3(width, height, depth), metrics, false)
	if not collisions:
		return
	var points := PackedVector3Array()
	for x in [-width * 0.5, width * 0.5]:
		points.append(Vector3(x, -0.1, 0))
		points.append(Vector3(x, 0, 0))
		points.append(Vector3(x, -0.1, direction * run))
		points.append(Vector3(x, rise, direction * run))
	var body := StaticBody3D.new()
	body.name = "WalkableRamp"
	body.collision_layer = metrics.collision_layer
	body.collision_mask = metrics.collision_mask
	var shape := CollisionShape3D.new()
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = points
	shape.shape = wedge
	body.add_child(shape)
	flight.add_child(body)


static func landing_depth(width: float) -> float:
	return maxf(3.0, width + 0.4)


## Close the service void between a ceiling and the next storey's floor.
## This stays above playable headroom and below the next floor slab.
static func _close_storey_gap(root: Node3D, building: BuildingLayout, index: int, collisions: bool) -> void:
	var floor_plan: LevelLayout = building.floors[index]
	if not floor_plan.include_ceiling:
		return
	var bottom: float = floor_plan.room_size.y + floor_plan.ceiling_thickness
	var top: float = building.floor_height - building.floors[index + 1].floor_thickness
	if top <= bottom:
		return
	for room in floor_plan.rooms:
		var size: Vector3 = DungeonPlanner.actual_size(floor_plan, room)
		var metrics := DungeonPlanner.make_blueprint(floor_plan, room)
		var center: Vector3 = room.world_transform.origin + Vector3(0, (bottom + top) * 0.5, 0)
		RoomGeometryBuilder._add_box(root, "StoreyClosure_" + room.stable_id, center,
			Vector3(size.x, top - bottom, size.z), floor_plan.wall_material, metrics, collisions)
