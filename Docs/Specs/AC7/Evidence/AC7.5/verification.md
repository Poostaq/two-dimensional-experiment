# AC7.5 battle visual-state verification

Verified 2026-09-18 on `feature/ac7-5-battle-visual-states`. Implementation: `4625596`.
AC7.4 implementation `57429e0` and evidence `8e3410b` were verified and fast-forwarded into local main before this task branch was created. Main was fetched and updated from origin first; no worktrees or remote push were used.

Godot `4.7.2.stable.steam.ed1daf0bf`; Windows, OpenGL compatibility, NVIDIA RTX 3080. Rendered fixtures use 1152x648 and 1024x648.

## Results

- All 25 `Tests/Battle/test_*.gd` runners plus party formation, world battle entry and preparation UI passed: 28 runners. Final AC7.5, AC7.4 and world-entry checks passed again after exit cleanup; AC7.2 and AC7.5 passed after preview-label composition changes.
- [Rendered input runner](rendered-qa.log): PASS at both sizes. Uses viewport pointer events, Tab/Shift+Tab, Enter and Space; direct fixture setup is used for cooldown, defeat and ribbon/selection overlap. All 24 captures listed below were inspected.
- GodotIQ final project scan: 169 scripts, 18 scenes, zero errors; unchanged baseline 27 warnings and 6 informational findings. `check_errors(scope="project")`: zero errors. No orphan signals. Native UI signals emitted in tests appear as scanner-only missing definitions.
- Main scene and battle scene `verify_project_runs`: PASS, empty captured debug console. The battle tour showed the lane layout, action bar and independent NOW frame. The game was stopped after verification.
- Read-only implementation review: PASS after correcting zero-target affected-unit presentation, blocked-phase explanations, visible keyboard focus, and retained read-only completion details. Final visual inspection also corrected duplicate preview text and separated the ribbon preview label from selection.
- `git diff --check` passed before committing. No combat-rule, effect resolver, turn-queue, save-data or reward modules changed.

## Reproduction

Executable: `D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`.

```text
godot.windows.opt.tools.64.exe --headless --path . --script res://<runner path>
godot.windows.opt.tools.64.exe --path . --rendering-method gl_compatibility --script res://Tests/Battle/capture_ac7_5_battle_visual_states.gd
```

The harness uses Python `subprocess.run` with captured stdout/stderr and a 60-second timeout per runner. It requires exit zero and no `SCRIPT ERROR` or `FAILED:`. Existing negative-data tests deliberately emit `ERROR:` for invalid CharacterSkill, BattleUnitState, combo, keyword, reaction and effect-plan construction; those diagnostics were inspected and retained in their logs. A PASS line alone is not sufficient to ignore script errors.

## Acceptance mapping

| Contract | Evidence |
|---|---|
| Deterministic independent actor, spotlight, target and selected layers | AC7.5 resolver matrix: empty/active/defeated, all three action kinds, overlap, invalidated selection, fresh results and immutable inputs |
| Observation does not change combat | AC7.5 snapshots compare HP, armor, speed, cooldowns, queue, current actor, round, revision, history, default preview, selected skill and full transaction across pointer/focus and repeated refresh |
| Legal availability and no-target reasons | FREE empty target set, cooldown priority, authored zero-target Slipstep, mixed-side missing stage and complete stage; existing confirmation validator determines legal completion without applying effects |
| Self effects without invented selection | Accepted detached plan supplies affected actor; explicit transaction target IDs remain empty; self frame and valid border coexist |
| Selection stability and default actions | Hovering another skill preserves selected IDs/transaction; Attack and Swap have distinct labels/glyphs; invalid activation is guarded; multi-target input retains both selected units |
| Input arbitration and accessibility | Late A exit cannot erase B; pointer wins over focus; last source leaving clears preview; occupied cards have FOCUS, empty cards leave traversal; disabled defaults remain focusable with explanations; actual keyboard target selection and no-target Enter checks |
| Cleanup | AC7.5 covers cancel, successful confirmation, turn, cooldown, defeat, removal, same-ID reset/deferred tooltip, preparation, terminal completion and exit; AC2.8 lifecycle, AC7.2 relocation, AC7.3 and AC7.4 regressions retain their existing checks |
| Drawer and history coexistence | AC7.4 regression passes; opening clears obscured hover while retaining committed action; legacy actor/log/effect feedback continues alongside resolved semantic overlays |
| Completed-phase information | Real terminal battle retains final inspected skills, clears selected/default/transaction state, reveals blocked explanations on fresh input and refuses activation |

## Inspected screenshots

Each row links the same state at both supported sizes. The retained outer NOW frame, weaker preview, thicker selected border, check marker, action label and independent focus text remain distinguishable. Tooltip panels stay inside the viewport. The compact default NO TARGET badge is supported by the full-size reason readout on focus.

| State | 1152x648 | 1024x648 | Observation |
|---|---|---|---|
| Enemy skill preview | [hover](hover-1152.png) | [hover](hover-1024.png) | Legal enemies only; no selected markers. |
| Committed selection | [selected](selected-1152.png) | [selected](selected-1024.png) | Rally details do not replace Quick Strike selection. |
| Ribbon with selected target | [ribbon-selected](ribbon-selected-1152.png) | [ribbon-selected](ribbon-selected-1024.png) | PREVIEW label and cyan outline coexist with selected border/check. |
| Default Attack | [attack](attack-1152.png) | [attack](attack-1024.png) | Sword, ATTACK and selected treatment. |
| Default Swap | [swap](swap-1152.png) | [swap](swap-1024.png) | Arrows, SWAP and adjacent allied candidates. |
| Same-ID reset | [reset](reset-1152.png) | [reset](reset-1024.png) | Only authoritative actor frame remains. |
| Zero-target self effect | [self](self-1152.png) | [self](self-1024.png) | NOW and valid affected-self border; no fabricated selected target. |
| Idle keyboard focus | [focus](focus-1152.png) | [focus](focus-1024.png) | FOCUS remains distinct from selection. |
| No legal targets | [no-target](no-target-1152.png) | [no-target](no-target-1024.png) | Inspectable NO TARGET actions; Slipstep remains usable. |
| Cooldown and defeat | [unavailable](unavailable-1152.png) | [unavailable](unavailable-1024.png) | Cooldown reason is readable; defeated identity remains without target border. |
| Allied predefined preview | [allies](allies-1152.png) | [allies](allies-1024.png) | Rally previews allies including actor. |
| Multiple selected targets | [multi](multi-1152.png) | [multi](multi-1024.png) | Both Ring Net selections remain visible; keyboard focus identifies the second. |

## Implementation decisions and limits

- The resolver's input class is named `Request` because `Input` conflicts with Godot's native class. Existing tooltip generations, source identity guards and a phase context token provide invalidation; no new global UI state owner was introduced.
- The approved task commits were consolidated into one implementation commit and one evidence commit. Existing authored skill-button labels were reused; the action-bar and unit-view scenes gained only presentation controls.
- The terminal-only expectation in `test_active_turn_skill_lock.gd` was intentionally updated: no-current-unit still shows a neutral prompt; completed battles retain read-only information with actions blocked. Active-turn ownership checks remain unchanged.
- Automated and rendered checks cover the current bounded formations and authored skills. Screen-reader speech, color-vision simulation, localization and arbitrary viewport sizes were not tested. Accessibility names/descriptions, text/glyph cues, focus and activation behavior were checked.
- Evidence artifacts are excluded from Godot import by this directory's `.gdignore`. The original planning stash remains as a backup; its relevant planning files were restored into their respective task commits.

## Runner logs

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
- [test_world_battle_entry](test_world_battle_entry.log)
