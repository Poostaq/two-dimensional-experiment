# AC3.3 Party Management Design

**Status:** Approved

**Acceptance criterion:** AC3.3 — Player can freely rearrange the active party before and after fights through a party-management interface.

## Goal

Add a reusable party-management interface that lets the player inspect characters and arrange the run roster across six semantic formation slots. Formation changes persist immediately and determine exact player positions in the next battle. Recruitment below capacity also uses the interface to let the player choose the new character's initial empty slot.

## Scope

AC3.3 includes:

- A persistent `Manage Party` button on the world map while no encounter, battle, or party-management overlay is active.
- A dedicated full-screen party-management scene layered above the preserved map.
- Six authoritative formation slots that may be occupied or empty.
- Dragging an occupied character onto another occupied slot to swap them.
- Dragging an occupied character onto an empty slot to move them.
- Immediate persistence after each valid drop; there is no Apply or rollback action in normal mode.
- Click-to-inspect behavior with selected-character stats and skills below the formation.
- Green numeric HP bars along the bottom edge of occupied character cards.
- Recruitment placement mode for choosing an empty slot before a recruitment reward is committed.
- Cancellation from recruitment placement back to unchanged reward choices.
- Automated, integration, runtime, and visual evidence that exact formation slots reach the next battle.

AC3.3 excludes:

- Full-roster dismissal or replacement; AC3.2 remains unchecked and will later use a separate replacement scene based on this interface.
- Battle-time rearrangement and the default adjacent-swap action owned by AC3.7.
- Equipment editing, progression editing, recovery-rule changes, save persistence, and meta-progression.
- Dragging a pending recruit onto an occupied slot.

## Architecture

Convert `RunRoster` from a compact ordered character array into the authoritative fixed six-slot formation. Each slot contains one `RunCharacter` or is empty. Membership, duplicate checks, capacity, formation placement, and fresh battle-state conversion remain in this focused run-domain object.

`MapController` continues to own the current run roster and coordinates overlays. It opens normal party management from the map, supplies defensive six-slot snapshots, applies requested moves through `RunRoster`, and refreshes the scene from authoritative state. It also coordinates recruitment placement without allowing `BattleArena` or the party scene to mutate run state directly.

The new party-management scene owns presentation and transient interaction only. It renders a supplied snapshot, reports typed move or placement requests, displays valid drop targets, and emits close or cancel intent. It does not retain authoritative character objects or assume that a request succeeded.

`BattleArena` continues to own reward selection. For recruitment below capacity, confirmation begins a pending placement transaction instead of immediately emitting the completed reward-and-exit sequence. Cancelling placement restores the same reward choices and selection state without roster mutation. Successful placement completes the reward once and follows normal battle cleanup.

## RunRoster contract

`RunRoster` stores exactly six entries in `_slots: Array[RunCharacter]`. The array always has length `MAX_ROSTER_SIZE`; an empty position is represented by `null`. No sentinel `RunCharacter` or compacted index is permitted.

A fresh run preserves AC3.1 starter order by placing `player_0`, `player_1`, and `player_2` in slots 0, 1, and 2 respectively; slots 3, 4, and 5 are `null`.

The AC3.3 public API is:

```gdscript
enum AddResult { ADDED, INVALID, DUPLICATE, FULL, INVALID_SLOT, OCCUPIED }
enum MoveResult { MOVED, SWAPPED, INVALID_SLOT, EMPTY_SOURCE, STALE_SOURCE, SAME_SLOT }

func size() -> int
func is_full() -> bool
func has_character(character_id: StringName) -> bool
func can_add(character_id: StringName) -> bool
func can_add_at(character_id: StringName, slot_index: int) -> bool
func try_add_at(character: RunCharacter, slot_index: int) -> AddResult
func try_move(source_slot: int, destination_slot: int, expected_character_id: StringName) -> MoveResult
func get_character_at(slot_index: int) -> RunCharacter
func get_slot_snapshot() -> Array[RunCharacter]
func get_characters() -> Array[RunCharacter]
func create_battle_units() -> Array[BattleUnitState]
```

`get_character_at()` returns `null` for an invalid or empty slot. `get_slot_snapshot()` returns a six-entry defensive array including `null` entries. `get_characters()` remains a compatibility API and returns only occupied characters in ascending slot order. `create_battle_units()` keeps its existing signature but assigns each unit the source slot index rather than a compacted array index.

The compact `try_add(character)` API is removed. Every production and test caller migrates to `try_add_at(character, slot_index)`, making placement explicit. The existing AC3.1 integration handler that immediately calls `try_add()` is replaced by the pending-placement transaction. AC3.1 tests that fill a roster directly use explicit empty indices. `MapController.get_run_roster_snapshot()` remains as a compatibility occupied-character snapshot, while the party interface receives a new `get_run_formation_snapshot()` six-slot snapshot.

The resulting contracts are:

- A defensive six-slot formation snapshot that preserves empty positions.
- An occupied-character snapshot for membership-oriented consumers.
- Size, full-state, and character-ID membership queries that count only occupied entries.
- Duplicate and invalid-character rejection across all occupied slots.
- Addition to an explicitly requested empty slot.
- Atomic movement between slots: occupied-to-occupied swaps and occupied-to-empty moves.
- Same-slot, invalid-index, empty-source, stale-character-ID, occupied-placement, duplicate, and full-roster requests fail without mutation.
- Fresh `BattleUnitState` creation with each character's exact semantic slot index; empty slots produce no battle unit.

Existing AC3.1 behavior changes only where necessary: a normal eligible recruit is no longer automatically appended to the lowest available position. Catalog lookup, duplicate protection, capacity six, fresh battle-state creation, and run reset remain intact.

## Normal party-management mode

The world map exposes a persistent `Manage Party` button. It is usable only when no encounter, battle, or party-management overlay is active. Activating it opens the full-screen scene while preserving map and run state underneath.

The formation contains two clearly labeled columns: three back-row slots and three front-row slots nearest the enemy. Each occupied card shows identity, relevant summary information, and a green HP bar with numeric current and maximum HP along its bottom edge. Empty slots remain visible as drop targets.

For this slice, run characters do not yet own persistent between-battle damage; AC3.8 owns recovery behavior. Party management therefore renders each card's HP as `max_hp / max_hp` from `RunCharacter.max_hp`. It must not reuse stale `BattleUnitState.current_hp`. The details panel shows the authoritative fields available on `RunCharacter`: display name, maximum HP, base speed, and its zero-to-four character-specific skills. Power, defense, race, class, equipment, and progression fields are not fabricated; later criteria may extend the panel when those fields become authoritative.

Clicking an occupied card selects it and reveals a details panel below the formation with identity, core stats, and up to four inspectable character-specific skills. With no selection, the details panel is completely hidden. Empty slots cannot be selected.

Dragging begins only from an occupied card. A valid target receives clear feedback:

- Occupied target: swap the two slot occupants atomically.
- Empty target: move the source occupant and leave the source empty.

A valid drop requests the authoritative operation, refreshes from a new roster snapshot, and keeps the moved character selected in its destination. Drops onto the same slot, outside the formation, from an empty slot, or against stale state do nothing and restore presentation from authoritative state.

`Return to Map` clears selected-character, drag, hover, and drop-target state before closing. Reopening always starts with no selected character and a hidden details panel. Valid formation changes remain persisted because they were applied immediately.

## Recruitment placement mode

When a recruitment reward is selected below capacity, confirming it opens the party-management interface in `Place Recruit` mode. The new character appears as a pending draggable card outside the six slots. Existing roster members remain visible but cannot be rearranged in this mode.

Only empty formation slots are valid targets. Until a valid drop succeeds:

- The pending character is not part of the run roster.
- The reward is not latched as completed.
- The battle does not exit.
- No existing slot occupant changes.

A valid drop asks `MapController` to add the resolved fresh recruit to that exact empty slot. On success, the transaction latches once, battle cleanup runs, and the player returns to the map. The next battle places the recruit in the chosen semantic slot.

`Cancel` clears pending placement and returns to the unchanged battle reward interface with its recruitment option still selectable. Invalid, outside, occupied-slot, repeated, stale, duplicate, or capacity-invalid placement attempts leave both roster and reward state unchanged. Closing, scene teardown, battle teardown, or run reset cannot preserve a pending recruit.

## Concrete scene and transaction interfaces

`PartyManagement` exposes two configuration methods and four typed intent signals:

```gdscript
signal move_requested(source_slot: int, destination_slot: int, expected_character_id: StringName)
signal placement_requested(destination_slot: int, expected_character_id: StringName)
signal close_requested
signal placement_cancelled

func configure_normal(slots: Array[RunCharacter]) -> void
func configure_placement(slots: Array[RunCharacter], pending_recruit: RunCharacter) -> void
func refresh_slots(slots: Array[RunCharacter]) -> void
```

`BattleArena` changes recruitment confirmation at one explicit seam:

```gdscript
signal recruitment_placement_requested(option: BattleRewardOption)

func restore_pending_recruitment(option: BattleRewardOption) -> void
func complete_pending_recruitment(option: BattleRewardOption) -> void
```

When `confirm_reward_selection()` receives a selected recruitment option, it emits `recruitment_placement_requested` and hides or suspends the reward overlay without setting `_reward_confirmation_latched`, emitting `reward_confirmed`, emitting `exit_requested`, or clearing the selected option. Non-recruitment rewards retain the current completion path.

`MapController` is the sole owner of the pending recruit across the placement transaction through `_pending_recruitment_option: BattleRewardOption` and `_pending_recruit: RunCharacter`. On `recruitment_placement_requested`, it rejects a second transaction, resolves a fresh catalog character, stores both fields, and opens `PartyManagement.configure_placement()`. It owns all placement revalidation and roster mutation.

On `placement_cancelled`, `MapController` closes the party scene, clears both pending fields, and calls `BattleArena.restore_pending_recruitment(option)`, which restores the unchanged reward overlay and selected option. On a successful `placement_requested`, `MapController` calls `RunRoster.try_add_at()`, closes and clears placement state, then calls `BattleArena.complete_pending_recruitment(option)`. That method revalidates the exact selected option, latches once, emits the existing `reward_confirmed` signal for compatibility, and emits the existing exit request in its established order. A rejected placement refreshes the party scene and leaves the transaction open.

`exit_active_battle()`, `set_run_id()`, party-scene teardown, and unexpected battle-tree exit all call one idempotent `MapController._clear_pending_recruitment()` boundary. Unexpected teardown clears state without applying a character. Only explicit Cancel restores reward UI because there may be no live arena during other teardown paths.

## AC3.2 reuse boundary

AC3.2 will be implemented after AC3.3 as a separate full-roster replacement scene based on the approved party-management visual and interaction language. It may reuse character cards, HP bars, selection details, slot presentation, and drag/drop helpers. AC3.3 does not dismiss or replace an occupied member and does not mark AC3.2 complete.

## Data flow

### Normal rearrangement

1. The player activates `Manage Party` on an unobstructed map.
2. `MapController` opens the scene with a defensive six-slot snapshot.
3. A click selects an occupied character and reveals details.
4. A drag/drop emits source slot, destination slot, and source character ID.
5. `MapController` asks `RunRoster` to apply the atomic move.
6. On success or rejection, the scene refreshes from a new authoritative snapshot.
7. Closing clears transient scene state; the next battle converts occupied roster slots using their exact indices.

### Recruitment placement

1. The player wins, selects a valid recruitment reward, and confirms it.
2. `BattleArena` begins pending recruitment instead of completing and exiting.
3. `MapController` resolves the reward to a fresh character and opens placement mode.
4. The player either cancels back to rewards or drags the pending card to an empty slot.
5. A valid placement is revalidated and applied atomically by `RunRoster`.
6. Only successful addition completes the reward and exits the battle.

## Defensive behavior

- Scene snapshots and character/skill arrays are defensive; UI mutation cannot alter the roster.
- Every move and placement is revalidated at mutation time using slot indices and stable character identity.
- A rejected operation never changes membership, slot occupancy, order, reward completion, or battle lifecycle.
- Normal mode cannot add or remove roster membership.
- Placement mode cannot move existing members or displace an occupied slot.
- Duplicate-character prevention applies to current roster membership.
- Run reset rebuilds the starter formation and clears every open or pending party transaction.
- Only one party-management scene and one pending recruitment transaction may exist at a time.

## Verification strategy

### Domain automation

Focused `RunRoster` tests verify:

- Exactly six semantic slots with correct starter placement and empty positions.
- Occupied-to-occupied swap and occupied-to-empty move behavior.
- Exact battle conversion slot indices with gaps preserved.
- Explicit addition to a chosen empty slot.
- Size/full invariants and duplicate prevention.
- Rejection without mutation for same-slot, invalid-index, empty-source, stale-ID, occupied-placement, duplicate, and full requests.
- Defensive formation, character, battle-state, and skill snapshots.

### Scene automation

Focused real-scene tests verify:

- Six visible slot targets with correct front/back labels and occupied/empty rendering.
- Green numeric HP bars at the bottom of occupied cards.
- Hidden details by default and after close/reopen.
- Click selection, selected presentation, core stats, and skill population.
- Drag start restrictions, valid-target feedback, swap/move requests, failed-drop cleanup, and post-success refresh.
- Placement-mode pending card, empty-only targets, locked existing members, and Cancel behavior.

The focused runner paths are fixed as:

```text
Tests/Run/test_ac3_3_party_formation.gd
Tests/UI/test_ac3_3_party_management.gd
Tests/Map/test_ac3_3_party_management_integration.gd
```

### Integration and regression automation

Map/battle integration tests verify:

- Persistent map-button availability and overlay gating.
- Rearrangement before a fight reaches exact player battle slots.
- Rearrangement after returning from a fight reaches the following battle.
- Selecting a recruit does not mutate the roster or close the battle.
- Cancelling placement restores unchanged rewards and roster.
- Successful placement adds exactly once to the chosen empty slot and completes cleanup.
- Repeated, stale, invalid, occupied, duplicate, and outside drops cannot add or duplicate a recruit.
- Existing AC3.1 catalog, capacity, duplicate filtering, run reset, reward alternatives, and fresh battle-state guarantees remain passing.

### Runtime and visual evidence

Use real pointer input to open the persistent button, click an occupied card, inspect stats and skills, drag between occupied slots, drag into an empty slot, close, and reopen. Verify no selection and no details on reopen, while formation changes persist. Enter battles before and after rearrangement and inspect exact semantic player slots.

Win a supported battle, select recruitment, cancel placement once, then reopen placement and drop the recruit into a chosen empty slot. Verify the roster changes only after the valid drop and that the next fight uses the chosen slot. Run a GodotIQ visual tour after scene work to confirm readable cards, bottom HP bars, details-panel fit, front/back clarity, drag feedback, and no overlap at the target viewport.

## Acceptance traceability

| Requirement | Classification | Verification path | Completion gate |
|---|---|---|---|
| Persistent access before and after fights | Integration/runtime | Map integration runner plus real pointer check | Button is correctly gated and both openings succeed |
| Free rearrangement | Logic/integration | Roster move tests plus scene drag/drop tests | Swaps and moves persist immediately |
| Exact next-battle lineup | Integration/runtime | Map-to-battle slot assertions plus live state inspection | Occupied semantic slots match exactly |
| Character inspection | Visual/runtime | Scene assertions plus visual tour | Details are hidden until click and show stats/skills afterward |
| Recruitment slot choice | Integration/runtime | Pending-placement tests plus live reward flow | No early mutation; chosen empty slot is used |
| Cancel recruitment placement | Integration/runtime | Reward restoration assertions plus pointer check | Roster unchanged and reward choices restored |
| Defensive behavior | Logic/integration | Invalid/stale/repeated operation matrix | Every rejected path is mutation-free |

## Authority and completion evidence

No separate roadmap or migration-matrix artifact exists in this repository. The authority chain for this slice is therefore explicit and limited to:

1. `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` for canonical AC3.1/AC3.3 requirements and status.
2. This approved AC3.3 design for behavior and boundaries.
3. `Docs/superpowers/plans/2026-08-13-ac3-3-party-management.md` for executable migration steps and file ownership.
4. Focused tests and current GodotIQ/runtime outputs for verification.
5. Evidence files tied to one tested implementation commit.

Completion evidence is written exactly to:

```text
Docs/Specs/AC3/Evidence/AC3.3/2026-08-13/automated-test.log
Docs/Specs/AC3/Evidence/AC3.3/2026-08-13/manual-runtime-check.md
Docs/Specs/AC3/Evidence/AC3.3/2026-08-13/implementation-link.txt
Docs/Specs/AC3/Evidence/AC3.1/2026-08-13/ac3-3-placement-amendment.md
```

The automated log records focused runner commands and PASS signatures, full-corpus results, GodotIQ validation/error/signal results, and the runtime gate. The manual record uses binary PASS/FAIL/BLOCKED entries for map-button gating, hidden initial details, click inspection, HP presentation, occupied swap, empty-slot move, close/reopen selection cleanup, pre/post-fight persistence, recruitment cancellation, chosen-slot recruitment, and runtime health. The implementation link contains the full tested implementation commit SHA; all three files must name that same commit.

Only after every gate passes may implementation change AC3.3 from `[ ]` to `[x]` and replace its manual-only verification row in `GAME_DESIGN_SPEC_MVP.md` with exactly:

```markdown
| `AC3.3` | Automated and manual runtime check | Run `Tests/Run/test_ac3_3_party_formation.gd`, `Tests/UI/test_ac3_3_party_management.gd`, and `Tests/Map/test_ac3_3_party_management_integration.gd` to verify fixed six-slot formation storage, exact battle slot conversion, immediate drag-to-swap and drag-to-empty movement, defensive rejection, map-button gating, click inspection, selection cleanup, and cancellable chosen-slot recruitment. Then use the persistent Manage Party button before and after fights, inspect a character, rearrange occupied and empty slots with real pointer input, reopen with no selection, and confirm the next battle uses the exact formation. Finally cancel one recruitment placement without mutation, place the recruit into a chosen empty slot, and confirm the following battle uses that slot. |
```

AC3.1 remains checked, but its verification row is updated to include the AC3.3 integration runner's pending-placement, cancellation, and chosen-slot cases. The dated `ac3-3-placement-amendment.md` records that the original AC3.1 implementation evidence proved automatic slot population before AC3.3 and that current regression evidence supersedes only that placement mechanism; historical logs are not overwritten. AC3.2 remains unchecked.

AC3.3 is complete only when focused domain, scene, and integration tests pass; the full test corpus passes; GodotIQ project validation, parser/error, and signal checks pass; runtime behavior and visual layout are recorded; AC3.1 documentation reflects explicit recruitment placement; the canonical AC3.3 checkbox and row are updated only after success; and all matching evidence artifacts identify the same tested implementation commit. Any missing capability or FAIL/BLOCKED item keeps AC3.3 unchecked.
