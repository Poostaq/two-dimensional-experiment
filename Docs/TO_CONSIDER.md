# Product Questions To Consider

This is the living register for deliberately deferred product decisions. A question belongs here when the current implementation needs an explicit temporary rule but the final game rule has not been chosen.

## Open questions

### TC-001 — Can a run roster contain duplicate characters?

- **Raised during:** AC3.1 run-roster recruitment design.
- **Current rule:** No. A character whose stable `character_id` is already in the run roster is not offered as a recruitment reward, and direct acquisition is rejected.
- **Decision needed by:** Any feature that intentionally introduces duplicate recruitment; otherwise before finalizing AC3.2–AC3.6 identity-dependent behavior.
- **Questions to resolve:**
  - Are duplicates universally allowed, universally forbidden, or controlled by game mode, rarity, or character definition?
  - If duplicates are allowed, does each acquired copy receive a separate instance ID in addition to its shared character-definition ID?
  - Does progression belong to each copy or to the shared character definition?
  - Can duplicate copies hold different equipment and occupy different party slots?
  - How are identical copies distinguished in dismissal and party-management interfaces?
  - Can a reward offer a character already owned, and if so, is it a new unit, an upgrade, or a conversion into another resource?

### TC-002 — How should full-roster recruitment integrate with AC3.2?

- **Raised during:** AC3.1 run-roster recruitment design.
- **Current rule:** At six roster members, recruitment options are omitted; money and item rewards remain available. AC3.1 provides no dismissal prompt.
- **Decision needed by:** AC3.2 design.
- **Questions to resolve:**
  - Should a full-roster victory show recruitment as an option that opens a replacement flow, or use a separate recruitment event?
  - Can the player cancel replacement and return to the other reward choices?
  - When is the old character removed relative to adding the recruit so the roster never enters an invalid state?
  - What happens to the dismissed character's equipment, progression, and other owned state?
  - Does dismissing a character make that character eligible to be recruited again later in the same run?

## Resolved questions

Move an entry here when the project lead makes a durable decision. Record the decision date, affected acceptance criteria, and the specification or implementation link that made it authoritative.
