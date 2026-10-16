<p align="center">
  <img src="docs/assets/atrium-mark.svg" width="144" height="144" alt="Atrium — connected rooms and architectural spaces">
</p>

<h1 align="center">Atrium</h1>

<p align="center"><strong>Create rooms, dungeons and multi-storey building blockouts in Godot.</strong></p>

<p align="center">
  <a href="https://godotengine.org/"><img src="https://img.shields.io/badge/Godot-4.7.2-478CBF?logo=godotengine&amp;logoColor=white" alt="Godot 4.7.2"></a>
  <a href="addons/room_creator/plugin.cfg"><img src="https://img.shields.io/badge/addon-1.17.0-334155" alt="Addon 1.17.0"></a>
  <a href="https://github.com/Dragonboon/Atrium/actions/workflows/godot-ci.yml"><img src="https://github.com/Dragonboon/Atrium/actions/workflows/godot-ci.yml/badge.svg" alt="Validation"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2E8540" alt="MIT license"></a>
</p>

<p align="center">
  <a href="#get-started">Get started</a> ·
  <a href="#what-you-can-build">Capabilities</a> ·
  <a href="#documentation">Documentation</a> ·
  <a href="#current-limits">Current limits</a>
</p>

Atrium is an editor-first 3D authoring addon that combines procedural generation with controlled manual editing. Build a layout from a seed, refine individual rooms, validate connections and export an editable native Godot scene with static collisions.

## What you can build

| Capability | Available today |
| --- | --- |
| **Individual rooms** | Editable room blueprints, dimensions, wall openings, materials, geometry validation and static collision export |
| **Procedural dungeons** | Seeded critical-path, depth-first tree and random-frontier tree strategies, with configurable branches and optional loops |
| **House blockouts** | Central hall and side-room layouts with semantic room purposes such as kitchen, bedroom, bathroom and storage |
| **Connected floors** | Two to eight cardinal floors connected by an enclosed switchback stair wing; single-floor generation remains available |
| **Room and corridor variation** | Rectangle, L, T and cross silhouettes, variable room sizes and spacing, routed corridors and exterior openings |
| **Single-floor spatial layouts** | Cardinal placement, optional free-yaw placement and bounded off-grid socket packing |
| **Editor refinement** | Room selection and search, active-floor controls, persistent locks, bounded geometry overrides, visual module painting and connected branch placement |
| **Reusable assets** | Socket-validated visual modules and supported structural room prefabs, with distinct collision requirements |
| **Native scene output** | Editable meshes, markers, static bodies and collision shapes; exported geometry does not require the addon |

Atrium generates **architectural blockouts**, not furnished environments. Add your own art, lighting, furniture, gameplay and player controller to the exported scene. Generation and edits validate the supported layout constraints before replacing the previous valid result.

## Installation

Use **Godot 4.7.2 stable**, the engine version pinned by this repository's checks.

1. Copy [`addons/room_creator/`](addons/room_creator/) into your project's `addons/` directory.
2. Open **Project → Project Settings → Plugins** and enable **Room Creator**.
3. Add `RoomAuthoring3D` for a single room or `DungeonAuthoring3D` for a dungeon/building.

The project is named **Atrium**; the plugin entry, addon directory and existing class names still use **Room Creator**. Keep these paths when copying the addon. No other addon is required.

To explore the supplied scenes and presets, clone this repository and import its [`project.godot`](project.godot) in Godot. Copying only the addon does not install the example scenes.

## Get started

### Generate a dungeon or building

1. Open [`examples/dungeon_authoring.tscn`](examples/dungeon_authoring.tscn) and select its `DungeonAuthoring3D` node.
2. Assign one of the following resources to **Config**, or keep the scene's existing configuration.
3. Press **Generate Layout** to produce and preview the layout. Review any validation diagnostics.
4. Use the **Room Creator** dock to select rooms, choose the active floor and refine the layout. The same authoring actions are available in the Inspector.
5. Press **Bake Static Dungeon**, set **Output Scene Path**, then **Save Baked Scene**.
6. Open the exported `.tscn` to work with its native Godot nodes.

| Start with | Preset | Result |
| --- | --- | --- |
| Long branching paths | [Depth-first dungeon](examples/atrium_depth_first_preset.tres) | Tree growth from the newest active cell |
| More distributed branching | [Random-frontier dungeon](examples/atrium_frontier_preset.tres) | Tree growth from a randomly selected active cell |
| A house | [Two-storey house](examples/atrium_house_preset.tres) | Central hall, side rooms with purposes and connected floors |
| A multi-floor dungeon | [Three-storey dungeon](examples/atrium_multilevel_preset.tres) | Cardinal floors and a shared stair wing |
| Rotated single-floor rooms | [Free-yaw dungeon](examples/dungeon_free_yaw_preset.tres) | Independent room yaw with validated world-space routes |
| Socket-driven placement | [Off-grid dungeon](examples/dungeon_offgrid_socket_preset.tres) | Bounded placement from real door sockets |

Topology strategies and spatial placement modes are separate controls. Not every combination is supported: multi-floor generation currently requires cardinal procedural shells. See the [building guide](docs/PROCEDURAL_BUILDINGS.md) for algorithm budgets, house dimensions and stair constraints.

### Author a single room

1. Open [`examples/single_room_door.tscn`](examples/single_room_door.tscn), or add `RoomAuthoring3D` to your own 3D scene.
2. Create a `RoomBlueprint` and set the room dimensions, thicknesses and optional materials.
3. Add `RoomOpening` resources for doors/windows. Choose the wall, offset, width, height and sill height. Walkable doorways start at floor level.
4. Use **Validate Blueprint → Generate Preview → Bake Static Room → Save Baked Scene**.

### Refine a generated layout

The dock provides a room browser, selection details and editing actions. Enable **Room Tool** in the 3D viewport to select rooms and use painting or connected-room placement. Press **Esc** to return to ordinary editor selection.

- **Protect rooms:** persistent locks preserve selected rooms during supported local regeneration. Full layout regeneration refuses to overwrite locked rooms.
- **Adjust geometry:** apply bounded room translations, sizes and supported silhouettes. Invalid connections or collisions reject the edit.
- **Paint appearance:** assign compatible visual modules without replacing structural collision geometry.
- **Extend a branch:** preview and add a connected neighboring room on a valid free wall. Placement is validated before commit.
- **Work by floor:** select the active storey; edits are checked against the building, including stair access.

Authoring actions participate in Godot's scene Undo/Redo. For exact controls and restrictions, see the [editor workspace guide](docs/EDITOR_WORKSPACE.md) and [multi-floor editing guide](docs/PROCEDURAL_BUILDINGS.md#edit-before-and-after-generation).

## Saving and export

**The authoring scene and the exported scene serve different purposes.**

| Operation | What it preserves |
| --- | --- |
| **Ctrl+S on the authoring scene** | Editable blueprints/layout resources, room edits and user-owned children. Generated preview/bake nodes are transient. |
| **Bake** | Geometry derived from the current validated source. Re-bake after geometry or material changes. |
| **Save Baked Scene** | A native `.tscn` containing the generated geometry and collisions, ready for independent editing. |

Reopening an authoring scene may require rebuilding its preview. Export checks reject invalid or geometrically stale bakes.

Once you edit an exported scene, save your finished version under a separate path: **exporting again to the same path replaces that file**, including manual edits. Those edits do not flow back into the procedural source. Building exports expose room `Interior` nodes and purpose metadata for your own content.

## Generate from code

The planner produces layout data; the compiler turns a successful layout into native nodes:

```gdscript
var config := load("res://examples/atrium_house_preset.tres") as DungeonConfig
var result := DungeonPlanner.generate_layout(config)
if result.success:
    var building := DungeonSceneCompiler.build(result.layout, true)
    add_child(building)
else:
    push_warning(result.report.summary())
```

This example uses a preset included in the repository. In an addon-only installation, use your own `DungeonConfig` resource. Duplicate shared presets before changing per-instance settings. For editor transactions and source edits, use the authoring facade rather than directly mutating the generated graph.

## Current limits

Atrium is actively developed. Its supported generation and export workflows are available now; the following remain outside the current supported scope:

- **Unrestricted 3D buildings:** arbitrary-yaw floor stacking and physical prefab stair cutouts are not supported. Multi-floor layouts use cardinal procedural shells.
- **Navigation and gameplay:** no automatic NavMesh baking, furnished assets, hinged doors or player controller. Stair collision uses continuous ramp wedges beneath visible treads.
- **Unrestricted prefab placement:** structural prefabs have specific socket/collider contracts. Arbitrary mesh collision shells, oblique door cuts and guaranteed closure of arbitrary off-grid loops are not established capabilities.
- **Advanced editor tools:** full 3D prefab ghosts, marker-level socket picking, unrestricted room dragging and automatic neighboring-room rearrangement are not complete.
- **Larger systems:** biome/material authoring layers, city generation and large-scale performance targets remain roadmap work.
- **Platform acceptance:** Linux headless and virtual graphical-editor checks do not establish Windows interactive acceptance or compatibility with every game's controller and physics settings.

The older `RoomCreator` and `DungeonGenerator` nodes remain for compatibility. Use `RoomAuthoring3D` and `DungeonAuthoring3D` for new authoring workflows; the legacy generator does not share all current validation guarantees.

## Documentation

| Need | Guide |
| --- | --- |
| Algorithms, houses, floors, stairs and native editing | [Procedural buildings](docs/PROCEDURAL_BUILDINGS.md) |
| Dock, viewport selection, painting and branch placement | [Editor workspace](docs/EDITOR_WORKSPACE.md) |
| Supported single-floor geometry and acceptance checks | [Single-floor acceptance](docs/F2_ACCEPTANCE.md) |
| Detailed editing status and constraints | [Editing progress](docs/F3_PROGRESS.md) |
| Architecture, planned features and engineering milestones | [Development roadmap](docs/ROADMAP.md) |
| Contributor workflow and validation requirements | [Contributor contract](AGENTS.md) |

## Validation and contributing

The [Godot workflow](.github/workflows/godot-ci.yml) checks addon-only installation, import/parsing, deterministic generation, geometry and capsule passage, scene save/reload and graphical-editor transactions. Its badge reports the workflow status; it is not a guarantee for every target project.

For a focused local check with the pinned engine:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/room_creator_smoke.gd
godot --headless --path . --script res://tests/atrium_generation_smoke.gd
godot --headless --path . --script res://tests/atrium_stairs_smoke.gd
```

Read [AGENTS.md](AGENTS.md) before contributing. Report issues with your Godot version, seed/configuration and a minimal scene. Preserve authored resources and test Undo/Redo, export and recovery for changes to the editor pipeline.

## License

Atrium is available under the [MIT license](LICENSE).
