import Confidence
import SwiftUI

@main
struct ConfidenceWatchApp: App {
    private let confidence: Confidence
    private let flaggingState = WatchFlaggingState()
    private let secret = ProcessInfo.processInfo.environment["CLIENT_SECRET"] ?? "<Empty Secret>"

    init() {
        confidence = Confidence
            .Builder(clientSecret: secret, loggerLevel: .TRACE)
            .withContext(initialContext: ["platform": .init(string: "watchOS")])
            .build()

        do {
            try confidence.activate()
        } catch {
            flaggingState.state = .error(error.localizedDescription)
        }

        let eval = confidence.getEvaluation(
            key: "swift-demoapp.color",
            defaultValue: "Gray")
        flaggingState.color = WatchContentView.getColor(color: eval.value)
        flaggingState.reason = eval.reason

        let state = flaggingState
        let client = confidence
        Task {
            do {
                state.state = .loading
                try await client.fetchAndActivate()
                state.state = .ready
            } catch {
                state.state = .error(error.localizedDescription)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView(confidence: confidence)
                .environmentObject(flaggingState)
        }
    }
}

class WatchFlaggingState: ObservableObject {
    var color: Color = .gray
    var reason: ResolveReason = .unknown
    @Published var state: State = .loading

    enum State: Equatable {
        case loading
        case ready
        case error(String)
    }
}
