extends SceneTree
## Source-only manual authoring and guarded native export, using independent fixtures.
var failures: int = 0
var exports: Array[int] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("ROOM_AUTHORING_LIFECYCLE: FAIL: " + message)

func _run() -> void:
	var author: RoomAuthoring3D = RoomAuthoring3D.new()
	author.blueprint = RoomBlueprint.new()
	author.output_scene_path = "res://room_authoring_lifecycle_test_output.tscn"
	author.export_finished.connect(func(_path: String, error: Error) -> void: exports.append(error))
	root.add_child(author)
	var user_node: Node3D = Node3D.new()
	user_node.name = "DesignerMarker"
	author.add_child(user_node)
	user_node.owner = author
	check(author.save_scene() == ERR_DOES_NOT_EXIST, "Missing bake is rejected.")
	check(exports == [ERR_DOES_NOT_EXIST], "Every export attempt notifies the host.")
	author.generate_preview()
	author.bake()
	var source: PackedScene = PackedScene.new()
	check(source.pack(author) == OK, "Authored source packs.")
	check(source.get_state().get_node_count() == 2, "Source contains author and designer node, not generated geometry.")
	var source_path: String = "user://manual_authoring_source.tscn"
	check(ResourceSaver.save(source, source_path) == OK, "Source saves to disk.")
	var reopened: PackedScene = ResourceLoader.load(source_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var reopened_author: RoomAuthoring3D = reopened.instantiate() as RoomAuthoring3D
	check(reopened_author.blueprint.fingerprint() == author.blueprint.fingerprint(), "Fingerprint survives source save/reopen.")
	check(reopened_author.get_node_or_null(RoomAuthoring3D.BAKE_NAME) == null, "Reopened source has no bake pollution.")
	reopened_author.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(source_path))
	var opening: RoomOpening = RoomOpening.new()
	author.blueprint.openings.append(opening)
	var before_opening: String = author.blueprint.fingerprint()
	opening.offset = 0.5
	check(author.blueprint.fingerprint() != before_opening, "Nested opening changes invalidate freshness.")
	var duplicate: RoomBlueprint = author.blueprint.duplicate(true) as RoomBlueprint
	check(duplicate.fingerprint() == author.blueprint.fingerprint(), "Resource identity does not affect geometry fingerprint.")
	duplicate.collision_layer = 2
	check(duplicate.fingerprint() != author.blueprint.fingerprint(), "Physics masks participate in freshness.")
	var previous: Node = author.get_node(RoomAuthoring3D.BAKE_NAME)
	author.blueprint.room_size.x += 1.0
	check(author.save_scene() == ERR_INVALID_DATA, "A stale bake cannot be exported after changing dimensions.")
	check(author.get_node(RoomAuthoring3D.BAKE_NAME) == previous, "Rejected export preserves the previous bake.")
	author.bake()
	check(author.save_scene() == OK, "Rebaking enables native export.")
	var loaded: PackedScene = ResourceLoader.load(author.output_scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	check(loaded != null, "Export reloads.")
	if loaded != null:
		var instance: Node = loaded.instantiate()
		check(instance.get_script() == null, "Export has a native root.")
		check(not instance.find_children("*", "CollisionShape3D", true, false).is_empty(), "Export retains collisions.")
		instance.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(author.output_scene_path))
	check(exports == [ERR_DOES_NOT_EXIST, ERR_INVALID_DATA, OK], "Exactly one event per export attempt.")
	var dungeon: DungeonAuthoring3D = DungeonAuthoring3D.new()
	var dungeon_exports: Array[int] = []
	dungeon.export_finished.connect(func(_path: String, error: Error) -> void: dungeon_exports.append(error))
	check(dungeon.save_scene() == ERR_INVALID_DATA, "Dungeon without a layout fails validation.")
	check(dungeon_exports == [ERR_INVALID_DATA], "Dungeon early export failures also notify their host.")
	dungeon.free()
	author.free()
	if failures == 0:
		print("ROOM_AUTHORING_LIFECYCLE: PASS")
	quit(0 if failures == 0 else 1)
