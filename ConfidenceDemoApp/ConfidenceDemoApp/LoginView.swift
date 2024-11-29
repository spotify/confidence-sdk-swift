import SwiftUI
import Confidence

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
                Button("Login as user1") {
                    do {
                        try confidence.activate()
                    } catch {
                        flaggingState.state = .error(
                            ExperimentationFlags.CustomError(message: error.localizedDescription))
                    }

                    flaggingState.color = ContentView.getColor(
                        color: confidence.getValue(key: "swift-demoapp.color", defaultValue: "Gray")
                    )

                    // Simulating a module that handles feature flagging state during login
                    Task {
                        flaggingState.state = .loading
                        try? await Task.sleep(nanoseconds: 5 * 1_000_000_000) // simulating network delay
                        // putContext adds the user_id field to the evaluation context and fetches values for it
                        await confidence.putContext(context: ["user_id": .init(string: "user1")])
                        flaggingState.state = .ready
                    }

                    // Simulating a module that handles the actual login mechanism for a user
                    Task {
                        loggingIn = true
                        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000) // simulating network delay
                        loggedUser = "user1"
                        loggingIn = false
                        loginCompleted = true
                    }
                }
                .navigationDestination(isPresented: $loginCompleted) {
                    ContentView(confidence: confidence)
                }

                if loggingIn {
                    ProgressView()
                }

                Spacer()
            }
        }
    }
}
