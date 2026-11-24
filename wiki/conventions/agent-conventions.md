---
type: Conventions
title: Agent Conventions
description: KANBAN protocol, issue tracking, domain docs, and where project decisions live — the working rules for agents in this repo.
tags: [conventions, kanban, workflow, agents]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
stale_after: 2027-02-24T00:00:00Z
sources:
  - id: kanban
    resource: KANBAN.md
    title: KANBAN.md (protocol + cards)
    last_modified: 2026-11-24
  - id: issuetracker
    resource: docs/agents/issue-tracker.md
    title: Issue tracker conventions (GitHub via gh)
    last_modified: 2026-11-23
  - id: domain
    resource: docs/agents/domain.md
    title: Domain docs conventions
    last_modified: 2026-11-23
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# Agent Conventions

## Task tracking: KANBAN.md

The working task tracker is `KANBAN.md` at the repo root (cards, not GitHub
issues). Protocol:[^kanban]

- A card moves column **in the same commit** that changes its state.
- Starting a task → card to **In Progress**; the completion commit flips it to
  **Done** with its commit hash.
- Card numbers are assigned once and never re-used. Next free number is
  announced in the header (24 at time of writing).
- Cards carry branch/commit refs where they exist; deferred work from PR
  reviews gets its own card (e.g. [19], [21], [22]).

## Issue tracking

GitHub Issues via the `gh` CLI; conventions and wayfinding operations live in
`docs/agents/issue-tracker.md` — read it, don't duplicate it here.[^issuetracker]

## Domain docs

`docs/agents/domain.md` governs glossary/ADR consumption: read `GLOSSARY.md`
and `docs/adr/` before exploring, proceed silently if absent (the
`/domain-modeling` skill creates them lazily). Note: neither `GLOSSARY.md` nor
`docs/adr/` exists in this repo yet; **project decisions live in this bundle's
[`decisions/`](/decisions/index.md)** until the domain-docs flow creates the
root-level homes (decided 2026-11-24).[^domain]

## Git workflow

- Feature branches + PRs for review (PR #1/#2 flow); worktrees for parallel
  lines (this checkout is a worktree of `embedding-test` on branch `wiki`).
- Commit subjects observed: `Feat:` / `Fix:` / `Test:` / `Refactor:` /
  `Docs:` / `chore:` / `kanban:` — kanban-state commits use the `kanban:`
  prefix and flip cards in the same commit.

## Bundle maintenance

Rules for editing this wiki live in [Agent Rules](/AGENTS.md).

## Related

- [Changelog](/changelog.md) — what actually shipped, when

[^kanban]: KANBAN.md (read during 2026-11-24 bundle rebuild)
[^issuetracker]: docs/agents/issue-tracker.md (read during 2026-11-24 bundle rebuild)
[^domain]: docs/agents/domain.md (read during 2026-11-24 bundle rebuild)
