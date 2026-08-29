# Goblin Classes — Set 1

## Authority

This is the implementation-target Goblin roster. It reconciles Set 1 from `CLASS_SKILL_REVISION_MATRICES_V1.md` with the current `SkillAuthoringContract.md` and enemy-debuff Advantage contract in `SkillKeywords.md`.

These are design requirements, not shipped-behavior claims. As of 2026-08-29 the Goblin catalog, keyword states, reactions, and skill-specific queue rebuilds described here have no AC6 implementation evidence.

Regular units have exactly three battle skills. Commanders retain their root class's three skills and add one commander skill. Movement is an optional defensive action for Goblins, not their primary combat identity. No Goblin skill directly displaces an enemy.

`CD N` means a post-use cooldown of N successful owning-side actions. Unless stated otherwise, effects expire at battle end; invalid or stale targets reject atomically; damage uses the shared physical-damage formula; Advantage and Snared are non-stacking and expire at round end.

## Scrapshield Bruiser

**Role:** Nuisance anchor and adjacent protector. **Weakness:** Low damage and tempo. **Stats:** 20 Health, 4 Power, 7 Speed, 2 Defense.

| Skill | Contract |
|---|---|
| **Shield Tap (CD1)** | Active; one enemy. Deal 85% Power. If that enemy directly attacked one of the Bruiser's active allies earlier this round, that ally gains 2 Armor. Tooltip: `Deal 85% Power. If this enemy attacked an ally this round, that ally gains 2 Armor.` |
| **Pack Brace (CD2)** | Active; self and one active adjacent ally. Both gain 3 Armor. Reject without a legal adjacent ally. Tooltip: `You and one adjacent ally gain 3 Armor.` |
| **Banner Nudge (CD3)** | Active; one enemy. Apply Advantage until round end. Tooltip: `Apply Advantage to one enemy until round end.` |

## Wirefang Skirmisher

**Role:** Fast setup striker. **Weakness:** Extremely fragile. **Stats:** 14 Health, 6 Power, 10 Speed, 0 Defense.

| Skill | Contract |
|---|---|
| **Quick Mark (CD1)** | Active; one enemy. Deal 90% Power, then apply Advantage until round end. The damaging hit resolves before application and cannot consume the newly applied token. Tooltip: `Deal 90% Power, then apply Advantage until round end.` |
| **Cheap Finish (CD2)** | Active; one enemy. Deal 120% Power. **Advantage rider:** consume Advantage on the target and deal 160% instead. Tooltip: `Deal 120% Power; consume the target's Advantage to deal 160% instead.` |
| **Slipstep (CD3)** | Active; self. Optionally perform one legal self Move 1, then gain 2 Armor. The Armor still applies when no move is chosen; an explicitly chosen stale path rejects the action. Tooltip: `Optionally move 1, then gain 2 Armor.` |

## Snarewright

**Role:** Stationary trap controller. **Weakness:** Low direct output without setup. **Stats:** 16 Health, 4 Power, 9 Speed, 1 Defense.

| Skill | Contract |
|---|---|
| **Tripline Tag (CD1)** | Active; one enemy. Apply Snared until round end. The first subsequent allied direct hit on that Snared enemy applies Advantage after its damage resolves. That triggering hit cannot consume the newly applied Advantage. Snared remains. Tooltip: `Apply Snared. The first later allied direct hit this round applies Advantage after damage.` |
| **Holdfast Wire (CD2)** | Active; one Snared enemy. Deal 115% Power and apply -1 Speed until round end. Snared is required but not consumed. Rebuild only unresolved queue entries immediately after the Speed change. Tooltip: `Against a Snared enemy, deal 115% Power and reduce Speed by 1 this round.` |
| **Ring Net (CD4)** | Active; choose one or two enemies. Apply Snared to all locked targets atomically until round end. Reject if any selected target becomes stale. Tooltip: `Apply Snared to up to 2 enemies until round end.` |

Tripline Tag's follow-up guard is stored per Snared application and triggers at most once before reapplication. Reapplying Snared refreshes the expiry and rearms that authored Tripline follow-up; it never creates a second Snared stack.

## Scrapbroker

**Role:** Armor support and setup broker. **Weakness:** Lowest Goblin Power. **Stats:** 18 Health, 3 Power, 8 Speed, 1 Defense.

| Skill | Contract |
|---|---|
| **Spot Buyer (CD1)** | Active; one enemy. Apply Advantage until round end. Tooltip: `Apply Advantage to one enemy until round end.` |
| **Hand-Me-Down (CD2)** | Active; one ally. Grant 4 Armor. If that ally consumed any enemy's Advantage earlier this round, grant 5 Armor instead. Tooltip: `Grant an ally 4 Armor, or 5 if it consumed Advantage this round.` |
| **Emergency Kit (CD4)** | Active; one ally below 50% maximum HP. Grant 6 Armor. Reject if the health threshold is no longer met. Tooltip: `Grant an ally below 50% HP 6 Armor.` |

## Shivrunner

**Role:** Opportunistic Bleed finisher. **Weakness:** Lowest Health and no Defense. **Stats:** 12 Health, 7 Power, 10 Speed, 0 Defense.

| Skill | Contract |
|---|---|
| **Quick Nick (CD1)** | Active; one enemy. Deal 80% Power and apply 1 Bleed using the canonical two-committed-action duration. Tooltip: `Deal 80% Power and apply 1 Bleed.` |
| **Dirty Window (CD2)** | Active; one Bleeding enemy. Deal 125% Power. If any ally committed an action before the Shivrunner this round, deal 145% instead. This bonus is not an Advantage rider. Tooltip: `Deal 125% Power to a Bleeding enemy, or 145% if an ally acted before you this round.` |
| **Collect Debt (CD4)** | Active; one Bleeding enemy below 50% maximum HP. Deal 175% Power. Bleed is not consumed. Tooltip: `Deal 175% Power to a Bleeding enemy below 50% HP.` |

## Mobcaller

**Role:** Coalition coordinator. **Weakness:** Requires several surviving allies. **Stats:** 17 Health, 4 Power, 9 Speed, 1 Defense.

| Skill | Contract |
|---|---|
| **Point and Yell (CD1)** | Active; one enemy. Apply Advantage until round end. Tooltip: `Apply Advantage to one enemy until round end.` |
| **Dogpile Math (CD2)** | Active; one enemy previously hit by an ally this round. Deal 90% Power plus 20 percentage points per distinct allied attacker that directly hit the target this round, maximum 150%. The Mobcaller is not counted before this hit resolves. Tooltip: `Deal 90% Power, +20% per distinct allied attacker on this target this round (max 150%).` |
| **Louder Together (CD3)** | Active; one different-race ally and one enemy. Apply Advantage to the enemy and grant the ally +1 Speed until round end. Speed does not stack; reapplication refreshes expiry. Immediately rebuild unresolved queue entries. Tooltip: `Choose a different-race ally and an enemy: apply Advantage to the enemy and grant the ally +1 Speed this round.` |

## Role summary

| Class | Primary job | Defining interaction |
|---|---|---|
| Scrapshield Bruiser | Anchor | Retaliatory Armor and adjacent bracing |
| Wirefang Skirmisher | Setup striker | Applies then converts shared Advantage |
| Snarewright | Controller | Snared setup and round-local Speed control |
| Scrapbroker | Armor support | Rewards allies that consume Advantage |
| Shivrunner | Finisher | Bleed and allied-action timing |
| Mobcaller | Coalition support | Distinct attackers and mixed-race sequencing |

Leveling, tier upgrades, evolution, and mechanical-unit progression are intentionally deferred for re-evaluation and are not part of these loadouts.
