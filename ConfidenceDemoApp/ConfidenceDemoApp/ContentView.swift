import SwiftUI
import OpenFeature

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

    @Published var state: State = .unknown

    init() {
        OpenFeatureAPI.shared.addHandler(
            observer: self,
            selector: #selector(confidenceReady(notification:)),
            event: .ready
        )

        OpenFeatureAPI.shared.addHandler(
            observer: self,
            selector: #selector(confidenceError(notification:)),
            event: .error
        )
    }

    @objc func confidenceReady(notification: Notification) {
        DispatchQueue.main.async {
            self.state = .ready
        }
    }

    @objc func confidenceError(notification: Notification) {
        DispatchQueue.main.async {
            let error = notification.userInfo?[providerEventDetailsKeyError] as? Error
            self.state = .error(error)
        }
    }
}

class DisplayText: ObservableObject {
    @Published var text = "Hello World!"
}


class FlagColor: ObservableObject {
    @Published var color: Color = .black
}
