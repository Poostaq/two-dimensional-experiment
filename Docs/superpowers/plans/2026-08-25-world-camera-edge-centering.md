# World Camera Edge-Centering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permit every radius-8 boundary hex to occupy the viewport center at 3-, 5-, and 11-hex framing while retaining bounded pan, live minimap footprint updates, and the existing dark overscan background.

**Architecture:** Keep `WorldCameraController.configure(world_rect, viewport_size, cell_flat_width)` source-compatible, but treat `world_rect` as legal camera-center bounds instead of a rectangle that must enclose the viewport. `WorldPresentationController` supplies exact canonical cell-center bounds. Existing camera signals continue publishing the full visible rectangle, including portions beyond the board.

**Tech Stack:** Godot 4.7, typed GDScript, Camera2D, axial hex coordinates, SceneTree headless tests, GodotIQ runtime and screenshot verification.

**Authority:** `Docs/superpowers/specs/2026-08-25-world-camera-edge-centering-design.md`.

---

## File map

| Path | Responsibility |
|---|---|
| `Scripts/WorldMap/world_camera_controller.gd` | Clamp camera center to supplied cell-center bounds at every zoom |
| `Scripts/WorldMap/world_presentation_controller.gd` | Calculate exact bounds of canonical radius-8 cell centers |
| `Tests/WorldMap/test_world_camera_controller.gd` | Unit contract for overscan and center-bound clamping |
| `Tests/WorldMap/test_world_presentation_scene.gd` | Six corners × three framings and live minimap integration |
| `Docs/Specs/WorldMap/Evidence/CameraEdgeCentering/` | RED/GREEN logs and inspected 3/5/11 boundary-centered captures |

### Task 1: Lock the camera-center bounds contract

**Files:**
- Modify: `Tests/WorldMap/test_world_camera_controller.gd`
- Create: `Docs/Specs/WorldMap/Evidence/CameraEdgeCentering/red/camera-edge-red.stdout.log`
- Create: `Docs/Specs/WorldMap/Evidence/CameraEdgeCentering/red/camera-edge-red.stderr.log`

- [ ] **Step 1: Replace viewport-enclosure assertions with center-bound assertions**

After configuring `Rect2(-800.0, -800.0, 1600.0, 1600.0)`, add exact boundary and overscan checks:

```gdscript
camera.call("center_on", Vector2(-800.0, -800.0))
_expect(camera.position == Vector2(-800.0, -800.0), "minimum boundary center is reachable")
_expect(not world_rect.encloses(camera.call("get_visible_world_rect")), "boundary centering exposes dark overscan")
camera.call("center_on", Vector2(800.0, 800.0))
_expect(camera.position == Vector2(800.0, 800.0), "maximum boundary center is reachable")
camera.call("center_on", Vector2(5000.0, -5000.0))
_expect(camera.position == Vector2(800.0, -800.0), "camera center cannot leave supplied bounds")
```

Retain the zero-turn, no-edge-scroll, drag, wheel, and `view_changed(Rect2)` assertions. Update `EXPECTED_TEST_COUNT` to the exact resulting count.

- [ ] **Step 2: Run the camera test RED**

Run:

```powershell
godot --headless --path . --script res://Tests/WorldMap/test_world_camera_controller.gd
```

Expected: exit `1`; the current half-viewport clamp prevents the boundary center positions.

- [ ] **Step 3: Capture RED stdout and stderr**

Store the exact command, exit code, stdout, and stderr under `Docs/Specs/WorldMap/Evidence/CameraEdgeCentering/red/`.

- [ ] **Step 4: Commit the RED contract**

```powershell
git add Tests/WorldMap/test_world_camera_controller.gd Docs/Specs/WorldMap/Evidence/CameraEdgeCentering/red
git commit -m "test: lock world camera edge-centering contract"
```

### Task 2: Clamp the camera center instead of the visible viewport

**Files:**
- Modify: `Scripts/WorldMap/world_camera_controller.gd`
- Test: `Tests/WorldMap/test_world_camera_controller.gd`

- [ ] **Step 1: Implement center-bound clamping**

Replace `_clamp_position()` with:

```gdscript
func _clamp_position() -> void:
	var minimum := _world_rect.position
	var maximum := _world_rect.end
	position.x = clampf(position.x, minimum.x, maximum.x)
	position.y = clampf(position.y, minimum.y, maximum.y)
```

Do not change `configure`, `center_on`, `pan_by`, `zoom_by_steps`, `get_visible_world_rect`, input ownership, or `view_changed` signatures. Continue emitting `view_changed` after configure, center, pan, and zoom.

- [ ] **Step 2: Run GodotIQ convention and parser checks**

Run `validate` and `check_errors` for `res://Scripts/WorldMap/world_camera_controller.gd`. Expected: zero issues and zero parser errors.

- [ ] **Step 3: Run the camera test GREEN**

Run the Task 1 command. Expected: exit `0`, all assertions pass, stderr is empty.

- [ ] **Step 4: Commit the implementation**

```powershell
git add Scripts/WorldMap/world_camera_controller.gd
git commit -m "feat: allow boundary hex camera centering"
```

### Task 3: Supply canonical radius-8 cell-center bounds

**Files:**
- Modify: `Tests/WorldMap/test_world_presentation_scene.gd`
- Modify: `Scripts/WorldMap/world_presentation_controller.gd`

- [ ] **Step 1: Write the six-corner, three-framing integration test**

Use the canonical corners and exact world projection:

```gdscript
var corners: Array[Vector2i] = [
	Vector2i(-8, 0), Vector2i(-8, 8), Vector2i(0, -8),
	Vector2i(0, 8), Vector2i(8, -8), Vector2i(8, 0),
]
for framing: int in [3, 5, 11]:
	camera.set_default_zoom()
	if framing == 3:
		camera.zoom_by_steps(100, Vector2(576.0, 324.0))
	elif framing == 11:
		camera.zoom_by_steps(-100, Vector2(576.0, 324.0))
	for corner: Vector2i in corners:
		var target: Vector2 = preview.call("axial_to_world", corner)
		camera.center_on(target)
		_expect(camera.position.is_equal_approx(target), "%s centers at %d-hex framing" % [corner, framing])
```

Record the minimap footprint before and after opposite-corner centers and assert it changes while `get_plan_instance_id()` remains constant.

- [ ] **Step 2: Run the presentation test RED**

Run:

```powershell
godot --headless --path . --script res://Tests/WorldMap/test_world_presentation_scene.gd
```

Expected: exit `1`; `_calculate_world_rect()` currently adds render margins rather than returning exact cell-center extrema.

- [ ] **Step 3: Return exact canonical cell-center bounds**

Replace the final margin calculation in `_calculate_world_rect()` with:

```gdscript
return Rect2(minimum, maximum - minimum)
```

The rectangle is used only as legal Camera2D center bounds. Do not clamp the minimap footprint to this rectangle.

- [ ] **Step 4: Validate and run integration GREEN**

Run GodotIQ `validate` and `check_errors` for the controller, then rerun the presentation test. Expected: all six corners center at all three framings, minimap footprint changes, shared plan identity remains stable, and stderr is empty.

- [ ] **Step 5: Commit integration**

```powershell
git add Scripts/WorldMap/world_presentation_controller.gd Tests/WorldMap/test_world_presentation_scene.gd
git commit -m "test: verify radius-8 edge centering"
```

### Task 4: Capture visual and regression evidence

**Files:**
- Create: `Docs/Specs/WorldMap/Evidence/CameraEdgeCentering/green/automated-tests.log`
- Create: `Docs/Specs/WorldMap/Evidence/CameraEdgeCentering/visual/edge-centered-3-hex.png`
- Create: `Docs/Specs/WorldMap/Evidence/CameraEdgeCentering/visual/edge-centered-5-hex.png`
- Create: `Docs/Specs/WorldMap/Evidence/CameraEdgeCentering/visual/edge-centered-11-hex.png`
- Create: `Docs/Specs/WorldMap/Evidence/CameraEdgeCentering/visual/visual-review.md`

- [ ] **Step 1: Capture three representative boundary-centered screenshots**

Run `res://Scenes/world_map_preview.tscn`, center the camera on `Vector2i(8, 0)`, and capture 1152×648 PNGs at 3-, 5-, and 11-hex framing. Persist the PNGs and their Godot `.import` files under the visual evidence directory.

- [ ] **Step 2: Inspect the actual PNGs**

Record whether the selected boundary cell is centered, outside-board space is the existing dark background, HUD/minimap remain readable, and the minimap footprint grows across 3/5/11 framing. Correct defects before approval; do not auto-approve pixel baselines.

- [ ] **Step 3: Run the focused and frozen regression gates**

Run these exact scripts individually with exit and stderr capture:

```text
res://Tests/WorldMap/test_world_camera_controller.gd
res://Tests/WorldMap/test_world_minimap.gd
res://Tests/WorldMap/test_world_presentation_scene.gd
res://Tests/WorldMap/test_world_visual_fixtures.gd
res://Tests/Map/test_hex_map_model.gd
res://Tests/Map/test_map_controller_runtime.gd
res://Tests/Map/test_world_turn_counter.gd
```

Expected: seven exit codes `0`; every stderr file has zero bytes.

- [ ] **Step 4: Verify runtime and production isolation**

Use GodotIQ `verify_project_runs` for `res://Scenes/world_map_preview.tscn` and `main`; expect PASS and zero debugger entries. Run:

```powershell
git diff --exit-code main -- Scenes/game_world.tscn Scripts/Map Tests/Map
```

Expected: exit `0`; production authority remains `res://Scenes/game_world.tscn`.

- [ ] **Step 5: Commit evidence**

```powershell
git add Docs/Specs/WorldMap/Evidence/CameraEdgeCentering
git commit -m "test: record world camera edge-centering evidence"
```

## Final acceptance

- [ ] All six radius-8 corner cells can occupy viewport center at 3-, 5-, and 11-hex framing.
- [ ] Camera center cannot move beyond canonical cell-center extrema.
- [ ] Dark background fills outside-board overscan.
- [ ] Minimap footprint remains live and represents overscan without mutating the plan.
- [ ] Camera navigation consumes zero turns and has no edge scrolling.
- [ ] HUD and minimap remain readable in all three inspected captures.
- [ ] Production scene and frozen map boundary remain unchanged.
