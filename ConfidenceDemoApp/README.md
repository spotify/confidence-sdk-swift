# Confidence demo apps

The Xcode project contains iOS and watchOS demo targets backed by the local Confidence package:

- `ConfidenceDemoApp`
- `ConfidenceDemoWatchApp`

## Run the watchOS demo

1. Open `ConfidenceDemoApp.xcodeproj`.
2. Select the `ConfidenceDemoWatchApp` scheme and a watchOS simulator or device.
3. Add `CLIENT_SECRET` to the scheme's Run environment variables.
4. Run the app.

The watch app configures the Confidence OpenFeature provider with the targeting key `watch-demo-user` and evaluates `swift-demoapp.color`. On the first launch it fetches and activates flags. Later launches activate the persisted cache immediately and refresh it asynchronously. The Refresh button fetches and activates the latest values in the current session.

The displayed provider status, evaluation reason, and error message make offline and stale-cache behavior visible. Use a stable targeting key shared with the iOS app when both devices must receive the same assignment.

## Build from the command line

```sh
scripts/build.sh
```

The iOS target embeds the watch app, so this command compiles both demo targets.
