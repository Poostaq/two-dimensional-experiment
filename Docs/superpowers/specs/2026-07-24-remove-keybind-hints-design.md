# Remove Keybind Hints Design

**Date:** 2026-07-24
**Status:** Approved for implementation

## Goal

Remove every live world-map keyboard hint and obsolete keyboard movement binding before AC1.4 begins. Mouse selection remains the only world-map movement input.

## Scope

- Delete the complete `UI/NavigationHelp` subtree from `Scenes/game_world.tscn`, including the center hex and Q/W/E/A/S/D labels.
- Remove the `NavigationHelp` script `ext_resource` entry from `Scenes/game_world.tscn`; the scene must contain neither a node nor an external-resource reference to the deleted script.
- Delete `Scripts/UI/navigation_help.gd` and its Godot UID sidecar.
- Delete `Tests/Map/test_navigation_help_ui.gd` and its Godot UID sidecar.
- Remove the six `map_move_*` actions from `project.godot`.
- Update `Tests/Map/test_ac1_3_mouse_navigation.gd` to:
  - remove `_test_keyboard_action_is_ignored()`, which becomes semantically weak after the InputMap actions no longer exist;
  - assert that the scene has no `UI/NavigationHelp` node;
  - assert that none of the six `map_move_*` actions exists;
  - preserve the existing mouse-navigation behavior checks;
  - change `EXPECTED_TEST_COUNT` from `6` to `7`: remove one keyboard-event behavior check and add two explicit absence checks.

## Architecture

The keyboard hint is an isolated scene subtree with one drawing script and one dedicated test, so it should be removed rather than hidden or repurposed. The obsolete actions are removed from the project InputMap because `MapController` no longer consumes them. No replacement overlay is introduced.

Historical specifications, plans, and evidence remain unchanged. They describe prior milestones and verification history; they are not live UI or active input configuration.

## Error Handling

There is no runtime fallback. Loading `game_world.tscn` must succeed without the removed script, and mouse input remains authoritative through `HexTileView.tile_selected` and `MapController.request_move()`.

## Testing

The updated AC1.3 regression test must fail before removal while the overlay and InputMap actions still exist, then pass after removal. The deleted `test_navigation_help_ui.gd` must not be part of the post-change suite.

Run these exact scripts from `D:\Projects\two-dimension-exploration`:

```powershell
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_1_runtime_step_counts.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_encounter_determinism.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_hex_tile_view_states.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_runtime_encounter_layout.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_3_mouse_navigation.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_hex_map_model.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_map_controller_runtime.gd
```

Every command must exit `0` and print its suite-specific `PASS` line. A live GodotIQ runtime check must also confirm:

- no parser or missing-resource errors;
- no keybind overlay in the runtime UI;
- adjacent mouse clicks still move exactly once;
- every `map_move_*` InputMap action is absent.

## Out of Scope

- Replacing the removed hint with mouse instructions.
- Editing historical AC1.1/AC1.3 specifications or evidence.
- Changing mouse navigation, encounter generation, or AC1.4 behavior.
