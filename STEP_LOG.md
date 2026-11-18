# Step Log — Swap coding model (qwen-local → qwen-coder)

**Date:** 2026-11-18
**Goal:** Replace the general-purpose 8B model with a stronger local coding
model, as a backup for glm-5.3 (rucode gateway) so coding assistance survives
a gateway outage.

## Plan (approved by user)

- Model: Qwen3-Coder-30B-A3B (MoE, fast, non-thinking, 4-bit AWQ)
- Context length: 8192 → 32768 (automatic fallback to 16384 if GPU memory is too tight)
- GPU memory utilization: 0.85 → 0.90
- Served model name: `qwen-local` → `qwen-coder`

## Correction during execution

The official `Qwen/Qwen3-Coder-30B-A3B-Instruct-AWQ` repo does not exist
(no official Qwen AWQ for the Coder). Compared community quants via the
Hugging Face API and selected `stelterlab/Qwen3-Coder-30B-A3B-Instruct-AWQ`
(16.7 GB, 78k downloads, standard AWQ W4A16 — smaller than the cyankiwi
18.1 GB variant, leaving enough VRAM for the 32K context).

## Changes

1. `docker-compose.yml` — vLLM command: new model, served name `qwen-coder`,
   `--gpu-memory-utilization 0.90`, `--max-model-len 32768`
2. `litellm-config.yaml` — model_list entry renamed to `qwen-coder`
3. `test-local.sh` — test request model name updated

## Commands run

- `docker compose config --quiet` (validate configuration)
- `docker compose up -d` (recreates vLLM; downloads ~17 GB model once)
- `docker compose restart litellm` (re-reads the renamed model entry)

## Verification (all completed 2026-11-18)

- [x] vLLM loaded successfully — 15.6 GiB weights in 164 s; KV cache 4.12 GiB
      = **45,056 tokens** (a full 32K request fits; concurrency 1.38x)
- [x] Gateway health OK (`"I'm alive!"`)
- [x] `/v1/models` → `['qwen-coder']`
- [x] Coding test (LRU cache): **implementation CORRECT** — 9/9 asserts
      passed with a correct test suite, ~197 tokens/sec
- [x] GPU usage: 22.9 / 24.5 GB (as planned at 0.90 utilization)

### Test notes (honest findings)

- The model's LRU implementation was correct, but its **own generated test
  had a flawed expectation**: after `get(2)` makes key 2 most-recently-used,
  `put(3,3)` evicts key 1 — the model expected key 2 evicted. Its asserts
  failed on its own (wrong) expectation.
- One cosmetic glitch at temperature 0.2: class name came out `LRUCltra`
  (consistent, code still ran). Re-run at temperature 0 produced normal output.
- **Lesson: always execute generated code; do not trust the model's self-tests.**

## Result

The stack now serves `qwen-coder` (Qwen3-Coder-30B-A3B, 4-bit AWQ) as the
local backup coding model for glm-5.3 outages.

## Addition (same day): PostgreSQL database for the LiteLLM UI

**Why:** the browser UI showed "Not connected to DB!" — LiteLLM's management
screens (usage, keys, request logs) need a database. Approved by user
("use database").

**Changes:**
1. `docker-compose.yml` — added `db` service (`postgres:16-alpine`,
   internal network only, healthcheck, persistent `postgres-data` volume);
   `litellm` now waits for a healthy `db` before starting
2. `.env` — added `POSTGRES_PASSWORD` (random, generated locally, not
   displayed) and `DATABASE_URL` pointing at the `db` service

**Verification:**
- `docker compose up -d --wait` → all three containers healthy
- Prisma schema migration ran successfully (see gateway logs)
- `/user/info` (a DB-backed endpoint) returned real data → DB confirmed working
- vLLM untouched — no model reload needed

## Rollback

Revert the three files (model back to `Qwen/Qwen3-8B-AWQ`, name `qwen-local`,
max-model-len 8192, utilization 0.85) and run `docker compose up -d`.
The 8B weights stay in the `huggingface-cache` volume, so switching back is quick.
