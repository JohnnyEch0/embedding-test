---
type: Agent Rules
title: Embedding Test Wiki Agent Rules
description: Rules for agents working in this Open Knowledge wiki for the EmbVis project.
tags: [openknowledge, agents]
---

# Agent Rules

You are working inside a local Open Knowledge wiki for the EmbVis (Embedding Visualizer) project at `/home/azubi/Documents/code/embedding-test`.

## Reading this wiki

- Start at [index.md](index.md), then follow only links relevant to the task.
- [overview.md](overview.md) gives the high-level architecture. [decisions/](decisions/index.md) records why things are the way they are.

## Maintaining this wiki

- After a code change that alters architecture, data flow, or a module's purpose, update the matching page.
- After a deliberate technology or architecture choice, add an ADR in [decisions/](decisions/index.md) following the existing format.
- After a notable user-facing change, add an entry to [changelog.md](changelog.md).
- Run `okn validate --spec 0.2 .` from the wiki root after edits. Fix issues before finishing.

## Boundaries

- Do not add pages beyond what the interview established: architecture overview, decisions, changelog. Keep the wiki small.
- Do not invent decisions that were not actually made.
- Do not store raw source material in the wiki; keep it separate from maintained synthesis.
