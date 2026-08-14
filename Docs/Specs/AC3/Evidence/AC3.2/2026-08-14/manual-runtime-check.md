# AC3.2 manual runtime check

Date: 2026-08-14
Implementation commit: `172fdaf5ec5a9e0de5287a3d6ba671a39279c827`

- Main scene starts with zero runtime or script-console errors: PASS.
- Full-roster reward visibility through focused real-scene integration: PASS (automated runtime scene).
- Replacement mode opens without early roster mutation: PASS (automated runtime scene).
- Cancel restores the selected reward with unchanged formation: PASS (automated runtime scene).
- Atomic replacement preserves size six and the exact target slot: PASS (automated runtime scene).
- Stale, repeated, and unexpected-teardown requests remain mutation-free: PASS (automated runtime scene).
- Next battle uses the recruit in the exact replaced semantic slot: PASS (automated runtime scene).
- Real-pointer replacement flow at 1152×648: BLOCKED.
- Visual tour of replacement instructions, pending card, six occupied targets, details, destructive feedback, and Cancel: BLOCKED.

Blocker:

Current content has three starters plus only two distinct recruitable characters (Scout and Champion), while duplicate character IDs are rejected. A six-member roster is therefore not naturally reachable in the live run. The intended GodotIQ in-memory fixture path was unavailable because `godotiq_exec(context="game")` timed out after a stop/play handshake retry, including on a trivial query. No project file or persistent debug-only content was added to bypass this gate.

Result: BLOCKED. AC3.2 remains unchecked until the two blocked runtime/visual checks pass against the tested implementation.
