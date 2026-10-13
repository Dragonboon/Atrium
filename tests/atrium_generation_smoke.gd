extends SceneTree
## Independent acceptance: algorithms, stacked houses, edits, source/native round trips.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fingerprints: Dictionary = {}
	for algorithm in [0, 1, 2, 3]:
		for seed_value in range(12):
			var config := _config()
			config.algorithm = algorithm as DungeonConfig.Algorithm
			config.seed = seed_value * 101 + 7
			if algorithm != DungeonConfig.Algorithm.HALLWAY_HOUSE:
				config.grid_size = Vector2i(8, 8)
				config.critical_path_min = 3
				config.critical_path_max = 6
				config.branch_count = 8
			var result := DungeonPlanner.generate_layout(config)
			_check(result.success, "Algorithm %d seed %d: %s" % [algorithm, config.seed, result.report.summary()])
			if not result.success:
				continue
			var repeated := DungeonPlanner.generate_layout(config)
			_check(repeated.success and result.layout.fingerprint() == repeated.layout.fingerprint(), "Deterministic topology.")
			fingerprints[result.layout.fingerprint()] = true
			var geometry := DungeonSceneCompiler.build(result.layout)
			_check(geometry != null, "Topology compiles through existing owner.")
			if geometry != null:
				geometry.free()
	_check(fingerprints.size() > 30, "Algorithms/seeds produce varied layouts.")
	for preset in ["atrium_house", "atrium_multilevel", "atrium_depth_first", "atrium_frontier"]:
		var preset_config := load("res://examples/" + preset + "_preset.tres") as DungeonConfig
		var generated := DungeonPlanner.generate_layout(preset_config)
		_check(generated.success, "Shipped preset generates: " + preset)
	var config := _config()
	config.floor_count = 3
	var result := DungeonPlanner.generate_layout(config)
	_check(result.success, "Three-storey house: " + result.report.summary())
	if result.success:
		var building := result.layout as BuildingLayout
		_check(building.floors.size() == 3, "Three persisted floor layouts.")
		var uses: Dictionary = {}
		for room in building.floors[0].rooms:
			uses[room.purpose] = true
		for use in [&"hallway", &"bedroom", &"bathroom", &"kitchen", &"living_room", &"study", &"storage"]:
			_check(uses.has(use), "House provides " + str(use))
		var author := DungeonAuthoring3D.new()
		author.config = config
		author.layout = building
		root.add_child(author)
		author.selected_floor = 1
		author.selected_room_id = building.floors[1].rooms[3].stable_id
		_check(author.lock_selected_room(), "Existing lock transaction works on selected floor.")
		_check(DungeonRoomEditing.any_locked(author.layout), "Building protects floor locks.")
		var untouched: String = author.layout.floors[0].fingerprint()
		author.manual_room_size = Vector2(3.5, 4.0)
		_check(author.apply_selected_room_override(), "Existing safe size edit works on upper floor.")
		_check(author.layout.floors[0].fingerprint() == untouched, "Other floors remain unchanged.")
		var baseline: String = author.layout.fingerprint()
		author.selected_room_id = building.access_room_ids[1]
		author.manual_room_size = Vector2(4.0, 3.5)
		_check(not author.apply_selected_room_override(), "Moving a stair portal fails transactionally.")
		_check(author.layout.fingerprint() == baseline, "Rejected edit keeps whole building.")
		var designer := Marker3D.new()
		designer.name = "DesignerSpawn"
		author.add_child(designer)
		designer.owner = author
		author.bake()
		var source := PackedScene.new()
		_check(source.pack(author) == OK, "Source packs.")
		var source_path := "user://atrium_source.tscn"
		_check(ResourceSaver.save(source, source_path) == OK, "Source writes to disk.")
		var reopened := (load(source_path) as PackedScene).instantiate() as DungeonAuthoring3D
		_check(reopened.layout is BuildingLayout and reopened.get_node_or_null("DesignerSpawn") != null, "Source retains layout and authored nodes.")
		_check(reopened.get_node_or_null("DungeonBake") == null, "Source excludes transient compiled geometry.")
		reopened.free()
		var native := DungeonSceneCompiler.build(author.layout)
		_check(native != null, "Building compiles floors and stairs.")
		if native != null:
			var snapshot := DungeonAuthoring3D._snapshot_node(native)
			var path := "user://atrium_native.tscn"
			_check(ResourceSaver.save(snapshot, path) == OK, "Native geometry writes.")
			var restored := (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
			var addition := Marker3D.new()
			addition.name = "ManualPuzzle"
			restored.get_node("Floor_01").add_child(addition)
			addition.owner = restored
			var edited := PackedScene.new()
			_check(edited.pack(restored) == OK and ResourceSaver.save(edited, path) == OK, "Designer edits save to native scene.")
			var again := (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
			_check(again.has_node("Floor_01/ManualPuzzle"), "Manual additions survive native save/reopen.")
			_check(again.get_script() == null, "Native output has no authoring script.")
			again.free()
			restored.free()
			native.free()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		author.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(source_path))
		var broken := building.duplicate(true) as BuildingLayout
		broken.floors[1].floor_thickness = 1.5
		_check(not BuildingPlanner.validate(broken).is_valid(), "Overlapping inter-storey slabs are rejected.")
		broken.floors[0] = null
		_check(not BuildingPlanner.validate(broken).is_valid(), "Null floor returns a diagnostic.")
	config.floor_height = 1.0
	_check(not DungeonPlanner.generate_layout(config).success, "Insufficient floor headroom is rejected.")
	print("ATRIUM_GENERATION_SMOKE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _config() -> DungeonConfig:
	var config := DungeonConfig.new()
	config.algorithm = DungeonConfig.Algorithm.HALLWAY_HOUSE
	config.grid_size = Vector2i(3, 3)
	config.room_size = Vector3(4, 3, 4)
	config.critical_path_min = 3
	config.critical_path_max = 3
	config.branch_count = 6
	return config

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("ATRIUM_GENERATION_SMOKE: FAIL: " + message)
