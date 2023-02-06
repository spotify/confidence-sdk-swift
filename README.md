# OpenFeature

Swift implementation of the Konfidens feature provider.

## Usage

### Adding the package dependency

If you manage dependencies through XCode go to "Add package" and enter `git@ghe.spotify.net:konfidens/openfeature-swift-provider.git`.

If you manage dependencies through SPM, in the dependencies section of Package.swift add:
```swift
.package(url: "git@ghe.spotify.net:konfidens/openfeature-swift-provider.git", from: "0.1.0")
```

and in the target dependencies section add:
```swift
.product(name: "KonfidensProvider", package: "openfeature-swift-provider"),
```

### Enabling the provider and resolving flags

There are two types of providers available:
- A **regular provider**: makes one network call per resolve operation (no caching)
- A **batch provider**: allows to pre-fetch all flags and cache/persist them locally

To use the regular provider:

```swift
import KonfidensProvider
import OpenFeature

OpenFeatureAPI.shared.provider =
    KonfidensFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret"))
        .build()
let client = OpenFeatureAPI.shared.getClient()

let ctx = MutableContext(targetingKey: "myTargetingKey", structure: MutableStructure())
let result = client.getBooleanValue(key: "flag.my-boolean", defaultValue: false, ctx: ctx)
```

To use the batch provider
```swift
import KonfidensProvider
import OpenFeature

let provider = KonfidensBatchFeatureProvider.Builder(credentials: .clientSecret(secret: "mysecret"))
    .build()
OpenFeatureAPI.shared.provider = provider
let client = OpenFeatureAPI.shared.getClient()

let ctx = MutableContext(targetingKey: "myTargetingKey", structure: MutableStructure())
try provider.initializeFromContext(ctx: ctx)
let result = client.getBooleanValue(key: "flag.my-boolean", defaultValue: false, ctx: ctx)
```

Notes about the batch provider:
- If a flag can't be resolved from cache, the batch provider doesn't automatically resort to calling remote: refreshing the cache from remote is responsibility of the user, and can be achieved by calling the following provider API:
  - `provider.initializeFromContext(ctx: EvaluationContext)`
- The cache operates on top of a single `EvaluationContext`: subsequent resolves with different `EvaluationContext`s won't succeed.

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

Open the project in XCode and build by Product -> Build.

### Linting code

Code is automatically linted during build in XCode, if you need to manually lint:
```shell
brew install swiftlint
swiftlint
```

### Formatting code

You can automatically format your code using:
```shell
./scripts/swift-format
```

### Running tests from command line

```shell
./scripts/run_tests.sh
```
