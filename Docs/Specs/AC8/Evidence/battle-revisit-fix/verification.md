# Cleared battle hex revisit regression

Verified 2026-09-20 on `fix/cleared-battle-hex-revisit`.

## Root cause and fix

An ordinary victory persisted a settlement receipt, but WorldRuntimeModel restored only boss victory state. Returning to an ordinary defeated combat hex still produced a combat encounter. The replay then reached duplicate/conflicting settlement handling, which could not create a new reward and left the production arena locked.

The runtime model now derives defeated combat coordinates from durable victory receipts, retains them in movement candidate copies, and clears them on reset. Those coordinates resolve as safe unless the active boss occupies them. The controller rejects battle requests whose encounter type no longer matches the authoritative runtime model, including stale requests for cleared combat. No reward amounts, save schema, debug-exit authority or settlement idempotency rules changed.

Victory receipts are used deliberately: the existing consumed-encounter list also includes encounters closed without fighting. Closing an unfinished encounter must not count as winning it.

## Evidence

- `revisit-red.log`: the new reproduction failed on all six expected replay/restore assertions before the production fix.
- `test_cleared_battle_hex_revisit.log`: passes after the fix. Exercises actual battle completion and reward acknowledgement, movement away/back, safe overlay, stale battle request rejection, no duplicate gold, codec reload, model copies/reset, and unfinished encounter preservation.
- `results.json`: 17 successful targeted executions covering the new regression, reward presentation, victory/defeat settlement, runtime model/save coordinator, world debug integration, production launcher, settlement rules, preparation logic/UI, and six combat/boss writer/reader/acknowledged-reader restart modes.
- The restart runner was initially invoked without its required arguments; that invocation failure is retained in `test_ac8_3_reward_restart.log`. Its six correctly parameterized executions all pass.
- `godotiq.json`: main-scene Play passes, all 218 scripts compile, and convention counts remain at the baseline 0 errors / 33 warnings / 5 informational findings. Controller signal inspection has no missing or orphan connections. The final runtime console is empty. An old SkillEffectPlan console entry predating this reproduction was cleared by the Play verifier and did not recur.

Live QA used disposable slot `user://battle-revisit-fix-qa.json` and seed `world-debug-qa`. At `(-7, 0)`, three actual enemy defeats yielded 150 gold and the reward panel. After acknowledgement, movement back to `(-8, 0)` and return to `(-7, 0)` produced base encounter combat / effective encounter safe / safe overlay, gold 250, no active battle and no integration failure. Enemy HP was reduced in the disposable QA fixture to make the battle short. The normal save slot was not changed.

Existing saves already contain victory receipts, so the fix takes effect when Continue restores them. An already-running frozen arena needs a game restart to load the corrected code and durable state.
