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

        // If we have no cache, then do a fetch first.
        var initializationStratgey: InitializationStrategy =  .activateAndFetchAsync
        if ConfidenceFeatureProvider.isStorageEmpty() {
            initializationStratgey = .fetchAndActivate
        }

        // Create an EventSender instance
        let Confidence = Confidence(clientSecret: "xa0fQ4WKSvuxdjPtesupleiSbZeik6Gf")
        let eventSender = Confidence.createEventSender()

        // Configure the OF singleton
        let provider = Confidence.providerBuilder()
            .with(initializationStrategy: initializationStratgey)
            .build()
        let evalContext = MutableContext(
            targetingKey: UUID.init().uuidString,
            structure: MutableStructure())
        OpenFeatureAPI.shared.setProvider(
            provider: provider,
            initialContext: evalContext)

        // Send an event
        eventSender.send(
            eventName: "button-clicked",
            message: ButtonClicked(
                os_version: "17",
                button_id: "sdk-test",
                os_name: "iOS"))
    }
}

struct ButtonClicked: Codable {
    var os_version: String
    var button_id: String
    var os_name: String
}
