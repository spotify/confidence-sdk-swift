import ConfidenceProvider
import OpenFeature
import SwiftUI

@main
struct ConfidenceDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Task {
                        await self.setup()
                    }
                }
        }
    }
}

extension ConfidenceDemoApp {
    func setup() async {
        guard let secret = ProcessInfo.processInfo.environment["CLIENT_SECRET"] else {
            return
        }
        let provider = ConfidenceFeatureProvider
            .Builder(credentials: .clientSecret(secret: secret))
            .build()
        let ctx = MutableContext(targetingKey: UUID.init().uuidString, structure: MutableStructure())
        await OpenFeatureAPI.shared.setProvider(provider: provider, initialContext: ctx)
    }
}
