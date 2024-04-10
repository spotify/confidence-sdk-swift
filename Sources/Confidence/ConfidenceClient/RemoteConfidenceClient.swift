import Foundation

public class RemoteConfidenceClient: ConfidenceClient {
    private var options: ConfidenceClientOptions
    private let metadata: ConfidenceMetadata
    private var httpClient: HttpClient

    init(
        options: ConfidenceClientOptions,
        session: URLSession? = nil,
        metadata: ConfidenceMetadata
    ) {
        self.options = options
        self.httpClient = NetworkClient(session: session, region: options.region)
        self.metadata = metadata
    }

    public func send(definition: String, payload: ConfidenceStruct) async throws {
        let request = PublishEventRequest(
            eventDefinition: definition,
            payload: payload,
            clientSecret: options.credentials.getSecret(),
            sdk: Sdk(id: metadata.name, version: metadata.version)
        )

        do {
            let result: HttpClientResult<PublishEventResponse> =
            try await self.httpClient.post(path: ":publish", data: request)
            switch result {
            case .success(let successData):
                guard successData.response.status == .ok else {
                    throw successData.response.mapStatusToError(error: successData.decodedError)
                }
                return
            case .failure(let errorData):
                throw handleError(error: errorData)
            }
        }
    }

    private func handleError(error: Error) -> Error {
        if error is ConfidenceError {
            return error
        } else {
            return ConfidenceError.grpcError(message: "\(error)")
        }
    }
}

struct PublishEventRequest: Encodable {
    var eventDefinition: String
    var payload: ConfidenceStruct
    var clientSecret: String
    var sdk: Sdk
}

struct PublishEventResponse: Codable {
}

struct Sdk: Encodable {
    init(id: String?, version: String?) {
        self.id = id ?? "SDK_ID_SWIFT_PROVIDER"
        self.version = version ?? "unknown"
    }

    var id: String
    var version: String
}
