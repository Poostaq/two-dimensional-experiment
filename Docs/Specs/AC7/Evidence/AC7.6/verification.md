# AC7.6 skill and character-information verification

**Status: PASS.** Verified 2026-09-18 on `feature/ac7-6-character-information`. Implementation: `4da4935` (local commit, not pushed).

Authority: [MVP AC7.6](../../../GAME_DESIGN_SPEC_MVP.md). Contract/task record: [implementation plan](../../../../superpowers/plans/2026-09-18-battle-skill-and-character-information.md).

Main was fetched and updated from origin, then fast-forwarded to completed local AC7.5 before creating this task branch. AC7.4 `57429e0` and AC7.5 `4625596` are included. Planning changes were stashed during setup and restored; the stash remains as a backup. No worktree or remote push was used.

Environment: Godot `4.7.2.stable.steam.ed1daf0bf`, Windows, OpenGL compatibility, NVIDIA GeForce RTX 3080, driver 591.44. Rendered fixtures: 1152x648, 1024x648 and 1920x1080.

## Results

- All 25 pre-existing Battle runners passed the baseline. [AC7.4 baseline](test_ac7_4_debug_drawer-baseline.log) explicitly covers the required dependency.
- All 28 current Battle runners plus world battle entry, party formation and preparation UI passed: **31 runners**. After final focus/scroll corrections, the three new runners, AC7.3, AC7.4, AC7.5 and active-turn lock passed again. Final logs are listed below.
- [Rendered input/layout QA](rendered-qa.log): PASS at all three sizes with actual pointer right-clicks, hover, wheel scrolling and Escape dispatch. All 18 captures below were inspected.
- GodotIQ final validation: 175 scripts, 19 scenes, **zero errors**, unchanged baseline **27 warnings and 6 informational findings**. Project parser check: 175 scripts, zero errors. No orphan signals; scanner-only missing definitions refer to native UI signals emitted by tests.
- Battle and production `world_run_start.tscn` startup verification: PASS. Live inspection opened `player_4` at committed revision 1. The final GodotIQ tour showed the left panel, health/statistics, scrolling content and underlying battle layout; debug console empty. Game stopped after checks.
- Read-only presenter and integration reviews: PASS after fixing expiry/source metadata, Snared follow-up text, stale preview cleanup, covered-slot keyboard focus and visible-part pointer inspection. Added tests cover actual Tab traversal, hidden saved-focus fallback and reward/recruitment ownership.
- `git diff --check` and staged checks passed before the implementation commit.

## Acceptance mapping

| Contract | Executed evidence | Result |
|---|---|---|
| Equal skill dimensions, descriptions, unchanged defaults | [AC7.3](test_ac7_3_unified_action_bar.log): actual 160x88 tiles at three sizes, 0/1/4 active skills, long titles, default geometry stability, unavailable explanations, focus/pointer precedence, obscured-source cleanup. [AC2.6](test_ac2_6_character_skills.log) and [AC2.7](test_ac2_7_skill_preview.log) retain metadata/tooltip checks with passive presentation migrated. | PASS |
| Identity, health, stats, effects and passives | [Presenter](test_battle_character_info_presenter.log): detached nested copies, source IDs, structured expiry, opposing speed effects, defense versus armor, Bleed/Snared semantics, passive descriptions and resolving flag. [Panel](test_battle_character_info_panel.log): identity, width, scrolling, animation and scroll reset. Effect/passive captures below. | PASS |
| Complete committed snapshots and stale-work rejection | [Inspection](test_battle_character_inspection.log): a real damage callback opens a different unit and sees old HP while resolving; exactly one new revision includes final HP and advanced actor. Also explicit mid-resolution refresh, rejected action, defensive copy, unit switch, obsolete token, same-ID epoch reset and removal. Code review confirms publication after reactions/outcome/advancement and invalidation on partial failure. | PASS |
| Input/focus precedence and AC7.4 integration | [Inspection](test_battle_character_inspection.log): dispatched right-click/I/Escape/Tab, action-bar versus slot focus, target preservation, stale preview clearing, covered-slot traversal, exposed part of partially covered slot, panel click blocking, hidden debug-focus fallback, both panel opening orders during Attack/Swap. Three Escapes close information, drawer, action. [AC7.4 final](test_ac7_4_debug_drawer.log) and rendered overlap/wheel checks pass. | PASS |
| Lifecycle, modal ownership and regressions | [Inspection](test_battle_character_inspection.log): reset, removal, preparation, real victory, reward selection, recruitment placement/cancel, obsolete modal render. [Panel](test_battle_character_info_panel.log): close/reopen during animation and scroll cleanup. Existing Battle lifecycle/defeat/turn/default/passive tests, [world entry](test_world_battle_entry.log), [party formation](test_ac3_3_party_formation.log), [preparation UI](test_ac6_6_preparation_ui.log), project checks and live startup pass. | PASS |

Coverage: **5/5 contract groups PASS**, including fresh AC7.4 regression and coexistence evidence. Historical AC7.4 PASS was only the dependency baseline.

## Reproduction

Executable: `D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`.

```text
godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/Battle/test_battle_character_info_presenter.gd
godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/Battle/test_battle_character_info_panel.gd
godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/Battle/test_battle_character_inspection.gd
godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/Battle/test_ac7_4_debug_drawer.gd
godot.windows.opt.tools.64.exe --path . --rendering-method gl_compatibility --script res://Tests/Battle/capture_ac7_6_character_information.gd
```

Execute every `Tests/Battle/test_*.gd` plus `Tests/WorldMap/test_world_battle_entry.gd`, `Tests/Run/test_ac3_3_party_formation.gd` and `Tests/UI/test_ac6_6_preparation_ui.gd` with the same headless command. The harness used Python `subprocess.run`, captured stdout/stderr and enforced 60-second test/90-second rendered timeouts. Require exit zero, a passing result and no `SCRIPT ERROR` or `FAILED:`. Existing invalid-data fixtures intentionally emit `ERROR:` diagnostics; these were retained and inspected. Direct PowerShell GUI-executable invocation was replaced with subprocess waiting before baseline results were accepted.

The rendered runner uses deterministic Brakka/ally/enemy fixtures, actual viewport input, simultaneous effects, passive scrolling, both panels, Escape ordering and a passive-only roster. Initial capture-fixture mistakes (unsupported catalog ID and base speed 12) were corrected before the passing run; they were not product failures or accepted evidence.

## Inspected screenshots

| State | 1152x648 | 1024x648 | 1920x1080 | Observation |
|---|---|---|---|---|
| Skill tooltip/tiles | [capture](skills-1152.png) | [capture](skills-1024.png) | [capture](skills-1920.png) | Equal-width tiles; description above its anchor inside viewport; compact defaults at right. |
| Enemy inspection during Attack | [capture](input-overlap-1152.png) | [capture](input-overlap-1024.png) | [capture](input-overlap-1920.png) | Enemy HP/stats/Advantage explanation in left panel; Attack indicator retained. |
| Buffs/debuffs | [capture](character-effects-1152.png) | [capture](character-effects-1024.png) | [capture](character-effects-1920.png) | Effective speed/base/delta; armor separate from defense; long effect content scrolls within panel. |
| Passive description | [capture](character-passives-1152.png) | [capture](character-passives-1024.png) | [capture](character-passives-1920.png) | Banner Holder effect, targeting, requirements and usage readable after scroll; name/close fixed. |
| Both panels | [capture](drawer-info-overlap-1152.png) | [capture](drawer-info-overlap-1024.png) | [capture](drawer-info-overlap-1920.png) | Opaque panels coexist at opposite edges with reachable close controls and preserved battle target state. |
| Passive-only roster | [capture](passive-only-1152.png) | [capture](passive-only-1024.png) | [capture](passive-only-1920.png) | No skill tiles; defaults retained. Information starts at top after reset; passive text separately asserted by runner. |

## Decisions and limits

- Final dimensions: 160x88 logical pixels per active skill; 340 logical-pixel panel width capped to viewport; opening slide 0.18 seconds. Close hides immediately to stop input leakage and kills the tween.
- Arena owns committed cache and independent inspection ID. Presenter receives detached records. Renders are synchronous and four-token guarded, so there is no deferred data-render queue; tweens are cancelled on close/exit.
- Existing role presentation supplies Class/Role. No combat balance/class-model changes. Damage means base power, defense is flat physical reduction, armor is separate, and effect expiry retains real action/round/consumption semantics.
- Passives leave only action-bar presentation. Roster validation, reactions and save data remain intact. Historical AC2.6/AC2.7 tests changed only superseded presentation assertions.
- Arbitrary tiny windows, localization, assistive-technology speech and color-vision simulation were not verified. Panel overlays intentionally cover some battlefield area while open.
- `.gdignore` excludes these evidence artifacts from Godot import.

## Final runner logs

- [test_ac2_2_speed_order](test_ac2_2_speed_order.log)
- [test_ac2_3_damage_defeat_log](test_ac2_3_damage_defeat_log.log)
- [test_ac2_4_battle_results](test_ac2_4_battle_results.log)
- [test_ac2_5_reward_selection](test_ac2_5_reward_selection.log)
- [test_ac2_6_character_skills](test_ac2_6_character_skills.log)
- [test_ac2_7_skill_preview](test_ac2_7_skill_preview.log)
- [test_ac2_8_skill_arena](test_ac2_8_skill_arena.log)
- [test_ac2_8_skill_lifecycle](test_ac2_8_skill_lifecycle.log)
- [test_ac2_8_skill_scene](test_ac2_8_skill_scene.log)
- [test_ac2_8_skill_targeting](test_ac2_8_skill_targeting.log)
- [test_ac2_8_skill_transaction](test_ac2_8_skill_transaction.log)
- [test_ac2_9_combo_system](test_ac2_9_combo_system.log)
- [test_ac3_3_party_formation](test_ac3_3_party_formation.log)
- [test_ac3_4_default_actions](test_ac3_4_default_actions.log)
- [test_ac6_1_combat_foundation](test_ac6_1_combat_foundation.log)
- [test_ac6_2_keyword_reactions](test_ac6_2_keyword_reactions.log)
- [test_ac6_3_goblin_wave_a](test_ac6_3_goblin_wave_a.log)
- [test_ac6_4_goblin_wave_b](test_ac6_4_goblin_wave_b.log)
- [test_ac6_5_brakka](test_ac6_5_brakka.log)
- [test_ac6_6_battle_preparation](test_ac6_6_battle_preparation.log)
- [test_ac6_6_preparation_ui](test_ac6_6_preparation_ui.log)
- [test_ac7_1_living_lanes](test_ac7_1_living_lanes.log)
- [test_ac7_2_turn_order_ribbon](test_ac7_2_turn_order_ribbon.log)
- [test_ac7_3_unified_action_bar](test_ac7_3_unified_action_bar.log)
- [test_ac7_4_debug_drawer](test_ac7_4_debug_drawer.log)
- [test_ac7_5_battle_visual_states](test_ac7_5_battle_visual_states.log)
- [test_active_turn_skill_lock](test_active_turn_skill_lock.log)
- [test_battle_character_info_panel](test_battle_character_info_panel.log)
- [test_battle_character_info_presenter](test_battle_character_info_presenter.log)
- [test_battle_character_inspection](test_battle_character_inspection.log)
- [test_world_battle_entry](test_world_battle_entry.log)
