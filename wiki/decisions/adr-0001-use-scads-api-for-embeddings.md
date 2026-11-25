---
type: Decision
title: ADR-0001 Use ScaDS AI API for embeddings
description: Decision to use the ScaDS AI API (embeddinggemma-2) as the primary embedding backend.
tags: [decisions, embeddings, api]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
sources:
  - id: apigemma
    resource: api_gemma.py
    title: api_gemma.py (canonical API entry point)
    last_modified: 2026-11-19
  - id: auth
    resource: auth.py
    title: auth.py (key + client setup)
    last_modified: 2026-10-21
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# ADR-0001: Use ScaDS AI API for embeddings

**Date**: 2026-11-16
**Status**: Accepted

## Context

The project needs a reliable, reproducible embedding backend. Options considered:

1. **ScaDS AI API** (`https://llm.scads.ai/v1`) — hosted, OpenAI-compatible, provides `google/embeddinggemma-2`.
2. **Local sentence_transformers** — requires local GPU/CPU, model download, no reproducibility guarantee across machines.
3. **Other hosted APIs** — additional cost, vendor lock-in concerns.

## Decision

Use the ScaDS AI API with `google/embeddinggemma-2` as the primary embedding backend. Keep `gemma.py` (sentence_transformers) as a local fallback for development and offline use.

## Consequences

- Embeddings are reproducible across machines.
- Requires an API key at `~/.tudai-api-key` (see `auth.py`).[^auth]
- Rate limits and API downtime become failure modes.
- `api_gemma.py` is the canonical entry point for API-based embedding.[^apigemma]

## Addendum (2026-11-24)

The local `gemma.py` fallback was removed in the post-ADR cleanup (the typed
refactor, KANBAN card [11] era); the API is now the only embedding backend.
The rest of the ADR stands.

## Related

- [API embedding stage](/pipeline/api-embedding.md)

[^apigemma]: api_gemma.py (read during 2026-11-24 bundle rebuild)
[^auth]: auth.py (read during 2026-11-24 bundle rebuild)
