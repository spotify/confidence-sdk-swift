# OpenFeature Swift Confidence Provider

Swift implementation of the Confidence feature provider, to be used in conjunction with the OpenFeature SDK.

## Dependency Setup

### Xcode Dependencies

You have two options, both start from File > Add Packages... in the code menu.

First, ensure you have your GitHub account added as an option (+ > Add Source Control Account...). You will need to create a [Personal Access Token](https://github.com/settings/tokens) with the permissions defined in the Xcode interface.

1. Add as a remote repository
    * Search for `git@github.com:spotify/confidence-openfeature-provider-swift.git` and click "Add Package"
2. Clone the repository locally
    * Clone locally using your preferred method
    * Use the "Add Local..." button to select the local folder

Note: Option 2 is only recommended if you are making changes to the provider, you will also need to add
the relevant OpenFeature SDK manually.

### Swift Package Manager

In the dependencies section of Package.swift add:
```swift
.package(url: "git@github.com:spotify/confidence-openfeature-provider-swift.git", from: "0.1.0")
```

and in the target dependencies section add:
```swift
.product(name: "ConfidenceProvider", package: "openfeature-swift-provider"),
```

## Usage

### Import Modules

Import the `ConfidenceProvider` and `OpenFeature` modules

```swift
import ConfidenceProvider
import OpenFeature
```

### Create and Apply the Provider

```swift
let provider = ConfidenceFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret")).build()
await OpenFeatureAPI.shared.setProvider(provider: provider)
let client = OpenFeatureAPI.shared.getClient()
```

### Create and Apply the Context

```swift
let ctx = MutableContext(targetingKey: "myTargetingKey", structure: MutableStructure())
await OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)
```

### Request a flag / value

The `client` is used to retrieve values for the current user / context. For example, retrieving a boolean value for the
flag `flag.my-boolean`:

```swift
let result = client.getBooleanValue(key: "flag.my-boolean", defaultValue: false)
```

Notes:
- If a flag can't be resolved from the local cache, the provider doesn't automatically resort to calling remote. 
Refreshing the cache from remote only happens when setting a new provider and/or evaluation context in the global OpenFeatureAPI
- It's advised not to perform resolves while `setProvider` and `setEvaluationContext` are running: 
resolves might return the default value with reason `STALE` during such operations. 

### Local overrides

Assume that you have a flag `button` with the schema:
```
{
    color: string,
    size: number
}
```

Then you can locally override the size property by

```swift
OpenFeatureAPI.shared.provider =
    ConfidenceFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret"))
        .overrides(.field(path: "button.size", variant: "control", value: .integer(4)))
        .build()
```

now, all resolves of `button.size` will return 4.

## Development

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
The Confidence organisation used for IT tests is named `konfidens-e2e` (you may need to request access).

The tests use the flag `test-flag-1` and the client key can be found under `Swift Provider - E2E Tests` in the console.

To run the tests:

```shell
./scripts/run_tests.sh <CLIENT_TOKEN>
```
