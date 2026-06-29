# Changelog

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
