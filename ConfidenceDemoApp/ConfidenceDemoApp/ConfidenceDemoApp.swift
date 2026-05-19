import Confidence
import SwiftUI

// NOTE(unit-local experiment): kept around solely to satisfy the existing
// `LoginView` / `ContentView` references; the new UnitLocalDemoView below
// does not use it.
class ExperimentationFlags: ObservableObject {
    var color: Color = .red
    var reason: ResolveReason = .unknown
    @Published var state: State = .notReady

    enum State: Equatable {
        case unknown
        case notReady
        case loading
        case ready
        case error(CustomError?)
    }

    public struct CustomError: Error, Equatable {
        let message: String
    }
}

// NOTE(unit-local experiment): demo app rewritten to use a WASM-backed local
// resolver pointed at the local slice server. Original online flow preserved
// in git history. To run:
//
//   1. cd <confidence-resolver-unit-local-worktree> && cargo run -p unit-local-server
//   2. In Xcode, open this project and run the iOS simulator target.
//      Optional env vars on the run scheme:
//        UNIT_LOCAL_SERVER       (default http://127.0.0.1:8787)
//        CLIENT_SECRET           (default the fixture's confidence-demo-june secret)
//        UNIT_LOCAL_DEMO_FLAG    (default "fallthrough-test-1.enabled")
//
//   The fixture's flags don't include `swift-demoapp.color`; this demo
//   queries one of the fallthrough-test-* flags which return { enabled: bool }
//   and colours a label green/red based on the result.

@main
struct ConfidenceDemoApp: App {
    private let secret = ProcessInfo.processInfo.environment["CLIENT_SECRET"]
        ?? "mkjJruAATQWjeY7foFIWfVAcBWnci2YF"
    private let unitLocalServer = ProcessInfo.processInfo.environment["UNIT_LOCAL_SERVER"]
        ?? "http://127.0.0.1:8787"
    private let demoFlag = ProcessInfo.processInfo.environment["UNIT_LOCAL_DEMO_FLAG"]
        ?? "fallthrough-test-1.enabled"

    var body: some Scene {
        WindowGroup {
            UnitLocalDemoView(
                clientSecret: secret,
                serverURL: URL(string: unitLocalServer)!,
                flagKey: demoFlag
            )
        }
    }
}

/// Simple demo view that:
///   1. Bootstraps a `LocalConfidenceResolveClient` against the local slice server.
///   2. Builds a `Confidence` with the local resolver wired in.
///   3. Lets you change the randomization unit (visitor_id) and re-resolve.
///   4. Renders the resolved flag's match reason + value.
struct UnitLocalDemoView: View {
    let clientSecret: String
    let serverURL: URL
    let flagKey: String

    @State private var unit: String = "user_42"
    @State private var inputUnit: String = "user_42"
    @State private var status: Status = .idle
    @State private var resolvedSummary: String = ""
    @State private var lastReason: String = ""
    @State private var matched: Bool = false
    @State private var localClient: LocalConfidenceResolveClient?
    @State private var confidence: Confidence?

    enum Status: Equatable {
        case idle
        case bootstrapping
        case resolving
        case ready
        case error(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header

                HStack {
                    Text("visitor_id").font(.callout).foregroundStyle(.secondary)
                    TextField("user_42", text: $inputUnit)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Resolve") {
                        unit = inputUnit
                        Task { await resolve() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputUnit.isEmpty || status == .resolving || status == .bootstrapping)
                }
                .padding(.horizontal)

                Spacer()

                resultBox

                Spacer()

                Text(serverURL.absoluteString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Unit-local Demo")
            .task {
                await bootstrap()
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        switch status {
        case .idle:
            Text("Initialising…").font(.headline).foregroundStyle(.secondary)
        case .bootstrapping:
            ProgressView("Bootstrapping local resolver…")
        case .resolving:
            ProgressView("Resolving flag…")
        case .ready:
            Text("Ready").font(.headline).foregroundStyle(.green)
        case .error(let message):
            Text("Error: \(message)").font(.headline).foregroundStyle(.red).multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var resultBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("flag: \(flagKey)").font(.body.monospaced())
            Text("reason: \(lastReason)").font(.body.monospaced())
            Text("value: \(resolvedSummary)").font(.body.monospaced()).foregroundStyle(matched ? .green : .red)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func bootstrap() async {
        guard localClient == nil else { return }
        status = .bootstrapping
        do {
            let client = try await LocalConfidenceResolveClient.bootstrap(
                clientSecret: clientSecret,
                serverURL: serverURL
            )
            localClient = client
            let context: ConfidenceStruct = [
                "visitor_id": ConfidenceValue(string: unit),
                "country": ConfidenceValue(string: "SE"),
            ]
            let confidence = Confidence.Builder(clientSecret: clientSecret, loggerLevel: .TRACE)
                .withContext(initialContext: context)
                .withLocalResolver(client)
                .build()
            self.confidence = confidence
            await resolve()
        } catch {
            status = .error(String(describing: error))
        }
    }

    private func resolve() async {
        guard let confidence else { return }
        status = .resolving
        await confidence.removeContextAndWait(key: "visitor_id")
        confidence.putContext(key: "visitor_id", value: ConfidenceValue(string: unit))
        do {
            try await confidence.fetchAndActivate()
            let eval = confidence.getEvaluation(key: flagKey, defaultValue: false)
            matched = eval.value
            let errPart: String
            if let code = eval.errorCode {
                errPart = " (errorCode=\(code) msg=\(eval.errorMessage ?? "nil"))"
            } else {
                errPart = ""
            }
            resolvedSummary = "\(eval.value)\(errPart)"
            lastReason = String(describing: eval.reason)
            status = .ready
        } catch {
            status = .error(String(describing: error))
        }
    }
}
