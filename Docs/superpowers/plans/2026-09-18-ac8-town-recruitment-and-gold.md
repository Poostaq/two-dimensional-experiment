# AC8 — Town Recruitment and Gold Plan

> For implementation: use `superpowers:executing-plans`. Follow repository AGENTS.md, including GodotIQ inspection, per-script validation, and a dedicated branch in the primary workspace; do not use worktrees.

**Status:** AC8.1 implemented in `c644778`; [verification evidence](../../Specs/AC8/Evidence/AC8.1/verification.md). AC8.2 and AC8.3 are implemented and verified; [AC8.2 evidence](../../Specs/AC8/Evidence/AC8.2/verification.md), [AC8.3 evidence](../../Specs/AC8/Evidence/AC8.3/verification.md). AC8.4 ownership is verified, and current-world AC8.5 recruitment is implemented in `7e51140` ([evidence](../../Specs/AC8/Evidence/AC8.5/verification.md)). Broad AC8.4 acceptance and AC8.6-AC8.8 remain pending. Confirmed requirements are separated from proposed defaults.

**Goal:** Earn gold through victorious battles and spend it recruiting characters in intact allied towns.

**Architecture:** Run state owns the wallet and durable transactions. Battle results supply defeated-enemy identities; a small economy rules module calculates awards and purchases. WorldRuntimeController coordinates town UI, existing roster placement, and save-before-publication transactions.

**Tech stack:** Godot 4, typed GDScript, authored UI scenes, headless SceneTree tests, GodotIQ runtime verification.

## Confirmed design

- Every new run begins with 100 gold, displayed as `100g`.
- Every recruit costs 500g, irrespective of character class.
- A won fight awards 50g per defeated enemy character. Losing any fight, ordinary or boss, ends the run, grants no gold and returns the player to the main menu. The lost run cannot be continued, including after application restart; the player must start a new run.
- A reward screen shows a money icon and the exact earned amount, for example `Gold received: 150g` for three defeated enemies.
- Gold replaces the existing post-battle reward choices, including the Scout recruitment reward. Recruitment is accessed in towns.
- The roster remains limited to six characters. Reuse its placement/replacement interaction; no second roster system.
- Burned towns cannot be used for recruitment, but their map hexes remain traversable under AC10.
- Each town offers recruits only from the clan that owns its habitat.
- Before habitat generation is implemented, every existing town counts as Goblin habitat and offers only eligible Goblin classes. AC8 can therefore be implemented on the existing map without waiting for AC9's multi-clan habitats.
- Offer only classes absent from the entire current roster. Use canonical class identity, not character identity, display name, formation slot or current HP. A passed-out character still occupies its class in the roster.
- Recompute offers after recruitment, dismissal/replacement and reload. Once the last roster member of a class leaves, that class becomes eligible again in its clan's towns. If no eligible classes remain, show an empty-state message and no purchase action.

## Decisions and proposed defaults

The interim Goblin-town rule is confirmed. Resolve town ownership through one shared rule: pre-habitat world versions return Goblin ownership for every existing town; habitat-enabled versions use explicit generated ownership. Never use a missing clan field in a habitat-enabled save as a reason to silently turn that town Goblin. This compatibility rule does not change current town count, placement, roads or starting positions, and does not claim that habitat generation is implemented.

- Keep non-gold post-battle health recovery after victory and existing formation persistence. Recovery must not resume a lost run.
- Town browsing, purchasing, and party rearrangement do not advance world time. Enemy movement is driven by accepted map moves in AC10.
- Count distinct defeated character identities once per battle, including a commander in a victorious boss encounter. Revival followed by another defeat must not pay twice for the same character.
- Reward presentation is an acknowledgement of a committed award, not a second mutation when Continue is clicked.

## Ownership and files

Existing files to extend:

- `Scripts/Run/world_run_state.gd`: gold and pending/settled battle reward state.
- `Scripts/Run/world_run_start_service.gd`: initialize 100g exactly once on new-run creation.
- `Scripts/Run/run_roster.gd`: retain capacity, unique identities, placement and replacement validation.
- `Scripts/WorldMap/world_runtime_controller.gd`: coordinate victory settlement, town entry and purchases.
- `Scripts/WorldMap/world_runtime_save_coordinator.gd`: persist candidate state before publishing it.
- `Scripts/Battle/battle_arena.gd`: expose a final battle outcome and defeated-enemy identities; retire choice-based production rewards.
- `Scripts/UI/world_map_hud.gd`, `Scenes/world_map_hud.tscn`: wallet display.
- `Scripts/Save/world_run_save_codec_v2.gd`: inspect existing format before adding a new versioned codec; do not silently change the v2 contract.

Proposed new files:

- `Scripts/Run/run_economy_rules.gd`: pure award/purchase rules and named constants for 100/500/50.
- `Scripts/UI/town_recruitment_panel.gd`, `Scenes/UI/town_recruitment_panel.tscn`: town offers, prices and purchase/placement flow.
- `Scripts/UI/battle_gold_reward_panel.gd`, `Scenes/UI/battle_gold_reward_panel.tscn`: gold icon, amount and Continue control.
- `Tests/Run/test_ac8_economy.gd`, `Tests/WorldMap/test_ac8_town_recruitment.gd`, `Tests/UI/test_ac8_gold_reward.gd`.

## Transaction contracts

Victory settlement:

1. Freeze one final result with a stable battle identifier and distinct defeated enemy identifiers.
2. Calculate `earned_gold = 50 * defeated_enemy_count` only for victory.
3. Stage gold, recovery, encounter completion and the pending reward presentation together.
4. Persist the complete candidate. A failed save changes neither the live wallet nor encounter completion; retry reuses the same candidate.
5. Publish once and show the amount. Duplicate result signals do nothing. Reloading a pending reward screen must not re-award it.
6. Continue dismisses the presentation through the normal durable flow. Boss victory must still show its gold reward before the run-completion screen.

Defeat settlement (AC8.2):

1. Freeze the final loss result and block further battle/world input. This applies to ordinary and boss fights, including losses after defeating some enemies.
2. Grant no gold, show no victory reward, and do not apply recovery as a path back into the world.
3. Durably mark the run lost or invalidate its resumable slot before completing the return to the main menu. Both menu Continue eligibility and the domain load entry point must reject the lost run after application restart.
4. On persistence failure, retain the frozen loss and offer retry; do not use the ordinary discard-pending path to restore the pre-defeat playable checkpoint. Repeated results and retries settle the same loss once. The exact terminal-state storage mechanism belongs to AC8.2 implementation planning.
5. Return to the main menu once settlement succeeds. Start New Run creates a fresh run with 100g; gold, roster changes and progress from the lost run do not carry over. This implements the requested run-loss rule without reopening deferred cross-run progression decisions.

Recruitment:

1. Derive offers as the town clan's supported recruitable classes minus all class IDs in the current roster. Validate intact allied town, offer identity, class absence, clan eligibility and `gold >= 500`.
2. Open existing placement; for a full roster, require a valid replacement choice.
3. Stage the new roster and `gold - 500` as one transaction.
4. Persist, then publish both. Cancel, stale offer, failed replacement, duplicate click or failed save must never charge independently of recruitment.
5. Revalidate town status, class absence in the current live roster and available gold at commit. A stale offer cannot purchase a class acquired since the panel opened; choosing a replacement slot cannot bypass the class filter.
6. Refresh offers after publication. Cancellation or failed save leaves both roster eligibility and gold unchanged. Reload derives offers from the restored roster rather than persisting a stale UI list.

## Implementation sequence

The numbered steps below match the MVP acceptance criteria. Add focused failing tests before each implementation step; include durable candidate-state handling as each mutation is introduced, then complete the cross-flow persistence checks in AC8.8.

- [x] AC8.1: Follow the [focused starting-gold and HUD plan](2026-09-19-ac8-1-starting-gold-and-hud.md). Initialize new runs with 100g; persist and display the current balance. Test initialization exactly once, reload, candidate copying and balance refresh.
- [x] AC8.2: Implement victory gold at 50g per distinct defeated enemy and terminal run loss for every lost fight. Test ordinary/boss defeat, no award after partial enemy kills, one return to the main menu, Continue rejection after restart, fresh new-run state, terminal-save failure/retry, repeated defeats and duplicate result events.
- [x] AC8.3: Replace production reward choices with the money-icon/amount screen. Preserve health recovery and battle completion sequencing; update `Tests/Battle/test_ac2_5_reward_selection.gd` and `Tests/WorldMap/test_scout_recruitment_flow.gd` for the superseded production flow.
- [x] AC8.4 ownership prerequisite: [Verified](../../Specs/AC8/Evidence/AC8.4/verification.md); broad MVP acceptance still awaits AC8.5/AC8.6 filtered offers. Shared town-ownership rule: every existing allied town in a pre-habitat world counts as Goblin habitat. Verify all towns and reload without topology changes. Habitat-enabled worlds later use explicit generated ownership through the same rule.
- [x] AC8.5: Town recruitment at exactly 500g using resolved Goblin town ownership, with shared availability and open/reopen/no-op contracts. [Focused implementation plan](2026-09-20-ac8-5-town-recruitment.md) and [verification](../../Specs/AC8/Evidence/AC8.5/verification.md). Current-world acceptance does not claim full AC8.6-AC8.8 or generated/burned-town integration.
- [ ] AC8.6: Filter out every class already in the whole roster, including passed-out members. Revalidate class absence at purchase; test refresh after recruitment, dismissal/replacement and reload, empty offers and stale requests.
- [ ] AC8.7: Integrate existing six-member placement/replacement. Test chosen-slot preservation, insufficient funds, cancellation, invalid requests and failed saves without partial roster or wallet changes.
- [ ] AC8.8: Complete versioned persistence for wallet, pending reward acknowledgement and transaction identity. Verify save retry, reload, duplicate settlement, repeated purchases and ruins rejection across the integrated flows. Run runtime checks including boss victory, record evidence and update the MVP criteria without marking unverified behavior complete.

## Acceptance and verification

| Case | Expected result |
|---|---|
| Fresh run | Exactly 100g |
| Any town before habitat implementation, including after reload | Goblin ownership; only Goblin classes absent from the roster are offered; existing topology is unchanged |
| Habitat-enabled town | Explicit owning clan is respected; missing ownership is rejected rather than defaulted to Goblin |
| Victory over 3 enemies | Reward shows icon and 150g; balance becomes 250g |
| 8 total enemy defeats across won fights | Starting balance reaches 500g; one recruit leaves 0g |
| 499g / 500g purchase boundary | Reject unchanged / recruit once and deduct exactly 500g |
| Ordinary or boss defeat after killing an enemy | No gold or victory reward; run ends and returns to the main menu; player must start again |
| Continue or application restart after settled defeat | Lost run cannot resume through UI or domain load entry points |
| Duplicate loss result / terminal-save failure then retry | One terminal settlement and menu return; no reward and no playable rollback to the lost run |
| Start New Run after defeat | Fresh run with exactly 100g; no lost-run roster changes or progress carried over |
| Same enemy defeated twice or duplicate result event | One award per distinct enemy in the settled battle |
| Placement cancellation / full roster without replacement | Wallet and roster unchanged |
| Save failure then retry | No partial charge or reward; one successful transaction |
| Reload at reward screen | Same amount shown; no second award |
| Burned town | No recruitment entry or purchase; movement through hex still works |
| Class already present, including on a passed-out character | Not offered in any town; direct/stale purchase rejected without charge |
| Recruit an eligible class | Class disappears from offers in all towns of that clan |
| Dismiss/replace the last member of a class | Class becomes eligible again at that clan's towns |
| All classes of the town's clan represented | Empty offers with a clear message; no purchase action |
| Reload or cancelled/failed placement | Offers match the durable roster; no phantom availability changes |

Run each new headless test with `godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/<test-path>.gd`; require exit code 0 and no script errors. Retain recovery and roster-placement regressions. For runtime evidence use GodotIQ play, verify_project_runs, debug console and state inspection, plus a screenshot of the reward and town screens. Tests are planned, not executed for this document.

## Balance observation

With today's two-enemy ordinary encounters, each victory yields 100g: the first recruit costs four victories from 100g, subsequent recruits five victories each. AC10 pacing must leave enough time and accessible encounters to make town recruitment usable; tune siege/travel pacing after measuring this, without changing the requested economy values.
