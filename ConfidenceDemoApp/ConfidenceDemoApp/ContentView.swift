import SwiftUI
import Confidence
import Combine

struct ContentView: View {
    @ObservedObject var status: Status
    @StateObject var text = DisplayText()
    @StateObject var color = FlagColor()
    @State private var user = "logged out"
    @State private var logginIn = false
    @State private var evaluationReason = "Last Reason: ---"
    @State private var evaluationError = "Last Error: ---"

    private let confidence: Confidence

    init(confidence: Confidence, status: Status) {
        self.confidence = confidence
        self.status = status
    }

    var body: some View {
        if case .ready = status.state {
            VStack {
                Text("Current user:")
                if (logginIn) {
                    ProgressView()
                } else {
                    Text("\(user)")
                        .font(.title)
                        .bold()
                }
                Spacer()
                Image(systemName: "flag")
                    .imageScale(.large)
                    .font(.title)
                    .foregroundColor(color.color)
                    .padding(10)
                Text(text.text)
                Spacer()
                Button("Login yellow user") {
                    confidence.putContext(key: "user_id", value: ConfidenceValue.init(string: "user1"))
                    Task {
                        logginIn = true
                        try await confidence.fetchAndActivate()
                        user = "yellow_user"
                        logginIn = false
                    }
                }
                Button("Login green user") {
                    confidence.putContext(key: "user_id", value: ConfidenceValue.init(string: "user2"))
                    Task {
                        logginIn = true
                        try await confidence.fetchAndActivate()
                        logginIn = false
                        user = "green_user"
                    }
                }
                .padding(.bottom)
                Button("Get remote flag value") {
                    let eval = confidence.getEvaluation(key: "swift-demoapp.color", defaultValue: "DefaultValue")
                    evaluationReason = "Last Reason: \(eval.reason)"
                    evaluationError = "Last Error: \(eval.errorCode?.description ?? .none ?? "None")"
                    text.text = eval.value
                    if text.text == "Green" {
                        color.color = .green
                    } else if text.text == "Yellow" {
                        color.color = .yellow
                    } else {
                        color.color = .gray
                    }
                }
                VStack(alignment: .leading) {
                    HStack {
                        Text(evaluationReason)
                            .padding(.horizontal)
                        Spacer()
                    }
                    HStack {
                        Text(evaluationError)
                            .padding(.horizontal)
                        Spacer()
                    }
                }
                .padding(.bottom)
                Button("Get remote flag value with TypeMismatch ⚠️") {
                    let eval = confidence.getEvaluation(key: "swift-demoapp.color", defaultValue: true)
                    evaluationReason = "Last Reason: \(eval.reason)"
                    evaluationError = "Last Error: \(eval.errorCode?.description ?? .none ?? "None")"
                    if text.text == "Green" {
                        color.color = .green
                    } else if text.text == "Yellow" {
                        color.color = .yellow
                    } else {
                        color.color = .gray
                    }
                }
                .padding(.bottom)
                Button("Generate event") {
                    try! confidence.track(eventName: "Test", data: [:])
                }
                .padding(.top)
                Button("Flush 🚽") {
                    confidence.flush()
                }
                .padding(.bottom)
            }
            .padding()
        } else if case .error(let error) = status.state {
            VStack {
                Text("Provider Error")
                Text(error?.localizedDescription ?? "An unknow error has occured.")
                    .foregroundColor(.red)
            }
        } else {
            VStack {
                ProgressView()
            }
        }
    }
}

class Model: ObservableObject {

}

class DisplayText: ObservableObject {
    @Published var text = "Hello World!"
}


class FlagColor: ObservableObject {
    @Published var color: Color = .black
}
