# AC2.9 Manual Runtime Check

- Evidence recorded: 2026-08-05
- Implementation commit: `284aeac4135ddea1ddfd22f217e97ceb9d4fe0bb`
- Branch: `feat/ac2-9-generic-combos`
- Runtime viewport: 1152 x 648
- Final debugger state: 0 runtime errors, 0 script errors

## Runtime scenarios

| ID | Scenario | Result | Observed evidence |
|---|---|---|---|
| Q0 | Quick Strike initial state | PASS | Round 1, revision 0, no history entries. Tooltip reads `Combo: +3 damage if another ally damaged this target with a skill this round.` Its 268 x 75 label and 288 x 263 panel are fully inside the 1152 x 648 viewport. |
| Q1 | Non-qualifying Quick Strike hover | PASS | Target role `valid_hover`; no combo-ready target IDs; prompt `Select a target for Quick Strike`; summary `Damage: 5 total`. |
| Q2 | Non-qualifying target lock | PASS | Target role `locked`; prompt `Confirm Quick Strike`; summary remains `Damage: 5 total`. |
| Q3 | Cancel before commit | PASS | Round, revision, actor, zero-entry history, target HP, and cooldown were unchanged; target roles and presentation summaries cleared. |
| Q4 | Ally establishes qualifying history | PASS | Arena revision advanced to 1 and the sole authoritative entry recorded the ally, player side, round 1, enemy A, and 4 applied skill damage. |
| Q5 | Qualifying Quick Strike hover | PASS | Enemy A became `combo_ready`; enemy B remained `valid_preview`; combo-ready IDs contained only enemy A. |
| Q6 | Qualifying target lock | PASS | Prompt `Combo ready: +3 damage`; summary `Damage: 5 base + 3 combo = 8 total`; locked target role `combo_ready_locked`. |
| Q7 | Commit qualifying Quick Strike | PASS | Revision advanced from 1 to 2 and history from 1 to 2 entries. The new immutable log entry recorded 5 base, 3 combo, 8 requested, and 8 applied damage; enemy HP became 8. |
| N1 | Same actor supplied the prior hit | PASS | Combo did not activate; requested damage remained 5. |
| N2 | Enemy supplied the prior hit | PASS | Combo did not activate; requested damage remained 5. |
| N3 | Prior hit targeted another enemy | PASS | Combo did not activate; requested damage remained 5. |
| N4 | Prior entry applied zero damage | PASS | Combo did not activate; requested damage remained 5. The focused automated contract fixture provides the authoritative verification for this synthetic invalid-history boundary. |
| N5 | Prior hit occurred in another round | PASS | Combo did not activate; requested damage remained 5. |
| L1 | Qualifying actor removed before evaluation | PASS | The committed history entry remained authoritative after actor removal and the combo still activated for 3 bonus damage. |
| L2 | Battle teardown after victory | PASS | Outcome became victory; authoritative history remained available for the completed battle while combo-ready IDs, roles, prompt, and summary were cleared. |
| L3 | Arena reconfiguration | PASS | Replacement battle began at round 1/revision 0 with zero history entries and no stale combo presentation. |

## Contract and ownership checks

- The arena owns exactly one authoritative collection of immutable `BattleActionLogEntry` records.
- `BattleComboRules` consumes defensive history snapshots; it does not own or mutate history.
- Base damage, combo bonus damage, total requested damage, and applied damage are preserved as distinct action-log contract fields.
- Combo-ready target roles, prompts, summaries, and tooltip state are derived presentation state rather than a second history store.
- Cancellation clears presentation without committing history. Battle teardown clears combo presentation, and arena reconfiguration resets both authoritative history and presentation state.

## Genericity and traceability

| Requirement | Verification path |
|---|---|
| Generic metadata-driven evaluation | AC2.9 focused test `_test_quick_strike_and_combo_probe_have_identical_generic_results` applies the same condition to Quick Strike and a distinct Combo Probe fixture. |
| Negative condition boundaries | AC2.9 focused test `_test_same_actor_enemy_other_target_zero_and_prior_round_do_not_activate`, plus N1-N5 above. |
| Immutable damage breakdown | AC2.9 focused action-plan/log assertions, plus Q7 above. |
| Authoritative snapshot seam | AC2.9 history snapshot mutation test, plus Q4 and the ownership checks above. |
| Lifecycle cleanup | AC2.9 cancel, teardown, and reconfigure tests, plus Q3 and L2-L3 above. |
| Presentation states and summaries | AC2.9 scene/transaction assertions, plus Q0-Q2 and Q5-Q6 above. |

## Visual evidence note

Raster screenshot capture timed out in the available GodotIQ transport. The visual
check therefore used the supported live structured UI map and exact control geometry.
The final tooltip label measured 268 x 75, its panel measured 288 x 263, and both were
inside the 1152 x 648 viewport. Live UI state inspection also confirmed the exact
non-qualifying and combo-ready roles, prompts, and damage summaries listed above.
