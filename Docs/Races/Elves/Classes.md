# Elf Classes

## Reading the Skill Records

All Elf classes follow the shared battle contract in the project docs. Each class below is now written as a complete three-skill package that preserves the race’s identity as the coalition’s ranged and magical precision force.

## Class 1: Star Archer

**Role:** Precision ranged striker and distance specialist. **Rhythm:** Control the line, punish exposure, and convert a clean angle into decisive damage. **Weakness:** Fragile if forced into direct melee. **Stats:** 16 Health, 7 Power, 8 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Threaded Aim | `ELF-SA-01` Active Opener; offense/setup; one enemy; CD 1 | Deal 90% Power and apply Advantage until round end. This establishes the clean shot the rest of the elf line can convert. | Rejects if the target is invalid. AI opens on the enemy most likely to be converted by the next ally. Counterplay is to force the token to expire before another elf acts. | Tooltip: `Deal 90% Power and apply Advantage until round end.` Log: `<actor> threaded aim into <target>.` |
| Needle Shot | `ELF-SA-02` Active Converter; offense; one enemy with Advantage; CD 2 | Deal 140% Power. If the target moved this round, the hit rises to 170%. This is the class's most reliable damage conversion after a successful setup. | Rejects if the target has no Advantage. AI prefers a target that already moved or already took a risky position. Counterplay is to keep the target out of the open or consume the token before the shot lands. | Tooltip: `Deal 140% Power to an enemy with Advantage; moved targets take 170%.` Log: `<actor> drilled <target> with a needle shot.` |
| Horizon Pierce | `ELF-SA-03` Active Pivot; offense/capstone; one enemy with Advantage or Snared; CD 5 | Deal 200% Power. If the target has Advantage, consume it and deal 230% instead. The Archer’s finisher rewards disciplined setup and line control. | Rejects if the target has neither Advantage nor Snared. AI uses it on the clearest exposed target. Counterplay is to keep the target from carrying both setup states into the same round. | Tooltip: `Deal 200% Power; with Advantage, deal 230% instead.` Log: `<actor> pierced the horizon through <target>.` |

## Class 2: Moon Sage

**Role:** Arcane controller and burst mage. **Rhythm:** Force bad spacing and convert it into magical pressure. **Weakness:** Weaker when the enemy closes distance too quickly. **Stats:** 15 Health, 7 Power, 7 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Silver Sigil | `ELF-MS-01` Active Opener; offense/control; one enemy; CD 1 | Deal 70% Power and apply Snared until round end. The Sage lays down a magical anchor that keeps the target readable. | Rejects if the target is invalid. AI uses it against a target that wants to reposition. Counterplay is to move before the Sage can convert the mark. | Tooltip: `Deal 70% Power and apply Snared until round end.` Log: `<actor> placed a silver sigil on <target>.` |
| Lunar Thread | `ELF-MS-02` Active Converter; offense/control; one enemy with Snared; CD 2 | Deal 120% Power. If the target moved this round, the hit rises to 150%. The Sage turns the pinned target into magical pressure and timing control. | Rejects if the target is not Snared. AI uses it after the opener or after an allied trap effect. Counterplay is to break the follow-up path or force the mark to expire. | Tooltip: `Deal 120% Power to a Snared enemy; moved targets take 150%.` Log: `<actor> threaded lunar power through <target>.` |
| Crescent Collapse | `ELF-MS-03` Active Pivot; offense/capstone; one enemy with Snared or Advantage; CD 5 | Deal 210% Power. If the target has both Snared and Advantage, consume the Advantage and deal 240% instead. This is the Sage's major burst window. | Rejects if the target lacks both setup states. AI saves it for a target already trapped by the party. Counterplay is to deny the overlap between the two setup states or force the target to relocate. | Tooltip: `Deal 210% Power; with Snared and Advantage, deal 240% instead.` Log: `<actor> collapsed the crescent on <target>.` |

## Class 3: Wind Dancer

**Role:** Mobility and repositioning specialist. **Rhythm:** Control spacing, create windows, and escape danger through movement. **Weakness:** Lower durability and weaker direct heavy damage. **Stats:** 14 Health, 6 Power, 9 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Step Through Wind | `ELF-WD-01` Active Opener; mobility/Armor; self; CD 1 | Move self 2 on a legal ring path. If the Dancer ends in a different slot than it started, it gains 2 Armor. This is the class's most direct self-preservation tool. | Rejects if the path is illegal. AI uses it to escape contact or to open a better angle for the next action. Counterplay is to control the destination slot or force the Dancer into a dead path. | Tooltip: `Move 2; if you end in a new slot, gain 2 Armor.` Log: `<actor> stepped through the wind.` |
| Arc of Escape | `ELF-WD-02` Active Converter; mobility/control; enemy moved this round; CD 2 | Deal 120% Power. If the enemy has Advantage, the hit rises to 150%. The Dancer turns enemy motion into a punished opening while staying mobile itself. | Rejects if the target did not move this round. AI uses it on the enemy that was already displaced by another fighter. Counterplay is to avoid creating the movement trigger before the Dancer acts. | Tooltip: `Deal 120% Power to an enemy moved this round; Advantage targets take 150%.` Log: `<actor> escaped through <target> and struck back.` |
| Spiral Opening | `ELF-WD-03` Active Pivot; mobility/offense; self and one neighboring enemy; CD 5 | Move self 3 on a legal ring path, then deal 170% Power to a neighboring enemy at the destination. If the Dancer crossed an occupied path, the target also gains Snared until round end. This is the class’s high-mobility finish. | Rejects if the path or post-move target is illegal. AI uses it to reach a distant opening. Counterplay is to break the path or occupy the slots the Dancer wants. | Tooltip: `Move 3, then deal 170% Power to a neighboring enemy; occupied paths can Snare.` Log: `<actor> opened a spiral through <target>.` |

## Class 4: Warden of the Grove

**Role:** Defensive support and protective control caster. **Rhythm:** Keep the line stable while preserving fragile allies. **Weakness:** Moderate direct offensive ceiling. **Stats:** 18 Health, 4 Power, 6 Speed, 2 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Rooting Ward | `ELF-WG-01` Active Opener; Armor/support; one ally; CD 1 | Grant the target 4 Armor. If the target is adjacent to an enemy, that enemy also gains Snared until round end. The Warden protects and simultaneously makes the contact lane easier to read. | Rejects if the target cannot legally gain Armor. AI uses it on the ally most likely to be pressured. Counterplay is to remove adjacency or force the warded ally away from the contact lane. | Tooltip: `An ally gains 4 Armor; adjacent enemies may gain Snared.` Log: `<actor> rooted a ward around <target>.` |
| Calm the Ring | `ELF-WG-02` Active Converter; control; one enemy moved this round; CD 2 | Deal 90% Power and move the target 1 on a legal path. If the enemy has Advantage, the move still resolves and the hit rises to 120%. The Warden re-centers the battlefield. | Rejects if the target did not move this round. AI uses it against a unit that overextended or was already displaced. Counterplay is to keep the target stationary or to deny a valid ring path. | Tooltip: `Deal 90% Power to a moved enemy and move it 1; Advantage targets take 120%.` Log: `<actor> calmed the ring around <target>.` |
| Dawnglass Barrier | `ELF-WG-03` Active Pivot; Armor/support; all active allies; CD 5 | Every active ally gains 4 Armor. If two or more allies are below half HP, every active ally gains 6 Armor instead. This is the Warden's major formation-reset button. | Rejects only if no ally can legally gain Armor. AI uses it when the line is about to collapse. Counterplay is to pressure the party unevenly so the barrier is weaker or to force the Warden out of range. | Tooltip: `All active allies gain 4 Armor; if two or more are wounded, they gain 6 instead.` Log: `<actor> raised a dawnglass barrier.` |

## Class 5: Crescent Duelist

**Role:** Melee precision specialist with strong mobility. **Rhythm:** Close the gap, punish a bad angle, and finish a vulnerable target. **Weakness:** Very fragile if not allowed to reposition. **Stats:** 17 Health, 7 Power, 8 Speed, 1 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Cut the Angle | `ELF-CD-01` Active Opener; mobility/offense; self and one neighboring enemy; CD 1 | Move self 2 on a legal path, then deal 100% Power to a neighboring enemy at the destination. If the target moved this round, the hit rises to 130%. This is the Duelist's clean entry tool. | Rejects if the path or post-move target is illegal. AI uses it to reach a weak side lane. Counterplay is to change occupancy so the destination no longer supports the attack. | Tooltip: `Move 2, then deal 100% Power to a neighboring enemy; moved targets take 130%.` Log: `<actor> cut the angle on <target>.` |
| Short Arc | `ELF-CD-02` Active Converter; offense; one enemy with Advantage or Snared; CD 2 | Deal 150% Power. If the Duelist moved this round, the hit rises to 180% and the Duelist gains 2 Armor. The skill rewards clean repositioning and then cashes out the opening. | Rejects if the target lacks Advantage or Snared. AI uses it after a movement opener. Counterplay is to keep the target from carrying either setup state or to force the Duelist out of an efficient path. | Tooltip: `Deal 150% Power; if you moved this round, deal 180% and gain 2 Armor.` Log: `<actor> traced a short arc through <target>.` |
| Final Flourish | `ELF-CD-03` Active Pivot; offense/capstone; one enemy below half HP; CD 5 | Deal 210% Power. If the target has Advantage, consume it and deal 240% instead. The Duelist finishes wounded enemies with precision rather than brute force. | Rejects if the target is above half HP. AI uses it only when the kill window is clean. Counterplay is to keep the target just above threshold or remove the Advantage token before the Duelist acts. | Tooltip: `Deal 210% Power to an enemy below half HP; with Advantage, deal 240% instead.` Log: `<actor> delivered the final flourish on <target>.` |

## Class 6: Highborn Mystic

**Role:** Elite control and magical burst specialist. **Rhythm:** Layer magical disruption and convert it into huge tactical windows. **Weakness:** Lower sustained durability and heavy reliance on line control. **Stats:** 16 Health, 8 Power, 7 Speed, 0 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Glyph of Silence | `ELF-HM-01` Active Opener; offense/control; one enemy; CD 1 | Deal 70% Power and apply Snared until round end. The Mystic begins by placing a magical glyph that makes the target easier to pin in place. | Rejects if the target is invalid. AI uses it on a unit that wants to reposition or chain into another action. Counterplay is to move before the glyph can be converted. | Tooltip: `Deal 70% Power and apply Snared until round end.` Log: `<actor> inscribed a glyph of silence on <target>.` |
| Echoed Star | `ELF-HM-02` Active Converter; offense/control; one enemy with Snared; CD 2 | Deal 130% Power. If the target already has Advantage, the hit rises to 160%. The Mystic turns a pinned target into a large tactical window. | Rejects if the target is not Snared. AI uses it after the opener or after a team setup move. Counterplay is to avoid leaving the same target marked for the follow-up. | Tooltip: `Deal 130% Power to a Snared enemy; Advantage targets take 160%.` Log: `<actor> echoed a star through <target>.` |
| Final Constellation | `ELF-HM-03` Active Pivot; offense/capstone; up to two enemies, at least one Snared; CD 5 | Choose up to two enemies. The primary target takes 190% Power. If both targets are Snared, the primary target instead takes 230%. The secondary target takes 120% Power. This is the Mystic's highest-value burst and control window. | Rejects if none of the targets are legal or if no chosen target is Snared. AI uses it on clustered enemies or on a target that the rest of the party already trapped. Counterplay is to remove the Snared state or spread the formation. | Tooltip: `Choose up to 2 enemies; the primary takes 190% Power, or 230% if both are Snared.` Log: `<actor> completed the final constellation.` |

## Role Summary

| Class | Primary job | Signature fantasy |
|---|---|---|
| Star Archer | Ranged pressure | Precision and angle control |
| Moon Sage | Magical control | Elegant arcane disruption |
| Wind Dancer | Mobility | Positioning and escape |
| Warden of the Grove | Protective support | Stability and control |
| Crescent Duelist | Melee precision | Fast execution and mobility |
| Highborn Mystic | Elite burst control | Magical finish and tactical denial |

## Skill Delegation

The Elf roster now has full three-skill packages for every class. The remaining Skill and Progression Designer pass can focus on exact tuning rather than inventing the class identities from scratch.
