# Contributing

Open the project in Xcode and build by Product -> Build.

## Linting code

Code is automatically linted during a build in Xcode. If you need to manually lint:

```shell
brew install swiftlint
swiftlint
```

## Formatting code

You can automatically format your code using:

```shell
./scripts/swift-format
```

## API diffs
We run a script to make sure that we don't make changes to the public API without intending to.
The diff script and the script to generate a new "golden api file" uses a tool called [SourceKitten](https://github.com/jpsim/SourceKitten) which can be installed using homebrew (`brew install sourcekitten`).

### The expected workflow is:
* Write code (that may change the public API).
* Optionally run `./scripts/api_diff.sh` to detect the api change.
* Run `./scripts/generate_public_api.sh` -- this will update the file in `./api`.
* Commit both code and the updated API file in the same commit. 

## Running tests

IT tests require a Confidence client token to reach remote servers. The token can be created on the Confidence portal. 
The Confidence organization used for IT tests is named `confidence-test` (you may need to request access).

The tests use the flag `swift-flag-test` and the enabled client name is `swift-provider-e2e`.

To run the tests:

```shell
./scripts/run_tests.sh <CLIENT_TOKEN>
```

Alternatively, you can store the client token in your local keychain, allowing you to run the shell script without any parameters.

To store the token, run the following (replacing `CLIENT_TOKEN`):
```shell
security add-generic-password -s 'swift-provider-e2e'  -a 'confidence-test' -w 'CLIENT_TOKEN'
```

You can then run the script as follows (note: you may need to allow access to the keychain on the first run):
```shell
./scripts/run_tests.sh
```
