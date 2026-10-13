# Dungeons, houses and editable buildings (Atrium 1.17)

Use the existing `DungeonAuthoring3D` and `DungeonConfig`. No second editor or
runtime manager is required. The distributable path remains `addons/room_creator`;
existing class names, UIDs and single-floor resources stay compatible.

## Choose a generation strategy

| `DungeonConfig.algorithm` | Result | Important controls |
| --- | --- | --- |
| `CRITICAL_PATH` (default) | Original bounded path search, branches and optional loops | Critical path min/max, branches, loops |
| `DEPTH_FIRST_TREE` | A growing tree that expands its newest active cell, producing long runs | Target rooms = critical max + branches; minimum still bounds the actual shortest entrance/exit path |
| `RANDOM_FRONTIER_TREE` | A growing tree that chooses a random active cell, producing more branching | Same target and shortest-path constraints; bounded attempts may reject incompatible requirements |
| `HALLWAY_HOUSE` | A connected central hall with side rooms across a rectangular footprint | Grid X must be 3; grid Y is 2–12; minimum critical path must fit the hall; loops must be zero |

These are different topology strategies, not different names for the spatial
packing modes. The existing silhouettes, variable room sizes, corridors and
single-floor yaw/socket packing still run after topology selection. All modes
use the supplied local seed and the same reciprocal-opening and physical-layout
validator. Tree modes record their real shortest path after optional loops;
`critical_path_max` sets the room budget there, not an upper bound on path length.

Presets to assign to **Config** in your existing authoring scene:

- `examples/atrium_depth_first_preset.tres`
- `examples/atrium_frontier_preset.tres`
- `examples/atrium_house_preset.tres` (two-storey house)
- `examples/atrium_multilevel_preset.tres` (three-storey dungeon)

House mode fills all three columns. `branch_count` does not control its room
count. Each side room opens onto a hall, avoiding bedroom-to-bathroom chains as
the only circulation route. Seeded `RoomPlacementData.purpose` values identify
living room, kitchen, bedroom, bathroom, study and storage; upper storeys use
bedrooms instead of living rooms/kitchens. Small footprints may not contain
every use. The supplied 3×3 preset contains the complete ground-floor set.

This creates an architectural **blockout with interiors**, not a furnished art
pack. Exported rooms contain an `Interior` node and `purpose` metadata for your
furniture, lights, pickups, doors, puzzles and gameplay nodes. There are no
assumptions about horror mechanics, materials or a player controller.

## Several floors and stairs

Set **Floor Count** to 2–8. One preserves the original single-floor pipeline.
**Floor Height** must clear the room plus floor/ceiling slabs and stay at most
12 m. **Stair Width** must clear the configured capsule and doorway (max 4 m).

A `BuildingLayout` contains ordinary `LevelLayout` resources and their origins.
The compiler aligns a frontmost access room on every floor to a reserved,
enclosed stair wing. It generates switchback flights, turn landings, storey
landings, wall openings and a ground-floor side entrance. There are no hidden
floor/ceiling cuts through unrelated rooms. Door and stair nodes are native
Godot meshes, markers, static bodies and shapes.

Visible treads use continuous 30° wedge colliders. This supports native
`CharacterBody3D.move_and_slide()` without a custom step-climbing script. Use
an appropriate floor angle and floor snap in the consuming controller. These
are **not individual step collision boxes**. No NavMesh, handrails, doors with
hinges or furnished assets are baked automatically.

The first multilevel domain is cardinal procedural room shells. Arbitrary-yaw
stacking and physical prefab stair cutouts are rejected explicitly. Keep the
stair access room rectangular and its front doorway aligned. All rooms and
routed passages must remain outside the reserved stair footprint; all floors
share collision layers/masks. Invalid builds return a diagnostic without
replacing the previous source, preview or bake.

## Edit before and after generation

1. Assign a preset and press **Generate Layout** in the Inspector or dock.
2. In **Rooms → Active floor**, choose the storey. Room selection, searching by
   purpose, locks, safe overrides, visual painting and connected-room stamping
   use the existing transactions on that floor. The Inspector's **Selected
   Floor** is zero-based. The dock displays floors starting at 1.
3. A floor edit is validated against the whole building before commit. Moving
   a stair doorway out of alignment is rejected; edit another room or work on
   the native exported scene when intentionally changing the architecture.
4. **Ctrl+S saves the authoring source**, floor layouts and user-owned children.
   Preview/bake children remain transient. Reopen and regenerate the preview.
5. **Bake Static Dungeon → Save Baked Scene** writes a native `.tscn` to
   **Output Scene Path**. Open that exported scene directly. Its `Floor_00`,
   `Floor_01`, `Stairwell` and `Flights` nodes are editable. Add nodes under a
   room's `Interior`, change geometry/materials, then save normally in Godot.

The source and exported scene are separate deliverables. Re-exporting to the
same path replaces the prior exported file, including edits made there. After
starting manual native edits, save them under a separate path or use a new
output path for later procedural drafts. Procedural regeneration does not
round-trip arbitrary edits from an exported scene into the source graph.

```gdscript
var config := load("res://examples/atrium_house_preset.tres") as DungeonConfig
var result := DungeonPlanner.generate_layout(config)
if result.success:
    var building := DungeonSceneCompiler.build(result.layout, true)
    add_child(building)
else:
    push_warning(result.report.summary())
```

For geometry-aware source edits, use the authoring facade or existing
`DungeonRoomOverrides`/`DungeonRoomEditing` contracts. Do not mutate shared
preset resources in place; duplicate before changing per-instance settings.

## Evidence and limits

`tests/atrium_generation_smoke.gd` exercises all four algorithms over 48 seed
cases, repeatability, semantic rooms, floor locks, failed-edit preservation,
source-only save/reopen, native export and an added node surviving a second
save/reopen. `tests/atrium_stairs_smoke.gd` walks a real capsule up and down a
saved/reloaded three-floor house without teleporting between floors or jumping.
The graphical editor integration additionally exercises building generation,
floor edits, native export and Godot Undo/Redo.

These complement the existing 21 geometry/editor smoke scripts. Linux tests
and virtual OpenGL do not replace Windows interactive acceptance, target-game
controller feel, art collision review or navigation baking.
