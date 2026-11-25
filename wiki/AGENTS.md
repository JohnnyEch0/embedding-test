---
type: Agent Rules
title: EmbVis Wiki Agent Rules
description: Rules for agents working in this Open Knowledge bundle for the EmbVis project.
tags: [openknowledge, okf, agents]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
---

# Agent Rules

You are working inside the Open Knowledge bundle for the EmbVis (Embedding
Visualizer) repo — `embedding-test`, checked out here as the `emb_wiki`
worktree (branch `wiki`). The bundle lives in `wiki/` and follows OKF v0.2
(pinned copy: [SPEC.md](SPEC.md)).

## Reading this bundle

- Start at [index.md](index.md), then follow only the links relevant to the
  task.
- [overview.md](overview.md) gives the system shape; [decisions/](decisions/index.md)
  records why; [runbooks/](runbooks/regenerate-embeddings.md) covers hands-on
  work; [conventions/](conventions/agent-conventions.md) covers working rules.
- Weigh trust: `status: draft`, a passed `stale_after`, or an unverified
  concept means *check the code before relying on it*. The code is the source
  of truth; the bundle is a map.

## Maintaining this bundle

- After a code change that alters architecture, data flow, data format, or a
  module's purpose: update the matching concept, bump `generated.at`, and set
  `generated.by` to your actor (`<producer>/<version>` or `process:<id>`).
- After a deliberate technology or architecture choice: add an ADR in
  [decisions/](decisions/index.md) (ADR-0001 is the format template). This
  bundle is the repo's decision home until `docs/adr/` exists.
- After a notable user-facing change: add a [changelog.md](changelog.md) entry.
- Lifecycle events only (bundle/concept creation, deprecation, supersession,
  regeneration, verification) go in [log.md](log.md) — append, never rewrite.
  Routine concept edits are not logged.
- One concept per file. Prefer absolute bundle-relative links
  (`/pipeline/data-layer.md`).
- Validate before finishing: `okf_validate.py <bundle-dir> --strict` (see the
  `validate` skill). Resolve every ERROR. One known false-positive warning
  lives in the pinned `SPEC.md` (a `# Citations` line inside an upstream code
  fence) — do not edit the upstream text to silence it.

## Boundaries

- Keep the bundle small: pipeline, godot app, data format, decisions,
  runbooks, conventions, changelog. Do not add page types that don't serve
  those.
- Do not duplicate `docs/agents/*` — link to it (see
  [Agent conventions](conventions/agent-conventions.md)).
- Do not invent decisions that were not actually made; do not store raw
  source material here.
- Do not commit bundle changes on the same commit as unrelated code churn —
  the repo uses small, focused commits.
