import Confidence
import ConfidenceProvider
import OpenFeature
import SwiftUI

@main
struct ConfidenceDemoWatchApp: App {
    @StateObject private var model = WatchDemoModel()

    var body: some Scene {
        WindowGroup {
            WatchContentView(model: model)
                .task {
                    await model.start()
                }
        }
    }
}

struct WatchEvaluation {
    static let empty = WatchEvaluation(
        value: "Gray",
        reason: "Not evaluated",
        errorMessage: nil
    )

    let value: String
    let reason: String
    let errorMessage: String?

    var color: Color {
        switch value {
        case "Green":
            return .green
        case "Yellow":
            return .yellow
        case "Gray":
            return .gray
        default:
            return .red
        }
    }
}

@MainActor
final class WatchDemoModel: ObservableObject {
    @Published private(set) var currentUser: String?
    @Published private(set) var providerStatus = "Not ready"
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var hasCompletedInitialization = false
    @Published private(set) var fixedEvaluation = WatchEvaluation.empty
    @Published private(set) var appVersion: Int

    private let api = OpenFeatureAPI()
    private let confidence: Confidence
    private var hasStarted = false
    private let loggedUserKey = "watchDemoLoggedUser"
    private let appVersionKey = "watchDemoAppVersion"

    init() {
        let secret = ProcessInfo.processInfo.environment["CLIENT_SECRET"] ?? "<Empty Secret>"
        confidence = Confidence.Builder(clientSecret: secret, loggerLevel: .DEBUG).build()
        currentUser = UserDefaults.standard.string(forKey: loggedUserKey)
        let storedVersion = UserDefaults.standard.integer(forKey: appVersionKey)
        appVersion = max(storedVersion, 1)
        UserDefaults.standard.set(appVersion, forKey: appVersionKey)
    }

    func start() async {
        guard !hasStarted else {
            return
        }
        hasStarted = true
        isLoading = true

        confidence.putContextLocal(context: confidenceContext())
        do {
            try confidence.activate()
        } catch {
            errorMessage = error.localizedDescription
        }
        fixedEvaluation = evaluateActivatedCache()

        let provider = ConfidenceFeatureProvider(
            confidence: confidence,
            initializationStrategy: .fetchAndActivate
        )
        let latencyTask = Task {
            await waitForSimulatedLatency()
        }
        await api.setProviderAndWait(
            provider: provider,
            initialContext: evaluationContext()
        )
        await latencyTask.value

        updateStatus()
        errorMessage = evaluate().errorMessage
        hasCompletedInitialization = true
        isLoading = false
    }

    func refresh() async {
        await reconcileContext()
    }

    func simulateAppUpdate() async {
        appVersion += 1
        UserDefaults.standard.set(appVersion, forKey: appVersionKey)
        await reconcileContext()
    }

    func login(as user: String) async {
        do {
            try confidence.activate()
        } catch {
            errorMessage = error.localizedDescription
        }
        fixedEvaluation = evaluateActivatedCache()
        currentUser = user
        UserDefaults.standard.set(user, forKey: loggedUserKey)
        await reconcileContext()
    }

    func logout() async {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: loggedUserKey)
        fixedEvaluation = .empty
        await reconcileContext()
    }

    func evaluate() -> WatchEvaluation {
        let details = api.getClient().getStringDetails(
            key: "swift-demoapp.color",
            defaultValue: "Gray"
        )
        return WatchEvaluation(
            value: details.value,
            reason: details.reason ?? "Unknown",
            errorMessage: details.errorMessage
        )
    }

    private func reconcileContext() async {
        isLoading = true
        errorMessage = nil
        let latencyTask = Task {
            await waitForSimulatedLatency()
        }
        await api.setEvaluationContextAndWait(evaluationContext: evaluationContext())
        await latencyTask.value
        updateStatus()
        errorMessage = evaluate().errorMessage
        hasCompletedInitialization = true
        isLoading = false
    }

    private func waitForSimulatedLatency() async {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }

    private func evaluateActivatedCache() -> WatchEvaluation {
        let evaluation = confidence.getEvaluation(
            key: "swift-demoapp.color",
            defaultValue: "Gray"
        )
        return WatchEvaluation(
            value: evaluation.value,
            reason: String(describing: evaluation.reason),
            errorMessage: evaluation.errorMessage
        )
    }

    private func confidenceContext() -> ConfidenceStruct {
        var context = [
            "platform": ConfidenceValue(string: "watchOS"),
            "app_version": ConfidenceValue(integer: appVersion)
        ]
        if let currentUser {
            context["user_id"] = ConfidenceValue(string: currentUser)
        }
        return context
    }

    private func evaluationContext() -> ImmutableContext {
        var attributes = [
            "platform": OpenFeature.Value.string("watchOS"),
            "app_version": OpenFeature.Value.integer(Int64(appVersion))
        ]
        if let currentUser {
            attributes["user_id"] = .string(currentUser)
        }
        return ImmutableContext(structure: ImmutableStructure(attributes: attributes))
    }

    private func updateStatus() {
        providerStatus = String(describing: api.getProviderStatus())
    }
}

private struct WatchContentView: View {
    @ObservedObject var model: WatchDemoModel

    var body: some View {
        NavigationView {
            Group {
                if let currentUser = model.currentUser {
                    WatchFlagScreen(model: model, currentUser: currentUser)
                } else {
                    WatchLoginScreen(model: model)
                }
            }
        }
    }
}

private struct WatchLoginScreen: View {
    @ObservedObject var model: WatchDemoModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Confidence")
                    .font(.title3)

                Text("Provider: \(model.providerStatus)")
                    .font(.caption2)

                Button("Login user1") {
                    Task {
                        await model.login(as: "user1")
                    }
                }
                .disabled(!model.hasCompletedInitialization || model.isLoading)

                Button("Login user4") {
                    Task {
                        await model.login(as: "user4")
                    }
                }
                .disabled(!model.hasCompletedInitialization || model.isLoading)

                if model.isLoading {
                    ProgressView()
                }
            }
            .padding()
        }
        .navigationTitle("Login")
    }
}

private struct WatchFlagScreen: View {
    @ObservedObject var model: WatchDemoModel
    let currentUser: String

    var body: some View {
        let liveEvaluation = model.evaluate()

        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Logged in as \(currentUser)")
                    .font(.caption2)

                WatchFlagRow(
                    label: "[1] After loading",
                    evaluation: liveEvaluation,
                    isLoading: model.isLoading
                )
                WatchFlagRow(
                    label: "[2] Latest cache",
                    evaluation: liveEvaluation
                )
                WatchFlagRow(
                    label: "[3] Fixed value",
                    evaluation: model.fixedEvaluation
                )

                Text("Provider: \(model.providerStatus)")
                    .font(.caption2)
                Text("App version: \(model.appVersion)")
                    .font(.caption2)

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.red)
                }

                Button("Refresh") {
                    Task {
                        await model.refresh()
                    }
                }
                .disabled(model.isLoading)

                Button("Simulate update") {
                    Task {
                        await model.simulateAppUpdate()
                    }
                }
                .disabled(model.isLoading)

                NavigationLink(
                    destination: WatchNavigationScreen(model: model),
                    label: {
                        Text("Navigate")
                    }
                )

                Button("Logout") {
                    Task {
                        await model.logout()
                    }
                }
                .disabled(model.isLoading)
            }
            .padding()
        }
        .navigationTitle("Flags")
    }
}

private struct WatchFlagRow: View {
    let label: String
    let evaluation: WatchEvaluation
    var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)

            if isLoading {
                HStack(spacing: 6) {
                    ProgressView()
                    Text("Loading")
                        .font(.caption)
                }
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(evaluation.color)
                        .frame(width: 14, height: 14)
                    Text(evaluation.value)
                        .font(.headline)
                }
                Text(evaluation.reason)
                    .font(.caption2)
            }
        }
    }
}

private struct WatchNavigationScreen: View {
    @ObservedObject var model: WatchDemoModel
    @State private var capturedEvaluation = WatchEvaluation.empty

    var body: some View {
        VStack(spacing: 8) {
            Text("[4] On navigation")
                .font(.caption2)
            Circle()
                .fill(capturedEvaluation.color)
                .frame(width: 48, height: 48)
            Text(capturedEvaluation.value)
                .font(.headline)
            Text(capturedEvaluation.reason)
                .font(.caption2)
        }
        .navigationTitle("Destination")
        .onAppear {
            capturedEvaluation = model.evaluate()
        }
    }
}
