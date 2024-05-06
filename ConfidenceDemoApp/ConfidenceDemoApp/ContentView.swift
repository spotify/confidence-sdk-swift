import SwiftUI
import Confidence
import Combine

struct ContentView: View {
    @ObservedObject var status: Status
    @StateObject var text = DisplayText()
    @StateObject var color = FlagColor()

    private let confidence: Confidence

    init(confidence: Confidence, status: Status) {
        self.confidence = confidence
        self.status = status
    }

    var body: some View {
        if case .ready = status.state {
            VStack {
                Image(systemName: "flag")
                    .imageScale(.large)
                    .foregroundColor(color.color)
                    .padding(10)
                Text(text.text)
                Button("Get remote flag value") {
                    text.text = confidence.getValue(key: "swift-demoapp.color", defaultValue: "DEFAULT")
                    if text.text == "Green" {
                        color.color = .green
                    } else if text.text == "Yellow" {
                        color.color = .yellow
                    } else {
                        color.color = .red
                    }
                }
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

class DisplayText: ObservableObject {
    @Published var text = "Hello World!"
}


class FlagColor: ObservableObject {
    @Published var color: Color = .black
}
