# AC10 — Enemy Town Siege and Pursuit AI Plan

> For implementation: use `superpowers:executing-plans` after AC9's topology and shared persistence contract are available. Follow AGENTS.md and GodotIQ; use a dedicated task branch in the primary workspace, never a worktree.

**Status:** Planning only. Siege duration and event ordering below are explicit proposed defaults for the confirmed siege requirement.

**Goal:** The commander-led enemy party destroys allied towns, then pursues the player after every allied town is burned.

**Architecture:** A pure enemy campaign rules module advances a serializable state machine once per accepted world turn. WorldRuntimeModel produces a combined player/enemy/town candidate. WorldRuntimeController persists it before presentation or encounters are published. BattleArena continues to own combat, not campaign targeting.

**Tech stack:** Godot 4, typed GDScript, versioned run saves, SceneTree tests and GodotIQ runtime inspection.

## Confirmed design

- Seek the closest intact player-allied town when choosing a target.
- If multiple towns are equally close, randomly select one and stick to it. Do not reroll or switch every movement turn.
- Reaching a town begins a siege; the town is not burned immediately.
- Completing a siege turns it into a burned town with no usable town services.
- Burned town hexes remain traversable ruins. Roads through them remain traversable.
- After all allied towns are burned, actively pursue the player's party.
- This system replaces move-count-based Sudden Death. Do not retain its timer, activation or automatic boss empowerment alongside the new rule.
- With AC9's three allied habitats, the initial target set contains nine allied towns. Any future enemy-owned towns are excluded.

## Proposed timing and encounter rules

- Enemy movement: one adjacent hex after each accepted player map move, beginning with the first move. Roads have no speed bonus in the first version.
- Menus, town purchases, reward acknowledgements, battle rounds, rejected moves and save retries advance no campaign turns.
- Distance means shortest traversable hex-step distance, matching AC9's road-distance contract.
- Siege duration: one complete player world-turn opportunity after arrival. Arrival sets `siege_turns_remaining = 1` without decrementing it. On the next accepted world move, resolve player/enemy collision first, then decrement and burn if uninterrupted.
- The enemy remains on the town hex throughout the siege and on the burn turn; it cannot also move toward the next town that turn.
- The player may intercept the enemy on any hex, including the besieged town. Interception opens the commander-party battle before town destruction. Victory ends the run through the existing boss-victory flow and AC8 gold presentation; defeat ends the run.
- Services at a besieged town are temporarily unavailable; entering its occupied hex triggers interception. Burned towns permanently lose services for that run.
- On burning the final town, switch to pursuit immediately but take the first pursuit step on the next accepted world move.
- In pursuit, recalculate the shortest route to the player's latest committed destination each turn. Path ties use canonical neighbour order; town target ties use seeded random selection.

## State machine and persistence

States:

- `seeking_town`: lock an intact allied target if none exists, then follow its route.
- `sieging_town`: remain at the target until the siege countdown expires or the player intercepts.
- `pursuing_player`: follow the player's current map position after all allied towns are burned.
- `engaged`: boss battle owns progression; no map movement or siege countdown.
- Terminal run victory/defeat: no further campaign updates.

Persist the enemy coordinate and party identity, AI mode, locked target town ID, siege turns remaining, target-selection counter, stable town-status map and world-turn index. The settled battle/reward state belongs to AC8's transaction contract. The destroyed-town count should derive from town statuses rather than drift as an independent counter.

Town selection procedure:

1. If a locked target remains intact and reachable, retain it even if another town would now be closer.
2. Otherwise enumerate reachable intact allied towns, compute minimum path distance and sort the tied town IDs canonically.
3. Choose one using seed, AI namespace and persisted target-selection counter. Advance that counter only when the selected target is durably committed.
4. No intact allied towns means pursuit. Intact but unreachable towns mean a navigation invariant failure, not permission to pursue early or claim all towns burned.
5. A burned/invalid target is cleared and selected again; a temporarily invalid route is recomputed without silently switching an otherwise valid target.

## One world-turn transaction

1. Validate player movement and all modal/input blocks. Rejection changes nothing.
2. Stage the player's destination and world-turn increment.
3. If the player enters the enemy's current coordinate, stage boss engagement immediately and do not tick siege or move the enemy.
4. Otherwise advance exactly one enemy action: movement, siege progression, or pursuit. If the enemy enters the player's destination, stage boss engagement.
5. Determine town status and presentation changes. Boss collision takes priority over an ordinary encounter on the same player destination.
6. Stage the ordinary encounter only when no boss engagement exists.
7. Persist the combined player/enemy/town/encounter state. Publish and open presentation only after save success. Failed save/retry must not consume another siege turn, reroll a target or move the enemy again.

## Ownership and file map

Extend:

- `Scripts/WorldMap/world_runtime_model.gd`: replace Sudden Death advancement with one candidate campaign turn.
- `Scripts/WorldMap/world_runtime_snapshot.gd`, `world_move_result.gd`: immutable enemy/town/mode changes for consumers.
- `Scripts/Run/world_run_state.gd`: durable campaign state and validation.
- `Scripts/WorldMap/world_runtime_controller.gd`, `world_runtime_save_coordinator.gd`: combined persistence and encounter precedence.
- `Scripts/WorldMap/world_presentation_controller.gd`, `world_cell_view.gd`, `world_minimap.gd`: moving enemy marker, siege indicator and ruins.
- `Scripts/UI/world_map_hud.gd`, `Scenes/world_map_hud.tscn`: remaining allied towns and siege/pursuit status in place of Sudden Death messaging.

Create:

- `Scripts/WorldMap/enemy_campaign_rules.gd`: pure target selection, siege and pursuit transitions.
- `Tests/WorldMap/test_ac10_enemy_campaign.gd`: deterministic state-machine tests.
- `Tests/WorldMap/test_ac10_campaign_transactions.gd`: move/save/encounter integration.
- `Tests/UI/test_ac10_town_states.gd`: intact, besieged and ruined presentation/services.

## Implementation sequence

- [ ] Task 1 (AC10.1, AC10.3-AC10.5): Add state-machine fixtures for target selection, tie locking, approach, siege, burning and all-towns pursuit. Implement pure rules against AC9's stable town IDs and topology.
- [ ] Task 2 (AC10.2, AC10.6): Integrate one enemy action per accepted world move. Remove move-count Sudden Death activation/empowerment and HUD messaging for new-version runs; retain ordinary world-turn accounting needed by existing systems.
- [ ] Task 3 (AC10.8): Persist locked targets, siege progress, town statuses and selection counter in the shared schema; verify mid-siege reload and failed-save retry.
- [ ] Task 4 (AC10.7): Add player/enemy interception precedence and commander-party battle entry. Boss engagement must not also open an ordinary battle or burn the target.
- [ ] Task 5 (AC10.3, AC10.4, AC10.9): Add siege/ruin visuals, town-service guards, minimap state and remaining-town count. Use authored scene assets through GodotIQ.
- [ ] Task 6 (AC10.2, AC10.6-AC10.8): Replace superseded Sudden Death assertions in current runtime tests; retain regression checks for movement, modal blocking, save atomicity, battle entry and recovery.
- [ ] Task 7 (AC10.5, AC10.7, AC10.9): Run a complete campaign through nine town destructions into pursuit, plus an early interception victory and defeat. Record deterministic state logs and visual evidence.
- [ ] Task 8 (AC10.6, AC10.8): Update the main design spec and verification table, explicitly superseding the old Sudden Death behavior. Coordinate any old-save compatibility path with AC9 rather than allowing mixed rules in a new run.

## Acceptance and verification

| Fixture | Required result |
|---|---|
| One nearest intact town | Select it and approach by a shortest route |
| Two equally near towns | Seeded selection; no reroll during subsequent turns or reload |
| Another town becomes nearer after movement | Existing valid target retained |
| Arrival at target | Siege shown; town not burned on arrival |
| Next player move without interception | Town burns once; enemy does not also depart |
| Player enters besieged town | Boss fight opens before burn; no ordinary encounter |
| One intact allied town remains | Continue town-seeking, even beyond old Sudden Death threshold |
| Final allied town burns | Switch to pursuit; first pursuit move is next world turn |
| Player moves during pursuit | Enemy follows current destination one hex per accepted move |
| Burned town entered | Traversable; no recruitment/services |
| Rejected/modal-blocked move, UI action or battle round | No enemy movement, target roll or siege decrement |
| Save failure then retry | Entire candidate commits once; no double movement/burn |
| Mid-siege reload | Same target, mode, position and remaining siege time |
| Intact towns unreachable | Explicit invariant failure, not premature pursuit |

Run new tests with `godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/<test-path>.gd`, requiring exit code 0 and no script errors. Run affected world runtime, save, encounter and AC8 recruitment regressions. Verify with GodotIQ play, verify_project_runs, debug console and state inspection; capture siege and ruins only at their visual verification points. Tests are planned, not run for this document.

## Tuning after the first version

The confirmed threshold is all allied towns. Do not implement a lower threshold yet. Measure accepted moves to first siege, first affordable recruit, last town burned and forced interception across a seed corpus. If a one-turn siege gives insufficient response time, propose a longer siege using those measurements. Additional town defenders, rescue rewards, rebuilding, enemy reinforcements and boss stat escalation are outside this first version.
