# Scout Recruitment Reward Fix

## Problem

After a combat victory, selecting and confirming **Recruit Scout** does not open the party placement screen. The Scout therefore never joins the run roster and is absent from the next battle.

The reward catalog already marks Scout as a recruitment reward, and `BattleArena` already emits `recruitment_placement_requested` when a recruitment reward is confirmed. The defect lies in the runtime integration between that request and the existing party-placement flow.

## Desired Behavior

1. The player wins a combat encounter.
2. The player selects and confirms **Recruit Scout**.
3. The reward overlay is suspended and the existing party-management placement screen opens.
4. The player places Scout into an empty slot, or replaces an existing party member when the roster is full.
5. The updated formation is committed to durable run state.
6. The reward completes and the battle closes only after successful placement.
7. Scout is present in the player formation when the next battle opens.
8. Cancelling placement restores the pending reward without mutating the roster.

## Design

Keep recruitment ownership at the existing boundaries:

- `BattleArena` owns reward selection and suspends/resumes/completes the pending reward.
- `WorldRuntimeController` translates the recruitment request into the existing `PartyManagement` placement or replacement flow.
- `RunRoster` remains the authoritative in-memory party formation.
- The current save coordinator persists a staged formation before it becomes the live roster.

The exact boundary is: `BattleArena` confirms a recruitment reward and requests placement; `WorldRuntimeController` must open and coordinate the existing party-placement screen. No new placement logic belongs under the battle reward overlay.

### Recruitment Lifecycle

The lifecycle states are conceptual controller states; they may be represented by existing fields if the resulting transitions remain explicit and testable.

- `idle`: no recruitment reward is selected or queued.
- `reward_selected`: Scout is selected in the visible reward overlay but not yet confirmed.
- `recruitment_pending`: confirmation is accepted once, the reward overlay is suspended, and one recruit identity is queued.
- `placement_open`: exactly one party-placement screen owns that queued recruit.
- `placement_confirmed`: a valid slot choice has produced a staged roster candidate; the live roster is unchanged while persistence is attempted.
- `placement_cancelled`: the placement screen closes without a candidate or roster mutation, then transitions back to `reward_selected` with Scout still selected.
- `save_failed`: persistence of the staged candidate failed; the live roster remains unchanged, the reward remains pending, and the battle cannot complete.
- `reward_completed`: persistence succeeded, the staged roster became authoritative, and the pending battle reward completed exactly once.

Valid transitions are:

- `idle -> reward_selected -> recruitment_pending -> placement_open`
- `placement_open -> placement_cancelled -> reward_selected`
- `placement_open -> placement_confirmed -> reward_completed`
- `placement_confirmed -> save_failed -> reward_completed` when retry succeeds
- `save_failed -> placement_open` only when the failed candidate is explicitly discarded and the player remains in the run

Duplicate confirmation, duplicate placement requests, and any completion outside these transitions are no-ops.

### Transaction and Persistence Contract

Slot placement or replacement must operate on a candidate `RunRoster`, not the live `_roster`. The candidate is validated against the expected recruit identity and, for replacement, the expected current occupant identity. The save candidate is serialized from that candidate roster.

On save success:

1. Publish the candidate as the live roster and durable formation.
2. Close the party-placement screen and clear the queued recruit.
3. Complete the pending battle reward exactly once.
4. Close the battle through its existing completion signal.

On save failure:

1. Keep the live roster and durable formation unchanged.
2. Keep the same staged candidate and recruit identity for retry; never construct or append a second recruit.
3. Keep the battle open with its reward suspended and the placement screen underneath the autosave failure surface.
4. Do not emit reward completion or battle exit.
5. Disable further placement mutation while persistence is blocked.
6. A successful save retry publishes the existing candidate and resumes the success sequence without another slot click.
7. If the failed candidate is explicitly discarded while remaining in the run, discard it, refresh placement from the unchanged live roster, and return to `placement_open`.

This makes roster publication and reward completion atomic from the player's perspective.

### Cancellation Contract

- Cancellation is allowed only in `placement_open`, before a candidate save begins. The battle reward overlay is expected to be hidden at that point.
- Cancellation closes the party-placement screen, clears the queued recruit and any candidate, and restores the reward overlay with Scout still selected and confirmable.
- The player may confirm Scout again to create one new placement session.
- Any ordinary close route from the recruitment-mode party screen must use the same cancellation transition; it may not silently dismiss the screen or close the battle.
- Cancellation is ignored in `placement_confirmed`, `save_failed`, and `reward_completed`; those states are resolved through persistence retry/discard or normal completion.

## Non-goals

- Do not add automatic first-empty-slot placement.
- Do not duplicate party slot or replacement logic inside the reward overlay.
- Do not change money or item reward behavior.
- Do not redesign general party management or the save coordinator beyond the transaction boundary required here.

## Data Flow

`Recruit Scout` confirmation -> `recruitment_placement_requested` -> runtime creates Scout once from `RunCharacterCatalog` -> existing party-placement screen opens once -> player chooses a valid slot -> candidate `RunRoster` is created -> candidate formation persists -> candidate becomes the live roster -> battle completes the pending reward -> next battle receives `RunRoster.create_battle_units()` including Scout.

If recruit creation, duplicate validation, slot validation, or persistence fails, the reward must remain recoverable and must not silently complete.

## Verification

Add a focused integration regression test that exercises the real runtime boundary and proves:

- confirming Scout opens recruitment placement;
- reward confirmation emits the expected recruitment request and the runtime consumes it once;
- the placement UI opens exactly once and the pending Scout instance is not created twice;
- successful placement publishes Scout to both the live roster and serialized formation only after save success;
- stale destination occupant or recruit identity mismatches cannot replace a party member;
- save failure leaves the live roster unchanged, keeps the reward pending, and emits neither reward completion nor battle exit;
- successful retry publishes the existing candidate without duplicating Scout;
- cancelling placement leaves the roster unchanged, closes placement, and restores Scout as the selected reward so it can be retried;
- the next battle's actual player-unit input from `RunRoster.create_battle_units()` contains Scout, independent of UI labels;
- existing reward-selection and runtime tests remain green.

The regression test must fail for the reported behavior before production code changes are made.
