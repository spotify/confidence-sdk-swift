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
            structure: MutableStructure.init(attributes: ["country": .string("SE")]))
        Task {
            await OpenFeatureAPI.shared.setProviderAndWait(provider: provider, initialContext: ctx)
        }
        confidence.send(
            eventName: "all-types",
            message: [
                "my_string": ConfidenceValue(string: "hello_from_world"),
                "my_timestamp": ConfidenceValue(timestamp: Date()),
                "my_bool": ConfidenceValue(boolean: true),
                "my_date": ConfidenceValue(date: DateComponents(year: 2024, month: 4, day: 3)),
                "my_int": ConfidenceValue(integer: 2),
                "my_double": ConfidenceValue(double: 3.14),
                "my_list": ConfidenceValue(booleanList: [true, false]),
                "my_struct": ConfidenceValue(structure: [
                    "my_nested_struct": ConfidenceValue(structure: [
                        "my_nested_nested_struct": ConfidenceValue(structure: [
                            "my_nested_nested_nested_int": ConfidenceValue(integer: 666)
                        ]),
                        "my_nested_nested_list": ConfidenceValue(dateList: [
                            DateComponents(year: 2024, month: 4, day: 4),
                            DateComponents(year: 2024, month: 4, day: 5)
                        ])
                    ]),
                    "my_nested_string": ConfidenceValue(string: "nested_hello")
                ])
            ]
        )
    }
}
