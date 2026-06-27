# Local-model offload — detect and shell out

Copy-paste mechanic for routing eligible mechanical work to a **local Ollama** model, off the
Claude token budget. ship's Phase 3 decides *what* to offload; this file is *how*. The skill
stays portable: it hardcodes no endpoint or model names — discover them at runtime and honor
whatever the user documents in `CLAUDE.local.md` or their environment.

## 1. Detect (degrade silently if absent)

Run all three checks; if any fails, skip offload and use the normal tiers — never hard-depend
on a local model, since it's absent in CI, on a work machine, and so on:

```bash
command -v ollama >/dev/null || exit 1                          # CLI present
curl -sf http://localhost:11434/api/tags >/dev/null || exit 1   # server up (default port)
ollama list | tail -n +2 | grep -q . || exit 1                  # at least one model pulled
```

The endpoint defaults to `localhost:11434`; if the user documents a different host/port in
`CLAUDE.local.md` or `$OLLAMA_HOST`, use that instead.

## 2. Pick a model (discover, don't hardcode)

List what's actually installed and choose by stakes and latency — a smaller model for fast,
high-volume work; a larger one for quality-sensitive first passes:

```bash
ollama list   # inspect available models + sizes at runtime
```

Honor a user-stated preference first: if `CLAUDE.local.md` names which local models to use for
which role, follow it. Otherwise infer from `ollama list` (fewer parameters → the fast/cheap
lane; larger → the quality lane). Never assume a specific model is present.

## 3. Shell out

The OpenAI-compatible chat endpoint is simplest for one-shot tasks:

```bash
curl -sf http://localhost:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d @- <<'JSON'
{
  "model": "<model-from-step-2>",
  "messages": [
    {"role": "system", "content": "<tight instructions>"},
    {"role": "user", "content": "<the batch to process>"}
  ],
  "stream": false
}
JSON
```

`/api/generate` is the native alternative for a single prompt. The local model has **no repo
access and no tools** — paste the full context it needs into the request; it can't go read a
file.

## 4. Verify and log

- **Verify before it lands.** Local output is a *draft*: review it as you would a cheap-tier
  subagent's, and never let it reach the PR unchecked. Subtle logic, multi-file reasoning, and
  anything correctness-critical stay with Claude.
- **Log the routing.** Note in one line when a sub-step went local vs. to Claude (per Phase
  3's "surface the routing" rule) so the token saving — and any quality trade-off — is visible.

## What's eligible

Good local offload is batchable, low-stakes, and cheap to verify: bulk summarization across
many files, diff/log triage, first-pass boilerplate or scaffolding, classification/tagging.
Keep on Claude anything agentic, multi-file, or high-stakes, and reserve the Opus driver for
correctness-critical work. Local generation is throughput-limited, so only offload genuinely
**batchable** work — never anything on the interactive path.
