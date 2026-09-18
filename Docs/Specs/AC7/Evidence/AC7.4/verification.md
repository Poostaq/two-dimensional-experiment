# AC7.4 debug drawer verification

Verified 2026-09-18 on `feature/ac7-4-debug-drawer`. Implementation: `57429e0`. Dependency: AC7.3 `db6de5b` plus verification `a847d7b`, fast-forwarded into local main before branching.

Godot: `4.7.2.stable.steam.ed1daf0bf`, executable `D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`. Rendered checks used OpenGL compatibility on NVIDIA RTX 3080. Supported verification sizes: 1152×648 and 1024×648.

## Results

- Baseline: 26 automated runners passed before implementation; project checks had zero errors, 27 warnings and 6 informational findings.
- Final: all 24 Battle runners plus party formation, world battle entry and preparation UI passed (27 runners). Individual `test_*.log` files in this directory contain output. Existing intentional invalid-data diagnostics remain; no runner produced `SCRIPT ERROR` or `FAILED:`. AC7.4, reward selection and skill lifecycle were rerun after the recruitment guard fix and passed.
- [Rendered pointer/keyboard runner](rendered-qa.log): PASS. Exercises handle/Close, Tab/Shift+Tab, Enter/Space, Escape, real damage command, history hover, actual wheel position change, closed-panel Tab exclusion, and the same covered Attack target blocked while open and selectable after close.
- GodotIQ final project checks: zero script errors, unchanged 27 warnings and 6 informational findings; no orphaned signals. The signal scanner lists native UI signals emitted by tests as missing project definitions, not missing runtime signals.
- Production main scene `world_run_start.tscn`: `verify_project_runs` PASS, empty captured debug console. Battle scene also launched with runtime attached; tour returned one visible overview showing the collapsed handle, readable formations and action bar. Game stopped after verification.
- Read-only implementation review found a recruitment modal guard gap and missing input assertions. Both were corrected; follow-up review reported no remaining important defects. No combat-rule/queue/transaction modules changed.

## Commands

Run each `Tests/Battle/test_*.gd`, plus `Tests/Run/test_ac3_3_party_formation.gd`, `Tests/WorldMap/test_world_battle_entry.gd`, and `Tests/UI/test_ac6_6_preparation_ui.gd` using:

```text
godot.windows.opt.tools.64.exe --headless --path . --script res://<runner path>
godot.windows.opt.tools.64.exe --path . --rendering-method gl_compatibility --script res://Tests/Battle/capture_ac7_4_debug_drawer.gd
```

The execution harness used Python `subprocess.run` with captured stdout/stderr and a 60-second per-runner timeout, checked zero exit and absence of `SCRIPT ERROR`/`FAILED:`, and wrote the logs here. GodotIQ `validate` and `check_errors` were run after each script edit. `git diff --check` passed before the implementation commit.

## Acceptance mapping

| Contract | Evidence |
|---|---|
| Collapsed default and no reflow | `test_ac7_4_debug_drawer.log`: exact formation, twelve slot, ribbon, bar and result rectangles before/after open and close at both sizes; rendered captures below |
| Current diagnostics and queue | AC7.4 tests compare every queue ID, order, effective speed and current marker, round and revision, including removal and rollover; skill, target, Swap and cancel refresh checks |
| Existing commands | AC7.4 one-click seven damage, one entry and one turn advance; closed/resolving/empty-queue rejection; AC2.2/2.3/2.4 and skill lifecycle retain command and exit semantics |
| Log history and preview | Stable row identity, chronological append, late-exit source guard, close cleanup, hidden updates, newest-row scroll and actual wheel movement |
| Focus/input | Real Tab/Shift+Tab/Enter/Space/Escape; hidden-panel exclusion; fallback when original focused control is freed; selected-action preservation and click-through prevention |
| Reset and modal ownership | Append/reset race, same-ID reset, diagnostics scroll reset; preparation, reward, pending recruitment, recruitment cancellation and next-battle handle restoration |
| Prior behavior | All Battle runners plus listed integration runners and clean production startup |

## Inspected screenshots

- [Closed 1152](drawer-closed-1152.png), [closed 1024](drawer-closed-1024.png): only the right-edge handle remains; all formations and action controls fit.
- [Open 1152](drawer-open-1152.png), [open 1024](drawer-open-1024.png): opaque, bordered panel overlays battle content; live state/queue scroll independently of reachable command controls. Opening preserves the selected Default Attack.
- [History 1152](drawer-history-1152.png), [history 1024](drawer-history-1024.png): chronological history scrolls to newest; commands remain visible. Battlefield feedback borders no longer cross over the drawer.
- [Preparation](drawer-preparation.png): drawer and handle excluded, preparation dialog owns input and paints above battlefield feedback.

## Adjustments and limits

The oracle's illustrative Advance command remains the existing seven-damage command, labeled `Damage closest enemy (7)`; no advance-only command was added. Unit feedback uses z-indices 11/12, so the drawer uses 20 and blocking arena overlays use 30. Reset clears both log and outer diagnostics scroll. An early rendered fixture incorrectly expected off-turn inspection; it now verifies legal Default Attack targeting before/after close. Failed intermediate captures were replaced by passing captures.

Moved control lookups in speed-order (two), damage/log, lifecycle and world-entry tests resolve through `%BattleDebugDrawer`; activation fixtures open it first. AC2.6 had two additional geometry references to the removed log panel; those now check the action bar and retain the viewport/lifecycle assertions.

No 960-pixel support or assistive-technology screen-reader session is claimed. Accessibility evidence covers visible focus, keyboard traversal, accessible names and native input events. AC7.5's global visual-state language remains separate.
