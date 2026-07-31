# AC2.5 Event-Specific Reward Selection Design

**Status:** Approved

**Acceptance criterion:** AC2.5 — Winning battle presents multiple reward options based on the event type, with the player choosing from options such as recruitment, money, or item rewards.

## Goal

After a Combat or Boss victory, present three fixed, event-specific reward options. Let the player explicitly select one option and confirm it, then emit the typed choice and leave the battle. AC2.5 does not add the chosen reward to a roster, wallet, or inventory; those consumers belong to later acceptance criteria.

## Scope

AC2.5 includes:

- Fixed Combat and Boss reward catalogs.
- Typed reward option data.
- A victory-only reward panel embedded in the battle arena.
- Explicit selection followed by confirmation.
- A typed signal carrying the confirmed reward.
- Complete panel and selection cleanup when leaving, resetting, or starting another battle.
- Automated and manual verification for both supported event types.

AC2.5 excludes:

- Roster mutation or full-roster dismissal behavior from AC3.1 and AC3.2.
- Currency storage or spending.
- Inventory storage, equipment, or item effects.
- Random or seeded reward generation.
- Reward balancing, rarity rolls, or persistent unlocks.
- Defeat rewards.

## Architecture

Use a dedicated typed reward model and a pure fixed catalog while keeping presentation inside the existing battle arena scene. This separates reward definitions from the already stateful battle controller without introducing a separate screen-transition lifecycle.

`BattleRewardOption` is a value object. `BattleRewardCatalog` maps the configured encounter type to fresh reward options. `BattleArena` owns only the current panel state: available options, current selection, confirmation latch, rendering, and signal emission.

## Components

### BattleRewardOption

`BattleRewardOption` is a `RefCounted` typed value object with:

- `reward_id: StringName` — stable identity for future consumers and tests.
- `kind: Kind` — `RECRUITMENT`, `MONEY`, or `ITEM`.
- `title: String` — short selectable label.
- `description: String` — readable explanation of the prospective reward.

The object describes a choice but does not apply it. It contains no references to scene nodes or run state.

### BattleRewardCatalog

`BattleRewardCatalog` is a pure lookup with a function that accepts the existing encounter-type string and returns `Array[BattleRewardOption]`.

The fixed MVP catalog is:

| Event type | Reward ID | Kind | Title | Description intent |
|---|---|---|---|---|
| Combat | `combat_recruit_scout` | Recruitment | Recruit Scout | Offers a Scout recruit after the battle |
| Combat | `combat_money_100` | Money | 100 Money | Offers 100 run currency |
| Combat | `combat_supply_cache` | Item | Supply Cache | Offers a practical item cache |
| Boss | `boss_recruit_champion` | Recruitment | Recruit Champion | Offers a stronger Champion recruit |
| Boss | `boss_money_250` | Money | 250 Money | Offers 250 run currency |
| Boss | `boss_rare_relic` | Item | Rare Relic | Offers a rare boss item |

Every lookup returns fresh option instances so selection state cannot leak between battles. Unsupported event types return an empty typed array; there is no implicit fallback. On an unsupported-type victory, the reward panel is shown with `No rewards available`, no option controls, and disabled Confirm so the terminal state is explicit rather than silently hiding the reward surface.

### BattleArena reward panel

The reward panel is part of `battle_arena.tscn` and appears within the terminal result presentation. It contains:

- An event-specific heading.
- Three selectable reward controls when the catalog has options.
- A stable description surface for the currently selected option.
- A Confirm button.
- A readable empty state for unsupported event types.

The selected control has a persistent visual distinction. Selecting another option replaces the prior selection. Confirm is disabled until exactly one option is selected.

`BattleArena` adds a typed `reward_confirmed(option: BattleRewardOption)` signal. Confirmation emits this signal before the existing `exit_requested` signal so future run-state consumers can process the choice before the battle node is removed.

The existing `battle_completed(VICTORY)` signal remains emitted when victory is first latched. Reward presentation is a consequence of that terminal victory and does not change battle-outcome semantics.

## State and data flow

1. A battle is configured with its coordinate and encounter type.
2. Configuration clears reward controls, selected reward, confirmation latch, and descriptive text, and keeps the panel hidden.
3. Combat proceeds using the existing terminal-state rules.
4. Defeat shows the existing defeat result and never opens the reward panel.
5. Victory latches once, emits the existing battle completion event, obtains fresh options from `BattleRewardCatalog`, populates the reward controls, and reveals the panel.
6. Selecting a reward stores that option, updates the highlight and description, and enables Confirm.
7. Confirm latches immediately to reject repeated input.
8. The arena hides and clears the reward panel before emitting any exit signal.
9. The arena emits `reward_confirmed(selected_option)` exactly once, then emits `exit_requested`.
10. `MapController` follows its existing exit path and removes the active battle from the UI.
11. A later battle starts from a hidden, empty, unselected reward state.

The debug exit path also hides and clears the panel before requesting exit, but it never emits `reward_confirmed`.

## Lifecycle guarantees

The reward UI must not survive its battle:

- It is hidden on scene entry and after every configuration/reset.
- It becomes visible for every completed victory: supported Combat/Boss victories show selectable options, while unsupported-type victories show the non-actionable `No rewards available` empty state.
- It is immediately hidden and cleared on Confirm, before the battle exit signals.
- It is immediately hidden and cleared on debug exit.
- Removing the active battle instance removes the panel with it.
- A newly instantiated or reconfigured battle has no reward controls, no description, no selected reward, a disabled Confirm button, and a hidden panel.

These guarantees cover both normal new-instance creation and test-time reuse of one arena instance.

## Defensive behavior

- Unsupported encounter types produce no options, show a clear `No rewards available` state, and leave Confirm disabled.
- Defeat cannot populate, select, or confirm rewards.
- Input after battle completion cannot mutate combat state, preserving AC2.4.
- Confirm without a selected option is a no-op.
- Repeated Confirm input cannot emit duplicate reward or exit signals.
- Reconfiguration invalidates any previously selected option.
- Debug exit never masquerades as a confirmed choice.

## Verification strategy

### Automated coverage

A focused AC2.5 test suite verifies:

- Combat returns exactly the three specified fixed options.
- Boss returns exactly the three specified fixed options and differs from Combat.
- Unsupported event types return no options.
- Catalog calls return fresh option instances.
- Reward UI begins hidden and empty.
- Victory reveals the correct event-specific options.
- Defeat does not reveal rewards.
- Confirm begins disabled.
- Selecting one option highlights it, shows its description, and enables Confirm.
- Selecting a second option replaces the first selection.
- Confirm emits the selected typed option before exit.
- Confirm emits each signal at most once.
- Confirm hides and clears the reward UI immediately.
- Debug exit hides and clears the UI without a reward signal.
- Reconfiguration restores the initial hidden and unselected state.
- A second battle instance does not display the previous battle's panel or selection.
- Existing AC2.1–AC2.4 tests remain green.

### Manual runtime coverage

1. Win a Combat battle and verify the three Combat options.
2. Select one option, verify its persistent highlight and description, and verify Confirm becomes enabled.
3. Select a different option and verify the selection moves.
4. Confirm the option and verify the reward screen disappears with the fight.
5. Enter a new battle and verify no reward screen, controls, description, or selection from the previous fight is visible.
6. Win a Boss battle and verify its three options differ from Combat.
7. Confirm a Boss reward and verify the same cleanup.
8. Lose a battle and verify no reward panel appears.

## Completion boundary

AC2.5 is complete when Combat and Boss victories present their fixed multiple choices, the player can explicitly select and confirm exactly one typed choice, the reward panel is fully cleaned up after the fight and absent from the next battle, automated regressions pass, and the runtime evidence is recorded. The selected choice is intentionally not applied to run state in this criterion.
