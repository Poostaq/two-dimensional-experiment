# AC3.1 Manual Runtime Check

- Verification date: 2026-08-13
- Implementation commit: `5fe7f16a1e653ccdb7992496b286ce20e72cf4f1`
- Runtime: Godot 4.7.1.stable.steam.a13da4feb with the GodotIQ bridge attached.
- Initial roster in first fight: PASS — live battle state contained `player_0`, `player_1`, and `player_2` in starter order.
- Eligible Combat reward: PASS — after a Combat victory below capacity, the live reward UI exposed Recruit Scout, 100 Money, and Supply Cache.
- Recruitment confirmation: PASS — GodotIQ selected Recruit Scout and Confirm Reward through the real reward UI; the battle closed and the run roster became `player_0`, `player_1`, `player_2`, `scout`.
- Next-fight verification: PASS — the next live Combat battle contained `player_0`, `player_1`, `player_2`, and `scout` in player slots 0, 1, 2, and 3.
- Fresh battle state: PASS — all four next-fight player units were distinct fresh battle states at `20/20` HP with no stale reward screen.
- Duplicate filtering: PASS — after Scout was owned, the next Combat victory exposed only 100 Money and Supply Cache; Recruit Scout was absent and both remaining options were enabled.
- Full-roster filtering: PASS — a live six-character runtime fixture reached another Combat victory and exposed only 100 Money and Supply Cache; recruitment was absent and both remaining options were enabled.
- Runtime health: PASS — final GodotIQ debugger capture contained 0 runtime errors and 0 script errors.
- Scope boundary: PASS — no on-map roster UI, party-management UI, or dismissal flow was added.

Overall: PASS

## Interaction method

GodotIQ `ui_map` does not enumerate the map's Node2D hex tiles, and direct viewport-click dispatch to a live tile center did not mutate map state. That limitation belongs to mouse-map navigation coverage under AC1.3, not to AC3.1's recruitment behavior. For this AC3.1 run, GodotIQ invoked `MapController.request_move()`, the production public movement boundary, only to enter the required seeded Combat encounters. From the encounter overlay onward, GodotIQ used real UI input for Enter Battle, debug combat actions, reward selection, confirmation, and subsequent battle entry. Runtime state was observed through the attached live scene after each interaction.

The full-roster case added two valid runtime-only characters through the existing `RunRoster.try_add()` domain boundary to reach capacity six. No production file, scene, save data, or persistent fixture was modified.
