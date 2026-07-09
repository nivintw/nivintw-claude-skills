# Changelog

## [0.23.1](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.23.0...dev-kit-v0.23.1) (2026-07-09)


### Bug Fixes

* **dev-kit:** Correct unsupported minimal_output guidance + review-pr description ([3f31eff](https://github.com/nivintw/nivintw-claude-skills/commit/3f31effc888c450ce551d275cfea3fbe74fbb047)), closes [#171](https://github.com/nivintw/nivintw-claude-skills/issues/171)

## [0.23.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.22.0...dev-kit-v0.23.0) (2026-07-09)


### Features

* **dev-kit:** Scale ship's Phase 6 review battery to the diff ([e6f83f9](https://github.com/nivintw/nivintw-claude-skills/commit/e6f83f967e626aba8d324a7ff624b888c4142994)), closes [#166](https://github.com/nivintw/nivintw-claude-skills/issues/166)

## [0.22.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.21.0...dev-kit-v0.22.0) (2026-07-07)


### Features

* **dev-kit:** Add fleet-ship — the cross-repo batch coordinator above ship ([528d41c](https://github.com/nivintw/nivintw-claude-skills/commit/528d41ce8595e52f9d1afd1fd8bb3f88355c00dd)), closes [#156](https://github.com/nivintw/nivintw-claude-skills/issues/156)

## [0.21.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.20.2...dev-kit-v0.21.0) (2026-07-07)


### Features

* **dev-kit:** Add generate-docs affordance rubric, completeness critic, target-state marker ([1cf414b](https://github.com/nivintw/nivintw-claude-skills/commit/1cf414b2c1408524313b49aac3026b7f10be58cc)), closes [#148](https://github.com/nivintw/nivintw-claude-skills/issues/148) [#149](https://github.com/nivintw/nivintw-claude-skills/issues/149)
* **dev-kit:** First-class tracker reconcile + land skill, dry-dock/doctor/guard hardening ([5d1fd6e](https://github.com/nivintw/nivintw-claude-skills/commit/5d1fd6edc0241d8a8d336f5b3e44a15ba8211ac7)), closes [#128](https://github.com/nivintw/nivintw-claude-skills/issues/128) [#129](https://github.com/nivintw/nivintw-claude-skills/issues/129) [#130](https://github.com/nivintw/nivintw-claude-skills/issues/130) [#131](https://github.com/nivintw/nivintw-claude-skills/issues/131) [#132](https://github.com/nivintw/nivintw-claude-skills/issues/132) [#150](https://github.com/nivintw/nivintw-claude-skills/issues/150) [#151](https://github.com/nivintw/nivintw-claude-skills/issues/151) [#155](https://github.com/nivintw/nivintw-claude-skills/issues/155)
* **dev-kit:** Harden review-pr — real PR tree, toolchain-deferred syntax, staged reviews ([8cb6507](https://github.com/nivintw/nivintw-claude-skills/commit/8cb6507c719cdcda65d3663bed8188a34b27dd1b)), closes [#139](https://github.com/nivintw/nivintw-claude-skills/issues/139) [#142](https://github.com/nivintw/nivintw-claude-skills/issues/142) [#152](https://github.com/nivintw/nivintw-claude-skills/issues/152)
* **dev-kit:** Ship a real Copilot-review watch and harden ship's watcher guidance ([8cefacd](https://github.com/nivintw/nivintw-claude-skills/commit/8cefacd5395e3d6b121eec6329509016a570fbf7)), closes [#127](https://github.com/nivintw/nivintw-claude-skills/issues/127) [#138](https://github.com/nivintw/nivintw-claude-skills/issues/138) [#140](https://github.com/nivintw/nivintw-claude-skills/issues/140) [#141](https://github.com/nivintw/nivintw-claude-skills/issues/141)


### Bug Fixes

* **dev-kit:** Address Copilot review — tighten guards and clarify watch-script docs ([91561c6](https://github.com/nivintw/nivintw-claude-skills/commit/91561c69709285c822a28be6fed3dea722a94277))
* **dev-kit:** Address Copilot round 2 — keep the watch and validator exit contracts ([576b892](https://github.com/nivintw/nivintw-claude-skills/commit/576b89213c1916639befaa551e9bd940cf2e0b14))
* **dev-kit:** Address Copilot round 3 — validate the watch timeout, qualify its exit contract ([73b41a0](https://github.com/nivintw/nivintw-claude-skills/commit/73b41a044328825bd6588ae17169990d1e18befe))
* **dev-kit:** Address Copilot round 4 — doctor mktemp failure degrades, never exits ([a570b9b](https://github.com/nivintw/nivintw-claude-skills/commit/a570b9bae225dcb4f560010738677e52b31712be))
* **dev-kit:** Keep net-zero branches in cleanup-locally is_merged() ([0e33256](https://github.com/nivintw/nivintw-claude-skills/commit/0e3325669a6c7d61a69b4ef335385e5d2aa93225)), closes [#143](https://github.com/nivintw/nivintw-claude-skills/issues/143)
* **dev-kit:** Reconcile against copier's render, not a raw-tree byte-diff ([97403fe](https://github.com/nivintw/nivintw-claude-skills/commit/97403fea8834c717abee1af2ad551021d51be7a9)), closes [#146](https://github.com/nivintw/nivintw-claude-skills/issues/146) [#147](https://github.com/nivintw/nivintw-claude-skills/issues/147)
* **dev-kit:** Surface git's real reason and win the stash race in cleanup-locally ([7cdd395](https://github.com/nivintw/nivintw-claude-skills/commit/7cdd395c06bc90aed5452d51b46c3c698f1cd5fa)), closes [#144](https://github.com/nivintw/nivintw-claude-skills/issues/144) [#145](https://github.com/nivintw/nivintw-claude-skills/issues/145)

## [0.20.2](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.20.1...dev-kit-v0.20.2) (2026-07-06)


### Bug Fixes

* **dev-kit:** address Copilot review on generate-docs build-check guidance ([347260c](https://github.com/nivintw/nivintw-claude-skills/commit/347260c8d028323660c6661663426f130524558e)), closes [#116](https://github.com/nivintw/nivintw-claude-skills/issues/116)
* **dev-kit:** generalize generate-docs' stale Stage 4 build-check command ([aecfaf3](https://github.com/nivintw/nivintw-claude-skills/commit/aecfaf3f54579e1e71af17f31f910a70a41c7c58)), closes [#116](https://github.com/nivintw/nivintw-claude-skills/issues/116)

## [0.20.1](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.20.0...dev-kit-v0.20.1) (2026-07-06)


### Bug Fixes

* **dev-kit:** clarify batch decisions log in the PR and mirror on issues ([481961f](https://github.com/nivintw/nivintw-claude-skills/commit/481961fa3e08820c710dd57e79c3ca094ee4f1de))
* **dev-kit:** cover the multi-PR batch-split case in decision logging ([047a084](https://github.com/nivintw/nivintw-claude-skills/commit/047a084237b9555737812f3300f3d6c05a0fcec9))
* **dev-kit:** decouple ship's PR-batching decision from land ([9d0735e](https://github.com/nivintw/nivintw-claude-skills/commit/9d0735e8f8747f0e3e9955fe85629084911e6eba)), closes [#112](https://github.com/nivintw/nivintw-claude-skills/issues/112)
* **dev-kit:** scope batching decision-logging to the land path only ([7e8e0ad](https://github.com/nivintw/nivintw-claude-skills/commit/7e8e0ad10241b21810be0b3bdbb71d99e09258c4))

## [0.20.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.19.0...dev-kit-v0.20.0) (2026-07-06)


### Features

* **dev-kit:** retarget generate-docs to MkDocs Markdown + nav ([e11a3d3](https://github.com/nivintw/nivintw-claude-skills/commit/e11a3d3e1cb5463563043bf5c6e03931895beda9)), closes [#107](https://github.com/nivintw/nivintw-claude-skills/issues/107)
* **dev-kit:** teach generate-docs the docs-site design playbook ([1e2a26b](https://github.com/nivintw/nivintw-claude-skills/commit/1e2a26bc4d51d8bb363f58662836a645f8c779d1))


### Bug Fixes

* address Copilot review findings on PR [#109](https://github.com/nivintw/nivintw-claude-skills/issues/109) ([2004844](https://github.com/nivintw/nivintw-claude-skills/commit/200484497becb3c1d4353eaba733667bf7de469d))
* address further findings from a late-arriving review pass ([944ad3a](https://github.com/nivintw/nivintw-claude-skills/commit/944ad3a4dd4f1cd5038992cd31311d6fbf230182))
* address review-pr findings from the mkdocs migration ([119ff7f](https://github.com/nivintw/nivintw-claude-skills/commit/119ff7f15092923f22c5af944aa951e58ad56d3a))
* address round-2 Copilot findings on PR [#109](https://github.com/nivintw/nivintw-claude-skills/issues/109) ([5eee65a](https://github.com/nivintw/nivintw-claude-skills/commit/5eee65a83b5198d74b469ad7ab5fcd6d61ffaf37))
* check_docs.py crashes instead of exiting 2 on a non-mapping mkdocs.yml ([1d5f808](https://github.com/nivintw/nivintw-claude-skills/commit/1d5f80814837458c4ff7f94f3b90250ef6ad1a83))
* **dev-kit:** check_docs.py accepts raw-HTML directory-URL page links ([1b532d4](https://github.com/nivintw/nivintw-claude-skills/commit/1b532d4866629c2a8c4ca239f67d337680cc6fcb))

## [0.19.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.18.0...dev-kit-v0.19.0) (2026-07-04)


### Features

* **dev-kit:** land implies design-autonomy and batches into minimal PRs ([ec644c5](https://github.com/nivintw/nivintw-claude-skills/commit/ec644c5f148b7d4aef6efc32d31eac94b7165179)), closes [#104](https://github.com/nivintw/nivintw-claude-skills/issues/104)


### Bug Fixes

* **dev-kit:** address review-pr findings on land-batch-autonomy ([523d331](https://github.com/nivintw/nivintw-claude-skills/commit/523d331f3ab4721d126c9304e6f9fc1de16cd83f))

## [0.18.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.17.0...dev-kit-v0.18.0) (2026-07-04)


### Features

* **dev-kit:** complete dry-dock-overhaul with error handling and verification guidance ([5ecc5da](https://github.com/nivintw/nivintw-claude-skills/commit/5ecc5da099da16d9c45139b5aeede650f6ea4a47))
* **dev-kit:** scaffold dry-dock-overhaul skill and register it ([94d5f6c](https://github.com/nivintw/nivintw-claude-skills/commit/94d5f6c4ff1b9975f86c182748a0e495a1720362))
* **dev-kit:** write dry-dock-overhaul framing and Phases 0-2 ([496243a](https://github.com/nivintw/nivintw-claude-skills/commit/496243adce3d179d1ae88e82ddf124fb1279f205))
* **dev-kit:** write dry-dock-overhaul Phases 3-5, execution model, components ([1f5daf5](https://github.com/nivintw/nivintw-claude-skills/commit/1f5daf51aa7499e954f6e63953711bb3c6601f84))


### Bug Fixes

* **dev-kit:** address Copilot review findings on PR [#101](https://github.com/nivintw/nivintw-claude-skills/issues/101) ([00f4bc2](https://github.com/nivintw/nivintw-claude-skills/commit/00f4bc2f243e486c3d0041b02c675093d4e41de1))
* **dev-kit:** address review-pr findings on dry-dock-overhaul and open-work tests ([0d0c3d9](https://github.com/nivintw/nivintw-claude-skills/commit/0d0c3d9854c9c6de0aaeb64b227ee53fe120e894))
* **dev-kit:** finish addressing Copilot's gitignore-wording and stale-metadata findings ([8c2c20c](https://github.com/nivintw/nivintw-claude-skills/commit/8c2c20cad6edb20f220ad9f7ce722ee706f69054))
* **dev-kit:** open-work shows the entire ranked ready list, never capped ([502ad67](https://github.com/nivintw/nivintw-claude-skills/commit/502ad67179da0d07b54fde3aeb7042964ac469e3))

## [0.17.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.16.0...dev-kit-v0.17.0) (2026-07-04)


### Features

* **dev-kit:** split open-work's gather+rank into a testable script ([a0ade7f](https://github.com/nivintw/nivintw-claude-skills/commit/a0ade7f4d6e32a390b60994d5d3fd5993011d2c0)), closes [#97](https://github.com/nivintw/nivintw-claude-skills/issues/97)


### Bug Fixes

* **dev-kit:** correct degraded-mode ranking and GraphQL variable typing ([2196372](https://github.com/nivintw/nivintw-claude-skills/commit/219637273a83ac1906981a90ff16a6d2e72b5dda))

## [0.16.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.15.0...dev-kit-v0.16.0) (2026-06-29)


### Features

* **dev-kit:** generate-docs renders the built site before hand-off ([3f443e8](https://github.com/nivintw/nivintw-claude-skills/commit/3f443e84096f103b847079b912e3d3d6edc77521)), closes [#51](https://github.com/nivintw/nivintw-claude-skills/issues/51)

## [0.15.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.14.0...dev-kit-v0.15.0) (2026-06-29)


### Features

* **dev-kit:** add pre-public-hardening skill ([f058951](https://github.com/nivintw/nivintw-claude-skills/commit/f05895109c44d13929317e07b78ff90be83fc756)), closes [#58](https://github.com/nivintw/nivintw-claude-skills/issues/58)

## [0.14.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.13.0...dev-kit-v0.14.0) (2026-06-29)


### Features

* **dev-kit:** add template-reconcile skill for the repo&lt;-&gt;template seam ([afdfcbf](https://github.com/nivintw/nivintw-claude-skills/commit/afdfcbf8879b69842cd045bab1c5925dcc0dfe26)), closes [#52](https://github.com/nivintw/nivintw-claude-skills/issues/52)
* **dev-kit:** handle-task-tracking supports cross-repo issue filing ([932edef](https://github.com/nivintw/nivintw-claude-skills/commit/932edef0a1b9bc6aa02dd9d2777c3484904e141c)), closes [#49](https://github.com/nivintw/nivintw-claude-skills/issues/49)

## [0.13.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.12.0...dev-kit-v0.13.0) (2026-06-29)


### Features

* **dev-kit:** add /dev-kit:land command as a thin entry point to ship's land verb ([e172990](https://github.com/nivintw/nivintw-claude-skills/commit/e172990d46fdba5fefa8d2b1951e2182ad55f1fc)), closes [#77](https://github.com/nivintw/nivintw-claude-skills/issues/77)
* **dev-kit:** watch the release after a release-gated merge ([3fc2693](https://github.com/nivintw/nivintw-claude-skills/commit/3fc269389acc11a51ae03a6bea4df68555183c80)), closes [#55](https://github.com/nivintw/nivintw-claude-skills/issues/55)

## [0.12.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.11.0...dev-kit-v0.12.0) (2026-06-29)


### Features

* **dev-kit:** review-pr whole-repo audit mode + effort default + second-opinion synthesis ([ad17479](https://github.com/nivintw/nivintw-claude-skills/commit/ad174790efc6b14f26caafe928022358d6d6187f)), closes [#50](https://github.com/nivintw/nivintw-claude-skills/issues/50) [#60](https://github.com/nivintw/nivintw-claude-skills/issues/60)
* **dev-kit:** strip conversation-only comments in ship implement + simplify ([fc2a09e](https://github.com/nivintw/nivintw-claude-skills/commit/fc2a09e0695f19a836d1b3e14be8a7f32531a7a5)), closes [#63](https://github.com/nivintw/nivintw-claude-skills/issues/63)

## [0.11.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.10.0...dev-kit-v0.11.0) (2026-06-29)


### Features

* **dev-kit:** cleanup-locally reports merged remote branches ([c21373c](https://github.com/nivintw/nivintw-claude-skills/commit/c21373cad5077b48f2b1bf4879605f04fd7f4950)), closes [#61](https://github.com/nivintw/nivintw-claude-skills/issues/61)


### Bug Fixes

* **dev-kit:** doctor distinguishes published-not-downloaded from stale-load ([5ed2c96](https://github.com/nivintw/nivintw-claude-skills/commit/5ed2c96ad65545c7d06fd50707bfe278f542267a)), closes [#76](https://github.com/nivintw/nivintw-claude-skills/issues/76)

## [0.10.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.9.0...dev-kit-v0.10.0) (2026-06-29)


### Features

* **dev-kit:** treat newly-added suppressions as review findings ([7c8fcdb](https://github.com/nivintw/nivintw-claude-skills/commit/7c8fcdb321312142be01f52eb750075d326e392d)), closes [#53](https://github.com/nivintw/nivintw-claude-skills/issues/53)

## [0.9.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.8.0...dev-kit-v0.9.0) (2026-06-29)


### Features

* **dev-kit:** add a scope-confirmation beat to ship's plan phase ([7e98895](https://github.com/nivintw/nivintw-claude-skills/commit/7e9889585a4d5bd6b9783dcc9384fe362fa07994)), closes [#56](https://github.com/nivintw/nivintw-claude-skills/issues/56)
* **dev-kit:** treat worktree edits as authoritative at phase boundaries ([0f9cd63](https://github.com/nivintw/nivintw-claude-skills/commit/0f9cd6321f6d34ae030de48df70340ac617a00f8)), closes [#54](https://github.com/nivintw/nivintw-claude-skills/issues/54)


### Bug Fixes

* **dev-kit:** distinguish three states in ship's Copilot-review loop ([0cd556a](https://github.com/nivintw/nivintw-claude-skills/commit/0cd556accb481aee50aa7349796d5839406c37b8)), closes [#57](https://github.com/nivintw/nivintw-claude-skills/issues/57)

## [0.8.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.7.0...dev-kit-v0.8.0) (2026-06-29)


### Features

* **dev-kit:** add doctor skill (version drift + skill inventory) ([a7a9d58](https://github.com/nivintw/nivintw-claude-skills/commit/a7a9d58ceb3e012590aee072f4bbaba3b9715bf3)), closes [#47](https://github.com/nivintw/nivintw-claude-skills/issues/47)
* **dev-kit:** add opt-in land verb to ship ([34145b5](https://github.com/nivintw/nivintw-claude-skills/commit/34145b5c6ce48b158a989d78de2af652ade547ed)), closes [#44](https://github.com/nivintw/nivintw-claude-skills/issues/44)
* **dev-kit:** enforce typed, glossed issue/PR links in handle-task-tracking ([846769d](https://github.com/nivintw/nivintw-claude-skills/commit/846769d46ccf89a34d72464d850a911563987edb)), closes [#45](https://github.com/nivintw/nivintw-claude-skills/issues/45)


### Bug Fixes

* **dev-kit:** address review findings on land, waiting states, and doctor ([f8a4beb](https://github.com/nivintw/nivintw-claude-skills/commit/f8a4beb4ab50543bab299a74937e0e017c2d74f7))
* **dev-kit:** give ship's Stop hook waiting:ci/waiting:copilot park states ([733a497](https://github.com/nivintw/nivintw-claude-skills/commit/733a497ed841f48ce7807b2ab08c0429a70e34c5)), closes [#48](https://github.com/nivintw/nivintw-claude-skills/issues/48)
* **dev-kit:** stop generate-docs/review-pr skipping in-scope pre-existing drift ([b42c836](https://github.com/nivintw/nivintw-claude-skills/commit/b42c8368620c1f310d0f3ccb8279adcdc8f9e58a)), closes [#46](https://github.com/nivintw/nivintw-claude-skills/issues/46)

## [0.7.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.6.0...dev-kit-v0.7.0) (2026-06-29)


### Features

* **dev-kit:** add canonical output contract to open-work ([0edf854](https://github.com/nivintw/nivintw-claude-skills/commit/0edf854a9cf4d62c4e2316c93528251d81ccd6df)), closes [#41](https://github.com/nivintw/nivintw-claude-skills/issues/41)

## [0.6.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.5.1...dev-kit-v0.6.0) (2026-06-28)


### Features

* **dev-kit:** lead open-work output with in-progress work ([5e83714](https://github.com/nivintw/nivintw-claude-skills/commit/5e837149a2469cbf4e749b5a31ac4d1d6487651f))


### Bug Fixes

* **dev-kit:** reconcile issue status label on close so the ledger stops going stale ([20772bc](https://github.com/nivintw/nivintw-claude-skills/commit/20772bc1b75deb8909eaa2212cfe166c714cd896)), closes [#31](https://github.com/nivintw/nivintw-claude-skills/issues/31)

## [0.5.1](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.5.0...dev-kit-v0.5.1) (2026-06-28)


### Bug Fixes

* **dev-kit:** keep ship/review-pr from halting after a sub-skill hands back ([1841e59](https://github.com/nivintw/nivintw-claude-skills/commit/1841e599b330d13e1968933b628fb8bad26bd128)), closes [#27](https://github.com/nivintw/nivintw-claude-skills/issues/27)
* **dev-kit:** store ship run state under the git dir, not the working tree ([fd64443](https://github.com/nivintw/nivintw-claude-skills/commit/fd64443fcff230d0f5c51f1bb84ecc1af5489819)), closes [#25](https://github.com/nivintw/nivintw-claude-skills/issues/25)

## [0.5.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.4.0...dev-kit-v0.5.0) (2026-06-28)


### Features

* **dev-kit:** add docs-site validator for generate-docs ([49adcab](https://github.com/nivintw/nivintw-claude-skills/commit/49adcab75bd48f646eb8ed0d09059e02b7cd575a))
* **dev-kit:** rewrite generate-docs as docs reconciliation skill ([ec0480b](https://github.com/nivintw/nivintw-claude-skills/commit/ec0480bf70dc2b5dadb19a1c4f4d350f7264b377))


### Bug Fixes

* address Copilot review on docs validator and site ([a998217](https://github.com/nivintw/nivintw-claude-skills/commit/a9982170c9f85ff067682af324141a2cf519bcf4))
* address review — harden docs validator and JS robustness ([90da16c](https://github.com/nivintw/nivintw-claude-skills/commit/90da16c6b128abbb4cc57734131d5d9d54ff1428))
* flag protocol-relative refs as non-portable; restore dual-target in skill desc ([e6e16cd](https://github.com/nivintw/nivintw-claude-skills/commit/e6e16cd6befb787a0a715bf8858eae4151714dea))
* flag unsafe/non-portable URL schemes in docs validator ([a61c860](https://github.com/nivintw/nivintw-claude-skills/commit/a61c86072719fd241b0717006722eb4c56d518df))
* percent-decode anchor fragments and unify anchor parsing ([1fcfb75](https://github.com/nivintw/nivintw-claude-skills/commit/1fcfb75dfa50cfa7ca2f74edc525ff5f756b2742))

## [0.4.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.3.0...dev-kit-v0.4.0) (2026-06-27)


### Features

* **dev-kit:** teach /ship to shell out to a local Ollama model ([b348cc3](https://github.com/nivintw/nivintw-claude-skills/commit/b348cc3a353f0d9ba9bf1eb2c4cdd81446d7fed9))


### Bug Fixes

* **dev-kit:** drop the CLI-less aside that contradicted detection ([eff680a](https://github.com/nivintw/nivintw-claude-skills/commit/eff680a5822480a059c7943fb3865e8f987d0068))
* **dev-kit:** guard jq and add detection timeout in offload recipe ([4bdb17a](https://github.com/nivintw/nivintw-claude-skills/commit/4bdb17a14e6dbceac1668566bbb493850134ad0f))
* **dev-kit:** make the offload detection example degrade silently ([40b642a](https://github.com/nivintw/nivintw-claude-skills/commit/40b642ac1a00cae130c40ab8cc27a80cbf528398))
* **dev-kit:** make the Ollama offload recipe actually runnable ([e36f9f6](https://github.com/nivintw/nivintw-claude-skills/commit/e36f9f6edede4cf07549fb26fde93978db95dbac))

## [0.3.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.2.0...dev-kit-v0.3.0) (2026-06-27)


### Features

* **dev-kit:** add open-work skill for ranked pick-up-next selection ([aa39788](https://github.com/nivintw/nivintw-claude-skills/commit/aa397880c5f949f6b67890dce85b2100c42aef55)), closes [#16](https://github.com/nivintw/nivintw-claude-skills/issues/16)


### Bug Fixes

* **dev-kit:** tighten open-work "what's next" trigger to avoid misfires ([d3d1cd6](https://github.com/nivintw/nivintw-claude-skills/commit/d3d1cd6427b6719d88353976a49ba5094d013694))
* **dev-kit:** tighten open-work triggers and ranking after review ([1438fee](https://github.com/nivintw/nivintw-claude-skills/commit/1438fee23076828dc8028b505de8d5183edbf710))
* **dev-kit:** use full priority label names in open-work ranking ([415453b](https://github.com/nivintw/nivintw-claude-skills/commit/415453bafed43872e530fd3b94fef740e85d22b7))

## [0.2.0](https://github.com/nivintw/nivintw-claude-skills/compare/dev-kit-v0.1.0...dev-kit-v0.2.0) (2026-06-26)


### Features

* **dev-kit:** add cleanup-locally skill and wire it into ship ([c5af067](https://github.com/nivintw/nivintw-claude-skills/commit/c5af0675c5608b6cbf5d2188630042035d72774d))


### Bug Fixes

* **dev-kit:** close cleanup-locally review gaps on status, counting, and docs ([aa810c8](https://github.com/nivintw/nivintw-claude-skills/commit/aa810c88834e66ec1801be39651fd77b4d827579))
* **dev-kit:** harden cleanup-locally default-branch update ([5258bf2](https://github.com/nivintw/nivintw-claude-skills/commit/5258bf2a0d424e852175ab0f1f563c79e7c54a74))
* **dev-kit:** make cleanup-locally robust to the current checkout ([0a7f272](https://github.com/nivintw/nivintw-claude-skills/commit/0a7f272f20e2d681a1c68f52a63a2ee76730c143))
