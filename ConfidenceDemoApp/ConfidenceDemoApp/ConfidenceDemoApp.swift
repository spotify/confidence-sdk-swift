import Confidence
import ConfidenceProvider
import OpenFeature
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
        appVersion += 1
        var context = ["app_version": ConfidenceValue.init(integer: appVersion)]
        if let user = loggedUser {
            context["user_id"] = ConfidenceValue.init(string: user)
        }

        context = ConfidenceDeviceInfoContextDecorator(
            withDeviceInfo: true,
            withAppInfo: true,
            withOsInfo: true,
            withLocale: true
        ).decorated(context: context)

        confidence = Confidence
            .Builder(clientSecret: secret, loggerLevel: .TRACE)
            .withContext(initialContext: context)
            .build()

        let provider = ConfidenceFeatureProvider(confidence: confidence)
        OpenFeatureAPI.shared.setProvider(provider: provider)

        do {
            try confidence.activate()
        } catch {
            flaggingState.state = .error(ExperimentationFlags.CustomError(message: error.localizedDescription))
        }

        let client = OpenFeatureAPI.shared.getClient()
        let eval = client.getStringDetails(key: "swift-demoapp.color", defaultValue: "Gray")
        print("[Telemetry] OpenFeature evaluation: key=swift-demoapp.color value=\(eval.value) reason=\(eval.reason ?? "nil")")

        flaggingState.color = ContentView.getColor(color: eval.value)
        flaggingState.reason = ResolveReason(rawValue: eval.reason ?? "") ?? .unknown

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
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                try await confidence.fetchAndActivate()
                flaggingState.state = .ready
                print("[Telemetry] Flags fetched and activated")
            } catch {
                flaggingState.state = .error(ExperimentationFlags.CustomError(message: error.localizedDescription))
            }
        }
    }
}

class ExperimentationFlags: ObservableObject {
    var color: Color = .red
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
