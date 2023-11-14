import ConfidenceProvider
import OpenFeature
import SwiftUI

@main
struct ConfidenceDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    self.setup()
                }
        }
    }
}

extension ConfidenceDemoApp {
    func setup() {
        guard let secret = ProcessInfo.processInfo.environment["CLIENT_SECRET"] else {
            return
        }

        // If we have no cache, then do a fetch first.
        var initializationStratgey: InitializationStrategy = .activateAndFetchAsync
        if ConfidenceFeatureProvider.isStorageEmpty() {
            initializationStratgey = .fetchAndActivate
        }

        let provider = ConfidenceFeatureProvider
            .Builder(credentials: .clientSecret(secret: secret))
            .with(initializationStrategy: initializationStratgey)
            .build()
        // NOTE: Using a random UUID for each app start is not advised and can result in getting stale values.
        let ctx = MutableContext(targetingKey: UUID.init().uuidString, structure: MutableStructure())
        OpenFeatureAPI.shared.setProvider(provider: provider, initialContext: ctx)
    }
}
