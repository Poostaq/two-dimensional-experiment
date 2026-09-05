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

### TC-003 — How should character progression work for each unit model?

- **Raised from:** Former AC3.4.
- **Current rule:** Character progression is not part of the active MVP acceptance criteria and remains undefined.
- **Decision needed by:** Any implementation of leveling, class evolution, or permanent unit upgrades.
- **Questions to resolve:**
  - Which unit types use level-up growth, class evolution, permanent upgrades, or another progression model?
  - Which progression state persists within a run, between runs, or across all saves?
  - How are progression choices presented, earned, capped, and balanced across different unit models?

### TC-004 — What equipment eligibility restrictions should the game enforce?

- **Raised from:** Former AC3.5.
- **Current rule:** Equipment eligibility, including possible race restrictions, is not part of the active MVP acceptance criteria and remains undefined.
- **Decision needed by:** Any implementation of equippable items or equipment validation.
- **Questions to resolve:**
  - Can equipment be restricted by race, class, unit type, character, slot, or progression state?
  - How should the interface explain why a character is ineligible to equip an item?
  - Are restrictions fixed by item definition, modified by upgrades, or affected by run rules?

### TC-005 — How should equipment ownership, unequipping, and reassignment work?

- **Raised from:** Former AC3.6.
- **Current rule:** Equipment ownership and reassignment are not part of the active MVP acceptance criteria and remain undefined.
- **Decision needed by:** Any implementation of a shared inventory or character equipment management.
- **Questions to resolve:**
  - Is equipment held in a shared inventory, owned by individual characters, or managed through another model?
  - Can equipment be unequipped and reassigned freely, or are there timing, location, cost, or binding restrictions?
  - What happens to equipped items when a character is dismissed, defeated, transformed, or otherwise leaves the roster?

## Resolved questions

Move an entry here when the project lead makes a durable decision. Record the decision date, affected acceptance criteria, and the specification or implementation link that made it authoritative.

### TC-002 — Full-roster recruitment uses atomic replacement

- **Resolved:** 2026-08-14 for AC3.2.
- Valid recruitment remains in the normal reward catalog at roster size six.
- Confirm opens `PartyManagement.Mode.REPLACEMENT`; Cancel restores the unchanged reward choices.
- Any occupied member, including a starter, may be replaced through one atomic roster mutation.
- The dismissed character may be recruited again later when no copy is currently owned.
- Equipment and progression cleanup remain deferred until those systems own authoritative run state.
- Goblin leveling, tier upgrades, evolution, commander specialization, XP, and mechanical-unit progression remain explicitly deferred after AC6; AC6 implements battle identity and run-local state only.
- **Authority:** `Docs/superpowers/specs/2026-08-14-ac3-2-full-roster-replacement-design.md`.
