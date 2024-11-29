import SwiftUI
import Confidence
import Combine

struct ContentView: View {
    @EnvironmentObject
    var flaggingState: ExperimentationFlags
    @AppStorage("loggedUser")
    private var loggedUser: String?
    @State
    private var isLoggingOut = false
    @State
    private var loggedOut = false
    @State
    private var textColor = Color.red

    private let confidence: Confidence

    init(confidence: Confidence, color: Color? = nil) {
        self.confidence = confidence
    }

    var body: some View {
        NavigationStack {
            if flaggingState.state == .loading && !isLoggingOut {
                VStack {
                    Spacer()
                    Text("Login successful: \(loggedUser ?? "?")")
                    Text("We are preparing your experience...")
                    ProgressView()
                }
            } else {
                if flaggingState.state == .ready {
                    VStack {
                        Spacer()
                        if let user = loggedUser {
                            let eval = confidence.getEvaluation(key: "swift-demoapp.color", defaultValue: "Gray")
                            VStack {
                                Text("Hello \(user)")
                                    .font(.largeTitle)
                                    .foregroundStyle(ContentView.getColor(color: eval.value))
                                    .padding()
                                Text("This text only appears after a successful flag fetching")
                                    .font(.caption)
                                    .foregroundStyle(ContentView.getColor(color: eval.value))
                                    .padding()
                            }
                        }
                    }
                }
                NavigationLink(destination: AboutPage()) {
                    Text("Navigate")
                }
                Button("Logout") {
                    isLoggingOut = true
                    loggedUser = nil
                    flaggingState.state = .loading
                    flaggingState.color = .gray
                    Task {
                        await confidence.removeContext(key: "user_id")
                        flaggingState.state = .ready
                    }
                    loggedOut = true
                }
                .navigationDestination(isPresented: $loggedOut) {
                    LoginView(confidence: confidence)
                }
                Spacer()
            }
            ZStack {
                VStack {
                    Spacer()
                    Text("This text color is set on onAppear, doesn't wait for flag fetch")
                        .font(.caption)
                        .foregroundStyle(textColor)
                    Text("This text color dynamically changes on each flags fetch")
                        .font(.caption)
                        .foregroundStyle(ContentView.getColor(
                            color: confidence.getValue(
                                key: "swift-demoapp.color",
                                defaultValue: "Gray")))
                    Text("This text color is fixed from app start, doesn't react on flag fetches")
                        .font(.caption)
                        .foregroundStyle(flaggingState.color)
                }
            }.onAppear {
                let eval = confidence.getEvaluation(key: "swift-demoapp.color", defaultValue: "Gray")
                print(">> Evaluation reason: \(eval)")
                textColor = ContentView.getColor(color: eval.value)
            }
        }
    }

    static func getColor(color: String) -> Color {
        switch color {
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

struct AboutPage: View {
    var body: some View {
        Text("Mock Page")
    }
}
