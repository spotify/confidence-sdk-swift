# Changelog

## [2.0.0](https://github.com/spotify/confidence-sdk-swift/compare/1.3.1...2.0.0) (2025-06-30)


### ⚠ BREAKING CHANGES

* fix: Restore ConfidenceStruct evals, align Dictionary evals ([#205](https://github.com/spotify/confidence-sdk-swift/issues/205))

### 🐛 Bug Fixes

* make a copy of old context ([#207](https://github.com/spotify/confidence-sdk-swift/issues/207)) ([e9318ee](https://github.com/spotify/confidence-sdk-swift/commit/e9318ee807c9118e83322f731af8d65da0daa043))


### ✨ New Features

* fix: Restore ConfidenceStruct evals, align Dictionary evals ([#205](https://github.com/spotify/confidence-sdk-swift/issues/205)) ([d32b95a](https://github.com/spotify/confidence-sdk-swift/commit/d32b95ab789a60a51a851b6629a03f33841e98c2))
* Full support for list evals ([39e5259](https://github.com/spotify/confidence-sdk-swift/commit/39e525960d04fb60089406a0aafeeb21a0def6b6))
* pass Array to flag evaluation ([#203](https://github.com/spotify/confidence-sdk-swift/issues/203)) ([39e5259](https://github.com/spotify/confidence-sdk-swift/commit/39e525960d04fb60089406a0aafeeb21a0def6b6))
* pass Dictionary to flag evaluation ([#193](https://github.com/spotify/confidence-sdk-swift/issues/193)) ([5c3344b](https://github.com/spotify/confidence-sdk-swift/commit/5c3344b9377d25f954c0cb9587d19dfeb247f62c))


### 🔄 Refactoring

* lint fix ([#208](https://github.com/spotify/confidence-sdk-swift/issues/208)) ([115cecf](https://github.com/spotify/confidence-sdk-swift/commit/115cecfd6254a173a9232ed1f753f51acccb8f97))

## [1.3.1](https://github.com/spotify/confidence-sdk-swift/compare/1.3.0...1.3.1) (2025-06-18)


### 🐛 Bug Fixes

* improve taskmanager thread safety ([#201](https://github.com/spotify/confidence-sdk-swift/issues/201)) ([883f512](https://github.com/spotify/confidence-sdk-swift/commit/883f5122ab33dcdfaf79ad31434e84180d4313b4))


### 📚 Documentation

* update flag name ([#195](https://github.com/spotify/confidence-sdk-swift/issues/195)) ([1d42190](https://github.com/spotify/confidence-sdk-swift/commit/1d4219053667617b27683bcd0c077610643f9d0a))
* update open feature sdk url ([#194](https://github.com/spotify/confidence-sdk-swift/issues/194)) ([ca493de](https://github.com/spotify/confidence-sdk-swift/commit/ca493de4a70ed8410d541a38921d9311707fde30))

## [1.3.0](https://github.com/spotify/confidence-sdk-swift/compare/1.2.0...1.3.0) (2025-04-28)


### ⚠ BREAKING CHANGES

* restructure automatic context decorator ([#185](https://github.com/spotify/confidence-sdk-swift/issues/185))

### 🐛 Bug Fixes

* change how we log resolve tester hints ([#192](https://github.com/spotify/confidence-sdk-swift/issues/192)) ([40b206a](https://github.com/spotify/confidence-sdk-swift/commit/40b206a4866d4f18e699f77415c3160f1a2cd1ef))


### ✨ New Features

* add shouldApply to control sending apply ([#188](https://github.com/spotify/confidence-sdk-swift/issues/188)) ([a4b1e0a](https://github.com/spotify/confidence-sdk-swift/commit/a4b1e0af5ccfc83d61ca566a78f4a4181b112d63))
* Adopt latest OF SDK ([#184](https://github.com/spotify/confidence-sdk-swift/issues/184)) ([652d5f0](https://github.com/spotify/confidence-sdk-swift/commit/652d5f019ecf2a16c0cf0a6eeb81a42a1d6fb986))


### 🔄 Refactoring

* restructure automatic context decorator ([#185](https://github.com/spotify/confidence-sdk-swift/issues/185)) ([3588ae8](https://github.com/spotify/confidence-sdk-swift/commit/3588ae80a3c6efe36f8eaa8fb33cb037f6dbc2f0))

## [1.2.0](https://github.com/spotify/confidence-sdk-swift/compare/1.1.0...1.2.0) (2024-12-10)


### ⚠ BREAKING CHANGES

* Context APIs changes and documentation/onboarding ([#180](https://github.com/spotify/confidence-sdk-swift/issues/180))

### 🐛 Bug Fixes

* align debug resolve log wording on all platforms ([5369e04](https://github.com/spotify/confidence-sdk-swift/commit/5369e0484dc6f1241818f0798f5da2ace24fa517))
* Align debug resolve log wording on all platforms ([#181](https://github.com/spotify/confidence-sdk-swift/issues/181)) ([5369e04](https://github.com/spotify/confidence-sdk-swift/commit/5369e0484dc6f1241818f0798f5da2ace24fa517))


### 🔄 Refactoring

* Context APIs changes and documentation/onboarding ([#180](https://github.com/spotify/confidence-sdk-swift/issues/180)) ([6eb5dc7](https://github.com/spotify/confidence-sdk-swift/commit/6eb5dc7d8c67c0b1f8b935909b04b670317d86fb))

## [1.1.0](https://github.com/spotify/confidence-sdk-swift/compare/1.0.1...1.1.0) (2024-11-19)


### 🐛 Bug Fixes

* Properly encoded Resolve Debug URL ([#177](https://github.com/spotify/confidence-sdk-swift/issues/177)) ([00bf389](https://github.com/spotify/confidence-sdk-swift/commit/00bf389734840efbb41f641f642621e57278724e))
* TypeMismatch doesn't trigger apply ([#172](https://github.com/spotify/confidence-sdk-swift/issues/172)) ([df38f0b](https://github.com/spotify/confidence-sdk-swift/commit/df38f0b1043663d11e51250393d5757e61e2dd22))


### ✨ New Features

* Client Key in Resolve Debug logs ([#176](https://github.com/spotify/confidence-sdk-swift/issues/176)) ([712ff6e](https://github.com/spotify/confidence-sdk-swift/commit/712ff6e927ed7d760af2dfe821e66a5a954027da))
* Resolve Debug at DEBUG level logging ([#174](https://github.com/spotify/confidence-sdk-swift/issues/174)) ([558c811](https://github.com/spotify/confidence-sdk-swift/commit/558c8112210b16572f76f2636c1fdaafe1a4bdb6))

## [1.0.1](https://github.com/spotify/confidence-sdk-swift/compare/1.0.0...1.0.1) (2024-11-06)


### 🐛 Bug Fixes

* TypeMismatch error is handled ([#170](https://github.com/spotify/confidence-sdk-swift/issues/170)) ([6a04cda](https://github.com/spotify/confidence-sdk-swift/commit/6a04cda8653dacf15b1389c7b9ece61adb031d3f))

## [1.0.0](https://github.com/spotify/confidence-sdk-swift/compare/0.3.0...1.0.0) (2024-11-05)


### 🐛 Bug Fixes

* Fix warnings and prevent potential issues ([#165](https://github.com/spotify/confidence-sdk-swift/issues/165)) ([448fb93](https://github.com/spotify/confidence-sdk-swift/commit/448fb930e869d8282566f5c1abfa147a1a6611e9))
* Make Confidence.cache thread-safe ([#167](https://github.com/spotify/confidence-sdk-swift/issues/167)) ([df2c37f](https://github.com/spotify/confidence-sdk-swift/commit/df2c37f3c5cdac3ab1bdc9d2da54b0e1e8f8a30d))


### 🧪 Tests

* date formatter in tests iOS18 ([#168](https://github.com/spotify/confidence-sdk-swift/issues/168)) ([9cab6bb](https://github.com/spotify/confidence-sdk-swift/commit/9cab6bbb3511c2672fddbe09f483795ab77ccd3f))

## [0.3.0](https://github.com/spotify/confidence-sdk-swift/compare/0.2.4...0.3.0) (2024-07-16)


### ⚠ BREAKING CHANGES

* getEvaluation doesnt throw ([#158](https://github.com/spotify/confidence-sdk-swift/issues/158))
* decrease API surface ([#156](https://github.com/spotify/confidence-sdk-swift/issues/156))

### 🐛 Bug Fixes

* handle Int32 and Int64 in defaultValue evaluations ([#162](https://github.com/spotify/confidence-sdk-swift/issues/162)) ([6bb03d5](https://github.com/spotify/confidence-sdk-swift/commit/6bb03d5e06fa4a57ee5d5356d1b925ca207ef993))


### ✨ New Features

* add timeout to fetchAndActivate ([#160](https://github.com/spotify/confidence-sdk-swift/issues/160)) ([ea18479](https://github.com/spotify/confidence-sdk-swift/commit/ea18479aea15932e5c737b17274b89e4eb550018))


### 📚 Documentation

* Add docs to public APIs ([#163](https://github.com/spotify/confidence-sdk-swift/issues/163)) ([2c4ee11](https://github.com/spotify/confidence-sdk-swift/commit/2c4ee11809e88b25713a178910232bc15a03b74c))
* fix typo ([#161](https://github.com/spotify/confidence-sdk-swift/issues/161)) ([297658b](https://github.com/spotify/confidence-sdk-swift/commit/297658ba4d0175693d637e69643dd0f992f981a7))
* update readme ([#153](https://github.com/spotify/confidence-sdk-swift/issues/153)) ([9e49bb0](https://github.com/spotify/confidence-sdk-swift/commit/9e49bb01c112a887c6892101c379a3764d48799e))
* Update READMEs ([#164](https://github.com/spotify/confidence-sdk-swift/issues/164)) ([c8437ac](https://github.com/spotify/confidence-sdk-swift/commit/c8437ac41e4a91b5024732c18b94634a60092ffe))


### 🔄 Refactoring

* decrease API surface ([917743b](https://github.com/spotify/confidence-sdk-swift/commit/917743b98df4b1bbae7caa7941540cf07e7b9316))
* decrease API surface ([#156](https://github.com/spotify/confidence-sdk-swift/issues/156)) ([917743b](https://github.com/spotify/confidence-sdk-swift/commit/917743b98df4b1bbae7caa7941540cf07e7b9316))
* getEvaluation doesnt throw ([#158](https://github.com/spotify/confidence-sdk-swift/issues/158)) ([09f6b73](https://github.com/spotify/confidence-sdk-swift/commit/09f6b735a0c54c5b43bb7415b5fff87d48ba379e))

## [0.2.4](https://github.com/spotify/confidence-sdk-swift/compare/0.2.3...0.2.4) (2024-07-02)


### 🐛 Bug Fixes

* Readme update ([#145](https://github.com/spotify/confidence-sdk-swift/issues/145)) ([2ffc41d](https://github.com/spotify/confidence-sdk-swift/commit/2ffc41d0dd77a6b801bc2b8232663516ecfbe70c))
* Removes flag resolving from Confidence child instances ([#149](https://github.com/spotify/confidence-sdk-swift/issues/149)) ([543c380](https://github.com/spotify/confidence-sdk-swift/commit/543c3808a73ca03be0ff37b210da63d86a08d8ad))


### ✨ New Features

* add debuglogger to confidence ([#144](https://github.com/spotify/confidence-sdk-swift/issues/144)) ([c8fe939](https://github.com/spotify/confidence-sdk-swift/commit/c8fe93988413eddeef765745cd498cc8e313ba82))


### 📚 Documentation

* Smaller clarification on logging ([#150](https://github.com/spotify/confidence-sdk-swift/issues/150)) ([4be8b1b](https://github.com/spotify/confidence-sdk-swift/commit/4be8b1ba0de65fea799ab926a14627d5d3898109))


### 🔄 Refactoring

* Remove unused errors ([#148](https://github.com/spotify/confidence-sdk-swift/issues/148)) ([82d69a0](https://github.com/spotify/confidence-sdk-swift/commit/82d69a0f7087e7147de87071bf5cf52e9bfbfc3d))

## [0.2.3](https://github.com/spotify/confidence-sdk-swift/compare/0.2.2...0.2.3) (2024-06-25)


### 🔄 Refactoring

* Revert "feat: CreateConfidence from Provider for Metadata ([#141](https://github.com/spotify/confidence-sdk-swift/issues/141))" ([#142](https://github.com/spotify/confidence-sdk-swift/issues/142)) ([643a49a](https://github.com/spotify/confidence-sdk-swift/commit/643a49ab969a87cda197f90ae34d63c81d074054))

## [0.2.2](https://github.com/spotify/confidence-sdk-swift/compare/0.2.1...0.2.2) (2024-06-18)


### 🐛 Bug Fixes

* Confidence version auto-update ([#140](https://github.com/spotify/confidence-sdk-swift/issues/140)) ([9611e60](https://github.com/spotify/confidence-sdk-swift/commit/9611e608af7ccef7f68e58e0ab36bc26feffce20))
* Issues with context/secret trigger error ([#137](https://github.com/spotify/confidence-sdk-swift/issues/137)) ([54a674e](https://github.com/spotify/confidence-sdk-swift/commit/54a674e7ff8be4c97ad296f6bf066b8641ae95b5))
* targeting_key conversion ([#136](https://github.com/spotify/confidence-sdk-swift/issues/136)) ([d295ffa](https://github.com/spotify/confidence-sdk-swift/commit/d295ffa81cce2bb0ef611caea6661319541ac40c))


### ✨ New Features

* CreateConfidence from Provider for Metadata ([#141](https://github.com/spotify/confidence-sdk-swift/issues/141)) ([bf368df](https://github.com/spotify/confidence-sdk-swift/commit/bf368df1fba8b545b22f16a901d1ebd7b5d6fde9))


### 📚 Documentation

* track needs try ([#133](https://github.com/spotify/confidence-sdk-swift/issues/133)) ([0983035](https://github.com/spotify/confidence-sdk-swift/commit/098303518b8ca8a4c165d75b4bcb024cdc6fba18))


### 🔄 Refactoring

* remove is_foreground from event producer ([#135](https://github.com/spotify/confidence-sdk-swift/issues/135)) ([da06d45](https://github.com/spotify/confidence-sdk-swift/commit/da06d458d426825a590b4d6342f08614ceb007e4))

## [0.2.1](https://github.com/spotify/confidence-sdk-swift/compare/0.2.0...0.2.1) (2024-05-29)


### 🐛 Bug Fixes

* Improved keys and remove typo ([#127](https://github.com/spotify/confidence-sdk-swift/issues/127)) ([f31fe85](https://github.com/spotify/confidence-sdk-swift/commit/f31fe853f06755e1df664e9ea2f871d685228383))


### ✨ New Features

* add functionality to manual flush events ([#122](https://github.com/spotify/confidence-sdk-swift/issues/122)) ([475df55](https://github.com/spotify/confidence-sdk-swift/commit/475df558f661e63acbbe361541a422216b17a788))
* introduce a writeQueue for event tracking ([#124](https://github.com/spotify/confidence-sdk-swift/issues/124)) ([a49a393](https://github.com/spotify/confidence-sdk-swift/commit/a49a39387d82a0a7ad444a882a7f1fba6a592eab))
* LifecycleProducer events are emitted immediately ([#131](https://github.com/spotify/confidence-sdk-swift/issues/131)) ([accaaa3](https://github.com/spotify/confidence-sdk-swift/commit/accaaa323270e9f7bcf55d3c69ded2f900a530cd))


### 📚 Documentation

* update readme to cover Confidence APIs ([#121](https://github.com/spotify/confidence-sdk-swift/issues/121)) ([4962baf](https://github.com/spotify/confidence-sdk-swift/commit/4962baf8f1b24165c4149ef6630ddf639508c500))


### 🔄 Refactoring

* `context` container in event payload ([#130](https://github.com/spotify/confidence-sdk-swift/issues/130)) ([a9d41fa](https://github.com/spotify/confidence-sdk-swift/commit/a9d41fae6646a1381874f46e8708b2475c6b026e))
* app-launched no msg ([91604eb](https://github.com/spotify/confidence-sdk-swift/commit/91604eb97f68d88089c04343a54b34af8fd37441))
* from "message" to "data" ([#132](https://github.com/spotify/confidence-sdk-swift/issues/132)) ([f85dc9b](https://github.com/spotify/confidence-sdk-swift/commit/f85dc9ba6d13ac65260ab288c3ee26dc0af723c5))
* No message in `app-launched` ([#128](https://github.com/spotify/confidence-sdk-swift/issues/128)) ([91604eb](https://github.com/spotify/confidence-sdk-swift/commit/91604eb97f68d88089c04343a54b34af8fd37441))
* visitor id is default ([#129](https://github.com/spotify/confidence-sdk-swift/issues/129)) ([873e6b7](https://github.com/spotify/confidence-sdk-swift/commit/873e6b722eb94b1c463cef4d0bb62428fdbcfedb))

## [0.2.0](https://github.com/spotify/confidence-sdk-swift/compare/0.1.4...0.2.0) (2024-05-10)


### 🐛 Bug Fixes

* Add payload merger to merge context and message ([#108](https://github.com/spotify/confidence-sdk-swift/issues/108)) ([3386dd6](https://github.com/spotify/confidence-sdk-swift/commit/3386dd6a38f6987ea27eb0aa0171c7267ca0bb3d))
* API call in Demo app ([#119](https://github.com/spotify/confidence-sdk-swift/issues/119)) ([bfdc949](https://github.com/spotify/confidence-sdk-swift/commit/bfdc94983d6bc1c24ff65a148637d38316bec04c))
* Fix cancel async ([#103](https://github.com/spotify/confidence-sdk-swift/issues/103)) ([873ebe7](https://github.com/spotify/confidence-sdk-swift/commit/873ebe7633060e926543432dd9a670d759bfe9bf))
* Improve testSlowFirstResolveWillbeCancelledOnSecondResolve ([#109](https://github.com/spotify/confidence-sdk-swift/issues/109)) ([0624dee](https://github.com/spotify/confidence-sdk-swift/commit/0624dee2b50fd69b48a0c1cddfaf642495abfc24))
* Provider cache and resolver are accessed safely ([#107](https://github.com/spotify/confidence-sdk-swift/issues/107)) ([d166712](https://github.com/spotify/confidence-sdk-swift/commit/d1667125ca6dbd520eab1f0dc3ba568966197f6d))
* Provider still works with OF ctx nil ([#115](https://github.com/spotify/confidence-sdk-swift/issues/115)) ([4d58327](https://github.com/spotify/confidence-sdk-swift/commit/4d583271fcd3e3655ca60036724f2e500ce783fc))
* Revert "fix: Reconciliation bug" ([#117](https://github.com/spotify/confidence-sdk-swift/issues/117)) ([45135ae](https://github.com/spotify/confidence-sdk-swift/commit/45135aeebc406fa4c2cc719ca5ef5f36ff4ad0c6))
* Track API ([#105](https://github.com/spotify/confidence-sdk-swift/issues/105)) ([996b272](https://github.com/spotify/confidence-sdk-swift/commit/996b272e414ef6e6642126dc9fc5e1f33e5b8159))
* use the current strategy in resolve function ([#101](https://github.com/spotify/confidence-sdk-swift/issues/101)) ([eafe8bf](https://github.com/spotify/confidence-sdk-swift/commit/eafe8bf59ea71dfeaae2b3bcd8599a05870041c5))
* Visitor Id context key ([e78344d](https://github.com/spotify/confidence-sdk-swift/commit/e78344d1ded3254dd3edb9e9f6930c878f8d8bde))
* Visitor id key ([#116](https://github.com/spotify/confidence-sdk-swift/issues/116)) ([e78344d](https://github.com/spotify/confidence-sdk-swift/commit/e78344d1ded3254dd3edb9e9f6930c878f8d8bde))


### ✨ New Features

* Add ConfidenceValue ([#84](https://github.com/spotify/confidence-sdk-swift/issues/84)) ([8de4b78](https://github.com/spotify/confidence-sdk-swift/commit/8de4b7805378866023e939aec39c71a78ba771fe))
* add EventStorage ([#87](https://github.com/spotify/confidence-sdk-swift/issues/87)) ([fdc7543](https://github.com/spotify/confidence-sdk-swift/commit/fdc754301c8c4bd497a132fdee868213e73e56b7))
* add listening for context changes ([#97](https://github.com/spotify/confidence-sdk-swift/issues/97)) ([0d1cefd](https://github.com/spotify/confidence-sdk-swift/commit/0d1cefdeb766a3d24c7d05be5f834d8855f271f3))
* Add resolving against confidence context ([#94](https://github.com/spotify/confidence-sdk-swift/issues/94)) ([a7cbb19](https://github.com/spotify/confidence-sdk-swift/commit/a7cbb195dd06d64e9ff12686d17994820ce6d90e))
* Add visitorID context ([#106](https://github.com/spotify/confidence-sdk-swift/issues/106)) ([0ca65ea](https://github.com/spotify/confidence-sdk-swift/commit/0ca65eaa7157fdf7dca4eac052f849cd6c3c9fd6))
* Append EvalContext to Events ([#85](https://github.com/spotify/confidence-sdk-swift/issues/85)) ([56f8130](https://github.com/spotify/confidence-sdk-swift/commit/56f81302aed36d4f0b6e7960f6c350b33708f632))
* Confidence value is decodable and encodable with schema ([#92](https://github.com/spotify/confidence-sdk-swift/issues/92)) ([444a191](https://github.com/spotify/confidence-sdk-swift/commit/444a1914c13a974fb779cb047ad225e5d0ef4a2a))
* Event sender engine ([#88](https://github.com/spotify/confidence-sdk-swift/issues/88)) ([b223804](https://github.com/spotify/confidence-sdk-swift/commit/b223804858d920c77e4a5cd77152d3b83b1c76e5))
* Event Uploader ([#91](https://github.com/spotify/confidence-sdk-swift/issues/91)) ([b5ba3e0](https://github.com/spotify/confidence-sdk-swift/commit/b5ba3e05e0b727bda13dd4868e277bef8a5e3394))
* handle status codes for retrying in uploader ([#95](https://github.com/spotify/confidence-sdk-swift/issues/95)) ([85b89ed](https://github.com/spotify/confidence-sdk-swift/commit/85b89ed592828b7e8d14ea60a914f8edca72416e))
* Implement `withContext` ([#89](https://github.com/spotify/confidence-sdk-swift/issues/89)) ([d0dddee](https://github.com/spotify/confidence-sdk-swift/commit/d0dddee43da840bb4d31c645295a2cb002aefcfc))
* Manage Events - track app lifecycle events ([#118](https://github.com/spotify/confidence-sdk-swift/issues/118)) ([e74af7c](https://github.com/spotify/confidence-sdk-swift/commit/e74af7c8bbafc41046c3435951f9335e3ad517a6))
* Move flag evaluation confidence ([#113](https://github.com/spotify/confidence-sdk-swift/issues/113)) ([5f3c8aa](https://github.com/spotify/confidence-sdk-swift/commit/5f3c8aa1ecd5cda2374783bcfa9634efb53233b4))
* Return previous value on Provider STALE ([#98](https://github.com/spotify/confidence-sdk-swift/issues/98)) ([896be5e](https://github.com/spotify/confidence-sdk-swift/commit/896be5eadef82caaa35a5452a4b8ea333449c9ff))


### 🧹 Chore

* release 0.2.0 ([#120](https://github.com/spotify/confidence-sdk-swift/issues/120)) ([34f603f](https://github.com/spotify/confidence-sdk-swift/commit/34f603f21812e0135caebe2660a67c2a2a22b792))


### 📚 Documentation

* Add apply documentation note ([#80](https://github.com/spotify/confidence-sdk-swift/issues/80)) ([1bd9525](https://github.com/spotify/confidence-sdk-swift/commit/1bd9525e5e0a7d40834aba7bc962225978a36f91))
* Confidence SDK and Tracked Events ([#112](https://github.com/spotify/confidence-sdk-swift/issues/112)) ([18ab190](https://github.com/spotify/confidence-sdk-swift/commit/18ab1902a531276b0ce956acf7ccffda7b3f9c77))
* Documentation for public protocols/constructors ([#111](https://github.com/spotify/confidence-sdk-swift/issues/111)) ([01dda08](https://github.com/spotify/confidence-sdk-swift/commit/01dda0868abba7ae456914c1b7a1e4c1117834e1))
* STALE behaviour ([#102](https://github.com/spotify/confidence-sdk-swift/issues/102)) ([d4ec757](https://github.com/spotify/confidence-sdk-swift/commit/d4ec757a9c8011917eb1d86df9e8d7d2b0ffca11))


### 🔄 Refactoring

* Add Confidence Library scaffolding ([#83](https://github.com/spotify/confidence-sdk-swift/issues/83)) ([2e49e23](https://github.com/spotify/confidence-sdk-swift/commit/2e49e2370d29d63450cc094894743fae92914df5))
* Add message container to payload ([#99](https://github.com/spotify/confidence-sdk-swift/issues/99)) ([f0bf363](https://github.com/spotify/confidence-sdk-swift/commit/f0bf36358b1d691831845d576b9b942127180ef7))
* Rename product ([#114](https://github.com/spotify/confidence-sdk-swift/issues/114)) ([587a778](https://github.com/spotify/confidence-sdk-swift/commit/587a7789395389afea6255bc398edfcb78bb9182))
* Rename product name ([587a778](https://github.com/spotify/confidence-sdk-swift/commit/587a7789395389afea6255bc398edfcb78bb9182))
* send to track rename ([#100](https://github.com/spotify/confidence-sdk-swift/issues/100)) ([3c4febf](https://github.com/spotify/confidence-sdk-swift/commit/3c4febf10ca2919c4e2b20d831d371180513d0b8))

## [0.1.4](https://github.com/spotify/confidence-openfeature-provider-swift/compare/0.1.3...0.1.4) (2024-02-08)


### 🐛 Bug Fixes

* change STALE reason in case of context change ([#79](https://github.com/spotify/confidence-openfeature-provider-swift/issues/79)) ([9f5c91f](https://github.com/spotify/confidence-openfeature-provider-swift/commit/9f5c91feace22e227db63776a8808656fd926734))
* Remove extra slash in URL ([#74](https://github.com/spotify/confidence-openfeature-provider-swift/issues/74)) ([1f33e21](https://github.com/spotify/confidence-openfeature-provider-swift/commit/1f33e21954bf2fd1e540dd30418bdfdb432c2a8c))
* Remove STALE event ([#78](https://github.com/spotify/confidence-openfeature-provider-swift/issues/78)) ([485d09f](https://github.com/spotify/confidence-openfeature-provider-swift/commit/485d09f26a96fda0b2972f0c3d14f7b2e1ad12e3))


### 🧹 Chore

* Update CODEOWNERS ([#75](https://github.com/spotify/confidence-openfeature-provider-swift/issues/75)) ([500d84e](https://github.com/spotify/confidence-openfeature-provider-swift/commit/500d84ecc4c357f0239e850cf318f18c2299cca7))

## [0.1.3](https://github.com/spotify/confidence-openfeature-provider-swift/compare/0.1.2...0.1.3) (2024-01-30)


### 🐛 Bug Fixes

* add a default endpoint to the provider ([#68](https://github.com/spotify/confidence-openfeature-provider-swift/issues/68)) ([9d8d173](https://github.com/spotify/confidence-openfeature-provider-swift/commit/9d8d1732f8224b719afd0ee20b9cbcf6b3b6e8a2))
* Address in transit cache on startup ([#71](https://github.com/spotify/confidence-openfeature-provider-swift/issues/71)) ([a090f3e](https://github.com/spotify/confidence-openfeature-provider-swift/commit/a090f3ede3678c1513ad38b6313d38cc1c75a892))
* Fix FlagApplier async behaviour ([#70](https://github.com/spotify/confidence-openfeature-provider-swift/issues/70)) ([f169d90](https://github.com/spotify/confidence-openfeature-provider-swift/commit/f169d907127b0c073204c3355f64443cb7299466))


### 📚 Documentation

* Add Confidence link to the README ([#64](https://github.com/spotify/confidence-openfeature-provider-swift/issues/64)) ([60ba971](https://github.com/spotify/confidence-openfeature-provider-swift/commit/60ba971efe94545c969f89f113e2f1dbce5c2561))
* Add documentation about `apply` ([#72](https://github.com/spotify/confidence-openfeature-provider-swift/issues/72)) ([9cac324](https://github.com/spotify/confidence-openfeature-provider-swift/commit/9cac324b256fe4cdb67c7afbaa2d521578c044d1))
* Add documentation about apply ([9cac324](https://github.com/spotify/confidence-openfeature-provider-swift/commit/9cac324b256fe4cdb67c7afbaa2d521578c044d1))
* Fix SPM dependency in README ([#67](https://github.com/spotify/confidence-openfeature-provider-swift/issues/67)) ([9bdcb3e](https://github.com/spotify/confidence-openfeature-provider-swift/commit/9bdcb3e1f4fd554a0c07f6b3c4b60c0def7988ea))


### 🔄 Refactoring

* Remove callbacks from HttpClient ([#73](https://github.com/spotify/confidence-openfeature-provider-swift/issues/73)) ([403712a](https://github.com/spotify/confidence-openfeature-provider-swift/commit/403712a03c89bd3a3c6fb8aa9c2fc262c4133ddf))

## [0.1.2](https://github.com/spotify/confidence-openfeature-provider-swift/compare/0.1.1...0.1.2) (2023-11-16)


### ✨ New Features

* Add SDK id and version to requests ([#62](https://github.com/spotify/confidence-openfeature-provider-swift/issues/62)) ([e1cb474](https://github.com/spotify/confidence-openfeature-provider-swift/commit/e1cb4747b31989b43ac5a33f4022e162f93942c0))

## [0.1.1](https://github.com/spotify/confidence-openfeature-provider-swift/compare/v0.1.0...0.1.1) (2023-11-15)


### ✨ New Features

* Initialization strategy ([#55](https://github.com/spotify/confidence-openfeature-provider-swift/issues/55)) ([2c8c7f1](https://github.com/spotify/confidence-openfeature-provider-swift/commit/2c8c7f147d90e71cf9a547df2d729c680e58114c))
* Storage check ([#61](https://github.com/spotify/confidence-openfeature-provider-swift/issues/61)) ([db74dd5](https://github.com/spotify/confidence-openfeature-provider-swift/commit/db74dd56a0946fd8439e3146ee953f7e6a0b2359))


### 🧹 Chore

* Update CODEOWNERS ([#56](https://github.com/spotify/confidence-openfeature-provider-swift/issues/56)) ([1a7b379](https://github.com/spotify/confidence-openfeature-provider-swift/commit/1a7b379fa54a04111786c71dcc1bc5a537bd9958))
* update to use sdk from openfeature repo ([#50](https://github.com/spotify/confidence-openfeature-provider-swift/issues/50)) ([e618e31](https://github.com/spotify/confidence-openfeature-provider-swift/commit/e618e318837fec55d28137b8f99ceff1087e4c40))


### 📚 Documentation

* add release-please markers in readme.md ([#58](https://github.com/spotify/confidence-openfeature-provider-swift/issues/58)) ([21973d5](https://github.com/spotify/confidence-openfeature-provider-swift/commit/21973d51a51e8d6dc2796432047f82fdc51ee316))


### 🔄 Refactoring

* Fix swift lint warnings ([#60](https://github.com/spotify/confidence-openfeature-provider-swift/issues/60)) ([125ed50](https://github.com/spotify/confidence-openfeature-provider-swift/commit/125ed50d00a48604083ffb586d81c8663a1d5275))
