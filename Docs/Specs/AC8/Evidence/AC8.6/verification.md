# AC8.6 verification — 2026-09-20

**Verdict: PASS for base AC8.6. Separately, PASS for the user-requested standalone dismissal extension under D1.** Implemented on `feat/ac8-6-roster-eligibility`, based on `776c0ef`: `dfc8c2d` (roster), `a8538c0` (dismissal UI), `06da651` (transaction and eligibility), `540c0f9` (modal input isolation). The final evidence commit also contains the rendered runner and an additional all-town reload assertion.

The [implementation plan](../../../../superpowers/plans/2026-09-20-ac8-6-whole-roster-eligibility.md#d1--minimum-one-memberno-refund-policy-single-source-of-truth) remains the single source of truth for D1. Standalone dismissal controls, confirmation and the minimum-party/no-refund policy are a user-requested extension; they are not added to the base AC8.6 definition.

## Base AC8.6 acceptance

| Requirement | Evidence |
|---|---|
| Whole roster and canonical class identity | [40-check roster suite](gate-test_ac8_6_roster_eligibility.log): starter aliases, sparse slots, duplicate canonical classes with different IDs, pure queries and all-six empty eligibility |
| Passed-out members remain excluded | Roster suite plus [52-assertion recovery integration](gate-test_ac3_5_recovery_integration.log): actual battle unit at 0 HP retains roster membership, victory recovery, town browsing and Continue. World saves retain their existing positive-HP requirement |
| Refresh after recruitment/replacement/removal | [Town integration](all-town-gate-test_ac8_town_recruitment.log): actual panel rebuilds, replacement releases the old class, final representative removal enables exactly that class |
| Empty offers and stale requests | Town suite plus [37-assertion panel suite](gate-test_ac8_5_town_recruitment_panel.log): real six-class roster, reopen, no buttons/fallback, direct present-class rejection, stale add/replacement confirmation, obsolete button emission blocked |
| Reload | [Eight separate processes](restart-results.json): independent writers/readers for dismissal, replacement, empty roster eligibility and duplicate-class identity; exact state, ordered offers and zero browsing writes |
| Every legacy town | All-town integration verifies exact filtered offers at all seven towns before and after V5 Continue, canonical plan bytes unchanged and zero browsing writes. Combined with [ownership prerequisite evidence](../AC8.4/verification.md), this completes current-v1 AC8.4 |

The stale-class-confirmation test deliberately changes a roster between selection and confirmation to exercise adversarial revalidation. It is labelled as a fixture, not a new concurrent gameplay path. The recovery test resumes the recovered roster at a town fixture; it does not claim to verify navigation between the battle and that town.

## User-requested dismissal extension acceptance

- D1 rejects the final member in the domain and disables its UI action with the exact explanation. Dismissal changes only the selected formation slot and removed HP entry; gold, other members, coordinates, moves, boss/cache state and battle records remain unchanged.
- Confirmation captures the slot and character ID. Cancel/Escape, close, refresh and reconfiguration invalidate it. Repeated confirmation, moved/stale targets and old panel/session signals cannot remove another member.
- Normal party management is required. Battle, encounter, reward, terminal, placement/replacement and blocked-save contexts reject the action without writes.
- Failed writes preserve the live roster and durable state. Retry publishes once using identical candidate bytes and retains the modal movement lock. Discard preserves old eligibility and closes the abandoned panel.
- [Dismissal UI suite](gate-test_ac8_6_party_dismissal.log), town integration, independent dismissal restart and rendered input checks verify these extension obligations separately from base offer filtering.

## Automated gate and reproduction

[Gate results](gate-results.json) and [regression results](regression-results.json) contain **23 distinct passing suites**. Ten baseline suites passed before changes. Each final log includes exact command, process exit 0, explicit PASS and no script/runtime ERROR. The final expanded town suite passed again in [all-town results](all-town-gate-results.json).

From repository root:

```powershell
python Docs/Specs/AC8/Evidence/AC8.6/run_gate.py --prefix gate Run/test_ac8_6_roster_eligibility UI/test_ac8_6_party_dismissal WorldMap/test_ac8_town_recruitment UI/test_ac8_5_town_recruitment_panel WorldMap/test_ac3_5_recovery_integration UI/test_ac3_3_party_management UI/test_world_map_hud WorldMap/test_world_runtime_scene WorldMap/test_ac8_1_gold_runtime WorldMap/test_ac8_2_defeat_ends_run WorldMap/test_scout_recruitment_flow
python Docs/Specs/AC8/Evidence/AC8.6/run_gate.py --prefix regression Run/test_ac8_5_recruitment_rules Run/test_ac3_1_run_roster Run/test_ac3_3_party_formation Run/test_ac3_5_post_battle_recovery WorldMap/test_world_runtime_save_coordinator Save/test_world_run_save_codec_v5 WorldMap/test_ac8_4_town_ownership_reload WorldMap/test_ac8_4_world_debug_integration WorldMap/test_ac8_3_reward_presentation WorldMap/test_cleared_battle_hex_revisit WorldMap/test_world_production_scene Save/test_goblin_starter_save_migration
python Docs/Specs/AC8/Evidence/AC8.6/run_rendered.py 1280 1920
```

Restart commands are recorded in each `restart-<case>-<mode>.log`. Run the engine with `--headless --path . --script res://Tests/Run/test_ac8_6_eligibility_restart.gd -- --mode=writer --case=dismissal`, then start another process with `--mode=reader`. Repeat for `replacement`, `empty`, and `duplicate`. These use only `user://ac8-6-eligibility-<case>.json`; the normal active-run slot is untouched.

Red/green evidence: [missing removal API](roster-red.log), [missing production dismissal API](dismissal-red-test_ac8_town_recruitment.log), [missing dismissal UI API](ui-red-test_ac8_6_party_dismissal.log), [obsolete offer button](stale-button-red-test_ac8_5_town_recruitment_panel.log), and [modal input leak](ui-input-red-test_ac8_6_party_dismissal.log). Their final gates pass. Existing filtering tests passed as characterization evidence; no artificial implementation change was introduced to force them red.

The intermediate `dismissal-diagnosis` failure exposed a test assumption: the production starter formation includes Brakka at slot 1. The test now uses the authoritative slot ID rather than assuming `player_1`. This was a fixture correction, not a changed starter policy.

## Rendered production input and inspected captures

[1280x720](rendered-1280.log) and [1920x1080](rendered-1920.log) both PASS using the real production launcher and disposable saves. Actual pointer/keyboard events exercise Continue, Manage Party, slot selection, Dismiss, confirmation cancellation with Escape, pointer confirmation, returning to recruitment, drag placement, replacement and fresh-launcher Continue. Dismissal preserves 1500g; repurchase/replacement deducts exactly 500g. Keyboard and wheel input leave camera position/zoom unchanged behind the party overlay.

All 16 captures were inspected at both sizes:

| State | Observations | Captures |
|---|---|---|
| Selected member | Six slots, selected details, three skills and Dismiss readable | [1280](rendered-selected-1280.png), [1920](rendered-selected-1920.png) |
| Confirmation | Centered name/no-refund message, Dismiss and Cancel visible; Cancel has initial focus | [1280](rendered-confirmation-1280.png), [1920](rendered-confirmation-1920.png) |
| Final member | Disabled Dismiss and exact minimum-one explanation visible | [1280](rendered-last-member-1280.png), [1920](rendered-last-member-1920.png) |
| Initial empty | Actual six-class roster, clear empty message, Close usable | [1280](rendered-empty-1280.png), [1920](rendered-empty-1920.png) |
| Returned offer | Only Scrapbroker offered for 500g; wallet still 1500g | [1280](rendered-returned-offer-1280.png), [1920](rendered-returned-offer-1920.png) |
| Repurchased empty | Zero offers after actual purchase; wallet 1000g | [1280](rendered-repurchased-empty-1280.png), [1920](rendered-repurchased-empty-1920.png) |
| Continued empty | Same empty state and balance after fresh launcher Continue | [1280](rendered-continued-empty-1280.png), [1920](rendered-continued-empty-1920.png) |
| Replacement | Only released Wirefang class offered for 500g; wallet 1000g | [1280](rendered-replacement-1280.png), [1920](rendered-replacement-1920.png) |

No clipping was observed. Rendered QA found a real keyboard/wheel camera leak; early party input handling and regression probes fixed it in `540c0f9`. Initial capture-harness corrections used the actual `ManagePartyButton` name and root viewport routing for embedded dialogs; directly injecting into the child Window bypassed its window-input handling. Final tests exercise root input routing rather than emitting confirmation signals.

## GodotIQ and review

- Main-scene `run(play)` and `verify_project_runs(check_scope="project")`: PASS; final console has zero script/runtime errors.
- Bridge smoke used the isolated restart save: real input through `root.push_input` performed Continue, Manage Party, member selection, Dismiss and Escape. The dialog closed while party remained open; gold stayed 1500, formation was unchanged, moves stayed 0, `_dismissal_pending` was false. Game stopped after QA.
- One bridge `input(click_at)` timed out after 65 seconds, and initial `tap` used logical coordinates against a stretched 1920x1080 window. Restarting the bridge and using the game's viewport input pipeline completed the smoke checks. No domain action was substituted for UI input.
- `explore(mode="tour", max_areas=1)` inspected the live Wirefang dismissal dialog: centered readable wording, visible Cancel focus, selected roster slot and skill details. This is 2D UI evidence, not a claim about 3D placement.
- Baseline project validation: 225 scripts/22 scenes, 0 errors, 35 warnings, 5 informational findings. Final: 229 scripts/22 scenes, 0 errors, 36 warnings, 5 informational findings. The added warning is the standalone roster runner's missing `class_name`, consistent with existing runner style. Project parser check: 229 scripts, 0 errors.
- Controller and party scoped signal maps have no orphans. The static missing-definition scan flags `Button.pressed` because it is a built-in signal; input tests exercise it successfully.
- Independent spec and quality reviews approved roster, dismissal UI and integration. Follow-up review approved the modal fix and all 16 captures. A minor initial Shift+Tab/no-focus ordering edge is nonblocking; normal focus cycling and activation pass.

## Acceptance limits

AC8.7 and AC8.8 remain unchecked pending their complete matrices; targeted transaction checks here do not confer their acceptance. Generated ownership and burned/hostile-town service behavior remain AC9/AC10. No new save format, economy policy, commander restriction, refund behavior or broader party-management redesign was introduced. The branch remains local; push/merge was not requested.
