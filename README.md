# Swift Confidence SDK

This repo contains the official Swift SDK for accessing feature flags and for event tracking with [Confidence](https://confidence.spotify.com/).

It also contains the Confidence OpenFeature Provider, to be used in conjunction with the [OpenFeature SDK](https://openfeature.dev/docs/reference/concepts/provider).

For documentation related to flags management and event tracking in Confidence, refer to the [Confidence documentation website](https://confidence.spotify.com/docs).

Functionalities:
- Managed integration with the Confidence backend
- Prefetch and cache flag evaluations, for fast value reads even when the application is offline
- Automatic data collection about which flags have been accessed by the application
- Event tracking for instrumenting your application

## Supported platforms

- iOS 15+
- macOS 12+
- watchOS 8+

The core Confidence SDK and OpenFeature provider run natively on watchOS. Flag fetching, caching, evaluation, context management, and event tracking use the same APIs as on iOS.

`ConfidenceDeviceInfoContextDecorator` and `ConfidenceScreenTracker` are unavailable on watchOS because they depend on UIKit. Network refreshes and event uploads use a foreground `URLSession` and remain subject to watchOS suspension and background-execution limits. For fast startup, prefer `.activateAndFetchAsync` when a cached flag snapshot is available.

The generated `visitor_id` is local to each installation. Supply a stable targeting identity when iPhone and Apple Watch must receive consistent assignments.

# Using Confidence with OpenFeature

We suggest that you use Confidence together with the [OpenFeature SDK](https://github.com/open-feature/swift-sdk). This means that your app interacts completely with the OpenFeature SDK for feature flagging, and the Confidence Provider will be the engine for realizing the feature flagging values.


## Swift Package Manager

<!---x-release-please-start-version-->
In the dependencies section of Package.swift add:
```swift
.package(url: "git@github.com:spotify/confidence-sdk-swift.git", from: "1.8.0")
```
<!---x-release-please-end-->

and in the target dependencies section add:
```swift
.product(name: "Confidence", package: "confidence-sdk-swift"),
.product(name: "ConfidenceOpenFeature", package: "confidence-sdk-swift"),
```

## Create and set the Provider

The Confidence Provider instance needs to be created and then set in the global OpenFeatureAPI.
The Confidence Provider takes in the configured Confidence instance for its initialization:
```swift
import Confidence
import ConfidenceProvider
import OpenFeature

let confidence = Confidence.Builder(clientSecret: "mysecret", loggerLevel: .NONE).build()
let provider = ConfidenceFeatureProvider(confidence: confidence)
let ctx = ImmutableContext(targetingKey: "myTargetingKey", structure: ImmutableStructure())
OpenFeatureAPI.shared.setProvider(provider: provider, initialContext: ctx)
```

### Using a self-hosted local resolver sdk or sidecar resolver

Configure a custom resolve base URL to send flag resolve and apply requests to a [Confidence local resolver](https://confidence.spotify.com/docs/flags/local-resolver) or self-hosted sidecar resolver:

```swift
let confidence = Confidence.Builder(clientSecret: "mysecret")
    .withResolveBaseUrl(resolveBaseUrl: "http://localhost:8090")
    .build()
```

The SDK appends `/v1/flags:resolve` and `/v1/flags:apply` to this URL. Event tracking is not supported by the sidecar resolver and continues to use the Confidence events endpoint selected by `withRegion`.

The evaluation context is the way for the client to specify contextual data that Confidence uses to evaluate rules defined on the flag.

The `setProvider()` function is synchronous and returns immediately, however this does not mean that the provider is ready to be used. An asynchronous network request to the Confidence backend to fetch all the flags configured for your application must be completed by the provider first. The provider will then emit a _READY_ event indicating you can start resolving flags.

There is also an `async/await` compatible API available for waiting the Provider to become ready:
```swift
await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)
```

Choose an initialization strategy based on the age of the stored resolution:
```swift
let status = try confidence.getStorageStatus(check: MaxAgeStorageCheck(maxAge: 24 * 60 * 60))
let initializationStrategy: InitializationStrategy
switch status {
case .empty, .stale:
    initializationStrategy = .fetchAndActivate
case .fresh:
    initializationStrategy = .activateAndFetchAsync
}
let provider = ConfidenceFeatureProvider(
    confidence: confidence,
    initializationStrategy: initializationStrategy
)
```

`maxAge` is a positive, finite interval in seconds. A cache is stale at or beyond that age;
older caches without a fetch timestamp are also stale. Successful fetches persist the timestamp
with the resolution, even before activation. Failed fetches leave the timestamp unchanged.
Checking status does not fetch or activate flags, and storage read errors are thrown to the caller.

Implement `ResolveStorageCheck` for custom rules, such as checking the stored evaluation context:
```swift
struct UserStorageCheck: ResolveStorageCheck {
    let expectedUser: ConfidenceValue

    func check(metadata: ResolveStorageMetadata) -> ResolveStorageStatus {
        if metadata.isEmpty { return .empty }
        if metadata.context["user_id"] != expectedUser {
            return .stale(lastFetchedAt: metadata.lastFetchedAt)
        }
        return MaxAgeStorageCheck(maxAge: 24 * 60 * 60).check(metadata: metadata)
    }
}
```

`confidence.isStorageEmpty()` remains available when only cache presence matters.

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

## Updating the Evaluation Context

It is possible to update the evaluation context within an application's session via the following API:
```swift
let ctx = ImmutableContext(targetingKey: "myNewTargetingKey", structure: ImmutableStructure())
OpenFeatureAPI.shared.setEvaluationContext(evaluationContext: ctx)
```

`setEvaluationContext()` is a synchronous function similar to `setProvider()`. It calls the Confidence backend to fetch the flag evaluations according to the new evaluation context; if the call is successful, it replaces the cache with the new flag data.

**Notes:**

- The initialization strategy is not taken into consideration when calling `setEvaluationContext()`, so it's required to wait for READY before resuming to resolve flags.

- If you do attempt to resolve a flag before the READY event is emitted, you may receive the old value with the reason `STALE`.

- A "targeting key" in the evaluation context is expected by the OpenFeature APIs, but a different custom field inside the `structure` value can also be configured as the randomization unit in the Confidence portal. In this case, it's okay to leave `targetingKey` empty.

## Handling Provider Errors

When calling `setProvider()` via the `OpenFeatureAPI` an _ERROR_ event can be emitted if something goes wrong.
If `setEvaluationContext()` cannot fetch flags for the new context, a _STALE_ event is emitted and evaluations continue from the last cache.

To listen for the _ERROR_ event, you can add an event handler via the `OpenFeatureAPI` shared instance:
```swift
OpenFeatureAPI.shared.observe().sink { event in
    if event == .error {
        // An error has been emitted
    }
}
```

## Request a flag / value

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


# Confidence Vanilla SDK
If you want to use Confidence without OpenFeature, you can. Please take a look at our [dedicated SDK readme](https://github.com/spotify/confidence-sdk-swift/tree/main/Sources/Confidence).
