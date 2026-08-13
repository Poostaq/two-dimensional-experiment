# AC3.1 Run Roster Recruitment Design

**Status:** Approved

**Acceptance criterion:** AC3.1 — Player can acquire a unit from a valid run-based source if roster < 6.

## Goal

Create a run-owned roster with three fixed starters, apply eligible recruitment rewards to that roster, and use the updated roster to populate the player's side in the next battle. The acquired character is verified in that next fight; AC3.1 adds no on-map roster interface.

## Scope

AC3.1 includes:

- A separate persistent run-character model that does not reuse mutable battle state.
- A run roster owned by `MapController`, initialized with exactly three fixed starter characters.
- A maximum roster size of six.
- Recruitment mappings for the existing Scout and Champion reward IDs.
- Reward-option filtering so only currently eligible recruits are presented.
- Defensive validation again when a recruitment reward is confirmed.
- Fresh player battle-state creation from the current run roster for every fight.
- Automated and manual evidence that an acquired character appears in the next fight.

AC3.1 excludes:

- An on-map roster display or party-management interface.
- Dismissal or replacement when the roster is full.
- Duplicate characters.
- Currency and item reward application.
- Character progression, equipment, recovery, or default actions.
- Save persistence, meta-progression, and roster carry-over between runs.
- Changes to canonical AC3.2 or later acceptance-criterion status.

## Architecture

Use a `RunCharacter` value object and a focused `RunRoster` domain object owned directly by `MapController`. This is the smallest boundary that separates persistent run identity from transient battle state without introducing a global manager or a new scene node before the project needs one.

`RunCharacter` stores stable identity and base combat data. `RunRoster` owns roster membership, capacity and duplicate rules, and conversion into fresh `BattleUnitState` instances. A pure character catalog maps supported recruitment reward IDs to fresh `RunCharacter` definitions.

`MapController` remains the run-lifecycle coordinator. It owns one roster for the current run, supplies fresh player units when it creates each `BattleArena`, filters reward options against roster eligibility, consumes the confirmed reward before battle exit, and starts a new roster when a new run is initialized.

`BattleArena` remains responsible for battle execution and reward presentation. It receives the eligible reward options for the current victory; it does not own or mutate the run roster.

## Components

### RunCharacter

`RunCharacter` is a typed `RefCounted` value object containing:

- `character_id: StringName` — stable run identity used for duplicate detection and later unit-management features.
- `display_name: String` — the name shown in battle.
- `base_speed: int` — the initial battle speed.
- `max_hp: int` — the initial maximum battle HP.
- `skills: Array[CharacterSkill]` — defensive character-specific skill definitions.

It contains no current HP, cooldowns, temporary modifiers, side, or slot index. Those values belong to a newly created `BattleUnitState` for each battle.

### RunCharacterCatalog

`RunCharacterCatalog` is a pure lookup that returns fresh character definitions. It defines the three starter characters using the existing player fixtures and maps these existing reward IDs:

| Reward ID | Character |
|---|---|
| `combat_recruit_scout` | Scout |
| `boss_recruit_champion` | Champion |

Unknown or non-recruitment reward IDs return no character. Catalog calls return fresh objects so callers cannot mutate shared definitions.

### RunRoster

`RunRoster` owns an ordered `Array[RunCharacter]` and defines `MAX_ROSTER_SIZE = 6`. A new roster contains exactly the three catalog starters.

Its public contract provides:

- A defensive roster snapshot.
- Current size and full-state queries.
- Character-ID membership lookup.
- `can_add(character_id)` eligibility without mutation.
- `try_add(character)` with a typed result distinguishing success, invalid character, duplicate character, and full roster.
- Fresh player-side `BattleUnitState` creation in roster order.

`try_add()` is authoritative even when the reward UI previously filtered the option. This prevents stale, repeated, or directly invoked confirmation from bypassing capacity and duplicate rules.

Battle conversion assigns consecutive player slots from zero, begins every unit at its defined maximum HP, and creates fresh mutable skill and combat-state containers. Mutating one battle must not mutate the roster or a later battle.

### Reward eligibility

The reward catalog remains the source of event-specific reward choices. Before a victory reward panel is populated, recruitment options are filtered through the current roster:

- Omit recruitment when roster size is six.
- Omit recruitment when its mapped character is already owned.
- Omit recruitment when its reward ID has no valid character mapping.
- Preserve money and item options unchanged.

An eligible Combat or Boss victory therefore retains the existing three options. A full roster, duplicate recruit, or invalid recruitment mapping leaves the two non-recruitment options. Recruitment is omitted rather than shown disabled.

This AC3.1 behavior deliberately does not implement AC3.2. A later AC3.2 design may introduce an explicit replacement flow for full rosters.

## State and data flow

1. `MapController` initializes a fresh three-character `RunRoster` for the run.
2. A valid map encounter requests a battle.
3. `MapController` creates a `BattleArena` and supplies fresh player battle states converted from the current roster; enemy setup remains battle-owned.
4. Combat resolves using existing battle rules.
5. On victory, the event-specific reward catalog produces its normal options.
6. `MapController` filters recruitment options using the current roster and supplies the eligible options to the arena.
7. The player selects and confirms one presented option.
8. `BattleArena` emits `reward_confirmed` before `exit_requested`, preserving the existing signal-order contract.
9. `MapController` resolves recruitment through `RunCharacterCatalog` and calls `RunRoster.try_add()` exactly once. Money and item rewards remain no-ops in this criterion.
10. Battle cleanup follows the existing exit path.
11. The next battle receives a new player battle-state array built from the updated roster, making the acquired character visible in its roster slot.

## Defensive behavior

- A full roster never receives a recruitment option.
- An already-owned character never receives a recruitment option.
- An unknown recruitment reward never receives a selectable option.
- Mutation-time validation rejects full, duplicate, invalid, stale, and repeated recruitment requests without changing roster size or order.
- Reward confirmation and battle exit ordering cannot remove the arena before `MapController` processes a valid recruitment.
- Defeat never offers or applies a reward.
- Money and item confirmation does not mutate the roster.
- Battle-state mutation cannot alter run-character definitions or later battles.
- A fresh run reconstructs only the three starters.

## Verification strategy

### Automated coverage

A focused AC3.1 runner verifies:

- Exactly three fixed starters and stable roster order.
- Defensive roster and skill snapshots.
- Maximum size six and accurate full-state behavior.
- Valid Scout and Champion catalog mappings return fresh definitions.
- Successful eligible recruitment increases roster size exactly once.
- Duplicate, full, invalid, stale, and repeated acquisition attempts do not mutate the roster.
- Eligible recruit options remain alongside money and item options.
- Duplicate, full-roster, and unknown recruit options are absent while money and item choices remain.
- Fresh battle conversion uses player side, consecutive roster slots, full HP, and the current roster order.
- Battle-state changes do not leak into the roster or the next battle.
- `reward_confirmed` is processed before `exit_requested` cleanup.
- A confirmed eligible recruit appears in the next instantiated battle.
- Defeat and non-recruitment rewards do not mutate the roster.

Existing AC1 and AC2 runners remain regression gates, with particular attention to AC2.1 battle slots, AC2.5 reward selection and signal ordering, AC2.6 character skills, and AC2.9 battle history.

### Manual runtime coverage

1. Begin a run and enter a Combat battle with the three-character starter roster.
2. Win, select the eligible Scout recruitment reward, and confirm it.
3. Enter the next fight.
4. Verify four player units are present, the original three remain in order, and Scout occupies the next player slot.
5. Verify the fight starts without stale HP, cooldowns, selection, or reward state.
6. Exercise a duplicate or full-roster fixture and confirm recruitment is absent while the money and item choices remain usable.

No AC3.1 completion claim is valid without focused automated PASS, complete regression PASS, GodotIQ validation and error checks, runtime verification, and recorded manual evidence tied to the tested implementation commit.

## Future decision boundary

Unresolved product questions are recorded in `Docs/TO_CONSIDER.md`. AC3.1 temporarily forbids duplicate character IDs and hides recruitment at full capacity; these are explicit current rules, not permanent decisions for the complete game.
