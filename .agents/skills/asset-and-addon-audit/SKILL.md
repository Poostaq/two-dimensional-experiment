---
name: asset-and-addon-audit
description: Use when Godot assets or addons need checks for duplication, references, formats, naming, size, import cost, or overlapping responsibility.
---

# Asset and Addon Audit

Audit asset health without deleting or rewriting content.

## Inputs

- Asset category, directory, addon set, or full-project scope.
- Applicable budgets, naming rules, and supported formats.

## Preconditions

- Read `AGENTS.md` and identify protected, legacy, generated, and addon-owned paths.
- Use GodotIQ asset and dependency inspection before filesystem fallbacks.

## Workflow

1. Inventory in-scope assets and addons with structured Godot tooling.
2. Check references, duplicate sources, missing dependencies, import formats, names, and size outliers.
3. Identify overlapping addon responsibility and project settings without changing configuration.
4. Separate active, legacy, debug-only, generated, and uncertain content.
5. Rank cleanup or optimization recommendations by safety and likely value.

If GodotIQ is unavailable, filesystem listing and textual reference search are a fallback. Mark orphan and dependency results as provisional. Never edit scenes, Resources, imports, or scripts without structured Godot tooling.

## Output Contract

Return inventory summary, violations, duplicates, provisional orphans, missing dependencies, addon overlaps, recommendations, and verdict.

## Failure Behavior

Do not classify an asset as removable without dependency evidence. Report unsupported inspection capability and return `INCONCLUSIVE` where necessary.

## Verification Evidence

Include scanned roots, filters, asset counts, reference method, concrete paths, and confidence for every orphan or overlap finding.
