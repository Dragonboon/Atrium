extends SceneTree
## Walk a real capsule up AND down a saved/reloaded three-floor house without jumping.
var player: CharacterBody3D
var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := DungeonConfig.new()
	config.algorithm = DungeonConfig.Algorithm.HALLWAY_HOUSE
	config.grid_size = Vector2i(3, 3)
	config.room_size = Vector3(4, 3, 4)
	config.critical_path_min = 3
	config.critical_path_max = 3
	config.floor_count = 3
	var result := DungeonPlanner.generate_layout(config)
	if not result.success:
		push_error(result.report.summary())
		quit(1)
		return
	var geometry := DungeonSceneCompiler.build(result.layout)
	var packed := DungeonAuthoring3D._snapshot_node(geometry)
	geometry.free()
	var path := "user://atrium_stairs_physics.tscn"
	if ResourceSaver.save(packed, path) != OK:
		quit(1)
		return
	var restored := (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	root.add_child(restored)
	player = CharacterBody3D.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.floor_snap_length = 0.4
	player.safe_margin = 0.001
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = config.player_radius
	capsule.height = config.player_height
	collider.shape = capsule
	player.add_child(collider)
	root.add_child(player)
	player.position = Vector3(0, config.player_height * 0.5 + 0.03, 1)
	await physics_frame
	await physics_frame
	var points: Array[Vector3] = [Vector3(0, 0, 1)]
	var landing: float = BuildingSceneCompiler.landing_depth(config.stair_width)
	var run: float = config.floor_height * 0.5 / tan(deg_to_rad(30.0))
	var side: float = (config.stair_width + 0.2) * 0.5
	var entrance_probe := Transform3D(Basis.IDENTITY, Vector3(-config.stair_width + 0.3, config.player_height * 0.5 + 0.05, -landing * 0.5))
	if player.test_move(entrance_probe, Vector3(-1.5, 0, 0)):
		failed = true
		push_error("ATRIUM_STAIRS_SMOKE: FAIL: exterior entrance is blocked.")
	for index in range(config.floor_count - 1):
		var y: float = index * config.floor_height
		points.append(Vector3(0, y, -landing * 0.5))
		points.append(Vector3(side, y, -landing * 0.5))
		points.append(Vector3(side, y + config.floor_height * 0.5, -landing - run - landing * 0.5))
		points.append(Vector3(-side, y + config.floor_height * 0.5, -landing - run - landing * 0.5))
		points.append(Vector3(-side, y + config.floor_height, -landing * 0.5))
		points.append(Vector3(0, y + config.floor_height, -landing * 0.5))
		points.append(Vector3(0, y + config.floor_height, 1))
	for destination in points:
		if not await _walk(destination, config.player_height):
			break
	if not failed:
		points.reverse()
		for destination in points:
			if not await _walk(destination, config.player_height):
				break
	restored.free()
	player.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("ATRIUM_STAIRS_SMOKE: %s (three floors, ascent/descent, native reload)" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _walk(destination: Vector3, height: float) -> bool:
	for frame in range(900):
		await physics_frame
		var delta: float = 1.0 / 60.0
		var offset: Vector3 = destination - player.position
		offset.y = 0
		if offset.length() < 0.06 and absf(player.position.y - height * 0.5 - destination.y) < 0.15:
			return true
		var velocity: Vector3 = offset.normalized() * minf(2.5, offset.length() / delta)
		player.velocity.x = velocity.x
		player.velocity.z = velocity.z
		player.velocity.y -= 9.8 * delta
		player.move_and_slide()
	failed = true
	push_error("ATRIUM_STAIRS_SMOKE: FAIL: stuck at %s on the way to %s" % [player.position, destination])
	return false
