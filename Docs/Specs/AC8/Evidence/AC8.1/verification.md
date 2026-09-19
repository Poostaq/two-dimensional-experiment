# AC8.1 starting gold and HUD verification

Date: 2026-09-19. Engine: Godot 4.7.2 stable. Branch: `feat/ac8-1-starting-gold-and-hud`.

## Result

AC8.1 acceptance: PASS. Broader regression status: PASS WITH WARNINGS because an older preview-flow runner stalls outside the production-session path (details below). AC8.2 remains planned; this change does not add fight rewards or terminal defeat handling.

- Each supported commander starts a new run with exactly 100g. Ordinary state construction grants no allowance; a replacement run does not inherit the prior wallet.
- Gold survives dictionary copies, canonical identity, V3 encoding, movement, formation and encounter saves, preparation/recovery candidates, retry, discard and reload. Zero remains zero.
- V3 rejects absent, negative, fractional, nonnumeric, nonfinite and unsafe integer balances. V2 receives 0g at its explicit migration boundary. A progressed V2 fixture retains position, consumed encounters, swapped formation, nonempty HP, cache progress and committed preparation through V3.
- The HUD reads the durable wallet. Failed saves do not publish candidate gold; successful publication refreshes the HUD.

## Automated evidence

`automated-tests.log` records exact commands and outcomes for 23 passing headless runners. Coverage includes the three new AC8 runners, start service, both save formats, starter-health migration, repository, launcher, save coordinator, HUD, production menu, runtime scene/model, recovery, Goblin integration, recruitment, formation, cache and autosave overlay.

Red checks were observed before implementation: the wallet runner failed on absent initial/serialized gold; the V3 runner failed on missing codec; launcher/coordinator checks failed on V2 writes losing gold; HUD and runtime checks failed on absent wallet presentation. Subsequent green runs are recorded in the log.

GodotIQ project validation: 188 scripts, 19 scenes, zero errors; 27 warnings and 6 informational items, equal to the pre-change baseline. Project parser check: zero errors. Signal audit: no orphaned signals; reported missing signals are existing Godot built-in UI signals emitted by older tests. Independent implementation review found no blocking code defect.

## Rendered interaction evidence

Run `Tests/WorldMap/capture_ac8_1_gold.gd` with the command in `rendered-qa.log`. It uses the production launcher scene, keyboard events for menu buttons, a mouse event for map movement, and an isolated test save slot. It does not overwrite the player's active run.

Observed sequence: Start New Run -> 100g -> one accepted map click -> 100g -> return to menu -> Continue -> 100g -> Continue a saved 375g fixture -> 375g -> Continue a saved 0g fixture -> 0g -> confirmed replacement -> 100g. The rendered runner exits 0 with no script/runtime errors.

Inspected screenshots:

- `new-run-1152.png`: 100g appears after the move counter; cache, party controls and right-aligned boss information remain readable.
- `continued-375g-1152.png`: 375g is restored after movement; no top-bar overlap or clipping.
- `continued-0g-1152.png`: zero displays explicitly as 0g; surrounding layout remains stable.
- `continued-0g-1920.png`: the same layout scales to 1920x1080 with readable gold and separated controls.

GodotIQ startup verification passed. Its embedded runtime input/screenshot requests intermittently stalled. The tour captured the main menu rather than the HUD, so it is not used as wallet visual evidence. A tour attempt also reported a busy-parent add-child error; a fresh startup verification was run separately. The successful independent rendered input runner supplies the scoped interaction and visual evidence.

## Existing preview-runner limitation

`Tests/WorldMap/test_world_runtime_migrated_flows.gd` stalls after accessing a missing party child at lines 72-73. The same failure was reproduced after temporarily restoring the exact pre-change runtime-controller source; see `pre-existing-preview-failure.log`. Its fixture uses the preview world without a durable production session, and its battle completion path does not leave party management available. The AC8.1 controller was restored and the production-session integration and recovery suites passed. This unrelated runner was not modified and is not counted among the 23 passes.

## Implementation adjustments

- Shared envelope validation lives in `world_run_save_envelope.gd`, reused by V2 and V3 to retain canonical-plan checks and starter-health migration without duplication.
- `WorldSaveStore` is unchanged. Production reads are validated by `WorldSingleSlotRepository`; the store's atomic byte writer is codec-independent. The plan's assumption that atomic store validation needed V3 was unnecessary.
- The HUD's existing status labels now share an authored HBoxContainer with gold and an expanding spacer, preserving readable spacing as balances change.
- The task branch includes the previously committed Goblin/AC7.6 work as its baseline (`7052efa`). Unrelated uncommitted work was stashed before branching and restored after the implementation commit.

The implementation commit is identified by the repository history entry `feat(ac8.1): persist starting gold and show world wallet`; this evidence is committed with that implementation.
