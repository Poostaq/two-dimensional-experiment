# Orc Classes

## Reading the Skill Records

All skills inherit the shared mechanics contract. `CD N` is post-use cooldown in successful owning-side actions. Unstated duration, stacks, reapplication, movement, and Advantage are `None`; cleanup occurs at battle end; changed or invalid previews reject atomically; AI requires all listed effects to be legal; standard rounding applies. UI cells give exact tooltip and log text.

## Class 1: Iron Tusk Vanguard

**Role:** Defensive anchor. **Rhythm:** Brace, make contact, deny escape. **Weakness:** Minimal reach and damage. **Stats:** 30 Health, 5 Power, 2 Speed, 5 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Brace Line | Active Opener; Armor; self and ring-neighbor ally; front half; CD 1 | Self and ally each gain 4 Armor, additive to cap 10 | Reject no neighbor or both pools full; AI protects threatened ally; counter with status or repeated damage | Tooltip: `You and a neighboring ally each gain 4 Armor.` Log: `<actor> braced with <ally>; both gained 4 Armor.` |
| Shield Ram | Active Converter; offense/control; neighboring enemy; CD 2 | Deal 100% Power and rotate target Move 1; Advantage rider deals 140% | Reject illegal path; AI chooses contact-preserving path; counter by changing occupancy | Tooltip: `Deal 100% Power and move an enemy 1; with Advantage, deal 140%.` Log: `<actor> rammed <target> for <damage> and moved it 1.` |
| Hold the Gap | Active Pivot; Armor; self and both ring-neighbor allies; CD 4 | Each legal target gains 5 Armor, additive to cap 10 | Reject fewer than two targets able to gain Armor; AI fortifies a full line; counter with status damage | Tooltip: `You and both neighboring allies each gain 5 Armor.` Log: `<actor> held the gap; <targets> gained 5 Armor.` |
| Unbroken Contact | Passive Signature; Armor; round end while neighboring an enemy | Gain 2 Armor; once per round | No enemy neighbor, no trigger; AI maintains contact; counter by rotating Orc away | Tooltip: `Once per round, end beside an enemy to gain 2 Armor.` Log: `<actor>'s contact granted 2 Armor.` |

## Class 2: Bonebreaker Reaver

**Role:** Disabled-target bruiser. **Rhythm:** Open a wound, exploit control, execute. **Weakness:** Few defensive tools. **Stats:** 26 Health, 8 Power, 4 Speed, 2 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Crushing Entry | Active Opener; offense/control; neighboring enemy; CD 1 | Deal 100% Power and rotate target Move 1 | Reject no legal path; AI moves target into Orc contact; counter by changing occupancy | Tooltip: `Deal 100% Power and move a neighboring enemy 1.` Log: `<actor> crushed into <target> for <damage> and moved it 1.` |
| Break Formation | Active Converter; offense; enemy forcibly moved or Stunned this round; CD 2 | Deal 150% Power; Advantage rider deals 180% | Reject without condition; AI follows controller; counter by preventing movement/Stun | Tooltip: `Deal 150% Power to an enemy moved or Stunned this round.` Log: `<actor> broke <target>'s formation for <damage>.` |
| Execution Swing | Active Pivot; offense/capstone; enemy below half HP; front half; CD 4 | Deal 200% Power, ignoring Armor | Reject threshold/position; AI uses when lethal; counter with Defense or rotation | Tooltip: `From the front, deal 200% Power to an enemy below half HP, ignoring Armor.` Log: `<actor> executed a swing on <target> for <damage>.` |
| No Escape | Passive Signature; Armor; first attack each round against a moved or Stunned enemy | Gain 2 Armor after the attack; once per round | No qualifying enemy, no trigger; AI follows control; counter by denying setup | Tooltip: `Once per round after attacking a moved or Stunned enemy, gain 2 Armor.` Log: `<actor>'s No Escape granted 2 Armor.` |

## Class 3: Bloodbanner Captain

**Role:** Formation support. **Rhythm:** Plant support, reinforce contact, prevent collapse. **Weakness:** Low personal output. **Stats:** 28 Health, 5 Power, 3 Speed, 4 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Plant Banner | Active Opener; Armor/support; self plus ring neighbors; CD 2 | Each legal target gains 3 Armor | Reject no ally able to gain Armor; AI catches two allies; counter with status damage | Tooltip: `You and neighboring allies each gain 3 Armor.` Log: `<actor> planted the banner; <targets> gained 3 Armor.` |
| Rally Strike | Active Converter; offense/Armor; one enemy and one ally; CD 2 | Deal 90% Power; chosen ally gains 3 Armor; Advantage rider grants 5 | Reject no ally able to gain Armor; AI protects threatened ally; counter by focusing elsewhere | Tooltip: `Deal 90% Power and grant an ally 3 Armor; with Advantage, grant 5.` Log: `<actor> struck <target> and granted <ally> <amount> Armor.` |
| Last Standard | Active Pivot; Armor/capstone; all allies; two below half HP; CD 5 | Every active ally gains 5 Armor | Reject unless two allies are below half; AI uses under collapse; counter with status damage | Tooltip: `If two allies are below half HP, all allies gain 5 Armor.` Log: `<actor> raised the Last Standard; <allies> gained 5 Armor.` |
| Discipline of the Line | Passive Signature; Armor; first ally ending an action beside Captain each round | That ally gains 2 Armor; once per round | No neighbor able to gain Armor, no trigger; AI anchors center; counter by rotation | Tooltip: `Once per round, an ally ending beside you gains 2 Armor.` Log: `<actor>'s discipline granted <ally> 2 Armor.` |

## Class 4: Chainwarden

**Role:** Forced-movement controller. **Rhythm:** Move a target, drag it farther, spend one Stun window. **Weakness:** Long cooldowns and Stun Guard. **Stats:** 27 Health, 4 Power, 4 Speed, 4 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Chain Lash | Active Opener; control/offense; one enemy; CD 1 | Deal 70% Power and rotate target Move 1 | Reject no path; AI moves mobile enemy; counter by changing occupancy | Tooltip: `Deal 70% Power and move an enemy 1.` Log: `<actor> lashed <target> for <damage> and moved it 1.` |
| Yank Back | Active Converter; control/offense; enemy moved this round; CD 3 | Rotate target Move 2, then deal 100% Power | Reject no prior movement/path; AI pulls into Orc contact; counter by preventing first movement | Tooltip: `Move an already-moved enemy 2, then deal 100% Power.` Log: `<actor> yanked <target> along <path> for <damage>.` |
| Lockdown | Active Pivot; Stun; enemy moved this round without Stun Guard; front half; CD 5 | Apply canonical Stun | Reject boss immunity, Stun Guard, no movement, or position; AI targets imminent actor; counter with Stun Guard | Tooltip: `Stun one enemy moved this round.` Log: `<actor> locked down <target>.` |
| Short Leash | Passive Signature; movement; first enemy forcibly moved each round | Rotate Warden Move 1 toward its new slot if legal; once per round | No legal self path, no trigger; AI follows reachable target; counter by choosing the other path | Tooltip: `Once per round after an enemy is forcibly moved, move 1 toward it.` Log: `<actor>'s Short Leash moved it 1 toward <target>.` |

## Class 5: War Drummer

**Role:** Formation cadence support. **Rhythm:** Stabilize speed, strike on cadence, accelerate unresolved allies. **Weakness:** Benefits predictable formations, not initiative theft. **Stats:** 24 Health, 4 Power, 5 Speed, 3 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Marching Beat | Active Opener; Advantage/support; one ally; CD 2 | Grant chosen ally Advantage | Reject no eligible rider; AI chooses unresolved ally; counter by forcing expiry | Tooltip: `Grant one eligible ally Advantage until round end.` Log: `<actor>'s Marching Beat granted <ally> Advantage.` |
| Crushing Cadence | Active Converter; offense; enemy hit by ally this round; CD 2 | Deal 120% Power; Advantage rider deals 150% | Reject no prior hit; AI follows ally; counter by spreading targets | Tooltip: `After an ally hits, deal 120% Power; with Advantage, deal 150%.` Log: `<actor> struck <target> on cadence for <damage>.` |
| War Tempo | Active Pivot; Armor/support; all allies; CD 5 | Each active ally gains 3 Armor | Reject fewer than two allies able to gain Armor; AI uses before retaliation; counter with status damage | Tooltip: `All active allies gain 3 Armor.` Log: `<actor> raised War Tempo; <allies> gained 3 Armor.` |
| Keep the Measure | Passive Signature; Armor; second neighboring allied action each round | Drummer gains 3 Armor; once per round | Fewer than two neighboring actions, no trigger; AI stays central; counter by rotation | Tooltip: `Once per round after two neighboring allies act, gain 3 Armor.` Log: `<actor> kept the measure and gained 3 Armor.` |

## Class 6: Siegebreaker

**Role:** Anti-Armor heavy striker. **Rhythm:** Test Armor, break its remaining points, finish under contact. **Weakness:** Slowest Orc and easy to rotate away. **Stats:** 25 Health, 8 Power, 2 Speed, 3 Defense.

| Skill | Record | Effect and lifecycle | Failure, AI, counterplay | UI text |
|---|---|---|---|---|
| Test the Plate | Active Opener; offense/Armor; neighboring enemy; CD 1 | Remove up to 2 enemy Armor, then deal 110% Power | Reject no neighbor; AI targets highest Armor; counter by rotating target | Tooltip: `Remove up to 2 Armor, then deal 110% Power.` Log: `<actor> broke <removed> Armor and hit <target> for <damage>.` |
| Crack Armor | Active Converter; offense/Armor; enemy that lost Armor this round; CD 3 | Remove up to 3 Armor, then deal 140% Power; Advantage rider removes up to 5 | Reject no prior Armor loss; AI focuses armored target; counter by spending Armor earlier | Tooltip: `After Armor is lost, remove up to 3 more and deal 140% Power.` Log: `<actor> cracked <removed> Armor and dealt <damage> to <target>.` |
| Demolishing Blow | Active Pivot; offense/capstone; neighboring enemy; CD 5 | Deal 210% Power, ignoring Armor | Reject no contact; AI seeks lethal armored target; counter with Defense or rotation | Tooltip: `Deal 210% Power to a neighboring enemy, ignoring Armor.` Log: `<actor> demolished <target> for <damage>.` |
| Weight Behind It | Passive Signature; Armor; first consecutive-round attack on same enemy | Gain 3 Armor after attack; once per round | Target changed/no prior-round attack, no trigger; AI persists; counter by rotating target | Tooltip: `Once per round after attacking the same enemy in consecutive rounds, gain 3 Armor.` Log: `<actor>'s weight granted 3 Armor.` |

## Role Summary

| Class | Primary job | Signature mechanic |
|---|---|---|
| Iron Tusk Vanguard | Anchor | Contact protection |
| Bonebreaker Reaver | Bruiser | Moved/Stunned-target payoff |
| Bloodbanner Captain | Support | Group Armor |
| Chainwarden | Controller | Forced movement and bounded Stun |
| War Drummer | Cadence support | Local unresolved Speed |
| Siegebreaker | Specialist striker | Armor destruction and bypass |
