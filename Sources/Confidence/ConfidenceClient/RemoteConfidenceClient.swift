import Foundation
import Common
import os

public class RemoteConfidenceClient: ConfidenceClient {
    private var options: ConfidenceClientOptions
    private let metadata: ConfidenceMetadata
    private var httpClient: HttpClient
    private var baseUrl: String

    init(
        options: ConfidenceClientOptions,
        session: URLSession? = nil,
        metadata: ConfidenceMetadata
    ) {
        self.options = options
        switch options.region {
        case .global:
            self.baseUrl = "https://events.confidence.dev/v1/events"
        case .europe:
            self.baseUrl = "https://events.eu.confidence.dev/v1/events"
        case .usa:
            self.baseUrl = "https://events.us.confidence.dev/v1/events"
        }
        self.httpClient = NetworkClient(session: session, baseUrl: baseUrl)
        self.metadata = metadata
    }

    public func send(definition: String, payload: ConfidenceStruct) async throws {
        let timeString = Date.backport.nowISOString
        let request = PublishEventRequest(
            events: [
                Event(
                    eventDefinition: "eventDefinitions/\(definition)",
                    payload: payload,
                    eventTime: timeString
                )
            ],
            clientSecret: options.credentials.getSecret(),
            sendTime: timeString,
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
                let indexedErrorsCount = successData.decodedData?.errors.count ?? 0
                if indexedErrorsCount > 0 {
                    Logger(subsystem: "com.confidence.client", category: "network").error(
                        "Backend reported errors for \(indexedErrorsCount) event(s) in batch")
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
    var events: [Event]
    var clientSecret: String
    var sendTime: String
    var sdk: Sdk
}

struct Event: Encodable {
    var eventDefinition: String
    var payload: ConfidenceStruct
    var eventTime: String
}

struct PublishEventResponse: Decodable {
    var errors: [EventError]
}

struct EventError: Decodable {
    var index: Int
    var reason: Reason
    var message: String

    enum Reason: String, Decodable, CaseIterableDefaultsLast {
        case unspecified = "REASON_UNSPECIFIED"
        case eventDefinitionNotFound = "EVENT_DEFINITION_NOT_FOUND"
        case eventSchemaValidationFailed = "EVENT_SCHEMA_VALIDATION_FAILED"
        case unknown
    }
}


struct Sdk: Encodable {
    init(id: String?, version: String?) {
        self.id = id ?? "SDK_ID_SWIFT_PROVIDER"
        self.version = version ?? "unknown"
    }

    var id: String
    var version: String
}
