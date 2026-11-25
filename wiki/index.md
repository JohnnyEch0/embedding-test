---
okf_version: "0.2"
---

# Embedding Test Wiki

Entry point for the Open Knowledge bundle of the EmbVis (Embedding Visualizer) project.

## Start Here

- [Architecture Overview](overview.md) — system, pipeline, and core components
- [JSON Data Format](data-format.md) — the Poem-Embeddings schema of `poem_emb/` and `godot/data/`
- [Changelog](changelog.md) — notable changes, newest first

## Pipeline (Python)

- [Pipeline](pipeline/) — api_gemma (d128) → dimension_reduction (d32) → godot/data
- [Data layer](pipeline/data-layer.md) — the typed record model (`data.py`)

## Godot App

- [Godot](godot/) — architecture, DimMap, headless testing

## Runbooks

- [Regenerate embeddings](runbooks/regenerate-embeddings.md) — full pipeline run
- [Run tests](runbooks/run-tests.md) — pytest + headless Godot tests

## Conventions

- [Agent conventions](conventions/agent-conventions.md) — KANBAN protocol, issue tracking, git workflow

## Decisions

- [Architecture Decision Records](decisions/index.md) — why things are the way they are

## Reference

- [Agent Rules](AGENTS.md) — rules for agents working in this wiki
- [Spec](SPEC.md) — pinned copy of the Open Knowledge Format spec (upstream)

## Maintenance

- [Log](log.md) — bundle lifecycle history
