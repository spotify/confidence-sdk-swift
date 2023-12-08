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
