# Portable Agent Catalog — 2D Game Project

This directory is the behavioral source of truth for repository agents and reusable skills.

**Setup:** 2D-focused.

## Layout

- `roles/<id>/agent.json`: portable identity, permissions, capabilities, and skill bindings.
- `roles/<id>/instructions.md`: platform-neutral role behavior.
- `skills/<id>/SKILL.md`: open Agent Skills workflows usable by Codex and GitHub Copilot.
- `policies/project-governance.md`: replaceable repository workflow policy.
- `platforms/capabilities.json`: semantic capability to platform-tool mapping.

Files under `.codex/agents/` and `.github/agents/` are generated. Do not edit them directly.

## Commands

```text
python tools/agent_port.py validate
python tools/agent_port.py generate
python tools/agent_port.py check
```

`check` is non-mutating and exits with status 1 when committed adapters are missing or stale.

## Active Agents (2D Game)

- **Gameplay Systems Designer** — Define core loop, mechanics, rules
- **Godot Implementation** — Code gameplay, scenes, scripts
- **Spec Validation** — Review design specs
- **Godot Architecture Reviewer** — Check system ownership & boundaries
- **Godot QA Playtester** — Smoke testing & gameplay feedback
- **Godot MCP Investigator** — Debug Godot internals (as needed)

## Invocation

| Capability | Codex | GitHub Copilot |
|---|---|---|
| Game Design | Request `$gameplay-systems-designer` | Select Gameplay Systems Designer agent |
| Architecture audit | Invoke `$godot-architecture-audit` or request `godot-architecture-reviewer` | Select the generated reviewer agent or use `review_changes.prompt.md` |
| Smoke gate | Invoke `$godot-smoke-check` | Ask the generated QA playtester to use `godot-smoke-check` |
| Implementation | Request `$godot-implementation` + relevant skills | Select the generated implementation agent or use `implement-feature.prompt.md` |
| Investigation | Request `$godot-mcp-investigator` | Select the generated investigator or a diagnostic prompt wrapper |

When adding another platform, extend capability mapping and add a renderer without changing canonical role or skill content.

For a human-friendly navigation surface in Obsidian, see [docs/README.md](../docs/README.md).
