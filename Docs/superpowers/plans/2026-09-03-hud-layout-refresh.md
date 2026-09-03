# HUD Layout Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the world-map HUD so its compact top bar, smaller minimap, and narrower bordered party preview use screen edges consistently without changing HUD behavior.

**Architecture:** Keep layout ownership in the existing Godot scenes and preserve `WorldMapHud`'s public API. Add layout assertions to the existing scene-instantiation tests first, then use GodotIQ scene operations to change anchors, offsets, text, and theme overrides. Verify the composed runtime at the reference viewport and one narrower viewport.

**Tech Stack:** Godot 4, GDScript scene-tree tests, GodotIQ scene/runtime tools, PowerShell test commands.

---

## File map

- Modify `Tests/UI/test_world_map_hud.gd`: assert top-bar, information alignment, party-panel, heading, slot-border, and button geometry.
- Modify `Tests/WorldMap/test_world_minimap.gd`: assert the minimap's 225×225 size and left/top-bar alignment contract.
- Modify `Scenes/world_map_hud.tscn`: author the compact responsive top bar and integrated party-preview panel.
- Modify `Scenes/world_minimap.tscn`: author the 75-percent minimap size and edge placement.
- Inspect `Scenes/world_map_runtime.tscn`: verify the two scene instances compose correctly; modify only if its instance offsets override the child scenes.
- Preserve `Scripts/UI/world_map_hud.gd`: no behavioral change is expected because unique node names remain stable.

### Task 1: Add failing HUD layout coverage

**Files:**
- Modify: `Tests/UI/test_world_map_hud.gd`
- Test: `Tests/UI/test_world_map_hud.gd`

- [ ] **Step 1: Inspect the test before editing**

Run GodotIQ `file_context(file="Tests/UI/test_world_map_hud.gd", detail="brief")`, followed by `script_ops(op="read", path="Tests/UI/test_world_map_hud.gd", detail="full")`.

- [ ] **Step 2: Extend the assertion count and add geometry helpers**

Change `EXPECTED_TEST_COUNT` from `25` to `42`, then add these helpers before `_on_party_requested`:

```gdscript
func _rect(control: Control) -> Rect2:
	return control.get_global_rect()


func _has_visible_border(label: Label) -> bool:
	var style := label.get_theme_stylebox("normal")
	return (
		is_instance_valid(style)
		and style.get_border_width(SIDE_LEFT) > 0
		and style.get_border_width(SIDE_TOP) > 0
		and style.get_border_width(SIDE_RIGHT) > 0
		and style.get_border_width(SIDE_BOTTOM) > 0
	)
```

- [ ] **Step 3: Add layout assertions after the first `process_frame`**

Insert the following before the existing heading checks:

```gdscript
	var top_bar := hud.get_node("%TopBar") as Control
	var cache := hud.get_node("%CacheStatusLabel") as Control
	var remaining := hud.get_node("%RemainingLabel") as Control
	var boss := hud.get_node("%BossStateLabel") as Control
	var formation := hud.get_node("%FormationPanel") as Control
	var manage_button := hud.get_node("%ManagePartyButton") as Control
	_expect(is_equal_approx(_rect(top_bar).position.x, 0.0), "top bar is flush left")
	_expect(is_equal_approx(_rect(top_bar).size.x, hud.size.x), "top bar spans the viewport")
	_expect(_rect(top_bar).size.y <= 48.0, "top bar is compact")
	_expect(_rect(cache).position.x < hud.size.x * 0.25, "Cache information is left aligned")
	_expect(_rect(remaining).end.x <= _rect(boss).position.x, "boss countdown precedes boss state")
	_expect(_rect(boss).end.x >= hud.size.x - 24.0, "boss information is right aligned")
	_expect(is_equal_approx(_rect(formation).position.x, 0.0), "party preview is flush left")
	_expect(_rect(formation).size.x <= 260.0, "party preview is narrow")
	_expect(_rect(formation).encloses(_rect(manage_button)), "Manage Party is inside party preview")
	_expect(_rect(manage_button).size.x < _rect(formation).size.x, "Manage Party is narrower than party preview")
	_expect(abs(_rect(manage_button).get_center().x - _rect(formation).get_center().x) <= 1.0, "Manage Party is centered")
```

Replace the two heading expectations with:

```gdscript
	_expect((hud.get_node("%BackLineLabel") as Label).text == "BACK", "back column is labeled Back")
	_expect((hud.get_node("%FrontLineLabel") as Label).text == "FRONT", "front column is labeled Front")
```

Inside the existing three-slot loop, add:

```gdscript
		_expect(_has_visible_border(hud.get_node("%%BackSlot%d" % index) as Label), "back slot %d has a border" % index)
		_expect(_has_visible_border(hud.get_node("%%FrontSlot%d" % index) as Label), "front slot %d has a border" % index)
```

- [ ] **Step 4: Validate the edited test**

Run GodotIQ `validate(target="Tests/UI/test_world_map_hud.gd", detail="brief")`, then `check_errors(scope="Tests/UI/test_world_map_hud.gd")`. Expected: no parser errors.

- [ ] **Step 5: Run the test and confirm the layout assertions fail**

```powershell
godot --headless --path . --script res://Tests/UI/test_world_map_hud.gd
```

Expected: exit code `1`, with failures for the old inset top bar, old headings, wide party panel, missing slot borders, or external button.

- [ ] **Step 6: Commit the red test**

```powershell
git add -- Tests/UI/test_world_map_hud.gd
git commit -m "test: define refreshed HUD layout"
```

### Task 2: Author the compact top bar and integrated party preview

**Files:**
- Modify: `Scenes/world_map_hud.tscn`
- Test: `Tests/UI/test_world_map_hud.gd`

- [ ] **Step 1: Inspect the scene and change impact**

Run GodotIQ `file_context(file="Scenes/world_map_hud.tscn", detail="brief")`, then `impact_check(file="Scenes/world_map_hud.tscn", action="modify layout while preserving unique node names", target="TopBar, FormationPanel, ManagePartyButton")`.

- [ ] **Step 2: Apply the scene-native layout with one GodotIQ batch**

Use `node_ops` on `res://Scenes/world_map_hud.tscn` to set this property contract, retaining every unique node name:

```text
TopBar: left=0, top=0, right=viewport right, height=48
CacheStatusLabel: left margin=16, vertically centered in TopBar, width=180
MoveCountLabel: placed after CacheStatusLabel on the left, vertically centered
RemainingLabel: placed immediately before BossStateLabel on the right
BossStateLabel: right margin=16, vertically centered, width=180
FormationPanel: left=0, bottom=viewport bottom, width=252, height=232
BackLineLabel.text: "BACK"
FrontLineLabel.text: "FRONT"
BackSlot0..2 and FrontSlot0..2: 106×34 cells with a 1-pixel border StyleBoxFlat
ManagePartyButton: child/visual member of FormationPanel region, width=150, height=40,
  horizontally centered, 12 pixels below the final slot row and 12 pixels above panel bottom
ContextBar: left offset at least 268 so it does not overlap FormationPanel
```

Use anchors for viewport edges and offsets for the fixed compact dimensions. If reparenting the button is unsupported by the bridge, retain its scene parent but place its rectangle fully inside `FormationPanel`; the visual and geometry contract is authoritative.

- [ ] **Step 3: Save and validate the HUD scene**

Run `save_scene(expected_scene="res://Scenes/world_map_hud.tscn")`, `validate(target="Scenes/world_map_hud.tscn", detail="brief")`, then `check_errors(scope="Scenes/world_map_hud.tscn")`. Expected: saved scene, no incomplete controls, no parser errors.

- [ ] **Step 4: Run the HUD test to green**

```powershell
godot --headless --path . --script res://Tests/UI/test_world_map_hud.gd
```

Expected: `World map HUD tests: PASS (42/42)` and exit code `0`.

- [ ] **Step 5: Run the cache regression test**

```powershell
godot --headless --path . --script res://Tests/UI/test_ac6_6_cache_hud.gd
```

Expected: `PASS test_ac6_6_cache_hud (5/5)` and exit code `0`.

- [ ] **Step 6: Commit the HUD scene**

```powershell
git add -- Scenes/world_map_hud.tscn
git commit -m "feat: refresh world map HUD layout"
```

### Task 3: Add and implement the minimap size contract

**Files:**
- Modify: `Tests/WorldMap/test_world_minimap.gd`
- Modify: `Scenes/world_minimap.tscn`

- [ ] **Step 1: Inspect both files before editing**

Run `file_context` for both files and `script_ops(op="read", path="Tests/WorldMap/test_world_minimap.gd", detail="full")`.

- [ ] **Step 2: Add the failing minimap layout assertions**

Change `EXPECTED_TEST_COUNT` from `24` to `28` and add after the first `process_frame`:

```gdscript
	var minimap_rect := minimap.get_global_rect()
	_expect(is_equal_approx(minimap_rect.position.x, 0.0), "minimap is flush left")
	_expect(is_equal_approx(minimap_rect.position.y, 48.0), "minimap touches the top bar")
	_expect(is_equal_approx(minimap_rect.size.x, 225.0), "minimap width is 75 percent")
	_expect(is_equal_approx(minimap_rect.size.y, 225.0), "minimap height is 75 percent")
```

- [ ] **Step 3: Validate and run the red minimap test**

Run `validate(target="Tests/WorldMap/test_world_minimap.gd", detail="brief")`, `check_errors(scope="Tests/WorldMap/test_world_minimap.gd")`, then:

```powershell
godot --headless --path . --script res://Tests/WorldMap/test_world_minimap.gd
```

Expected: exit code `1` because the current minimap is approximately 300×300 and does not begin at `(0, 48)`.

- [ ] **Step 4: Update the minimap scene**

Use GodotIQ `node_ops` on `res://Scenes/world_minimap.tscn` to set the root `WorldMinimap` to top-left anchors, position `(0, 48)`, and size `(225, 225)`. Scale or resize its authored background and drawing region consistently so all markers and camera footprint remain inside the new bounds; do not change projection or marker-update logic.

- [ ] **Step 5: Save, validate, and run the green minimap test**

Run `save_scene(expected_scene="res://Scenes/world_minimap.tscn")`, `validate(target="Scenes/world_minimap.tscn", detail="brief")`, `check_errors(scope="Scenes/world_minimap.tscn")`, then:

```powershell
godot --headless --path . --script res://Tests/WorldMap/test_world_minimap.gd
```

Expected: `World minimap tests: PASS (28/28)` and exit code `0`.

- [ ] **Step 6: Commit the minimap contract**

```powershell
git add -- Tests/WorldMap/test_world_minimap.gd Scenes/world_minimap.tscn
git commit -m "feat: resize and align world minimap"
```

### Task 4: Verify composed HUD behavior and responsive layout

**Files:**
- Inspect: `Scenes/world_map_runtime.tscn`
- Test: `Tests/UI/test_world_map_hud.gd`
- Test: `Tests/UI/test_ac6_6_cache_hud.gd`
- Test: `Tests/WorldMap/test_world_minimap.gd`

- [ ] **Step 1: Run the focused regression suite**

```powershell
$tests = @(
  'res://Tests/UI/test_world_map_hud.gd',
  'res://Tests/UI/test_ac6_6_cache_hud.gd',
  'res://Tests/WorldMap/test_world_minimap.gd'
)
foreach ($test in $tests) {
  & godot --headless --path . --script $test
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: all three tests print PASS and the loop exits `0`.

- [ ] **Step 2: Validate the complete project and signal graph**

Run GodotIQ `validate(target="project", detail="brief")`, `check_errors(scope="project")`, and `signal_map(find="orphans")`. Expected: no new convention errors, parser errors, or orphaned HUD signals.

- [ ] **Step 3: Launch the composed runtime**

Run GodotIQ `run(action="play", scene="res://Scenes/world_map_runtime.tscn")`, then `verify_project_runs(scene="res://Scenes/world_map_runtime.tscn", check_scope="project", stop_after=false)`. Expected: Play starts with no failing errors.

- [ ] **Step 4: Inspect the reference viewport**

Use `ui_map(root="/root", max_depth=6, detail="full")` to confirm the exact geometry contract at 1152×648, then capture one `screenshot(scale=0.25, quality=0.3)`. Confirm visually that the top bar is edge-to-edge, the minimap is 225×225 below it, the party panel is flush left, every slot is bordered, and the centered button stays inside the panel.

- [ ] **Step 5: Inspect one alternate viewport width**

Set the running window to an alternate supported width through the editor/runtime controls, then repeat `ui_map`. Confirm cache remains left, boss information remains right, and neither the party panel nor context panel overlap. Restore the reference viewport afterward.

- [ ] **Step 6: Stop Play and inspect the final diff**

Run GodotIQ `run(action="stop")`, then:

```powershell
git diff --check
git status --short
git diff --stat main...HEAD
```

Expected: no whitespace errors and only the design, plan, focused tests, and relevant HUD/minimap scenes are tracked changes; unrelated untracked files remain unstaged.

- [ ] **Step 7: Commit any final integration-only adjustment**

If `Scenes/world_map_runtime.tscn` required removal of overriding offsets, stage only that scene and commit:

```powershell
git add -- Scenes/world_map_runtime.tscn
git commit -m "fix: preserve HUD edge alignment in runtime"
```

If no integration adjustment was required, do not create an empty commit.
