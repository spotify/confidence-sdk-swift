import Confidence
import SwiftUI

@main
struct ConfidenceDemoApp: App {
    @AppStorage("loggedUser")
    private var loggedUser: String?
    @AppStorage("appVersion")
    private var appVersion = 0

    private let confidence: Confidence
    private let flaggingState = ExperimentationFlags()
    private let secret = ProcessInfo.processInfo.environment["CLIENT_SECRET"] ?? "<Empty Secret>"

    init() {
        @AppStorage("appVersion") var appVersion = 0
        @AppStorage("loggedUser") var loggedUser: String?
        appVersion += 1 // Simulate update of the app on every new run
        var context = ["app_version": ConfidenceValue.init(integer: appVersion)]
        if let user = loggedUser {
            context["user_id"] = ConfidenceValue.init(string: user)
        }

        confidence = Confidence
            .Builder(clientSecret: secret, loggerLevel: .TRACE)
            .withContext(initialContext: context)
            .build()
        
        let contextProducer = ConfidenceDeviceInfoContextDecorator.builder()
            .withLocale()
            .withBundleId()
            .withDeviceInfo()
            .withVersionInfo()
            .build()

        confidence.track(producer: contextProducer)
        do {
            // NOTE: here we are activating all the flag values from storage, regardless of how `context` looks now
            try confidence.activate()
        } catch {
            flaggingState.state = .error(ExperimentationFlags.CustomError(message: error.localizedDescription))
        }
        // flaggingState.color is set here at startup and remains immutable until a user logs out
        let eval = confidence.getEvaluation(
            key: "swift-demoapp.color",
            defaultValue: "Gray")
        flaggingState.color = ContentView.getColor(
            color: eval.value)
        flaggingState.reason = eval.reason

        self.appVersion = appVersion
        self.loggedUser = loggedUser
        updateConfidence()
    }

    var body: some Scene {
        WindowGroup {
            if loggedUser == nil {
                LoginView(confidence: confidence)
                    .environmentObject(flaggingState)
            } else {
                ContentView(confidence: confidence)
                    .environmentObject(flaggingState)
            }
        }
    }

    private func updateConfidence() {
        Task {
            do {
                flaggingState.state = .loading
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // simulating slow network
                // The flags in storage are refreshed for the current `context`, and activated
                // After this line, fresh (and potentially new) flags values can be accessed
                try await confidence.fetchAndActivate()
                flaggingState.state = .ready
            } catch {
                flaggingState.state = .error(ExperimentationFlags.CustomError(message: error.localizedDescription))
            }
        }
    }
}

class ExperimentationFlags: ObservableObject {
    var color: Color = .red // This is set on applicaaton start, and reset on user logout
    var reason: ResolveReason = .unknown
    @Published var state: State = .notReady

    enum State: Equatable {
        case unknown
        case notReady
        case loading
        case ready
        case error(CustomError?)
    }

    public struct CustomError: Error, Equatable {
        let message: String
    }
}
