# Local-model offload — detect and shell out

Copy-paste mechanic for routing eligible mechanical work to a **local Ollama** model, off the
Claude token budget. ship's Phase 3 decides *what* to offload; this file is *how*. (The
detect-and-shell-out steps below are also how `review-pr` gets a local second opinion.) The
skill stays portable: it hardcodes no model names — discover them at runtime — and honors a
custom endpoint via `$OLLAMA_HOST`.

## 0. Resolve the endpoint

```bash
OLLAMA="${OLLAMA_HOST:-localhost:11434}"                       # honor a documented override
case "$OLLAMA" in http*) ;; *) OLLAMA="http://$OLLAMA" ;; esac  # $OLLAMA_HOST is often scheme-less
```

Use `"$OLLAMA"` in every call below so the endpoint stays in one place.

## 1. Detect (degrade silently if absent)

Guard, don't abort: detection must signal "absent → use the normal tiers," never kill the
caller. Make it a function that **returns** non-zero — not a script that `exit`s:

```bash
local_offload_available() {
  command -v ollama >/dev/null || return 1                       # CLI present (model discovery)
  command -v jq >/dev/null || return 1                           # jq builds the payload (step 3)
  curl -sf --max-time 5 "$OLLAMA/api/tags" >/dev/null || return 1  # server reachable (don't hang)
  ollama list | tail -n +2 | grep -q . || return 1              # at least one model pulled
}
local_offload_available || echo "no local model — use the normal tiers"
```

Never hard-depend on it — it's absent in CI, on a work machine, and so on.

## 2. Pick a model (discover, don't hardcode)

```bash
ollama list   # inspect installed models + sizes at runtime
```

Choose by stakes and latency — a smaller model for fast, high-volume work; a larger one for
quality-sensitive first passes. Honor a user-stated preference first: if `CLAUDE.local.md`
names which local model to use for which role, follow it. Never assume a specific model is
present. (Running against a remote Ollama with no local CLI? Read the model list from
`"$OLLAMA/api/tags"` instead.)

## 3. Shell out (JSON-encode the content — don't interpolate)

File content, diffs, and logs contain quotes, backslashes, and newlines that break a
hand-built JSON string. **Always build the payload with `jq`** so the content is encoded —
never paste raw text into the JSON:

```bash
MODEL="<model-from-step-2>"
SYS="<tight instructions>"
CONTENT="<the batch to process>"    # may contain quotes/newlines — jq encodes it safely

jq -nc --arg m "$MODEL" --arg sys "$SYS" --arg usr "$CONTENT" \
  '{model:$m, messages:[{role:"system",content:$sys},{role:"user",content:$usr}], stream:false}' \
| curl -s --max-time 120 --fail-with-body \
    "$OLLAMA/v1/chat/completions" -H 'Content-Type: application/json' -d @-
```

`--fail-with-body` surfaces the error body on a bad request so the agent can self-correct, and
`--max-time` stops a hung model from blocking. `/api/generate` is the native single-prompt
alternative. The local model has **no repo access and no tools** — put everything it needs in
the request; it can't read a file.

## 4. Verify and log

- **Verify before it lands.** Local output is a *draft*: review it as you would a cheap-tier
  subagent's, and never let it reach the PR unchecked. Subtle logic, multi-file reasoning, and
  anything correctness-critical stay with Claude.
- **Log the routing.** Note in one line when a sub-step went local vs. to Claude (per Phase
  3's "surface the routing" rule) so the token savings — and any quality trade-off — are visible.

## What's eligible

Offload only **batchable, low-stakes** work that's cheap to verify: bulk summarization across
many files, diff/log triage, first-pass boilerplate, classification/tagging. Keep on Claude
anything agentic, multi-file, or high-stakes, reserve the Opus driver for correctness-critical
work, and never put anything on the interactive path through a local model.
