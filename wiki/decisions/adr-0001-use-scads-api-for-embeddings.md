---
type: Decision
title: ADR-0001 Use ScaDS AI API for embeddings
description: Decision to use the ScaDS AI API (embeddinggemma-2) as the primary embedding backend.
tags: [decisions, embeddings, api]
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
- Requires an API key at `~/.tudai-api-key` (see `auth.py`).
- Rate limits and API downtime become failure modes.
- `api_gemma.py` is the canonical entry point for API-based embedding.
