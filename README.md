# Swift Confidence SDK

This repo contains the official Swift SDK for accessing feature flags and for event tracking with [Confidence](https://confidence.spotify.com/).

It also contains the Confidence OpenFeature Provider, to be used in conjunction with the [OpenFeature SDK](https://openfeature.dev/docs/reference/concepts/provider).

For documentation related to flags management and event tracking in Confidence, refer to the [Confidence documentation website](https://confidence.spotify.com/docs).

Functionalities:
- Managed integration with the Confidence backend
- Prefetch and cache flag evaluations, for fast value reads even when the application is offline
- Automatic data collection about which flags have been accessed by the application
- Event tracking for instrumenting your application

## Dependency Setup

### Swift Package Manager

<!---x-release-please-start-version-->
In the dependencies section of Package.swift add:
```swift
.package(url: "git@github.com:spotify/confidence-sdk-swift.git", from: "1.0.1")
```
<!---x-release-please-end-->

and in the target dependencies section add:
```swift
.product(name: "Confidence", package: "confidence-sdk-swift"),
```

### Xcode Dependencies

You have two options, both start from File > Add Packages... in the code menu.

First, ensure you have your GitHub account added as an option (+ > Add Source Control Account...). You will need to create a [Personal Access Token](https://github.com/settings/tokens) with the permissions defined in the Xcode interface.

1. Add as a remote repository
    * Search for `git@github.com:spotify/confidence-sdk-swift.git` and click "Add Package"
2. Clone the repository locally (only recommended if you are making changes to the SDK)
    * Clone locally using your preferred method
    * Use the "Add Local..." button to select the local folder

### Swift 6 support

If your app is using some of the features of Swift 6, we recommend setting the **Strict Concurrency Checking** to 
**Minimal**.

### Creating the Confidence instance

```swift
import Confidence

let confidence = Confidence.Builder(clientSecret: "mysecret", loggerLevel: .NONE).build()
await confidence.fetchAndActivate()
```

- The `clientSecret` for your application can be generated in the Confidence portal.
- The `loggerLevel` sets the verbosity level for logging to console. This can be useful while testing your integration with the Confidence SDK.

_Note: the Confidence SDK has been intended to work as a single instance in your Application.
Creating multiple instances in the same runtime could lead to unexpected behaviours._

### Initialization strategy

`confidence.activateAndFetch()` is an async function that fetches the flags from the Confidence backend,
stores the result on disk, and make the same data ready for the Application to be consumed.

The alternative option is to call `confidence.activate()`: this loads previously fetched flags data
from storage and makes that available for the Application to consume right away.
To avoid waiting on backend calls when the Application starts, the suggested approach is to call
`confidence.activate()` and then trigger a background refresh via `confidence.asyncFetch()` for future sessions.

### Setting the context
The context is a key-value map used for sampling and for targeting, when flags are evaluated by the Confidence backend.
It is also appended to the tracked events, making it a great way to create dimensions for metrics in Confidence.

```swift
confidence.putContext(context: ["key": ConfidenceValue(string: "value")])
```

Another way to configure the context involves using the `track` API:
```swift
confidence.track(producer: contextProducerImplementation)
```

The "producer" conforms to `ConfidenceContextProducer`, which allows to dynamically push context changes
to the Confidence object.

In both cases above, any context change triggers a new asynchronous `fetchAndActivate` and the flags in the
local cache are re-evaluated remotely according to the new context: until this background operation is complete,
flag values are returned to the application according to the old context's evaluation, and with `resolveReason = .stale`.


### Resolving feature flags
Once the Confidence instance is **activated**, you can access the flag values using the
`getValue` method or the `getEvaluation` functions.
Both functions use generics to return a type defined by the default value type.

The method `getEvaluation` returns an `Evaluation` object that contains the `value` of the flag, the `reason`
for the value returned and the `variant` selected.

The method `getValue` will simply return the assigned value or the default.
In the case of an error, the default value will be returned and the `Evaluation` contains information about the error.

```swift
let message: String = confidence.getValue(key: "flag-name.message", defaultValue: "default message") 
let messageFlag: Evaluation<String> = confidence.getEvaluation(key: "flag-name.message", defaultValue: "default message")

let messageValue = messageFlag.value
// message and messageValue are the same
```

### Tracking events
The Confidence instance offers APIs to track events, which are uploaded to the Confidence backend:
```swift
try confidence.track(eventName: "MyEvent", data: ["field": ConfidenceValue(string("value"))])
```

The SDK takes care of storing events in case of offline and retries in case of transient failures.

Note that the data struct can't contain the key `context`, as that is reserved for entries set via `putContext` (see below):
violating this rule will cause the track function to throw an error.

To set context data to be appended to all tracked events, here is an example:
```swift
confidence.putContext(context: ["os_version": ConfidenceValue(string: "17.0")])
```

# OpenFeature Provider
If you want to use OpenFeature, an OpenFeature Provider for the [OpenFeature SDK](https://github.com/open-feature/kotlin-sdk) is also available.
See the [dedicated Provider Readme](https://github.com/spotify/confidence-sdk-swift/tree/main/Sources/ConfidenceProvider).
