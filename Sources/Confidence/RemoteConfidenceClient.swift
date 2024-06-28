import Foundation
import os

public class RemoteConfidenceClient: ConfidenceClient {
    private var options: ConfidenceClientOptions
    private let metadata: ConfidenceMetadata
    private var httpClient: HttpClient
    private var baseUrl: String
    private let debugLogger: DebugLogger?

    init(
        options: ConfidenceClientOptions,
        session: URLSession? = nil,
        metadata: ConfidenceMetadata,
        debugLogger: DebugLogger? = nil
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
        self.debugLogger = debugLogger
    }

    func upload(events: [NetworkEvent]) async throws -> Bool {
        let timeString = Date.backport.nowISOString
        let request = PublishEventRequest(
            events: events.map { event in NetworkEvent(
                eventDefinition: "eventDefinitions/\(event.eventDefinition)",
                payload: event.payload,
                eventTime: event.eventTime)
            },
            clientSecret: options.credentials.getSecret(),
            sendTime: timeString,
            sdk: Sdk(id: metadata.name, version: metadata.version)
        )
        do {
            let result: HttpClientResult<PublishEventResponse> =
            try await self.httpClient.post(path: ":publish", data: request)
            switch result {
            case .success(let successData):
                let status = successData.response.statusCode
                switch status {
                case 200:
                    // clean up in case of success
                    debugLogger?.logMessage(
                        message: "Event upload: HTTP status 200",
                        isWarning: false
                    )
                    return true
                case 429:
                    // we shouldn't clean up for rate limiting
                    debugLogger?.logMessage(
                        message: "Event upload: HTTP status 429",
                        isWarning: true
                    )
                    return false
                case 400...499:
                    // if batch couldn't be processed, we should clean it up
                    debugLogger?.logMessage(
                        message: "Event upload: couldn't process batch",
                        isWarning: true
                    )
                    return true
                default:
                    debugLogger?.logMessage(
                        message: "Event upload error. Status code \(status)",
                        isWarning: true
                    )
                    return false
                }
            case .failure(let errorData):
                throw handleError(error: errorData)
            }
        }
    }

    private func handleError(error: Error) -> Error {
        debugLogger?.logMessage(
            message: "Event upload error: \(error.localizedDescription)",
            isWarning: true
        )
        if error is ConfidenceError {
            return error
        } else {
            return ConfidenceError.internalError(message: "\(error)")
        }
    }
}

struct PublishEventRequest: Codable {
    var events: [NetworkEvent]
    var clientSecret: String
    var sendTime: String
    var sdk: Sdk
}

struct NetworkEvent: Codable {
    var eventDefinition: String
    var payload: NetworkStruct
    var eventTime: String
}

struct PublishEventResponse: Codable {
    var errors: [EventError]
}

struct EventError: Codable {
    var index: Int
    var reason: Reason
    var message: String

    enum Reason: String, Codable, CaseIterableDefaultsLast {
        case unspecified = "REASON_UNSPECIFIED"
        case eventDefinitionNotFound = "EVENT_DEFINITION_NOT_FOUND"
        case eventSchemaValidationFailed = "EVENT_SCHEMA_VALIDATION_FAILED"
        case unknown
    }
}
