# AC5.1 Independent Run Lifecycle Design

## Goal

Integrate the existing single-slot run lifecycle so Continue Run restores the last durable session, while Start New Run requires confirmation before atomically replacing an existing session with a fresh seeded run whose roster and mutable run state are independent.

## Scope

AC5.1 covers new-run creation, overwrite confirmation, continuation of the last session, atomic replacement, and isolation of all run-owned state. It does not add meta-progression, multiple save slots, a global run-session autoload, or AC5.3 reproducibility guarantees beyond retaining the existing seed behavior.

## Architecture

`WorldProductionLauncher` remains the UI and lifecycle coordinator. It queries `WorldSingleSlotRepository` to decide whether Continue Run is available and whether Begin must enter overwrite confirmation. It delegates new-run construction to `WorldRunStartService` and durable replacement to the repository.

`WorldRunStartService` constructs a complete fresh `WorldRunState` from the requested seed and commander. The service must not read or merge the previous save. `WorldSingleSlotRepository.replace_atomic()` remains the only replacement boundary, so the old session survives generation, encoding, or write failures.

No autoload is introduced. Run ownership stays within the existing launcher, repository, runtime model, and save-coordinator boundaries.

## User Flow

1. On the main menu, Continue Run is enabled only when a valid single-slot session exists.
2. Continue Run loads and validates that session, then launches it with its saved seed and mutable state.
3. Start New Run opens the existing seed and commander configuration screen regardless of save presence.
4. With no existing session, Begin generates, validates, saves, and launches the new run directly.
5. With an existing session, Begin retains the requested seed and commander only as pending launcher state and opens the overwrite confirmation.
6. Cancel closes confirmation and returns to run configuration without changing the durable session.
7. Confirm constructs the fresh run and replaces the old slot atomically only after construction and encoding succeed.
8. If confirmation fails, the previous session remains loadable and the launcher presents the existing failure handling.

## Independence Contract

A replacement run starts exclusively from its requested seed, selected commander, and canonical starter roster. None of the following may carry over from the prior session:

- recruited or dismissed characters;
- formation slot assignments beyond the new starter formation;
- character HP snapshots;
- player or boss coordinates;
- move count, sudden-death state, or boss engagement state;
- consumed encounters;
- Quartermaster cache progress or readiness;
- committed battle preparation;
- transient battle, reward, selection, or pending-save state.

Continue Run must restore those same fields from the existing session rather than resetting them.

## Failure Handling

New-run construction and validation occur before durable replacement. Cancel never invokes replacement. Invalid or corrupt existing saves follow the repository's validated-load error path and are not silently treated as resumable sessions. Any generation, encoding, or atomic-write failure leaves the previous bytes intact and prevents launch of a partially created run.

## Verification

Focused automated coverage will prove:

- direct new-run creation when no save exists;
- confirmation gating when a save exists;
- pending seed and commander preservation through confirmation;
- cancel leaves the old bytes and session unchanged;
- failed replacement leaves the old session loadable;
- successful confirmation replaces the saved seed and all mutable run state;
- Continue Run restores the saved session exactly;
- the new run contains only the canonical starter roster/formation and initial state;
- repeated confirmation cannot create or launch more than one replacement session.

Regression coverage will retain the existing run-start scene, start-service, launcher, save-codec, repository, runtime model, save-coordinator, AC3.1 roster, AC3.3 formation, AC3.5 recovery, and AC6.5/AC6.7 integration runners.

Manual runtime verification will create or load a session with a recruited character and progressed world state, return to the main menu, verify Continue Run restores it, then start a different seeded run, cancel overwrite once, confirm overwrite once, and verify that the recruit and all prior mutable run state are absent.

## Acceptance Boundary

AC5.1 is complete only when the same tested implementation commit has focused automated lifecycle evidence, regression evidence, GodotIQ validation and error checks, and a manual main-menu proof of continuation plus confirmed independent replacement. The criterion remains incomplete if cancellation mutates the old session, failures destroy it, any prior run-owned state leaks, or Continue Run resets the saved session.
