# OpenFeature Swift Provider

Swift implementation of the Konfidens feature provider.

## Usage

### Adding the package dependency

If you manage dependencies through Xcode go to "Add package" and enter `git@github.com:spotify/openfeature-swift-provider.git`.

If you manage dependencies through SPM, in the dependencies section of Package.swift add:
```swift
.package(url: "git@github.com:spotify/openfeature-swift-provider.git", from: "0.1.0")
```

and in the target dependencies section add:
```swift
.product(name: "KonfidensProvider", package: "openfeature-swift-provider"),
```

### Enabling the provider, setting the evaluation context and resolving flags

```swift
import KonfidensProvider
import OpenFeature

let provider = KonfidensFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret"))
    .build()
await OpenFeatureAPI.shared.setProvider(provider: provider)
let client = OpenFeatureAPI.shared.getClient()

let ctx = MutableContext(targetingKey: "myTargetingKey", structure: MutableStructure())
await OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)
let result = client.getBooleanValue(key: "flag.my-boolean", defaultValue: false, ctx: ctx)
```

Notes:
- If a flag can't be resolved from cache, the provider doesn't automatically resort to calling remote: refreshing the cache from remote only happens when setting a new provider and/or evaluation context in the global OpenFeatureAPI
- It's advised to not perform resolves while `setProvider` and `setEvaluationContext` are running, as the internals might be in an inconsistent state during these operations 

### Local overrides

Assume that you have a flag `button` with the schema:
```
{
    color: string,
    size: number
}
```

then you can locally override the size property by

```swift
OpenFeatureAPI.shared.provider =
    KonfidensFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret"))
        .overrides(.field(path: "button.size", variant: "control", value: .integer(4)))
        .build()
```

now, all resolves of `button.size` will return 4.

## Development

Open the project in Xcode and build by Product -> Build.

### Linting code

Code is automatically linted during build in Xcode, if you need to manually lint:
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

IT tests require a Konfidens client token to reach remote servers. The token can be created on the Konfidens portal. The Konfidens project used for IT tests is named `konfidens_e2e`.


```shell
./scripts/run_tests.sh <CLIENT_TOKEN>
```
