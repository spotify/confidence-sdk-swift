import SwiftUI
import Confidence

struct WatchContentView: View {
    @EnvironmentObject var flaggingState: WatchFlaggingState

    private let confidence: Confidence

    init(confidence: Confidence) {
        self.confidence = confidence
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                flagSwatch

                Text(flagValue)
                    .font(.headline)
                    .foregroundStyle(flagColor)

                statusRow

                Text("[\(flaggingState.reason)]")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button {
                    refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(flaggingState.state == .loading)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Confidence")
    }

    private var flagSwatch: some View {
        Circle()
            .fill(flagColor)
            .frame(width: 44, height: 44)
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var statusRow: some View {
        switch flaggingState.state {
        case .loading:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Loading...")
                    .font(.caption2)
            }
        case .ready:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption2)
                Text("Ready")
                    .font(.caption2)
            }
        case .error(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption2)
                Text(message)
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
    }

    private var flagValue: String {
        confidence.getEvaluation(key: "swift-demoapp.color", defaultValue: "Gray").value
    }

    private var flagColor: Color {
        Self.getColor(color: flagValue)
    }

    private func refresh() {
        Task {
            flaggingState.state = .loading
            do {
                try await confidence.fetchAndActivate()
                flaggingState.state = .ready
            } catch {
                flaggingState.state = .error(error.localizedDescription)
            }
        }
    }

    static func getColor(color: String) -> Color {
        switch color {
        case "Green": return .green
        case "Yellow": return .yellow
        case "Gray": return .gray
        default: return .red
        }
    }
}
