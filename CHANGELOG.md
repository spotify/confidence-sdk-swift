# Changelog

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
