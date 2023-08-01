## Contributing

Open the project in Xcode and build by Product -> Build.

### Linting code

Code is automatically linted during a build in Xcode. If you need to manually lint:

```shell
brew install swiftlint
swiftlint
```

### Formatting code

You can automatically format your code using:

```shell
./scripts/swift-format
```

### Running tests

IT tests require a Confidence client token to reach remote servers. The token can be created on the Confidence portal. 
The Confidence organization used for IT tests is named `konfidens-e2e` (you may need to request access).

The tests use the flag `test-flag-1` and the client key can be found under `Swift Provider - E2E Tests` in the console.

To run the tests:

```shell
./scripts/run_tests.sh <CLIENT_TOKEN>
```
