# Confidence demo apps

The Xcode project contains iOS and watchOS demo targets backed by the local Confidence package:

- `ConfidenceDemoApp`
- `ConfidenceDemoWatchApp`

## Run the watchOS demo

1. Open `ConfidenceDemoApp.xcodeproj`.
2. Select the `ConfidenceDemoWatchApp` scheme and a watchOS simulator or device.
3. Add `CLIENT_SECRET` to the scheme's Run environment variables.
4. Run the app.

The watch app configures the Confidence OpenFeature provider and evaluates `swift-demoapp.color`. Login adds `user_id` with the value `user1` or `user4`, matching the iOS demo's context semantics. Startup activates the persisted cache immediately, then fetches and activates fresh values.

The flag screen mirrors the iOS demo:

- `[1] After loading` shows the latest evaluation after reconciliation, with two seconds of simulated latency so the loading state is visible.
- `[2] Latest cache` evaluates from the active cache whenever the view updates.
- `[3] Fixed value` captures the activated cache at startup and before login, and resets to Gray on logout.
- `[4] On navigation` captures the evaluation when the destination screen appears.

To exercise stale behavior, log in as one user and load a value, make the watch unable to reach the network, log out, then log in as the other user. The old cache remains usable, but the evaluation reason and provider status show that it is stale for the new context. Restore connectivity and tap Refresh to reconcile it.

The watch stores its login and flag cache locally. It does not share them with the iOS app; matching `user_id` values only make both apps eligible for the same assignment.

## Build from the command line

```sh
scripts/build.sh
```

The iOS target embeds the watch app, so this command compiles both demo targets.
