# AC7.1 verification — 2026-09-17

**Verdict: PASS WITH WARNINGS.** AC7.1 is implemented and verified. Project convention checks retain the baseline 27 warnings and 6 informational findings; there are no script errors or orphan signals. No blocking failures remain.

## Implementation and scope

Documentation was merged into local `main` at `8119e2c`; implementation commit `671612c` used `feature/ac7-1-living-lanes`, inline without subagents. The reusable unit scene displays a scene-authored figure, role and slot position, name, HP bar/value, and Armor/Advantage/Snared/Bleed/Speed badges. Full badge names and descriptions are included in the slot tooltip. Role lookup uses authored skill identity; unknown units use Combatant. No combat rules, character constructor, or save schema changed.

Views remain attached to stable side/slot positions. Occupant identity, role, figure, HP, and statuses move on Swap. Empty slots retain their identity. Defeated occupants retain their name and show zero HP plus a Defeated marker. Authoritative-change notification now refreshes unit presentation as well as action previews.

Implementation adjustments to the plan:

- Inspection confirmed the old public slot arrays followed interleaved flat-grid child order, rather than the numeric ordering assumed in the plan's baseline section. Getters now explicitly return indices 0–5; front/back membership, targeting lane arithmetic, adjacency, and turn tie ordering remain unchanged. Two old visual-order expectations and one direct scene path were migrated; their combat assertions remain intact.
- Occupied views combine role and slot position in one line; empty views show the standalone slot label. Short status labels preserve room for all five categories, with full names in tooltips.
- Removed redundant side headings, bounded the existing log scroll area, and placed existing default-action Confirm/Cancel controls beside Attack/Swap. The existing action controls and handlers are retained; this does not implement AC7.3's unified action bar or AC7.4's drawer.
- Shared scene instances use editor inheritance so size/style changes propagate. The current-actor frame expands through card padding to avoid covering text.
- Used the existing refresh path instead of adding a global BattleUiSnapshot prerequisite.
- AC7.2–AC7.5 remain pending. The approved oracle was not modified. Figures are simple role silhouettes; there is no new portrait-art pack.

## Automated evidence

Godot executable: `D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe` (Godot 4.7.2).

Run each test with:

```powershell
$godotExe = 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $godotExe --headless --path . --script res://Tests/Battle/test_ac7_1_living_lanes.gd
```

The complete run used Python `subprocess.run(..., capture_output=True, timeout=45)` to wait for the Windows executable and record each exit code, stdout, and stderr. All **23 test runners exited 0**: every `Tests/Battle/test_*.gd` (21 runners), `Tests/Run/test_ac3_3_party_formation.gd`, and `Tests/WorldMap/test_world_battle_entry.gd`. Individual logs are in this directory. Some existing negative-data tests deliberately call `push_error`; those messages were present in the baseline too. Final logs contain no SCRIPT ERROR, failed assertion, or resource-leak messages.

The new AC7.1 test first failed for absent lane containers, reusable renderers, HP bars, and figures. It now passes: twelve stable slots; numeric getter order; lane membership; occupied/empty/defeated states; HP refresh; Swap forwarding and view identity; all five status categories and cleanup; read-only repeat rendering; zero-net active speed effects; role lookup after renaming; commander priority; unknown fallback; and battle reset/removal cleanup.

## Rendered interaction and layout evidence

```powershell
& $godotExe --path . --rendering-method gl_compatibility --script res://Tests/Battle/capture_ac7_1_living_lanes.gd
```

**PASS**, exit 0, no stderr. See [rendered-qa.log](rendered-qa.log). The fixture injects mouse and keyboard events through the viewport input pipeline; it does not directly emit button signals for the interaction checks. It verifies pointer Attack/target/Cancel, keyboard Enter activation of Attack, pointer target/Confirm causing HP 20→14, and pointer Swap exchanging slots 0 and 3. Geometry checks verify the complete HUD and every slot remain inside the viewport and all active badges remain inside their cards.

Screenshots were rendered by the running Godot viewport and inspected directly:

| Evidence | Observations |
|---|---|
| [Dense, 1152×648](living-lanes-dense-1152.png) | All twelve figures, names, roles, HP bars, and all five status badges visible. Long name wraps within the card. |
| [Dense targeting, 1152×648](living-lanes-dense-target-1152.png) | Current frame does not cover text; skill controls, Attack/Swap, Confirm/Cancel, summary, and log region remain in bounds. |
| [Dense, 1280×720](living-lanes-dense-1280.png) | Actual logical HUD size is 1280×720; long name fits, all four lanes and statuses remain readable. |
| [Sparse and defeated](living-lanes-sparse-1152.png) | Empty slot markers and a dimmed defeated figure with retained identity and zero HP are distinct. |
| [Target selection](living-lanes-target-1152.png) | Existing targeting and confirmation controls remain visible. |
| [After Swap](living-lanes-swapped-1152.png) | Vanguard and Rear Guard exchange front/back occupants while slot positions remain fixed; damaged enemy shows HP 14/20. |

GodotIQ `explore(mode="tour")` and screenshot capture timed out on this Control-based scene. A runtime restart restored state queries but not capture. The rendered fixture above supplied visual and real-input evidence instead; no visual pass was inferred from headless tests.

## Structured checks and inline review

- GodotIQ `check_errors(scope="project")`: 157 scripts checked, **0 errors**.
- GodotIQ `validate(target="project")`: 157 scripts and 13 scenes checked, **0 errors, 27 warnings, 6 info**, matching the starting warning/info counts. New scripts have zero convention findings. The modified arena retains its pre-existing `effect_color` type-hint warning.
- `signal_map(find="orphans")`: **0 orphans**. Its missing-signal list refers to native Control signals emitted by test fixtures, not undeclared production signals.
- `verify_project_runs(scene="res://Scenes/battle_arena.tscn")`: **PASS**, no captured runtime/script errors.
- Final `verify_project_runs(scene="main", stop_after=true)`: **PASS** for `world_run_start.tscn`, no captured runtime/script errors; game stopped.
- Inline diff review checked scene inheritance, ID/slot separation, read-only status rendering, input passthrough, refresh boundaries, unchanged combat rules, obsolete test-path migration, and AC7.1 coverage. No subagent review was used, as requested.

The evidence folder is excluded from Godot asset imports with `.gdignore`.
