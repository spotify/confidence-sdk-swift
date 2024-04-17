import ConfidenceProvider
import Confidence
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
        var initializationStrategy: InitializationStrategy = .activateAndFetchAsync
        if ConfidenceFeatureProvider.isStorageEmpty() {
            initializationStrategy = .fetchAndActivate
        }

        let confidence = Confidence.Builder(clientSecret: secret)
            .withRegion(region: .europe)
            .withInitializationstrategy(initializationStrategy: initializationStrategy)
            .build()
        let provider = ConfidenceFeatureProvider(confidence: confidence)

        // NOTE: Using a random UUID for each app start is not advised and can result in getting stale values.
        let ctx = MutableContext(
            targetingKey: UUID.init().uuidString,
            structure: MutableStructure.init(attributes: [
                "my_string": .string("of_ctx"),
                "my_number": .integer(3)
            ]))
        confidence.updateContextEntry(key: "my_string", value: ConfidenceValue(string: "confidence_ctx"))
        confidence.updateContextEntry(key: "my_number", value: ConfidenceValue(integer: 5))
        Task {
            await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: ctx)
            confidence.send(
                definition: "test",
                payload: [
                    "my_string": ConfidenceValue(string: "message")
                ]
            )
        }
    }
}
