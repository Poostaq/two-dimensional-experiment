# AC3.1 recruitment placement amendment

AC3.3 changes the final recruitment step from automatic append to an explicit placement transaction:

- BattleArena owns the pending recruit until the player chooses Place.
- MapController then owns the suspended placement while the party-management overlay is open.
- Cancel returns the recruit to BattleArena and leaves RunRoster unchanged.
- Selecting an empty formation slot commits through `RunRoster.try_add_at()` and only then completes the reward flow.
- A following battle preserves the chosen formation slot exactly.

Verification: `Tests/Map/test_ac3_1_recruitment_integration.gd` PASS (7/7), `Tests/Map/test_ac3_3_party_management_integration.gd` PASS (12/12), and `Tests/Battle/test_ac2_5_reward_selection.gd` PASS (17/17).
