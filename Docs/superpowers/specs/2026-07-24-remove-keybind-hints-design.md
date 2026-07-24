# Remove Keybind Hints Design

**Date:** 2026-07-24
**Status:** Approved for implementation

## Goal

Remove every live world-map keyboard hint and obsolete keyboard movement binding before AC1.4 begins. Mouse selection remains the only world-map movement input.

## Scope

- Delete the complete `UI/NavigationHelp` subtree from `Scenes/game_world.tscn`, including the center hex and Q/W/E/A/S/D labels.
- Delete `Scripts/UI/navigation_help.gd` and its Godot UID sidecar.
- Delete `Tests/Map/test_navigation_help_ui.gd` and its Godot UID sidecar.
- Remove the six `map_move_*` actions from `project.godot`.
- Extend `Tests/Map/test_ac1_3_mouse_navigation.gd` to verify that:
  - the scene has no `UI/NavigationHelp` node;
  - none of the six `map_move_*` actions exists;
  - existing mouse navigation behavior remains operational.

## Architecture

The keyboard hint is an isolated scene subtree with one drawing script and one dedicated test, so it should be removed rather than hidden or repurposed. The obsolete actions are removed from the project InputMap because `MapController` no longer consumes them. No replacement overlay is introduced.

Historical specifications, plans, and evidence remain unchanged. They describe prior milestones and verification history; they are not live UI or active input configuration.

## Error Handling

There is no runtime fallback. Loading `game_world.tscn` must succeed without the removed script, and mouse input remains authoritative through `HexTileView.tile_selected` and `MapController.request_move()`.

## Testing

The updated AC1.3 regression test must fail before removal while the overlay and InputMap actions still exist, then pass after removal. The complete map suite and a live GodotIQ runtime check must confirm:

- no parser or missing-resource errors;
- no keybind overlay in the runtime UI;
- adjacent mouse clicks still move exactly once;
- keyboard movement actions no longer exist.

## Out of Scope

- Replacing the removed hint with mouse instructions.
- Editing historical AC1.1/AC1.3 specifications or evidence.
- Changing mouse navigation, encounter generation, or AC1.4 behavior.
