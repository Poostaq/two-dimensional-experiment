# Harpy Classes

## Reading the Skill Records

All skills inherit shared mechanics. `CD N` is post-use cooldown in successful owning-side actions. Unstated duration, stacks, reapplication, movement, and Advantage are `None`; cleanup is battle end; every movement row names range/path semantics; invalid previews reject atomically; UI cells contain exact tooltip and log text.

## Class 1: Talon Duelist

**Role:** Mobile pressure striker. **Rhythm:** Pass through the ring, exploit a moved enemy, retreat. **Weakness:** No protection during cooldown. **Stats:** 14 Health, 8 Power, 10 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Raking Pass | Active Opener; mobility/offense; self Move 2 then enemy neighboring destination; CD 1 | Rotate self along chosen ring path up to 2, then deal 90% Power; position after move | Reject path/post-move target; AI changes unsafe neighbors; counter by changing occupancy | Tooltip: `Move up to 2, then deal 90% Power to a new neighbor.` Log: `<actor> raked past <target> for <damage> via <path>.` |
| Exploit Opening | Active Converter; offense; enemy forcibly moved this round; CD 2 | Deal 150% Power; Advantage rider 180% | Reject no hostile movement; AI targets low HP; counter with Armor | Tooltip: `Deal 150% Power to an enemy forcibly moved this round.` Log: `<actor> exploited <target>'s opening for <damage>.` |
| Wingbeat Retreat | Active Pivot; mobility/Armor; self Move 2; CD 3 | Rotate self up to 2, then gain 4 Armor | Reject path; AI exits contact; counter with Poison or Bleed | Tooltip: `Move up to 2 and gain 4 Armor.` Log: `<actor> retreated to <slot> and gained 4 Armor.` |
| Never Land Twice | Passive Signature; Advantage; first action each round ending in a different slot | Gain Advantage; once per round | Same slot/no move, no trigger; AI keeps a rider ready; counter by forcing token expiry | Tooltip: `Once per round after ending in a different slot, gain Advantage.` Log: `<actor> never landed twice and gained Advantage.` |

## Class 2: Storm Siren

**Role:** Formation controller. **Rhythm:** Start a rotation, deepen it, reshape an entire engagement. **Weakness:** Low damage and path dependence. **Stats:** 17 Health, 6 Power, 8 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Gust Call | Active Opener; control/Advantage; one enemy and one ally; CD 1 | Rotate target Move 1; after success grant chosen eligible ally Advantage | Reject path/ally; AI changes valuable neighbors; counter by controlling recipient | Tooltip: `Move an enemy 1, then grant an ally Advantage.` Log: `<actor> gusted <target> 1; <ally> gained Advantage.` |
| Crosswind Pull | Active Converter; control/offense; enemy moved this round; CD 3 | Rotate target Move 2, then deal 100% Power; Advantage rider deals 130% | Reject no prior movement/path; AI aligns ally contact; counter by preventing first movement | Tooltip: `Move an already-moved enemy 2, then deal 100% Power.` Log: `<actor> pulled <target> along <path> for <damage>.` |
| Eye of the Storm | Active Pivot; control/capstone; one enemy; CD 5 | Rotate target Move 3 along either chosen shortest path | Reject path; AI chooses larger adjacency disruption; counter by changing occupancy | Tooltip: `Move an enemy 3 along either chosen ring path.` Log: `<actor> sent <target> through the Eye along <path>.` |
| Voices in the Gale | Passive Signature; Advantage; first enemy moved 2+ by Siren each round | Grant chosen eligible ally Advantage; once per round | No eligible ally/move, no trigger; AI picks unresolved rider; counter by controlling recipient | Tooltip: `Once per round after moving an enemy 2 or more, grant an ally Advantage.` Log: `<actor>'s gale granted <ally> Advantage.` |

## Class 3: Gale Scout

**Role:** Exposure spotter. **Rhythm:** Move a target, signal an ally, relocate that ally. **Weakness:** Lowest Harpy Health. **Stats:** 12 Health, 6 Power, 10 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Spot the Straggler | Active Opener; movement/Advantage; enemy and ally; CD 1 | Rotate enemy Move 1; after success grant chosen eligible ally Advantage | Reject path/ally; AI chooses ally able to target; counter by controlling ally | Tooltip: `Move an enemy 1 and grant an eligible ally Advantage.` Log: `<actor> moved <target>; <ally> gained Advantage.` |
| Diving Signal | Active Converter; offense; enemy forcibly moved this round; CD 2 | Deal 110% Power; Advantage rider deals 150% | Reject no forced movement; AI uses with token/low HP; counter with Armor | Tooltip: `Deal 110% Power to an enemy moved this round; with Advantage, deal 150%.` Log: `<actor> signaled a dive on <target> for <damage>.` |
| Updraft Reposition | Active Pivot; mobility/Armor; one ally; CD 3 | Rotate ally Move 2 on chosen path, then ally gains 2 Armor | Reject path/inactive; AI improves targeting; counter by changing occupancy | Tooltip: `Move an ally up to 2 and grant it 2 Armor.` Log: `<actor> lifted <ally> along <path>; Armor +2.` |
| Clear Sightline | Passive Signature; cooldown; first successful hostile movement each round | Reduce Spot the Straggler cooldown by 1; once per round | No hostile movement, no trigger; AI moves high-value target; counter by avoiding movement | Tooltip: `Once per round after hostile movement, reduce Spot the Straggler cooldown by 1.` Log: `<actor>'s Clear Sightline reduced its cooldown.` |

## Class 4: Skyhook Raider

**Role:** Target extractor. **Rhythm:** Separate prior neighbors, punish isolation, perform one full-ring extraction. **Weakness:** Long Pivot cooldown. **Stats:** 18 Health, 7 Power, 8 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Hook and Lift | Active Opener; control/Advantage; one enemy and one ally; CD 2 | Rotate target Move 2; after success grant chosen eligible ally Advantage | Reject path/ally; AI changes important neighbors; counter by controlling ally | Tooltip: `Move an enemy 2 and grant an ally Advantage.` Log: `<actor> hooked <target> along <path>; <ally> gained Advantage.` |
| Drop Out of Line | Active Converter; offense; enemy moved 2+ this round; CD 2 | Deal 160% Power; Advantage rider 190% | Reject movement distance condition; AI seeks lethal; counter with Armor | Tooltip: `Deal 160% Power to an enemy moved 2 or more this round.` Log: `<actor> dropped <target> out of line for <damage>.` |
| Snatch Away | Active Pivot; control/capstone; one enemy; CD 5 | Rotate target Move 3 on either chosen shortest path | Reject path; AI disrupts more valuable neighbors; counter by changing occupancy | Tooltip: `Move an enemy 3 on either ring path.` Log: `<actor> snatched <target> along <path>.` |
| Long-Distance Prey | Passive Signature; Advantage; first enemy moved 3 by Raider each round | Grant chosen eligible ally Advantage; once per round | No Move 3/eligible ally, no trigger; AI coordinates striker; counter by controlling recipient | Tooltip: `Once per round after moving an enemy 3, grant an ally Advantage.` Log: `<actor> granted <ally> Advantage after the extraction.` |

## Class 5: Nestguard

**Role:** Rescue mobility and protection. **Rhythm:** Cover a neighbor, weaken attackers, extract an ally. **Weakness:** Limited threat. **Stats:** 20 Health, 5 Power, 7 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Covering Wings | Active Opener; Armor/support; ring-neighbor ally; CD 1 | Ally gains 4 Armor | Reject no neighbor/full pool; AI protects fragile ally; counter with status damage | Tooltip: `A neighboring ally gains 4 Armor.` Log: `<actor> covered <ally>; Armor +4.` |
| Warning Screech | Active Converter; offense; enemy that hit an Armored ally this round; CD 2 | Deal 130% Power; Advantage rider deals 160% | Reject no qualifying attacker; AI retaliates; counter by attacking unarmored targets | Tooltip: `Deal 130% Power to an enemy that hit an Armored ally this round.` Log: `<actor> screeched at <target> for <damage>.` |
| Rescue Flight | Active Pivot; mobility/Armor; any ally; CD 4 | Explicitly swap Nestguard and ally; both gain 3 Armor | Reject slots/changed preview; AI rescues threatened ally; counter by changing occupancy | Tooltip: `Swap with any ally; both gain 3 Armor.` Log: `<actor> rescued <ally>; both gained 3 Armor.` |
| Cover from Above | Passive Signature; Armor; first ally moved beside Nestguard each round | Ally gains 2 Armor; once per round | No moved neighbor, no trigger; AI receives rotations; counter by attacking Nestguard first | Tooltip: `Once per round, an ally moved beside you gains 2 Armor.` Log: `<actor> granted <ally> 2 Armor from above.` |

## Class 6: Carrion Cantor

**Role:** Physical pressure support. **Rhythm:** Move with sound, apply the race's narrow Bleed branch, spiral through wounded enemies. **Weakness:** Armor blunts direct pressure. **Stats:** 16 Health, 7 Power, 9 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Cutting Note | Active Opener; offense/control; one enemy; CD 1 | Deal 90% Power and rotate target Move 1 | Reject no path; AI changes valuable neighbors; counter by changing occupancy | Tooltip: `Deal 90% Power and move an enemy 1.` Log: `<actor>'s Cutting Note hit <target> for <damage> and moved it 1.` |
| Rending Chorus | Active Converter; offense/Bleed; enemy moved this round; CD 2 | Deal 110% Power and apply 1 Bleed for 2 target actions, max 3/refresh canon | Reject no movement; AI applies to active target; counter with Armor | Tooltip: `Against an enemy moved this round, deal 110% Power and apply 1 Bleed.` Log: `<actor>'s chorus rent <target> for <damage>; Bleed applied.` |
| Funeral Spiral | Active Pivot; mobility/offense; self Move 3 and up to two Bleeding path-neighbors; CD 5 | Rotate self up to 3; deal 80% Power to each locked legal target; validate path/targets first | Reject no target/path; AI hits two; counter by changing occupancy | Tooltip: `Move up to 3 and deal 80% Power to up to two Bleeding path-neighbors.` Log: `<actor> spiraled along <path>, hitting <targets>.` |
| The Flock Descends | Passive Signature; movement; first different-race ally hitting Cantor-Bleeding enemy each round | Ally may rotate Move 1 after hit; once per round | No legal path/different race, no trigger; AI coordinates; counter by choosing the other path | Tooltip: `Once per round, a different-race ally hitting your Bleeding target may move 1.` Log: `<actor>'s song moved <ally> 1 after the hit.` |

## Role Summary

| Class | Primary job | Signature mechanic |
|---|---|---|
| Talon Duelist | Mobile striker | Self-rotation pressure |
| Storm Siren | Controller | Move 1-3 escalation |
| Gale Scout | Setup support | Movement-gated Advantage |
| Skyhook Raider | Extractor | Move 2-3 payoff |
| Nestguard | Protector | Rescue swap and Armor |
| Carrion Cantor | Pressure support | Narrow physical Bleed branch |
