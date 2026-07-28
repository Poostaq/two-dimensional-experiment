# AC2.3 Damage, Defeat, and Battle Log Design

| Field | Value |
|---|---|
| Project | Two-Dimension Exploration |
| Source Spec | `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` |
| Acceptance Criterion | AC2.3 — Unit takes damage; at 0 HP, removed from battle |
| Owner | Project Lead |
| Prepared by | Codex |
| Date | 2026-07-28 |
| Status | Approved in design review; pending written-spec review |

---

## 1. Goal

Extend the deterministic AC2.2 battle loop with a complete damage-and-defeat slice. The current unit uses a temporary debug action to damage the closest active opponent, defeated units leave active battle participation immediately, and a scrollable battle log makes each resolved action inspectable.

## 2. Scope

AC2.3 includes:

- `20` maximum and starting HP for every debug unit.
- A fixed `7`-damage debug action performed by the current unit.
- Deterministic closest-active-enemy targeting based on semantic formation positions.
- HP clamping at zero.
- Immediate removal of defeated units from targeting and turn queues.
- Persistent defeated-slot presentation showing `Defeated — HP 0/20`.
- One typed battle-log entry, treated as immutable after construction, per accepted damage action.
- A full-width scrollable battle log below both formations.
- Automatic scrolling to the newest entry.
- Brief attacker/receiver highlights and negative damage text when damage resolves.
- Hover inspection that highlights the historical attacker green, receiver red, and restores that entry's negative damage text.
- Automated domain and arena-integration tests, regression tests, and manual runtime verification.
- Updated MVP design, verification, extension, and evidence documentation.

AC2.3 excludes:

- Player-selected actions, targets, skills, cooldowns, conditions, swaps, and combos.
- Variable damage, attack, defense, critical hits, healing, status effects, or randomness.
- Victory, loss, battle completion, rewards, recovery after battle, and roster integration.
- Animation, audio, production combat presentation, and final combat controls.

Victory and loss remain AC2.4. When no active opponent exists, AC2.3 exposes a safe inactive action state without announcing a result.

## 3. Current Repository Baseline

AC2.3 starts from the completed AC2.2 implementation:

- `res://Scripts/Battle/battle_unit_state.gd` owns scene-independent unit identity, side, semantic slot, and speed.
- `res://Scripts/Battle/battle_turn_queue.gd` validates units and creates a deterministic descending-speed queue.
- `res://Scripts/Battle/battle_arena.gd` owns twelve debug fixtures, the active queue, current index, round number, and arena UI synchronization.
- `res://Scenes/battle_arena.tscn` owns twelve stable slots, unit/speed labels, turn status, current-unit highlighting, `Advance Turn (Debug)`, and the debug exit.
- `res://Tests/Battle/test_ac2_2_speed_order.gd` verifies the queue and arena turn loop.

Every current debug unit has identity, display name, side, slot, and speed. No unit currently has HP, damage behavior, targeting behavior, defeat state, damage presentation, or battle history.

## 4. Approved Architecture

Combat rules remain separate from scene presentation:

- `BattleUnitState` gains HP and an active-state query.
- `BattleTargetSelector` is a pure deterministic closest-opponent service.
- `BattleDamageResolver` is a focused damage application service that returns a typed `BattleDamageResult`.
- `BattleLogEntry` is a value treated as immutable after construction and describes one resolved damage event.
- `BattleArena` coordinates the current attacker, target selection, damage resolution, log storage, queue rebuilding, turn advancement, and UI state.
- `battle_arena.tscn` owns HP labels, damage-feedback labels, the scrollable log, hover controls, and the renamed damage button.

These boundaries provide AC2.4 with a clean no-active-opponents seam without implementing battle results early. They also avoid building the generalized skill/effect framework reserved for AC2.6 and AC2.7.

## 5. Unit Health Contract

`BattleUnitState` retains all AC2.2 fields and gains:

```gdscript
var max_hp: int
var current_hp: int

func is_active() -> bool
```

The constructor gains a maximum-HP argument. It initializes `max_hp` and `current_hp` to the same positive value. All twelve debug fixtures pass `20`.

`is_active()` returns `current_hp > 0`. A unit at zero HP remains a valid state object with stable identity and slot but no longer participates in targeting or turn queues.

Invalid maximum HP is a programmer/configuration error. Queue construction and combat configuration must reject non-positive maximum HP safely and expose the arena's no-active-unit state rather than operating on invalid health.

## 6. Deterministic Targeting

`Scripts/Battle/battle_target_selector.gd` defines:

```gdscript
class_name BattleTargetSelector
extends RefCounted

static func find_closest_enemy(
	attacker: BattleUnitState,
	units: Array[BattleUnitState]
) -> BattleUnitState
```

The selector considers only valid, active units on the opposing side. It never mutates the input collection.

Semantic formation rows are derived as:

```gdscript
row = slot_index % 3
```

Slots `0–2` are the front column and slots `3–5` are the back column. Candidates sort by this total key:

```text
(absolute row distance from attacker, target column priority, target slot index)
```

Front-column priority is `0`; back-column priority is `1`. Therefore:

1. Same-row targets precede targets in adjacent rows.
2. At equal row distance, a front-column target precedes a back-column target.
3. Lowest semantic slot index breaks any remaining tie.

Screen coordinates do not affect targeting, so mirrored player/enemy presentation produces identical deterministic decisions.

If the attacker is invalid or defeated, the collection is invalid, or no active opponent exists, the selector returns `null` and the arena performs no action.

## 7. Damage Resolution

`Scripts/Battle/battle_damage_resolver.gd` defines:

```gdscript
class_name BattleDamageResolver
extends RefCounted

const DEBUG_DAMAGE := 7

static func apply_damage(
	attacker: BattleUnitState,
	receiver: BattleUnitState,
	amount: int
) -> BattleDamageResult
```

`Scripts/Battle/battle_damage_result.gd` defines `BattleDamageResult`, which records:

```gdscript
var attacker_id: StringName
var receiver_id: StringName
var requested_damage: int
var applied_damage: int
var receiver_hp_after: int
var caused_defeat: bool
```

Accepted damage is:

```text
applied_damage = min(amount, receiver.current_hp)
receiver.current_hp = max(0, receiver.current_hp - amount)
```

Thus a unit at `6 HP` hit by the fixed action records `applied_damage = 6`, displays `-6`, and finishes at zero rather than recording excess damage.

The resolver rejects non-positive damage, invalid participants, a defeated attacker, a defeated receiver, and same-side participants. Invalid resolution returns `null` and performs no mutation.

## 8. Battle Log Contract

`Scripts/Battle/battle_log_entry.gd` defines a value created from a successful damage result and never mutated after construction:

```gdscript
class_name BattleLogEntry
extends RefCounted

var sequence_number: int
var round_number: int
var attacker_id: StringName
var receiver_id: StringName
var applied_damage: int
var receiver_hp_after: int
var caused_defeat: bool
```

The arena appends exactly one entry per accepted debug action. Entries use stable unit IDs rather than scene-node references, so historical hover remains valid after queue rebuilding and defeat.

The concise rendered form is:

```text
R1 · Player Back 2 dealt 7 damage to Enemy Front 2 · 13/20 HP
```

A defeating entry appends:

```text
· Defeated
```

The log retains the full battle history. It is cleared when a new arena unit configuration initializes a new battle, not when a round wraps.

## 9. Action Transaction

The existing `Advance Turn (Debug)` action is replaced by:

```text
Damage Closest Enemy (Debug)
```

One accepted press performs one complete transaction:

1. Read the current active unit as attacker.
2. Find the closest active opponent.
3. Apply fixed damage `7`.
4. Append one battle-log entry.
5. Refresh receiver HP and defeated presentation.
6. Briefly highlight the attacker green and receiver red.
7. Briefly show the negative applied amount over the receiver.
8. If the receiver was defeated, rebuild the queue without inactive units.
9. Advance exactly once to the next active unit.
10. Refresh normal current-unit and button state after transient feedback ends.

The arena blocks repeated activation until the transaction and immediate UI update finish. One accepted pointer click cannot create duplicate damage, log, or turn changes.

If no active opponent exists, the damage button is disabled. Direct action calls are a safe no-op with no HP mutation, log entry, queue change, turn advancement, round increment, or diagnostic error.

## 10. Queue and Round Integration

`BattleTurnQueue.build()` excludes units for which `is_active()` is false. Its AC2.2 ordering key remains unchanged for active units:

```text
(-speed, side_priority, slot_index)
```

When damage defeats a receiver, the arena rebuilds the queue immediately. It then advances from the attacker to the next valid active unit without skipping or repeating an actor. A defeated unit that had not yet acted in the current round is absent from the remainder of that round.

Round number increments only when action resolution advances past the last remaining active entry. Defeat itself does not increment the round.

The implementation plan must specify focused cases for defeating a unit before its turn, defeating the queue tail, and preserving the correct successor when a removed unit appears before or after the attacker in AC2.2 order.

## 11. Battle UI

Each occupied slot shows:

- Unit display name.
- Speed.
- `HP current/max`.
- A small damage-feedback label positioned over the character area.

At defeat, the slot remains visible and reads:

```text
Defeated — HP 0/20
```

The slot remains available for historical inspection but is not targetable and cannot become current.

The arena uses these highlight states:

| State | Color | Meaning |
|---|---|---|
| Normal current turn | Gold | Unit whose action is next |
| Damage attacker | Green | Unit that caused the displayed damage event |
| Damage receiver | Red | Unit that received the displayed damage event |
| Neutral | Existing neutral color | No active emphasis |

Transient damage feedback briefly overrides the normal gold highlight. After it ends, the arena restores the current-unit highlight unless a log entry is being hovered.

## 12. Scrollable Bottom Log and Hover

A bounded-height `ScrollContainer` spans the available width below both formations. Its vertical history:

- Appends entries chronologically.
- Automatically scrolls to the newest entry after append.
- Remains readable without compressing either six-slot formation.
- Retains older entries for inspection.

Each rendered log entry is an interactive `Control`. On hover:

1. Resolve its attacker and receiver by stable unit ID.
2. Temporarily clear the normal current-unit highlight.
3. Highlight the attacker green.
4. Highlight the receiver red.
5. Show `-<applied_damage>` over the receiver.

On hover exit:

1. Clear the historical damage text.
2. Clear hover highlights.
3. Restore any still-running transient feedback; otherwise restore the normal gold current-unit highlight.

Hover is presentation-only. It cannot change HP, targeting, queue order, current unit, round, log contents, or scroll position.

## 13. Error and State Handling

- HP never exceeds `max_hp` or falls below zero.
- A successful debug action creates exactly one mutation, log entry, and turn advance.
- Invalid damage requests and missing targets are no-ops.
- Defeated units remain resolvable by ID for historical log inspection.
- Reconfiguring units resets round, queue, battle log, transient feedback, and hover state.
- Empty or invalid unit configuration shows `No active units`, disables the action, and highlights no slot.
- A battle with active units on only one side keeps those units visible but disables damage because no active opponent exists.
- Exiting a battle does not mutate map/run state.
- Combat and Boss arenas use the same AC2.3 contract.

## 14. Automated Verification

Create:

```text
res://Tests/Battle/test_ac2_3_damage_defeat_log.gd
```

The focused contract must verify at least:

1. All twelve debug units initialize at `20/20 HP`.
2. Fixed damage reduces `20` to `13`.
3. Damage clamps at zero and records only the applied amount.
4. Same-row active enemies are selected first.
5. Front-column targets break equal-row-distance ties.
6. Lowest slot index provides the final deterministic tie-break.
7. Defeated enemies are ignored by targeting.
8. A defeated receiver remains visible as `Defeated — HP 0/20`.
9. A defeated receiver leaves the turn queue immediately.
10. Defeating a not-yet-acted unit preserves the correct next actor.
11. One debug-button activation creates one damage result and one turn advance.
12. One successful action appends one correctly populated log entry.
13. A defeating entry is marked as defeated.
14. No active opponent disables the button and makes direct action a no-op.
15. Resolution feedback shows green attacker, red receiver, and the correct negative applied amount.
16. Hover reproduces the entry-specific highlights and damage amount.
17. Hover exit restores the normal current-unit presentation.
18. Reconfiguration clears log, hover, transient feedback, and restores Round 1.

The implementation plan will define the exact PASS signature and runner behavior. Existing AC2.1 and AC2.2 tests remain independent regression gates.

GodotIQ verification must include:

- Per-script validation and parser checks after every code change.
- Scene validation after scene changes.
- Project validation and parser checks after the multi-file change.
- Orphan and missing signal checks.
- Runtime startup and debug-console inspection.
- Real pointer input for the damage button and log-hover path.

## 15. Manual Runtime Verification

1. Enter a Combat battle and confirm twelve units show names, speed, and `HP 20/20`.
2. Confirm the current unit is gold and the damage button is enabled.
3. Press `Damage Closest Enemy (Debug)` once.
4. Confirm the closest semantic target loses exactly `7 HP`, attacker flashes green, receiver flashes red, and `-7` briefly appears.
5. Confirm one log entry appears, the log scrolls to it, and the turn advances once.
6. Hover the entry and confirm its attacker is green, receiver is red, and `-7` reappears.
7. Leave the entry and confirm normal current-turn presentation returns.
8. Continue until one unit receives three hits; confirm the final applied amount is `6`, `-6` appears, the entry says `Defeated`, and the slot reads `Defeated — HP 0/20`.
9. Confirm the defeated unit never acts and cannot be targeted again.
10. Confirm historical entries for the defeated unit remain hoverable.
11. Defeat every unit on one side; confirm damage becomes disabled without a victory/loss announcement.
12. Exit through the debug control and confirm map state is preserved.
13. Enter a Boss battle and confirm the same initialization and damage behavior.

## 16. Documentation Updates

Implementation completion updates:

- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
  - Expand the combat-system description with HP, deterministic closest-enemy debug damage, active-participation removal, battle history, transient damage feedback, and hover inspection.
  - Expand AC2.3's verification path accordingly.
  - Mark AC2.3 complete only after all evidence gates pass.
- `Docs/superpowers/specs/2026-07-27-ac2-2-speed-order-design.md`
  - Replace its future AC2.3 note with a compatibility statement that active units retain the AC2.2 ordering contract.
- AC2.3 implementation plan
  - Define exact files, APIs, tests, commands, and evidence steps.
- `Docs/Specs/AC2/Evidence/AC2.3/2026-07-28/`
  - Add automated-test log, manual-runtime check, and implementation link.

AC2.4 documentation must inherit the no-active-opponent state as its future victory/loss trigger. AC2.3 must not mark or claim AC2.4 behavior.

## 17. Completion Evidence

AC2.3 remains unchecked until the same implementation commit satisfies:

1. The focused AC2.3 runner passes with its exact signature and exit `0`.
2. Every existing test exits `0`.
3. GodotIQ project validation, parser, signal, runtime, and debug-console gates pass.
4. Manual Combat and Boss checks record the complete action, defeat, log, hover, no-op, and map-preservation observations.
5. `automated-test.log`, `manual-runtime-check.md`, and `implementation-link.txt` identify the same tested implementation commit.
6. The source acceptance criterion is changed from `[ ]` to `[x]` only after gates 1–5 pass.

Any missing artifact, stale commit, failed check, incomplete hover observation, or victory/loss behavior represented as AC2.3 completion keeps the criterion unchecked.

## 18. Future Extension Points

- AC2.4 consumes the no-active-opponents seam to produce victory or loss.
- AC2.6 may replace the fixed debug resolver with skills while retaining typed results and log entries.
- AC2.7 may enrich log entries with combo information without changing hover identity semantics.
- Roster and enemy-composition integration may replace fixtures while preserving HP, targeting, queue, and log contracts.
- Production presentation may replace debug controls and simple feedback labels without moving combat rules into scene nodes.
