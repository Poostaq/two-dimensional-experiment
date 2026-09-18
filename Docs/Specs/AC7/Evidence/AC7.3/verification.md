# AC7.3 verification — 2026-09-18

**Verdict: PASS WITH WARNINGS.** AC7.3 is implemented and verified. No blocking failures remain. Convention findings remain at the measured baseline: 27 warnings and 6 informational findings; zero script errors.

## Implementation and scope

Implementation commit: `db6de5b`, branch `feature/ac7-3-unified-action-bar`, based on completed AC7.2 at `6625765`. Main was updated from origin and fast-forwarded to the completed AC7.2 branch before creating the task branch. Work and review were performed inline in the primary workspace.

Added an authored unified action-bar scene, an authored full skill tile, and a presentation-only controller. All zero-to-four skills, including passive and enemy-turn inspection, retain their existing identities and ordering. Attack and Swap use distinct small vector glyphs inside 44×44 controls, accessible names, tooltips, focus feedback, and one shared contextual Confirm/Cancel pair. Skills expand to use available width while keeping their 88×88 minimum; they scroll when necessary.

BattleArena still owns selection, transactions, targeting, default previews, revisions and action execution. The new UI adapters coordinate skill/default selection. Selecting a default clears the skill selection and transaction; selecting a skill clears default targeting. Passive inspection clears pending targeting without performing an action. Hover/focus detail preview respects locked skill targets and cannot replace a default preview.

The presenter retains tile instances/focus during same-roster updates. Pointer detail takes precedence over keyboard detail, keyboard detail resumes on pointer exit, and stale exits cannot clear a newer source. Availability text comes from existing rule evaluation, with live cooldown reasons in the accessible name, tooltip and readout. Unavailable skills remain inspectable; the existing rule engine prevents execution. Defaults use disabled controls, with reasons also available through the focusable bar's accessibility description.

Function-by-function diff review confirmed unchanged public combat preview/confirmation methods, rule evaluation, transaction implementation, damage/effect resolution, queue advancement, turn ordering, save behavior and revision checks. Existing rendering methods now delegate control drawing; battlefield target indicators remain in BattleArena. Preparation gains immediate presentation refresh and tooltip cleanup.

## Measured plan adjustments

- **Constrained width is 1024×648.** The planned 960×648 failed because the pre-existing formation layout requires approximately 1000 pixels (four 236-pixel slot minima plus spacing). At 1024 and the required 1152 pixels, the complete HUD and controls fit. This criterion does not reduce lane minima or claim support below the existing layout width.
- Existing full tile minimums and child-label contracts were retained. Tiles expand to fill the skill strip, preventing awkward word breaks at normal widths.
- A fixed-height detail row prevents pointer hover from moving the clicked button. The first rendered input test reproduced missed clicks caused by a dynamically appearing row; the final fixture verifies actual clicks.
- Existing tooltip fields were extracted with the component into a CanvasLayer. Its background is opaque so battlefield labels do not show through its text.
- The row schema carries a duplicated CharacterSkill for existing detailed tooltip formatting plus detached availability/selection fields. It does not expose the arena's mutable skill instance.
- Two tiny glyphs are rasterized from vector path data by the presenter; no external art/font dependency was introduced.
- The original exact node-name scope changed with scene extraction. Ten pre-existing test/capture scripts now resolve moved controls through `%BattleActionBar`. The old two confirmation-region expectations resolve the one contextual region; tooltip-handler tests address the presenter. Combat, geometry and interaction assertions were retained.
- No invisible duplicate panels, A/B selector, AC7.4 drawer or AC7.5 global state resolver were added. The approved oracle is unchanged.

## Automated evidence

Executable: `D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`, Godot **4.7.2**.

**26 distinct runners passed:** all 23 Battle test runners, plus party formation, world-to-battle entry and preparation UI. Logs are adjacent to this document. After the final live-detail refresh fix, the new AC7.3 runner and AC2.7 tooltip runner were rerun successfully; rendered QA was rerun successfully as well. The subsequent EOF whitespace cleanup passed script validation/checking.

Known negative-data tests emit deliberate validation errors also present in the 25-runner baseline. There are no final script errors or failed assertions.

The new [AC7.3 runner log](test_ac7_3_unified_action_bar.log) covers:

- Authored bar existence, four full tiles, compact dimensions and accessible names/tooltips.
- Skill → Attack → Swap → Skill transitions, passive inspection, single confirmation routing and cancellation without combat mutation.
- Hover preserving locked skill targets and default targeting.
- Valid skill confirmation committing exactly once and stale default confirmation committing nothing.
- Same-roster focus retention, zero-through-four rosters, repeated read-only rendering and pointer/focus arbitration.
- Cooldown reasons, live reason refresh, actor defeat/removal, preparation locking, completion and reused-ID reset.

The first contract test failed because the authored bar did not exist. Later failures reproduced incorrect scene initial visibility, hover-induced reflow, stale defeat/preparation details and stale live cooldown readout before their fixes. All final cases pass.

Reproduce automated checks from the repository root:

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
    output = result.stdout + result.stderr
    print(test, result.returncode)
    print(output)
    assert result.returncode == 0
    assert 'SCRIPT ERROR' not in output and 'FAILED:' not in output
'@ | python -
```

## Rendered input and visual inspection

[Rendered QA log](rendered-qa.log): **PASS**, exit zero. The fixture uses viewport mouse motion/button events and keyboard events, not emitted signals, for activation and navigation. It tests four-skill layout, keyboard details and Enter activation, skill target selection, Attack/Swap target selection, cancellation, Tab traversal/exit, zero-skill defaults, one actual confirmed attack and enemy-turn presentation. Bounds assertions cover the whole HUD, bar, visible controls and tooltip at 1152×648 and 1024×648.

```powershell
@'
import subprocess
exe = r'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
result = subprocess.run([exe, '--path', '.', '--rendering-method', 'gl_compatibility',
                         '--script', 'res://Tests/Battle/capture_ac7_3_unified_action_bar.gd'],
                        capture_output=True, text=True, timeout=60)
print(result.stdout + result.stderr)
assert result.returncode == 0
'@ | python -
```

Inspected final images:

| Capture | Observed result |
|---|---|
| [Four skills](bar-four-skills.png) | All four full names and Active/Passive labels fit; icons remain compact beside the skill strip |
| [Keyboard details](bar-keyboard-details.png) | Focus marker and opaque, bounded tooltip; existing target-preview indicators remain visible |
| [Skill target](bar-skill-target.png) | Skill selected, damage summary and one Confirm/Cancel pair |
| [Attack target](bar-attack-target.png) | Attack selected, skill selection cleared, correct enemy summary |
| [Swap target](bar-swap-target.png) | Swap selected, correct adjacent-ally summary and shared confirmation |
| [Constrained width](bar-constrained-1024.png) | Full HUD fits at 1024×648; no action control clipping |
| [Cooldown](bar-cooldown.png) | Locked label and “Ready in 2 actions.” visible via keyboard detail |
| [Zero skills](bar-zero-skills.png) | Explicit empty skill state; Attack usable and Swap disabled without an ally |
| [Enemy turn](bar-enemy-turn.png) | Current enemy identity, disabled defaults and preserved log/damage feedback |

## GodotIQ runtime checks

- Battle scene launch, `verify_project_runs`, and debug console: **PASS**, no runtime/script errors.
- `state_inspect`: current actor `player_4`, initial selection empty, default mode 0, round 1.
- `ui_map`: four full skill buttons and two compact actions in one component; no superseded panels.
- `explore(mode="tour")`: one screenshot returned and inspected. Ribbon, four lanes and unified bar fit together without overlap.
- Live clicks verified default mode **0 → 1 (Attack) → 0 (Cancel) → 2 (Swap) → 0 (Cancel)** while battle revision remained 0.
- GodotIQ's name-based tap used logical coordinates against a 1920×1080 window displaying a 1152×648 viewport, so the first taps missed. Using coordinates adjusted to the measured window/viewport scale verified the transitions. The independent rendered fixture injects viewport events directly and passed.
- Main entry `res://Scenes/world_run_start.tscn`: `verify_project_runs(scene="main")` **PASS**, no debug console errors. Runs were stopped afterward.
- Project validation: **0 errors, 27 warnings, 6 informational findings**, unchanged from baseline.
- Signal audit: **zero orphan signals**. Its “missing” list refers to built-in `pressed`, `gui_input`, `mouse_entered` and `mouse_exited` signals emitted by test fixtures, not missing project signal declarations.
- The UI audit recommends 48×48 touch controls and flags the two approved 44×44 icon controls. This implementation targets the specified mouse/keyboard interaction and retains the approved 44×44 dimensions.

## Acceptance

| AC7.3 requirement | Evidence | Result |
|---|---|---|
| Complete skill roster beside compact defaults | New runner, AC2.6, four-skill/zero-skill captures | PASS |
| Accessible names, tooltips and keyboard operation | New runner, rendered traversal/details, UI audit | PASS with documented touch-size recommendation |
| One shared selection and confirmation flow | New runner and rendered skill/Attack/Swap transitions | PASS |
| Existing preview/target/confirm/cancel behavior | AC2.7/AC2.8, AC3.4, rendered input | PASS |
| Current-turn ownership and lifecycle | Active-turn runner, new defeat/preparation/reset cases | PASS |
| Existing lanes/ribbon and normal entry | AC7.1/7.2, integration runners, tour and main launch | PASS |

AC7.3 is complete. AC7.4 and AC7.5 remain pending.
