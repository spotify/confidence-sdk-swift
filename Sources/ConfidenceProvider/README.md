# OpenFeature Provider
If you want to use OpenFeature, an OpenFeature Provider for the [OpenFeature SDK](https://github.com/open-feature/kotlin-sdk) is also available.

## Usage

### Swift Package Manager

<!---x-release-please-start-version-->
In the dependencies section of Package.swift add:
```swift
.package(url: "git@github.com:spotify/confidence-sdk-swift.git", from: "1.3.0")
```
<!---x-release-please-end-->

and in the target dependencies section add:
```swift
.product(name: "Confidence", package: "confidence-sdk-swift"),
.product(name: "ConfidenceProvider", package: "confidence-sdk-swift"),
```

### Create and set the Provider

The Confidence Provider instance needs to be created and then set in the global OpenFeatureAPI.
The Confidence Provider takes in the configured Confidence instance for its initialization:
```swift
import Confidence
import ConfidenceProvider
import OpenFeature

let confidence = Confidence.Builder(clientSecret: "mysecret", loggerLevel: .NONE).build()
let provider = ConfidenceFeatureProvider(confidence: confidence)
let ctx = MutableContext(targetingKey: "myTargetingKey", structure: MutableStructure())
OpenFeatureAPI.shared.setProvider(provider: provider, initialContext: ctx)
```

The evaluation context is the way for the client to specify contextual data that Confidence uses to evaluate rules defined on the flag.

The `setProvider()` function is synchronous and returns immediately, however this does not mean that the provider is ready to be used. An asynchronous network request to the Confidence backend to fetch all the flags configured for your application must be completed by the provider first. The provider will then emit a _READY_ event indicating you can start resolving flags.

There is also an `async/await` compatible API available for waiting the Provider to become ready:
```swift
await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)
```

A utility function is available on the provider to check if the current storage has any stored values - this can be used to determine the best initialization strategy.
```swift
// If we have no cache, then do a fetch first.
var initializationStrategy: InitializationStrategy = .activateAndFetchAsync
if ConfidenceFeatureProvider.isStorageEmpty() {
    initializationStrategy = .fetchAndActivate
}
```

Initialization strategies:
- _activateAndFetchAsync_: the flags in the cached are used for this session, while updated values are fetched and stored on disk for a future session; this means that a READY event is immediately emitted when calling `setProvider()`;
- _fetchAndActivate_: the Provider attempts to refresh the flag cache on disk before exposing the flags; this might prolong the time needed for the Provider to become READY.

To listen for the _READY_ event, you can add an event handler via the `OpenFeatureAPI` shared instance:
```swift
OpenFeatureAPI.shared.observe().sink { event in
    if event == .ready {
        // Provider is ready
    }
}
```

**Note:** if you do attempt to resolve a flag before the READY event is emitted, you may receive the default value with the reason `STALE`.

There are other events that are emitted by the provider, see [Provider Events](https://openfeature.dev/specification/types#provider-events) in the Open Feature specification for more details.

### Updating the Evaluation Context

It is possible to update the evaluation context within an application's session via the following API:
```swift
let ctx = MutableContext(targetingKey: "myNewTargetingKey", structure: MutableStructure())
OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)
```

`setEvaluationContext()` is a synchronous function similar to `setProvider()`. It calls the Confidence backend to fetch the flag evaluations according to the new evaluation context; if the call is successful, it replaces the cache with the new flag data.

**Notes:**

- The initialization strategy is not taken into consideration when calling `setEvaluationContext()`, so it's required to wait for READY before resuming to resolve flags.

- If you do attempt to resolve a flag before the READY event is emitted, you may receive the old value with the reason `STALE`.

- A "targeting key" in the evaluation context is expected by the OpenFeature APIs, but a different custom field inside the `structure` value can also be configured as the randomization unit in the Confidence portal. In this case, it's okay to leave `targetingKey` empty.

### Handling Provider Errors

When calling `setEvaluationContext()` or `setProvider()` via the `OpenFeatureAPI` an _ERROR_ event can be emitted if something goes wrong.

To listen for the _ERROR_ event, you can add an event handler via the `OpenFeatureAPI` shared instance:
```swift
OpenFeatureAPI.shared.observe().sink { event in
    if event == .error {
        // An error has been emitted
    }
}
```

### Request a flag / value

The `client` is used to retrieve values for the current user / context. For example, retrieving a boolean value for the
flag `my-flag.my-boolean`:

```swift
let client = OpenFeatureAPI.shared.getClient()
let result = client.getBooleanValue(key: "my-flag.my-boolean", defaultValue: false)
```

In Confidence each flag value is a complex data structure including one or more properties of different types. To access a specific flag's property, the dot notation in the example above is used. The full data structure for a flag can always be fetched via:
```swift
let result = client.getObjectValue(key: "my-flag", defaultValue: Value.null)
```

**Note:** if a flag can't be resolved from the local cache, the provider doesn't automatically resort to calling remote. Refreshing the cache from remote only happens when setting a new provider and/or evaluation context in the global OpenFeatureAPI.
