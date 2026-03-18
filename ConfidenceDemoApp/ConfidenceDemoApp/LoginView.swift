import SwiftUI
import Confidence
import ConfidenceProvider
import OpenFeature

struct LoginView: View {
    @EnvironmentObject
    var flaggingState: ExperimentationFlags
    @AppStorage("loggedUser")
    private var loggedUser: String?
    @State
    private var loginCompleted = false
    @State
    private var flagsLoaded = false
    @State
    private var loggingIn = false

    private let confidence: Confidence

    init(confidence: Confidence) {
        self.confidence = confidence
    }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                ZStack {
                    Button(action: {
                        do {
                            try confidence.activate()
                        } catch {
                            flaggingState.state = .error(
                                ExperimentationFlags.CustomError(message: error.localizedDescription))
                        }

                        let client = OpenFeatureAPI.shared.getClient()
                        let eval = client.getStringDetails(key: "swift-demoapp.color", defaultValue: "Gray")
                        print("[Telemetry] Login flag eval: key=swift-demoapp.color value=\(eval.value) reason=\(eval.reason ?? "nil")")
                        flaggingState.color = ContentView.getColor(
                            color: eval.value
                        )
                        flaggingState.reason = ResolveReason(rawValue: eval.reason ?? "") ?? .unknown

                        Task {
                            flaggingState.state = .loading
                            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                            await confidence.putContextAndWait(context: ["user_id": .init(string: "user1")])
                            flaggingState.state = .ready
                            print("[Telemetry] Context updated with user_id, flags refreshed")
                        }

                        Task {
                            loggingIn = true
                            try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                            loggedUser = "user1"
                            loggingIn = false
                            loginCompleted = true
                        }
                    }, label: {
                        Text("Login as user1")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    })
                    .navigationDestination(isPresented: $loginCompleted) {
                        ContentView(confidence: confidence)
                    }

                    if loggingIn {
                        ProgressView()
                            .offset(y: 40)
                    }
                }
                Spacer()
            }
        }
    }
}
