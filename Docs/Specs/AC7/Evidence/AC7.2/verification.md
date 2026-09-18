# AC7.2 verification — 2026-09-18

**Verdict: PASS WITH WARNINGS.** AC7.2 is implemented and verified. No blocking failures remain. Project convention checks retain the baseline 27 warnings and 6 informational findings; there are zero script errors and zero orphan signals.

## Implementation and scope

Implementation commit: `0df1ee0`, branch `feature/ac7-2-turn-order-ribbon`, based on completed AC7.1 at `cf52969`. Local main was updated from origin, then fast-forwarded to the completed AC7.1 branch before creating this task branch. Work was performed inline in the primary workspace.

Added authored ribbon and entry scenes, a presentation-only ribbon controller, a dedicated unit-view preview overlay/setter, and arena preview routing. The ribbon presents the remaining current-round queue, pins the current actor with a persistent gold frame and `NOW`, and horizontally scrolls later entries. Full identity/team/ordinal are exposed through accessible names and tooltips; visible team labels supplement color. Hover takes precedence over focus, with focus resuming on pointer exit. Tab/Shift-Tab can traverse and leave the ribbon. Entry activation does not perform a combat action.

The cyan preview outline and `ORDER` marker are independent of existing current-turn, target, effect and damage layers. The arena resolves stable IDs to current slot occupants and reapplies preview after unit rendering. Benign refresh retains entry instances/focus; turn, phase, reset, defeat and removal boundaries clear stale previews.

Final diff review confirmed no changes to queue construction or sorting, tie-breaking, authoritative turn/round mutations, formation rules, save data, targeting legality, action resolution or transactions. Existing lifecycle functions gained presentation calls only. No global visual-state resolver, unified action bar or debug drawer was introduced. AC7.3–AC7.5 remain pending.

## Layout adjustments and fixes

- The first integration exceeded the 648-pixel viewport. Existing encounter/round/current labels now share a header; existing debug buttons share the log heading; existing skill confirmation text and buttons share a horizontal row. All original controls, unique names and handlers remain. These are container-layout adjustments required to fit the new ribbon, not new action mechanics.
- Visual inspection found the first preview outline crossed character text because PanelContainer already applies content padding. Its scene offsets now derive from that padding, keeping the border outside content. A geometry assertion reproduced the defect before the fix and passes afterward.
- The initial test failed for the absent ribbon and twelve absent preview overlays. The final AC7.2 runner passes. The original viewport regressions also pass without weakening their assertions.
- The approved oracle was not edited. Initials serve as the entry icon fallback; character artwork is unchanged.

## Automated evidence

Godot executable: `D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`, Godot **4.7.2**.

**25 distinct automated runners passed:** all 22 `Tests/Battle/test_*.gd` runners, `Tests/Run/test_ac3_3_party_formation.gd`, `Tests/WorldMap/test_world_battle_entry.gd`, and `Tests/UI/test_ac6_6_preparation_ui.gd`. Each exited zero. Logs are adjacent to this document. Known negative-data tests emit deliberate validation errors also present in the baseline; no final log contains a script error, failed assertion or resource-leak warning.

The new [AC7.2 test log](test_ac7_2_turn_order_ribbon.log) covers authoritative display ordering, tied speeds, twelve entries, duplicate display names, `NOW` persistence, pointer/focus arbitration including delayed exit, no combat-state mutation, focus retention on HP refresh, round rollover, reset with reused IDs, defeated exclusion without queue mutation, removal, occupant relocation, preparation, empty state and terminal completion.

Reproduce all automated checks from the repository root:

```powershell
@'
from pathlib import Path
import subprocess
exe = r'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
tests = sorted(Path('Tests/Battle').glob('test_*.gd')) + [
    Path('Tests/Run/test_ac3_3_party_formation.gd'),
    Path('Tests/WorldMap/test_world_battle_entry.gd'),
    Path('Tests/UI/test_ac6_6_preparation_ui.gd'),
]
for test in tests:
    result = subprocess.run([exe, '--headless', '--path', '.', '--script',
                             'res://' + test.as_posix()],
                            capture_output=True, text=True, timeout=60)
    print(test, result.returncode)
    print(result.stdout + result.stderr)
    assert result.returncode == 0
    assert 'SCRIPT ERROR' not in result.stdout + result.stderr
'@ | python -
```

## Rendered input and inspected images

[Rendered QA log](rendered-qa.log): **PASS**, exit zero. The fixture uses viewport mouse motion/button events and keyboard events, rather than emitted button signals, to verify pointer preview, all twelve Tab stops, scroll-to-focus, Tab exit, Shift-Tab reentry, inert Enter activation, real Attack/target/Cancel input, and selected-skill target preservation. It verifies viewport bounds, status bounds, pinned current visibility, and preview-outline clearance around text.

```powershell
@'
import subprocess
exe = r'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
result = subprocess.run([exe, '--path', '.', '--rendering-method', 'gl_compatibility',
                         '--script', 'res://Tests/Battle/capture_ac7_2_turn_order_ribbon.gd'],
                        capture_output=True, text=True, timeout=60)
print(result.stdout + result.stderr)
assert result.returncode == 0
'@ | python -
```

All ten captured images were inspected after the final layout/outline corrections:

| Image | Observation |
|---|---|
| [Dense 1152×648](ribbon-dense-1152.png) | Twelve characters, all five status categories, long name wrapping, ribbon and action controls fit. Upcoming entries scroll; current actor remains pinned. |
| [Current actor preview](ribbon-current-preview.png) | Gold `NOW` remains; current character retains its white frame and gains the cyan preview/`ORDER` marker without covering text. |
| [Enemy pointer preview](ribbon-enemy-preview.png) | Exactly the matching enemy has a cyan outline; current actor retains its separate frame. |
| [Keyboard scroll](ribbon-keyboard-scrolled.png) | Last enemy entry is visibly keyboard-focused and scrolled into view; matching backline character is emphasized; `NOW` remains visible. |
| [Dense 1280×720](ribbon-dense-1280.png) | Entire HUD fits the larger logical viewport; focus and linked preview survive the size change. |
| [Default Attack overlap](ribbon-target-overlap.png) | Selected Attack summary and Confirm/Cancel remain visible while its target receives ribbon preview. |
| [Skill target overlap](ribbon-skill-target-overlap.png) | Green skill-target indicator and cyan ribbon outline/marker remain distinct; confirmation controls fit. |
| [After turn](ribbon-after-turn.png) | `NOW` moves to Rear Guard and old preview clears. |
| [After defeat](ribbon-after-defeat.png) | Defeated opponent is absent from the ribbon; its card retains identity, zero HP and defeat text, without preview. |
| [After reset](ribbon-after-reset.png) | Reused arena displays the fresh queue and clears old occupant/preview state. |

## Structured runtime and final review

- `validate(target="project", detail="brief")`: 160 scripts, 15 scenes, **0 errors, 27 warnings, 6 info**, matching baseline severity counts.
- `check_errors(scope="project")`: **160 scripts checked, zero errors**. New ribbon/test scripts have no convention findings; the arena retains its pre-existing warning.
- `signal_map(find="orphans")`: **zero orphans**. Reported missing definitions are native Control signals emitted in fixtures, not missing production signal declarations.
- GodotIQ `run(play)` and `verify_project_runs(scene="res://Scenes/battle_arena.tscn")`: **PASS**, no runtime/script errors in `read_debug_console()`.
- `state_inspect`: round 1, current context `player_4:1:false:false`, empty initial preview ID, confirming the live adapter initializes without stale preview.
- `explore(mode="tour", max_areas=1, screenshots_per_area=1, scale=0.25, quality=0.3)`: **one area and one visible screenshot**. The default battle shows the pinned current entry, four readable lanes, skill/default-action controls and the log/debug row within the viewport. Full-size rendered images above provide detailed interaction evidence.
- `verify_project_runs(scene="main", stop_after=true)`: **PASS** for `world_run_start.tscn`, no captured runtime/script errors. Game stopped.
- Inline review covered ID/slot separation, read-only queue presentation, focus retention and cleanup, authored scene ownership, mouse passthrough, overlay independence, unchanged combat mutation order and bounded layout. `git diff --check` passed. No subagent review was used.

The evidence directory includes `.gdignore` so logs and screenshots are not imported as game assets. No blocking evidence is missing. The remaining warnings are the recorded pre-existing convention findings.
