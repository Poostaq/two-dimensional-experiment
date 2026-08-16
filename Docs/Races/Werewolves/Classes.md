# Werewolf Classes

## Reading the Skill Records

All skills inherit the shared mechanics contract. `CD N` is post-use cooldown in successful owning-side actions. Unstated duration, stacks, reapplication, movement, and Advantage are `None`; cleanup is battle end; invalid previews reject atomically; AI requires legal listed effects; UI cells contain exact tooltip and log text.

## Class 1: Moonfang Skirmisher

**Role:** Execution skirmisher. **Rhythm:** Mark wounded prey, pounce, finish with Leech. **Weakness:** Poor value above wound thresholds. **Stats:** 17 Health, 9 Power, 9 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Scent Blood | Active Opener; Advantage; enemy below 70% HP and self; CD 1 | Deal 70% Power and grant self Advantage | Reject threshold or no eligible rider; AI picks lowest HP; counter with Armor | Tooltip: `Against an enemy below 70% HP, deal 70% Power and gain Advantage.` Log: `<actor> scented <target>, dealt <damage>, and gained Advantage.` |
| Pounce | Active Converter; mobility/offense; self Move 2 then neighboring enemy below 70%; CD 2 | Rotate self up to Move 2, then deal 140% Power; Advantage rider 170% | Reject path/post-move threshold; AI closes lethal target; counter by changing occupancy | Tooltip: `Move up to 2 and deal 140% Power to a neighboring enemy below 70% HP.` Log: `<actor> pounced on <target> for <damage>.` |
| Moonfang Finish | Active Pivot; offense/Leech; enemy below half HP; CD 4 | Deal 190% Power and Leech 35%; Advantage rider increases Leech to 40% | Reject threshold; AI uses lethal/high missing HP; counter with Armor or Defense | Tooltip: `Deal 190% Power to an enemy below half HP and Leech 35%.` Log: `<actor> finished <target> for <damage> and leeched <healing> HP.` |
| Predator's Recovery | Passive Signature; Leech; first direct-damage defeat each battle | The next direct hit this battle Leeches 40%; once per battle, consumed on hit | No direct defeat, no trigger; AI favors a high-damage next hit; counter by denying the last hit | Tooltip: `Once per battle after a direct defeat, your next direct hit Leeches 40%.` Log: `<actor>'s Predator's Recovery prepared 40% Leech.` |

## Class 2: Pack Howler

**Role:** Hunt-window support. **Rhythm:** Call prey, move the pack, amplify one coalition attack. **Weakness:** Low personal conversion. **Stats:** 20 Health, 6 Power, 8 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Hunting Cry | Active Opener; Advantage/support; up to two allies; enemy below 70%; CD 2 | Grant each selected eligible ally Advantage | Reject no wounded enemy or eligible ally; AI chooses two unresolved consumers; counter by forcing expiry | Tooltip: `While an enemy is below 70% HP, grant up to two allies Advantage.` Log: `<actor> called the hunt; <allies> gained Advantage.` |
| Drive the Pack | Active Converter; mobility; up to two allies; CD 3 | Rotate each ally Move 1 in declared order; validate both paths first | Reject either path; AI improves attack access; counter by changing occupancy | Tooltip: `Move up to two allies 1 in a declared order.` Log: `<actor> drove <allies> along <paths>.` |
| Full-Moon Chorus | Active Pivot; Leech/support; all allies; enemy below half; CD 5 | Each ally's first direct hit this round Leeches 25%; one use per ally | Reject no wounded enemy or unresolved ally; AI uses early; counter with Armor | Tooltip: `This round, each ally's first direct hit Leeches 25%.` Log: `<actor> began a Full-Moon Chorus for <allies>.` |
| Answer the Call | Passive Signature; movement; first different-race ally direct hit each round | Howler rotates Move 1 after the action if legal; once per round | No legal path/different race, no trigger; AI pairs mixed roster; counter by choosing the other path | Tooltip: `Once per round after a different-race ally hits, move 1.` Log: `<actor> answered <ally>'s call and moved 1.` |

## Class 3: Bloodtrail Stalker

**Role:** Persistent Bleed tracker. **Rhythm:** Apply Bleed, follow rotation, deepen the wound. **Weakness:** Armor blunts direct conversion. **Stats:** 18 Health, 8 Power, 8 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Rake | Active Opener; offense/Bleed; one enemy; CD 1 | Deal 90% Power and apply 1 Bleed for 2 target actions, max 3/refresh canon | Reject inactive; AI chooses low Bleed; counter with Armor on direct hits | Tooltip: `Deal 90% Power and apply 1 Bleed for 2 actions.` Log: `<actor> raked <target> for <damage> and applied Bleed.` |
| Follow the Trail | Active Converter; mobility/offense; Bleeding enemy; CD 2 | Rotate self Move 2 toward a neighboring slot, then deal 120% Power; Advantage rider permits Move 3 | Reject path/adjacency; AI pursues lowest HP; counter by rotation | Tooltip: `Move up to 2 and deal 120% Power to a neighboring Bleeding enemy.` Log: `<actor> followed <target>'s trail for <damage>.` |
| Cornered Prey | Active Pivot; offense/Bleed; Bleeding enemy with both ring neighbors occupied; CD 4 | Deal 170% Power and add 1 Bleed stack, refresh canon | Reject formation/no Bleed; AI seeks crowded target; counter by opening a neighbor slot | Tooltip: `Deal 170% Power to an enclosed Bleeding enemy and add 1 Bleed.` Log: `<actor> cornered <target> for <damage>; Bleed <stacks>/3.` |
| Never Lose the Scent | Passive Signature; cooldown; first Bleeding enemy movement each round | Reduce Follow the Trail cooldown by 1; once per round | No Bleed/move, no trigger; AI maintains Bleed; counter by avoiding movement | Tooltip: `Once per round when a Bleeding enemy moves, reduce Follow the Trail cooldown by 1.` Log: `<actor> kept <target>'s scent.` |

## Class 4: Duskhide Ravager

**Role:** Risky sustain bruiser. **Rhythm:** Sacrifice safety, Leech through contact, commit to frenzy. **Weakness:** Self-damage and focus fire. **Stats:** 22 Health, 9 Power, 6 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Reckless Claw | Active Opener; offense/risk; one enemy; CD 0 | Deal 130% Power; actor takes 10% max HP direct self-damage after hit, cannot defeat actor below 1 HP | Reject if self-cost would leave 1 and target not below half; AI requires payoff; counter with retaliation | Tooltip: `Deal 130% Power and lose 10% max HP, stopping at 1 HP.` Log: `<actor> clawed <target> for <damage> and lost <cost> HP.` |
| Feed Through Pain | Active Converter; offense/Leech; one enemy while actor below 70%; CD 2 | Deal 140% Power and Leech 40%; Advantage rider 160% | Reject health condition; AI uses with missing HP; counter with Armor or Defense | Tooltip: `Below 70% HP, deal 140% Power and Leech 40%.` Log: `<actor> fed through pain for <damage> and leeched <healing>.` |
| Frenzied Lunge | Active Pivot; mobility/capstone; self Move 2 then neighbor; actor below half; CD 5 | Rotate, then deal 210% Power | Reject path/threshold/target; AI seeks lethal; counter with Armor | Tooltip: `Below half HP, move up to 2 and deal 210% Power.` Log: `<actor> lunged at <target> for <damage>.` |
| Violence Sustains | Passive Signature; Leech; first direct hit each round while below half | That hit Leeches 25%; once per round | No damage/threshold, no trigger; AI stays offensive; counter with Armor or Defense | Tooltip: `Once per round below half HP, your first direct hit Leeches 25%.` Log: `<actor>'s Violence Sustains leeched <amount> HP.` |

## Class 5: Den Warden

**Role:** Pack protector. **Rhythm:** Armor a wounded ally, punish its attacker, rotate it to safety. **Weakness:** Low offensive pressure. **Stats:** 24 Health, 6 Power, 6 Speed, 2 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Armor the Weak | Active Opener; Armor; ring-neighbor ally below half; CD 1 | Ally gains 5 Armor | Reject threshold/no neighbor/full pool; AI protects fragile ally; counter with status damage | Tooltip: `A neighboring ally below half HP gains 5 Armor.` Log: `<actor> granted <ally> 5 Armor.` |
| Warning Snarl | Active Converter; offense; enemy that hit an Armored ally this round; CD 2 | Deal 130% Power; Advantage rider deals 160% | Reject no qualifying attacker; AI retaliates against strongest; counter by attacking unarmored targets | Tooltip: `Deal 130% Power to an enemy that hit an Armored ally this round.` Log: `<actor> snarled and hit <target> for <damage>.` |
| Pack Intercept | Active Pivot; movement/Armor; any ally; CD 4 | Explicitly swap Warden and ally; both gain 3 Armor | Reject slots/changed preview; AI rescues threatened ally; counter by changing occupancy | Tooltip: `Swap with any ally; both of you gain 3 Armor.` Log: `<actor> intercepted for <ally>; both gained 3 Armor.` |
| Nobody Hunts Alone | Passive Signature; Armor; first wounded ally ending beside Warden each round | Ally gains 2 Armor; once per round | No qualifying neighbor, no trigger; AI stays near wounded ally; counter by separating units | Tooltip: `Once per round, a neighboring ally below half HP gains 2 Armor.` Log: `<actor> granted wounded <ally> 2 Armor.` |

## Class 6: Moonblood Seer

**Role:** Predictive threshold support. **Rhythm:** Foretell a wound, prepare conversion, open one capstone hunt. **Weakness:** Predictions can be healed away. **Stats:** 19 Health, 6 Power, 7 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Foretell the Kill | Active Opener; Advantage; enemy above half and one ally; CD 1 | Grant chosen eligible ally Advantage | Reject threshold/no eligible ally; AI prepares a converter; counter by forcing expiry | Tooltip: `While an enemy is above half HP, grant one ally Advantage.` Log: `<actor> foretold a kill; <ally> gained Advantage.` |
| Red Moon Strike | Active Converter; offense/Advantage; enemy below half; CD 2 | Deal 120% Power; Advantage rider deals 150% and Leeches 25% | Reject threshold; AI converts Advantage; counter with Armor | Tooltip: `Below half HP, deal 120% Power; with Advantage, deal 150% and Leech 25%.` Log: `<actor> struck <target> for <damage> and leeched <healing>.` |
| Eclipse Hunt | Active Pivot; support/capstone; enemy below half; all allies; CD 5 | For current round, each ally may rotate Move 1 immediately before its first direct attack on target; one use/ally | Reject no unresolved ally/threshold; AI opens team access; counter by changing occupancy or using Armor | Tooltip: `This round, each ally may move 1 before its first attack on wounded prey.` Log: `<actor> began an Eclipse Hunt on <target>.` |
| Fate Smells of Blood | Passive Signature; cooldown; first enemy crossing below half each round | Reduce one chosen ally Active cooldown by 1; once per round | No crossing/no ally cooldown, no trigger; AI focuses threshold; counter by preventing threshold crossing | Tooltip: `Once per round when an enemy falls below half HP, reduce an ally cooldown by 1.` Log: `<actor> read blood's fate for <ally>.` |

## Role Summary

| Class | Primary job | Signature mechanic |
|---|---|---|
| Moonfang Skirmisher | Finisher | Prey execution and Leech |
| Pack Howler | Hunt support | Shared prey window |
| Bloodtrail Stalker | Tracker | Bleed pursuit |
| Duskhide Ravager | Sustain bruiser | Self-risk Leech |
| Den Warden | Protector | Interception without healing |
| Moonblood Seer | Predictive support | Wounded-threshold Advantage |
