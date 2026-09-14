# Dwarf Classes

## Reading the Skill Records

All Dwarf classes follow the shared battle contract in the project docs. Each class below is written as a complete three-skill loadout and is tuned to read as craft, durability, and expensive battlefield certainty.

## Class 1: Forgewarden

**Role:** Stone-wall defensive anchor. **Rhythm:** Hold a lane, absorb contact, and protect nearby allies. **Weakness:** Limited offensive speed and reach. **Stats:** 28 Health, 5 Power, 3 Speed, 5 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Iron Brace | `DWF-FW-01` Active Opener; Armor/support; self and one neighboring ally; CD 1 | Both legal targets gain 4 Armor. This is the Forgewarden's baseline contact tool and the class's quickest way to stabilize a lane. | Rejects if no neighboring ally can gain Armor. AI uses it before contact or before a projected burst. Counterplay is to isolate the Forgewarden from its protected ally. | Tooltip: `You and one neighboring ally gain 4 Armor.` Log: `<actor> forged a brace with <ally>.` |
| Runed Guard | `DWF-FW-02` Active Converter; offense/Armor; one neighboring enemy; CD 2 | Deal 90% Power. If the Forgewarden has any Armor, it and one neighboring ally each gain 2 Armor after the hit. The skill turns existing defense into more line stability. | Rejects if no neighboring enemy is legal. AI prefers the enemy most likely to break through the formation. Counterplay is to strip the Forgewarden’s Armor before the attack or force a bad lane. | Tooltip: `Deal 90% Power; if you have Armor, you and one ally gain 2 Armor.` Log: `<actor> ran a runed guard into <target>.` |
| Unyielding Stone | `DWF-FW-03` Active Pivot; Armor/support; self and both neighboring allies; CD 5 | Each legal target gains 5 Armor. If one target is below half HP, that target gains 2 extra Armor instead. This is the class's emergency fortress reset. | Rejects if fewer than two targets can legally gain Armor. AI uses it when the lane is about to crack. Counterplay is status damage that bypasses Armor or breaking the formation before the cast resolves. | Tooltip: `You and both neighboring allies gain 5 Armor; a wounded target gains 2 more.` Log: `<actor> stood as unyielding stone.` |

## Class 2: Siege Smith

**Role:** Anti-armor and heavy damage specialist. **Rhythm:** Break a target's resilience and convert that into direct offense. **Weakness:** Slow and vulnerable if forced to attack without setup. **Stats:** 26 Health, 8 Power, 3 Speed, 3 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Test the Plate | `DWF-SS-01` Active Opener; offense/Armor; neighboring enemy; CD 1 | Remove up to 2 Armor from the target, then deal 110% Power. This is the class’s cleanest way to test how much protection an enemy still has left. | Rejects if no neighboring enemy is legal. AI targets the enemy with the most Armor. Counterplay is to rotate the target away or spend Armor before the Smith acts. | Tooltip: `Remove up to 2 Armor, then deal 110% Power.` Log: `<actor> tested the plate on <target>.` |
| Hollow Core | `DWF-SS-02` Active Converter; offense/Armor; enemy that lost Armor this round; CD 3 | Deal 150% Power. If the target lost 3 or more Armor this round, the hit rises to 180%. The Smith converts broken armor into a heavier strike. | Rejects if the target did not lose Armor this round. AI follows a friendly breaker or waits for its own opener to land. Counterplay is to avoid spending too much Armor on one target in the same round. | Tooltip: `Deal 150% Power to an enemy that lost Armor this round; 180% if it lost 3+.` Log: `<actor> struck the hollow core of <target>.` |
| Breaker's Verdict | `DWF-SS-03` Active Pivot; offense/capstone; neighboring enemy; CD 5 | Deal 210% Power, ignoring Armor. If the target has no Armor, the hit rises to 240%. This is the class's decisive heavy-finish tool. | Rejects if no neighboring enemy is legal. AI saves it for a target that is already soft or already stripped. Counterplay is to keep the target out of contact or maintain enough Armor for the hit to stay below the higher band. | Tooltip: `Deal 210% Power to a neighboring enemy, ignoring Armor; unarmored targets take 240%.` Log: `<actor> delivered the breaker’s verdict.` |

## Class 3: Rune Sentinel

**Role:** Defensive support and magical ward specialist. **Rhythm:** Protect the line while creating stable defensive windows. **Weakness:** Lower direct damage than a true striker. **Stats:** 27 Health, 4 Power, 4 Speed, 4 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Warded Step | `DWF-RS-01` Active Opener; mobility/Armor; self or one adjacent ally; CD 1 | Move the target 1 on a legal ring path, then grant 3 Armor. The Sentinel uses movement to prevent collapse rather than to chase kills. | Rejects if the path is illegal or the target cannot move. AI uses it to reposition a threatened ally into a safer lane. Counterplay is to invalidate the path with occupancy or force a worse rotation choice. | Tooltip: `Move 1, then gain 3 Armor.` Log: `<actor> warded a step for <target>.` |
| Rune of Hold | `DWF-RS-02` Active Converter; control; one enemy moved this round; CD 2 | Deal 100% Power and apply Snared until round end. The Sentinel locks down a target that already committed to movement. | Rejects if the target did not move this round. AI uses it after a rotation or allied pull. Counterplay is to avoid moving the intended target before the Sentinel’s turn. | Tooltip: `Deal 100% Power to an enemy moved this round and apply Snared.` Log: `<actor> held <target> in rune-light.` |
| Living Plate | `DWF-RS-03` Active Pivot; Armor/support; all active allies; CD 5 | Every active ally gains 4 Armor. If the Sentinel has 3 or more Armor, the most injured ally gains 2 extra Armor. This is the class's broad defensive capstone. | Rejects only if no ally can legally gain Armor. AI uses it before a major hostile swing. Counterplay is status damage that ignores Armor or forcing the Sentinel to spend its own defenses early. | Tooltip: `All active allies gain 4 Armor; the most injured ally can gain 2 more.` Log: `<actor> raised living plate over the line.` |

## Class 4: Quarrel Engineer

**Role:** Ranged control and damage specialist. **Rhythm:** Punish mispositioning and enforce a difficult angle of engagement. **Weakness:** Less effective at close range. **Stats:** 24 Health, 6 Power, 4 Speed, 3 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Shot-Lock | `DWF-QE-01` Active Opener; offense/setup; one enemy; CD 1 | Deal 85% Power and apply Snared until round end. This is the Engineer’s cleanest way to pin a target in place for later shots. | Rejects if the target is invalid. AI uses it to prepare a target for a heavier follow-up. Counterplay is to change the target’s position before the next shot lands. | Tooltip: `Deal 85% Power and apply Snared until round end.` Log: `<actor> locked the shot on <target>.` |
| Hammered Line | `DWF-QE-02` Active Converter; offense/control; one Snared enemy; CD 2 | Deal 130% Power. If the target moved this round, the hit rises to 160%. The Engineer turns immobility into a disciplined firing lane. | Rejects if the target is not Snared. AI uses it after Shot-Lock or after an ally trap effect. Counterplay is to avoid leaving the same target exposed for the follow-up. | Tooltip: `Deal 130% Power to a Snared enemy; moved targets take 160% instead.` Log: `<actor> hammered the line through <target>.` |
| Explosive Refit | `DWF-QE-03` Active Pivot; offense/capstone; up to two enemies; CD 5 | Choose up to two enemies. The primary target takes 180% Power. The second target takes 100% Power. If the primary target is Snared, the secondary target takes 120% instead. This is the Engineer’s high-value burst lane. | Rejects if no legal targets exist. AI uses it to punish clustered enemies or to cash out a prepared target. Counterplay is to spread the formation or remove Snared from the priority target first. | Tooltip: `Choose up to 2 enemies; the primary takes 180% Power and the second takes 100% or 120%.` Log: `<actor> refit the explosive line.` |

## Class 5: Hearthkeeper

**Role:** Party sustain and team protection specialist. **Rhythm:** Keep the formation alive long enough to convert a good lane. **Weakness:** Lower direct output and limited mobility. **Stats:** 23 Health, 4 Power, 4 Speed, 3 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Hearth Reset | `DWF-HK-01` Active Opener; Armor/support; one ally below 75% HP; CD 1 | Grant the target 4 Armor. If it is below half HP, grant 6 Armor instead. The Hearthkeeper immediately rescues a threatened unit. | Rejects if the target is too healthy or cannot legally gain Armor. AI chooses the most threatened ally. Counterplay is to pressure the Hearthkeeper before the rescue lands. | Tooltip: `An ally below 75% HP gains 4 Armor; below half HP, it gains 6 instead.` Log: `<actor> reset the hearth around <target>.` |
| Warm the Line | `DWF-HK-02` Active Converter; Armor/support; self and neighboring allies; CD 2 | Each legal target gains 3 Armor. If one of them is below half HP, that target gains 2 extra Armor. The skill spreads survival across the front. | Rejects if no neighboring ally can gain Armor. AI uses it after a small burst or before contact. Counterplay is to separate the formation so the keeper cannot reach multiple allies at once. | Tooltip: `You and neighboring allies gain 3 Armor; a wounded target gains 2 more.` Log: `<actor> warmed the line.` |
| Shared Forge | `DWF-HK-03` Active Pivot; Armor/support; all active allies; CD 5 | Every active ally gains 4 Armor. If at least two allies are below half HP, every active ally gains 6 Armor instead. This is the Hearthkeeper’s full-team recovery capstone. | Rejects if no ally can legally gain Armor. AI uses it in collapse states or before a predicted enemy burst. Counterplay is to force one ally to drop early and then deny the full-team window. | Tooltip: `All active allies gain 4 Armor; if two or more are wounded, they gain 6 instead.` Log: `<actor> shared the forge with the whole line.` |

## Class 6: Thunderbreaker

**Role:** Heavy striker and battlefield breaker. **Rhythm:** Crash into a weak point and force immediate tactical consequences. **Weakness:** Slow and vulnerable if the fight turns mobile or repositioned. **Stats:** 25 Health, 8 Power, 2 Speed, 3 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Weight of the Hammer | `DWF-TB-01` Active Opener; offense/Armor; neighboring enemy; CD 1 | Deal 100% Power and remove up to 2 Armor from the target. The breaker opens by testing the enemy's cover and clearing it if possible. | Rejects if no neighboring enemy is legal. AI prefers the most protected target. Counterplay is to keep the target out of direct contact or spend Armor before the swing. | Tooltip: `Remove up to 2 Armor, then deal 100% Power.` Log: `<actor> weighed the hammer against <target>.` |
| Cracked Foundation | `DWF-TB-02` Active Converter; offense/Armor; enemy that lost Armor this round; CD 3 | Deal 160% Power. If the target lost 3 or more Armor this round, the hit rises to 190%. The breaker cashes out the opening created by earlier pressure. | Rejects if the target did not lose Armor this round. AI follows an ally or its own opener. Counterplay is to avoid spending too much Armor on one target in the same round. | Tooltip: `Deal 160% Power to an enemy that lost Armor this round; 190% if it lost 3+.` Log: `<actor> cracked the foundation under <target>.` |
| Thunderfall Decision | `DWF-TB-03` Active Pivot; offense/capstone; neighboring enemy; CD 5 | Deal 220% Power, ignoring Armor. If the target lost Armor this round, the hit rises to 250%. This is the class’s decisive contact-ending strike. | Rejects if no neighboring enemy is legal. AI saves it for the target with the cleanest breach. Counterplay is to stay out of contact or keep Armor loss from happening before the breaker acts. | Tooltip: `Deal 220% Power to a neighboring enemy, ignoring Armor; Armor-loss targets take 250%.` Log: `<actor> called thunderfall on <target>.` |

## Role Summary

| Class | Primary job | Signature fantasy |
|---|---|---|
| Forgewarden | Defensive anchor | Unshakable front-line resilience |
| Siege Smith | Anti-armor specialist | Turn defense into weakness |
| Rune Sentinel | Ward support | Protection through crafted magical defense |
| Quarrel Engineer | Ranged control | Precision damage and denial |
| Hearthkeeper | Support specialist | Sustained team survival |
| Thunderbreaker | Heavy striker | Single-impact battlefield destruction |

## Skill Delegation

The Dwarf roster is now fully specified at the three-skill level. The remaining Skill and Progression Designer pass should only need to normalize exact numbers, tighten edge cases, and align any final balance constraints.
