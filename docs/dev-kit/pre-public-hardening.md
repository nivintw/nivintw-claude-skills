---
title: dev-kit pre-public-hardening
---

# pre-public-hardening

`/dev-kit:pre-public-hardening` — a whole-repo, full-history readiness review before a
private repo goes public: scans every commit for secrets (not just the working tree), audits
`.gitignore` for leak gaps, flushes private-context artifacts, and verifies license
completeness — producing a go/no-go checklist. Detects and prescribes; it never flips
visibility or rewrites history itself.

Try: *"make this repo public"* · *"is this repo safe to open-source?"* · *"scan the git
history for secrets"*.
