---
name: explain-godot-code
description: Explain selected Godot code through its ownership and dependencies.
disable-model-invocation: true
---
Canonical role: `godot-architecture-reviewer`

Load `.agents/roles/godot-architecture-reviewer/instructions.md` and the `reverse-document-system` skill. Apply them read-only to the selected code and the user's question. Treat canonical files as authoritative; this prompt adds no workflow rules.
