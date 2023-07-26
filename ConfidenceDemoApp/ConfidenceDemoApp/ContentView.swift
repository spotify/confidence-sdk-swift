import SwiftUI
import OpenFeature

struct ContentView: View {
    @StateObject var text: DisplayText = DisplayText()
    @StateObject var color: FlagColor = FlagColor()

    var body: some View {
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
                    .getStringValue(key: "hawkflag.color", defaultValue: "ERROR")
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
    }
}

class DisplayText: ObservableObject {
    @Published var text = "Hello World!"
}


class FlagColor: ObservableObject {
    @Published var color: Color = .black
}
