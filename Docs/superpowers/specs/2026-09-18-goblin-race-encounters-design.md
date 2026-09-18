# Goblin parties and race encounters

Status: approved by the user on 2026-09-18.

Replace default placeholder players with Scrapshield Bruiser, Wirefang Skirmisher, and Snarewright using their existing authored kits. Preserve commander selection, saved formation identity, player health, and explicit test unit arrays.

Provide three deterministic two-unit enemy encounters: Human Ranger + Crossbowman (Snared conversion), Dwarf Siege Smith + Thunderbreaker (Armor removal and same-round payoff), and Elf Star Archer + Moon Sage (Advantage setup and burst). Use authored stats and three-skill kits from the race class documents. Each encounter creates fresh battle state.

The standalone arena selects encounters by an exported index. World encounters derive a stable index from encounter coordinates so re-entering or reloading the same encounter preserves its team. Indices cycle human, dwarf, elf. Enemy turns select legal setup/payoff actions through the existing skill transaction and fall back to Default Attack. Explicitly configured test battles remain manually controlled.

Implement missing Armor-break and conditional damage rules in shared typed authoring infrastructure. Preview and rejected confirmations never mutate combat state. Record actual Armor removed and absorbed for same-round dwarf conversion. Existing turn, status, cooldown, victory, reward, and preparation rules remain authoritative.

Verify real catalog kits, legal opposing-side targeting, each pair's combo, deterministic selection, fresh state, starter identities, commander flow, battle entry, and relevant combat regressions. Runtime-check the arena and project with GodotIQ.
