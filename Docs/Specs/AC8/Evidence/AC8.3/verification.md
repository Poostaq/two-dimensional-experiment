# AC8.3 verification — 2026-09-19

Result: **PASS** for gold reward presentation and durable acknowledgement. Implementation: `3abd28f` (domain), `d3ab8c0` (V5 persistence), `3d1319a` (presentation/integration/restart), based on AC8.2 `8fff747`. Branch: `feat/ac8-3-gold-reward-presentation`. The subsequent evidence commit contains only documentation/evidence and a whitespace cleanup in the recovery test.

## Implemented contract

- Production victory displays an authored coin, the receipt's exact amount and Continue. Legacy item/rest/recruitment choices and direct Scout reward calls are disabled in production. Six-slot placement coverage remains in explicit legacy preview tests for future town integration.
- Settlement atomically saves gold, recovery, encounter completion, receipt and pending battle ID. Acknowledgement clears only that ID; wallet, health, formation, moves and receipt remain unchanged. Controller publication dismisses the panel only after coordinator persistence succeeds.
- Failed settlement has no reward panel or partial live award. Failed acknowledgement retains the panel and world input block. Retries reuse identical bytes. Discard/Return preserves committed pending state; a fresh process restores its panel without reconstructing the arena or awarding again.
- V5 adds exactly one field to V4's state shape. V4 retains its schema; older saves normalize empty pending. Malformed V5, injected legacy fields, unsupported future versions and downgrade of pending state reject.
- Session/battle/source checks reject stale settlement publication. Session/panel/battle identity and expected-state checks reject stale acknowledgement callbacks. Repeated Continue and results do not duplicate writes or routing.
- Ordinary/boss defeat remains terminal and pays nothing. No new campaign-completion screen or replacement completion route was added. AC8.4–AC8.8 are not accepted by this record.

## Automated gate

All **35 required process runs** pass: exit 0, explicit PASS output, no script/runtime ERROR. [Machine-readable results](gate-results.json) enumerate every runner/mode. Each `gate-*.log` records the exact command and outcome. The required set includes all five focused runners, six reward restart modes, both terminal-loss restart modes and every regression named in the approved plan.

The first complete gate found an outdated recovery fixture (34/35). It expected production Scout placement and attempted another battle before reward acknowledgement. The migrated fixture preserves health, replacement and roster assertions in an explicit preview, acknowledges before the production next-battle check, and passes **43/43**. Its final gate log replaces that initial result. Reward-selection passes **18/18** and Scout flow **56/56**.

Focused UI coverage includes 0/50/150/maximum integer amounts, keyboard activation, actual viewport mouse events, repeated pointer clicks, Escape/outside-click rejection, save blocking and intent-only visibility. The headless UI fixture explicitly sizes its viewport to 1280×720 for coordinate-based input.

Reproduce a runner from repository root with the executable recorded in every gate log:

```powershell
& 'D:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --quit-after 1800 --script res://Tests/WorldMap/test_ac8_3_reward_presentation.gd
```

Execution used Python `subprocess.run(..., capture_output=True, text=True, timeout=120)` to reliably capture this Windows GUI executable's output and exit code. PowerShell piping initially produced empty captures; those were not counted as passes.

## Transition-to-test mapping

`P` below is `Tests/WorldMap/test_ac8_3_reward_presentation.gd::_case`, run for both combat and boss. `D` is `Tests/Run/test_ac8_3_reward_acknowledgement.gd`; `C` is `Tests/WorldMap/test_world_runtime_save_coordinator.gd`; `R` is the separate-process `Tests/Run/test_ac8_3_reward_restart.gd`. All referenced tests pass in the gate.

| Approved transition | Passing proof |
|---|---|
| Settlement save succeeds → committed | P: gold/pending committed together; frozen settlement bytes |
| Committed publication → visible | P: exact 150g panel, legacy overlay absent, destinations empty |
| Settlement save fails / fails again | P: `settlement retry fails again`, gold stays 100, no panel |
| Failed settlement → successful retry | P: same bytes, one award, duplicate result adds no write |
| Failed settlement → discard/Return | P(kind, true): one Return, old gold retained, no invented reward/acknowledgement |
| Load pending → visible without arena | P plus R reader: full state equal, no writes, no arena, blocked world |
| Continue → acknowledgement saving | P: fail-injected save, Continue disabled, durable pending unchanged |
| Acknowledgement write fails | P: panel retained, exact durable state unchanged; C publication withheld |
| Acknowledgement retry starts/fails again | P and C: repeated failure retains panel and byte-identical candidate |
| Initial acknowledgement / retry succeeds | P: live-arena success cleans it once; restored no-arena retry succeeds; only pending field changes |
| Failed acknowledgement → in-world discard | P: pending retained, Continue enabled, destinations still empty |
| Failed acknowledgement → Return | P and R writer: launcher return preserves durable pending checkpoint |
| Duplicate while saving | P: no extra write; panel latch/UI tests prevent repeated submission |
| Duplicate after acknowledgement | D, P and R reader: successful no-op, no save or reopened panel |
| Unknown/stale ID | D and P: rejected without state mutation; older ID cannot clear a different pending reward |
| Old callback after replacement/disposal | P: captured real settlement callback and stale UI/ack callbacks cannot publish into replacement; Return invalidates callback generation |
| Load acknowledged → ordinary route | R acknowledged-reader for both encounter kinds: no panel, full state retained |

## Rendered and editor verification

All six restart modes also pass rendered on OpenGL at 1280×720 and 1920×1080 using `--rendering-method gl_compatibility` and `-- <mode> <kind> capture`. They use only `user://ac83-reward-restart-test.json`; normal user saves were not touched. Full logs are `rendered-*.txt`.

All twelve captured images were visually inspected:

- `{combat,boss}-victory-{1280x720,1920x1080}.png`: centered unclipped gold-bordered panel, coin, exact `Gold received: 150g`, focused Continue, no old reward choices.
- `{combat,boss}-ack-failure-{1280x720,1920x1080}.png`: autosave overlay above the retained dimmed reward panel; focused Retry, readable Return/Copy controls. It intentionally obscures the underlying coin/amount.
- `{combat,boss}-restored-{1280x720,1920x1080}.png`: identical 150g presentation over the world rather than an arena; HUD displays 250g; Continue focus is visible.

Representative captures: [combat victory](combat-victory-1280x720.png), [acknowledgement failure](combat-ack-failure-1920x1080.png), [restored boss reward](boss-restored-1280x720.png). Input blocking is established by behavioral tests, not screenshots alone.

GodotIQ Play and `verify_project_runs` returned PASS with no console errors. Live in-memory boss fixture checks confirmed failed settlement at 100g/no reward, successful retry at 250g/pending with zero valid destinations, and failed acknowledgement retaining 250g/pending/visible panel. Game was stopped after inspection.

Final [GodotIQ checks](final-godotiq-checks.json): 206 scripts and 20 scenes, zero validation errors, zero parser errors, no orphan project signals. There are 31 warnings and 5 informational findings, matching the baseline counts. Signal analysis additionally labels engine-native test signals (`pressed`, `gui_input`, etc.) as missing project definitions; these are not missing engine signals.

## Review and limitations

Independent domain, persistence and UI/controller reviews passed. Review found and fixed a stale settlement callback gap and added live-arena acknowledgement proof. Final review approved restart coverage, legacy fixture migration and absence of new completion routing; its repeated-settlement-failure coverage request was added and passed.

GodotIQ's 3D tour produced no screenshots for this 2D UI; its screenshot/input bridge also timed out. Those attempts are not counted as visual/input proof. Separate rendered production-process captures and actual viewport keyboard/pointer tests provide that evidence. The bridge's state inspections and launch/error checks worked.

Existing AC8.2 durability limits before the first successful atomic settlement remain unchanged. This is the focused AC8.3 gate, not a full-project exhaustive test claim or a resolution of the historical migrated-preview runner stall. Earlier `red-*`, baseline and intermediate logs document development failures; the final acceptance sources are `gate-*`, `gate-results.json`, rendered restart logs and this record.
