# Goblin Commander

## Brakka Rustbanner, Packmarshal

Brakka is a Scrapshield Bruiser who leads from the front with a scavenged banner pole, battered shield, and practical battlefield calls. She became a commander by keeping mixed crews coherent during raids that should have broken them.

## Commander Rule

A commander retains the base class's four-slot limit. One class skill is replaced by a commander-specific Signature Passive, creating a real personal-versus-party tradeoff.

## Banner Holder

**Slot:** Signature Passive replacing Pack Wall. **Trigger:** Start of Brakka's eligible action. **Limit:** Once per round.

- Grant Advantage to the next active ally in unresolved action order that owns at least one currently legal Active skill with an Advantage rider.
- Brakka spends no action on the trigger.
- The token lasts until the recipient consumes it or the current round ends.
- Default Attack and Default Swap cannot consume it.
- If no ally qualifies, grant nothing and log `Banner Holder found no eligible ally.`
- Revalidate queue position, recipient activity, and rider eligibility before application. Failure grants nothing and does not redirect the token.
- Extra actions and Passive chains cannot bypass the once-per-round guard.

**Tooltip:** `Once per round at the start of your action, grant Advantage to the next eligible ally in unresolved order.`

**Success log:** `<actor>'s Banner Holder granted Advantage to <ally>.`

**AI condition:** Brakka values a formation containing an unresolved ally with a legal Advantage rider; the Passive itself has no AI activation.

**Counterplay:** Control or defeat the predicted recipient, force its rider targets out of legality, or let the token expire at round end.

## Party Function

Brakka is a front-line anchor and coalition tempo setter. Replacing Pack Wall reduces automatic neighbor protection, so she remains meaningfully less defensive than a standard Scrapshield Bruiser while improving mixed-race sequencing.
