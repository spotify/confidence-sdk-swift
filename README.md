
# Swift Confidence SDK

Swift Confidence SDK enables seamless feature flag evaluation and event tracking for iOS and macOS applications using the [Confidence backend](https://confidence.spotify.com/).

This repository also contains the Confidence OpenFeature Provider, to be used with the [OpenFeature SDK](https://openfeature.dev/docs/reference/concepts/provider).

For detailed documentation on flag management and event tracking, see the [Confidence documentation website](https://confidence.spotify.com/docs).

## Features
- Managed integration with the Confidence backend.
- Prefetch and cache flag evaluations for fast reads even when offline.
- Automatic collection of accessed flag data.
- Event tracking to instrument your application.

## Dependency Setup

### Swift Package Manager

Add the following to the dependencies section of your `Package.swift`:

```swift
.package(url: "git@github.com:spotify/confidence-sdk-swift.git", from: "1.4.0")
```

Then add the product to your target dependencies:

```swift
.product(name: "Confidence", package: "confidence-sdk-swift"),
```

### Xcode Dependency Setup

Start from **File > Add Packages...** in the Xcode menu.

Make sure your GitHub account is added (**+ > Add Source Control Account...**), and create a [Personal Access Token](https://github.com/settings/tokens) with the required permissions.

You have two options:

1. Add as a remote repository  
   Search for `git@github.com:spotify/confidence-sdk-swift.git` and click **Add Package**.

2. Clone locally (recommended only if modifying the SDK)  
   - Clone the repository manually.  
   - Use the **Add Local...** button to select the folder.

### Swift 6 Support

If using Swift 6 features, set **Strict Concurrency Checking** to **Minimal** in your project settings.

### Creating the Confidence Instance

```swift
import Confidence

let confidence = Confidence
    .Builder(clientSecret: "mysecret", loggerLevel: .none)
    .withContext(context: ["user_id": ConfidenceValue(string: "user_1")])
    .build()

await confidence.fetchAndActivate()
```

- `clientSecret`: Generated in the Confidence portal for your app.  
- `loggerLevel`: Controls console log verbosity; useful during integration testing.  
- `withContext()`: Sets initial context (key-value map) used for sampling and targeting flags.

**Note:** The SDK is designed to have a single instance per application runtime. Creating multiple instances may cause unexpected behavior.

### Initialization Strategies

- `await confidence.fetchAndActivate()`: Asynchronously fetches flags based on current context, caches them, and activates them for use.  
- `confidence.activate()`: Loads cached flags and makes them immediately available.

To avoid blocking app startup on network calls, call `activate()` first, then `asyncFetch()` to update flags in the background.

**Important:** `activate()` ignores any context changes since the last fetch and uses cached flag values.

### Managing Context at Runtime

The context can be updated after initialization:

```swift
await confidence.putContext(context: ["key": ConfidenceValue(string: "value")])
await confidence.putContext(key: "key", value: ConfidenceValue(string: "value"))
await confidence.removeContext(key: "key")
```

These are asynchronous because they fetch updated flags from the backend and update storage.

**Note:** Context changes may result in different flag evaluations.  
**Note:** While fetching new flags, the old values remain available but are marked with evaluation reason `STALE`.

### Context Decorator Helper

Use `ConfidenceDeviceInfoContextDecorator` to append static device info to your context:

```swift
let context = ConfidenceDeviceInfoContextDecorator(
    withDeviceInfo: true,
    withAppInfo: true,
    withOsInfo: true,
    withLocale: true
).decorated(context: [:])  // You may pass an existing context here
```

The decorator adds:

- **App Info:** version, build, bundle identifier  
- **Device Info:** manufacturer ("Apple"), model identifier, device type  
- **OS Info:** system name and version  
- **Locale Info:** current locale and preferred languages

### Reading Flag Values

After activation, use:

```swift
let message: String = confidence.getValue(key: "flag-name.message", defaultValue: "default message")
let messageFlag: Evaluation<String> = confidence.getEvaluation(key: "flag-name.message", defaultValue: "default message")

let messageValue = messageFlag.value
// message and messageValue will be the same
```

`getEvaluation()` returns detailed info: value, reason, variant.  
`getValue()` returns just the value or the default on error.

You can use Swift Dictionary (`[String: Any]`) or `ConfidenceStruct` for complex flag schemas, but parsing the result carefully is advised.

### Tracking Events

Track events with:

```swift
try confidence.track(eventName: "MyEvent", data: ["field": ConfidenceValue(string: "value")])
```

- Events are stored and retried when offline.  
- The data dictionary **cannot contain the key `context`**, which is reserved for context data.

Set global context data for all events:

```swift
confidence.putContext(context: ["os_version": ConfidenceValue(string: "17.0")])
```

## OpenFeature Provider

Use the Confidence OpenFeature Provider with the [OpenFeature SDK](https://github.com/open-feature/swift-sdk).

See the [Provider README](https://github.com/spotify/confidence-sdk-swift/tree/main/Sources/ConfidenceProvider) for details.
