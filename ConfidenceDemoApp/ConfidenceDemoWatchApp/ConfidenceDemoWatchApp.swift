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

@MainActor
final class WatchDemoModel: ObservableObject {
    @Published private(set) var value = "Gray"
    @Published private(set) var reason = "Not evaluated"
    @Published private(set) var providerStatus = "Not ready"
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private let api = OpenFeatureAPI()
    private let confidence: Confidence
    private var hasStarted = false

    init() {
        let secret = ProcessInfo.processInfo.environment["CLIENT_SECRET"] ?? "<Empty Secret>"
        confidence = Confidence.Builder(clientSecret: secret, loggerLevel: .DEBUG).build()
    }

    func start() async {
        guard !hasStarted else {
            return
        }
        hasStarted = true
        isLoading = true

        let strategy: InitializationStrategy = confidence.isStorageEmpty()
            ? .fetchAndActivate
            : .activateAndFetchAsync
        let provider = ConfidenceFeatureProvider(
            confidence: confidence,
            initializationStrategy: strategy
        )
        await api.setProviderAndWait(
            provider: provider,
            initialContext: ImmutableContext(
                targetingKey: "watch-demo-user",
                structure: ImmutableStructure(
                    attributes: ["platform": .string("watchOS")]
                )
            )
        )

        updateEvaluation()
        isLoading = false
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            try await confidence.fetchAndActivate()
            updateEvaluation()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

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

    private func updateEvaluation() {
        let details = api.getClient().getStringDetails(
            key: "swift-demoapp.color",
            defaultValue: "Gray"
        )
        value = details.value
        reason = details.reason ?? "Unknown"
        providerStatus = String(describing: api.getProviderStatus())
        errorMessage = details.errorMessage
    }
}

private struct WatchContentView: View {
    @ObservedObject var model: WatchDemoModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Circle()
                    .fill(model.color)
                    .frame(width: 48, height: 48)

                Text(model.value)
                    .font(.headline)

                Text("Provider: \(model.providerStatus)")
                    .font(.caption)

                Text("Reason: \(model.reason)")
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

                if model.isLoading {
                    ProgressView()
                }
            }
            .padding()
        }
    }
}
