# Goblin Commander

## Brakka Rustbanner, Packmarshal

Brakka is a Scrapshield Bruiser who leads from the front with a scavenged banner pole, battered shield, and practical battlefield calls. She became a commander by keeping mixed crews coherent during raids that should have broken them.

## Commander Rule

A commander retains all three battle skills of its root class and adds exactly one commander-specific fourth skill. Brakka therefore uses Shield Tap, Pack Brace, Banner Nudge, and Banner Holder. No skill is replaced.

## Banner Holder

**Slot:** Fourth commander skill (Passive). **Trigger:** Start of Brakka's eligible action. **Limit:** Once per round.

- Apply Advantage to the active enemy closest to Brakka.
- Brakka spends no action on the trigger.
- Distance is measured by the canonical battle formation-distance rule.
- Ties resolve frontline before backline, then lowest slot index.
- The token lasts until an eligible allied skill consumes it or the current round ends.
- Default Attack and Default Swap cannot consume it.
- If no active enemy exists, apply nothing and log `Banner Holder found no active enemy.`
- Revalidate enemy activity and distance before application. If the chosen enemy becomes stale during resolution, apply nothing and do not redirect.
- Extra actions and Passive chains cannot bypass the once-per-round guard.

**Tooltip:** `Once per round at the start of your action, apply Advantage to the closest active enemy.`

**Success log:** `<actor>'s Banner Holder applied Advantage to <enemy>.`

**AI condition:** The Passive itself has no AI activation. Brakka values teams with eligible Advantage riders.

**Counterplay:** Change which enemy is closest before Brakka's action, defeat Brakka, or let the token expire at round end.

## Party Function

Brakka is a front-line anchor and coalition tempo setter. She keeps the complete Scrapshield loadout and adds deterministic shared setup through Banner Holder.

## World-Map Passive: Scrapline Quartermaster

**Type:** Passive world-map utility. **Trigger:** Gain 1 Cache charge every four accepted moves, maximum 1 stored.

- On entering the next Combat encounter, consume Cache and choose one prep bonus:
	- Frontline Briefing: choose one active enemy to start battle with Advantage.
	- Spare Plating: all frontline allies start battle with +2 Armor.
- No tile reveal, no movement range increase, and no move_count behavior changes.
- Uses the implemented pre-Combat preparation hook for battle-start bonuses.

**Implementation status:** Implemented and evidenced by AC6.6. Cache progress/readiness and the canonical preparation record persist in `WorldRunState`; the production world controller performs atomic offer/commit publication; the battle arena blocks actions until a durable choice is applied; and Safe/Boss encounters bypass preparation without consuming Cache. See `Docs/Specs/AC6/Evidence/AC6.6/2026-09-02/manual-runtime-check.md`.

**Integration status:** AC6.7 proves Brakka's three-plus-one loadout, Banner Holder trigger, reward and mixed-party transition, Cache reload, preparation commit, persistent formation, and clean next-battle state through the production world scene. See `Docs/Specs/AC6/Evidence/AC6.7/2026-09-03/manual-runtime-check.md`.

**Intent:** Keep Goblin commander identity as coalition setup through practical preparation rather than visibility, while preserving Harpy movement scouting and Werewolf hunt-pressure identity.

Commander leveling, XP, specialization, and respec rules in the progression brief are design candidates only and remain deferred for re-evaluation.

See `Docs/Races/COMMANDER_PROGRESSION_BRIEF_V1.md` for the full five-race commander set and review log.
