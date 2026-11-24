---
type: Pipeline Stage
title: API Embedding Stage (api_gemma.py)
description: Embeds .md poems at word/line/verse/poem level via the ScaDS AI API into eg2_d128_*.json files.
tags: [pipeline, embeddings, api-gemma, scads]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
stale_after: 2027-02-24T00:00:00Z
sources:
  - id: api-gemma
    resource: api_gemma.py
    title: api_gemma.py (stage source)
    last_modified: 2026-11-19
  - id: auth
    resource: auth.py
    title: auth.py (API client setup)
    last_modified: 2026-10-21
  - id: a1
    resource: /decisions/adr-0001-use-scads-api-for-embeddings.md
    title: ADR-0001 Use ScaDS AI API for embeddings
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# Pipeline Stage: API Embedding

`api_gemma.py` is stage 1 of the pipeline: it reads `.md` poems and writes one
`eg2_d{dims}_{stem}.json` per poem at the default `dims=128` — the files in
`poem_emb/`. See [Regenerate embeddings](/runbooks/regenerate-embeddings.md) for
the full run.

## Invocation

```bash
python3 api_gemma.py <input-dir> <output-dir> [--model M] [--dims N] [--batch B] [--jsonl]
```

Defaults: `--model google/embeddinggemma-2`, `--dims 128`, `--batch 256` words
per API call.[^api-gemma] `--jsonl` writes the deprecated JSONL format
(see [Data format](/data-format.md)); removal is tracked as KANBAN card [7].

## What gets embedded

Per poem, one flat text list — words, then raw lines, then verse texts, then
the whole-poem text — is embedded in a single API pass (chunked by `--batch`,
order restored via response `index`).[^api-gemma]

- **word** — whitespace split of each line
- **line** — each non-empty line
- **verse** — blank-line-separated blocks of the file (empty blocks skipped)
- **poem** — verse texts joined with a blank line

YAML frontmatter is stripped from the embedded text but `author`/`title` are
extracted into `metadata` (hand-rolled `key: value` parser; `{}` on
malformed/absent frontmatter, so `author` can be `null`).[^api-gemma]

Safety checks: a file with no words is skipped; a file whose verse line-count
doesn't add up is skipped.

## Auth

`auth.py` builds an OpenAI-compatible client for `https://llm.scads.ai/v1`
(see [ADR-0001](/decisions/adr-0001-use-scads-api-for-embeddings.md)) with the
key read from `~/.tudai-api-key`; the script exits if the key file is
missing or empty.[^auth]

## Legacy code in the file

`parse_md_lines`, `attach_embeddings`, `write_jsonl`, and `embed_file` are the
pre-typed-refactor word-only path; `main()` no longer calls them. They stay
until the JSONL removal (card [7]).[^api-gemma]

## Related

- [Data layer](/pipeline/data-layer.md) — the record types written here
- [Dimension reduction](/pipeline/dimension-reduction.md) — stage 2
- [Data format](/data-format.md) — the output schema

[^api-gemma]: api_gemma.py (read during 2026-11-24 bundle rebuild)
[^auth]: auth.py (read during 2026-11-24 bundle rebuild)
