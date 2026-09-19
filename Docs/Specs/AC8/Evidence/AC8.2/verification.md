# AC8.2 verification — 2026-09-19

Result: PASS for battle gold settlement and durable terminal defeat. Branch: `feat/ac8-2-battle-gold-and-terminal-defeat`; base: AC8.1 `c644778`. This record covers implemented behavior, not only plan review.

## Implemented contract

- Victory atomically commits 50g per distinct defeated enemy, recovery, encounter completion and one canonical battle receipt. Defeat commits zero reward and a lost lifecycle record. Revived enemies count once; commander identities use the same rules.
- Canonical receipt validation, immutable snapshots and battle/session generation checks reject conflicting or stale results. Identical events and retries do not pay twice.
- V4 explicitly validates lifecycle fields and receipts. V2/V3 readers normalize legacy active states; malformed V4 never falls back. A valid lost slot is inspectable, but playable loading returns RUN_LOST without a session.
- Failed terminal writes preserve candidate bytes and block mutation, discard, replacement and launcher return. Retry success publishes once and disables Continue. Direct launcher/controller calls are guarded as well as UI actions.
- Fresh runs persist full starter health and 100g. Boss victory receipts prevent reactivation/rematch on reload. Existing optional victory choices remain until AC8.3 and unlock only after settlement.

## Automated evidence

All 27 `test_*.log` files in this directory contain passing executions (exit 0, PASS output, no script/runtime ERROR). They cover economy, identity, pure settlement, run-state validation, V4 and legacy codecs, real victory/loss controller flows, save coordinator, launcher/start service, recovery, existing battle rewards, recruitment, world runtime and AC8.1 regression behavior.

Reproduce any suite from the repository root:

```powershell
& 'D:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --quit-after 1800 --script res://Tests/WorldMap/test_ac8_2_defeat_ends_run.gd
```

Each log records its exact script path and command. An exit code alone is insufficient: require PASS and inspect stderr for script errors.

Run `res://Tests/Run/test_ac8_2_terminal_launcher.gd` with `-- writer`, then in a separate process with `-- reader`. The two terminal-launcher logs confirm real-file failed-save/keyboard-Retry behavior, restart rejection, no early replacement, and a fresh playable 100g run. They use only `user://ac82-terminal-launcher-test.json`. The final direct launcher-return bypass test failed before its guard and passed after the fix.

## Rendered and editor evidence

Rendered writer/reader runs used `--rendering-method gl_compatibility` and `-- writer capture` / `-- reader capture`; logs are retained. The following 1920x1080 images were visually inspected:

- [Failed terminal save](terminal-save-failure-retry-only.png): defeated roster behind a blocking overlay; Retry Save and Copy Details; no Return action.
- [Returned launcher](terminal-menu-continue-disabled.png): Continue disabled after the durable loss.
- [Published victory wallet](victory-published-wallet-150g.png): world HUD shows 150g after one defeated enemy and settlement.

GodotIQ production main-scene smoke check: runtime attached, verify_project_runs PASS, empty debug console, launcher MAIN state observed, then stopped. Final project parser check: 198 scripts, zero errors. Project convention validation: zero errors, 31 warnings and 5 informational findings; these are not claimed as a warning-free gate. Scoped controller/arena signal checks reported no orphan or missing connections. Independent static implementation review and final-delta review both passed.

## Limits and follow-up

The restart guarantee begins after a successful atomic terminal write. If all writes fail and the process is forcibly killed before Retry succeeds, the prior active checkpoint can remain; this is the explicitly approved durability boundary, without a pre-battle journal.

AC8.3 reward presentation and durable acknowledgement are deferred. Reload after committed victory resumes the settled checkpoint without reopening legacy choices. No new campaign-completion screen is introduced. This verification does not claim a full-project exhaustive suite or resolution of the previously documented migrated-preview-flow stall.
