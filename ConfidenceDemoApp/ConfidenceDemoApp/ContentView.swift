import SwiftUI
import OpenFeature
import Combine

struct ContentView: View {
    @StateObject var status = Status()
    @StateObject var text = DisplayText()
    @StateObject var color = FlagColor()

    var body: some View {
        if case .ready = status.state {
            VStack {
                Image(systemName: "flag")
                    .imageScale(.large)
                    .foregroundColor(color.color)
                    .padding(10)
                Text(text.text)
                Button("Get remote flag value") {
                    text.text = OpenFeatureAPI
                        .shared
                        .getClient()
                        .getStringValue(key: "swift-demoapp.color", defaultValue: "ERROR")
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

class Status: ObservableObject {
    enum State {
        case unknown
        case ready
        case error(Error?)
    }

    var cancellable: AnyCancellable?

    @Published var state: State = .unknown

    init() {
        cancellable = OpenFeatureAPI.shared.observe().sink { event in
            if event == .ready {
                DispatchQueue.main.async {
                    self.state = .ready
                }
            }
            if event == .error {
                DispatchQueue.main.async {
                    self.state = .error(nil)
                }
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
