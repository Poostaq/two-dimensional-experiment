# Harpy Classes

## Reading the Skill Records

All skills inherit shared mechanics and the Exposed/Isolated definitions in `Lore.md`. `CD N` is post-use cooldown in successful owning-side actions. Unstated duration, stacks, reapplication, movement, and Advantage are `None`; cleanup is battle end; every movement row names range/path semantics; invalid previews reject atomically; UI cells contain exact tooltip and log text.

## Class 1: Talon Duelist

**Role:** Mobile pressure striker. **Rhythm:** Pass through the ring, exploit a moved enemy, retreat. **Weakness:** No protection during cooldown. **Stats:** 14 Health, 8 Power, 10 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Raking Pass | Active Opener; mobility/offense; self Move 2 then enemy neighboring destination; CD 1 | Rotate self along chosen ring path up to 2, then deal 90% Power; position after move | Reject path/post-move target; AI changes unsafe neighbors; counter movement lock | Tooltip: `Move up to 2, then deal 90% Power to a new neighbor.` Log: `<actor> raked past <target> for <damage> via <path>.` |
| Exploit Opening | Active Converter; offense; enemy forcibly moved this round; CD 2 | Deal 150% Power; Advantage rider 180%; no duration/stack | Reject no hostile movement; AI targets low HP; counter Guard/prevent movement | Tooltip: `Deal 150% Power to an enemy forcibly moved this round.` Log: `<actor> exploited <target>'s opening for <damage>.` |
| Wingbeat Retreat | Active Pivot; mobility/defense; self Move 2; CD 3 | Rotate self up to 2; +2 Defense until next action, refresh/no stack | Reject path; AI exits contact; counter pursuit/Poison | Tooltip: `Move up to 2 and gain 2 Defense until your next action.` Log: `<actor> retreated to <slot> and gained 2 Defense.` |
| Never Land Twice | Passive Signature; mobility; first action each round ending in different slot | +1 Power next action; once/round; Aggressive +2, Protective +1 Defense too | Same slot/no move, no trigger; AI alternates legal positions; counter movement lock | Tooltip: `Once per round after ending in a new slot, gain 1 Power next action.` Log: `<actor> never landed twice and gained <bonus> Power.` |

## Class 2: Storm Siren

**Role:** Formation controller. **Rhythm:** Start a rotation, deepen it, reshape an entire engagement. **Weakness:** Low damage and path dependence. **Stats:** 17 Health, 6 Power, 8 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Gust Call | Active Opener; control; one enemy; CD 1 | Rotate target Move 1 on selected legal ring path; mark Exposed until next eligible action, refresh/no stack | Reject path; AI changes valuable neighbors; counter movement lock | Tooltip: `Move an enemy 1 and Expose it until its next action.` Log: `<actor> gusted <target> 1 along <path>; Exposed.` |
| Crosswind Pull | Active Converter; control/offense; Exposed enemy; CD 3 | Rotate target Move 2; deal 80% Power after movement; refresh Exposed | Reject no Exposed/path; AI aligns ally contact; counter movement lock/Cleanse effect | Tooltip: `Move an Exposed enemy up to 2, then deal 80% Power.` Log: `<actor> pulled <target> along <path> for <damage>.` |
| Eye of the Storm | Active Pivot; control/capstone; one enemy; CD 5 | Rotate target Move 3 along chosen direction; apply Exposed through next action; no damage | Reject path; AI chooses larger adjacency disruption; counter movement immunity | Tooltip: `Move an enemy 3 along either chosen ring path and Expose it.` Log: `<actor> sent <target> through the Eye along <path>.` |
| Voices in the Gale | Passive Signature; setup; first enemy moved 2+ by Siren each round | Grant chosen ally Advantage; once/round; Aggressive target -1 Defense next hit, Protective ally +1 Defense | No eligible ally/move, no trigger; AI picks rider; counter control recipient | Tooltip: `Once per round after moving an enemy 2 or more, grant an ally Advantage.` Log: `<actor>'s gale granted <ally> Advantage.` |

## Class 3: Gale Scout

**Role:** Exposure spotter. **Rhythm:** Move a target, signal an ally, relocate that ally. **Weakness:** Lowest Harpy Health. **Stats:** 12 Health, 6 Power, 10 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Spot the Straggler | Active Opener; movement/setup; enemy and ally; CD 1 | Rotate enemy Move 1; on success mark Exposed and grant chosen eligible ally Advantage | Reject path/ally; AI chooses ally able to target; counter movement lock/control ally | Tooltip: `Move an enemy 1, Expose it, and grant an eligible ally Advantage.` Log: `<actor> spotted <target>; <ally> gained Advantage.` |
| Diving Signal | Active Converter; offense; Exposed enemy; CD 2 | Deal 110% Power and consume Exposed; Advantage rider deals 150% and does not consume Exposed until after damage | Reject no Exposed; AI uses with token/low HP; counter Guard | Tooltip: `Deal 110% Power to Exposed; with Advantage, deal 150%.` Log: `<actor> signaled a dive on <target> for <damage>.` |
| Updraft Reposition | Active Pivot; mobility/support; one ally; CD 3 | Rotate ally up to Move 2 on chosen path; ally +1 Speed current round, queue rebuild | Reject path/inactive; AI improves legal targeting; counter movement lock | Tooltip: `Move an ally up to 2 and grant 1 Speed this round.` Log: `<actor> lifted <ally> to <slot> along <path>.` |
| Clear Sightline | Passive Signature; setup; first successful hostile movement each round | Exposed target remains through one extra eligible action, max 2; once/round; Aggressive ally rider +1 Power, Protective Scout +1 Defense | No hostile move, no trigger; AI moves high-value target; counter Cleanse effect | Tooltip: `Once per round, your first Exposed target lasts one extra action.` Log: `<actor> maintained a clear sightline on <target>.` |

## Class 4: Skyhook Raider

**Role:** Target extractor. **Rhythm:** Separate prior neighbors, punish isolation, perform one full-ring extraction. **Weakness:** Long Pivot cooldown. **Stats:** 18 Health, 7 Power, 8 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Hook and Lift | Active Opener; control; one enemy; CD 2 | Rotate target Move 2; apply Isolated until next eligible action, refresh/no stack | Reject path; AI breaks Guard/adjacency; counter movement lock | Tooltip: `Move an enemy 2 and Isolate it until its next action.` Log: `<actor> hooked <target> along <path>; Isolated.` |
| Drop Out of Line | Active Converter; offense; Isolated enemy; CD 2 | Deal 160% Power and consume Isolated after damage; Advantage rider 190% | Reject no Isolated; AI seeks lethal; counter Guard/Cleanse effect | Tooltip: `Deal 160% Power to an Isolated enemy and consume Isolated.` Log: `<actor> dropped <target> out of line for <damage>.` |
| Snatch Away | Active Pivot; control/capstone; one enemy; CD 5 | Rotate target Move 3 on chosen equal path; apply Isolated and Exposed until next action | Reject path; AI selects path disrupting more valuable neighbors; counter movement immunity | Tooltip: `Move an enemy 3 on either ring path; apply Isolated and Exposed.` Log: `<actor> snatched <target> along <path>.` |
| Isolated Prey | Passive Signature; offense; first allied direct hit on Raider-Isolated target each round | Hit ignores 1 Defense; once/round; Aggressive ignore 2, Protective Raider gains shield 2 | No isolated target/hit, no trigger; AI coordinates striker; counter remove effect/Guard | Tooltip: `Once per round, the first allied hit on your Isolated target ignores 1 Defense.` Log: `<actor>'s Isolated Prey ignored <amount> Defense for <ally>.` |

## Class 5: Nestguard

**Role:** Rescue mobility and protection. **Rhythm:** Cover a neighbor, weaken attackers, extract an ally. **Weakness:** Limited threat. **Stats:** 20 Health, 5 Power, 7 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Covering Wings | Active Opener; Guard/support; ring-neighbor ally; CD 1 | Guard ally and give shield 2 until direct hit or round end; refresh/no stack | Reject no neighbor/equal effect; AI protects fragile; counter area/status | Tooltip: `Guard a neighboring ally and shield it for 2 until round end.` Log: `<actor> covered <ally> with its wings.` |
| Warning Screech | Active Converter; debuff; enemy that targeted guarded ally this round; CD 2 | Deal 70% Power; target -2 Power through next action, refresh/no stack | Reject no qualifying attacker; AI weakens imminent actor; counter Cleanse | Tooltip: `Deal 70% Power and reduce by 2 the Power of an enemy threatening your ward.` Log: `<actor> screeched at <target> for <damage>; Power -2.` |
| Rescue Flight | Active Pivot; mobility/support; any ally; CD 4 | Explicitly swap Nestguard and ally; ally retains shield and gains +1 Defense until next action | Reject slots/changed preview/movement lock; AI rescues threatened; counter lock/area pressure | Tooltip: `Swap with any ally; it gains 1 Defense until its next action.` Log: `<actor> rescued <ally> by swapping slots.` |
| Guard from Above | Passive Signature; defense; first ally moved into a slot neighboring Nestguard each round | Ally shield 2 until round end; once/round; Aggressive ally +1 Power, Protective shield 3 | No moved neighbor, no trigger; AI receives rotations; counter attack Nestguard first | Tooltip: `Once per round, shield an ally moved beside you for 2.` Log: `<actor> guarded <ally> from above.` |

## Class 6: Carrion Cantor

**Role:** Physical pressure support. **Rhythm:** Cut with sound, apply the race's narrow Bleed branch, spiral through weakened enemies. **Weakness:** Bleed Cleanse and low Defense. **Stats:** 16 Health, 7 Power, 9 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Cutting Note | Active Opener; offense/debuff; one enemy; CD 1 | Deal 90% Power; target -1 Defense until round end, one/source refresh | Reject inactive/equal debuff; AI opens high Defense; counter Cleanse/Guard | Tooltip: `Deal 90% Power and reduce Defense by 1 until round end.` Log: `<actor>'s Cutting Note hit <target> for <damage>.` |
| Rending Chorus | Active Converter; offense/Bleed; enemy with reduced Defense; CD 2 | Deal 110% Power and apply 1 Bleed for 2 target actions, max 3/refresh canon | Reject no Defense reduction; AI applies to active target; counter Cleanse | Tooltip: `Against reduced Defense, deal 110% Power and apply 1 Bleed.` Log: `<actor>'s chorus rent <target> for <damage>; Bleed applied.` |
| Funeral Spiral | Active Pivot; mobility/offense; self Move 3 and up to two Bleeding enemies encountered as path neighbors; CD 5 | Rotate self up to 3; deal 80% Power independently to each locked legal target; validate entire path/targets first | Reject fewer than one target/path; AI hits two; counter movement lock/Cleanse | Tooltip: `Move up to 3 and deal 80% Power to up to two Bleeding enemies along the path.` Log: `<actor> spiraled along <path>, hitting <targets>.` |
| The Flock Descends | Passive Signature; coalition; first different-race ally hitting Cantor-Bleeding enemy each round | Ally may rotate Move 1 after hit; once/round; Aggressive hit +1 Power, Protective ally +1 Defense | No legal path/different race, no move; AI coordinates; counter movement lock/Cleanse | Tooltip: `Once per round, a different-race ally hitting your Bleeding target may move 1.` Log: `<actor>'s song moved <ally> 1 after the hit.` |

## Role Summary

| Class | Primary job | Signature mechanic |
|---|---|---|
| Talon Duelist | Mobile striker | Self-rotation pressure |
| Storm Siren | Controller | Move 1-3 escalation |
| Gale Scout | Setup support | Movement-gated Advantage |
| Skyhook Raider | Extractor | Isolated target payoff |
| Nestguard | Protector | Rescue swap and Guard |
| Carrion Cantor | Pressure support | Narrow physical Bleed branch |
