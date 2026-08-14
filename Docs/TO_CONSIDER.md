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

## Resolved questions

Move an entry here when the project lead makes a durable decision. Record the decision date, affected acceptance criteria, and the specification or implementation link that made it authoritative.

### TC-002 — Full-roster recruitment uses atomic replacement

- **Resolved:** 2026-08-14 for AC3.2.
- Valid recruitment remains in the normal reward catalog at roster size six.
- Confirm opens `PartyManagement.Mode.REPLACEMENT`; Cancel restores the unchanged reward choices.
- Any occupied member, including a starter, may be replaced through one atomic roster mutation.
- The dismissed character may be recruited again later when no copy is currently owned.
- Equipment and progression cleanup remain deferred until those systems own authoritative run state.
- **Authority:** `Docs/superpowers/specs/2026-08-14-ac3-2-full-roster-replacement-design.md`.
