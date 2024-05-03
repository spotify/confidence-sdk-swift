import Foundation
import Common
import OpenFeature

@testable import Confidence

class MockedResolveClientURLProtocol: URLProtocol {
    public static var callStats = 0
    public static var resolveStats = 0
    public static var resolveRequestFields = NetworkStruct(fields: [:])
    public static var flags: [String: TestFlag] = [:]
    public static var failFirstApply = false

    static func set(flags: [String: TestFlag]) {
        MockedResolveClientURLProtocol.flags = flags
    }

    static func mockedSession(flags: [String: TestFlag]) -> URLSession {
        MockedResolveClientURLProtocol.set(flags: flags)
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockedResolveClientURLProtocol.self]

        return URLSession(configuration: config)
    }

    static func reset() {
        MockedResolveClientURLProtocol.flags = [:]
        MockedResolveClientURLProtocol.callStats = 0
        MockedResolveClientURLProtocol.resolveStats = 0
        MockedResolveClientURLProtocol.failFirstApply = false
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let path = request.url?.absoluteString, request.httpMethod == "POST" else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "test", code: URLError.badURL.rawValue))
            return
        }

        switch path {
        case _ where path.hasSuffix("/flags:resolve"):
            return resolve()
        default:
            client?.urlProtocol(self, didFailWithError: NSError(domain: "test", code: URLError.badURL.rawValue))
            return
        }
    }

    override func stopLoading() {
        // This is called if the request gets canceled or completed.
    }

    private func resolve() {
        MockedResolveClientURLProtocol.callStats += 1
        MockedResolveClientURLProtocol.resolveStats += 1
        guard let request = request.decodeBody(type: ResolveFlagsRequest.self) else {
            client?.urlProtocol(
                self, didFailWithError: NSError(domain: "test", code: URLError.cannotDecodeRawData.rawValue))
            return
        }

        MockedResolveClientURLProtocol.resolveRequestFields = request.evaluationContext

        guard case .string(let targetingKey) = request.evaluationContext.fields["targeting_key"] else {
            respondWithError(
                statusCode: 400,
                code: GrpcStatusCode.invalidArgument.rawValue,
                message: "Request missing field targeting_key")
            return
        }

        let flags = MockedResolveClientURLProtocol.flags
            .filter { _, flag in
                flag.isArchived == false
            }
            .filter { flagName, _ in
                if !request.flags.isEmpty {
                    return request.flags.contains(flagName)
                }
                return true
            }
            .map { flagName, flag in
                guard let resolved = flag.resolve[targetingKey], let schema = flag.schemas[targetingKey] else {
                    return ResolvedFlag(flag: flagName, reason: .noSegmentMatch)
                }
                var responseValue: ConfidenceStruct? = resolved.value

                if responseValue == nil {
                    respondWithError(
                        statusCode: 400,
                        code: GrpcStatusCode.invalidArgument.rawValue,
                        message: "Could not convert value to response")
                }

                // Assume that, if present, "custom_targeting_key" is the targeting key field configured for a flag
                if request.evaluationContext.fields["custom_targeting_key"] != nil {
                    guard case .string = request.evaluationContext.fields["custom_targeting_key"] else {
                        return ResolvedFlag(
                            flag: flagName, reason: .targetingKeyError)
                    }
                }
                return ResolvedFlag(
                    flag: flagName, value: responseValue, variant: resolved.variant, flagSchema: schema, reason: .match)
            }
        respondWithSuccess(
            response: ResolveFlagsResponse(resolvedFlags: flags, resolveToken: "token1"))
    }

    private func respondWithError(statusCode: Int, code: Int, message: String) {
        let error = HttpError(code: code, message: message, details: [])
        let errorData = try? JSONEncoder().encode(error)

        let response = HTTPURLResponse(
            // swiftlint:disable:next force_unwrapping
            url: request.url!, statusCode: statusCode, httpVersion: "", headerFields: [:])!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let errorData = errorData {
            client?.urlProtocol(self, didLoad: errorData)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    private func respondWithSuccess(response: Codable) {
        // swiftlint:disable:next force_unwrapping
        let httpResponse = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "", headerFields: [:])!

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)

        if let data = try? JSONEncoder().encode(response) {
            client?.urlProtocol(self, didLoad: data)
        }

        client?.urlProtocolDidFinishLoading(self)
    }
}

extension MockedResolveClientURLProtocol {
    struct ResolvedTestFlag {
        var variant: String
        var value: ConfidenceStruct
    }

    struct TestFlag {
        var resolve: [String: ResolvedTestFlag]
        var schemas: [String: StructFlagSchema]
        var isArchived: Bool

        init(
            resolve: [String: ResolvedTestFlag],
            schemas: [String: StructFlagSchema],
            isArchived: Bool = false
        ) {
            self.resolve = resolve
            self.schemas = schemas
            self.isArchived = isArchived
        }

        init(resolve: [String: ResolvedTestFlag], isArchived: Bool = false) {
            self.resolve = resolve
            self.schemas = resolve.compactMapValues { resolvedValue in
                let structure = resolvedValue.value
                let schema = structure.compactMapValues(TestFlag.toSchema)

                return StructFlagSchema(schema: schema)
            }
            self.isArchived = isArchived
        }

        // swiftlint:disable:next cyclomatic_complexity
        private static func toSchema(value: ConfidenceValue) -> FlagSchema? {
            switch value.type() {
            case .boolean:
                return FlagSchema.boolSchema
            case .string:
                return FlagSchema.stringSchema
            case .integer:
                return FlagSchema.intSchema
            case .double:
                return FlagSchema.doubleSchema
            case .date:
                return nil
            case .list:
                guard let list = value.asList() else {
                    return nil
                }
                if list.isEmpty {
                    return nil
                }

                let schemas = list.compactMap(TestFlag.toSchema)
                guard let firstSchema = schemas.first else {
                    return nil
                }

                if !schemas.allSatisfy({ $0 == firstSchema }) {
                    return nil
                }

                return FlagSchema.listSchema(firstSchema)
            case .structure:
                guard let structure = value.asStructure() else {
                    return nil
                }
                if structure.isEmpty {
                    return nil
                }

                let schemas = structure.compactMapValues(TestFlag.toSchema)

                return FlagSchema.structSchema(StructFlagSchema(schema: schemas))
            case .null:
                return nil
            case .timestamp:
                return nil
            }
        }
    }
}
