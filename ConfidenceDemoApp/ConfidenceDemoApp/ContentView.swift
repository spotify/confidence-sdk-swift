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

    private let confidence: Confidence

    init(confidence: Confidence, color: Color? = nil) {
        self.confidence = confidence
    }

    var body: some View {
        NavigationStack {
            VStack {
                if let user = loggedUser {
                    Text("Hello \(user)")
                        .font(.largeTitle)
                        .padding()
                }
                Spacer()
                NavigationLink(destination: AboutPage(confidence: confidence)) {
                    Text("Navigate")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .padding()
                Button(action: {
                    isLoggingOut = true
                    loggedUser = nil
                    flaggingState.state = .loading
                    flaggingState.color = .gray
                    Task {
                        await confidence.removeContextAndWait(key: "user_id")
                        flaggingState.state = .ready
                    }
                    loggedOut = true
                }, label: {
                    Text("Logout")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .clipShape(Capsule())
                })
                .navigationDestination(isPresented: $loggedOut) {
                    LoginView(confidence: confidence)
                }
                Spacer()
            }
            Spacer()
            HStack {
                Text("[1]")
                if flaggingState.state == .loading && !isLoggingOut {
                    Text("Loading the text color...")
                        .font(.body)
                } else {
                    let eval = confidence.getEvaluation(key: "swift-demoapp.color", defaultValue: "Gray")
                    Text("This text only appears after a successful flag fetching")
                        .font(.body)
                        .foregroundStyle(ContentView.getColor(color: eval.value))
                    Spacer()
                    Text("[\(eval.reason)]")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            HStack {
                let eval = confidence.getEvaluation(
                    key: "swift-demoapp.color",
                    defaultValue: "Gray")
                Text("[2]")
                Text("This text color dynamically changes on each flags fetch")
                    .font(.body)
                    .foregroundStyle(ContentView.getColor(
                        color: eval.value))
                Spacer()
                Text("[\(eval.reason)]")
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding()

            HStack {
                Text("[3]")
                Text("This text color is fixed from app start, doesn't react on flag fetches")
                    .font(.body)
                    .foregroundStyle(flaggingState.color)
                Spacer()
                Text("[\(flaggingState.reason)]")
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding()
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
    @State
    private var textColor = Color.red
    @State
    private var reason = ResolveReason.unknown
    private let confidence: Confidence

    init(confidence: Confidence) {
        self.confidence = confidence
    }

    var body: some View {
        HStack {
            Text("This text color is set on onAppear, doesn't wait for flag fetch")
                .font(.body)
                .foregroundStyle(textColor)
                .padding()
                .onAppear {
                    let eval = confidence.getEvaluation(key: "swift-demoapp.color", defaultValue: "Gray")
                    textColor = ContentView.getColor(
                        color: eval.value)
                    reason = eval.reason
                }
            Spacer()
            Text("[\(reason)]")
        }
    }
}
