import Foundation
import os

public class RemoteConfidenceClient: ConfidenceClient {
    private var options: ConfidenceClientOptions
    private let telemetry: Telemetry
    private var httpClient: HttpClient
    private var baseUrl: String
    private let debugLogger: DebugLogger?

    init(
        options: ConfidenceClientOptions,
        session: URLSession? = nil,
        telemetry: Telemetry,
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
        self.httpClient = NetworkClient(
            session: session,
            baseUrl: baseUrl,
            timeoutIntervalForRequests: options.timeoutIntervalForRequest
        )
        self.telemetry = telemetry
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
            sdk: telemetry.sdk
        )
        do {
            let result: HttpClientResult<PublishEventResponse> =
            try await self.httpClient.post(
                path: ":publish", data: request
            )
            switch result {
            case .success(let successData):
                return handleSuccess(successData: successData, events: events)
            case .failure(let errorData):
                throw handleError(error: errorData)
            }
        }
    }

    private func handleSuccess(
        successData: HttpClientResponse<PublishEventResponse>,
        events: [NetworkEvent]
    ) -> Bool {
        let status = successData.response.statusCode
        let indicesWithError = successData.decodedData?.errors.map { error in
            error.index
        } ?? []
        let successEventNames = events.enumerated()
            .filter { index, _ in
                return !(indicesWithError.contains(index))
            }
            .map { _, event in
                event.eventDefinition
            }
        switch status {
        case 200:
            if let errors = successData.decodedData?.errors, !errors.isEmpty {
                for error in errors {
                    let eventName = events.indices.contains(error.index)
                        ? events[error.index].eventDefinition
                        : "index-\(error.index)"
                    debugLogger?.logMessage(
                        message: "Event upload rejected: \(eventName) "
                            + "reason=\(error.reason.rawValue) message=\(error.message)",
                        isWarning: true
                    )
                }
            }
            debugLogger?.logMessage(
                message: "Event upload: HTTP status 200. Events: \(successEventNames.joined(separator: ","))",
                isWarning: false
            )
            return true
        case 429:
            debugLogger?.logMessage(
                message: "Event upload: HTTP status 429",
                isWarning: true
            )
            return false
        case 400...499:
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
