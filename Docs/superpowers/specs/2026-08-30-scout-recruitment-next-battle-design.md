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
- The current save coordinator persists the formation after successful roster mutation.

The implementation will repair the smallest broken runtime boundary found by an integration-level reproduction. It will not add automatic placement, duplicate slot selection inside the reward overlay, or change money/item reward behavior.

## Data Flow

`Recruit Scout` confirmation -> `recruitment_placement_requested` -> runtime creates Scout from `RunCharacterCatalog` -> party placement screen opens -> player chooses a slot -> `RunRoster` mutates -> authoritative run state commits -> battle completes the pending reward -> next battle receives `RunRoster.create_battle_units()` including Scout.

If recruit creation, duplicate validation, slot validation, or persistence fails, the reward must remain recoverable and must not silently complete.

## Verification

Add a focused integration regression test that exercises the real runtime boundary and proves:

- confirming Scout opens recruitment placement;
- successful placement adds Scout to the roster and serialized formation;
- the next battle is configured with Scout as a player unit;
- cancelling placement leaves the roster unchanged and restores reward selection;
- existing reward-selection and runtime tests remain green.

The regression test must fail for the reported behavior before production code changes are made.
