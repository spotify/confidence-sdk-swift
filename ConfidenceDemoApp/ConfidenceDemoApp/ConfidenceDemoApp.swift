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
                .withTimeout(timeout: 0.001)
                .withContext(initialContext: ["targeting_key": ConfidenceValue(string: UUID.init().uuidString)])
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
    }
}
