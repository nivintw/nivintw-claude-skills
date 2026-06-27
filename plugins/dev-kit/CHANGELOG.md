# Changelog

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
