import Confidence
import SwiftUI

class Status: ObservableObject {
    enum State {
        case unknown
        case ready
        case error(Error?)
    }

    @Published var state: State = .unknown
}


@main
struct ConfidenceDemoApp: App {
    @StateObject private var lifecycleObserver = ConfidenceAppLifecycleProducer()

    var body: some Scene {
        WindowGroup {
            let secret = ProcessInfo.processInfo.environment["CLIENT_SECRET"] ?? ""
            let confidence = Confidence.Builder(clientSecret: secret, loggerLevel: .TRACE)
                .withContext(initialContext: ["targeting_key": ConfidenceValue(string: UUID.init().uuidString)])
                .withRegion(region: .europe)
                .build()

            let status = Status()

            ContentView(confidence: confidence, status: status)
                .task {
                    do {
                        confidence.track(producer: lifecycleObserver)
                        try await self.setup(confidence: confidence)
                        status.state = .ready
                    } catch {
                        status.state = .error(error)
                        print(error.localizedDescription)
                    }
                }
        }
    }
}

extension ConfidenceDemoApp {
    func setup(confidence: Confidence) async throws {
        try await confidence.fetchAndActivate()
        try confidence.track(
            eventName: "all-types",
            data: [
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
