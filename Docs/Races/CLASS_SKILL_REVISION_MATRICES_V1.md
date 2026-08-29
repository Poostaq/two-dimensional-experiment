# Class Skill Revision Matrices V1

Date: 2026-08-28

## Battle Rule Baseline

- Each side uses 6 slots.
- Regular units have 3 battle skills.
- Commander units keep the same 3 class skills and add 1 commander skill.
- Turn order is based on Speed.
- Equal Speed tie-break: Player side acts before Enemy side; Frontline slot acts before Backline slot.
- On turn, a unit selects exactly one option: one skill or one movement action.
- Movement is optional and primarily defensive, except Harpies where movement is a race gimmick.

---

## Set 1: Stationary-First Synergy Matrix

Design intent:
- Non-Harpies are mostly stationary.
- Movement is situational mitigation for most races.
- Harpies remain the core movement race.

### Goblins (Setup and Advantage Glue)

**Implementation reconciliation:** `Docs/Races/Goblins/Classes.md` is authoritative for Goblin names, targeting, timing, and lifecycle. Under the canonical contract, Advantage is applied to an enemy and consumed by the first eligible allied skill targeting that enemy. The concise matrix below reflects that retargeting but does not replace the full skill records.

| Class | Skill 1 | Skill 2 | Skill 3 |
|---|---|---|---|
| Scrapshield Bruiser | **Shield Tap (CD1):** 85% damage; if target attacked your ally this round, that ally gains 2 Armor. | **Pack Brace (CD2):** self and one adjacent ally gain 3 Armor. | **Banner Nudge (CD3):** apply Advantage to one enemy. |
| Wirefang Skirmisher | **Quick Mark (CD1):** 90% damage, then apply Advantage to the target. | **Cheap Finish (CD2):** 120% damage, or consume target Advantage for 160%. | **Slipstep (CD3):** optional self Move 1, then gain 2 Armor. |
| Snarewright | **Tripline Tag (CD1):** apply Snared; first later allied direct hit applies Advantage after damage. | **Holdfast Wire (CD2):** if target is Snared, deal 115% and reduce its Speed by 1 this round without consuming Snared. | **Ring Net (CD4):** apply Snared to up to 2 enemies. |
| Scrapbroker | **Spot Buyer (CD1):** apply Advantage to one enemy. | **Hand-Me-Down (CD2):** ally gains 4 Armor; if it consumed Advantage this round, +1 extra Armor. | **Emergency Kit (CD4):** ally below 50% HP gains 6 Armor. |
| Shivrunner | **Quick Nick (CD1):** 80% damage and apply 1 Bleed. | **Dirty Window (CD2):** 125% damage to Bleeding target; +20% if ally acted before Shivrunner this round. | **Collect Debt (CD4):** 175% damage to Bleeding target below 50% HP. |
| Mobcaller | **Point and Yell (CD1):** apply Advantage to one enemy. | **Dogpile Math (CD2):** 90% damage +20% per distinct allied attacker on target this round (max 150%). | **Louder Together (CD3):** apply Advantage to one enemy and grant a different-race ally +1 temporary Speed this round. |

### Orcs (Armor Contact and Discipline)

| Class | Skill 1 | Skill 2 | Skill 3 |
|---|---|---|---|
| Iron Tusk Vanguard | **Brace Line (CD1):** self + adjacent ally gain 4 Armor. | **Shield Ram (CD2):** 105% damage; if Vanguard has Armor, +20% damage. | **Hold the Gap (CD4):** self and up to 2 adjacent allies gain 4 Armor. |
| Bonebreaker Reaver | **Crushing Entry (CD1):** 110% damage. | **Break Formation (CD2):** 145% damage to target already hit by ally this round; +20% with Advantage. | **Execution Swing (CD4):** 190% damage to target below 50% HP, ignores Armor. |
| Bloodbanner Captain | **Plant Banner (CD2):** self + adjacent allies gain 3 Armor. | **Rally Strike (CD2):** 90% damage and one ally gains 3 Armor. | **Last Standard (CD5):** all allies gain 4 Armor if two allies are below 50% HP. |
| Chainwarden | **Chain Lash (CD1):** 75% damage and move enemy 1. | **Yank Back (CD3):** move enemy 2 if it was moved this round, then deal 95% damage. | **Lockdown (CD5):** Stun moved enemy (single target, bounded). |
| War Drummer | **Marching Beat (CD2):** grant one ally Advantage. | **Crushing Cadence (CD2):** 120% damage after ally hit same target this round. | **War Tempo (CD5):** all allies gain 3 Armor. |
| Siegebreaker | **Test the Plate (CD1):** remove up to 2 Armor, then deal 110% damage. | **Crack Armor (CD3):** remove up to 3 Armor, then 140% damage. | **Demolishing Blow (CD5):** 205% damage, ignores Armor. |

### Werewolves (Wounded-Target Hunt and Leech)

| Class | Skill 1 | Skill 2 | Skill 3 |
|---|---|---|---|
| Moonfang Skirmisher | **Scent Blood (CD1):** 80% damage; if target <70%, gain Advantage. | **Pounce Bite (CD2):** 135% damage to target <70%; 165% with Advantage. | **Moonfang Finish (CD4):** 185% damage to target <50%, Leech 35%. |
| Pack Howler | **Hunting Cry (CD2):** up to 2 allies gain Advantage while any enemy <70%. | **Pack Focus (CD2):** one ally gets +15% direct damage on next hit this round. | **Full-Moon Chorus (CD5):** allies' first direct hit this round Leeches 20%. |
| Bloodtrail Stalker | **Rake (CD1):** 90% damage + 1 Bleed. | **Trail Punish (CD2):** 120% damage to Bleeding target; +20% with Advantage. | **Cornered Prey (CD4):** 165% damage to Bleeding target with both adjacent enemy slots occupied. |
| Duskhide Ravager | **Reckless Claw (CD0):** 130% damage, self loses 10% max HP (cannot self-defeat). | **Feed Through Pain (CD2):** below 70% HP, deal 140% and Leech 40%. | **Frenzy Snap (CD5):** below 50% HP, deal 205% damage. |
| Den Warden | **Armor the Weak (CD1):** adjacent ally below 50% HP gains 5 Armor. | **Warning Snarl (CD2):** 130% damage to enemy that hit an Armored ally this round. | **Pack Intercept (CD4):** swap with any ally; both gain 3 Armor. |
| Moonblood Seer | **Foretell the Kill (CD1):** grant one ally Advantage. | **Red Moon Strike (CD2):** 120% damage to target <50%; with Advantage also Leech 25%. | **Eclipse Hunt (CD5):** chosen target <50%; allies gain +10% direct damage vs that target this round. |

### Lizardmen (Single-Axis Poison Planning)

| Class | Skill 1 | Skill 2 | Skill 3 |
|---|---|---|---|
| Venom Saurian | **Weakening Bite (CD1):** 80% damage + 1 Power Poison. | **Venom Pulse (CD2):** 100% damage and +1 stack to own Power Poison. | **Cold Finish (CD4):** 120% +20% per own Power Poison stack (max 180%). |
| Scale Sentinel | **Brace Scales (CD1):** gain 5 Armor. | **Tail Check (CD2):** 95% damage; if Sentinel has Armor, +20% damage. | **Layered Scales (CD4):** gain 8 Armor if current Armor <=2. |
| Mire Spitter | **Slowing Spit (CD1):** 70% damage + 1 Speed Poison. | **Bog Down (CD2):** add 1 own Speed Poison stack, then move target 1. | **Saturate Ground (CD4):** apply 1 Speed Poison to up to 3 enemies. |
| Fang Alchemist | **Corrosive Dose (CD1):** 70% damage + 1 Defense Poison. | **Catalyze (CD2):** 80% +20% per Poison stack on target (max 160%). | **Antidote Exchange (CD4):** transfer 1 Poison source from ally to enemy, preserving axis/duration. |
| Reed Ambusher | **Stillwater Focus (CD1):** if not moved this round, gain Advantage. | **Sudden Lunge (CD3):** Move up to 2 and deal 155% damage; 185% with Advantage. | **Reed Guard (CD3):** gain 4 Armor; if not moved since last action, also +1 Speed this round. |
| Sunscale Warder | **Warming Armor (CD1):** adjacent ally gains 4 Armor. | **Reflecting Scale (CD3):** spend up to 3 own Armor, deal 50% per Armor spent. | **Solar Bulwark (CD5):** all allies gain 4 Armor. |

### Harpies (Movement Gimmick Race)

| Class | Skill 1 | Skill 2 | Skill 3 |
|---|---|---|---|
| Talon Duelist | **Raking Pass (CD1):** Move 2 then deal 90% to neighboring enemy. | **Exploit Opening (CD2):** 150% to enemy forcibly moved this round. | **Wingbeat Retreat (CD3):** Move 2 and gain 4 Armor. |
| Storm Siren | **Gust Call (CD1):** move enemy 1, then grant ally Advantage. | **Crosswind Pull (CD3):** move enemy 2 then deal 100%. | **Eye of the Storm (CD5):** move enemy 3 (chosen shortest path). |
| Gale Scout | **Spot the Straggler (CD1):** move enemy 1 and grant ally Advantage. | **Diving Signal (CD2):** 110% to moved target; 150% with Advantage. | **Updraft Reposition (CD3):** move ally 2 and grant 2 Armor. |
| Skyhook Raider | **Hook and Lift (CD2):** move enemy 2 and grant ally Advantage. | **Drop Out of Line (CD2):** 160% to enemy moved 2+ this round. | **Snatch Away (CD5):** move enemy 3. |
| Nestguard | **Covering Wings (CD1):** adjacent ally gains 4 Armor. | **Warning Screech (CD2):** 130% to enemy that hit Armored ally this round. | **Rescue Flight (CD4):** swap with ally; both gain 3 Armor. |
| Carrion Cantor | **Cutting Note (CD1):** 90% and move enemy 1. | **Rending Chorus (CD2):** 110% +1 Bleed if target moved this round. | **Funeral Spiral (CD5):** Move 3, then hit up to 2 legal Bleeding path-neighbors for 80% each. |

---

## Set 2: Tempo/Burst Alternative Matrix

Design intent:
- Faster kill windows and stronger conversions.
- Non-Harpy movement still limited where possible.

### Goblins (Higher Tempo)

| Class | Skill 1 | Skill 2 | Skill 3 |
|---|---|---|---|
| Scrapshield Bruiser | **Scrap Jab (CD1):** 95% damage; if target has no Armor, grant adjacent ally 2 Armor. | **Hook Feint (CD2):** move enemy 1 and apply Exposed mark until round end. | **Pack Wall Order (CD3):** grant one ally Advantage and 1 Armor. |
| Wirefang Skirmisher | **Wire Cut (CD0):** Move 1 and gain Advantage. | **Cheap Shot (CD2):** 110%, or 165% with Advantage. | **Scuttle Shift (CD2):** Move 2 then deal 80% to new neighbor. |
| Snarewright | **Tripwire (CD1):** move enemy 1 and deal 70%. | **Reel In (CD2):** move enemy 2, then grant ally Advantage. | **Tangled Ring (CD4):** move up to 3 enemies 1 in declared order. |
| Scrapbroker | **Appraise Weakness (CD1):** grant ally Advantage. | **Hard Bargain (CD2):** ally gains 4 Armor, or 6 if it consumes Advantage this round. | **Emergency Parts (CD4):** ally below 50% HP gains 7 Armor. |
| Shivrunner | **Shiv Open (CD1):** 85% +1 Bleed. | **Slip Behind (CD2):** Move 2 then 120% to Bleeding enemy. | **Collect the Cut (CD4):** 180% to Bleeding target below 50%, remove 1 Bleed stack after hit. |
| Mobcaller | **Point and Yell (CD1):** grant one ally Advantage. | **Dogpile (CD2):** 90% +20% per distinct ally attacker on target (max 150%). | **Scatter! (CD4):** move up to 2 allies by 1. |

### Orcs (Hard Contact Burst)

| Class | Skill 1 | Skill 2 | Skill 3 |
|---|---|---|---|
| Iron Tusk Vanguard | **Plate Up (CD1):** gain 5 Armor. | **Shield Ram (CD2):** 100% and move enemy 1. | **Gap Command (CD4):** self + both adjacent allies gain 5 Armor. |
| Bonebreaker Reaver | **Crushing Entry (CD1):** 100% and move enemy 1. | **Break Formation (CD2):** 155% to moved or Stunned target. | **Execution Swing (CD4):** 200% to target below 50%, ignores Armor. |
| Bloodbanner Captain | **Plant Banner (CD2):** self + neighbors gain 3 Armor. | **Rally Strike (CD2):** 90% and one ally gains 3 Armor. | **Last Standard (CD5):** all allies gain 5 Armor if 2 allies below 50%. |
| Chainwarden | **Chain Lash (CD1):** 70% and move enemy 1. | **Yank Back (CD3):** move enemy 2 then deal 100%. | **Lockdown (CD5):** Stun moved target without Stun Guard. |
| War Drummer | **Marching Beat (CD2):** grant one ally Advantage. | **Crushing Cadence (CD2):** 120% after ally hit this round; 150% with Advantage. | **War Tempo (CD5):** all allies gain 3 Armor. |
| Siegebreaker | **Test the Plate (CD1):** remove 2 Armor then 110%. | **Crack Armor (CD3):** after Armor loss this round, remove 3 and deal 140%. | **Demolishing Blow (CD5):** 210%, ignores Armor. |

### Werewolves (Aggressive Execute Package)

| Class | Skill 1 | Skill 2 | Skill 3 |
|---|---|---|---|
| Moonfang Skirmisher | **Scent Blood (CD1):** 70% and self Advantage vs target <70%. | **Pounce (CD2):** Move 2 then 140% vs target <70%. | **Moonfang Finish (CD4):** 190% vs target <50%, Leech 35%. |
| Pack Howler | **Hunting Cry (CD2):** up to 2 allies gain Advantage if any enemy <70%. | **Drive the Pack (CD3):** move up to 2 allies by 1. | **Full-Moon Chorus (CD5):** allies' first direct hit this round Leeches 25%. |
| Bloodtrail Stalker | **Rake (CD1):** 90% +1 Bleed. | **Follow the Trail (CD2):** Move 2 then 120% to Bleeding enemy. | **Cornered Prey (CD4):** 170% +1 Bleed to enclosed Bleeding target. |
| Duskhide Ravager | **Reckless Claw (CD0):** 130%, self-cost 10% max HP. | **Feed Through Pain (CD2):** below 70%, 140% and Leech 40%. | **Frenzied Lunge (CD5):** below 50%, Move 2 then 210%. |
| Den Warden | **Armor the Weak (CD1):** adjacent ally below 50% gains 5 Armor. | **Warning Snarl (CD2):** 130% to enemy that hit Armored ally this round. | **Pack Intercept (CD4):** swap with ally; both gain 3 Armor. |
| Moonblood Seer | **Foretell the Kill (CD1):** grant ally Advantage. | **Red Moon Strike (CD2):** 120% vs <50%; with Advantage 150% + Leech 25%. | **Eclipse Hunt (CD5):** this round allies may Move 1 before first attack on chosen <50% target. |

### Lizardmen (Poison Pressure Package)

| Class | Skill 1 | Skill 2 | Skill 3 |
|---|---|---|---|
| Venom Saurian | **Weakening Bite (CD1):** 80% +1 Power Poison. | **Venom Pulse (CD2):** 100% and +1 Power Poison stack. | **Cold Finish (CD4):** 120% +20% per Power Poison stack (max 180%). |
| Scale Sentinel | **Brace Scales (CD1):** gain 5 Armor. | **Tail Check (CD2):** 90% and move enemy 1. | **Layered Scales (CD4):** gain 8 Armor when Armor is low. |
| Mire Spitter | **Slowing Spit (CD1):** 70% +1 Speed Poison. | **Bog Down (CD2):** +1 Speed Poison and move target 1. | **Saturate Ground (CD4):** apply 1 Speed Poison to up to 3 enemies. |
| Fang Alchemist | **Corrosive Dose (CD1):** 70% +1 Defense Poison. | **Catalyze (CD2):** 80% +20% per total Poison stack (max 160%). | **Antidote Exchange (CD4):** move one Poison source from ally to enemy. |
| Reed Ambusher | **Stillwater Focus (CD1):** if unmoved this round, gain Advantage. | **Sudden Lunge (CD3):** Move 3 then 160%; 190% with Advantage. | **Vanish into Reeds (CD3):** Move 2 and gain 4 Armor. |
| Sunscale Warder | **Warming Armor (CD1):** adjacent ally gains 4 Armor. | **Reflecting Scale (CD3):** spend up to 3 Armor for damage conversion. | **Solar Bulwark (CD5):** all allies gain 4 Armor. |

### Harpies (High Mobility Package)

| Class | Skill 1 | Skill 2 | Skill 3 |
|---|---|---|---|
| Talon Duelist | **Raking Pass (CD1):** Move 2 then 90%. | **Exploit Opening (CD2):** 150% to forcibly moved target. | **Wingbeat Retreat (CD3):** Move 2 and gain 4 Armor. |
| Storm Siren | **Gust Call (CD1):** move enemy 1 and grant ally Advantage. | **Crosswind Pull (CD3):** move enemy 2 then 100%. | **Eye of the Storm (CD5):** move enemy 3. |
| Gale Scout | **Spot the Straggler (CD1):** move enemy 1, grant ally Advantage. | **Diving Signal (CD2):** 110% vs moved target, 150% with Advantage. | **Updraft Reposition (CD3):** move ally 2 and grant 2 Armor. |
| Skyhook Raider | **Hook and Lift (CD2):** move enemy 2 and grant ally Advantage. | **Drop Out of Line (CD2):** 160% to enemy moved 2+ this round. | **Snatch Away (CD5):** move enemy 3. |
| Nestguard | **Covering Wings (CD1):** adjacent ally gains 4 Armor. | **Warning Screech (CD2):** 130% retaliation vs attacker of Armored ally. | **Rescue Flight (CD4):** swap with ally; both gain 3 Armor. |
| Carrion Cantor | **Cutting Note (CD1):** 90% and move enemy 1. | **Rending Chorus (CD2):** 110% +1 Bleed if target moved this round. | **Funeral Spiral (CD5):** Move 3 and hit up to 2 Bleeding path-neighbors. |

---

## Commander Notes (Applies to Both Sets)

Each commander adds one 4th skill that reinforces race identity and team synergy.

| Race | Commander Theme | 4th Commander Skill Direction |
|---|---|---|
| Goblins | Tempo director | Advantage distribution and cooldown sequencing |
| Orcs | Contact stabilizer | Armor and anti-collapse frontline control |
| Werewolves | Execute caller | Threshold timing and Leech window extension |
| Lizardmen | Axis planner | Poison-axis consistency and conversion reliability |
| Harpies | Flight controller | Movement-trigger chaining and angle creation |

## Reading Guide

- Set 1 is the safer baseline for stationary-first combat.
- Set 2 is the higher-pressure alternative for faster battles.
- Harpies intentionally remain movement-heavy in both sets.
- For strict stationary compliance, keep non-Harpies at 0-1 movement-coupled skill per class.

---

## Hard Constraint Update: Enemy Movement Must Be Rare

Date: 2026-08-28

This addendum overrides any earlier row text where needed.

### Global caps

- Non-Harpy races: enemy displacement effects are capped at 1 skill per race per set.
- Harpies: enemy displacement effects are capped at 1 class per role family, with no more than 4 enemy-displacement skills total in a set.
- Any enemy displacement skill must have CD 3+ unless it is the single designated Harpy opener in that set.
- No commander skill may directly displace enemies.

### Approved enemy-displacement anchors per set

- Set 1 anchors:
	- Goblins: none.
	- Orcs: Chainwarden keeps exactly one enemy displacement skill.
	- Werewolves: none.
	- Lizardmen: none.
	- Harpies: Storm Siren and Skyhook Raider keep enemy displacement as race gimmick anchors.
- Set 2 anchors:
	- Goblins: Snarewright keeps exactly one enemy displacement skill.
	- Orcs: Chainwarden keeps exactly one enemy displacement skill.
	- Werewolves: none.
	- Lizardmen: none.
	- Harpies: Storm Siren and Skyhook Raider keep enemy displacement as race gimmick anchors.

### Replacement rulebook (apply to both sets)

If a skill text says "move enemy" and the skill is not in the approved anchors above, replace that clause using one of these templates:

- Replace with **Expose**: "Apply Exposed until end of round. First allied direct hit consumes Exposed for +20% damage."
- Replace with **Stagger**: "Apply Staggered for 1 action. Target loses 1 Speed for unresolved queue order only."
- Replace with **Pin**: "Target cannot gain Advantage until end of round."
- Replace with **Brace Break**: "Remove up to 2 Armor before damage."

### Concrete substitutions for current matrix rows

- Set 1:
	- Orc Chainwarden:
		- Chain Lash -> **Chain Lash**: 75% damage and apply Exposed (no movement).
		- Yank Back -> **Yank Back**: 95% damage; if target is Exposed, +25% damage (no movement).
		- Lockdown -> keep Stun as the class specialist control, but remove moved-target requirement.
	- Lizardmen Mire Spitter:
		- Bog Down -> **Bog Down**: add 1 own Speed Poison stack and apply Staggered for 1 action (no movement).
	- Harpies Gale Scout:
		- Spot the Straggler -> keep ally-setup, replace enemy move with Exposed.
	- Harpies Carrion Cantor:
		- Cutting Note -> 90% plus Exposed (no enemy movement).

- Set 2:
	- Goblins:
		- Scrapshield Hook Feint -> Exposed (no enemy movement).
		- Wirefang Scuttle Shift -> self Move 1 optional, no enemy movement.
		- Shivrunner Slip Behind -> self Move 1 optional, no enemy movement requirement.
		- Mobcaller Scatter! -> ally-only reposition remains allowed; no enemy movement.
	- Orcs:
		- Iron Tusk Shield Ram -> keep damage/Armor synergy, remove enemy movement.
		- Bonebreaker Crushing Entry -> keep damage opener, remove enemy movement.
		- Chainwarden retains one displacement anchor only: Chain Lash keeps enemy move 1; Yank Back becomes Exposed payoff.
	- Werewolves:
		- Any enemy-move prerequisite is converted to Bleed or Wounded-threshold prerequisite.
	- Lizardmen:
		- Tail Check and Bog Down remove enemy movement and use Staggered/Expose alternatives.
	- Harpies:
		- Keep enemy movement on Storm Siren and Skyhook Raider only.
		- Talon, Gale, and Cantor convert enemy-move clauses to Exposed or self-reposition clauses.

### Validation checklist

- Enemy displacement appears only in approved anchor classes.
- Total enemy-displacement skills per set are <= 8 (mostly Harpy-owned).
- Non-Harpy sets preserve race identity through Armor, Advantage, Leech, Poison, and thresholds rather than displacement.
