# Human Classes

## Reading the Skill Records

All Human classes follow the shared battle contract in the project docs. Each class below is written as a full three-skill loadout: Opener, Converter, and Pivot. The intent is to give the coalition a flexible combined-arms faction that can answer nearly any battlefield state without becoming a specialist copy of the other races.

Each record below is design-ready for the Skill and Progression Designer pass. The skill names, trigger conditions, and tactical jobs are fixed here; the exact implementation details can be tightened further if later balance review demands it.

## Class 1: Vanguard

**Role:** Front-line tactician and stability anchor. **Rhythm:** Hold space, command the lane, and absorb early pressure. **Weakness:** Weaker than dedicated damage specialists when the fight becomes pure offense. **Stats:** 22 Health, 5 Power, 5 Speed, 3 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Commanding Step | `HUM-VM-01` Active Opener; mobility/support; self; CD 1 | Move self 1 on a legal ring path, then self and one neighboring ally gain 3 Armor. If no neighboring ally can gain Armor, the action rejects. AI uses this to enter a contact lane or cover the front. | Rejects on stale path, illegal side, or invalid occupancy. Counterplay is to break the intended lane before confirmation or force the Marshal out of usable adjacency. | Tooltip: `Move 1, then you and one neighboring ally gain 3 Armor.` Log: `<actor> advanced the line and granted Armor.` |
| Shielded Advance | `HUM-VM-02` Active Converter; offense/Armor; neighboring enemy; CD 2 | Deal 115% Power. If the Marshal or either neighboring ally currently has Armor, this rises to 145%. The skill rewards proper formation and converts stability into a stronger hit. | Rejects if no neighboring enemy is legal. AI prefers targets that are already pressuring the line. Counterplay is to strip adjacency or force the Marshal into a lane with no protected allies. | Tooltip: `Deal 115% Power; if you or a neighboring ally has Armor, deal 145% instead.` Log: `<actor> shielded forward into <target> for <damage>.` |
| Lineholder's Verdict | `HUM-VM-03` Active Pivot; offense/capstone; one enemy; CD 5 | Deal 180% Power. If an allied unit acted before the Marshal this round, the hit rises to 210%. This is the class's decisive command payoff: the Marshal is strongest when the army is already moving as a unit. | Rejects on invalid target or if the target is outside legal range. AI waits for a clean team-order state or a weakened target. Counterplay is to disrupt allied sequencing or keep the target out of the Marshal's preferred lane. | Tooltip: `Deal 180% Power; if an ally acted first this round, deal 210% instead.` Log: `<actor> issued the verdict on <target> for <damage>.` |

## Class 2: Ranger

**Role:** Flexible ranged pressure and anti-threat control. **Rhythm:** Pressure exposed targets, punish movement, and maintain distance. **Weakness:** Fragile if forced into prolonged melee. **Stats:** 18 Health, 7 Power, 7 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Quick Draw | `HUM-BR-01` Active Opener; offense/setup; one enemy; CD 1 | Deal 90% Power and apply Snared until round end. The Ranger opens with a clean mark that makes the enemy easier to read and punish. | Rejects if the target is invalid or if the mark cannot be applied. AI targets enemies that want to move or hide. Counterplay is to force the Ranger onto a poor angle before the opener resolves. | Tooltip: `Deal 90% Power and apply Snared until round end.` Log: `<actor> quick-drew at <target> and applied Snared.` |
| Pinning Volley | `HUM-BR-02` Active Converter; offense/control; one Snared enemy; CD 2 | Deal 130% Power. If the target is Snared, it also gains Advantage until round end after damage resolves. The Ranger converts the opener into a coalition window for the next ally. | Rejects if the target is not Snared. AI uses it after Quick Draw or after an ally trap effect. Counterplay is to cleanse the setup by removing the Ranger or forcing the token to expire before the volley. | Tooltip: `Deal 130% Power to a Snared enemy; then apply Advantage until round end.` Log: `<actor> pinned <target> for <damage> and marked it for the team.` |
| Break the Angle | `HUM-BR-03` Active Pivot; offense/control; one enemy with Snared or Advantage; CD 4 | Deal 170% Power. If the target has both Snared and Advantage, the Ranger consumes the Advantage and the hit rises to 210%. This is the class's finisher for exposed or already-marked targets. | Rejects if the target has neither Snared nor Advantage. AI uses it on the most exposed target in the fight. Counterplay is to avoid stacking the two setup states on the same enemy or to force the target to relocate before the Ranger acts. | Tooltip: `Deal 170% Power; if the target has Snared and Advantage, deal 210% instead.` Log: `<actor> broke the angle on <target> for <damage>.` |

## Class 3: Iron Sentinel

**Role:** Defensive specialist. **Rhythm:** Build stability, hold ground, and absorb punishable hits. **Weakness:** Lower offensive ceiling than the more aggressive classes. **Stats:** 25 Health, 4 Power, 4 Speed, 4 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Brace the Line | `HUM-IS-01` Active Opener; Armor/support; self and one neighboring ally; CD 1 | Both legal targets gain 4 Armor. This is the Sentinel's baseline stabilization tool and the class's quickest way to secure a lane. | Rejects if no neighboring ally can gain Armor. AI uses it before contact or immediately before a projected burst. Counterplay is to force the Sentinel into a bad side of the ring. | Tooltip: `You and one neighboring ally gain 4 Armor.` Log: `<actor> braced the line with an ally.` |
| Field Fortification | `HUM-IS-02` Active Converter; offense/Armor; one neighboring enemy; CD 2 | Deal 100% Power. If the Sentinel has at least 2 Armor, the target loses up to 2 Armor before damage. The skill converts the Sentinel's own protection into an opening strike. | Rejects if no neighboring enemy is legal. AI uses it after the opener or after the Sentinel has been defended by allies. Counterplay is to strip the Sentinel's Armor before the attack or to rotate the target away. | Tooltip: `Deal 100% Power; if you have 2+ Armor, remove up to 2 Armor from the target first.` Log: `<actor> fortified into <target> for <damage>.` |
| Wall of Steel | `HUM-IS-03` Active Pivot; Armor/support; self and both neighboring allies; CD 5 | Each legal target gains 5 Armor. If one of those targets is below half HP, that target gains 2 extra Armor instead. This is the class's emergency fortress reset. | Rejects if fewer than two targets can legally gain Armor. AI uses it when the lane is about to crack. Counterplay is status damage that bypasses Armor or breaking the formation before the cast resolves. | Tooltip: `You and both neighboring allies gain 5 Armor; a wounded target gains 2 more.` Log: `<actor> raised a wall of steel.` |

## Class 4: Field Medic

**Role:** Sustain and battlefield recovery specialist. **Rhythm:** Keep the party alive long enough to convert a tactical opening. **Weakness:** Lower direct offensive output. **Stats:** 19 Health, 4 Power, 6 Speed, 2 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Combat Patch | `HUM-FM-01` Active Opener; Armor/support; one ally below 75% HP; CD 1 | Grant the target 4 Armor. If the target is below half HP, it instead gains 6 Armor. The Medic immediately stabilizes a lane before it becomes fatal. | Rejects if the target is too healthy or cannot legally gain Armor. AI prefers the most threatened ally. Counterplay is to pressure the Medic before the wounded ally can be patched. | Tooltip: `An ally below 75% HP gains 4 Armor; below half HP, it gains 6 instead.` Log: `<actor> patched up <target>.` |
| Guarded Recovery | `HUM-FM-02` Active Converter; Armor/support; one ally with Armor; CD 2 | Grant the target 3 Armor. If the target already had Armor, it gains 5 instead. This turns existing protection into a stronger recovery window. | Rejects if the target has no legal Armor state or is an invalid ally. AI uses it on the most valuable protected unit. Counterplay is to strip Armor before the Medic can convert it. | Tooltip: `An ally with Armor gains 3 more; if it already had Armor, it gains 5 instead.` Log: `<actor> guarded <target>'s recovery.` |
| Hold the Wound | `HUM-FM-03` Active Pivot; Armor/support; all active allies below half HP; CD 5 | Each legal target gains 4 Armor. If at least two allies are below half HP, each target gains 6 Armor instead. This is the Medic's collapse-prevention capstone. | Rejects if no ally is below half HP. AI uses it when the line is about to fail. Counterplay is to prevent the health collapse from happening all at once or to force the Medic out of range. | Tooltip: `Wounded allies gain 4 Armor; if two or more are wounded, they gain 6 instead.` Log: `<actor> held the wound for the party.` |

## Class 5: Crosbowman

**Role:** Ranged control and discipline enforcer. **Rhythm:** Keep enemies in bad positions and force mistakes. **Weakness:** Needs line-of-sight and setup time. **Stats:** 20 Health, 6 Power, 6 Speed, 2 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Sightline Mark | `HUM-CC-01` Active Opener; offense/setup; one enemy; CD 1 | Deal 80% Power and apply Advantage until round end. The Captain opens with a clean mark that invites the next allied shot. | Rejects if the target is invalid. AI uses this on the enemy most likely to be converted by a teammate. Counterplay is to force token expiry before the team can capitalize. | Tooltip: `Deal 80% Power and apply Advantage until round end.` Log: `<actor> marked <target> for the line.` |
| Repeating Shot | `HUM-CC-02` Active Converter; offense/control; one enemy with Advantage or Snared; CD 2 | Deal 140% Power. If the target has Advantage, the shot consumes it and the hit rises to 170%. The Captain turns a marked target into a direct damage opportunity. | Rejects if the target has neither Advantage nor Snared. AI fires when an ally has already prepared the target. Counterplay is to keep the marked enemy out of line or force the Captain to shoot a different target. | Tooltip: `Deal 140% Power; if the target has Advantage, deal 170% instead.` Log: `<actor> repeated the shot into <target> for <damage>.` |
| Commanding Volley | `HUM-CC-03` Active Pivot; offense/control; up to two enemies; CD 5 | Choose up to two enemies. The first legal target takes 180% Power if it has Advantage; otherwise it takes 120%. The second legal target takes 120% Power. This is the Captain's lane-breaking capstone. | Rejects if neither target is legal. AI uses it to punish clustered or already-marked enemies. Counterplay is to keep the line spread or remove the setup token before the volley. | Tooltip: `Choose up to 2 enemies; the marked target takes 180%, others take 120%.` Log: `<actor> issued a commanding volley.` |

## Class 6: Duelist

**Role:** Close-range tactical finisher. **Rhythm:** Close the gap, punish the exposed target, and secure the kill. **Weakness:** Limited durability and poor opening against a proper front line. **Stats:** 21 Health, 8 Power, 7 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Cut the Distance | `HUM-DC-01` Active Opener; mobility/offense; self and one neighboring enemy; CD 1 | Move self 2 on a legal ring path, then deal 100% Power to a neighboring enemy at the new slot. If the target moved this round, the hit rises to 130%. The Commander opens by forcing contact. | Rejects if the move path or post-move target is illegal. AI uses it to close on a unit that already spent movement. Counterplay is to change occupancy so the chosen path no longer works. | Tooltip: `Move 2, then deal 100% Power to a neighboring enemy; moved targets take 130%.` Log: `<actor> cut the distance to <target> for <damage>.` |
| Counterstep | `HUM-DC-02` Active Converter; offense/reaction; one enemy that hit this unit or one adjacent ally this round; CD 2 | Deal 140% Power. If the target has Advantage or Snared, the hit rises to 170%. The Commander answers a bad exchange with a stronger strike. | Rejects if no qualifying enemy exists. AI prefers the enemy that overcommitted into the formation. Counterplay is to avoid giving the Commander a clean retaliatory window. | Tooltip: `Deal 140% Power to an enemy that hit you or an ally; marked targets take 170%.` Log: `<actor> counterstepped <target> for <damage>.` |
| Final Verdict | `HUM-DC-03` Active Pivot; offense/capstone; one enemy below half HP; CD 5 | Deal 210% Power. If the target has Advantage, the skill consumes it and rises to 240%. This is the Commander's finisher for a target that has already been opened. | Rejects if the target is above half HP or invalid. AI uses it only when the kill is realistic. Counterplay is to keep the target above threshold or remove the Advantage token before the Commander acts. | Tooltip: `Deal 210% Power to an enemy below half HP; with Advantage, deal 240% instead.` Log: `<actor> delivered the final verdict on <target>.` |

## Role Summary

| Class | Primary job | Signature fantasy |
|---|---|---|
| Vanguard | Front-line tactician | Command and control under pressure |
| Ranger | Ranged pressure | Precision target denial |
| Iron Sentinel | Defensive anchor | Resilience and field stability |
| Field Medic | Sustain specialist | Survival and rescue |
| Crosbowman | Control specialist | Distance and discipline |
| Duelist | Finisher | Close-range tactical kill pressure |

## Skill Delegation

These class sheets now contain complete three-skill packages. They are still design documents rather than runtime evidence, but the skill-level work is now explicit enough for implementation or QA handoff.
