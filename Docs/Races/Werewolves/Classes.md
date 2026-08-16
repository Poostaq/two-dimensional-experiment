# Werewolf Classes

## Reading the Skill Records

All skills inherit the shared mechanics contract. `CD N` is post-use cooldown in successful owning-side actions. Unstated duration, stacks, reapplication, movement, and Advantage are `None`; cleanup is battle end; invalid previews reject atomically; AI requires legal listed effects; UI cells contain exact tooltip and log text.

## Class 1: Moonfang Skirmisher

**Role:** Execution skirmisher. **Rhythm:** Mark wounded prey, pounce, finish with Leech. **Weakness:** Poor value above wound thresholds. **Stats:** 17 Health, 9 Power, 9 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Scent Blood | Active Opener; setup; enemy below 70% HP; CD 1 | Mark for 2 rounds; marked target is legal for hunter converters; one/source, refresh | Reject threshold/equal mark; AI picks lowest HP; counter by healing/Cleanse | Tooltip: `Mark an enemy below 70% HP as prey for 2 rounds.` Log: `<actor> scented <target> as prey.` |
| Pounce | Active Converter; mobility/offense; self Move 2 then neighboring marked enemy; CD 2 | Rotate self up to Move 2, then deal 140% Power; Advantage rider 170% | Reject path/post-move mark; AI closes lethal target; counter with movement lock | Tooltip: `Move up to 2 and deal 140% Power to neighboring prey.` Log: `<actor> pounced on <target> for <damage>.` |
| Moonfang Finish | Active Pivot; offense/Leech; prey below half HP; CD 4 | Deal 190% Power and Leech 35%; Advantage rider increases Leech to 40% | Reject threshold/mark; AI uses lethal/high missing HP; counter with Guard/heal | Tooltip: `Deal 190% Power to wounded prey and Leech 35%.` Log: `<actor> finished <target> for <damage> and leeched <healing> HP.` |
| Predator's Recovery | Passive Signature; sustain; first defeat caused by direct damage each battle | Heal 20% max HP; once/battle; Aggressive next attack +2 Power, Protective heal 30% | No defeat/status kill; AI favors finish; counter by denying last hit | Tooltip: `Once per battle after directly defeating prey, heal 20% max HP.` Log: `<actor>'s Predator's Recovery healed <amount> HP.` |

## Class 2: Pack Howler

**Role:** Hunt-window support. **Rhythm:** Call prey, move the pack, amplify one coalition attack. **Weakness:** Low personal conversion. **Stats:** 20 Health, 6 Power, 8 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Hunting Cry | Active Opener; support/setup; one enemy below 70% and two allies; CD 2 | Mark prey 2 rounds; chosen allies +1 Speed current round; mark refresh, queue rebuild | Reject no prey/unresolved ally; AI catches two hunters; counter by heal/Speed Poison | Tooltip: `Mark wounded prey for 2 rounds; two allies gain 1 Speed this round.` Log: `<actor> called the hunt on <target> for <allies>.` |
| Drive the Pack | Active Converter; support/mobility; up to two allies targeting prey; CD 3 | Rotate each ally Move 1 in declared order; each next direct attack on prey gains +1 Power this round | Reject either path; AI improves reach; counter with movement lock | Tooltip: `Move up to two allies 1; their next prey attacks gain 1 Power this round.` Log: `<actor> drove <allies> toward <target>.` |
| Full-Moon Chorus | Active Pivot; capstone/support; marked prey; CD 5 | All allies' first direct hit on prey this round Leech 25%; one effect/ally, non-stack/refresh | Reject no prey or after all allies acted; AI uses early; counter by Guard/rotation | Tooltip: `Each ally's first direct hit on prey this round Leeches 25%.` Log: `<actor> began a Full-Moon Chorus against <target>.` |
| Answer the Call | Passive Signature; coalition; first different-race ally hitting prey each round | Howler gains Move 1 after action if legal; once/round; Aggressive ally +1 Power, Protective ally +1 Defense | No legal path/different race, no move; AI pairs mixed roster; counter by movement lock | Tooltip: `Once per round after a different-race ally hits prey, move 1.` Log: `<actor> answered <ally>'s call and moved 1.` |

## Class 3: Bloodtrail Stalker

**Role:** Persistent Bleed tracker. **Rhythm:** Apply Bleed, follow rotation, corner the target. **Weakness:** Cleanse breaks the trail. **Stats:** 18 Health, 8 Power, 8 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Rake | Active Opener; offense/Bleed; one enemy; CD 1 | Deal 90% Power and apply 1 Bleed for 2 target actions, max 3/refresh canon | Reject inactive; AI chooses no/low Bleed; counter Cleanse | Tooltip: `Deal 90% Power and apply 1 Bleed for 2 actions.` Log: `<actor> raked <target> for <damage> and applied Bleed.` |
| Follow the Trail | Active Converter; mobility/offense; Bleeding enemy; CD 2 | Rotate self Move 2 toward a slot neighboring target, then deal 120% Power; Advantage rider Move 3 | Reject no path/adjacency; AI pursues lowest HP; counter movement lock/rotation | Tooltip: `Move up to 2 and deal 120% Power to neighboring Bleeding prey.` Log: `<actor> followed <target>'s trail for <damage>.` |
| Cornered Prey | Active Pivot; offense/control; Bleeding enemy with both ring neighbors occupied by its allies; CD 4 | Deal 170% Power and apply movement lock through target's next action; non-stack/refresh | Reject formation condition; AI seeks crowded target; counter by opening neighbor slot | Tooltip: `Deal 170% Power and lock a Bleeding enemy enclosed by allies.` Log: `<actor> cornered <target> for <damage>.` |
| Never Lose the Scent | Passive Signature; tracking; first Bleeding target movement each round | Reveal new slot and reduce Follow the Trail CD by 1; once/round; Aggressive +1 Power next hit, Protective +1 Defense | No Bleed/move; AI maintains stacks; counter Cleanse | Tooltip: `Once per round when a Bleeding enemy moves, reduce Follow the Trail cooldown by 1.` Log: `<actor> kept <target>'s scent.` |

## Class 4: Duskhide Ravager

**Role:** Risky sustain bruiser. **Rhythm:** Sacrifice safety, Leech through contact, commit to frenzy. **Weakness:** Self-damage and focus fire. **Stats:** 22 Health, 9 Power, 6 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Reckless Claw | Active Opener; offense/risk; one enemy; CD 0 | Deal 130% Power; actor takes 10% max HP direct self-damage after hit, cannot defeat actor below 1 HP | Reject if self-cost would leave 1 and target not below half; AI requires payoff; counter with retaliation | Tooltip: `Deal 130% Power and lose 10% max HP, stopping at 1 HP.` Log: `<actor> clawed <target> for <damage> and lost <cost> HP.` |
| Feed Through Pain | Active Converter; offense/Leech; one enemy while actor below 70%; CD 2 | Deal 140% Power and Leech 40%; Advantage rider 160% | Reject health condition; AI uses with missing HP; counter Guard/high Defense | Tooltip: `Below 70% HP, deal 140% Power and Leech 40%.` Log: `<actor> fed through pain for <damage> and healed <healing>.` |
| Frenzied Lunge | Active Pivot; mobility/capstone; self Move 2 then neighbor; actor below half; CD 5 | Rotate, deal 210% Power, then -2 Defense until next action; no stack, refresh | Reject path/threshold/target; AI seeks lethal; counter shield/peel | Tooltip: `Below half HP, move up to 2 and deal 210% Power; lose 2 Defense until next action.` Log: `<actor> lunged at <target> for <damage> and lost Defense.` |
| Violence Sustains | Passive Signature; sustain; first direct hit each round while below half | Leech 25% on that hit; once/round; Aggressive 35%, Protective gain 2-damage shield | No damage/threshold, no trigger; AI stays aggressive; counter control or Defense | Tooltip: `Once per round below half HP, your first direct hit Leeches 25%.` Log: `<actor>'s Violence Sustains healed <amount> HP.` |

## Class 5: Den Warden

**Role:** Pack interceptor. **Rhythm:** Guard weakness, warn attackers, rotate an ally to safety. **Weakness:** Low offensive pressure. **Stats:** 24 Health, 6 Power, 6 Speed, 2 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Guard the Weak | Active Opener; defense; ring-neighbor ally below half; CD 1 | Guard ally until direct hit or round end; Warden +1 Defense for same duration; refresh/no stack | Reject threshold/no neighbor; AI protects fragile; counter area/status | Tooltip: `Guard a neighboring ally below half HP and gain 1 Defense until round end.` Log: `<actor> guarded <ally>.` |
| Warning Snarl | Active Converter; debuff; enemy that hit guarded ally this round; CD 2 | Deal 80% Power; target -2 Power through next action; one/source, refresh | Reject no qualifying attack; AI reduces strongest attacker; counter Cleanse | Tooltip: `Deal 80% Power and reduce by 2 the Power of an enemy that attacked your ward.` Log: `<actor> warned <target> for <damage>; Power -2.` |
| Pack Intercept | Active Pivot; mobility/defense; ally within Move 3; CD 4 | Explicitly swap Warden with ally; Warden Guards that ally until round end; atomic swap | Reject inactive slots/changed preview; AI rescues threatened ally; counter movement lock/area | Tooltip: `Swap with any ally, then Guard that ally until round end.` Log: `<actor> intercepted for <ally>, swapping slots.` |
| Nobody Hunts Alone | Passive Signature; defense; first ally below half ending action beside Warden each round | Ally gains 2-damage shield until round end; once/round; Aggressive Warden +1 Power, Protective shield 3 | No qualifying neighbor; AI stays near wounded; counter separate units | Tooltip: `Once per round, shield a neighboring wounded ally for 2.` Log: `<actor> ensured <ally> did not hunt alone.` |

## Class 6: Moonblood Seer

**Role:** Predictive threshold support. **Rhythm:** Foretell a wound, prepare conversion, open one capstone hunt. **Weakness:** Predictions can be healed away. **Stats:** 19 Health, 6 Power, 7 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Foretell the Kill | Active Opener; setup; one enemy above half HP; CD 1 | Omen 2 rounds; when target first falls below half, chosen ally gains +2 Power next action; one/source, refresh | Reject already below half/equal Omen; AI picks focus target; counter Cleanse/heal | Tooltip: `For 2 rounds, when an enemy first falls below half HP, an ally gains 2 Power.` Log: `<actor> foretold <target>'s wound for <ally>.` |
| Red Moon Omen | Active Converter; support; Omen target and one ally; CD 2 | Deal 70% Power; if target now below half, ally's next direct hit Leeches 25%; lasts current round | Reject no Omen; AI crosses threshold; counter shield/heal | Tooltip: `Deal 70% Power to an Omen target; if wounded, an ally's next hit Leeches 25%.` Log: `<actor> invoked a Red Moon Omen on <target>.` |
| Eclipse Hunt | Active Pivot; support/capstone; enemy below half; all allies; CD 5 | For current round, each ally may rotate Move 1 immediately before its first direct attack on target; one use/ally | Reject no unresolved ally/threshold; AI opens team access; counter movement lock/heal | Tooltip: `This round, each ally may move 1 before its first attack on wounded prey.` Log: `<actor> began an Eclipse Hunt on <target>.` |
| Fate Smells of Blood | Passive Signature; setup; first enemy crossing below half each round | Reduce one random-free selected ally's active cooldown by 1; once/round; Aggressive ally +1 Power, Protective +1 Defense | No crossing/no ally cooldown; AI focuses threshold; counter prevent crossing | Tooltip: `Once per round when an enemy falls below half HP, reduce an ally cooldown by 1.` Log: `<actor> read blood's fate for <ally>.` |

## Role Summary

| Class | Primary job | Signature mechanic |
|---|---|---|
| Moonfang Skirmisher | Finisher | Prey execution and Leech |
| Pack Howler | Hunt support | Shared prey window |
| Bloodtrail Stalker | Tracker | Bleed pursuit |
| Duskhide Ravager | Sustain bruiser | Self-risk Leech |
| Den Warden | Protector | Interception without healing |
| Moonblood Seer | Predictive support | Wounded-threshold omen |

